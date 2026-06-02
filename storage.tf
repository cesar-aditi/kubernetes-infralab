# =======================================================
# storage.tf — Cloud Storage and Persistent Disks
# Provisioned over time, never cleaned up
# =======================================================

# --- Cloud Storage Buckets ---

# Main app bucket — standard storage, no lifecycle rules
resource "google_storage_bucket" "app_assets" {
  name          = "my-company-prod-app-assets"
  location      = "US"            # Multi-region — expensive, single-region would suffice
  storage_class = "STANDARD"      # All objects on STANDARD — no tiering

  # No lifecycle rules — objects accumulate forever
  # lifecycle_rule {}  <-- never configured

  # No versioning policy expiry
  versioning {
    enabled = true    # Versioning on with no expiry = infinite old versions stored
  }

  # No retention policy
  # No object expiry
}

# Log storage bucket — logs kept forever at standard pricing
resource "google_storage_bucket" "app_logs" {
  name          = "my-company-prod-logs"
  location      = "US"
  storage_class = "STANDARD"      # Logs should be NEARLINE or COLDLINE after 30 days

  # Log data from 2021 still sitting here at $0.026/GB/month
  # Estimated: 4TB of logs = ~$106/month just for old logs
}

# Backup bucket — no lifecycle, backups from 2021 still present
resource "google_storage_bucket" "backups" {
  name          = "my-company-prod-backups"
  location      = "US"
  storage_class = "STANDARD"

  # Daily backups for 3 years with no expiry
  # Estimated 8TB sitting in STANDARD = ~$208/month
}

# --- Persistent Disk for legacy database (moved to Cloud SQL but disk kept) ---
resource "google_compute_disk" "legacy_db_disk" {
  name  = "legacy-db-data-disk"
  type  = "pd-ssd"          # SSD — but this disk is no longer attached to any VM
  size  = 500               # 500GB orphaned SSD disk = ~$85/month doing nothing
  zone  = "us-east1-b"

  # No snapshot schedule
  # No deletion protection
}

# --- Additional orphaned disks from old VMs ---
resource "google_compute_disk" "old_worker_disk_1" {
  name  = "worker-vm-disk-01"   # VM was deleted but disk remains
  type  = "pd-ssd"
  size  = 200
  zone  = "us-east1-b"
}

resource "google_compute_disk" "old_worker_disk_2" {
  name  = "worker-vm-disk-02"
  type  = "pd-ssd"
  size  = 200
  zone  = "us-east1-b"
}

# --- PersistentVolumeClaims in Kubernetes ---
# Defined as YAML, representing GCP PDs provisioned by GKE
