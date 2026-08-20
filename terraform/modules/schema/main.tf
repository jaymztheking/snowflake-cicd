resource "snowflake_schema" "this" {
  database = var.database_name
  name     = var.name
  comment  = var.comment
}
