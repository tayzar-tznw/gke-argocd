# SmartHR GKE migration — demo & sample code

This repository is a working demonstration of the **Cloud Run + App Engine → GKE + ArgoCD + KEDA** migration designed for SmartHR's two Rails services (`hanica` and `oke`). It stands up the target architecture in a sandbox GCP project, deploys the topology from `mutitanency.png` exactly, and shows the GitOps CD pipeline end-to-end.

## What this repo deploys

```
                          ┌────────────────────────────────────────┐
                          │           GCP project (demo)           │
                          │                                        │
            ┌─────────────┴────────┐                ┌──────────────┴─────────┐
            │   smarthr-autopilot  │                │     smarthr-standard   │
            │  (GKE Autopilot)     │                │  (GKE Standard, zonal) │
            │                      │                │  default-pool +        │
            │                      │                │  io-heavy-pool (taint) │
            └──────────┬───────────┘                └────────────┬───────────┘
                       │                                         │
                       ▼                                         ▼
            ┌────────────────────────────────────────────────────────────┐
            │             same manifest base, two overlays               │
            │  hanica  oke  argocd  keda  (matches mutitanency.png)      │
            └────────────────────────────────────────────────────────────┘
```

Both clusters are reconciled by ArgoCD from this repo. KEDA scales the `oke` workers on queue depth and on a cron schedule (modeling the "predictable spike" pattern in `project.md`).

## Prerequisites

- GCP project `smart-hr-demo-499522` (or set `PROJECT_ID` env var)
- IAM permissions: `Owner` or equivalent in the project
- `gcloud`, `terraform >= 1.5`, `kubectl`, `gke-gcloud-auth-plugin`, `gh` on PATH
- Authenticated: `gcloud auth login` and `gcloud auth application-default login`

## Quickstart

```bash
# from the repo root
./scripts/bootstrap.sh
```

This enables APIs, terraforms the clusters, installs ArgoCD + KEDA, applies tenant bootstrapping (namespaces, quotas, NetPols), and hands the rest to ArgoCD.

To open ArgoCD UI on the Autopilot cluster:
```bash
kubectl config use-context gke_smart-hr-demo-499522_asia-northeast1_smarthr-autopilot
kubectl -n argocd port-forward svc/argocd-server 8080:80
# user: admin
# pwd:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

To trip the KEDA scaler:
```bash
kubectl -n oke exec -it deploy/redis -- \
  redis-cli RPUSH document-build-queue $(seq 1 50 | tr '\n' ' ')
watch -n2 kubectl -n oke get scaledobject,pods -l app.kubernetes.io/name=document-build-worker
```

To tear down:
```bash
./scripts/teardown.sh
```

## Repo layout

| Path | What lives here |
|---|---|
| `infra/terraform/` | VPC, NAT, Artifact Registry, both GKE clusters, Workload Identity Federation pool |
| `platform/argocd/` | ArgoCD install kustomization, per-tenant AppProjects, per-cluster ApplicationSets |
| `platform/keda/` | KEDA install (upstream v2.20.1) |
| `platform/cluster-bootstrap/` | Tenant namespaces, ResourceQuotas, LimitRanges, NetworkPolicies |
| `tenants/hanica/` | hanica web tier — Kustomize base + per-cluster overlays |
| `tenants/oke/` | oke document-gen tier — base + overlays, plus KEDA ScaledObjects and Redis |
| `apps/hanica-sample/` | Placeholder Dockerfile the CI workflow builds |
| `apps/oke-sample/` | Placeholder oke worker Dockerfile |
| `.github/workflows/` | PR validate + per-service CI workflows (build → push → tag bump → ArgoCD) |
| `scripts/` | `bootstrap.sh`, `teardown.sh` |
| `docs/` | This file, `DEMO.md`, `ARCHITECTURE.md`, `AUTOPILOT_VS_STANDARD.md` |

## What this demo is for

To convince SmartHR's engineering team that the target architecture in `project.md` is real, reproducible, and operationally tractable — without requiring them to first commit to a final cluster mode. They can run hanica on Autopilot, oke on Standard, or both on either. The same manifests work.

See `docs/DEMO.md` for the live-walkthrough script and `docs/AUTOPILOT_VS_STANDARD.md` for the side-by-side comparison.

## Cost while running

Roughly **$0.45/hour** with the placeholder workloads in `asia-northeast1`:

| Item | Hourly |
|---|---|
| Autopilot regional control plane | $0 |
| Autopilot pod consumption (~3 vCPU, 6 GiB) | ~$0.30 |
| Standard zonal control plane | $0 |
| Standard nodes (1× e2-standard-2 active) | ~$0.07 |
| External LB + NAT | ~$0.08 |
| **Total** | **~$0.45/hour** |

`./scripts/teardown.sh` makes it one command to stop the spend.
