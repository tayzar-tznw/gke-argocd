# `another-service-example/` — placeholder

This directory exists to make the **multi-service** intent of `smarthr-terraform` visible. In real life, this would be a second environment alongside `smarthr-gke-demo/`, e.g. `hanica-prod/`, `oke-prod/`, or `internal-tools-staging/`.

## What a real env dir would contain

```
hanica-prod/
├── backend.tf          # GCS backend, distinct `prefix` so state is isolated per env
├── main.tf
├── vpc.tf              # OR: module "network" { source = "../../modules/vpc" ... }
├── alloydb.tf
├── memorystore.tf
├── gke.tf              # OR: module "cluster" { source = "../../modules/gke-autopilot-cluster" ... }
└── variables.tf
```

## CD behavior

The repo's `apply.yml` workflow detects which `environments/<name>/` directories changed in the merged PR and runs `terraform apply` for each one in parallel. Each apply uses its env-specific GCS backend prefix, so:

- A PR that only touches `environments/hanica-prod/**` triggers an apply ONLY for hanica-prod
- A PR that touches `modules/gke-autopilot-cluster/**` would (by simple match) apply nothing — modules don't have state. In practice the apply workflow can also re-apply every env that consumes a touched module, but that's an opt-in policy.

## State isolation

Each env's `backend.tf` uses a different `prefix:`

```hcl
# environments/hanica-prod/backend.tf
terraform {
  backend "gcs" {
    bucket = "smarthr-tfstate-PROJECT_NUMBER"
    prefix = "environments/hanica-prod"
  }
}
```

This guarantees `terraform apply` for one env cannot accidentally touch another env's resources, even if the resource names collide.
