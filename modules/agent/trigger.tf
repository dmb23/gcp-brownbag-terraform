# Create an Eventarc trigger for Cloud Storage events
resource "google_eventarc_trigger" "storage_trigger" {
  name     = "storage-finalize-trigger"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.report-bucket.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.function_service.name
      region  = var.region
    }
  }

  service_account = google_service_account.function_service_account.email

  depends_on = [google_storage_bucket_iam_member.eventarc_bucket_viewer]
}

# Create a Pub/Sub topic for the scheduled job
resource "google_pubsub_topic" "schedule_topic" {
  name = "daily-agent-job-topic"
}

# Create a Cloud Scheduler job to trigger the agent_job daily at 10AM
resource "google_cloud_scheduler_job" "daily_job" {
  name             = "daily-agent-job"
  description      = "Triggers the agent job every day at 10AM"
  schedule         = "0 9 * * *"
  time_zone        = "Europe/Paris"
  attempt_deadline = "320s"
  region           = "europe-west3" # cloud scheduler not available in default region

  pubsub_target {
    topic_name = google_pubsub_topic.schedule_topic.id
    data       = base64encode("{\"message\": \"Run daily agent job\"}")
  }

}

# Create a Pub/Sub subscription to trigger the Cloud Run job
resource "google_pubsub_subscription" "job_subscription" {
  name  = "agent-job-subscription"
  topic = google_pubsub_topic.schedule_topic.name

  push_config {
    push_endpoint = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.project.project_id}/jobs/${google_cloud_run_v2_job.agent_job.name}:run"

    oidc_token {
      service_account_email = google_service_account.job_service_account.email
    }
  }
}

