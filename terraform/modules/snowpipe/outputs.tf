output "bucket_name" {
  description = "Name of the S3 landing bucket"
  value       = aws_s3_bucket.landing.id
}

output "bucket_arn" {
  description = "ARN of the S3 landing bucket"
  value       = aws_s3_bucket.landing.arn
}

output "s3_url" {
  description = "S3 URL Snowpipe watches, including the key prefix"
  value       = local.s3_url
}

output "iam_role_arn" {
  description = "ARN of the IAM role Snowflake assumes"
  value       = aws_iam_role.snowflake.arn
}

output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = snowflake_storage_integration_aws.this.name
}

output "schema_name" {
  description = "Name of the ingest schema"
  value       = snowflake_schema.this.name
}

output "table_fqn" {
  description = "Fully-qualified name of the landing table"
  value       = snowflake_table.this.fully_qualified_name
}

output "stage_fqn" {
  description = "Fully-qualified name of the external stage"
  value       = snowflake_stage_external_s3.this.fully_qualified_name
}

output "pipe_fqn" {
  description = "Fully-qualified name of the pipe"
  value       = snowflake_pipe.this.fully_qualified_name
}

output "notification_channel" {
  description = "SQS queue ARN Snowpipe listens on; wired into the bucket's event notification"
  value       = snowflake_pipe.this.notification_channel
}
