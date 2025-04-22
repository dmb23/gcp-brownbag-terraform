# gcp-brownbag-terraform

Steps I took to bootstrap this configuration:

- after provisioning the bucket for the remote state, I migrated local state to the remote backend: `terraform init -migrate-state`
- I needed to import the existing project to get the project number. I had to [generated the config](https://developer.hashicorp.com/terraform/language/import/generating-configuration) so that the billing account would not get unlinked. I then refactored this information into proper variables.
- I found that I can get the project number via the data source for a project (`data "google_project" "project"`). When switching to that solution I had to `terraform state rm "google_project.default"` to forget about the formerly imported project (and not delete the project I am working in...)
- I had to add branch protection rules manually in github. I enforce that all status checks need to have passed. For that I need to send the result of the cloudbuild pipelines back to github.
