#!/usr/bin/env bash
# Bootstrap the SmartHR GKE demo end-to-end.
#
# Steps:
#   1. enable required GCP APIs
#   2. terraform apply (VPC, Artifact Registry, both clusters, WIF)
#   3. fetch credentials for each cluster
#   4. install ArgoCD + KEDA + cluster bootstrap manifests on each cluster
#   5. apply per-cluster ApplicationSet so ArgoCD takes over reconciliation
#
# Idempotent — safe to re-run.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="${ROOT_DIR}/infra/terraform"

PROJECT_ID="${PROJECT_ID:-smart-hr-demo-499522}"
REGION="${REGION:-asia-northeast1}"
ZONE="${ZONE:-asia-northeast1-a}"
AUTOPILOT_CLUSTER="${AUTOPILOT_CLUSTER:-smarthr-autopilot}"
STANDARD_CLUSTER="${STANDARD_CLUSTER:-smarthr-standard}"

log()   { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
abort() { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

# --- prereq check ---
for cmd in gcloud terraform kubectl gke-gcloud-auth-plugin; do
  command -v "$cmd" >/dev/null 2>&1 || abort "missing prereq: $cmd"
done

log "Using project=${PROJECT_ID} region=${REGION}"
gcloud config set project "${PROJECT_ID}" >/dev/null

# --- 1. enable APIs ---
log "Enabling GCP APIs (idempotent)…"
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com \
  sts.googleapis.com \
  --project="${PROJECT_ID}"

# --- 2. terraform apply ---
log "terraform init…"
( cd "${TF_DIR}" && terraform init -input=false )

log "terraform apply… (this takes ~10 minutes for the two clusters)"
( cd "${TF_DIR}" && terraform apply -auto-approve -input=false )

# --- 3. get cluster credentials ---
log "Fetching cluster credentials"
gcloud container clusters get-credentials "${AUTOPILOT_CLUSTER}" --region "${REGION}"
AUTOPILOT_CTX="gke_${PROJECT_ID}_${REGION}_${AUTOPILOT_CLUSTER}"

gcloud container clusters get-credentials "${STANDARD_CLUSTER}" --zone "${ZONE}"
STANDARD_CTX="gke_${PROJECT_ID}_${ZONE}_${STANDARD_CLUSTER}"

# --- 4-5. bootstrap each cluster ---
bootstrap_cluster() {
  local ctx="$1" flavor="$2"
  log "==> Bootstrapping ${ctx} (flavor=${flavor})"

  log "Installing Argo CD"
  kubectl --context "${ctx}" apply -k "${ROOT_DIR}/platform/argocd/install/"
  log "Waiting for Argo CD CRDs"
  kubectl --context "${ctx}" wait --for=condition=Established \
    crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io \
    --timeout=120s
  log "Waiting for argocd-server"
  kubectl --context "${ctx}" -n argocd rollout status deploy/argocd-server --timeout=300s

  log "Installing KEDA"
  kubectl --context "${ctx}" apply -k "${ROOT_DIR}/platform/keda/install/"
  log "Waiting for KEDA CRDs"
  kubectl --context "${ctx}" wait --for=condition=Established \
    crd/scaledobjects.keda.sh --timeout=120s
  log "Waiting for KEDA operator"
  kubectl --context "${ctx}" -n keda rollout status deploy/keda-operator --timeout=300s

  log "Applying tenant namespaces, quotas, network policies"
  kubectl --context "${ctx}" apply -k "${ROOT_DIR}/platform/cluster-bootstrap/"

  log "Applying Argo CD AppProjects"
  kubectl --context "${ctx}" apply -f "${ROOT_DIR}/platform/argocd/projects/"

  log "Applying ApplicationSet (flavor=${flavor})"
  kubectl --context "${ctx}" apply -f "${ROOT_DIR}/platform/argocd/appsets/${flavor}.yaml"

  log "${ctx}: bootstrap complete. Argo CD will now reconcile tenant workloads from git."
}

bootstrap_cluster "${AUTOPILOT_CTX}" autopilot
bootstrap_cluster "${STANDARD_CTX}"  standard

log ""
log "==> All done. Useful follow-ups:"
log "  kubectl --context ${AUTOPILOT_CTX} -n argocd port-forward svc/argocd-server 8080:80"
log "  open http://localhost:8080  # admin pwd: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
log "  watch -n2 kubectl --context ${AUTOPILOT_CTX} get application -n argocd"
log ""
log "Trigger KEDA scale-from-zero (on autopilot cluster):"
log "  kubectl --context ${AUTOPILOT_CTX} -n oke exec -it deploy/redis -- \\"
log "    redis-cli RPUSH document-build-queue \$(seq 1 50 | tr '\\n' ' ')"
log ""
log "Outputs from terraform:"
( cd "${TF_DIR}" && terraform output )
