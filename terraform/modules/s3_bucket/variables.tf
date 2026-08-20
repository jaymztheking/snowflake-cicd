variable "name" {
  description = "Bucket name. Must be globally unique across all of AWS."
  type        = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the bucket even when it still holds objects. Defaults to false so a bucket holding real data cannot be emptied by accident."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the bucket"
  type        = map(string)
  default     = {}
}
