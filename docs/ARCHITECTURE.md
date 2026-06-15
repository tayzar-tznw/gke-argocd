# Architecture mapping — diagram → file

Each element in `mutitanency.png` and the To-Be diagrams in `project.md` maps to one or more files in this repo.

## Cluster + infrastructure

| Diagram element | File(s) |
|---|---|
| GKE cluster (Autopilot) | `infra/terraform/gke.tf` → `google_container_cluster.autopilot` |
| GKE cluster (Standard) | `infra/terraform/gke.tf` → `google_container_cluster.standard` + node pools |
| VPC + Cloud NAT | `infra/terraform/vpc.tf` |
| Artifact Registry | `infra/terraform/artifact_registry.tf` |
| Workload Identity Federation (GitHub → GCP) | `infra/terraform/wif.tf` |
| GKE Workload Identity (KSA → GSA) | `infra/terraform/wif.tf` → `google_service_account.hanica_runtime` + `tenants/hanica/base/serviceaccount.yaml` |

## Namespace: hanica (`mutitanency.png`)

| Diagram Deployment | File |
|---|---|
| `app` | `tenants/hanica/base/deployment-app.yaml` |
| `tsukekae` | `tenants/hanica/base/deployment-tsukekae.yaml` |
| `worker` | `tenants/hanica/base/deployment-worker.yaml` |
| `io-heavy-worker` | `tenants/hanica/base/deployment-io-heavy-worker.yaml` |
| `1-thread-worker` | `tenants/hanica/base/deployment-1-thread-worker.yaml` |

Supporting:
- Service + Ingress: `tenants/hanica/base/{service,ingress}.yaml`
- HPA on `app`: `tenants/hanica/base/hpa.yaml`
- KSA for Workload Identity: `tenants/hanica/base/serviceaccount.yaml`
- Per-cluster overrides: `tenants/hanica/overlays/{standard,autopilot}/`

## Namespace: oke (`mutitanency.png`)

| Diagram Deployment | File | KEDA scaler |
|---|---|---|
| `app` | `tenants/oke/base/deployment-app.yaml` | — (HPA-eligible) |
| `tsukekae` | `tenants/oke/base/deployment-tsukekae.yaml` | — |
| `signing-path-function` | `tenants/oke/base/deployment-signing-path-function.yaml` | — |
| `document-build-worker` | `tenants/oke/base/deployment-document-build-worker.yaml` | Redis list |
| `notifier-worker` | `tenants/oke/base/deployment-notifier-worker.yaml` | Redis list |
| `io-heavy-worker` | `tenants/oke/base/deployment-io-heavy-worker.yaml` | Redis list |
| `document-download-worker` | `tenants/oke/base/deployment-document-download-worker.yaml` | Redis list |
| `mailer-worker` | `tenants/oke/base/deployment-mailer-worker.yaml` | Cron |
| `cert-update-worker` | `tenants/oke/base/deployment-cert-update-worker.yaml` | Cron |

Supporting:
- All ScaledObjects: `tenants/oke/base/scaledobjects.yaml`
- In-cluster Redis (queue backend for the demo): `tenants/oke/base/redis.yaml`
- Service + Ingress: `tenants/oke/base/{service,ingress}.yaml`
- Per-cluster overrides: `tenants/oke/overlays/{standard,autopilot}/`

## Namespace: argocd

Installed from upstream Argo CD v3.4.3 manifests via `platform/argocd/install/kustomization.yaml`. Contains:
- `argocd-server`
- `argocd-repo-server`
- `argocd-application-controller` (StatefulSet)
- `argocd-redis`
- AppProjects: `platform/argocd/projects/{hanica,oke,platform}.yaml`
- ApplicationSets (per cluster): `platform/argocd/appsets/{autopilot,standard}.yaml`

## Namespace: keda

Installed from upstream KEDA v2.20.1 manifest via `platform/keda/install/kustomization.yaml`. Contains:
- `keda-operator`
- `keda-metrics-apiserver`
- `keda-admission-webhooks`

## CD pipeline (`hanica-cd-to-be.png` / `oke-cd-to-be.png`)

| Pipeline step | File |
|---|---|
| Validate PRs (kubeconform + kustomize build) | `.github/workflows/validate.yml` |
| hanica: build + push + tag bump + Apollo stub + Slack | `.github/workflows/ci-hanica.yml` |
| oke: build + push + readonly-perms stub + tag bump + Slack | `.github/workflows/ci-oke.yml` |
| Sample Dockerfile (hanica) | `apps/hanica-sample/Dockerfile` |
| Sample Dockerfile (oke worker) | `apps/oke-sample/Dockerfile` |
| Image-tag bump target | `tenants/{hanica,oke}/overlays/*/kustomization.yaml` (the `images:` block) |
| Manual approval gate | GitHub Environment `production` with required reviewer |

## Multi-tenancy primitives

| Concern | File |
|---|---|
| Tenant namespaces (with Pod Security Standards) | `platform/cluster-bootstrap/namespaces.yaml` |
| Per-tenant CPU/memory ceilings | `platform/cluster-bootstrap/quotas.yaml` (ResourceQuota + LimitRange) |
| Default-deny + same-ns allow + LB healthcheck allow | `platform/cluster-bootstrap/netpols.yaml` |
| ArgoCD AppProject scoping | `platform/argocd/projects/{hanica,oke,platform}.yaml` |
