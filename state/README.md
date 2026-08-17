# Terraform state

`terraform.tfstate` in this directory is written and committed automatically by
the `Terraform Apply` GitHub Actions workflow after a successful apply. Do not
edit it by hand. It does not exist until the first successful apply runs.

See the root `README.md` for why state lives here instead of a remote backend.
