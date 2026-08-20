variable "database_name" {
  description = "Database to create the schema in"
  type        = string
}

variable "name" {
  description = "Schema name"
  type        = string
}

variable "comment" {
  description = "Optional comment on the schema"
  type        = string
  default     = null
}
