data "aws_caller_identity" "current" {}

locals {
  bucket_name = lower("${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}")

  # Normalise the watched prefix so it always ends in "/" (or is empty for whole-bucket).
  path_prefix = var.path == "" ? "" : (endswith(var.path, "/") ? var.path : "${var.path}/")

  s3_url = "s3://${local.bucket_name}/${local.path_prefix}"

  # The IAM role ARN is built as a string rather than read off aws_iam_role, so the
  # storage integration does not depend on the role. The role's trust policy depends on
  # the integration (it needs the ARN and external ID Snowflake generates), and without
  # this indirection that would be a dependency cycle. Snowflake does not verify the role
  # when the integration is created — it is checked on first stage use, by which point
  # aws_iam_role exists.
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.iam_role_name}"
}

# ---------------------------------------------------------------------------
# S3 landing bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "landing" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Snowflake storage integration + the IAM role it assumes
# ---------------------------------------------------------------------------

resource "snowflake_storage_integration_aws" "this" {
  name                      = "${var.database_name}_${var.schema_name}_INT"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = local.iam_role_arn
  storage_allowed_locations = [local.s3_url]
  comment                   = var.comment
}

resource "aws_iam_role" "snowflake" {
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
  role = aws_iam_role.snowflake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.landing.arn}/${local.path_prefix}*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.landing.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["${local.path_prefix}*"]
          }
        }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Snowflake ingest objects
# ---------------------------------------------------------------------------

resource "snowflake_schema" "this" {
  database = var.database_name
  name     = var.schema_name
  comment  = var.comment
}

resource "snowflake_table" "this" {
  database = var.database_name
  schema   = snowflake_schema.this.name
  name     = var.table_name
  comment  = var.comment

  dynamic "column" {
    for_each = var.table_columns

    content {
      name = column.value.name
      type = column.value.type
    }
  }
}

resource "snowflake_stage_external_s3" "this" {
  database            = var.database_name
  schema              = snowflake_schema.this.name
  name                = var.stage_name
  url                 = local.s3_url
  storage_integration = snowflake_storage_integration_aws.this.name
  comment             = var.comment

  file_format {
    dynamic "json" {
      for_each = var.file_format == "JSON" ? [1] : []
      content {}
    }

    dynamic "csv" {
      for_each = var.file_format == "CSV" ? [1] : []
      content {}
    }

    dynamic "parquet" {
      for_each = var.file_format == "PARQUET" ? [1] : []
      content {}
    }
  }
}

resource "snowflake_pipe" "this" {
  database = var.database_name
  schema   = snowflake_schema.this.name
  name     = var.pipe_name
  comment  = var.comment

  auto_ingest    = true
  copy_statement = "COPY INTO ${snowflake_table.this.fully_qualified_name} FROM @${snowflake_stage_external_s3.this.fully_qualified_name}"

  # Snowflake requires the pipe to be recreated when the referenced stage's cloud
  # parameters change, otherwise the SQS notification channel goes stale.
  # https://docs.snowflake.com/en/user-guide/data-load-snowpipe-manage#changing-the-cloud-parameters-of-the-referenced-stage
  lifecycle {
    replace_triggered_by = [
      snowflake_stage_external_s3.this.url,
      snowflake_stage_external_s3.this.storage_integration,
    ]
  }
}

# ---------------------------------------------------------------------------
# S3 -> Snowpipe event notification
# ---------------------------------------------------------------------------

# This resource is authoritative for the bucket's entire notification config, which
# is safe here only because each request owns its own bucket.
resource "aws_s3_bucket_notification" "pipe" {
  bucket = aws_s3_bucket.landing.id

  queue {
    queue_arn     = snowflake_pipe.this.notification_channel
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = local.path_prefix != "" ? local.path_prefix : null
  }
}

# ---------------------------------------------------------------------------
# Grants — let the request's database role actually read what was provisioned
# ---------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_database_role" "schema_usage" {
  count = var.database_role_fqn != null ? 1 : 0

  database_role_name = var.database_role_fqn
  privileges         = ["USAGE"]

  on_schema {
    schema_name = snowflake_schema.this.fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_database_role" "stage_read" {
  count = var.database_role_fqn != null ? 1 : 0

  database_role_name = var.database_role_fqn
  privileges         = ["READ"]

  on_schema_object {
    object_type = "STAGE"
    object_name = snowflake_stage_external_s3.this.fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_database_role" "table_read" {
  count = var.database_role_fqn != null ? 1 : 0

  database_role_name = var.database_role_fqn
  privileges         = ["SELECT", "INSERT"]

  on_schema_object {
    object_type = "TABLE"
    object_name = snowflake_table.this.fully_qualified_name
  }
}
