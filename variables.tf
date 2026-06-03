variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "southamerica-east1"   # FIX: closer to LATAM (was us-east1)
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "prod-cluster"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "production"
}

variable "authorized_cidr" {
  description = "CIDR allowed to reach the GKE API server"
  type        = string
  default     = "0.0.0.0/0"   # Restrict to your VPN/office IP in production
}

variable "spot_min_nodes" {
  description = "Minimum nodes in spot pool per zone"
  type        = number
  default     = 1
}

variable "spot_max_nodes" {
  description = "Maximum nodes in spot pool per zone"
  type        = number
  default     = 4
}
