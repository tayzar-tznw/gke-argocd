# SmartHR GKE migration — demo & sample code

This repository is a working demonstration of the **Cloud Run + App Engine → GKE + ArgoCD + KEDA** migration designed for SmartHR's two Rails services (`hanica` and `oke`). It stands up the target architecture in a sandbox GCP project, deploys the topology from `mutitanency.png` exactly, and shows the GitOps CD pipeline end-to-end.

## What this repo deploys

```
                          ┌────────────────────────────┐
                          │       GCP project (demo)   │
                          │                            │
                          │   ┌──────────────────────┐ │
                          │   │  smarthr-autopilot   │ │
                          │   │  (GKE Autopilot)     │ │
                          │   │                      │ │
                          │   │  hanica  oke         │ │
                          │   │  argocd  keda        │ │
                          │   └──────────────────────┘ │
                          └────────────────────────────┘
```

ArgoCD reconciles all tenant workloads from this repo. KEDA scales the `oke` workers on queue depth and on a cron schedule (modeling the "predictable spike" pattern in `project.md`).

See [`WHY_AUTOPILOT.md`](WHY_AUTOPILOT.md) for the rationale behind the Autopilot-only decision.

## Single repo, simulated 4-repo layout

The directory layout under `repos/` mirrors SmartHR's intended **four-repo production structure**: `hanica`, `oke`, `smarthr-terraform`, `gke-argocd`. Each subdirectory contains a README explaining what its real-life counterpart would hold. Read [`MULTI_REPO_LAYOUT.md`](MULTI_REPO_LAYOUT.md) first to understand the structure before diving in.

## Prerequisites

- GCP project `smart-hr-demo-499522` (or set `PROJECT_ID` env var)
- IAM permissions: `Owner` or equivalent in the project
- `gcloud`, `terraform >= 1.5`, `kubectl`, `gke-gcloud-auth-plugin`, `gh` on PATH
- Authenticated: `gcloud auth login` and `gcloud auth application-default login`

## Quickstart

```bash
# from the repo root
./repos/gke-argocd/scripts/bootstrap.sh
```

This enables APIs, runs `terraform apply` against `repos/smarthr-terraform/environments/smarthr-gke-demo/` (state in GCS), installs ArgoCD + KEDA on the resulting cluster, applies tenant bootstrapping, and hands the rest to ArgoCD.

To open the ArgoCD UI:
```bash
kubectl config use-context gke_smart-hr-demo-499522_asia-northeast1_smarthr-autopilot
kubectl -n argocd port-forward svc/argocd-server 8080:80
# user: admin
# pwd:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

To trip the KEDA scaler:
```bash
kubectl -n oke exec deploy/redis -- \
  redis-cli RPUSH document-build-queue $(seq 1 50 | tr '\n' ' ')
watch -n2 'kubectl -n oke get scaledobject,pods -l app.kubernetes.io/name=document-build-worker'
```

To tear down:
```bash
./repos/gke-argocd/scripts/teardown.sh
```

## Repo layout

| Path | What lives here |
|---|---|
| `repos/hanica/` | hanica source repo (simulated) — Dockerfile, illustrative CI |
| `repos/oke/` | oke source repo (simulated) — Dockerfile, illustrative CI |
| `repos/smarthr-terraform/environments/smarthr-gke-demo/` | **Live** terraform for this demo (VPC, NAT, AR, GKE, WIF). State in GCS. |
| `repos/smarthr-terraform/environments/another-service-example/` | Placeholder showing multi-service layout |
| `repos/smarthr-terraform/modules/` | Placeholder explaining the shared-modules pattern |
| `repos/smarthr-terraform/.github/workflows/` | Illustrative TF plan/apply CD pipeline |
| `repos/gke-argocd/platform/` | ArgoCD install, KEDA install, cluster bootstrap (namespaces, quotas, NetPols) |
| `repos/gke-argocd/tenants/hanica/` | hanica web tier manifests |
| `repos/gke-argocd/tenants/oke/` | oke document-gen manifests + KEDA ScaledObjects + Redis |
| `repos/gke-argocd/scripts/` | `bootstrap.sh`, `teardown.sh` |
| `.github/workflows/` (root) | The **real** workflows that drive this demo: ci-hanica, ci-oke, validate |
| `docs/` | This file + MULTI_REPO_LAYOUT.md, DEMO.md, ARCHITECTURE.md, WHY_AUTOPILOT.md |

## What this demo is for

To convince SmartHR's engineering team that the target architecture in `project.md` is real, reproducible, and operationally tractable — *and* to show them the canonical repo layout they should adopt when introducing ArgoCD.

See `docs/DEMO.md` for the live-walkthrough script.

## Cost while running

Roughly **$0.40–0.60/hour** with the placeholder workloads in `asia-northeast1`:

| Item | Hourly |
|---|---|
| Autopilot regional control plane | $0 |
| Autopilot pod consumption (~3–5 vCPU, 6–10 GiB) | ~$0.30–0.50 |
| External LB + NAT | ~$0.08 |
| **Total** | **~$0.40–0.60/hour** |

`./repos/gke-argocd/scripts/teardown.sh` makes it one command to stop the spend.
