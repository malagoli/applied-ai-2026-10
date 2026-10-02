-- Phase 3e (side demo from the README): catalog enrichment.
-- Rewrite terse legacy product descriptions into customer-facing copy.
CREATE OR REPLACE TABLE `retail_fraud.products_enriched` AS
SELECT
  product_id, sku, category, product_name,
  description AS raw_description,
  AI.GENERATE(
    prompt => CONCAT(
      'Rewrite this terse legacy retail catalog description as 1-2 clear, appealing, ',
      'customer-facing sentences in English. Do not invent specifications. ',
      'Output ONLY the final description text, with no options, preamble or markdown. ',
      'Product name: ', product_name, '. Category: ', category,
      '. Legacy description: "', description, '"'),
    connection_id => 'eu.vertex_ai_conn',
    endpoint => 'gemini-3.8-flash').result AS enriched_description
FROM (
  SELECT * FROM `retail_fraud.products`
  WHERE MOD(product_id, 3) = 0   -- the messy legacy records
  ORDER BY product_id
  LIMIT 12
);
