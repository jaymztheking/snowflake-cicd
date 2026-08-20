# The composite itself only uses the AWS provider directly (for aws_caller_identity).
# Child modules declare their own requirements and inherit provider configuration from
# the root.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
