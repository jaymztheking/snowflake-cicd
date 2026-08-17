locals {
  request_files = fileset(var.requests_path, "**/*.yaml")

  requests = {
    for f in local.request_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${var.requests_path}/${f}"))
  }
}

module "database" {
  source   = "./modules/database"
  for_each = local.requests

  name    = each.value.database.name
  comment = try(each.value.database.comment, null)
}

module "warehouse" {
  source   = "./modules/warehouse"
  for_each = local.requests

  name         = each.value.warehouse.name
  size         = try(each.value.warehouse.size, "XSMALL")
  auto_suspend = try(each.value.warehouse.auto_suspend, 60)
  auto_resume  = try(each.value.warehouse.auto_resume, true)
}

module "database_role" {
  source   = "./modules/database_role"
  for_each = local.requests

  name          = each.value.database_role.name
  database_name = module.database[each.key].name
  grants        = try(each.value.database_role.grants, [])
}

module "functional_role" {
  source   = "./modules/functional_role"
  for_each = local.requests

  name               = each.value.functional_role.name
  database_role_fqns = [module.database_role[each.key].fully_qualified_name]
  warehouse_name     = module.warehouse[each.key].name
  warehouse_usage    = try(each.value.functional_role.warehouse_usage, false)
}
