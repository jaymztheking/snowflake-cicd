# One grant to a database role, targeting either a schema (on_schema) or an object inside
# a schema (on_schema_object). Exactly one of schema_name / object_name must be set.
resource "snowflake_grant_privileges_to_database_role" "this" {
  database_role_name = var.database_role_name
  privileges         = var.privileges

  dynamic "on_schema" {
    for_each = var.schema_name != null ? [1] : []

    content {
      schema_name = var.schema_name
    }
  }

  dynamic "on_schema_object" {
    for_each = var.object_name != null ? [1] : []

    content {
      object_type = var.object_type
      object_name = var.object_name
    }
  }
}
