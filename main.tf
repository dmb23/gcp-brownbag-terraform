terraform {
  required_version = ">= 1.11.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.30.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "gcp-cicd" {
  source = "./modules/gcp-cicd"

  location = var.region
}

resource "google_project_service" "resource_manager_service" {
  service                    = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
}

data "google_project" "project" {
  depends_on = [google_project_service.resource_manager_service]
}
