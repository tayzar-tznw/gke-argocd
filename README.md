# SmartHR GKE migration demo

A working GitOps deployment of the SmartHR Cloud Run → GKE migration target architecture: a single multi-tenant **GKE Autopilot** cluster, ArgoCD for GitOps, KEDA for event-driven autoscaling, and a GitHub Actions CD pipeline.

## Single repo, simulated 4-repo layout

This repo's `repos/` subdirectories mirror the **four GitHub repositories** SmartHR should have in production:

```
repos/
├── hanica/             ← represents smarthr/hanica          (source + Dockerfile)
├── oke/                ← represents smarthr/oke             (source + Dockerfile)
├── smarthr-terraform/  ← represents smarthr/smarthr-terraform (shared infra)
└── gke-argocd/         ← represents smarthr/gke-argocd      (manifests-only)
```

Each subdir has its own README explaining what the real repo would contain. The illustrative CI workflows under `repos/<svc>/.github/workflows/` show the real-life cross-repo flow.

**Why this layout: see [`docs/MULTI_REPO_LAYOUT.md`](docs/MULTI_REPO_LAYOUT.md).**

## Read the docs

- **[`docs/README.md`](docs/README.md)** — full overview and quickstart
- **[`docs/MULTI_REPO_LAYOUT.md`](docs/MULTI_REPO_LAYOUT.md)** — the canonical multi-repo structure + how to split this demo into real separate repos
- **[`docs/DEMO.md`](docs/DEMO.md)** — live walkthrough script for SmartHR engineers
- **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)** — file-by-file mapping to the source diagrams
- **[`docs/WHY_AUTOPILOT.md`](docs/WHY_AUTOPILOT.md)** — cluster choice rationale

## One command

```bash
./repos/gke-argocd/scripts/bootstrap.sh   # ~7–10 minutes, ~$0.40–0.60/hour while running
./repos/gke-argocd/scripts/teardown.sh    # when you're done
```
