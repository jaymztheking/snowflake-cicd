terraform {
  # >= 1.10 for the S3 backend's native use_lockfile support (see backend.tf).
  required_version = ">= 1.10.0"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# All connection details (organization, account, user, private key) are read from
# the standard SNOWFLAKE_* environment variables set by the GitHub Actions workflows.
provider "snowflake" {
  authenticator = "SNOWFLAKE_JWT"

  # snowflake_pipe and snowflake_table are still preview resources in the provider —
  # they must be opted into by name or the plan fails with "preview feature not enabled".
  preview_features_enabled = [
    "snowflake_pipe_resource",
    "snowflake_table_resource",
  ]
}

# Credentials come from the GitHub OIDC role assumed by the workflows
# (aws-actions/configure-aws-credentials), or from the local AWS profile.
provider "aws" {
  region = var.aws_region
}
