-- =============================================================================
-- Step 2 (ad-hoc showcase): quick triage & semantic ranking with scalar AI
--                           functions, cost-optimized where BigQuery supports it
--
-- 2a. AI.IF       — is this review reporting a product defect?      (BOOL)
--     AI.CLASSIFY — which defect category does it fall into?        (STRING)
--     AI.GENERATE_INT — how severe is it on a 1–5 scale?            (INT64)
-- 2b. AI.SCORE    — rank reviews by physical safety hazard urgency  (FLOAT64)
--
-- Cost optimization (https://docs.cloud.google.com/bigquery/docs/optimize-ai-functions):
-- AI.IF and AI.CLASSIFY accept optimization_mode => 'MINIMIZE_COST'. BigQuery
-- then labels a sample of rows with the LLM, trains a lightweight *distilled*
-- model on text embeddings of the input, validates its quality against the
-- LLM answers, and serves most rows from the distilled model instead of
-- calling Gemini per row. Requirements / caveats:
--   * needs ~3,000+ rows before distillation kicks in — below that (like this
--     demo table) every row transparently falls back to the LLM, same results;
--   * do NOT pass an explicit endpoint — the optimizer manages model choice
--     (endpoint + optimization_mode together is a query error);
--   * embeddings are computed autonomously by BigQuery, or you can pass your
--     own via the embeddings => argument;
--   * Preview feature; AI.GENERATE_INT below has no optimized mode yet.
--
-- Run with:  bq query --use_legacy_sql=false --location=EU < sql/02_quick_triage.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2a. Cost-Optimized Triage: AI.IF + AI.CLASSIFY + AI.GENERATE_INT
-- -----------------------------------------------------------------------------
SELECT
  r.review_id,
  r.sku,
  r.rating,
  LEFT(r.review_text, 80) AS review_snippet,
  -- optimizable boolean predicate: distilled model answers most rows at scale
  AI.IF(
    ('Does this product review describe a malfunction or physical defect of the product itself (not shipping, packaging, price or personal preference)? Review: ', r.review_text),
    connection_id     => 'eu.vertex_ai_conn',
    optimization_mode => 'MINIMIZE_COST'
  ) AS is_defect_report,
  -- optimizable single-label classification
  AI.CLASSIFY(
    r.review_text,
    categories        => ['heating', 'motor', 'leak_seal', 'electronics', 'housing_cosmetic', 'none'],
    connection_id     => 'eu.vertex_ai_conn',
    optimization_mode => 'MINIMIZE_COST'
  ) AS defect_category,
  -- free-form numeric extraction: no optimized mode, always a direct LLM call
  AI.GENERATE_INT(
    ('Rate the severity of the problem described in this review from 1 (cosmetic/no problem) to 5 (safety hazard or total failure). Review: ', r.review_text),
    connection_id => 'eu.vertex_ai_conn',
    endpoint      => 'gemini-3.8-flash'
  ).result AS severity
FROM `mfg_quality_demo.product_reviews` AS r
ORDER BY r.review_id
LIMIT 10;

-- -----------------------------------------------------------------------------
-- 2b. Semantic Priority Ranking with AI.SCORE in ORDER BY
-- Ranks low-rated customer reviews by immediate physical safety risk (electrical
-- hazard, burning smell, overheating, or water leaking near power outlets).
-- -----------------------------------------------------------------------------
SELECT
  r.review_id,
  r.sku,
  r.batch_id,
  r.rating,
  r.review_text,
  ROUND(
    AI.SCORE(
      ('Urgency of physical safety hazard: electrical fire risk, burning smell, overheating, or water leaking near electrical outlet: ', r.review_text),
      connection_id => 'eu.vertex_ai_conn'
    ),
    2
  ) AS safety_hazard_score
FROM (
  SELECT * FROM `mfg_quality_demo.product_reviews`
  WHERE rating <= 2
  ORDER BY review_id
  LIMIT 15
) AS r
ORDER BY safety_hazard_score DESC
LIMIT 5;
