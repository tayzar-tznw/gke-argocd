# `gke-argocd` repo (simulated — and this is also the actual repo's "purpose")

> **In production this is a separate GitHub repository**, e.g. `smarthr/gke-argocd`. In this demo it lives as a subdirectory under the same-named outer repo.

## What lives here in real life

The **GitOps manifest repo**. ArgoCD watches this repo and reconciles the cluster to match. Nothing else lives here — no source code, no terraform, no Dockerfiles.

```
platform/               # cluster-level installs (ArgoCD itself, KEDA, NetworkPolicies, ResourceQuotas)
tenants/                # per-tenant workloads (hanica, oke)
scripts/                # one-shot bootstrap + teardown for the K8s layer
.github/workflows/      # PR validate (kubeconform, kustomize build) — ILLUSTRATIVE here
```

## Why a separate repo from source / terraform

| Reason | What goes wrong if you don't split |
|---|---|
| Lifecycle independence | Every source-code commit looks like a potential deploy event to ArgoCD |
| Permissions / blast radius | Devs push code freely; deploys to prod should be guarded |
| Rollback semantics | `git revert` here = "undo the deploy", cleanly |
| Cross-env promotion | "Promote dev image to staging" is a tag-bump commit in a clear scope |
| Build-before-reference ordering | Image must exist in AR before a manifest references it |

## What ArgoCD watches

```
spec:
  source:
    repoURL: https://github.com/tayzar-tznw/gke-argocd.git
    targetRevision: main
    path: repos/gke-argocd/tenants/<tenant>/overlays/autopilot
```

After SmartHR splits this out into a real separate repo, `repoURL` becomes `https://github.com/smarthr/gke-argocd.git` and `path` becomes just `tenants/<tenant>/overlays/autopilot`.

## CD writes from the service repos

The `hanica` and `oke` source repos open PRs against this repo bumping the image tag in `tenants/<svc>/overlays/<env>/kustomization.yaml`. The PR review IS the deploy approval gate.

See [`docs/MULTI_REPO_LAYOUT.md`](../../docs/MULTI_REPO_LAYOUT.md).
