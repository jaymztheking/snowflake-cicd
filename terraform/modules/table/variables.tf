variable "database_name" {
  description = "Database to create the table in"
  type        = string
}

variable "schema_name" {
  description = "Schema to create the table in"
  type        = string
}

variable "name" {
  description = "Table name"
  type        = string
}

variable "columns" {
  description = "Table columns. At least one is required by Snowflake."
  type = list(object({
    name = string
    type = string
  }))

  validation {
    condition     = length(var.columns) > 0
    error_message = "columns must contain at least one column."
  }
}

variable "comment" {
  description = "Optional comment on the table"
  type        = string
  default     = null
}
