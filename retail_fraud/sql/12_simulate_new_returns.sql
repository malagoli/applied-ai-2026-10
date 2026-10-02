-- Phase 4c (demo helper): simulate 10 fresh returns arriving in the system.
-- The next run of 07_async_scoring_batch.sql picks them up automatically
-- (newest first) without rescoring anything already in returns_scored.
INSERT INTO `retail_fraud.returns`
  (return_id, order_id, customer_id, return_date, refund_amount,
   return_reason_text, agent_notes, status)
SELECT
  6000000 + o.order_id,
  o.order_id,
  o.customer_id,
  CURRENT_DATE(),
  o.order_total,
  'Package never arrived even though tracking says delivered. Refund to my card immediately please.',
  'Tracking shows delivered with signature. Customer refused replacement, demanded card refund. New claim pattern, flagging.',
  'pending'
FROM `retail_fraud.orders` o
WHERE NOT EXISTS (SELECT 1 FROM `retail_fraud.returns` r WHERE r.order_id = o.order_id)
ORDER BY o.order_id
LIMIT 10;
