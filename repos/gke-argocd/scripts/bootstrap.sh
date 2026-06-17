#!/usr/bin/env bash
# Bootstrap the SmartHR GKE demo end-to-end.
#
# In real life:
#   - `terraform apply` is run from the smarthr-terraform repo's CD pipeline,
#     not from this script. It creates the GCP infra (VPC, AR, GKE cluster, WIF).
#   - This bootstrap script lives in the gke-argocd repo and only installs the
#     in-cluster pieces (ArgoCD, KEDA, namespaces, ApplicationSet).
#
# For the all-in-one demo, this script does BOTH so you can stand the whole
# thing up with one command. The terraform step is clearly marked.
#
# Idempotent — safe to re-run.

set -euo pipefail

# REPO_ROOT = the top of the gitops repo (one level above this gke-argocd subdir)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GKE_ARGOCD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${GKE_ARGOCD_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/repos/smarthr-terraform/environments/smarthr-gke-demo"

PROJECT_ID="${PROJECT_ID:-smart-hr-demo-499522}"
REGION="${REGION:-asia-northeast1}"
AUTOPILOT_CLUSTER="${AUTOPILOT_CLUSTER:-smarthr-autopilot}"

log()   { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
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

# --- 2. terraform apply (lives in smarthr-terraform/ in real life) ---
log "terraform init (state in GCS bucket smarthr-gke-tfstate-87614275791)…"
( cd "${TF_DIR}" && terraform init -input=false )

log "terraform apply… (~7 minutes for the Autopilot cluster)"
( cd "${TF_DIR}" && terraform apply -auto-approve -input=false )

# --- 3. get cluster credentials ---
log "Fetching cluster credentials"
gcloud container clusters get-credentials "${AUTOPILOT_CLUSTER}" --region "${REGION}"
CTX="gke_${PROJECT_ID}_${REGION}_${AUTOPILOT_CLUSTER}"

# --- 4-5. bootstrap the cluster (this is what lives in the gke-argocd repo) ---
log "==> Bootstrapping ${CTX}"

log "Installing Argo CD"
# --server-side avoids the "annotations: Too long: may not be more than 262144 bytes"
# error on the ArgoCD CRDs (they have very large OpenAPI schemas).
kubectl --context "${CTX}" apply -k "${GKE_ARGOCD_DIR}/platform/argocd/install/" --server-side --force-conflicts
log "Waiting for Argo CD CRDs"
kubectl --context "${CTX}" wait --for=condition=Established \
  crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io \
  --timeout=120s
log "Waiting for argocd-server"
kubectl --context "${CTX}" -n argocd rollout status deploy/argocd-server --timeout=300s

log "Installing KEDA"
kubectl --context "${CTX}" apply -k "${GKE_ARGOCD_DIR}/platform/keda/install/" --server-side --force-conflicts
log "Waiting for KEDA CRDs"
kubectl --context "${CTX}" wait --for=condition=Established \
  crd/scaledobjects.keda.sh --timeout=120s
log "Waiting for KEDA operator"
kubectl --context "${CTX}" -n keda rollout status deploy/keda-operator --timeout=300s

log "Applying tenant namespaces, quotas, network policies"
kubectl --context "${CTX}" apply -k "${GKE_ARGOCD_DIR}/platform/cluster-bootstrap/"

log "Applying Argo CD AppProjects"
kubectl --context "${CTX}" apply -f "${GKE_ARGOCD_DIR}/platform/argocd/projects/"

log "Applying ApplicationSet"
kubectl --context "${CTX}" apply -f "${GKE_ARGOCD_DIR}/platform/argocd/appsets/autopilot.yaml"

log "Bootstrap complete. Argo CD will now reconcile tenant workloads from git."

log ""
log "==> Useful follow-ups:"
log "  kubectl --context ${CTX} -n argocd port-forward svc/argocd-server 8080:80"
log "  open http://localhost:8080  # admin pwd: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
log "  watch -n2 kubectl --context ${CTX} get application -n argocd"
log ""
log "Trigger KEDA scale-from-zero:"
log "  kubectl --context ${CTX} -n oke exec deploy/redis -- \\"
log "    redis-cli RPUSH document-build-queue \$(seq 1 50 | tr '\\n' ' ')"
log ""
log "Outputs from terraform:"
( cd "${TF_DIR}" && terraform output )
