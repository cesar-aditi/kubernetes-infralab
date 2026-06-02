variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "my-company-prod-001"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-east1"   # Original region — never re-evaluated
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
