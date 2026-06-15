################################################################################
# GKE Autopilot cluster (smarthr-autopilot) — regional in var.region
################################################################################
resource "google_container_cluster" "autopilot" {
  provider = google-beta

  name     = "smarthr-autopilot"
  location = var.region

  enable_autopilot    = true
  deletion_protection = false

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "demo-open"
    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  cost_management_config {
    enabled = true
  }

  resource_labels = var.labels
}

################################################################################
# GKE Standard cluster (smarthr-standard) — zonal, with two node pools
################################################################################
resource "google_container_cluster" "standard" {
  provider = google-beta

  name     = "smarthr-standard"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.16/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "demo-open"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  cost_management_config {
    enabled = true
  }

  datapath_provider = "ADVANCED_DATAPATH"

  resource_labels = var.labels
}

resource "google_container_node_pool" "standard_default" {
  name     = "default-pool"
  cluster  = google_container_cluster.standard.name
  location = google_container_cluster.standard.location

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = merge(var.labels, {
      pool = "default"
    })
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_container_node_pool" "standard_io_heavy" {
  name     = "io-heavy-pool"
  cluster  = google_container_cluster.standard.name
  location = google_container_cluster.standard.location

  autoscaling {
    min_node_count = 0
    max_node_count = 2
  }

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "workload"
      value  = "io-heavy"
      effect = "NO_SCHEDULE"
    }

    labels = merge(var.labels, {
      pool = "io-heavy"
    })
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
