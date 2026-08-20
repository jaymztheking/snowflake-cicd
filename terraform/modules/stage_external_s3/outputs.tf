output "name" {
  value = snowflake_stage_external_s3.this.name
}

output "fully_qualified_name" {
  value = snowflake_stage_external_s3.this.fully_qualified_name
}

# Exposed so callers can build a fingerprint for a pipe's replace_triggered_by — a
# lifecycle block can only reference resources in its own module, so the pipe cannot
# watch these attributes directly. See modules/pipe.
output "url" {
  value = snowflake_stage_external_s3.this.url
}

output "storage_integration" {
  value = snowflake_stage_external_s3.this.storage_integration
}
