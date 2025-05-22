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

# cloud run service to post to slack
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


