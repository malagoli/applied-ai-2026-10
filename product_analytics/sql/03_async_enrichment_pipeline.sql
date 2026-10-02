-- =============================================================================
-- Step 3: asynchronous enrichment pipeline with quota-error retries
--
-- Creates:
--   * review_insights — structured output table
--   * enrich_new_reviews() — stored procedure that processes ONLY reviews not
--     yet analyzed (incremental / idempotent), using AI.GENERATE with a typed
--     output_schema so Gemini returns a validated STRUCT per review.
--
-- Quota-error handling
-- (https://docs.cloud.google.com/bigquery/docs/iterate-generate-text-calls):
-- when many rows hit Vertex AI at once, some calls can fail with a RETRYABLE
-- quota / rate-limit error. The row still lands in the output, with the error
-- recorded in the AI status column as 'A retryable error occurred: ...'.
-- Following the pattern from the doc above, the procedure iterates: it deletes
-- rows whose status marks a retryable error so the incremental anti-join picks
-- them up again, and repeats up to max_attempts times or until no retryable
-- failures remain. Non-retryable errors are kept (with their status) so they
-- can be inspected and are never retried blindly.
-- (For ML.GENERATE_TEXT remote-model pipelines Google ships a ready-made
-- wrapper, `bqutil.procedure.bqml_generate_text`; AI.GENERATE has no public
-- wrapper yet, so this procedure applies the same status-check-and-retry
-- pattern directly.)
--
-- The procedure is designed to be invoked asynchronously by a BigQuery
-- scheduled query (see DEMO_WALKTHROUGH.md) so new reviews landing in
-- product_reviews get analyzed continuously without any application code.
--
-- Run with:  bq query --use_legacy_sql=false --location=EU < sql/03_async_enrichment_pipeline.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS `mfg_quality_demo.review_insights` (
  review_id          STRING NOT NULL,
  sentiment          STRING,   -- positive | neutral | negative
  is_defect_report   BOOL,
  defect_category    STRING,   -- heating | motor | leak_seal | electronics | housing_cosmetic | none
  affected_component STRING,   -- heating_element | thermostat | motor | gasket_seal | plastic_housing | control_board | none
  severity           INT64,    -- 1 (cosmetic) .. 5 (safety hazard)
  summary            STRING,
  ai_status          STRING,   -- empty on success, error details otherwise
  processed_at       TIMESTAMP
);

CREATE OR REPLACE PROCEDURE `mfg_quality_demo.enrich_new_reviews`()
BEGIN
  DECLARE attempts       INT64 DEFAULT 0;
  DECLARE max_attempts   INT64 DEFAULT 3;
  DECLARE retryable_rows INT64 DEFAULT 0;

  REPEAT

    -- Drop rows that failed with a RETRYABLE error (quota / rate limit) on a
    -- previous pass — this run's or an earlier scheduled run's — so the
    -- incremental anti-join below selects them again.
    DELETE FROM `mfg_quality_demo.review_insights`
    WHERE ai_status LIKE '%A retryable error occurred%';

    INSERT INTO `mfg_quality_demo.review_insights`
      (review_id, sentiment, is_defect_report, defect_category,
       affected_component, severity, summary, ai_status, processed_at)
    SELECT
      review_id,
      g.sentiment,
      g.is_defect_report,
      g.defect_category,
      g.affected_component,
      g.severity,
      g.summary,
      g.status,
      CURRENT_TIMESTAMP()
    FROM (
      SELECT
        r.review_id,
        AI.GENERATE(
          prompt => CONCAT(
            'You are a quality engineer at NovaHome Appliances, a consumer appliance manufacturer. ',
            'Analyze this customer review of the product "', p.product_name, '" (category: ', p.category, ').\n',
            'Rules:\n',
            '- sentiment: one of positive, neutral, negative.\n',
            '- is_defect_report: true only if the review describes a malfunction or physical defect of the product itself. ',
            'Shipping damage, packaging, price, noise levels within normal operation, app/software issues and personal preferences are NOT product defects.\n',
            '- defect_category: one of heating, motor, leak_seal, electronics, housing_cosmetic, none.\n',
            '- affected_component: your best hypothesis for the physical component at fault: ',
            'heating_element, thermostat, motor, gasket_seal, plastic_housing, control_board, or none.\n',
            '- severity: 1 (cosmetic) to 5 (safety hazard or total failure); use 1 when there is no defect.\n',
            '- summary: one factual sentence a quality engineer can act on.\n\n',
            'Review: """', r.review_text, '"""'),
          connection_id => 'eu.vertex_ai_conn',
          endpoint      => 'gemini-3.8-flash',
          output_schema => 'sentiment STRING, is_defect_report BOOL, defect_category STRING, affected_component STRING, severity INT64, summary STRING'
        ) AS g
      FROM `mfg_quality_demo.product_reviews` AS r
      JOIN `mfg_quality_demo.products` AS p USING (sku)
      -- incremental: only reviews that have not been analyzed yet
      LEFT JOIN `mfg_quality_demo.review_insights` AS i USING (review_id)
      WHERE i.review_id IS NULL
    );

    SET attempts = attempts + 1;
    SET retryable_rows = (
      SELECT COUNT(*)
      FROM `mfg_quality_demo.review_insights`
      WHERE ai_status LIKE '%A retryable error occurred%');

  UNTIL retryable_rows = 0 OR attempts >= max_attempts
  END REPEAT;
END;

-- Run one enrichment pass now (subsequent calls only process new reviews)
CALL `mfg_quality_demo.enrich_new_reviews`();

-- Monitoring: rows the AI could not analyze after all retries (empty = all good).
-- Rows still marked retryable here exhausted max_attempts and will be retried
-- automatically on the next scheduled run.
SELECT review_id, ai_status
FROM `mfg_quality_demo.review_insights`
WHERE ai_status IS NOT NULL AND ai_status != '';
