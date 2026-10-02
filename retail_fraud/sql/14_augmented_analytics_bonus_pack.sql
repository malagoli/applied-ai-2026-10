-- =============================================================================
-- BONUS PACK: BigQuery Augmented Analytics Table-Valued Functions (TVFs)
--
-- Reference: "Agent-ready analytics: Unlocking insights with BigQuery augmented analytics"
-- https://cloud.google.com/blog/products/data-analytics/bigquery-augmented-analytics-tvfs?e=48754805
--
-- This script showcases the 6 augmented analytics functions chained together
-- for autonomous, agent-ready data investigation:
--   1. ML.DETECT_CHANGE_POINTS — Identifies structural breaks / regime shifts in returns.
--   2. ML.TREND                — Isolates the underlying secular trend (+ 7-day projection).
--   3. ML.SEASONALITY          — Discovers predictable recurring cycles (weekly/monthly).
--   4. AI.KEY_DRIVERS          — Diagnoses the dimensional drivers behind the detected shift.
--   5. AI.CAUSAL_EFFECT        — Quantifies causal dollar impact vs counterfactual baseline.
--   6. ML.CORRELATION          — Computes statistical correlation matrix across metrics.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ML.DETECT_CHANGE_POINTS: Quando è cambiato strutturalmente il volume dei resi?
-- -----------------------------------------------------------------------------
-- Domanda di Business: In quali intervalli temporali l'ammontare dei rimborsi ha subito
-- uno shift persistente di regime (es. attivazione coordinata dei fraud ring)?
WITH daily_returns AS (
  SELECT return_date, ROUND(SUM(refund_amount), 2) AS daily_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  begin_timestamp,
  end_timestamp,
  metrics.count AS duration_days,
  ROUND(metrics.avg, 2) AS avg_daily_refund_eur,
  ROUND(metrics.min, 2) AS min_daily_refund_eur,
  ROUND(metrics.max, 2) AS max_daily_refund_eur
FROM ML.DETECT_CHANGE_POINTS(
  TABLE daily_returns,
  data_col => 'daily_refund_eur',
  timestamp_col => 'return_date'
)
ORDER BY begin_timestamp DESC;

-- -----------------------------------------------------------------------------
-- 2. ML.TREND: Trend di fondo secolare e proiezione a 7 giorni (senza rumore)
-- -----------------------------------------------------------------------------
-- Domanda di Business: Qual è la traiettoria reale di crescita dei rimborsi, isolata
-- dalle fluttuazioni casuali giornaliere, e quale sarà il trend per i prossimi 7 giorni?
WITH daily_returns AS (
  SELECT return_date, ROUND(SUM(refund_amount), 2) AS daily_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  return_date,
  time_series_type,
  ROUND(daily_refund_eur, 2) AS actual_or_forecast_refund_eur,
  ROUND(trend, 2) AS underlying_trend_eur
FROM ML.TREND(
  TABLE daily_returns,
  data_col => 'daily_refund_eur',
  timestamp_col => 'return_date',
  horizon => 7,
  smoothing_window_size => 7,
  adjust_step_changes => TRUE
)
ORDER BY return_date DESC
LIMIT 14;

-- -----------------------------------------------------------------------------
-- 3. ML.SEASONALITY: Decomposizione stagionale e cicli settimanali
-- -----------------------------------------------------------------------------
-- Domanda di Business: Esiste un pattern settimanale ricorrente nei rimborsi
-- (es. picco di richieste post-weekend) da non confondere con le anomalie di frode?
WITH daily_returns AS (
  SELECT return_date, ROUND(SUM(refund_amount), 2) AS daily_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  return_date,
  FORMAT_DATE('%A', return_date) AS day_of_week,
  ROUND(daily_refund_eur, 2) AS daily_refund_eur,
  ROUND(weekly, 2) AS weekly_seasonal_component_eur
FROM ML.SEASONALITY(
  TABLE daily_returns,
  data_col => 'daily_refund_eur',
  timestamp_col => 'return_date'
)
ORDER BY return_date DESC
LIMIT 7;

-- -----------------------------------------------------------------------------
-- 4. AI.KEY_DRIVERS: Chaining dall'intervallo anomalo per scoprire i fattori colpevoli
-- -----------------------------------------------------------------------------
-- Domanda di Business: Confrontando il periodo pre-ondata con quello post-ondata,
-- quali categorie di prodotti e segmenti di clienti hanno determinato l'impennata dei resi?
WITH labeled_returns AS (
  SELECT
    p.category AS product_category,
    c.segment AS customer_segment,
    r.refund_amount,
    -- Label di interesse: transazioni avvenute durante l'ondata sospetta del Q4 2025
    (r.return_date >= '2025-11-15' AND r.return_date <= '2026-01-15') AS is_suspicious_period
  FROM `retail_fraud.returns` r
  JOIN `retail_fraud.customers` c ON c.customer_id = r.customer_id
  JOIN `retail_fraud.order_items` oi ON oi.order_id = r.order_id
  JOIN `retail_fraud.products` p ON p.product_id = oi.product_id
)
SELECT
  drivers AS key_driver_segment,
  ROUND(metric_interest, 1) AS refunds_in_interest_period,
  ROUND(metric_reference, 1) AS refunds_in_reference_period,
  ROUND(relative_difference * 100, 1) AS relative_growth_pct,
  ROUND(unexpected_difference, 1) AS excess_refund_amount_eur
FROM AI.KEY_DRIVERS(
  TABLE labeled_returns,
  metric_col => 'refund_amount',
  dimension_cols => ['product_category', 'customer_segment'],
  interest_label_col => 'is_suspicious_period',
  top_k => 5
)
ORDER BY relative_difference DESC;

-- -----------------------------------------------------------------------------
-- 5. AI.CAUSAL_EFFECT: Misura dell'impatto causale netto rispetto al controfattuale
-- -----------------------------------------------------------------------------
-- Domanda di Business: Qual è il danno economico causale netto attribuibile all'ondata di
-- frode iniziata a metà Novembre 2025, isolando il controfattuale sintetico organico?
WITH daily_returns AS (
  SELECT TIMESTAMP(return_date) AS return_ts, ROUND(SUM(refund_amount), 2) AS daily_refund_eur
  FROM `retail_fraud.returns`
  GROUP BY 1
)
SELECT
  ROUND(prob_causal_effect * 100, 1) AS probability_of_causal_impact_pct,
  ROUND(p_value, 4) AS statistical_p_value,
  ROUND(absolute_effect, 2) AS cumulative_causal_financial_impact_eur,
  ROUND(relative_effect * 100, 1) AS relative_lift_over_counterfactual_pct
FROM AI.CAUSAL_EFFECT(
  (SELECT * FROM daily_returns),
  data_col => 'daily_refund_eur',
  timestamp_col => 'return_ts',
  intervention_timestamp => TIMESTAMP '2025-11-15 00:00:00',
  output_time_series => FALSE
);

-- -----------------------------------------------------------------------------
-- 6. ML.CORRELATION: Matrice di correlazione tra metriche di business per segmento
-- -----------------------------------------------------------------------------
-- Domanda di Business: Come correlano il numero di ordini, il tasso di reso e i rimborsi
-- totali tra i vari segmenti di clientela per individuare cluster a rischio?
WITH customer_aggregates AS (
  SELECT
    c.customer_id,
    c.segment,
    CAST(COUNT(DISTINCT o.order_id) AS FLOAT64) AS total_orders,
    CAST(COUNT(DISTINCT r.return_id) AS FLOAT64) AS total_returns,
    CAST(ROUND(SUM(IFNULL(r.refund_amount, 0)), 2) AS FLOAT64) AS total_refunds
  FROM `retail_fraud.customers` c
  JOIN `retail_fraud.orders` o USING (customer_id)
  LEFT JOIN `retail_fraud.returns` r USING (order_id)
  GROUP BY 1, 2
)
SELECT
  corr_col AS feature_name,
  target_col AS target_metric,
  ROUND(correlation, 3) AS pearson_correlation,
  segment_size AS evaluated_customers_count
FROM ML.CORRELATION(
  TABLE customer_aggregates,
  target_col => 'total_returns',
  target_correlation_cols => ['total_orders', 'total_refunds']
)
ORDER BY correlation DESC;
