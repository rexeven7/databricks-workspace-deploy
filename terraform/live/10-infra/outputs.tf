# These outputs are read by layer 20 (platform) via a terraform_remote_state
# data source, and printed for use in Databricks CLI / bundle profiles.
output "workspace_id" {
  description = "Azure resource ID of the workspace."
  value       = module.workspace.workspace_id
}

output "workspace_url" {
  description = "Workspace host URL."
  value       = module.workspace.workspace_url
}

output "resource_group_name" {
  description = "Resource group containing the workspace."
  value       = azurerm_resource_group.this.name
}

output "uc_access_connector_id" {
  description = "Access connector resource ID for the UC storage credential (consumed by layer 20)."
  value       = module.uc_storage.access_connector_id
}

output "uc_storage_url" {
  description = "ADLS Gen2 container root for the UC managed location (consumed by layer 20)."
  value       = module.uc_storage.storage_url
}
