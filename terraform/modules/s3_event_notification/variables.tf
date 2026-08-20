variable "bucket_id" {
  description = "Bucket to attach the notification configuration to"
  type        = string
}

variable "queue_arn" {
  description = "SQS queue ARN to notify. For Snowpipe this is the pipe's notification_channel, a queue Snowflake owns."
  type        = string
}

variable "events" {
  description = "S3 event types that trigger a notification"
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "filter_prefix" {
  description = "Key prefix to filter on. Empty means the whole bucket."
  type        = string
  default     = ""
}
