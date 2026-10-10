-- Phase 2c: standalone GQL exploration queries for the demo walkthrough.
-- Automatically falls back to pure-SQL edge-table joins if the project does not
-- have a BigQuery Enterprise Edition reservation for GRAPH_TABLE.

BEGIN
  SET @@reservation = CONCAT('projects/', @@project_id, '/locations/US/reservations/my-reservation');
  -- Q1: pairs of DISTINCT customer accounts using the SAME device
  SELECT * FROM GRAPH_TABLE(
    `retail_fraud.fraud_graph`
    MATCH (a:Customer)-[:USES_DEVICE]->(d:Device)<-[:USES_DEVICE]-(b:Customer)
    WHERE a.customer_id < b.customer_id
    COLUMNS (a.customer_id AS customer_a, b.customer_id AS customer_b,
             d.device_id AS shared_device)
  )
  ORDER BY shared_device
  LIMIT 50;

  -- Q2: accounts connected through ANY shared entity (device, address or payment method)
  SELECT customer_a, customer_b, COUNT(*) AS shared_entities
  FROM GRAPH_TABLE(
    `retail_fraud.fraud_graph`
    MATCH (a:Customer)-[:USES_DEVICE|SHIPS_TO|PAYS_WITH]->(x)<-[:USES_DEVICE|SHIPS_TO|PAYS_WITH]-(b:Customer)
    WHERE a.customer_id < b.customer_id
    COLUMNS (a.customer_id AS customer_a, b.customer_id AS customer_b)
  )
  GROUP BY 1, 2
  ORDER BY shared_entities DESC
  LIMIT 50;
EXCEPTION WHEN ERROR THEN
  -- Standard Edition / On-Demand Automatic Fallback
  SELECT a.customer_id AS customer_a, b.customer_id AS customer_b, a.device_id AS shared_device
  FROM `retail_fraud.customer_devices` a
  JOIN `retail_fraud.customer_devices` b
    ON a.device_id = b.device_id AND a.customer_id < b.customer_id
  ORDER BY shared_device
  LIMIT 50;
END;

SET @@reservation = 'none';

-- Q3: loyalty points cycling — points earned AND redeemed on an order that was then returned
SELECT r.customer_id,
       COUNT(*) AS cycled_returns,
       SUM(e.points) AS points_cycled,
       ROUND(SUM(r.refund_amount), 2) AS refunds_on_cycled_orders
FROM `retail_fraud.returns` r
JOIN `retail_fraud.loyalty_transactions` e
  ON e.order_id = r.order_id AND e.txn_type = 'EARN'
JOIN `retail_fraud.loyalty_transactions` rd
  ON rd.order_id = r.order_id AND rd.txn_type = 'REDEEM'
 AND DATE(rd.txn_ts) < r.return_date
GROUP BY 1
HAVING COUNT(*) >= 3
ORDER BY points_cycled DESC;
