locals {
  request_files = fileset(var.requests_path, "**/*.yaml")

  requests = {
    for f in local.request_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${var.requests_path}/${f}"))
  }

  # The snowpipe block is optional — requests without one provision no AWS resources.
  snowpipe_requests = {
    for k, r in local.requests : k => r
    if try(r.snowpipe, null) != null
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

module "snowpipe" {
  source   = "./modules/snowpipe"
  for_each = local.snowpipe_requests

  database_name     = module.database[each.key].name
  database_role_fqn = module.database_role[each.key].fully_qualified_name

  bucket_prefix = each.value.snowpipe.bucket_prefix
  path          = try(each.value.snowpipe.path, "")
  iam_role_name = each.value.snowpipe.iam_role_name
  force_destroy = try(each.value.snowpipe.force_destroy, false)
  file_format   = try(each.value.snowpipe.file_format, "JSON")

  schema_name   = each.value.snowpipe.schema.name
  table_name    = each.value.snowpipe.table.name
  table_columns = try(each.value.snowpipe.table.columns, [{ name = "RAW", type = "VARIANT" }])
  stage_name    = each.value.snowpipe.stage.name
  pipe_name     = each.value.snowpipe.pipe.name

  comment = try(each.value.snowpipe.comment, null)
  tags = {
    ManagedBy = "terraform"
    Request   = each.key
  }
}
