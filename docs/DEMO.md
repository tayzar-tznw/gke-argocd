# Live demo script — SmartHR GKE migration walkthrough

A ~20-minute walkthrough designed for SmartHR engineers. Each section has what to **say**, what to **show**, and what to **run**.

## 0. Setup (do this before the meeting starts)

```bash
./scripts/bootstrap.sh
```

Wait for both clusters to be Ready and ArgoCD to show all Applications **Synced + Healthy**. Confirm with:
```bash
for ctx in gke_smart-hr-demo-499522_asia-northeast1_smarthr-autopilot \
           gke_smart-hr-demo-499522_asia-northeast1-a_smarthr-standard; do
  echo "=== $ctx ==="
  kubectl --context "$ctx" get application -n argocd
done
```

Open two browser windows:
- ArgoCD UI for the Autopilot cluster (port-forward)
- A second ArgoCD UI for the Standard cluster (different port-forward)

---

## 1. The diagram, made real (2 min)

**Say**: "The target architecture from `mutitanency.png` is running right now in both clusters. Same manifests, two cluster flavors."

**Show**:
```bash
kubectl get ns hanica oke argocd keda
kubectl -n hanica get deploy
kubectl -n oke get deploy
```

Point out: all five `hanica` Deployments and all nine `oke` Deployments match the diagram one-to-one.

---

## 2. The GitOps CD pipeline is real (4 min)

**Say**: "The To-Be CD pipeline in `project.md` — `merge → build → push → manifest bump → ArgoCD sync` — works end-to-end. Let me push a change."

**Run**:
```bash
# Edit one line of the placeholder index.html
sed -i 's|hanica — GKE demo placeholder|hanica — DEMO IS LIVE|' apps/hanica-sample/index.html
git commit -am "demo: live update"
git push
```

**Show**:
1. The `ci-hanica` workflow run in GitHub Actions (build, push to AR, the required-reviewer gate).
2. Approve the gate.
3. The follow-up commit by `github-actions[bot]` bumping the image tag in the overlay kustomization.
4. In the ArgoCD UI: the hanica Application picks up the new commit and starts syncing.
5. Once Synced: `curl http://<LB-IP>/` shows the new HTML.

**Say**: "Same flow for `oke`. The CI build is service-specific, the rest is identical."

---

## 3. KEDA solves oke's predictable spike pain (4 min)

**Say**: "The reason for KEDA in `project.md` is `oke`'s predictable spike usage. Here's that working."

**Show queue-driven scaler**:
```bash
kubectl -n oke get scaledobject document-build-worker
kubectl -n oke get pods -l app.kubernetes.io/name=document-build-worker
# (0 pods)

# Push 50 jobs onto the queue
kubectl -n oke exec -it deploy/redis -- redis-cli RPUSH document-build-queue $(seq 1 50 | tr '\n' ' ')

# Watch replicas climb from 0 → N within ~30s
watch -n2 'kubectl -n oke get pods -l app.kubernetes.io/name=document-build-worker'
```

**Show cron scaler**:
```bash
kubectl -n oke get scaledobject mailer-worker -o yaml | grep -A5 triggers
```
Point out: scales up at `:00`, back down at `:10`, every hour. Replaces this with the real payroll dispatch window when productionizing.

**Say**: "Cloud Run's min-instances would have these warm 24/7. KEDA makes them zero-cost when idle and ready before the spike."

---

## 4. Autopilot vs Standard, same workload (4 min)

**Say**: "Same manifests, two clusters. The point isn't to pick — it's to show you can pick per-workload."

**Show in Standard's ArgoCD UI**: open the `oke` Application, find `io-heavy-worker`. Click into the pod, show:
- Node it landed on (`io-heavy-pool-xxx`)
- Toleration `workload=io-heavy:NoSchedule`
- `nodeSelector: pool: io-heavy`

```bash
kubectl --context $STD_CTX -n oke get pods -l app.kubernetes.io/name=io-heavy-worker -o wide
kubectl --context $STD_CTX get nodes -l pool=io-heavy
```

**Show in Autopilot**: same Deployment, no node selector — Google picks the node class.

```bash
kubectl --context $AP_CTX -n oke get pods -l app.kubernetes.io/name=io-heavy-worker -o wide
```

**Say**: "Standard gives you the knob. Autopilot saves you from needing one. The recommendation in `docs/AUTOPILOT_VS_STANDARD.md` is: start `hanica` on Autopilot, consider Standard for `oke` when burst economics matter."

---

## 5. Tenant isolation is enforced, not aspirational (2 min)

```bash
# Cross-tenant traffic is denied by NetworkPolicy:
kubectl -n hanica run debug --rm -it --image=alpine -- \
  sh -c 'apk add curl && curl -m 5 http://app.oke.svc.cluster.local || echo BLOCKED'

# Same-namespace traffic works:
kubectl -n hanica run debug --rm -it --image=alpine -- \
  sh -c 'apk add curl && curl -m 5 http://app.hanica.svc.cluster.local && echo OK'
```

```bash
# ResourceQuotas enforce ceilings:
kubectl -n hanica describe resourcequota
kubectl -n oke describe resourcequota
```

```bash
# AppProjects scope what each tenant Application can do:
kubectl -n argocd get appproject -o yaml | grep -A3 destinations
```

---

## 6. Cost observability per tenant (1 min)

**Say**: "GKE cost allocation is on. Per-namespace spend lands in BigQuery."

```bash
# Show the cluster config:
gcloud container clusters describe smarthr-autopilot --region asia-northeast1 \
  --format='value(costManagementConfig.enabled)'
```

Show BigQuery dataset (post-demo): the `gke_namespace_cost` view aggregates by namespace label so SmartHR can chargeback by tenant.

---

## 7. Teardown (live) (1 min)

```bash
./scripts/teardown.sh
```

Walks through the prompts. Roughly $0.45/hour stops when the script completes.
