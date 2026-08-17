variable "name" {
  description = "Functional (account-level) role name"
  type        = string
}

variable "database_role_fqns" {
  description = "Fully-qualified database role names to grant to this functional role"
  type        = list(string)
  default     = []
}

variable "warehouse_name" {
  description = "Warehouse to grant USAGE on, if warehouse_usage is true"
  type        = string
  default     = null
}

variable "warehouse_usage" {
  description = "Whether to grant this role USAGE on warehouse_name"
  type        = bool
  default     = false
}
