terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
    aws = {
      source = "hashicorp/aws"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
