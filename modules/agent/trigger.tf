# Create an Eventarc trigger for Cloud Storage events
resource "google_eventarc_trigger" "storage_trigger" {
  name     = "storage-finalize-trigger"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.report-bucket.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.function_service.name
      region  = var.region
    }
  }

  service_account = google_service_account.function_service_account.email

}
