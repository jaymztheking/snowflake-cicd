terraform {
  required_version = ">= 1.6.0"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
    }
  }
}

# All connection details (organization, account, user, private key) are read from
# the standard SNOWFLAKE_* environment variables set by the GitHub Actions workflows.
provider "snowflake" {
  authenticator = "SNOWFLAKE_JWT"
}
