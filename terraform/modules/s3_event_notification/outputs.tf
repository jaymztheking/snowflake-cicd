output "id" {
  description = "ID of the notification configuration (the bucket name)"
  value       = aws_s3_bucket_notification.this.id
}
