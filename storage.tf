# -------------------------------------------------------
# Storage — optimized
# FIX: single-region, lifecycle tiering, orphaned disks removed
# -------------------------------------------------------

resource "google_storage_bucket" "app_assets" {
  name          = "${var.project_id}-app-assets"
  location      = var.region    # FIX: single-region (was multi-region "US")
  storage_class = "STANDARD"
  force_destroy = false

  versioning {
    enabled = true
  }

  # FIX: expire old versions — stop accumulating forever
  lifecycle_rule {
    action { type = "Delete" }
    condition { num_newer_versions = 3 }
  }

  # FIX: tier to NEARLINE after 30 days
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition { age = 30 }
  }

  # FIX: tier to COLDLINE after 90 days
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition { age = 90 }
  }
}

resource "google_storage_bucket" "app_logs" {
  name          = "${var.project_id}-app-logs"
  location      = var.region    # FIX: single-region
  storage_class = "STANDARD"
  force_destroy = false

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition { age = 30 }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition { age = 90 }
  }

  # FIX: delete logs after 1 year
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

resource "google_storage_bucket" "backups" {
  name          = "${var.project_id}-backups"
  location      = var.region
  storage_class = "NEARLINE"    # FIX: backups start on NEARLINE (was STANDARD)
  force_destroy = false

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition { age = 90 }
  }

  # FIX: delete backups older than 1 year
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

# FIX: 3 orphaned disks removed
# legacy-db-disk   500 GB pd-ssd  ~$85/mo  → gone
# worker-disk-1    200 GB pd-ssd  ~$34/mo  → gone
# worker-disk-2    200 GB pd-ssd  ~$34/mo  → gone
