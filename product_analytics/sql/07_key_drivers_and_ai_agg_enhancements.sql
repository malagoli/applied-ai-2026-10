-- =============================================================================
-- Lab II Enhancement: Automated Contribution Analysis (AI.KEY_DRIVERS),
--                     Multi-Row Aggregation (AI.AGG), Semantic Join (JOIN ON AI.IF),
--                     Semantic Similarity (AI.SIMILARITY) & TimesFM 3.0
--                     (AI.DETECT_ANOMALIES, Multivariate AI.FORECAST, AI.EVALUATE)
--
-- Dimostra come utilizzare:
--   7a. AI.KEY_DRIVERS      — Isola in 0.5s i fattori dimensionali (lotto, fornitore,
--                             linea, macchinario) responsabili dei difetti.
--   7b. AI.AGG              — Riassume i feedback difettosi per SKU dentro GROUP BY.
--   7c. JOIN ON AI.IF       — Esegue un Join Semantico tra Bollettini Tecnici dei
--                             fornitori e recensioni in testo libero senza foreign key.
--   7d. AI.SIMILARITY       — Trova le recensioni storiche semanticamente più simili
--                             a una nuova segnalazione critica.
--   7e. AI.DETECT_ANOMALIES — (TimesFM 3.0) Intercetta il picco giornaliero di reclami
--                             difettosi causato dall'arrivo dei lotti HE-4471.
--   7f. AI.FORECAST         — (TimesFM 3.0 Multivariato) Prevede congiuntamente il
--                             numero di difetti e la severità media con covariate.
--   7g. AI.EVALUATE         — (TimesFM 3.0) Backtesting zero-shot sui difetti giornalieri.
--
-- Eseguire con:
-- bq query --location=US --use_legacy_sql=false < sql/07_key_drivers_and_ai_agg_enhancements.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 7a. AUTOMATED ROOT-CAUSE DISCOVERY: AI.KEY_DRIVERS
-- Confronta il gruppo di interesse (recensioni associate a componenti calibrati
-- sulla stazione sospetta CAL-02) rispetto al resto della fabbrica per scoprire
-- quali segmenti dimensionali trainano l'anomalia dei difetti.
-- -----------------------------------------------------------------------------
WITH review_bom_joined AS (
  SELECT
    cl.component_type,
    cl.supplier,
    cl.installed_by_machine_id AS machine_id,
    pb.production_line,
    p.category AS product_category,
    IF(i.is_defect_report, 1.0, 0.0) AS defect_flag_metric,
    (cl.installed_by_machine_id = 'CAL-02') AS is_station_cal02
  FROM `mfg_quality_demo.review_insights` i
  JOIN `mfg_quality_demo.product_reviews` r USING (review_id)
  JOIN `mfg_quality_demo.products` p USING (sku)
  JOIN `mfg_quality_demo.production_batches` pb USING (batch_id)
  JOIN `mfg_quality_demo.batch_components` bc USING (batch_id)
  JOIN `mfg_quality_demo.component_lots` cl USING (lot_id)
)
SELECT
  drivers AS root_cause_segment,
  ROUND(metric_interest, 1) AS defects_in_segment,
  ROUND(metric_reference, 1) AS defects_in_reference,
  ROUND(relative_difference * 100, 0) AS relative_increase_pct,
  ROUND(apriori_support, 3) AS segment_support
FROM AI.KEY_DRIVERS(
  TABLE review_bom_joined,
  metric_col => 'defect_flag_metric',
  dimension_cols => ['component_type', 'supplier', 'production_line', 'product_category'],
  interest_label_col => 'is_station_cal02',
  top_k => 5
)
ORDER BY relative_difference DESC;

-- -----------------------------------------------------------------------------
-- 7b. MULTI-ROW SEMANTIC AGGREGATION PER SKU: AI.AGG
-- Aggrega direttamente tutte le recensioni difettose per SKU generando un
-- bollettino tecnico per il team R&D senza concatenazioni manuali STRING_AGG.
-- -----------------------------------------------------------------------------
SELECT
  p.sku,
  p.product_name,
  COUNT(*) AS defect_reviews_count,
  AI.AGG(
    STRUCT(CAST(r.rating AS STRING) AS star_rating, r.review_text AS customer_verbatim, i.affected_component AS ai_suspected_part),
    'Sei il Responsabile Qualità di NovaHome Appliances. Riassumi in italiano (max 2 frasi) il sintomo tecnico principale lamentato dai clienti su questo prodotto e indica il componente fisico da ispezionare.',
    connection_id => 'us.vertex_ai_conn',
    endpoint => 'gemini-3.8-flash'
  ) AS rd_technical_digest_it
FROM `mfg_quality_demo.review_insights` i
JOIN `mfg_quality_demo.product_reviews` r USING (review_id)
JOIN `mfg_quality_demo.products` p USING (sku)
WHERE i.is_defect_report = TRUE
GROUP BY p.sku, p.product_name
ORDER BY defect_reviews_count DESC;

-- -----------------------------------------------------------------------------
-- 7c. SEMANTIC JOIN: JOIN ... ON AI.IF(...)
-- Unisce una tabella di Bollettini Tecnici dei Fornitori (engineering_bulletins)
-- direttamente con il testo libero delle recensioni (product_reviews) usando
-- AI.IF come condizione di JOIN relazionale, senza alcuna chiave esterna comune!
-- -----------------------------------------------------------------------------
WITH engineering_bulletins AS (
  SELECT 'TB-2025-01' AS bulletin_id,
         'ThermoCore Heating Element' AS component_family,
         'Thermal calibration drift causing water to stop heating around 70C, lukewarm water, or premature switch click-off' AS bulletin_symptom
  UNION ALL
  SELECT 'TB-2025-02' AS bulletin_id,
         'FlexiSeal Base Gasket' AS component_family,
         'Silicone reservoir gasket deformation causing water pooling or dripping underneath the coffee maker base' AS bulletin_symptom
),
sample_reviews AS (
  SELECT review_id, sku, batch_id, review_text
  FROM `mfg_quality_demo.product_reviews`
  WHERE review_id IN ('R-0001', 'R-0005', 'R-0022', 'R-0024', 'R-0030', 'R-0041')
)
SELECT
  b.bulletin_id,
  b.component_family,
  r.review_id,
  r.sku,
  r.batch_id,
  LEFT(r.review_text, 100) AS matched_review_snippet
FROM engineering_bulletins b
JOIN sample_reviews r
  ON AI.IF(
    ('Does this customer review describe the exact technical failure symptom in the engineering bulletin? Review: ',
     r.review_text, ' | Engineering Bulletin: ', b.bulletin_symptom),
    connection_id => 'us.vertex_ai_conn'
  )
ORDER BY b.bulletin_id, r.review_id;

-- -----------------------------------------------------------------------------
-- 7d. SEMANTIC SIMILARITY SEARCH: AI.SIMILARITY
-- Data una segnalazione critica di mancato riscaldamento, calcola la similarità
-- semantica (cosine similarity con text-embedding-005) per recuperare i reclami
-- gemelli nel dataset senza dipendere da parole chiave esatte.
-- -----------------------------------------------------------------------------
SELECT
  r.review_id,
  r.sku,
  r.batch_id,
  r.rating,
  LEFT(r.review_text, 90) AS review_snippet,
  ROUND(
    AI.SIMILARITY(
      content1 => 'Kettle stopped heating water after two weeks, switch clicks off and water stays cold or lukewarm.',
      content2 => r.review_text,
      connection_id => 'us.vertex_ai_conn',
      endpoint => 'text-embedding-005'
    ),
    3
  ) AS semantic_similarity
FROM `mfg_quality_demo.product_reviews` r
ORDER BY semantic_similarity DESC
LIMIT 6;

-- -----------------------------------------------------------------------------
-- 7e. QUALITY SPIKE DETECTION: TimesFM 3.0 Anomaly Detection (AI.DETECT_ANOMALIES)
-- Intercetta in zero-shot i giorni di fine Luglio / inizio Agosto 2025 in cui le
-- segnalazioni di difetti superano la banda predittiva di TimesFM 3.0 in seguito
-- alla distribuzione dei lotti B-2507-05 e B-2507-10 (lotto HE-4471).
-- -----------------------------------------------------------------------------
WITH daily_defects AS (
  SELECT
    r.review_date,
    CAST(COUNTIF(i.is_defect_report) AS FLOAT64) AS defect_count
  FROM `mfg_quality_demo.product_reviews` r
  JOIN `mfg_quality_demo.review_insights` i USING (review_id)
  WHERE r.review_date <= '2025-08-15'
  GROUP BY 1
)
SELECT
  time_series_timestamp AS review_date,
  time_series_data AS actual_defects,
  ROUND(lower_bound, 2) AS expected_min,
  ROUND(upper_bound, 2) AS expected_max,
  is_anomaly,
  ROUND(anomaly_probability, 3) AS anomaly_prob
FROM AI.DETECT_ANOMALIES(
  (SELECT * FROM daily_defects WHERE review_date < '2025-07-25'),
  (SELECT * FROM daily_defects WHERE review_date >= '2025-07-25'),
  data_col => 'defect_count',
  timestamp_col => 'review_date',
  model => 'TimesFM 3.0',
  anomaly_prob_threshold => 0.70
)
WHERE is_anomaly = TRUE
ORDER BY review_date;

-- -----------------------------------------------------------------------------
-- 7f. MULTIVARIATE QUALITY FORECAST: TimesFM 3.0 (AI.FORECAST con target_cols)
-- Prevede simultaneamente il numero di reclami difettosi giornalieri (defect_count)
-- e la gravità media (avg_severity) per i prossimi 5 giorni usando il volume
-- totale di recensioni (total_reviews) come covariata storica (past_covariate_cols).
-- -----------------------------------------------------------------------------
WITH daily_quality_metrics AS (
  SELECT
    r.review_date,
    CAST(COUNTIF(i.is_defect_report) AS FLOAT64) AS defect_count,
    CAST(ROUND(AVG(IFNULL(i.severity, 0)), 2) AS FLOAT64) AS avg_severity,
    CAST(COUNT(*) AS FLOAT64) AS total_reviews
  FROM `mfg_quality_demo.product_reviews` r
  JOIN `mfg_quality_demo.review_insights` i USING (review_id)
  WHERE r.review_date <= '2025-08-15'
  GROUP BY 1
)
SELECT
  review_date AS predicted_date,
  ROUND(defect_count.value, 2) AS predicted_defects,
  ROUND(defect_count.prediction_interval_upper_bound, 2) AS defects_ci95_upper,
  ROUND(avg_severity.value, 2) AS predicted_avg_severity,
  ROUND(avg_severity.prediction_interval_upper_bound, 2) AS severity_ci95_upper
FROM AI.FORECAST(
  TABLE daily_quality_metrics,
  model => 'TimesFM 3.0',
  timestamp_col => 'review_date',
  target_cols => ['defect_count', 'avg_severity'],
  past_covariate_cols => ['total_reviews'],
  horizon => 5,
  confidence_level => 0.95
)
ORDER BY predicted_date;

-- -----------------------------------------------------------------------------
-- 7g. ZERO-SHOT BACKTESTING: TimesFM 3.0 Accuracy Evaluation (AI.EVALUATE)
-- Valida l'accuratezza zero-shot di TimesFM 3.0 sulla serie storica dei difetti.
-- -----------------------------------------------------------------------------
WITH daily_defects AS (
  SELECT
    r.review_date,
    CAST(COUNTIF(i.is_defect_report) AS FLOAT64) AS defect_count
  FROM `mfg_quality_demo.product_reviews` r
  JOIN `mfg_quality_demo.review_insights` i USING (review_id)
  WHERE r.review_date <= '2025-08-15'
  GROUP BY 1
)
SELECT
  ROUND(mean_absolute_error, 2) AS mae_defects,
  ROUND(root_mean_squared_error, 2) AS rmse_defects,
  ROUND(symmetric_mean_absolute_percentage_error, 2) AS smape_pct,
  ai_evaluate_status
FROM AI.EVALUATE(
  (SELECT * FROM daily_defects WHERE review_date < '2025-07-25'),
  (SELECT * FROM daily_defects WHERE review_date >= '2025-07-25'),
  data_col => 'defect_count',
  timestamp_col => 'review_date',
  model => 'TimesFM 3.0'
);
