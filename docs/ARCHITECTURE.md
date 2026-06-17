# Architecture mapping — diagram → file

Each element in `mutitanency.png` and the To-Be diagrams in `project.md` maps to one or more files in this repo. Paths assume the single-repo demo layout (with the `repos/` simulation); in SmartHR's real-life setup, drop the `repos/<name>/` prefix.

## Cluster + infrastructure

> Lives in real life under `smarthr/smarthr-terraform`. In this demo: `repos/smarthr-terraform/environments/smarthr-gke-demo/`.

| Diagram element | File(s) |
|---|---|
| GKE cluster (Autopilot) | `gke.tf` → `google_container_cluster.autopilot` |
| VPC + Cloud NAT | `vpc.tf` |
| Artifact Registry | `artifact_registry.tf` |
| Workload Identity Federation (GitHub → GCP) | `wif.tf` |
| GKE Workload Identity (KSA → GSA for hanica) | `wif.tf` → `google_service_account.hanica_runtime` + `repos/gke-argocd/tenants/hanica/base/serviceaccount.yaml` |
| Terraform state | GCS bucket `smarthr-gke-tfstate-87614275791` (`backend.tf`) |

## Namespace: hanica (`mutitanency.png`)

> Lives in real life under `smarthr/gke-argocd`. In this demo: `repos/gke-argocd/tenants/hanica/base/`.

| Diagram Deployment | File |
|---|---|
| `app` | `deployment-app.yaml` |
| `tsukekae` | `deployment-tsukekae.yaml` |
| `worker` | `deployment-worker.yaml` |
| `io-heavy-worker` | `deployment-io-heavy-worker.yaml` |
| `1-thread-worker` | `deployment-1-thread-worker.yaml` |

Supporting (same directory):
- Service + Ingress: `service.yaml`, `ingress.yaml`
- HPA on `app`: `hpa.yaml`
- KSA for Workload Identity: `serviceaccount.yaml`
- Overlay (per-env overrides): `repos/gke-argocd/tenants/hanica/overlays/autopilot/`

## Namespace: oke (`mutitanency.png`)

> Lives in `repos/gke-argocd/tenants/oke/base/`.

| Diagram Deployment | File | KEDA scaler |
|---|---|---|
| `app` | `deployment-app.yaml` | — (HPA-eligible) |
| `tsukekae` | `deployment-tsukekae.yaml` | — |
| `signing-path-function` | `deployment-signing-path-function.yaml` | — |
| `document-build-worker` | `deployment-document-build-worker.yaml` | Redis list |
| `notifier-worker` | `deployment-notifier-worker.yaml` | Redis list |
| `io-heavy-worker` | `deployment-io-heavy-worker.yaml` | Redis list |
| `document-download-worker` | `deployment-document-download-worker.yaml` | Redis list |
| `mailer-worker` | `deployment-mailer-worker.yaml` | Cron |
| `cert-update-worker` | `deployment-cert-update-worker.yaml` | Cron |

Supporting:
- All ScaledObjects: `scaledobjects.yaml`
- In-cluster Redis (queue backend for the demo): `redis.yaml`
- Service + Ingress: `service.yaml`, `ingress.yaml`
- Overlay: `repos/gke-argocd/tenants/oke/overlays/autopilot/`

## Namespace: argocd

Installed from upstream Argo CD v3.4.3 manifests via `repos/gke-argocd/platform/argocd/install/kustomization.yaml`. Contains:
- `argocd-server`
- `argocd-repo-server`
- `argocd-application-controller` (StatefulSet)
- `argocd-redis`
- AppProjects: `repos/gke-argocd/platform/argocd/projects/{hanica,oke,platform}.yaml`
- ApplicationSet: `repos/gke-argocd/platform/argocd/appsets/autopilot.yaml`

## Namespace: keda

Installed from upstream KEDA v2.20.1 manifest via `repos/gke-argocd/platform/keda/install/kustomization.yaml`.

## CD pipeline (`hanica-cd-to-be.png` / `oke-cd-to-be.png`)

### Real-life flow (4 repos)

| Pipeline step | Real-life file | Demo file (illustrative) |
|---|---|---|
| hanica CI: build + push + open bump PR | `smarthr/hanica/.github/workflows/ci.yml` | `repos/hanica/.github/workflows/ci.yml` |
| oke CI: build + push + open bump PR | `smarthr/oke/.github/workflows/ci.yml` | `repos/oke/.github/workflows/ci.yml` |
| TF plan on PR | `smarthr/smarthr-terraform/.github/workflows/plan.yml` | `repos/smarthr-terraform/.github/workflows/plan.yml` |
| TF apply on merge to main | `smarthr/smarthr-terraform/.github/workflows/apply.yml` | `repos/smarthr-terraform/.github/workflows/apply.yml` |
| Manifest validation on PR | `smarthr/gke-argocd/.github/workflows/validate.yml` | `repos/gke-argocd/.github/workflows/validate.yml` |
| Manual approval gate | GitHub Environment `production` with required reviewer on the `apply.yml` AND on the manifest-bump PR merge |

### Demo's real (running) workflows

Because GitHub Actions only fires from `.github/workflows/` at the repo root, this single-repo demo has a *second* set of workflows at the root that do the same job but within one repo:

| Pipeline step | File |
|---|---|
| Validate PRs (kubeconform + kustomize build) | `.github/workflows/validate.yml` |
| hanica: build + push + tag bump | `.github/workflows/ci-hanica.yml` |
| oke: build + push + tag bump | `.github/workflows/ci-oke.yml` |

See [`MULTI_REPO_LAYOUT.md`](MULTI_REPO_LAYOUT.md) for the full explanation of the two-layer workflow scheme.

## Multi-tenancy primitives

| Concern | File |
|---|---|
| Tenant namespaces (with Pod Security Standards) | `repos/gke-argocd/platform/cluster-bootstrap/namespaces.yaml` |
| Per-tenant CPU/memory ceilings | `repos/gke-argocd/platform/cluster-bootstrap/quotas.yaml` |
| Default-deny + same-ns allow + LB healthcheck allow | `repos/gke-argocd/platform/cluster-bootstrap/netpols.yaml` |
| ArgoCD AppProject scoping | `repos/gke-argocd/platform/argocd/projects/{hanica,oke,platform}.yaml` |
