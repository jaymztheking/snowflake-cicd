# This resource is authoritative for the bucket's entire notification config — a second
# one targeting the same bucket silently replaces the first. Safe here only because each
# request owns its own bucket.
resource "aws_s3_bucket_notification" "this" {
  bucket = var.bucket_id

  queue {
    queue_arn     = var.queue_arn
    events        = var.events
    filter_prefix = var.filter_prefix != "" ? var.filter_prefix : null
  }
}
