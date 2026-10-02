-- Phase 4b: investigator dashboard view -- rings ranked by refund exposure,
-- combining graph evidence, AI return scores and the generated case brief.
CREATE OR REPLACE VIEW `retail_fraud.fraud_dashboard` AS
WITH rm AS (
  SELECT ring_id, m AS customer_id
  FROM `retail_fraud.suspicious_rings`, UNNEST(members) m
),
ai AS (
  SELECT rm.ring_id,
         COUNT(s.return_id) AS scored_returns,
         COUNTIF(s.is_suspicious) AS ai_flagged_returns
  FROM rm
  JOIN `retail_fraud.returns_scored` s USING (customer_id)
  GROUP BY 1
)
SELECT
  sr.ring_id, sr.n_members, sr.members, sr.shared_entities,
  sr.total_returns, sr.avg_return_rate, sr.refund_exposure,
  ai.scored_returns, ai.ai_flagged_returns,
  cs.case_summary
FROM `retail_fraud.suspicious_rings` sr
LEFT JOIN ai USING (ring_id)
LEFT JOIN `retail_fraud.case_summaries` cs USING (ring_id);
