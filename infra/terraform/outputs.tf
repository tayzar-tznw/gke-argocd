output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "autopilot_cluster_name" {
  value = google_container_cluster.autopilot.name
}

output "autopilot_cluster_endpoint" {
  value     = google_container_cluster.autopilot.endpoint
  sensitive = true
}

output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.smarthr_demo.repository_id}"
}

output "wif_provider" {
  value       = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
  description = "Pass this to google-github-actions/auth as workload_identity_provider."
}

output "gh_actions_sa_email" {
  value       = google_service_account.gh_actions_deployer.email
  description = "Pass this to google-github-actions/auth as service_account."
}

output "hanica_runtime_sa_email" {
  value       = google_service_account.hanica_runtime.email
  description = "Annotate the hanica/app KSA with this for Workload Identity."
}

data "google_project" "this" {
  project_id = var.project_id
}
