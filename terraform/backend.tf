terraform {
  # Partial configuration: the bucket and region are supplied at init time rather
  # than hardcoded, so this public repo doesn't name the state location.
  #
  #   local:  terraform init -backend-config=backend.hcl
  #   CI:     terraform init -backend-config="bucket=..." -backend-config="region=..."
  #
  # use_lockfile puts the lock in the state bucket itself (Terraform 1.10+), so
  # there is no DynamoDB table to provision or pay for.
  backend "s3" {
    key          = "snowflake-cicd/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
