# `oke` source repo (simulated)

> **In production this is a separate GitHub repository**, e.g. `smarthr/oke`. In this demo it lives as a subdirectory.

## What lives here in real life

- Application source code (Rails document-generation backend)
- `Dockerfile`s for the web tier and the various worker tiers
- Service-specific docs
- CI workflow that builds + pushes + opens a deploy PR

## What's in this demo subdir

| File | Purpose |
|---|---|
| `Dockerfile` | redis:7-alpine + worker.sh placeholder |
| `worker.sh` | LPOPs from a Redis queue (matches what KEDA's `redis` scaler watches) |
| `.github/workflows/ci.yml` | **Illustrative** — PR-based cross-repo bump against the `gke-argocd` repo |

`.github/workflows/ci.yml` here never executes; it documents the real-life workflow. The operational equivalent that drives this demo is at the repo root: `.github/workflows/ci-oke.yml`.

See [`docs/MULTI_REPO_LAYOUT.md`](../../docs/MULTI_REPO_LAYOUT.md).

## Real-life deploy flow

```
dev merges PR to main of smarthr/oke
    ↓ ci.yml in this repo
    docker build & push to Artifact Registry
    rake db:migrate
    [oke] rake task: grant readonly env permissions
    ↓ open PR against smarthr/gke-argocd
    Updates tenants/oke/overlays/<env>/kustomization.yaml with the new image tag
    PR is the manual approval gate
    ↓ on merge of that PR
    ArgoCD reconciles
    Slack notification
```
