#!/usr/bin/env bash
# ==============================================================================
# Applied AI & Data Hackathon - Cleanup Script
# Removes all BigQuery datasets, models, property graphs, Cloud Resource
# Connections, and Cloud Storage buckets created during Lab 1 and Lab 2.
#
# Usage:
#   ./cleanup_hackathon.sh [PROJECT_ID] [-y|--yes]
# ==============================================================================

set -euo pipefail

PROJECT_ID=""
AUTO_APPROVE=false

for arg in "$@"; do
  case "$arg" in
    -y|--yes)
      AUTO_APPROVE=true
      ;;
    *)
      if [[ -z "${PROJECT_ID}" ]]; then
        PROJECT_ID="$arg"
      fi
      ;;
  esac
done

if [[ -z "${PROJECT_ID}" ]]; then
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
fi

if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "❌ Error: No active Google Cloud project detected."
  echo "Usage: ./cleanup_hackathon.sh [PROJECT_ID] [-y|--yes]"
  exit 1
fi

LOCATION="US"
CONN_ID="vertex_ai_conn"
RESERVATION_ID="${RESERVATION_ID:-my-reservation}"
EVIDENCE_BUCKET="gs://${PROJECT_ID}-fraud-evidence"

echo "================================================================================"
echo "🧹 Applied AI & Data Hackathon - Resource Cleanup"
echo "   Target GCP Project : ${PROJECT_ID}"
echo "   Region             : ${LOCATION}"
echo "--------------------------------------------------------------------------------"
echo "The following resources will be permanently deleted if present:"
echo "  1. BigQuery Dataset : ${PROJECT_ID}:retail_fraud (tables, BQML models, graphs)"
echo "  2. BigQuery Dataset : ${PROJECT_ID}:mfg_quality_demo (tables, embeddings, models)"
echo "  3. BQ Connection    : ${PROJECT_ID}.${LOCATION}.${CONN_ID}"
echo "  4. BQ Reservation   : ${PROJECT_ID}:${LOCATION}.${RESERVATION_ID} (+ assignments)"
echo "  5. GCS Bucket       : ${EVIDENCE_BUCKET}"
echo "================================================================================"

if [[ "${AUTO_APPROVE}" != "true" && -t 0 ]]; then
  read -r -p "Proceed with cleanup on project '${PROJECT_ID}'? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      echo "Cleanup cancelled."
      exit 0
      ;;
  esac
fi

echo ""
echo "🗑️  [1/5] Removing BigQuery dataset 'retail_fraud'..."
if bq show --project_id="${PROJECT_ID}" "retail_fraud" >/dev/null 2>&1; then
  bq rm -r -f -d "${PROJECT_ID}:retail_fraud"
  echo "   ✅ Deleted dataset '${PROJECT_ID}:retail_fraud'."
else
  echo "   ℹ️  Dataset '${PROJECT_ID}:retail_fraud' not found (already deleted)."
fi

echo ""
echo "🗑️  [2/5] Removing BigQuery dataset 'mfg_quality_demo'..."
if bq show --project_id="${PROJECT_ID}" "mfg_quality_demo" >/dev/null 2>&1; then
  bq rm -r -f -d "${PROJECT_ID}:mfg_quality_demo"
  echo "   ✅ Deleted dataset '${PROJECT_ID}:mfg_quality_demo'."
else
  echo "   ℹ️  Dataset '${PROJECT_ID}:mfg_quality_demo' not found (already deleted)."
fi

echo ""
echo "🗑️  [3/5] Removing BigQuery Cloud Resource Connection '${CONN_ID}'..."
if bq show --connection --location="${LOCATION}" --project_id="${PROJECT_ID}" "${CONN_ID}" >/dev/null 2>&1; then
  bq rm --connection --force --location="${LOCATION}" --project_id="${PROJECT_ID}" "${CONN_ID}"
  echo "   ✅ Deleted connection '${LOCATION}.${CONN_ID}'."
else
  echo "   ℹ️  Connection '${LOCATION}.${CONN_ID}' not found (already deleted)."
fi

echo ""
echo "🗑️  [4/5] Removing BigQuery Reservation '${RESERVATION_ID}' and assignments..."
if bq show --project_id="${PROJECT_ID}" --location="${LOCATION}" --reservation "${RESERVATION_ID}" >/dev/null 2>&1; then
  ASSIGNMENTS=$(bq ls --format=json --project_id="${PROJECT_ID}" --location="${LOCATION}" --reservation_assignment "${PROJECT_ID}:${LOCATION}.${RESERVATION_ID}" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(' '.join(a['name'].split('.')[-1] for a in data if 'name' in a))" 2>/dev/null || echo "")
  for aid in ${ASSIGNMENTS}; do
    bq rm --project_id="${PROJECT_ID}" --location="${LOCATION}" --reservation_assignment "${RESERVATION_ID}.${aid}" >/dev/null 2>&1 || true
  done
  bq rm --project_id="${PROJECT_ID}" --location="${LOCATION}" --reservation "${RESERVATION_ID}" >/dev/null 2>&1 || true
  echo "   ✅ Deleted reservation '${PROJECT_ID}:${LOCATION}.${RESERVATION_ID}' and its assignments."
else
  echo "   ℹ️  Reservation '${PROJECT_ID}:${LOCATION}.${RESERVATION_ID}' not found (already deleted)."
fi

echo ""
echo "🗑️  [5/5] Removing Cloud Storage bucket '${EVIDENCE_BUCKET}'..."
if gcloud storage buckets describe "${EVIDENCE_BUCKET}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage rm -r "${EVIDENCE_BUCKET}" --project="${PROJECT_ID}"
  echo "   ✅ Deleted bucket '${EVIDENCE_BUCKET}'."
else
  echo "   ℹ️  Bucket '${EVIDENCE_BUCKET}' not found (already deleted)."
fi

echo ""
echo "================================================================================"
echo "✅ Cleanup completed successfully for project: ${PROJECT_ID}"
echo "================================================================================"
