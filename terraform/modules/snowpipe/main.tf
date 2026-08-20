data "aws_caller_identity" "current" {}

locals {
  bucket_name = lower("${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}")

  # Normalise the watched prefix so it always ends in "/" (or is empty for whole-bucket).
  path_prefix = var.path == "" ? "" : (endswith(var.path, "/") ? var.path : "${var.path}/")

  s3_url = "s3://${local.bucket_name}/${local.path_prefix}"

  # Must not be derived from database_role_fqn: that is a module output which is unknown
  # at plan time on a fresh apply, and Terraform refuses a module count it cannot resolve.
  grants_enabled = var.create_grants ? 1 : 0
}

# ---------------------------------------------------------------------------
# AWS: landing bucket
# ---------------------------------------------------------------------------

module "bucket" {
  source = "../s3_bucket"

  name          = local.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# ---------------------------------------------------------------------------
# The S3 <-> Snowflake trust relationship
#
# Storage integration, IAM role, its read policy, and the IAM propagation wait all live in
# one module because they are mutually entangled — see the cycle-break note in
# modules/snowflake_s3_access/main.tf.
# ---------------------------------------------------------------------------

module "s3_access" {
  source = "../snowflake_s3_access"

  integration_name      = "${var.database_name}_${var.schema_name}_INT"
  iam_role_name         = var.iam_role_name
  aws_account_id        = data.aws_caller_identity.current.account_id
  bucket_arn            = module.bucket.arn
  s3_url                = local.s3_url
  path_prefix           = local.path_prefix
  iam_propagation_delay = var.iam_propagation_delay
  comment               = var.comment
  tags                  = var.tags
}

# ---------------------------------------------------------------------------
# Snowflake: ingest objects
# ---------------------------------------------------------------------------

module "schema" {
  source = "../schema"

  database_name = var.database_name
  name          = var.schema_name
  comment       = var.comment
}

module "table" {
  source = "../table"

  database_name = var.database_name
  schema_name   = module.schema.name
  name          = var.table_name
  columns       = var.table_columns
  comment       = var.comment
}

module "stage" {
  source = "../stage_external_s3"

  database_name       = var.database_name
  schema_name         = module.schema.name
  name                = var.stage_name
  url                 = local.s3_url
  storage_integration = module.s3_access.integration_name
  file_format         = var.file_format
  comment             = var.comment
}

module "pipe" {
  source = "../pipe"

  # Waits out IAM propagation. CREATE PIPE with AUTO_INGEST is the first operation that
  # assumes the IAM role, and nothing else in the Snowflake chain depends on it.
  depends_on = [module.s3_access]

  database_name  = var.database_name
  schema_name    = module.schema.name
  name           = var.pipe_name
  auto_ingest    = true
  copy_statement = "COPY INTO ${module.table.fully_qualified_name} FROM @${module.stage.fully_qualified_name}"
  comment        = var.comment

  stage_fingerprint = join("|", [module.stage.url, module.stage.storage_integration])
}

# ---------------------------------------------------------------------------
# AWS: the event notification that drives the pipe
# ---------------------------------------------------------------------------

module "notification" {
  source = "../s3_event_notification"

  bucket_id     = module.bucket.id
  queue_arn     = module.pipe.notification_channel
  filter_prefix = local.path_prefix
}

# ---------------------------------------------------------------------------
# Grants — let the request's database role actually read what was provisioned
# ---------------------------------------------------------------------------

module "grant_schema_usage" {
  source = "../database_role_grant"
  count  = local.grants_enabled

  database_role_name = var.database_role_fqn
  privileges         = ["USAGE"]
  schema_name        = module.schema.fully_qualified_name
}

module "grant_stage_read" {
  source = "../database_role_grant"
  count  = local.grants_enabled

  database_role_name = var.database_role_fqn
  privileges         = ["READ"]
  object_type        = "STAGE"
  object_name        = module.stage.fully_qualified_name
}

module "grant_table_read" {
  source = "../database_role_grant"
  count  = local.grants_enabled

  database_role_name = var.database_role_fqn
  privileges         = ["SELECT", "INSERT"]
  object_type        = "TABLE"
  object_name        = module.table.fully_qualified_name
}
