resource "snowflake_database" "this" {
  name    = var.name
  comment = var.comment
}
