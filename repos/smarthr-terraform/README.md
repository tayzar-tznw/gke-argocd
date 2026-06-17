# `smarthr-terraform` repo (simulated)

> **In production this is a separate GitHub repository**, e.g. `smarthr/smarthr-terraform`. In this demo it lives as a subdirectory.

## What lives here in real life

The **shared, multi-service** infrastructure code for SmartHR:

- Reusable modules (VPC, GKE, Artifact Registry, WIF, AlloyDB, Memorystore, …)
- One subdirectory under `environments/` per (service × env) — e.g. `hanica-prod`, `oke-prod`, `internal-tools-staging`, `smarthr-gke-demo`
- A CD pipeline: `terraform plan` runs on every PR; `terraform apply` runs on merge to `main` with a required-reviewer environment gate

## What's in this demo subdir

```
modules/               # placeholder — explains how shared modules go here
environments/
  smarthr-gke-demo/    # the LIVE terraform for this demo (creates the cluster + supporting GCP resources)
  another-service-example/   # placeholder to make the multi-service intent visible
.github/workflows/
  plan.yml             # ILLUSTRATIVE: terraform plan on PR
  apply.yml            # ILLUSTRATIVE: terraform apply on merge to main
```

The workflows under `.github/workflows/` here are **illustrative** — they show SmartHR what the real `smarthr-terraform` repo's CD pipeline should look like. They never execute in this demo.

See [`docs/MULTI_REPO_LAYOUT.md`](../../docs/MULTI_REPO_LAYOUT.md).

## Multi-environment layout pattern

```
environments/
├── smarthr-gke-demo/    # one directory per (project, environment)
│   ├── backend.tf       # GCS prefix unique to this env — state isolation
│   ├── main.tf
│   ├── vpc.tf
│   ├── gke.tf
│   └── …
├── hanica-prod/         # consume the same modules with different vars
│   ├── backend.tf
│   ├── main.tf
│   └── …
└── oke-prod/
    └── …
```

Each environment has its own state prefix in the GCS backend bucket, so `terraform apply` for one env can never accidentally touch another.

## State backend

GCS bucket `smarthr-gke-tfstate-87614275791` in `asia-northeast1`. Versioning is on so a bad apply can be rolled back. The bucket itself was created once via `gcloud` outside Terraform (chicken-and-egg).

## CD pattern (illustrative)

```
dev opens PR → plan.yml runs `terraform plan` and posts the diff to the PR
reviewer approves → merge to main
apply.yml runs `terraform apply` (gated by GitHub Environment `production` with required reviewer)
```

Auth: Workload Identity Federation, same pool as the service repos. The pool's attribute_condition restricts which repos can mint tokens.
