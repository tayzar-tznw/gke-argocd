# SmartHR GKE migration demo

A working GitOps deployment of the SmartHR Cloud Run → GKE migration target architecture: two multi-tenant GKE clusters (one Autopilot, one Standard), ArgoCD for GitOps, KEDA for event-driven autoscaling, and a GitHub Actions CD pipeline.

**See [`docs/README.md`](docs/README.md) for the full overview and quickstart.**

**See [`docs/DEMO.md`](docs/DEMO.md) for the live walkthrough script.**

**See [`docs/AUTOPILOT_VS_STANDARD.md`](docs/AUTOPILOT_VS_STANDARD.md) for the side-by-side cluster comparison.**

**See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the file-by-file mapping to the source diagrams.**

## One command

```bash
./scripts/bootstrap.sh   # ~12 minutes, ~$0.45/hour while running
./scripts/teardown.sh    # when you're done
```
