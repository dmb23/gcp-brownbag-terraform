locals {
  iam_roles = [
    "roles/cloudbuild.builds.builder",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.securityAdmin",
    "roles/storage.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/logging.logWriter",
  ]
}

resource "google_service_account" "cloudbuild_service_account" {
  account_id   = "cloudbuild-sa"
  display_name = "Cloudbuild Service Account"
}

resource "google_project_iam_member" "project_iam_role" {
  for_each = toset(local.iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}
