variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region — southamerica-east1 is closer to LATAM users than original us-east1"
  type        = string
  default     = "southamerica-east1"   # FIX: was us-east1
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
  description = "CIDR allowed to reach the GKE API server (your office/VPN IP)"
  type        = string
  default     = "0.0.0.0/0"   # Restrict to your IP in production
}

variable "spot_min_nodes" {
  description = "Min nodes in spot pool per zone"
  type        = number
  default     = 1
}

variable "spot_max_nodes" {
  description = "Max nodes in spot pool per zone"
  type        = number
  default     = 4
}
