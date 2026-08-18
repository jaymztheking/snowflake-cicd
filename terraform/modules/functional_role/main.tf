resource "snowflake_account_role" "this" {
  name = var.name
}

resource "snowflake_grant_database_role" "this" {
  for_each = { for idx, fqn in var.database_role_fqns : idx => fqn }

  database_role_name = each.value
  parent_role_name   = snowflake_account_role.this.name
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  count = var.warehouse_usage ? 1 : 0

  account_role_name = snowflake_account_role.this.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }
}
