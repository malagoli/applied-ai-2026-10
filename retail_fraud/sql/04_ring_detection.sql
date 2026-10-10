-- Phase 2b: ring detection.
-- Graph (GQL) finds customers connected through shared entities; SQL adds the
-- behavioral filter (high return rate) and groups them into rings.
-- Detection uses NO ground-truth knowledge.
-- Automatically falls back to pure-SQL edge-table traversal if the project
-- does not have a BigQuery Enterprise Edition reservation for GRAPH_TABLE.

BEGIN
  SET @@reservation = CONCAT('projects/', @@project_id, '/locations/US/reservations/my-reservation');
  CREATE OR REPLACE TABLE `retail_fraud.suspicious_rings` AS
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
    SELECT 'device' AS entity_type, CAST(device_id AS STRING) AS entity_id, customer_id
    FROM GRAPH_TABLE(`retail_fraud.fraud_graph`
         MATCH (c:Customer)-[:USES_DEVICE]->(d:Device)
         COLUMNS (c.customer_id AS customer_id, d.device_id AS device_id))
    UNION ALL
    SELECT 'address', CAST(address_id AS STRING), customer_id
    FROM GRAPH_TABLE(`retail_fraud.fraud_graph`
         MATCH (c:Customer)-[:SHIPS_TO]->(a:Address)
         COLUMNS (c.customer_id AS customer_id, a.address_id AS address_id))
    UNION ALL
    SELECT 'payment_method', CAST(payment_method_id AS STRING), customer_id
    FROM GRAPH_TABLE(`retail_fraud.fraud_graph`
         MATCH (c:Customer)-[:PAYS_WITH]->(p:PaymentMethod)
         COLUMNS (c.customer_id AS customer_id, p.payment_method_id AS payment_method_id))
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

EXCEPTION WHEN ERROR THEN
  -- Standard Edition / On-Demand Automatic Fallback
  CREATE OR REPLACE TABLE `retail_fraud.suspicious_rings` AS
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
END;
