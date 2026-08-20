locals {
  # The IAM role ARN is built as a string rather than read off aws_iam_role, so the
  # storage integration does not depend on the role. The role's trust policy depends on
  # the integration (it needs the ARN and external ID Snowflake generates), and without
  # this indirection that would be a dependency cycle. Snowflake does not verify the role
  # when the integration is created.
  #
  # This is why the whole trick lives in one module: split across two, the ordering below
  # becomes the caller's problem and is easy to get wrong.
  iam_role_arn = "arn:aws:iam::${var.aws_account_id}:role/${var.iam_role_name}"
}

resource "snowflake_storage_integration_aws" "this" {
  name                      = var.integration_name
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = local.iam_role_arn
  storage_allowed_locations = [var.s3_url]
  comment                   = var.comment
}

resource "aws_iam_role" "this" {
  name = var.iam_role_name
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        AWS = snowflake_storage_integration_aws.this.describe_output[0].iam_user_arn
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = snowflake_storage_integration_aws.this.describe_output[0].external_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "s3_read" {
  name = "${var.iam_role_name}-s3-read"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.bucket_arn}/${var.path_prefix}*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.path_prefix}*"]
          }
        }
      },
    ]
  })
}

# Creating a pipe is the first operation that makes Snowflake actually assume the role
# above (CREATE PIPE with AUTO_INGEST validates the stage's credentials; CREATE STAGE does
# not). IAM is eventually consistent, so a trust policy written seconds earlier is not yet
# usable and the pipe fails with:
#
#   003167 (42601): Error assuming AWS_ROLE: ... is not authorized to perform:
#   sts:AssumeRole on resource: .../SNOWFLAKE_<NAME>_ROLE
#
# Because the ARN indirection above means nothing downstream references aws_iam_role,
# Terraform would otherwise build the role and the pipe in parallel. Callers should hang
# their pipe off this module with depends_on.
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy.s3_read]
  create_duration = var.iam_propagation_delay
}
