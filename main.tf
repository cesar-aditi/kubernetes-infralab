terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-east1"   # Far from users in LATAM — high latency, no regional discount
}

# -------------------------------------------------------
# GKE Cluster — provisioned in 2021
# -------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = "prod-cluster"
  location = "us-east1"   # Zonal cluster — no HA, but paying for full zonal pricing

  # Default node pool left enabled (bad practice — wastes a node)
  initial_node_count = 1

  # No private cluster — all nodes have public IPs (security + cost)
  networking_mode = "ROUTES"

  # Logging and monitoring set to SYSTEM only — missing cost insights
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # No maintenance window — updates can happen anytime, no cost optimization
  # maintenance_policy not set

  addons_config {
    # HTTP load balancing always on — charges for unused LB
    http_load_balancing {
      disabled = false
    }
    # Horizontal pod autoscaling disabled — static scaling
    horizontal_pod_autoscaling {
      disabled = true
    }
  }

  node_config {
    # n1-standard-8: 8 vCPU / 30GB — massively oversized for most workloads
    machine_type = "n1-standard-8"

    # On-demand pricing — no use of spot/preemptible
    preemptible  = false
    spot         = false

    # 200GB SSD boot disk — way more than needed
    disk_size_gb = 200
    disk_type    = "pd-ssd"

    # No workload identity — using default service account (over-privileged)
    service_account = "default"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",  # Full access scope — not least privilege
    ]

    # No labels or taints — all workloads share same expensive nodes
  }

  # No cluster autoscaler
  # No vertical pod autoscaler
}

# -------------------------------------------------------
# Node Pool — "we needed more capacity in a rush"
# -------------------------------------------------------
resource "google_container_node_pool" "general_workload" {
  name       = "general-workload-pool"
  location   = "us-east1"
  cluster    = google_container_cluster.primary.name
  node_count = 5   # Static count — paying for 5 nodes 24/7/365

  node_config {
    machine_type = "n1-standard-8"   # Same oversized type
    preemptible  = false
    spot         = false
    disk_size_gb = 200
    disk_type    = "pd-ssd"

    labels = {
      env = "production"
    }
  }

  # No autoscaling configured
  # autoscaling {}  <-- commented out and forgotten
}

# -------------------------------------------------------
# Static External IP
# -------------------------------------------------------
resource "google_compute_address" "static_ip_1" {
  name   = "legacy-service-ip-1"
  region = "us-east1"
}

resource "google_compute_address" "static_ip_2" {
  name   = "legacy-service-ip-2"
  region = "us-east1"
}

resource "google_compute_address" "static_ip_3" {
  name   = "legacy-service-ip-3"
  region = "us-east1"
}
