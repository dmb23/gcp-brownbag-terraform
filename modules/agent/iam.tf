# service account for CI/CD
resource "google_service_account" "container_service_account" {
  account_id   = "container-cd-sa"
  display_name = "Continous Deployment for Cloud Run Containers Service Account"
}

# service account for Cloud Run job
resource "google_service_account" "job_service_account" {
  account_id   = "cloud-run-job-sa"
  display_name = "Cloud Run Job Service Account"
}

# service account for Cloud Run function
resource "google_service_account" "function_service_account" {
  account_id   = "cloud-run-function-sa"
  display_name = "Cloud Run Function Service Account"
}

# IAM for service accounts
locals {
  cd_iam_roles = [
    "roles/logging.logWriter",
    "roles/run.developer",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
  ]

  job_iam_roles = [
    "roles/logging.logWriter",
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
  ]
}

resource "google_project_iam_member" "cd_iam_role" {
  for_each = toset(local.cd_iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.container_service_account.email}"
}

resource "google_project_iam_member" "job_iam_role" {
  for_each = toset(local.job_iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.job_service_account.email}"
}

# Add IAM permission for Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "job_secret_access" {
  for_each = google_secret_manager_secret.agent_secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.job_service_account.email}"
}

resource "google_project_iam_member" "function_iam_role" {
  for_each = toset(local.job_iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Add IAM permission for Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "function_secret_access" {
  for_each = google_secret_manager_secret.function_secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_service_account.email}"
}
