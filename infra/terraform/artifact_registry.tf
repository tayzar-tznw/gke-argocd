resource "google_artifact_registry_repository" "smarthr_demo" {
  location      = var.region
  repository_id = "smarthr-demo"
  description   = "Docker images for the SmartHR GKE demo (hanica, oke)."
  format        = "DOCKER"
  labels        = var.labels

  cleanup_policies {
    id     = "keep-recent-10"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-older-30d"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }
}
