output "integration_name" {
  description = "Name of the storage integration, for use as a stage's storage_integration"
  value       = snowflake_storage_integration_aws.this.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role Snowflake assumes"
  value       = aws_iam_role.this.arn
}

output "iam_user_arn" {
  description = "Snowflake's IAM user ARN, as trusted by the role"
  value       = snowflake_storage_integration_aws.this.describe_output[0].iam_user_arn
}
