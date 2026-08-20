variable "database_name" {
  description = "Database to create the pipe in"
  type        = string
}

variable "schema_name" {
  description = "Schema to create the pipe in"
  type        = string
}

variable "name" {
  description = "Pipe name"
  type        = string
}

variable "copy_statement" {
  description = "COPY INTO statement the pipe runs"
  type        = string
}

variable "auto_ingest" {
  description = "Whether the pipe ingests automatically from cloud storage notifications"
  type        = bool
  default     = true
}

variable "stage_fingerprint" {
  description = "A string derived from the referenced stage's cloud parameters (url, storage integration). When it changes the pipe is recreated. See the note in main.tf."
  type        = string
}

variable "comment" {
  description = "Optional comment on the pipe"
  type        = string
  default     = null
}
