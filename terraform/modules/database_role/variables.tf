variable "name" {
  description = "Database role name"
  type        = string
}

variable "database_name" {
  description = "Name of the database this role is scoped to"
  type        = string
}

variable "grants" {
  description = "Privileges to grant this role on its database"
  type = list(object({
    privilege = string
    on        = string
  }))
  default = []
}
