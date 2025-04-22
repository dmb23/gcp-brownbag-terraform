# gcp-brownbag-terraform

Steps I took to bootstrap this configuration:

- after provisioning the bucket for the remote state, I migrated local state to the remote backend: `terraform init -migrate-state`
- I needed to import the existing project to get the project number. I had to [generated the config](https://developer.hashicorp.com/terraform/language/import/generating-configuration) so that the billing account would not get unlinked. I then refactored this information into proper variables.
