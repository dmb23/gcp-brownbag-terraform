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
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "gcp-cicd" {
  source = "./modules/gcp-cicd"

  location = var.region
}

import {
  to = google_project.default
  id = var.project_id
}

resource "google_project" "default" {
  auto_create_network = true
  billing_account     = var.billing_account
  deletion_policy     = "PREVENT"
  folder_id           = null
  labels              = {}
  name                = var.project_name
  org_id              = null
  project_id          = var.project_id
  tags                = null
}
