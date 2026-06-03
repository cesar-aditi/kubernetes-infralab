terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "REPLACE_WITH_YOUR_TFSTATE_BUCKET"   # replace with your bucket name
    prefix = "after"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# -------------------------------------------------------
# VPC — private cluster needs its own network
# FIX: private nodes, no public IPs on cluster machines
# -------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-subnet"
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.48.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.52.0.0/20"
  }
}

# Cloud NAT — lets private nodes reach internet (pull images) without public IPs
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# -------------------------------------------------------
# Service Account — least privilege for GKE nodes
# FIX: replaces over-privileged default compute SA
# -------------------------------------------------------
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node SA — ${var.cluster_name}"
}

resource "google_project_iam_member" "node_sa_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_metrics_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# -------------------------------------------------------
# GKE Cluster
# FIX: regional (HA), private, HPA on, managed prometheus,
#      VPA, cost allocation, maintenance window
# -------------------------------------------------------
resource "google_container_cluster" "primary" {
  provider = google-beta

  name                = var.cluster_name
  location            = var.region          # FIX: regional — was zonal
  deletion_protection = false

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # FIX: private nodes — no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_cidr
      display_name = "allowed-access"
    }
  }

  # FIX: remove wasteful default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false   # FIX: was disabled
    }
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # FIX: VPA for right-sizing recommendations
  vertical_pod_autoscaling {
    enabled = true
  }

  # FIX: GCP Managed Prometheus — replaces self-hosted Prometheus
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "POD", "DAEMONSET", "DEPLOYMENT"]
    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # FIX: cost allocation per namespace in Cloud Billing
  cost_management_config {
    enabled = true
  }

  # FIX: bin-pack nodes instead of spreading (saves nodes)
  cluster_autoscaling {
    enabled             = false
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

  # FIX: updates during low-traffic window
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# -------------------------------------------------------
# Node Pool: spot — stateless workloads
# FIX: e2-standard-4 spot, autoscales per zone
#      was: n1-standard-8 on-demand, static 5 nodes
# -------------------------------------------------------
resource "google_container_node_pool" "spot_workload" {
  name     = "spot-workload-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count  = var.spot_min_nodes   # FIX: autoscales (was static 5)
    max_node_count  = var.spot_max_nodes
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-4"                          # FIX: right-sized (was n1-standard-8)
    spot            = true                                     # FIX: 60-91% cheaper
    disk_size_gb    = 50                                       # FIX: was 200 GB
    disk_type       = "pd-balanced"                            # FIX: was pd-ssd
    service_account = google_service_account.gke_node_sa.email # FIX: least-privilege SA

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      env  = var.environment
      pool = "spot"
    }

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [
    google_project_iam_member.node_sa_artifact_registry,
    google_project_iam_member.node_sa_log_writer,
    google_project_iam_member.node_sa_metrics_writer,
  ]
}

# -------------------------------------------------------
# Node Pool: on-demand — ingress controller + critical only
# -------------------------------------------------------
resource "google_container_node_pool" "ondemand_critical" {
  name     = "ondemand-critical-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count  = 1
    max_node_count  = 3
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = "e2-standard-2"
    spot            = false
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_node_sa.email

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env  = var.environment
      pool = "ondemand-critical"
    }

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [
    google_project_iam_member.node_sa_artifact_registry,
    google_project_iam_member.node_sa_log_writer,
    google_project_iam_member.node_sa_metrics_writer,
  ]
}

# -------------------------------------------------------
# Static IP — one for the ingress controller
# FIX: was 3 reserved (2 unused). Now 1.
# -------------------------------------------------------
resource "google_compute_address" "ingress_ip" {
  name   = "${var.cluster_name}-ingress-ip"
  region = var.region
}
