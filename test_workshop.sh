#!/usr/bin/env bash
# =============================================================================
# Automated End-to-End Validation Suite for Applied AI & Data Hackathon Labs
# Target Environment: Active GCP Project (Location: US)
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null || echo "")}"
LOCATION="US"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "❌ Error: No active GCP project found. Run 'gcloud config set project <PROJECT_ID>' or pass it as argument 1."
  exit 1
fi

echo "============================================================================="
echo "🧪 Starting End-to-End Validation Suite"
echo "   Project ID : ${PROJECT_ID}"
echo "   Location   : ${LOCATION}"
echo "============================================================================="

echo ""
echo "▶ [Test 1/11] Checking Vertex AI Cloud Resource Connection..."
bq show --connection "${PROJECT_ID}.${LOCATION}.vertex_ai_conn" > /dev/null
echo "  ✅ Connection ${PROJECT_ID}.${LOCATION}.vertex_ai_conn is ACTIVE."

echo ""
echo "▶ [Test 2/11] Validating Lab I (retail_fraud) Property Graph & Ring Detection..."
RINGS_COUNT=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet \
  "SELECT COUNT(*) FROM \`retail_fraud.suspicious_rings\`;" | tail -n 1)
if [[ "${RINGS_COUNT}" -eq 3 ]]; then
  echo "  ✅ Lab I Property Graph detected exactly ${RINGS_COUNT} fraud rings (Ground Truth matched)."
else
  echo "  ❌ Expected 3 fraud rings, found ${RINGS_COUNT}!"
  exit 1
fi

echo ""
echo "▶ [Test 3/11] Validating Lab I Incremental Batch Scoring on Simulated Returns (return_id >= 6000000)..."
SIM_SCORED=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet \
  "SELECT COUNTIF(return_id >= 6000000 AND is_suspicious) FROM \`retail_fraud.returns_scored\`;" | tail -n 1)
if [[ "${SIM_SCORED}" -ge 8 ]]; then
  echo "  ✅ Lab I Incremental Batch Scoring prioritized and flagged ${SIM_SCORED}/10 simulated fraud returns."
else
  echo "  ❌ Expected >= 8 flagged simulated returns, found ${SIM_SCORED}!"
  exit 1
fi

echo ""
echo "▶ [Test 4/11] Validating Lab I Enhancement: TimesFM 3.0 Anomaly Detection (AI.DETECT_ANOMALIES)..."
ANOMALIES_COUNT=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH weekly_returns AS (
  SELECT DATE_TRUNC(return_date, WEEK) AS week_start, ROUND(SUM(refund_amount), 2) AS weekly_refund_eur
  FROM \`retail_fraud.returns\` GROUP BY 1
)
SELECT COUNT(*) FROM AI.DETECT_ANOMALIES(
  (SELECT * FROM weekly_returns WHERE week_start < '2025-09-01'),
  (SELECT * FROM weekly_returns WHERE week_start BETWEEN '2025-09-01' AND '2026-01-31'),
  data_col => 'weekly_refund_eur', timestamp_col => 'week_start', model => 'TimesFM 3.0', anomaly_prob_threshold => 0.80
) WHERE is_anomaly = TRUE;" | tail -n 1)
if [[ "${ANOMALIES_COUNT}" -ge 1 ]]; then
  echo "  ✅ TimesFM 3.0 (AI.DETECT_ANOMALIES) successfully flagged ${ANOMALIES_COUNT} anomalous refund weeks in Q4/Q1."
else
  echo "  ❌ TimesFM 3.0 did not detect expected anomalies!"
  exit 1
fi

echo ""
echo "▶ [Test 5/11] Validating Lab I Enhancement: TimesFM 3.0 Multivariate Forecasting (AI.FORECAST) & Evaluation (AI.EVALUATE)..."
FORECAST_ROWS=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH weekly_multivariate AS (
  SELECT DATE_TRUNC(return_date, WEEK) AS week_start,
         CAST(ROUND(SUM(refund_amount), 2) AS FLOAT64) AS weekly_refund_eur,
         CAST(COUNT(*) AS FLOAT64) AS return_count
  FROM \`retail_fraud.returns\` WHERE return_date < '2026-06-01' GROUP BY 1
)
SELECT COUNT(*) FROM AI.FORECAST(
  TABLE weekly_multivariate, model => 'TimesFM 3.0', timestamp_col => 'week_start',
  target_cols => ['weekly_refund_eur', 'return_count'], horizon => 4
);" | tail -n 1)
MAPE_VAL=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH weekly_returns AS (
  SELECT DATE_TRUNC(return_date, WEEK) AS week_start, ROUND(SUM(refund_amount), 2) AS weekly_refund_eur
  FROM \`retail_fraud.returns\` GROUP BY 1
)
SELECT ROUND(mean_absolute_percentage_error, 2) FROM AI.EVALUATE(
  (SELECT * FROM weekly_returns WHERE week_start < '2025-06-01'),
  (SELECT * FROM weekly_returns WHERE week_start BETWEEN '2025-06-01' AND '2025-08-31'),
  data_col => 'weekly_refund_eur', timestamp_col => 'week_start', model => 'TimesFM 3.0'
);" | tail -n 1)
if [[ "${FORECAST_ROWS}" -eq 4 && -n "${MAPE_VAL}" ]]; then
  echo "  ✅ TimesFM 3.0 Multivariate AI.FORECAST (${FORECAST_ROWS} weeks) & AI.EVALUATE (MAPE=${MAPE_VAL}%) succeeded."
else
  echo "  ❌ TimesFM 3.0 AI.FORECAST / AI.EVALUATE validation failed!"
  exit 1
fi

echo ""
echo "▶ [Test 6/11] Validating Lab I Enhancement: Managed AI.SCORE & AI.SIMILARITY..."
TOP_SCORE=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
SELECT ROUND(AI.SCORE(
  ('Rate chargeback threat severity from 1 to 5: ', return_reason_text, ' | ', agent_notes),
  connection_id => 'us.vertex_ai_conn'
), 1) AS score
FROM \`retail_fraud.returns\` WHERE return_id IN (5920001, 5000001) ORDER BY score DESC LIMIT 1;" | tail -n 1)
TOP_SIM=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
SELECT ROUND(AI.SIMILARITY(
  content1 => return_reason_text,
  content2 => 'Package never arrived despite carrier tracking showing delivered. Demanding immediate refund.',
  connection_id => 'us.vertex_ai_conn', endpoint => 'text-embedding-005'
), 3) AS sim
FROM \`retail_fraud.returns\` WHERE return_id = 5920011;" | tail -n 1)
echo "  ✅ AI.SCORE (top escalation score=${TOP_SCORE}) & AI.SIMILARITY (cosine similarity=${TOP_SIM}) succeeded."

echo ""
echo "▶ [Test 7/11] Validating Lab II (mfg_quality_demo) Root-Cause BOM View..."
TOP_LOT=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet \
  "SELECT lot_id FROM \`mfg_quality_demo.v_component_lot_defect_rates\` ORDER BY implicating_defect_reviews DESC LIMIT 1;" | tail -n 1)
if [[ "${TOP_LOT}" == "HE-4471" ]]; then
  echo "  ✅ Lab II BOM Root-Cause analysis accurately isolated suspect lot: ${TOP_LOT} (Station CAL-02)."
else
  echo "  ❌ Expected top suspect lot HE-4471, got ${TOP_LOT}!"
  exit 1
fi

echo ""
echo "▶ [Test 8/11] Validating Lab II Enhancement: Automated Contribution Analysis (AI.KEY_DRIVERS)..."
TOP_DRIVER=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH review_bom_joined AS (
  SELECT cl.component_type, cl.supplier, IF(i.is_defect_report, 1.0, 0.0) AS defect_metric,
         (cl.installed_by_machine_id = 'CAL-02') AS is_cal02
  FROM \`mfg_quality_demo.review_insights\` i
  JOIN \`mfg_quality_demo.product_reviews\` r USING (review_id)
  JOIN \`mfg_quality_demo.batch_components\` bc USING (batch_id)
  JOIN \`mfg_quality_demo.component_lots\` cl USING (lot_id)
)
SELECT TO_JSON_STRING(drivers) FROM AI.KEY_DRIVERS(
  TABLE review_bom_joined, metric_col => 'defect_metric',
  dimension_cols => ['component_type', 'supplier'], interest_label_col => 'is_cal02', top_k => 3
) ORDER BY relative_difference DESC LIMIT 1;" | tail -n 1)
echo "  ✅ AI.KEY_DRIVERS identified top statistically significant driver: ${TOP_DRIVER}"

echo ""
echo "▶ [Test 9/11] Validating Lab II Enhancement: Semantic Join (JOIN ... ON AI.IF)..."
SEMANTIC_MATCHES=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH bulletins AS (
  SELECT 'TB-2025-01' AS bulletin_id, 'Thermal calibration drift causing water to stop heating around 70C' AS symptom
),
reviews AS (
  SELECT review_id, review_text FROM \`mfg_quality_demo.product_reviews\` WHERE review_id IN ('R-0005', 'R-0041')
)
SELECT COUNT(*) FROM bulletins b JOIN reviews r
  ON AI.IF(('Does this review match the bulletin symptom? Review: ', r.review_text, ' Bulletin: ', b.symptom), connection_id => 'us.vertex_ai_conn');" | tail -n 1)
if [[ "${SEMANTIC_MATCHES}" -ge 1 ]]; then
  echo "  ✅ Semantic JOIN ON AI.IF matched ${SEMANTIC_MATCHES} engineering bulletin(s) to unstructured customer reviews."
else
  echo "  ❌ Semantic JOIN ON AI.IF returned 0 matches!"
  exit 1
fi

echo ""
echo "▶ [Test 10/11] Validating Lab II Enhancement: TimesFM 3.0 Anomaly Detection & Multivariate Forecast..."
LAB2_ANOMALIES=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH daily_defects AS (
  SELECT r.review_date, CAST(COUNTIF(i.is_defect_report) AS FLOAT64) AS defect_count
  FROM \`mfg_quality_demo.product_reviews\` r
  JOIN \`mfg_quality_demo.review_insights\` i USING (review_id)
  WHERE r.review_date <= '2025-08-15' GROUP BY 1
)
SELECT COUNT(*) FROM AI.DETECT_ANOMALIES(
  (SELECT * FROM daily_defects WHERE review_date < '2025-07-25'),
  (SELECT * FROM daily_defects WHERE review_date >= '2025-07-25'),
  data_col => 'defect_count', timestamp_col => 'review_date', model => 'TimesFM 3.0', anomaly_prob_threshold => 0.70
) WHERE is_anomaly = TRUE;" | tail -n 1)
LAB2_FORECAST=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet "
WITH daily_quality_metrics AS (
  SELECT r.review_date,
         CAST(COUNTIF(i.is_defect_report) AS FLOAT64) AS defect_count,
         CAST(ROUND(AVG(IFNULL(i.severity, 0)), 2) AS FLOAT64) AS avg_severity,
         CAST(COUNT(*) AS FLOAT64) AS total_reviews
  FROM \`mfg_quality_demo.product_reviews\` r
  JOIN \`mfg_quality_demo.review_insights\` i USING (review_id)
  WHERE r.review_date <= '2025-08-15' GROUP BY 1
)
SELECT COUNT(*) FROM AI.FORECAST(
  TABLE daily_quality_metrics, model => 'TimesFM 3.0', timestamp_col => 'review_date',
  target_cols => ['defect_count', 'avg_severity'], past_covariate_cols => ['total_reviews'], horizon => 5
);" | tail -n 1)
if [[ "${LAB2_ANOMALIES}" -ge 1 && "${LAB2_FORECAST}" -eq 5 ]]; then
  echo "  ✅ Lab II TimesFM 3.0 AI.DETECT_ANOMALIES (${LAB2_ANOMALIES} spike days) & Multivariate AI.FORECAST (${LAB2_FORECAST} days) succeeded."
else
  echo "  ❌ Lab II TimesFM 3.0 validation failed!"
  exit 1
fi

echo ""
echo "▶ [Test 11/11] Validating Lab II Incremental Review Enrichment (R-0061..R-0063) & Lab I Fraud Dashboard..."
ENRICHED_SIM_COUNT=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet \
  "SELECT COUNT(*) FROM \`mfg_quality_demo.review_insights\` WHERE review_id IN ('R-0061', 'R-0062', 'R-0063') AND ai_status = '';" | tail -n 1)
DASHBOARD_COUNT=$(bq query --project_id="${PROJECT_ID}" --location="${LOCATION}" --use_legacy_sql=false --format=csv --quiet \
  "SELECT COUNT(*) FROM \`retail_fraud.fraud_dashboard\`;" | tail -n 1)
if [[ "${ENRICHED_SIM_COUNT}" -eq 3 && "${DASHBOARD_COUNT}" -eq 3 ]]; then
  echo "  ✅ Lab II Incremental Review Enrichment (${ENRICHED_SIM_COUNT}/3 simulated reviews) & Lab I Fraud Dashboard (${DASHBOARD_COUNT} rings) verified."
else
  echo "  ❌ Expected 3 enriched simulated reviews & 3 dashboard rings, got ${ENRICHED_SIM_COUNT} and ${DASHBOARD_COUNT}!"
  exit 1
fi

echo ""
echo "============================================================================="
echo "🎉 ALL 11 END-TO-END TESTS PASSED (${PROJECT_ID})!"
echo "============================================================================="
