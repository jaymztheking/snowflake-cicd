output "id" {
  description = "Bucket name, as used by other S3 resources"
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}
