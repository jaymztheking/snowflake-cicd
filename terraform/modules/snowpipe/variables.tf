variable "database_name" {
  description = "Database the schema, table, stage and pipe are created in"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for the landing bucket name; the AWS account ID is appended to make it globally unique"
  type        = string
}

variable "path" {
  description = "Key prefix inside the bucket that Snowpipe watches, e.g. \"raw/\". Empty means the whole bucket."
  type        = string
  default     = ""
}

variable "iam_role_name" {
  description = "Name of the IAM role Snowflake assumes to read the bucket"
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

variable "schema_name" {
  description = "Schema to create for the ingest objects"
  type        = string
}

variable "table_name" {
  description = "Landing table the pipe copies into"
  type        = string
}

variable "table_columns" {
  description = "Landing table columns. Defaults to a single VARIANT column for raw JSON."
  type = list(object({
    name = string
    type = string
  }))
  default = [{
    name = "RAW"
    type = "VARIANT"
  }]

  validation {
    condition     = length(var.table_columns) > 0
    error_message = "table_columns must contain at least one column."
  }
}

variable "stage_name" {
  description = "External stage name"
  type        = string
}

variable "pipe_name" {
  description = "Pipe name"
  type        = string
}

variable "comment" {
  description = "Optional comment applied to the Snowflake ingest objects"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete the landing bucket even when it still holds objects. Defaults to false so a bucket holding real data cannot be emptied by accident; set true for throwaway/POC requests."
  type        = bool
  default     = false
}

variable "iam_propagation_delay" {
  description = "How long to wait after writing the IAM trust policy before creating the pipe, so the cross-account role is assumable. See time_sleep.iam_propagation in main.tf."
  type        = string
  default     = "60s"
}

variable "database_role_fqn" {
  description = "Database role to grant read access on the ingest objects. Null skips the grants."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the AWS resources"
  type        = map(string)
  default     = {}
}
