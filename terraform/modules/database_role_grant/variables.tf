variable "database_role_name" {
  description = "Fully-qualified name of the database role receiving the grant"
  type        = string
}

variable "privileges" {
  description = "Privileges to grant, e.g. [\"USAGE\"] or [\"SELECT\", \"INSERT\"]"
  type        = list(string)
}

variable "schema_name" {
  description = "Fully-qualified schema name to grant on. Mutually exclusive with object_name."
  type        = string
  default     = null
}

variable "object_type" {
  description = "Object type when granting on a schema object, e.g. TABLE or STAGE"
  type        = string
  default     = null
}

variable "object_name" {
  description = "Fully-qualified object name to grant on. Mutually exclusive with schema_name."
  type        = string
  default     = null

  validation {
    condition     = (var.schema_name != null) != (var.object_name != null)
    error_message = "Set exactly one of schema_name (grant on a schema) or object_name (grant on a schema object)."
  }

  validation {
    condition     = var.object_name == null || var.object_type != null
    error_message = "object_type is required when object_name is set."
  }
}
