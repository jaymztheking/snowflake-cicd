resource "snowflake_database_role" "this" {
  database = var.database_name
  name     = var.name
}

resource "snowflake_grant_privileges_to_database_role" "this" {
  for_each = { for idx, g in var.grants : idx => g if g.on == "DATABASE" }

  database_role_name = snowflake_database_role.this.fully_qualified_name
  privileges         = [each.value.privilege]
  on_database        = var.database_name
}
