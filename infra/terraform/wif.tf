################################################################################
# Workload Identity Federation pool for GitHub Actions → GCP
################################################################################
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions WIF Pool"
  description               = "Pool for GitHub Actions to impersonate GCP SAs without keys."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
  }

  # Restrict to the user-specified repo so no other repo can use this provider.
  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

################################################################################
# GCP SA used by GitHub Actions to deploy to Artifact Registry and the cluster.
# Impersonated via WIF; no JSON keys are minted.
################################################################################
resource "google_service_account" "gh_actions_deployer" {
  account_id   = "gh-actions-deployer"
  display_name = "GitHub Actions deployer (WIF)"
}

resource "google_project_iam_member" "gh_actions_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.gh_actions_deployer.email}"
}

resource "google_project_iam_member" "gh_actions_container_dev" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.gh_actions_deployer.email}"
}

resource "google_project_iam_member" "gh_actions_sa_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.gh_actions_deployer.email}"
}

# Allow the GitHub repo (main branch) to impersonate this SA via the WIF provider.
resource "google_service_account_iam_member" "gh_actions_wif_binding" {
  service_account_id = google_service_account.gh_actions_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

################################################################################
# GCP SA representing the hanica runtime workload (worked example of
# in-cluster Workload Identity for talking to AlloyDB / GCS in production).
# Bound to the KSA `hanica/app` so pods using that KSA can mint GCP tokens.
################################################################################
resource "google_service_account" "hanica_runtime" {
  account_id   = "hanica-runtime"
  display_name = "hanica runtime (KSA-bound)"
}

resource "google_project_iam_member" "hanica_runtime_storage_obj_user" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.hanica_runtime.email}"
}

resource "google_service_account_iam_member" "hanica_runtime_wi_binding" {
  service_account_id = google_service_account.hanica_runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[hanica/app]"
}
