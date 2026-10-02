-- Phase 1b: orders, order_items, returns (free text), loyalty, entity/link tables, ground truth.
-- Seeded schemes:
--   Ring A (9001-9006): wardrobing, 25 orders each, ~65% returned, share devices 999001/999002 + address 888001
--   Ring B (9101-9104): loyalty points cycling, 12 orders each, ~67% returned AFTER redeeming points, share address 888101
--   Ring C (9201-9205): "item not received" claims on electronics, 10 orders each, ~80% "returned", share payment 777201
--   Benign high-returners (4001-4050): ~50% return rate, legit sizing reasons, NO shared entities

CREATE OR REPLACE TABLE `retail_fraud.orders` AS
WITH base AS (
  SELECT oid AS order_id,
         1 + ABS(MOD(FARM_FINGERPRINT(CONCAT('c', oid)), 5000)) AS customer_id,
         DATE_ADD(DATE '2025-01-01', INTERVAL ABS(MOD(FARM_FINGERPRINT(CONCAT('d', oid)), 540)) DAY) AS order_date
  FROM UNNEST(GENERATE_ARRAY(1, 50000)) oid
  UNION ALL
  SELECT 900000 + (m - 9001) * 25 + n, m,
         DATE_ADD(DATE '2025-09-01', INTERVAL MOD(n * 11 + m, 290) DAY)
  FROM UNNEST(GENERATE_ARRAY(9001, 9006)) m, UNNEST(GENERATE_ARRAY(1, 25)) n
  UNION ALL
  SELECT 910000 + (m - 9101) * 12 + n, m,
         DATE_ADD(DATE '2025-10-01', INTERVAL MOD(n * 19 + m, 260) DAY)
  FROM UNNEST(GENERATE_ARRAY(9101, 9104)) m, UNNEST(GENERATE_ARRAY(1, 12)) n
  UNION ALL
  SELECT 920000 + (m - 9201) * 10 + n, m,
         DATE_ADD(DATE '2025-11-01', INTERVAL MOD(n * 23 + m, 230) DAY)
  FROM UNNEST(GENERATE_ARRAY(9201, 9205)) m, UNNEST(GENERATE_ARRAY(1, 10)) n
)
SELECT
  order_id, customer_id, order_date,
  CASE WHEN customer_id BETWEEN 9001 AND 9006 THEN IF(MOD(order_id, 2) = 0, 999001, 999002)
       ELSE 100000 + customer_id END AS device_id,
  CASE WHEN customer_id BETWEEN 9001 AND 9006 THEN 888001
       WHEN customer_id BETWEEN 9101 AND 9104 THEN 888101
       ELSE 200000 + customer_id END AS address_id,
  CASE WHEN customer_id BETWEEN 9201 AND 9205 THEN 777201
       ELSE 300000 + customer_id END AS payment_method_id,
  ROUND(CASE WHEN customer_id BETWEEN 9201 AND 9205
             THEN 400 + ABS(MOD(FARM_FINGERPRINT(CONCAT('t', order_id)), 50000)) / 100
             ELSE 20 + ABS(MOD(FARM_FINGERPRINT(CONCAT('t', order_id)), 38000)) / 100 END, 2) AS order_total,
  'web' AS channel
FROM base;

CREATE OR REPLACE TABLE `retail_fraud.order_items` AS
SELECT
  o.order_id * 10 AS order_item_id,
  o.order_id,
  CASE WHEN o.customer_id BETWEEN 9201 AND 9205
       THEN 8 * (1 + ABS(MOD(FARM_FINGERPRINT(CONCAT('rc', o.order_id)), 62)))  -- Electronics only
       ELSE 1 + ABS(MOD(FARM_FINGERPRINT(CONCAT('pi', o.order_id)), 500)) END AS product_id,
  1 AS quantity,
  o.order_total AS line_amount
FROM `retail_fraud.orders` o;

-- Returns with cohort-specific free text (the unstructured input for the AI functions)
CREATE OR REPLACE TABLE `retail_fraud.returns` AS
WITH cfg AS (
  SELECT
    ['Wrong size, I need a medium instead of a large.',
     'Color looked quite different from the website photos.',
     'Arrived later than expected and I no longer need it.',
     'Quality not as expected, the fabric feels thin.',
     'Ordered two sizes to compare, returning the one that does not fit.',
     'Gift for my sister but she already had the same one.',
     'The box was crushed in transit and the item is scratched.',
     'Changed my mind after seeing it in person.',
     'Does not match the curtains in my living room.',
     'Instructions missing from the package, gave up on assembling it.'] AS legit_reasons,
    ['Item did not fit properly.',
     'Not as described.',
     'Defective.',
     'Item did not fit properly, requesting full refund.'] AS ring_a_reasons,
    ['Package never arrived even though tracking says delivered. I need a refund immediately or I will open a chargeback.',
     'Never received this order. The tracking info must be wrong. Refund to my card please, not store credit.',
     'Item was not in the box when it arrived, the box was empty. I want my money back today.'] AS ring_c_reasons,
    ['Found a better price elsewhere, returning this one.',
     'Changed my mind, please refund to original payment method.',
     'No longer needed.'] AS ring_b_reasons,
    ['Runs small, exchanging for a bigger size next order.',
     'Sizing chart was off for me, returning.',
     'Fit was not right, I have a hard-to-fit shape so I order several and return most.',
     'Too tight around the shoulders, returning as usual, sorry!'] AS hr_reasons,
    ['Standard return, item in original packaging with tags. Processed refund.',
     'Customer polite, item unused. Refund issued per policy.',
     'Damaged in transit confirmed by photos. Refund plus apology voucher.',
     'Item resellable, restocked. No issues.',
     'Late delivery confirmed by carrier. Refund issued.'] AS legit_notes,
    ['Tags detached and faint perfume smell on the garment. Customer insisted on immediate refund. Sounded like the same script as a call I handled last week from a different account, same address on file.',
     'Garment shows clear signs of wear, small makeup stain inside the collar. Customer became aggressive when I mentioned our wear-and-return policy.',
     'Third return this month from this account, all worn items with tags reattached with a different tag gun. Escalating to review queue but issuing refund per policy.',
     'Item smells of smoke and detergent, hem re-stitched. Customer quoted our refund policy verbatim before I could speak.'] AS ring_a_notes,
    ['Carrier tracking shows delivered with GPS pin at the address and signature. Customer refused replacement, demanded refund to card only. Account created recently, high-value electronics only.',
     'Second item-not-received claim from this payment method across different accounts. Customer threatened chargeback within the first minute of the call.',
     'Photos requested of the empty box; customer refused and quoted consumer protection law. Tracking weight matches shipped weight.'] AS ring_c_notes,
    ['Points from this purchase were already redeemed for a gift card before the return came in. Points balance went negative, flagging for loyalty team.',
     'Customer redeemed the earn from this order two days after purchase, then returned the item. Same pattern as their previous three orders.',
     'Loyalty earn already spent on a discounted order. Refund processed, loyalty clawback failed.'] AS ring_b_notes,
    ['Frequent returner, always sizing-related, items always unworn with tags. Genuine fit issues, VIP customer.',
     'Regular size-sampler, returns are always in perfect condition. No concerns.',
     'Known bracketing behavior, returns clean and prompt. Standard processing.'] AS hr_notes
),
eligible AS (
  SELECT o.*,
    CASE
      WHEN o.customer_id BETWEEN 9001 AND 9006 THEN 'ring_a'
      WHEN o.customer_id BETWEEN 9101 AND 9104 THEN 'ring_b'
      WHEN o.customer_id BETWEEN 9201 AND 9205 THEN 'ring_c'
      WHEN o.customer_id BETWEEN 4001 AND 4050 THEN 'high_returner'
      ELSE 'regular' END AS cohort,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('ret', o.order_id)), 100)) AS dice
  FROM `retail_fraud.orders` o
)
SELECT
  5000000 + e.order_id AS return_id,
  e.order_id,
  e.customer_id,
  DATE_ADD(e.order_date, INTERVAL 5 + ABS(MOD(FARM_FINGERPRINT(CONCAT('rd', e.order_id)), 15)) DAY) AS return_date,
  e.order_total AS refund_amount,
  CASE e.cohort
    WHEN 'ring_a' THEN ring_a_reasons[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('rr', e.order_id)), 4)))]
    WHEN 'ring_b' THEN ring_b_reasons[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('rr', e.order_id)), 3)))]
    WHEN 'ring_c' THEN ring_c_reasons[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('rr', e.order_id)), 3)))]
    WHEN 'high_returner' THEN hr_reasons[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('rr', e.order_id)), 4)))]
    ELSE legit_reasons[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('rr', e.order_id)), 10)))]
  END AS return_reason_text,
  CASE e.cohort
    WHEN 'ring_a' THEN ring_a_notes[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('an', e.order_id)), 4)))]
    WHEN 'ring_b' THEN ring_b_notes[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('an', e.order_id)), 3)))]
    WHEN 'ring_c' THEN ring_c_notes[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('an', e.order_id)), 3)))]
    WHEN 'high_returner' THEN hr_notes[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('an', e.order_id)), 3)))]
    ELSE legit_notes[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('an', e.order_id)), 5)))]
  END AS agent_notes,
  'refunded' AS status
FROM eligible e CROSS JOIN cfg
WHERE e.dice < CASE e.cohort
                 WHEN 'ring_a' THEN 65 WHEN 'ring_b' THEN 67 WHEN 'ring_c' THEN 80
                 WHEN 'high_returner' THEN 50 ELSE 8 END;

-- Loyalty: accounts for everyone; Ring B earns points then redeems them 2 days later, then returns the item
CREATE OR REPLACE TABLE `retail_fraud.loyalty_accounts` AS
SELECT customer_id,
       1000000 + customer_id AS loyalty_account_id,
       ABS(MOD(FARM_FINGERPRINT(CONCAT('pts', customer_id)), 20000)) AS points_balance,
       ['bronze','silver','gold'][OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('tier', customer_id)), 3)))] AS tier
FROM `retail_fraud.customers`;

CREATE OR REPLACE TABLE `retail_fraud.loyalty_transactions` AS
-- regular earns on ~20% of regular orders
SELECT o.order_id * 10 + 1 AS txn_id, o.customer_id, o.order_id, 'EARN' AS txn_type,
       CAST(o.order_total * 10 AS INT64) AS points,
       TIMESTAMP(o.order_date) AS txn_ts
FROM `retail_fraud.orders` o
WHERE o.customer_id <= 5000 AND ABS(MOD(FARM_FINGERPRINT(CONCAT('le', o.order_id)), 5)) = 0
UNION ALL
SELECT o.order_id * 10 + 1, o.customer_id, o.order_id, 'EARN',
       CAST(o.order_total * 10 AS INT64), TIMESTAMP(o.order_date)
FROM `retail_fraud.orders` o WHERE o.customer_id BETWEEN 9101 AND 9104
UNION ALL
SELECT o.order_id * 10 + 2, o.customer_id, o.order_id, 'REDEEM',
       -CAST(o.order_total * 10 AS INT64), TIMESTAMP(DATE_ADD(o.order_date, INTERVAL 2 DAY))
FROM `retail_fraud.orders` o WHERE o.customer_id BETWEEN 9101 AND 9104;

-- Entity + link tables (graph edges). Link tables derive from actual order behavior,
-- plus benign household noise: every 37th customer also uses the neighbor's device
-- (shared device but normal return rate -> must NOT be flagged).
CREATE OR REPLACE TABLE `retail_fraud.customer_devices` AS
SELECT DISTINCT customer_id, device_id FROM `retail_fraud.orders`
UNION DISTINCT
SELECT id, 100000 + id + 1 FROM UNNEST(GENERATE_ARRAY(1, 4999)) id WHERE MOD(id, 37) = 0;

CREATE OR REPLACE TABLE `retail_fraud.customer_addresses` AS
SELECT DISTINCT customer_id, address_id FROM `retail_fraud.orders`
UNION DISTINCT
SELECT id, 200000 + id + 1 FROM UNNEST(GENERATE_ARRAY(1, 4999)) id WHERE MOD(id, 41) = 0;

CREATE OR REPLACE TABLE `retail_fraud.customer_payments` AS
SELECT DISTINCT customer_id, payment_method_id FROM `retail_fraud.orders`;

CREATE OR REPLACE TABLE `retail_fraud.devices` AS
SELECT DISTINCT device_id,
       CONCAT('fp_', TO_HEX(MD5(CAST(device_id AS STRING)))) AS device_fingerprint,
       ['ios','android','web'][OFFSET(MOD(device_id, 3))] AS platform
FROM `retail_fraud.customer_devices`;

CREATE OR REPLACE TABLE `retail_fraud.addresses` AS
SELECT DISTINCT address_id,
       CONCAT('Via ', ['Roma','Milano','Garibaldi','Dante','Verdi','Manzoni'][OFFSET(MOD(address_id, 6))],
              ' ', CAST(1 + MOD(address_id, 200) AS STRING)) AS street,
       ['Milan','Rome','Turin','Naples','Bologna','Florence'][OFFSET(MOD(address_id, 6))] AS city
FROM `retail_fraud.customer_addresses`;

CREATE OR REPLACE TABLE `retail_fraud.payment_methods` AS
SELECT DISTINCT payment_method_id,
       ['card','paypal','wallet'][OFFSET(MOD(payment_method_id, 3))] AS method_type,
       LPAD(CAST(MOD(payment_method_id, 10000) AS STRING), 4, '0') AS last4
FROM `retail_fraud.customer_payments`;

-- Ground truth (evaluation only -- not used by any detection query)
CREATE OR REPLACE TABLE `retail_fraud._ground_truth_rings` AS
SELECT 'RING-A' AS ring_id, id AS customer_id, 'wardrobing via shared devices + address' AS scheme
FROM UNNEST(GENERATE_ARRAY(9001, 9006)) id
UNION ALL
SELECT 'RING-B', id, 'loyalty points cycling via shared address' FROM UNNEST(GENERATE_ARRAY(9101, 9104)) id
UNION ALL
SELECT 'RING-C', id, 'item-not-received claims via shared payment method' FROM UNNEST(GENERATE_ARRAY(9201, 9205)) id;
