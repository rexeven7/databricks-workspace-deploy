output "catalog_name" {
  description = "Catalog name."
  value       = databricks_catalog.this.name
}

output "schema_name" {
  description = "Schema name."
  value       = databricks_schema.this.name
}

output "schema_full_name" {
  description = "Fully-qualified catalog.schema, e.g. dev.sales."
  value       = "${databricks_catalog.this.name}.${databricks_schema.this.name}"
}

output "volume_path" {
  description = "Filesystem path of the landing volume (/Volumes/<catalog>/<schema>/<volume>)."
  value       = "/Volumes/${databricks_catalog.this.name}/${databricks_schema.this.name}/${databricks_volume.landing.name}"
}
