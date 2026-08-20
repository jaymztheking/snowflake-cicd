resource "snowflake_table" "this" {
  database = var.database_name
  schema   = var.schema_name
  name     = var.name
  comment  = var.comment

  dynamic "column" {
    for_each = var.columns

    content {
      name = column.value.name
      type = column.value.type
    }
  }
}
