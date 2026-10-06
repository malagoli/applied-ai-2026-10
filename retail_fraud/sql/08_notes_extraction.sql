-- =============================================================================
-- Phase 3c: Structured extraction from free-text agent notes
--
-- Upgraded to use Serverless zero-setup AI.GENERATE with typed output_schema
-- (consistent with Lab II), eliminating the requirement to run CREATE MODEL first.
-- =============================================================================

-- Hackathon optimization: materialize 10 representative returns across suspicious rings
-- in a TEMP TABLE first so BigQuery's optimizer does not push AI.GENERATE below the filter.
CREATE TEMP TABLE _sampled_returns AS
SELECT r.return_id, r.customer_id, r.agent_notes
FROM `retail_fraud.returns` r
JOIN (
  SELECT DISTINCT m AS customer_id
  FROM `retail_fraud.suspicious_rings`, UNNEST(members) m
) s USING (customer_id)
QUALIFY ROW_NUMBER() OVER (PARTITION BY r.customer_id ORDER BY r.return_id) = 1
ORDER BY r.return_id
LIMIT 10;

CREATE OR REPLACE TABLE `retail_fraud.return_notes_extracted` AS
SELECT
  return_id,
  customer_id,
  agent_notes,
  extracted.claimed_issue,
  extracted.product_condition,
  extracted.refund_pressure,
  extracted.coordination_signal,
  extracted.status AS ai_status
FROM (
  SELECT
    r.return_id,
    r.customer_id,
    r.agent_notes,
    AI.GENERATE(
      prompt => CONCAT(
        'Extract structured fraud-investigation facts from these retail return agent notes. ',
        'Always populate every field with a string value (never return JSON null; use "N/A" if not applicable):\n',
        '- claimed_issue: short summary of the issue or scheme (e.g. item_not_received, wardrobing, loyalty_points_abuse, sizing, defective)\n',
        '- product_condition: physical state observed or "N/A" (e.g. worn_with_perfume, tags_reattached, missing, pristine, N/A)\n',
        '- refund_pressure: level of urgency/pressure or financial risk (LOW, MEDIUM, HIGH)\n',
        '- coordination_signal: true if notes mention repeated patterns, negative points balance, scripted calls, or shared accounts/addresses.\n\n',
        'Agent notes: ', r.agent_notes
      ),
      connection_id => 'us.vertex_ai_conn',
      endpoint      => 'gemini-3.8-flash',
      output_schema => 'claimed_issue STRING, product_condition STRING, refund_pressure STRING, coordination_signal BOOL'
    ) AS extracted
  FROM _sampled_returns r
);
