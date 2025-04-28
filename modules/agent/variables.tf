variable "region" {
  type        = string
  description = "Region for artifact repository"
}

variable "agent_image_name" {
  type        = string
  description = "Image Name for Cloud Run Container from gcp-brownbag-agent repo"
}
