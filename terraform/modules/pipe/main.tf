# Snowflake requires the pipe to be recreated when the referenced stage's cloud parameters
# change, otherwise the SQS notification channel goes stale:
# https://docs.snowflake.com/en/user-guide/data-load-snowpipe-manage#changing-the-cloud-parameters-of-the-referenced-stage
#
# A lifecycle block can only reference resources in its own module, so the pipe cannot
# watch the stage's attributes directly once the stage lives elsewhere. This anchors the
# trigger to a local resource whose input is a caller-supplied fingerprint of those
# attributes instead.
resource "terraform_data" "stage_fingerprint" {
  input = var.stage_fingerprint
}

resource "snowflake_pipe" "this" {
  database = var.database_name
  schema   = var.schema_name
  name     = var.name
  comment  = var.comment

  auto_ingest    = var.auto_ingest
  copy_statement = var.copy_statement

  lifecycle {
    replace_triggered_by = [terraform_data.stage_fingerprint]
  }
}
