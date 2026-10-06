-- Phase 1a: customers and products
-- Deterministic synthetic data (FARM_FINGERPRINT-based, safe to re-run).
-- Customer id ranges: 1-5000 regular (4001-4050 = benign high-returners),
--                     9001-9006 Ring A, 9101-9104 Ring B, 9201-9205 Ring C.

CREATE SCHEMA IF NOT EXISTS `retail_fraud`
  OPTIONS (
    location = 'US',
    description = 'Demo: Retail return-fraud ring detection with BigQuery Property Graph and Generative AI'
  );

CREATE OR REPLACE TABLE `retail_fraud.customers` AS
WITH ids AS (
  SELECT id FROM UNNEST(GENERATE_ARRAY(1, 5000)) id
  UNION ALL SELECT id FROM UNNEST(GENERATE_ARRAY(9001, 9006)) id
  UNION ALL SELECT id FROM UNNEST(GENERATE_ARRAY(9101, 9104)) id
  UNION ALL SELECT id FROM UNNEST(GENERATE_ARRAY(9201, 9205)) id
)
SELECT
  id AS customer_id,
  CONCAT('customer_', id, '@example.com') AS email,
  CONCAT('Customer ', id) AS full_name,
  DATE_ADD(DATE '2023-06-01',
           INTERVAL ABS(MOD(FARM_FINGERPRINT(CONCAT('s', id)), 700)) DAY) AS signup_date,
  ['new','regular','vip','occasional'][OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('seg', id)), 4)))] AS segment
FROM ids;

CREATE OR REPLACE TABLE `retail_fraud.products` AS
WITH cfg AS (
  SELECT
    ['Electronics','Apparel','Footwear','Home','Beauty','Sports','Toys','Accessories'] AS cats,
    ['Aurora','Nimbus','Vertex','Pulse','Echo','Terra','Lumen','Drift','Atlas','Nova'] AS brands,
    ['Wireless Headphones','Slim Jacket','Running Shoes','Table Lamp','Face Serum','Yoga Mat','Building Blocks','Leather Belt'] AS base_names
)
SELECT
  id AS product_id,
  CONCAT('SKU-', LPAD(CAST(id AS STRING), 5, '0')) AS sku,
  cats[OFFSET(MOD(id, 8))] AS category,
  CONCAT(brands[OFFSET(ABS(MOD(FARM_FINGERPRINT(CONCAT('b', id)), 10)))], ' ',
         base_names[OFFSET(MOD(id, 8))], ' ', CAST(100 + MOD(id, 900) AS STRING)) AS product_name,
  ROUND(CASE WHEN MOD(id, 8) = 0 THEN 250 ELSE 15 END
        + ABS(MOD(FARM_FINGERPRINT(CONCAT('p', id)), 35000)) / 100, 2) AS unit_price,
  -- every 3rd product carries a terse legacy description (catalog-enrichment demo target)
  CASE WHEN MOD(id, 3) = 0 THEN
    CONCAT(LOWER(SUBSTR(cats[OFFSET(MOD(id, 8))], 1, 4)), ' itm ', CAST(id AS STRING), ' ',
           ['blk','wht','nvy','gry','red'][OFFSET(MOD(id, 5))],
           ' s/m/l no tag imp.2024 see sup cat ref#', CAST(1000 + id AS STRING))
  ELSE
    CONCAT('High-quality ', LOWER(cats[OFFSET(MOD(id, 8))]), ' item from our ',
           ['spring','summer','autumn','winter'][OFFSET(MOD(id, 4))], ' collection.')
  END AS description
FROM UNNEST(GENERATE_ARRAY(1, 500)) id CROSS JOIN cfg;
