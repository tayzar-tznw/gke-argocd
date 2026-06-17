terraform {
  backend "gcs" {
    bucket = "smarthr-gke-tfstate-87614275791"
    prefix = "environments/smarthr-gke-demo"
  }
}
