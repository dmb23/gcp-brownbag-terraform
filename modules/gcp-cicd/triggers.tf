locals {
  terraform_version = "1.11"
}

resource "google_cloudbuild_trigger" "plan-trigger" {
  description        = "terraform plan for all non-main branches"
  disabled           = false
  filename           = "modules/gcp-cicd/cloudbuild-plan.yaml"
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "plan-trigger"
  project            = data.google_project.project.project_id
  service_account    = google_service_account.cloudbuild_service_account.id
  substitutions = {
    _TF_VERSION = local.terraform_version
  }
  tags = []
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-terraform"
    owner = "dmb23"
    push {
      branch       = "^main$"
      invert_regex = true
    }
  }
}


resource "google_cloudbuild_trigger" "apply-trigger" {
  description        = "terraform apply for main branch"
  disabled           = false
  filename           = "modules/gcp-cicd/cloudbuild-apply.yaml"
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "apply-trigger"
  project            = data.google_project.project.project_id
  service_account    = google_service_account.cloudbuild_service_account.id
  substitutions = {
    _TF_VERSION = local.terraform_version
  }
  tags = []
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-terraform"
    owner = "dmb23"
    push {
      branch = "^main$"
    }
  }
}
