# Multi-repo layout — the canonical structure for SmartHR

## TL;DR

In production, SmartHR's GitOps setup should be **four GitHub repositories**:

1. `smarthr/hanica` — Rails source + Dockerfile + CI
2. `smarthr/oke` — Rails source + Dockerfile + CI
3. `smarthr/smarthr-terraform` — shared multi-service infrastructure, CD-driven `terraform apply` on merge to main
4. `smarthr/gke-argocd` — GitOps manifests (Kustomize bases + overlays, ArgoCD AppProjects + ApplicationSets, KEDA + cluster-bootstrap)

This demo lives in **one** repo (`tayzar-tznw/gke-argocd`) but mirrors the 4-repo shape internally via `repos/{hanica, oke, smarthr-terraform, gke-argocd}/` subdirectories. That way SmartHR can see the structure of all four side-by-side before splitting them.

## Why four repos, not one

| Concern | What goes wrong with one big repo |
|---|---|
| **Lifecycle independence** | Every source-code commit looks like a potential deploy event to ArgoCD. Noisy. |
| **Blast radius** | Devs push code freely; deploys to prod should be guarded. Different repos → different review rules. |
| **Rollback semantics** | `git revert` on `gke-argocd` = "undo the deploy", cleanly. In one repo, `git revert` may also undo code. |
| **Cross-env promotion** | "Promote dev image to staging" is a tag-bump PR with a clear scope. Easier in a manifests-only repo. |
| **Build-before-reference ordering** | The image must exist in Artifact Registry before a manifest references it. Two repos enforces: build first, then bump. |
| **Permissions on shared infra** | `terraform apply` can touch any GCP resource. A separate `smarthr-terraform` repo can have stricter CODEOWNERS than service repos. |
| **State isolation between services** | Each terraform env directory has its own GCS state prefix — `hanica-prod` can't accidentally touch `oke-prod`. |

## The canonical flow

```
┌──────────────────┐                ┌──────────────────┐
│  smarthr/hanica  │   PR merge     │   smarthr/oke    │   PR merge
│   (source repo)  │  to main       │  (source repo)   │  to main
└────────┬─────────┘                └────────┬─────────┘
         │                                   │
         │ ci.yml: docker build,             │ ci.yml: docker build,
         │ push to Artifact Registry,        │ push to Artifact Registry,
         │ open PR in gke-argocd repo        │ open PR in gke-argocd repo
         ▼                                   ▼
                  ┌──────────────────────────┐
                  │   smarthr/gke-argocd     │
                  │   (manifests repo)       │
                  │                          │
                  │  PR bumps the image tag  │
                  │  in tenants/<svc>/       │
                  │  overlays/<env>/         │
                  │  kustomization.yaml      │
                  │                          │
                  │  Reviewer merges = deploy│
                  └────────────┬─────────────┘
                               │
                               │ ArgoCD watches main
                               ▼
                  ┌──────────────────────────┐
                  │   GKE Autopilot cluster  │
                  │   (smart-hr-demo-499522) │
                  └──────────────────────────┘
                               ▲
                               │  cluster created by
                               │
                  ┌────────────┴─────────────┐
                  │ smarthr/smarthr-terraform│
                  │  (shared infra repo)     │
                  │                          │
                  │ PR → plan.yml runs plan  │
                  │ Merge to main →          │
                  │   apply.yml runs apply   │
                  │   (gated by env reviewer)│
                  └──────────────────────────┘
```

## Why this demo has TWO sets of workflow files

GitHub Actions only fires from `.github/workflows/` at the **root** of a repo, not from nested directories. So in this single-repo demo:

| Location | What it is | Does it run? |
|---|---|---|
| `.github/workflows/ci-{hanica,oke}.yml` (repo root) | The **real** workflows that drive the demo. Build images, bump tags within this same repo. | YES |
| `repos/hanica/.github/workflows/ci.yml` | **Illustrative.** Shows what the workflow looks like when `hanica` is a real separate repo. Uses cross-repo PRs with `peter-evans/create-pull-request@v6`. | NO |
| `repos/oke/.github/workflows/ci.yml` | Same as above, for oke. | NO |
| `repos/smarthr-terraform/.github/workflows/{plan,apply}.yml` | **Illustrative.** TF plan on PR / apply on merge to main. The real `terraform apply` for this demo happens via `bootstrap.sh` or manually. | NO |
| `repos/gke-argocd/.github/workflows/validate.yml` | **Illustrative.** kustomize build + kubeconform on PRs in the real gke-argocd repo. | NO |

Each illustrative workflow has a top-of-file comment marking it as such.

## When SmartHR actually splits the repos

1. **Create** `smarthr/hanica`, `smarthr/oke`, `smarthr/smarthr-terraform`, `smarthr/gke-argocd` (or whatever naming convention they prefer).
2. **Move** the contents of each `repos/<name>/` subdirectory into the root of the corresponding new repo. The illustrative `.github/workflows/` in each subdir becomes the real one at the new repo's root.
3. **Adjust paths**:
   - In `gke-argocd/platform/argocd/appsets/autopilot.yaml`, change the `repoURL` to `https://github.com/smarthr/gke-argocd.git` and the `path` to just `tenants/{{ .tenant }}/overlays/autopilot` (drop the `repos/gke-argocd/` prefix).
   - In each service repo's `ci.yml`, set `GITOPS_REPO: smarthr/gke-argocd`.
4. **Wire WIF**: The WIF attribute_condition in the terraform must allow tokens from each of the new repos. Update `infra/wif.tf` to set `attribute.repository in ['smarthr/hanica', 'smarthr/oke', 'smarthr/smarthr-terraform']`.
5. **Issue cross-repo tokens**: Each source repo needs a `GITOPS_PAT` secret (fine-grained PAT or GitHub App token) scoped to write to `smarthr/gke-argocd`.
6. **Delete** the now-empty illustrative files and the root-level `.github/workflows/ci-*.yml` from `smarthr/gke-argocd`.

The base manifests (`tenants/<svc>/base/`) and the platform install (`platform/`) are repo-portable as-is.

## Repo ownership recommendations

| Repo | Owners (CODEOWNERS) |
|---|---|
| `smarthr/hanica` | hanica service team |
| `smarthr/oke` | oke service team |
| `smarthr/smarthr-terraform` | platform team |
| `smarthr/gke-argocd` | platform team + service team (per-tenant directory) |

A common pattern: in `gke-argocd`, the platform team owns `platform/` and tenant teams own `tenants/<theirteam>/` via CODEOWNERS. This way the deploy approval gate (the PR review on the image-bump PR) can be the service team itself, not the platform team.
