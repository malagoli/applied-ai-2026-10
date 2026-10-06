-- Phase 3d: AI.GENERATE -- investigator case brief per detected ring,
-- combining graph evidence (shared entities) with AI-read return narratives.
CREATE OR REPLACE TABLE `retail_fraud.case_summaries` AS
WITH ring_members AS (
  SELECT sr.ring_id, m AS customer_id
  FROM `retail_fraud.suspicious_rings` sr, UNNEST(sr.members) m
),
samples AS (
  SELECT rm.ring_id,
         STRING_AGG(DISTINCT r.return_reason_text, ' | ' LIMIT 5) AS sample_reasons,
         STRING_AGG(DISTINCT r.agent_notes, ' | ' LIMIT 5) AS sample_notes
  FROM ring_members rm
  JOIN `retail_fraud.returns` r USING (customer_id)
  GROUP BY 1
)
SELECT
  sr.ring_id, sr.members, sr.refund_exposure,
  AI.GENERATE(
    prompt => CONCAT(
      'You are a retail fraud investigator. Write a concise case brief (max 180 words) ',
      'for this suspected return-fraud ring, ending with ONE recommended next action. ',
      'Evidence -- ring id: ', sr.ring_id,
      '; member customer ids: ', TO_JSON_STRING(sr.members),
      '; entities shared by all members: ', TO_JSON_STRING(sr.shared_entities),
      '; total returns: ', CAST(sr.total_returns AS STRING),
      '; average return rate: ', CAST(sr.avg_return_rate AS STRING),
      '; refund exposure (EUR): ', CAST(sr.refund_exposure AS STRING),
      '; sample return reasons: ', s.sample_reasons,
      '; sample agent notes: ', s.sample_notes),
    connection_id => 'us.vertex_ai_conn',
    endpoint => 'gemini-3.8-flash').result AS case_summary
FROM `retail_fraud.suspicious_rings` sr
JOIN samples s USING (ring_id);
