# SmartHR GKE migration demo

A working GitOps deployment of the SmartHR Cloud Run → GKE migration target architecture: a single multi-tenant **GKE Autopilot** cluster, ArgoCD for GitOps, KEDA for event-driven autoscaling, and a GitHub Actions CD pipeline.

**See [`docs/README.md`](docs/README.md) for the full overview and quickstart.**

**See [`docs/DEMO.md`](docs/DEMO.md) for the live walkthrough script.**

**See [`docs/WHY_AUTOPILOT.md`](docs/WHY_AUTOPILOT.md) for the cluster choice rationale.**

**See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the file-by-file mapping to the source diagrams.**

## One command

```bash
./scripts/bootstrap.sh   # ~7–10 minutes, ~$0.40–0.60/hour while running
./scripts/teardown.sh    # when you're done
```
