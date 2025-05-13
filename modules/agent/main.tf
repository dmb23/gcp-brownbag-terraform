terraform {
  required_version = ">= 1.11.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.30.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
  }
}

locals {
  mount_path = "/mnt/reports"
}

data "google_project" "project" {
}

# artifact repository for built containers
resource "google_artifact_registry_repository" "cloud-run-containers" {
  location      = var.region
  repository_id = "cloud-run-containers"
  description   = "Containers for Cloud Run Jobs"
  format        = "docker"
}


# cloud run trigger to deploy containers
resource "google_cloudbuild_trigger" "deploy-trigger" {
  description        = "Deploy new container to artifact repository"
  disabled           = false
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "container-cd-trigger"
  filename           = "cloudbuild-deploy.yaml"
  project            = data.google_project.project.project_id
  service_account    = google_service_account.container_service_account.id
  tags               = []
  substitutions = {
    _REGION     = var.region
    _REPOSITORY = google_artifact_registry_repository.cloud-run-containers.repository_id
    _IMAGE      = var.agent_image_name
  }
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-agents"
    owner = "dmb23"
    push {
      branch = "^main$"
    }
  }
}

# cloud run trigger to deploy containers for Function
resource "google_cloudbuild_trigger" "function-deploy-trigger" {
  description        = "Deploy new function container to artifact repository"
  disabled           = false
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "function-container-cd-trigger"
  filename           = "cloudbuild.yaml"
  project            = data.google_project.project.project_id
  service_account    = google_service_account.container_service_account.id
  tags               = []
  substitutions = {
    _REGION     = var.region
    _REPOSITORY = google_artifact_registry_repository.cloud-run-containers.repository_id
    _IMAGE      = var.function_image_name
  }
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-function"
    owner = "dmb23"
    push {
      branch = "^main$"
    }
  }
}

# storage bucket for markdown reports
resource "random_id" "default" {
  byte_length = 8
}

resource "google_storage_bucket" "report-bucket" {
  name     = "${random_id.default.hex}-grimaud-reports"
  location = var.region

  force_destroy               = false
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Secret Manager secrets
resource "google_secret_manager_secret" "agent_secrets" {
  for_each = toset([
    "ANTHROPIC_API_KEY",
    "LOGFIRE_TOKEN",
    "GEMINI_API_KEY",
  ])

  secret_id = "agent_${each.key}"

  replication {
    auto {}
  }
}

# Secret Manager secrets
resource "google_secret_manager_secret" "function_secrets" {
  for_each = toset([
    "SLACK_BOT_TOKEN",
    "SLACK_CHANNEL_ID",
  ])

  secret_id = "function_${each.key}"

  replication {
    auto {}
  }
}

# cloud run function
resource "google_cloud_run_v2_service" "function_service" {
  name     = "post-to-slack-function"
  location = var.region

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${data.google_project.project.project_id}/${google_artifact_registry_repository.cloud-run-containers.repository_id}/${var.function_image_name}"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # Add secret environment variables
      dynamic "env" {
        for_each = google_secret_manager_secret.function_secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = "latest"
            }
          }
        }
      }
    }

    service_account = google_service_account.function_service_account.email
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# cloud run job
resource "google_cloud_run_v2_job" "agent_job" {
  name                = "agent-job"
  location            = var.region
  deletion_protection = false

  template {
    template {
      containers {
        image = "${var.region}-docker.pkg.dev/${data.google_project.project.project_id}/${google_artifact_registry_repository.cloud-run-containers.repository_id}/${var.agent_image_name}"

        resources {
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }

        env {
          name  = "OUTPUT_DIR"
          value = local.mount_path
        }

        # Add secret environment variables
        dynamic "env" {
          for_each = google_secret_manager_secret.agent_secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret_id
                version = "latest"
              }
            }
          }
        }

        # Mount GCS bucket using Cloud Storage FUSE
        volume_mounts {
          name       = "reports"
          mount_path = local.mount_path
        }
      }

      volumes {
        name = "reports"
        gcs {
          bucket = google_storage_bucket.report-bucket.name
        }
      }

      service_account = google_service_account.job_service_account.email
      timeout         = "3600s"
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}

# IAM policy to make the function publicly accessible
resource "google_cloud_run_service_iam_member" "function_invoker" {
  location = google_cloud_run_v2_service.function_service.location
  service  = google_cloud_run_v2_service.function_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Storage trigger for the function
resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.report-bucket.name
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]
  topic          = google_pubsub_topic.bucket_notifications.name
}

# Grant the storage service account permission to publish to Pub/Sub topics
resource "google_project_iam_binding" "pubsub_publisher" {
  project = data.google_project.project.project_id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"]
}

# Create a Pub/Sub topic that will trigger the Cloud Run function
resource "google_pubsub_topic" "bucket_notifications" {
  name = "bucket-notifications"
}

# Grant the storage service account permission to publish to this topic
resource "google_pubsub_topic_iam_member" "publisher" {
  topic  = google_pubsub_topic.bucket_notifications.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Create a Pub/Sub push subscription that targets the Cloud Run function
resource "google_pubsub_subscription" "push_subscription" {
  name  = "push-to-function"
  topic = google_pubsub_topic.bucket_notifications.name

  push_config {
    push_endpoint = google_cloud_run_v2_service.function_service.uri

    oidc_token {
      service_account_email = google_service_account.function_service_account.email
    }
  }

  depends_on = [google_cloud_run_service_iam_member.function_invoker]
}
