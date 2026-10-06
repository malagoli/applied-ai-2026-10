-- =============================================================================
-- Lab I Enhancement: TimesFM 3.0 (AI.DETECT_ANOMALIES, AI.FORECAST, AI.EVALUATE)
--                    + Managed GenAI (AI.AGG, AI.SCORE, AI.SIMILARITY)
--
-- Dimostra come integrare i Foundation Model per serie storiche (TimesFM 3.0,
-- incluso il forecasting multivariato con target_cols) e le nuove funzioni AI
-- gestite di BigQuery (AI.AGG, AI.SCORE, AI.SIMILARITY) nel caso d'uso Retail.
--
-- Eseguire con:
-- bq query --location=US --use_legacy_sql=false < sql/13_timesfm_and_ai_agg_enhancements.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 13a. MACRO ALERT: TimesFM 3.0 Anomaly Detection (AI.DETECT_ANOMALIES)
-- Rileva automaticamente (zero-shot, senza training) il picco anomalo di
-- rimborsi settimanali innescato dall'entrata in azione del Ring C (Nov 2025).
-- -----------------------------------------------------------------------------
WITH weekly_returns AS (
  SELECT
    DATE_TRUNC(return_date, WEEK) AS week_start,
    ROUND(SUM(refund_amount), 2) AS weekly_refund_eur,
    COUNT(*) AS return_count
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  time_series_timestamp AS week_start,
  time_series_data AS actual_refund_eur,
  ROUND(lower_bound, 0) AS expected_min_eur,
  ROUND(upper_bound, 0) AS expected_max_eur,
  is_anomaly,
  ROUND(anomaly_probability, 3) AS anomaly_probability
FROM AI.DETECT_ANOMALIES(
  -- Storico di baseline (Gennaio - Agosto 2025: pre-attacco Ring C)
  (SELECT * FROM weekly_returns WHERE week_start < '2025-09-01'),
  -- Finestra di ispezione (Settembre 2025 - Gennaio 2026)
  (SELECT * FROM weekly_returns WHERE week_start BETWEEN '2025-09-01' AND '2026-01-31'),
  data_col => 'weekly_refund_eur',
  timestamp_col => 'week_start',
  model => 'TimesFM 3.0',
  anomaly_prob_threshold => 0.80
)
WHERE is_anomaly = TRUE
ORDER BY week_start;

-- -----------------------------------------------------------------------------
-- 13b. RISK EXPOSURE FORECAST: TimesFM 3.0 Univariate & Multivariate (AI.FORECAST)
-- Proietta l'esposizione finanziaria settimanale dei rimborsi per le prossime
-- 8 settimane (univariata con data_col e multivariata con target_cols).
-- -----------------------------------------------------------------------------
WITH weekly_returns AS (
  SELECT
    DATE_TRUNC(return_date, WEEK) AS week_start,
    ROUND(SUM(refund_amount), 2) AS weekly_refund_eur
  FROM `retail_fraud.returns`
  WHERE return_date < '2026-06-01'
  GROUP BY 1
)
SELECT
  forecast_timestamp AS predicted_week,
  ROUND(forecast_value, 2) AS predicted_refund_eur,
  ROUND(prediction_interval_lower_bound, 2) AS ci_95_lower_eur,
  ROUND(prediction_interval_upper_bound, 2) AS ci_95_upper_eur
FROM AI.FORECAST(
  TABLE weekly_returns,
  data_col => 'weekly_refund_eur',
  timestamp_col => 'week_start',
  model => 'TimesFM 3.0',
  horizon => 8,
  confidence_level => 0.95
)
ORDER BY predicted_week;

-- 13b-bis. NOVITÀ ESCLUSIVA TimesFM 3.0: Forecasting Multivariato (target_cols)
-- Prevede simultaneamente sia l'esposizione in € (weekly_refund_eur) sia il
-- volume di pacchi resi (return_count) in una singola chiamata zero-shot.
WITH weekly_multivariate AS (
  SELECT
    DATE_TRUNC(return_date, WEEK) AS week_start,
    CAST(ROUND(SUM(refund_amount), 2) AS FLOAT64) AS weekly_refund_eur,
    CAST(COUNT(*) AS FLOAT64) AS return_count
  FROM `retail_fraud.returns`
  WHERE return_date < '2026-06-01'
  GROUP BY 1
)
SELECT
  week_start AS predicted_week,
  ROUND(weekly_refund_eur.value, 2) AS predicted_refund_eur,
  ROUND(weekly_refund_eur.prediction_interval_upper_bound, 2) AS refund_ci95_upper_eur,
  ROUND(return_count.value, 1) AS predicted_return_packages,
  ROUND(return_count.prediction_interval_upper_bound, 1) AS packages_ci95_upper
FROM AI.FORECAST(
  TABLE weekly_multivariate,
  model => 'TimesFM 3.0',
  timestamp_col => 'week_start',
  target_cols => ['weekly_refund_eur', 'return_count'],
  horizon => 4,
  confidence_level => 0.95
)
ORDER BY predicted_week;

-- -----------------------------------------------------------------------------
-- 13c. ZERO-SHOT BACKTESTING: TimesFM 3.0 Accuracy Evaluation (AI.EVALUATE)
-- Valida in zero-shot l'accuratezza di TimesFM 3.0 confrontando lo storico di
-- training (Gen-Mag 2025) con i dati reali pre-attacco (Giu-Ago 2025),
-- calcolando automaticamente MAE, RMSE e MAPE (14.49%) senza CREATE MODEL.
-- -----------------------------------------------------------------------------
WITH weekly_returns AS (
  SELECT
    DATE_TRUNC(return_date, WEEK) AS week_start,
    ROUND(SUM(refund_amount), 2) AS weekly_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  ROUND(mean_absolute_error, 2) AS mae_eur,
  ROUND(root_mean_squared_error, 2) AS rmse_eur,
  ROUND(mean_absolute_percentage_error, 2) AS mape_pct,
  ROUND(symmetric_mean_absolute_percentage_error, 2) AS smape_pct,
  ai_evaluate_status
FROM AI.EVALUATE(
  (SELECT * FROM weekly_returns WHERE week_start < '2025-06-01'),
  (SELECT * FROM weekly_returns WHERE week_start BETWEEN '2025-06-01' AND '2025-08-31'),
  data_col => 'weekly_refund_eur',
  timestamp_col => 'week_start',
  model => 'TimesFM 3.0'
);

-- -----------------------------------------------------------------------------
-- 13d. SEMANTIC RING PROFILING: Multi-Row Aggregation (AI.AGG)
-- Sostituisce la concatenazione manuale (STRING_AGG) aggregando direttamente
-- i campi testuali (motivo reso + note operatore) all'interno della GROUP BY ring_id.
-- Nota: assicura in modo idempotente che `retail_fraud.suspicious_rings` esista
-- anche se questo script viene eseguito allo Step 2 prima di `04_ring_detection.sql`.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `retail_fraud.suspicious_rings` AS
WITH cust_stats AS (
  SELECT o.customer_id,
         COUNT(DISTINCT o.order_id) AS n_orders,
         COUNT(DISTINCT r.return_id) AS n_returns,
         SAFE_DIVIDE(COUNT(DISTINCT r.return_id), COUNT(DISTINCT o.order_id)) AS return_rate,
         ROUND(SUM(IFNULL(r.refund_amount, 0)), 2) AS total_refunds
  FROM `retail_fraud.orders` o
  LEFT JOIN `retail_fraud.returns` r USING (order_id)
  GROUP BY 1
),
shared AS (
  SELECT 'device' AS entity_type, CAST(device_id AS STRING) AS entity_id, customer_id FROM `retail_fraud.customer_devices` UNION ALL
  SELECT 'address', CAST(address_id AS STRING), customer_id FROM `retail_fraud.customer_addresses` UNION ALL
  SELECT 'payment_method', CAST(payment_method_id AS STRING), customer_id FROM `retail_fraud.customer_payments`
),
flagged AS (
  SELECT s.entity_type, s.entity_id, s.customer_id
  FROM shared s
  JOIN cust_stats cs USING (customer_id)
  WHERE cs.return_rate >= 0.4 AND cs.n_returns >= 3
),
grp AS (
  SELECT entity_type, entity_id,
         ARRAY_AGG(DISTINCT customer_id ORDER BY customer_id) AS members
  FROM flagged
  GROUP BY 1, 2
  HAVING COUNT(DISTINCT customer_id) >= 3
),
merged AS (
  SELECT TO_JSON_STRING(members) AS member_key,
         ANY_VALUE(members) AS members,
         ARRAY_AGG(STRUCT(entity_type, entity_id)) AS shared_entities
  FROM grp
  GROUP BY 1
)
SELECT
  CONCAT('RING-', CAST(ROW_NUMBER() OVER (ORDER BY member_key) AS STRING)) AS ring_id,
  m.members,
  ARRAY_LENGTH(m.members) AS n_members,
  m.shared_entities,
  (SELECT SUM(cs.n_returns) FROM cust_stats cs WHERE cs.customer_id IN UNNEST(m.members)) AS total_returns,
  (SELECT ROUND(AVG(cs.return_rate), 2) FROM cust_stats cs WHERE cs.customer_id IN UNNEST(m.members)) AS avg_return_rate,
  (SELECT ROUND(SUM(cs.total_refunds), 2) FROM cust_stats cs WHERE cs.customer_id IN UNNEST(m.members)) AS refund_exposure
FROM merged m;

SELECT
  sr.ring_id,
  sr.n_members,
  sr.refund_exposure AS refund_exposure_eur,
  AI.AGG(
    STRUCT(r.return_reason_text AS customer_claim, r.agent_notes AS support_agent_observation),
    'Agisci come Senior Fraud Investigator. Sintetizza in 2 frasi in italiano il Modus Operandi comune emergente da questi resi e indica 1 azione immediata di mitigazione.',
    connection_id => 'us.vertex_ai_conn',
    endpoint => 'gemini-3.8-flash'
  ) AS ai_agg_modus_operandi_it
FROM `retail_fraud.suspicious_rings` sr,
UNNEST(sr.members) AS customer_id
JOIN `retail_fraud.returns` r USING (customer_id)
GROUP BY sr.ring_id, sr.n_members, sr.refund_exposure
ORDER BY sr.refund_exposure DESC;

-- -----------------------------------------------------------------------------
-- 13e. SEMANTIC ESCALATION RANKING: Ranking in Natural Language (AI.SCORE)
-- Ordina i resi sospetti in base al grado di minaccia di chargeback, pressione
-- legale e aggressività verso il customer care direttamente nella ORDER BY.
-- -----------------------------------------------------------------------------
WITH candidate_returns AS (
  SELECT return_id, customer_id, refund_amount, return_reason_text, agent_notes
  FROM `retail_fraud.returns`
  WHERE customer_id >= 9000 OR MOD(return_id, 500) = 0
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY return_id) = 1
  ORDER BY return_id DESC
  LIMIT 12
)
SELECT
  return_id,
  customer_id,
  refund_amount,
  return_reason_text,
  agent_notes,
  ROUND(
    AI.SCORE(
      ('Rate the severity of chargeback threat, legal intimidation, refusal of store credit, or scripted abuse in this return interaction: ',
       return_reason_text, ' | Agent notes: ', agent_notes),
      connection_id => 'us.vertex_ai_conn'
    ),
    2
  ) AS escalation_risk_score
FROM candidate_returns
ORDER BY escalation_risk_score DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- 13f. SCRIPTED CLAIM DISCOVERY: Semantic Similarity (AI.SIMILARITY)
-- Individua gli account che utilizzano lo stesso "copione" (script) fraudolento
-- calcolando la similarità semantica (cosine similarity) rispetto a un pattern noto.
-- -----------------------------------------------------------------------------
WITH sample_claims AS (
  SELECT return_id, customer_id, refund_amount, return_reason_text
  FROM `retail_fraud.returns`
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY return_id) = 1
  ORDER BY (customer_id >= 9000) DESC, customer_id
  LIMIT 12
)
SELECT
  return_id,
  customer_id,
  refund_amount,
  return_reason_text,
  ROUND(
    AI.SIMILARITY(
      content1 => return_reason_text,
      content2 => 'Package never arrived despite carrier tracking showing delivered. Demanding immediate refund to credit card or opening a chargeback.',
      connection_id => 'us.vertex_ai_conn',
      endpoint => 'text-embedding-005'
    ),
    3
  ) AS script_similarity_score
FROM sample_claims
ORDER BY script_similarity_score DESC
LIMIT 6;
