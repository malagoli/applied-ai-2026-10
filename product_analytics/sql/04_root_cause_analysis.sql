-- =============================================================================
-- Step 4: root-cause analysis — trace AI-extracted defects back to
--         component lots and factory machines
--
-- Run with:  bq query --use_legacy_sql=false --location=US < sql/04_root_cause_analysis.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 4a. Defect rate per component lot.
-- A review "implicates" a lot when the AI-identified affected_component
-- matches the lot's component_type AND that lot was used in the reviewed
-- unit's production batch.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW `mfg_quality_demo.v_component_lot_defect_rates` AS
WITH batch_review_stats AS (
  SELECT
    r.batch_id,
    COUNT(*) AS reviews_total,
    COUNTIF(i.is_defect_report) AS reviews_defect
  FROM `mfg_quality_demo.product_reviews` r
  JOIN `mfg_quality_demo.review_insights` i USING (review_id)
  GROUP BY r.batch_id
),
lot_implications AS (
  SELECT
    bc.lot_id,
    COUNT(*) AS implicating_defect_reviews,
    AVG(i.severity) AS avg_severity,
    ARRAY_AGG(i.summary ORDER BY i.severity DESC LIMIT 3) AS example_findings
  FROM `mfg_quality_demo.review_insights` i
  JOIN `mfg_quality_demo.product_reviews` r USING (review_id)
  JOIN `mfg_quality_demo.batch_components` bc ON bc.batch_id = r.batch_id
  JOIN `mfg_quality_demo.component_lots` cl ON cl.lot_id = bc.lot_id
  WHERE i.is_defect_report
    AND i.affected_component = cl.component_type
  GROUP BY bc.lot_id
)
SELECT
  cl.lot_id,
  cl.component_type,
  cl.supplier,
  cl.installed_by_machine_id,
  SUM(brs.reviews_total) AS reviews_on_batches_using_lot,
  COALESCE(ANY_VALUE(li.implicating_defect_reviews), 0) AS implicating_defect_reviews,
  ROUND(COALESCE(ANY_VALUE(li.implicating_defect_reviews), 0) / SUM(brs.reviews_total), 2) AS implication_rate,
  ROUND(COALESCE(ANY_VALUE(li.avg_severity), 0), 1) AS avg_severity,
  ANY_VALUE(li.example_findings) AS example_findings
FROM `mfg_quality_demo.component_lots` cl
JOIN `mfg_quality_demo.batch_components` bc USING (lot_id)
JOIN batch_review_stats brs USING (batch_id)
LEFT JOIN lot_implications li ON li.lot_id = cl.lot_id
GROUP BY cl.lot_id, cl.component_type, cl.supplier, cl.installed_by_machine_id;

SELECT * EXCEPT(example_findings)
FROM `mfg_quality_demo.v_component_lot_defect_rates`
ORDER BY implication_rate DESC, implicating_defect_reviews DESC;

-- ---------------------------------------------------------------------------
-- 4b. Roll up to the machine that installed/processed each lot:
--     which machine's output correlates with customer-reported defects?
-- ---------------------------------------------------------------------------
SELECT
  m.machine_id,
  m.machine_name,
  m.production_line,
  m.last_maintenance_date,
  SUM(v.implicating_defect_reviews) AS defect_reviews_traced_to_machine,
  SUM(v.reviews_on_batches_using_lot) AS total_reviews_exposed,
  ROUND(SUM(v.implicating_defect_reviews) / SUM(v.reviews_on_batches_using_lot), 2) AS machine_implication_rate,
  STRING_AGG(DISTINCT v.lot_id ORDER BY v.lot_id) AS lots_processed
FROM `mfg_quality_demo.v_component_lot_defect_rates` v
JOIN `mfg_quality_demo.machines` m
  ON m.machine_id = v.installed_by_machine_id
GROUP BY m.machine_id, m.machine_name, m.production_line, m.last_maintenance_date
ORDER BY machine_implication_rate DESC;

-- ---------------------------------------------------------------------------
-- 4c. Control check: same component type, different lots.
--     HE-4471 vs HE-4472/HE-4398 isolates the lot (and the machine that
--     calibrated it) from the design of the product itself.
-- ---------------------------------------------------------------------------
SELECT
  v.lot_id,
  v.supplier,
  v.installed_by_machine_id AS calibrated_on,
  v.reviews_on_batches_using_lot,
  v.implicating_defect_reviews,
  v.implication_rate
FROM `mfg_quality_demo.v_component_lot_defect_rates` v
WHERE v.component_type = 'heating_element'
ORDER BY v.implication_rate DESC;
