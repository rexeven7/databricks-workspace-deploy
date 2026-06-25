output "catalog_name" {
  description = "Catalog created for this environment."
  value       = module.unity_catalog.catalog_name
}

output "schema_full_name" {
  description = "Fully-qualified catalog.schema (feed to the bundle)."
  value       = module.unity_catalog.schema_full_name
}

output "volume_path" {
  description = "Landing volume path."
  value       = module.unity_catalog.volume_path
}

output "warehouse_id" {
  description = "SQL warehouse id. Set this as the bundle's warehouse_id variable."
  value       = module.sql_warehouse.warehouse_id
}
