# Why Autopilot (decision record)

**Decision**: Run both `hanica` and `oke` on a single **GKE Autopilot** cluster.

**Date**: 2026-06-16

**Status**: Accepted

## Context

The migration is from Cloud Run + App Engine to GKE. The choice within GKE is **Autopilot** vs **Standard**. Both options were prototyped side-by-side in this repo before this decision; the Standard cluster has been removed.

## What we considered

| Aspect | Autopilot | Standard |
|---|---|---|
| Node management | Google-managed; no nodes to operate | You manage node pools |
| Pricing model | Per pod-request | Per node + sustained-use discounts |
| Control plane | Free, regional always | Free zonal / $0.10/h regional |
| Node pools per workload class | One implicit class | Multiple pools with taints/labels |
| Scale-to-zero workers | No (Autopilot always reserves a pod's resources) | Yes (`min_node_count: 0` + KEDA) |
| Pod-spec freedom | Restricted | Full Kubernetes API |
| Network policy | Always on | Opt-in (Dataplane V2) |
| Operational overhead | ~Zero | Node upgrades, autoscaler tuning, capacity planning |

## Why Autopilot won

1. **The operational tax of Standard wasn't worth it.** SmartHR's two services are normal Rails apps with normal workload shapes. They don't need node-pool isolation, custom DaemonSets, or privileged pods. The things Autopilot restricts are things SmartHR doesn't use.

2. **Pod-request pricing fits the migration profile better.** Cloud Run was already pay-per-request. Autopilot's pay-per-pod-request is a smaller mental shift for cost teams than "pay-per-VM with a bin-packing problem."

3. **One operational surface.** No node upgrades to schedule, no autoscaler config to tune, no capacity planning. The team can focus on the application migration itself.

4. **Workload Identity, NetworkPolicy, Pod Security Standards, Gateway API — all on by default** in Autopilot. On Standard we had to enable each one. Fewer foot-guns.

5. **KEDA still gives us the scaling story.** The `oke` "predictable spike" requirement is solved by KEDA's cron and queue scalers — neither needs Standard. (KEDA's `minReplicaCount: 0` does still mean pods spin down to zero; what Autopilot doesn't do is *also* spin nodes to zero for that pod class. With Autopilot pricing, the cost of one idle pod's reservation is small enough that it doesn't change the calculus.)

## What we'd revisit Standard for

We'd reconsider Standard only if:

- A workload appears that needs **GPU/TPU** with custom drivers (Autopilot supports GPU but with constraints).
- A workload appears that needs **node-local SSDs** or other special node hardware.
- The cost of always-on Autopilot reservations becomes meaningfully larger than the cost of Standard nodes + autoscaler-managed scale-to-zero. (At current SmartHR scale, this is not the case.)

None of these are currently in scope for the hanica/oke migration.

## Implications for the demo / repo

- Only one cluster: `smarthr-autopilot` (regional in `asia-northeast1`)
- Only one ApplicationSet: `platform/argocd/appsets/autopilot.yaml`
- Each tenant has a single Kustomize overlay: `tenants/<svc>/overlays/autopilot/`
- The overlay layer is kept (rather than rendering base directly) so per-env overrides (resource sizing, replica counts) have a clean place to live without touching the base
- The `io-heavy-worker` Deployments lose their node-selector + toleration (Autopilot picks the node class)

## Reversing this decision

If the team later decides to add Standard, the existing structure makes it cheap:
1. Re-add the Standard cluster + node pools in `infra/terraform/gke.tf`
2. Re-add `tenants/<svc>/overlays/standard/` (with the io-heavy node-selector patch)
3. Re-add `platform/argocd/appsets/standard.yaml`
4. Both clusters can run side-by-side; ArgoCD on each cluster reconciles its own ApplicationSet

The base manifests in `tenants/<svc>/base/` are portable across both flavors by design.
