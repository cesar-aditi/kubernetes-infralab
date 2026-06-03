output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_location" {
  value = google_container_cluster.primary.location
}

output "ingress_ip" {
  description = "Attach this to the NGINX ingress LoadBalancer service"
  value       = google_compute_address.ingress_ip.address
}

output "node_sa_email" {
  value = google_service_account.gke_node_sa.email
}

output "kubectl_config_command" {
  description = "Run this after apply to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
