#!/usr/bin/env bash
# Tear down everything bootstrap.sh stood up.
# Order: delete Argo CD applications first (so prune doesn't fight terraform destroy),
# then terraform destroy.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${ROOT_DIR}/infra/terraform"

PROJECT_ID="${PROJECT_ID:-smart-hr-demo-499522}"
REGION="${REGION:-asia-northeast1}"
AUTOPILOT_CLUSTER="${AUTOPILOT_CLUSTER:-smarthr-autopilot}"

log() { printf '\033[1;34m[teardown]\033[0m %s\n' "$*"; }

read -r -p "About to destroy all demo infrastructure in project ${PROJECT_ID}. Type 'destroy' to confirm: " confirm
if [[ "${confirm}" != "destroy" ]]; then
  log "aborted."
  exit 0
fi

# Best-effort delete of ApplicationSets — keeps prune from creating ghosts.
log "Trying to clean ApplicationSets on ${AUTOPILOT_CLUSTER}…"
if gcloud container clusters get-credentials "${AUTOPILOT_CLUSTER}" --region "${REGION}" --project "${PROJECT_ID}" 2>/dev/null; then
  kubectl delete applicationset --all -n argocd --ignore-not-found --wait=false || true
fi

log "terraform destroy…"
( cd "${TF_DIR}" && terraform destroy -auto-approve )

log "Done. The GitHub repo (tayzar-tznw/gke-argocd) and Artifact Registry images are NOT deleted."
log "Delete the repo with: gh repo delete tayzar-tznw/gke-argocd --yes"
