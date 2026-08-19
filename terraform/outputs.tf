output "provisioned_requests" {
  description = "Keys (team/name) of every request currently provisioned"
  value       = keys(local.requests)
}

output "snowpipe" {
  description = "Snowpipe ingest details per request, keyed by team/name"
  value = {
    for k, m in module.snowpipe : k => {
      bucket               = m.bucket_name
      s3_url               = m.s3_url
      iam_role_arn         = m.iam_role_arn
      storage_integration  = m.storage_integration_name
      table                = m.table_fqn
      stage                = m.stage_fqn
      pipe                 = m.pipe_fqn
      notification_channel = m.notification_channel
    }
  }
}
