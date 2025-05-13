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


