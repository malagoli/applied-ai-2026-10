#!/usr/bin/env bash
# =============================================================================
# Applied AI & Data Hackathon (Milano, 13 Ottobre 2026)
# Qwiklabs / Empty GCP Environment Bootstrap & Setup Utility
#
# Supports three modes for an empty Qwiklabs / GCP project:
#   MODE 0 (default / --bootstrap): Bootstraps an empty GCP project from zero
#                                   (APIs, Cloud Resource Connection, IAM, Base Seed Tables)
#   MODE 1 (--full)               : Runs full bootstrap + materializes all lab
#                                   pipeline tables (ready for ./test_workshop.sh)
#   MODE 2 (--project <proj_id>)  : Parameterizes SQL scripts for a specific
#                                   target GCP project & connection.
# =============================================================================

set -euo pipefail

ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
LOCATION="EU"
CONN_ID="vertex_ai_conn"

usage() {
  cat <<EOF
Usage:
  $0 [--bootstrap]                              # Default: Bootstrap empty Qwiklabs/GCP project (APIs, Connection, IAM, Seed Data)
  $0 --full                                     # Bootstrap + execute all Lab I & Lab II pipeline scripts (for automated validation)
  $0 --project <project_id> [--conn <conn_id>]  # Parameterize SQL files for a specific project/connection

Examples:
  $0
  $0 --full
  $0 --project my-qwiklabs-project-id --conn eu.vertex_ai_conn
EOF
  exit 1
}

MODE="${1:---bootstrap}"

if [[ "${MODE}" == "--bootstrap" || "${MODE}" == "--full" ]]; then
  if [[ -z "${ACTIVE_PROJECT}" || "${ACTIVE_PROJECT}" == "(unset)" ]]; then
    echo "❌ Error: No active GCP project found. Run 'gcloud config set project <PROJECT_ID>'."
    exit 1
  fi

  echo "============================================================================="
  echo "🚀 Bootstrapping Empty Qwiklabs / GCP Project from Scratch (${MODE})"
  echo "   Target Project : ${ACTIVE_PROJECT} (${LOCATION})"
  echo "   Connection ID  : ${LOCATION}.${CONN_ID}"
  echo "============================================================================="

  echo "▶ [1/5] Enabling required Google Cloud APIs (BigQuery, Connection, Vertex AI)..."
  gcloud services enable \
    bigquery.googleapis.com \
    bigqueryconnection.googleapis.com \
    aiplatform.googleapis.com \
    --project="${ACTIVE_PROJECT}" --quiet
  echo "   ✅ APIs enabled."

  echo "▶ [2/5] Ensuring Vertex AI Cloud Resource Connection '${CONN_ID}' exists in ${LOCATION}..."
  if ! bq show --connection --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" "${CONN_ID}" >/dev/null 2>&1; then
    bq mk --connection --connection_type=CLOUD_RESOURCE --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" "${CONN_ID}"
    echo "   ✅ Created connection '${LOCATION}.${CONN_ID}'."
  else
    echo "   ℹ️  Connection '${LOCATION}.${CONN_ID}' already exists."
  fi

  echo "▶ [3/5] Granting Vertex AI IAM permissions to Connection Service Account..."
  SA_EMAIL=$(bq show --format=json --connection --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" "${CONN_ID}" | python3 -c "import sys, json; print(json.load(sys.stdin)['cloudResource']['serviceAccountId'])")
  echo "   Service Account: ${SA_EMAIL}"
  gcloud projects add-iam-policy-binding "${ACTIVE_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/aiplatform.user" \
    --condition=None --quiet >/dev/null
  gcloud projects add-iam-policy-binding "${ACTIVE_PROJECT}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectViewer" \
    --condition=None --quiet >/dev/null
  echo "   ✅ Granted roles/aiplatform.user & roles/storage.objectViewer."
  echo "   ⏳ Waiting 15s for IAM propagation..."
  sleep 15

  echo "▶ [4/5] Creating Lab I (retail_fraud) schema and seed tables..."
  bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet < retail_fraud/sql/01_customers_products.sql
  bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet < retail_fraud/sql/02_orders_returns_loyalty.sql
  echo "   ✅ Lab I base schema & seed data loaded."

  echo "▶ [5/5] Creating Lab II (mfg_quality_demo) schema and seed tables..."
  bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet < product_analytics/sql/01_setup_dataset_and_data.sql
  echo "   ✅ Lab II base schema & seed data loaded."

  if [[ "${MODE}" == "--full" ]]; then
    echo ""
    echo "▶ [Full Mode] Materializing Lab I pipeline tables (03 -> 12)..."
    for script in 03_property_graph.sql 04_ring_detection.sql 06_remote_model.sql \
                  07_async_scoring_batch.sql 08_notes_extraction.sql 09_case_summaries.sql \
                  10_catalog_enrichment.sql 11_fraud_dashboard.sql 12_simulate_new_returns.sql; do
      echo "   Running retail_fraud/sql/${script}..."
      bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet < "retail_fraud/sql/${script}"
    done
    echo "   Scoring newly simulated returns via retail_fraud.score_new_returns_batch()..."
    bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet "CALL \`retail_fraud.score_new_returns_batch\`();"
    echo "   ✅ Lab I pipeline tables materialized."

    echo "▶ [Full Mode] Materializing Lab II pipeline tables (03 -> 06)..."
    for script in 03_async_enrichment_pipeline.sql 04_root_cause_analysis.sql 06_simulate_new_reviews.sql; do
      echo "   Running product_analytics/sql/${script}..."
      bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet < "product_analytics/sql/${script}"
    done
    echo "   Enriching newly simulated reviews via mfg_quality_demo.enrich_new_reviews()..."
    bq query --project_id="${ACTIVE_PROJECT}" --location="${LOCATION}" --use_legacy_sql=false --quiet "CALL \`mfg_quality_demo.enrich_new_reviews\`();"
    echo "   ✅ Lab II pipeline tables materialized."
  fi

  echo ""
  echo "🎉 Bootstrap complete! The Qwiklabs environment is ready for Lab I and Lab II."
  echo "   👉 Lab I Walkthrough  : retail_fraud/WALKTHROUGH.md"
  echo "   👉 Lab II Walkthrough : product_analytics/DEMO_WALKTHROUGH.md"

elif [[ "${MODE}" == "--project" ]]; then
  if [[ $# -lt 2 ]]; then usage; fi
  TARGET_PROJECT="$2"
  TARGET_CONN="${4:-eu.vertex_ai_conn}"

  echo "============================================================================="
  echo "🔧 Configuring active project & connection"
  echo "   Target Project ID : ${TARGET_PROJECT}"
  echo "   Connection ID     : ${TARGET_CONN}"
  echo "============================================================================="

  gcloud config set project "${TARGET_PROJECT}"

  find retail_fraud/sql product_analytics/sql -name "*.sql" -exec sed -i \
    -e "s/[0-9a-zA-Z_-]*\.*eu\.vertex_ai_conn/${TARGET_CONN}/g" {} +

  echo "  ✅ Active project set to ${TARGET_PROJECT} and SQL connection IDs set to ${TARGET_CONN}."
else
  usage
fi
