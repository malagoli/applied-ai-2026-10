-- =============================================================================
-- Step 6 (live demo): simulate new reviews arriving from the review ingestion
-- feed. They will be picked up asynchronously by the scheduled query, or you
-- can trigger the pipeline immediately with:
--   CALL `mfg_quality_demo.enrich_new_reviews`();
--
-- Run with:  bq query --use_legacy_sql=false --location=EU < sql/06_simulate_new_reviews.sql
-- =============================================================================

INSERT INTO `mfg_quality_demo.product_reviews` VALUES
  ('R-0061', 'KTL-200', 'B-2507-05', CURRENT_DATE(), 1, 'amazon',
   'Just stopped heating this morning, 18 days after purchase. Cold water, blinking light, error E4. Same story as the other reviews here — how is this still being sold?'),
  ('R-0062', 'TST-140', 'B-2507-06', CURRENT_DATE(), 5, 'app',
   'Perfect toaster, browning is even and the defrost mode is genuinely useful. Zero issues after six weeks.'),
  ('R-0063', 'CM-350', 'B-2507-08', CURRENT_DATE(), 2, 'support_email',
   'Water leaks from under the machine after every brew, started in week two. Serial NB-B250710-1104. Requesting a warranty replacement.');

-- Show pipeline backlog: reviews waiting for AI analysis
SELECT r.review_id, r.sku, r.review_date, LEFT(r.review_text, 60) AS snippet
FROM `mfg_quality_demo.product_reviews` r
LEFT JOIN `mfg_quality_demo.review_insights` i USING (review_id)
WHERE i.review_id IS NULL;
