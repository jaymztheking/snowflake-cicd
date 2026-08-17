variable "name" {
  description = "Database name"
  type        = string
}

variable "comment" {
  description = "Optional comment on the database"
  type        = string
  default     = null
}
