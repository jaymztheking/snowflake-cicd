variable "integration_name" {
  description = "Name of the Snowflake storage integration"
  type        = string
}

variable "iam_role_name" {
  description = "Name of the IAM role Snowflake assumes to read the bucket"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID, used to construct the IAM role ARN without referencing aws_iam_role. See the cycle-break note in main.tf."
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the bucket the role is granted read access to"
  type        = string
}

variable "s3_url" {
  description = "s3:// URL (including key prefix) the integration is allowed to access"
  type        = string
}

variable "path_prefix" {
  description = "Key prefix the IAM policy is scoped to. Empty means the whole bucket."
  type        = string
  default     = ""
}

variable "iam_propagation_delay" {
  description = "How long to wait after writing the IAM trust policy before dependents run, so the cross-account role is assumable. See time_sleep.iam_propagation in main.tf."
  type        = string
  default     = "60s"
}

variable "comment" {
  description = "Optional comment on the storage integration"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the IAM role"
  type        = map(string)
  default     = {}
}
