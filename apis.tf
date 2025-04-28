locals {
  apis = [
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

resource "google_project_service" "project_service" {
  for_each = toset(local.apis)

  service                    = each.value
  disable_dependent_services = true
}
