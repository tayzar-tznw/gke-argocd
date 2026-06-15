# GKE Autopilot vs GKE Standard — what this demo shows

The demo runs the **same manifests** on both flavors so SmartHR can feel the difference instead of reading about it.

## At a glance

| Aspect | Autopilot (`smarthr-autopilot`) | Standard (`smarthr-standard`) |
|---|---|---|
| **Node management** | Google-managed; you never see nodes | You manage node pools |
| **Pricing model** | Per pod-request (CPU, memory, ephemeral storage) | Per node (e2/n2/...) |
| **Control plane** | Free, regional always | Free zonal / $0.10/h regional |
| **Best for** | Steady traffic, low ops burden (e.g. `hanica` web) | Bursty + cost-tuned + custom (e.g. `oke` workers) |
| **Node pools per workload** | One implicit class | Multiple pools with taints/labels |
| **Scale-to-zero workers** | No (Autopilot reserves at least 1 pod's resources) | Yes (`min_node_count = 0` + KEDA `minReplicaCount: 0`) |
| **Pod-spec freedom** | Restricted — no hostPath, no privileged, no custom DaemonSets (with exceptions), seccompProfile required | Full Kubernetes API |
| **GPU / TPU / spot** | Supported with constraints | Full control |
| **DaemonSets you add** | Subset only | Any |
| **Network policy** | Always on | Opt-in (we turned it on via Dataplane V2) |
| **Operational overhead** | ~Zero | Node upgrades, autoscaler tuning, capacity planning |

## What you can do on Standard that you can't on Autopilot (in this demo)

1. **Dedicated node pool with a taint** — `io-heavy-pool` is `e2-standard-4`, tainted `workload=io-heavy:NoSchedule`. Only `io-heavy-worker` pods (with matching toleration + nodeSelector) land there. Autopilot picks for you and you can't reserve a pool for one workload class.

2. **Scale-to-zero node pool** — `io-heavy-pool` is `min_node_count: 0`. When KEDA scales `io-heavy-worker` to zero, the node pool drains to zero nodes too. Total cost for that workload class is $0 when idle. Autopilot pods always reserve resources, so you pay even when load is zero.

3. **Privileged DaemonSets** — Standard supports anything (log forwarders, GPU drivers, custom CNI plugins). Autopilot allow-lists a fixed set.

## What you give up on Standard

- Node upgrades, autoscaler tuning, surge configuration: you own them.
- Capacity planning for the node pool — you set min/max, you handle bin-packing.
- You pay for the whole node even if half its CPU is idle.

## What you give up on Autopilot

- Per-pool isolation.
- Scale-to-zero on cost-sensitive bursty workloads.
- Some pod-spec features (rare ones, but they exist).

## Recommendation surfaced by this demo

> **Start `hanica` on Autopilot.** Steady web traffic, no need for pool isolation, low ops cost. Autopilot's restrictions don't bite.
>
> **Run `oke` on Standard.** The whole reason `oke` is being migrated is the predictable spike economics. Scale-to-zero (only possible on Standard) + KEDA + dedicated `io-heavy-pool` is exactly the lever you came here for.

Both can run side-by-side. ArgoCD doesn't care which is which — the manifests are portable. The `overlays/standard/` overlay adds the `pool: io-heavy` selector and toleration; the `overlays/autopilot/` overlay omits them.

## When you'd consolidate to one flavor later

- If `oke`'s spikes get tame enough that scale-to-zero stops mattering → consolidate to Autopilot.
- If SmartHR wants a single ops model and you need pool isolation anywhere → consolidate to Standard.

The demo is built around the assumption you may want both at first and one of them later. The manifests don't change either way.
