# -------------------------------------------------------
# GKE Security Bulletin Notifications
# Rule: Configure Pub/Sub topics so GKE security bulletin
# notifications are received, routed to Cloud Logging,
# and available for third-party alerting integrations.
# Org policy: constraints/container.managed.enableSecurityBulletinNotifications
# -------------------------------------------------------

# Pub/Sub topic — GKE publishes security bulletins here
resource "google_pubsub_topic" "gke_security_bulletins" {
  name    = "${var.cluster_name}-gke-security-bulletins"
  project = var.project_id

  message_retention_duration = "604800s" # 7 days

  labels = {
    env     = var.environment
    purpose = "gke-security-bulletins"
  }
}

# Pull subscription — lets downstream consumers (SIEM, PagerDuty, Datadog, etc.)
# process bulletin messages. Tune ack_deadline and retention to match your
# third-party integration's polling interval.
resource "google_pubsub_subscription" "gke_security_bulletins" {
  name    = "${var.cluster_name}-gke-security-bulletins-sub"
  topic   = google_pubsub_topic.gke_security_bulletins.id
  project = var.project_id

  ack_deadline_seconds = 600 # 10 minutes — bulletins are not time-critical

  message_retention_duration = "604800s" # 7 days — retain unacked messages

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = {
    env     = var.environment
    purpose = "gke-security-bulletins"
  }
}

# Cloud Logging sink — captures GKE security bulletin log entries and
# routes them into the Pub/Sub topic, satisfying the "route to Cloud Logging"
# requirement and making bulletins available to log-based alerting policies.
resource "google_logging_project_sink" "gke_security_bulletins" {
  name        = "${var.cluster_name}-gke-security-bulletins-sink"
  project     = var.project_id
  destination = "pubsub.googleapis.com/${google_pubsub_topic.gke_security_bulletins.id}"

  # Filter for GKE security bulletin notifications published by Google
  filter = "resource.type=\"gke_cluster\" AND logName:\"cloudaudit.googleapis.com\" AND protoPayload.methodName:\"io.k8s.core\" OR (resource.type=\"project\" AND logName:\"container.googleapis.com/security_bulletins\")"

  unique_writer_identity = true

  description = "Routes GKE security bulletin log entries to Pub/Sub for alerting"
}

# IAM — grant the sink's unique writer identity publish rights on the topic
resource "google_pubsub_topic_iam_member" "gke_security_bulletins_sink_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.gke_security_bulletins.name
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.gke_security_bulletins.writer_identity
}
