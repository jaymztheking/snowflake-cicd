variable "name" {
  description = "Warehouse name"
  type        = string
}

variable "size" {
  description = "Warehouse size"
  type        = string
  default     = "XSMALL"
}

variable "auto_suspend" {
  description = "Seconds of inactivity before the warehouse auto-suspends"
  type        = number
  default     = 60
}

variable "auto_resume" {
  description = "Whether the warehouse auto-resumes on query"
  type        = bool
  default     = true
}
