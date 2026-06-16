variable "project_id" {
  description = "GCP project ID for the SmartHR GKE demo."
  type        = string
  default     = "smart-hr-demo-499522"
}

variable "region" {
  description = "GCP region for all regional resources."
  type        = string
  default     = "asia-northeast1"
}

variable "github_repo" {
  description = "GitHub repository in 'owner/name' form. Used by WIF binding."
  type        = string
  default     = "tayzar-tznw/gke-argocd"
}

variable "labels" {
  description = "Common labels applied to all resources."
  type        = map(string)
  default = {
    demo    = "smarthr-gke"
    managed = "terraform"
  }
}
