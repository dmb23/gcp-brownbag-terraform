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
    "roles/run.invoker",
  ]

  function_iam_roles = [
    "roles/logging.logWriter",
    "roles/storage.objectUser",
    "roles/run.invoker",
    "roles/eventarc.eventReceiver",
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

resource "google_project_iam_member" "function_iam_role" {
  for_each = toset(local.function_iam_roles)

  project = data.google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Add IAM permission for Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "job_secret_access" {
  for_each = google_secret_manager_secret.agent_secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.job_service_account.email}"
}

# Add IAM permission for Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "function_secret_access" {
  for_each = google_secret_manager_secret.function_secrets

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_service_account.email}"
}

# IAM policy to make the function publicly accessible
resource "google_cloud_run_service_iam_member" "function_invoker" {
  location = google_cloud_run_v2_service.function_service.location
  service  = google_cloud_run_v2_service.function_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow the Cloud Storage account to publish PubSub topics
data "google_storage_project_service_account" "gcs_account" {}
resource "google_project_iam_member" "pubsubpublisher" {
  project = data.google_project.project.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}


# Create a custom role with storage.buckets.get permission
resource "google_project_iam_custom_role" "storage_bucket_viewer" {
  role_id     = "storageBucketViewer"
  title       = "Storage Bucket Viewer"
  description = "Custom role with storage.buckets.get permission"
  permissions = ["storage.buckets.get"]
}

# Grant the custom role to the Eventarc service account
resource "google_storage_bucket_iam_member" "eventarc_bucket_viewer" {
  bucket = google_storage_bucket.report-bucket.name
  role   = google_project_iam_custom_role.storage_bucket_viewer.id
  member = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Create a custom role with aiplatform.endpoints.predict permission
resource "google_project_iam_custom_role" "ai_platform_predictor" {
  role_id     = "aiPlatformPredictor"
  title       = "AI Platform Predictor"
  description = "Custom role with aiplatform.endpoints.predict permission"
  permissions = ["aiplatform.endpoints.predict"]
}

# Grant the AI Platform Predictor role to the job service account
resource "google_project_iam_member" "job_ai_predictor" {
  project = data.google_project.project.project_id
  role    = google_project_iam_custom_role.ai_platform_predictor.id
  member  = "serviceAccount:${google_service_account.job_service_account.email}"
}
