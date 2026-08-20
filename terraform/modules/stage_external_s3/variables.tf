variable "database_name" {
  description = "Database to create the stage in"
  type        = string
}

variable "schema_name" {
  description = "Schema to create the stage in"
  type        = string
}

variable "name" {
  description = "Stage name"
  type        = string
}

variable "url" {
  description = "s3:// URL the stage points at, including any key prefix"
  type        = string
}

variable "storage_integration" {
  description = "Name of the storage integration used to authenticate to S3"
  type        = string
}

variable "file_format" {
  description = "File format of the staged data"
  type        = string
  default     = "JSON"

  validation {
    condition     = contains(["JSON", "CSV", "PARQUET"], var.file_format)
    error_message = "file_format must be one of JSON, CSV or PARQUET."
  }
}

variable "comment" {
  description = "Optional comment on the stage"
  type        = string
  default     = null
}
