-- =============================================================================
-- Phase 3b / Phase 4: ASYNCHRONOUS AI scoring pipeline with Quota Retry Loop.
-- Incremental pattern: each run scores ONLY returns not yet in returns_scored,
-- newest first, in bounded batches of 20 (demo) / 500 (production).
--
-- Production Hardening (aligned with Lab II):
--   1. Quota-error resilience: wraps batch scoring in a bounded REPEAT loop that
--      automatically retries rows failing with 'A retryable error occurred'
--      without re-billing successful rows.
--   2. Cost Optimization showcase: includes AI.IF with optimization_mode =>
--      'MINIMIZE_COST' alongside AI.GENERATE_BOOL.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `retail_fraud.returns_scored` (
  return_id INT64,
  order_id INT64,
  customer_id INT64,
  is_suspicious BOOL,
  ai_status STRING,
  scored_at TIMESTAMP
);

CREATE OR REPLACE PROCEDURE `retail_fraud.score_new_returns_batch`()
BEGIN
  DECLARE attempts INT64 DEFAULT 0;
  DECLARE max_attempts INT64 DEFAULT 3;
  DECLARE retryable_rows INT64 DEFAULT 0;

  REPEAT
    -- Drop rows that failed with a retryable error (429 quota/rate limit) on a previous pass
    DELETE FROM `retail_fraud.returns_scored`
    WHERE ai_status LIKE '%A retryable error occurred%';

    INSERT INTO `retail_fraud.returns_scored`
      (return_id, order_id, customer_id, is_suspicious, ai_status, scored_at)
    SELECT
      return_id,
      order_id,
      customer_id,
      ai.result AS is_suspicious,
      ai.status AS ai_status,
      CURRENT_TIMESTAMP() AS scored_at
    FROM (
      SELECT
        b.return_id,
        b.order_id,
        b.customer_id,
        -- Note: For large-scale cost distillation (>3,000 rows), you can also use:
        -- AI.IF(('Is this return fraudulent? ', b.return_reason_text, b.agent_notes),
        --       connection_id => 'eu.vertex_ai_conn', optimization_mode => 'MINIMIZE_COST')
        AI.GENERATE_BOOL(
          prompt => CONCAT(
            'You are a retail returns-abuse analyst. Based on the customer return reason ',
            'and the agent notes, decide if this return shows signs of return fraud or abuse ',
            '(wardrobing / wear-and-return, false item-not-received claims, loyalty points ',
            'cycling, scripted or coordinated behavior). Answer true ONLY for clear abuse ',
            'signals; ordinary sizing, preference or damaged-in-transit returns are false. ',
            'Return reason: "', b.return_reason_text, '" | Agent notes: "', b.agent_notes, '"'),
          connection_id => 'eu.vertex_ai_conn',
          endpoint => 'gemini-3.8-flash'
        ) AS ai
      FROM (
        SELECT r.*
        FROM `retail_fraud.returns` r
        WHERE NOT EXISTS (
          SELECT 1 FROM `retail_fraud.returns_scored` s
          WHERE s.return_id = r.return_id
        )
        ORDER BY (r.return_id >= 6000000) DESC, (r.customer_id >= 9000) DESC, r.return_id DESC   -- prioritize live-simulated returns, suspect ring accounts & newest
        LIMIT 20                                                                                 -- bounded demo batch per run
      ) b
    );

    SET attempts = attempts + 1;
    SET retryable_rows = (
      SELECT COUNT(*)
      FROM `retail_fraud.returns_scored`
      WHERE ai_status LIKE '%A retryable error occurred%'
    );
  UNTIL retryable_rows = 0 OR attempts >= max_attempts
  END REPEAT;
END;

-- Run one incremental batch pass now
CALL `retail_fraud.score_new_returns_batch`();
