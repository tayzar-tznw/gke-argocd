# `hanica` source repo (simulated)

> **In production this is a separate GitHub repository**, e.g. `smarthr/hanica`. In this demo it lives as a subdirectory so all four "repos" can be shown side-by-side.

## What lives here in real life

Everything the hanica service team owns:

- Application source code (Rails app, pnpm-built frontend assets)
- `Dockerfile`
- Service-specific docs
- CI workflow that builds the image and triggers a deploy

## What's in this demo subdir

Just enough to show the CI pattern end-to-end:

| File | Purpose |
|---|---|
| `Dockerfile` | nginx-based placeholder, build-time-stamped HTML |
| `index.html` | placeholder content with `__BUILD_SHA__` substitution |
| `.github/workflows/ci.yml` | **Illustrative** — what the workflow looks like when this repo is a *real* separate repo. Builds the image, pushes to Artifact Registry, opens a PR against the `gke-argocd` repo to bump the image tag. |

The CI workflow under `.github/workflows/ci.yml` is **never executed** in this demo (GitHub Actions only fires from `.github/workflows/` at the repo root). It is here to show SmartHR what their real `hanica` repo's workflow should look like. The *actual* operational workflow that drives this demo lives at the repo root in `.github/workflows/ci-hanica.yml`.

See [`docs/MULTI_REPO_LAYOUT.md`](../../docs/MULTI_REPO_LAYOUT.md) for the full explanation.

## Real-life deploy flow

```
dev merges PR to main of smarthr/hanica
    ↓ ci.yml in this repo
    bundle install + pnpm asset build
    docker build & push to Artifact Registry
    rake db:migrate (as a Kubernetes Job)
    ↓ open PR against smarthr/gke-argocd
    Updates tenants/hanica/overlays/<env>/kustomization.yaml with the new image tag
    PR is the manual approval gate
    ↓ on merge of that PR
    ArgoCD detects the manifest change and reconciles to the new image
    [hanica] GraphQL schema deploy to Apollo Federation post-sync
    Slack notification
```
