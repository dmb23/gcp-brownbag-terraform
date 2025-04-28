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
  terraform_version = "1.11"
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

# service account for CI/CD
resource "google_service_account" "container_service_account" {
  account_id   = "container-cd-sa"
  display_name = "Continous Deployment for Cloud Run Containers Service Account"
}

# IAM for service account
locals {
  iam_roles = [
    "roles/logging.logWriter",
    "roles/run.developer",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
  ]
}

resource "google_project_iam_member" "project_iam_role" {
  for_each = toset(local.iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.container_service_account.email}"
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
    "API_KEY",
    "DATABASE_URL",
    # Add other secret names here
  ])

  secret_id = "agent_${each.key}"
  
  replication {
    auto {}
  }
}

# Add IAM permission for Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = google_secret_manager_secret.agent_secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.container_service_account.email}"
}

# cloud run job
resource "google_cloud_run_v2_job" "agent_job" {
  name     = "agent-job"
  location = var.region

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
          name  = "BUCKET_NAME"
          value = google_storage_bucket.report-bucket.name
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
          mount_path = "/mnt/reports"
        }
      }

      volumes {
        name = "reports"
        cloud_storage {
          bucket = google_storage_bucket.report-bucket.name
        }
      }

      service_account = google_service_account.container_service_account.email
      timeout        = "3600s"
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }
}
