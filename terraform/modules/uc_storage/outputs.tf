output "access_connector_id" {
  description = "Azure resource ID of the access connector (consumed by databricks_storage_credential)."
  value       = azurerm_databricks_access_connector.this.id
}

output "storage_url" {
  description = "ADLS Gen2 container root, no trailing slash (e.g. abfss://ucdata@acct.dfs.core.windows.net)."
  value       = "abfss://${azurerm_storage_container.this.name}@${azurerm_storage_account.this.name}.dfs.core.windows.net"
}

output "role_assignment_id" {
  description = "ID of the Storage Blob Data Contributor assignment (used to order downstream UC resources)."
  value       = azurerm_role_assignment.uc.id
}
