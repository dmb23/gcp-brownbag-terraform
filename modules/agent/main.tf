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
  location = "europe-west9"
  repository_id = "cloud-run-containers"
  description = "Containers for Cloud Run Jobs"
  format = "docker"
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
  ]
}

resource "google_project_iam_member" "project_iam_role" {
  for_each = toset(local.iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.container_service_account.email}"
}

# cloud run trigger to deploy containers
resource "google_cloudbuild_trigger" "plan-trigger" {
  description        = "Deploy new container to artifact repository"
  disabled           = false
  filename           = "modules/agent/cloudbuild-deploy.yaml"
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "container-cd-trigger"
  project            = data.google_project.project.project_id
  service_account    = google_service_account.container_service_account.id
  substitutions = {
    _TF_VERSION = local.terraform_version
  }
  tags = []
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-agent"
    owner = "dmb23"
    push {
      branch       = "^main$"
    }
  }
}

# storage bucket for markdown reports

# cloud run job
