terraform {
  required_version =">= 1.11.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.30.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

module "gcp-cicd" {
  source = "./modules/gcp-cicd"

  location = var.region
}
