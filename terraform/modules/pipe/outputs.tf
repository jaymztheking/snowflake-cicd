output "name" {
  value = snowflake_pipe.this.name
}

output "fully_qualified_name" {
  value = snowflake_pipe.this.fully_qualified_name
}

output "notification_channel" {
  description = "ARN of the SQS queue Snowpipe listens on. Snowflake owns this queue; point the bucket's event notification at it."
  value       = snowflake_pipe.this.notification_channel
}
