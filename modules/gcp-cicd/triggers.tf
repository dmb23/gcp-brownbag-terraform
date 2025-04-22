resource "google_cloudbuild_trigger" "plan-trigger" {
  description        = "terraform plan"
  disabled           = false
  filename           = "modules/gcp-cicd/cloudbuild-plan.yaml"
  filter             = null
  ignored_files      = []
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = []
  location           = "global"
  name               = "plan-trigger"
  project            = "focus-dragon-457009-i8"
  service_account    = google_service_account.cloudbuild_service_account.id
  substitutions      = {}
  tags               = []
  approval_config {
    approval_required = false
  }
  github {
    name  = "gcp-brownbag-terraform"
    owner = "dmb23"
    push {
      branch       = "^main$"
      invert_regex = true
      tag          = null
    }
  }
}
