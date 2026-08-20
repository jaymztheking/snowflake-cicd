output "bucket_name" {
  description = "Name of the S3 landing bucket"
  value       = module.bucket.id
}

output "bucket_arn" {
  description = "ARN of the S3 landing bucket"
  value       = module.bucket.arn
}

output "s3_url" {
  description = "S3 URL Snowpipe watches, including the key prefix"
  value       = local.s3_url
}

output "iam_role_arn" {
  description = "ARN of the IAM role Snowflake assumes"
  value       = module.s3_access.iam_role_arn
}

output "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  value       = module.s3_access.integration_name
}

output "schema_name" {
  description = "Name of the ingest schema"
  value       = module.schema.name
}

output "table_fqn" {
  description = "Fully-qualified name of the landing table"
  value       = module.table.fully_qualified_name
}

output "stage_fqn" {
  description = "Fully-qualified name of the external stage"
  value       = module.stage.fully_qualified_name
}

output "pipe_fqn" {
  description = "Fully-qualified name of the pipe"
  value       = module.pipe.fully_qualified_name
}

output "notification_channel" {
  description = "SQS queue ARN Snowpipe listens on; wired into the bucket's event notification"
  value       = module.pipe.notification_channel
}
