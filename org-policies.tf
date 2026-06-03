# -------------------------------------------------------
# GKE Org Policy Constraints
# These enforce cluster security settings at the organization
# level, complementing the per-cluster Terraform settings in
# main.tf. Applying these requires the caller to have
# roles/orgpolicy.policyAdmin on the organization.
# -------------------------------------------------------

# Disable ABAC on all GKE clusters in the org
resource "google_org_policy_policy" "disable_abac" {
  name   = "organizations/${var.org_id}/policies/container.managed.disableABAC"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Disable legacy client certificate issuance (static cert/password auth)
resource "google_org_policy_policy" "disable_legacy_client_certs" {
  name   = "organizations/${var.org_id}/policies/container.managed.disableLegacyClientCertificateIssuance"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Disable the insecure kubelet read-only port (10255) on all node pools
resource "google_org_policy_policy" "disable_kubelet_readonly_port" {
  name   = "organizations/${var.org_id}/policies/container.managed.disableInsecureKubeletReadOnlyPort"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Enable DenyServiceExternalIPs admission controller (prevents CVE GCP-2020-015)
resource "google_org_policy_policy" "deny_service_external_ips" {
  name   = "organizations/${var.org_id}/policies/container.managed.denyServiceExternalIPs"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require security bulletin notifications for all GKE projects
resource "google_org_policy_policy" "enable_security_bulletin_notifications" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableSecurityBulletinNotifications"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require Shielded GKE Nodes on all Standard clusters
resource "google_org_policy_policy" "enable_shielded_nodes" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableShieldedNodes"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require private nodes — prevent external IPs on node VMs
resource "google_org_policy_policy" "enable_private_nodes" {
  name   = "organizations/${var.org_id}/policies/container.managed.enablePrivateNodes"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require Workload Identity Federation on all Standard clusters
resource "google_org_policy_policy" "enable_workload_identity" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableWorkloadIdentityFederation"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require NetworkPolicy enforcement on all clusters
resource "google_org_policy_policy" "enable_network_policy" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableNetworkPolicy"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require Cloud Logging to remain enabled on all clusters
resource "google_org_policy_policy" "enable_cloud_logging" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableCloudLogging"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Disallow use of the default Compute Engine service account for GKE node pools
resource "google_org_policy_policy" "disallow_default_compute_sa" {
  name   = "organizations/${var.org_id}/policies/container.managed.disallowDefaultComputeServiceAccount"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Require DNS-only control plane endpoint access
resource "google_org_policy_policy" "enable_control_plane_dns_only" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableControlPlaneDNSOnlyAccess"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Enable Google Groups-based RBAC for group-managed access control
resource "google_org_policy_policy" "enable_google_groups_rbac" {
  name   = "organizations/${var.org_id}/policies/container.managed.enableGoogleGroupsRBAC"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
