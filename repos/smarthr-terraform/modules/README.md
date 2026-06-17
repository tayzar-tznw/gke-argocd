# Terraform modules

Reusable Terraform modules go here. In SmartHR's real `smarthr-terraform` repo, this directory factors out common pieces so each `environments/<name>/` can stay small and consume the modules.

## Suggested structure

```
modules/
├── gke-autopilot-cluster/   # cluster + WI + cost allocation + gateway addon
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── vpc/                     # VPC, subnet (with secondary ranges), NAT
├── artifact-registry/       # AR repo with cleanup policies
├── wif-github-actions/      # WIF pool + provider + SA binding for one GitHub repo
└── secrets-bootstrap/       # Secret Manager secrets + WI bindings for KSAs
```

A consuming environment then looks like:

```hcl
# environments/hanica-prod/main.tf
module "network" {
  source = "../../modules/vpc"
  name   = "hanica-prod-vpc"
  region = "asia-northeast1"
}

module "cluster" {
  source           = "../../modules/gke-autopilot-cluster"
  name             = "hanica-prod"
  region           = "asia-northeast1"
  network          = module.network.vpc_id
  subnetwork       = module.network.subnet_id
}
```

## Why this demo skips modules

The demo has only ONE environment (`smarthr-gke-demo`), so factoring everything into modules would be pure ceremony. The terraform under `environments/smarthr-gke-demo/` keeps all resources inline. When SmartHR adds the second environment (`hanica-prod`, `oke-prod`, etc.), the natural refactor is to extract the common pieces into modules here.

## Versioning

In production, pin modules to a tag/SHA when consuming across environments:

```hcl
module "cluster" {
  source = "git::https://github.com/smarthr/smarthr-terraform.git//modules/gke-autopilot-cluster?ref=v2.4.1"
}
```

Within the same repo, relative paths (`../../modules/...`) are simpler and Terraform reads them on each `init`.
