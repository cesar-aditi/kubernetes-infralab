# -------------------------------------------------------
# Storage — optimized
# FIX: single-region, lifecycle tiering, orphaned disks removed
# -------------------------------------------------------

resource "google_storage_bucket" "app_assets" {
  name          = "${var.project_id}-app-assets"
  location      = var.region    # FIX: single-region (was multi-region "US")
  storage_class = "STANDARD"
  force_destroy = false

  # FIX: version expiry — old versions don't accumulate forever
  versioning {
    enabled = true
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { num_newer_versions = 3 }
  }

  # FIX: tiering — objects move to cheaper classes automatically
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
}

resource "google_storage_bucket" "app_logs" {
  name          = "${var.project_id}-app-logs"
  location      = var.region    # FIX: single-region
  storage_class = "STANDARD"
  force_destroy = false

  # FIX: logs tier quickly — they're rarely accessed after 30 days
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
  storage_class = "NEARLINE"    # FIX: backups start on NEARLINE, not STANDARD
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

# FIX: orphaned disks removed entirely
# legacy-db-data-disk  (500 GB pd-ssd) — $85/mo gone
# worker-vm-disk-1     (200 GB pd-ssd) — $34/mo gone
# worker-vm-disk-2     (200 GB pd-ssd) — $34/mo gone
