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

module "gcp-agent" {
  source = "./modules/agent/"

  region           = var.region
  agent_image_name = "grimaud"
}

data "google_project" "project" {
  depends_on = [google_project_service.project_service["cloudresourcemanager.googleapis.com"]]
}
