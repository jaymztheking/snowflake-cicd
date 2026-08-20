resource "snowflake_stage_external_s3" "this" {
  database            = var.database_name
  schema              = var.schema_name
  name                = var.name
  url                 = var.url
  storage_integration = var.storage_integration
  comment             = var.comment

  file_format {
    dynamic "json" {
      for_each = var.file_format == "JSON" ? [1] : []
      content {}
    }

    dynamic "csv" {
      for_each = var.file_format == "CSV" ? [1] : []
      content {}
    }

    dynamic "parquet" {
      for_each = var.file_format == "PARQUET" ? [1] : []
      content {}
    }
  }
}
