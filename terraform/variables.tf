variable "requests_path" {
  description = "Path to the directory containing request YAML files"
  type        = string
  default     = "../requests"
}

variable "aws_region" {
  description = "AWS region for Snowpipe landing buckets and IAM. Set via TF_VAR_aws_region in CI."
  type        = string
  default     = "us-east-1"
}
