resource "google_service_account" "cloudbuild_service_account" {
  account_id   = "cloudbuild-sa"
  display_name = "Cloudbuild Service Account"
}

resource "google_project_iam_member" "project_editor" {
  project = data.google_project.project.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}
