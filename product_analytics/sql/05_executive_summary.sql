-- =============================================================================
-- Step 5: AI-written executive summary
--
-- Feeds the aggregated root-cause evidence back into Gemini to produce a
-- briefing for the quality team — structured data in, narrative out.
--
-- Run with:  bq query --use_legacy_sql=false --location=US < sql/05_executive_summary.sql
-- =============================================================================

WITH evidence AS (
  SELECT STRING_AGG(
    FORMAT(
      'lot=%s type=%s supplier=%s machine=%s exposed_reviews=%d defect_reviews=%d rate=%.2f examples=%s',
      v.lot_id, v.component_type, v.supplier, v.installed_by_machine_id,
      v.reviews_on_batches_using_lot, v.implicating_defect_reviews, v.implication_rate,
      IFNULL(ARRAY_TO_STRING(v.example_findings, ' | '), '-')),
    '\n' ORDER BY v.implication_rate DESC)
    AS evidence_text
  FROM `mfg_quality_demo.v_component_lot_defect_rates` v
),
machine_context AS (
  SELECT STRING_AGG(
    FORMAT('machine=%s (%s, %s) last_maintenance=%t',
           machine_id, machine_name, production_line, last_maintenance_date),
    '\n')
    AS machines_text
  FROM `mfg_quality_demo.machines`
)
SELECT
  AI.GENERATE(
    prompt => CONCAT(
      'You are the head of quality at NovaHome Appliances. Below is the per-component-lot defect ',
      'evidence extracted by AI from customer reviews, plus factory machine maintenance records. ',
      'Write a concise executive briefing (max 250 words) that: 1) names the most likely root cause ',
      '(component lot, supplier, and the machine that processed it), 2) cites the numbers, ',
      '3) notes any relevant maintenance context, 4) recommends three concrete next actions.\n\n',
      'DEFECT EVIDENCE:\n', e.evidence_text,
      '\n\nMACHINE RECORDS:\n', m.machines_text),
    connection_id => 'us.vertex_ai_conn',
    endpoint      => 'gemini-3.8-flash'
  ).result AS executive_briefing
FROM evidence e, machine_context m;
