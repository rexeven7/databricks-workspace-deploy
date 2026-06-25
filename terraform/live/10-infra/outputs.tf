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
