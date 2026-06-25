output "workspace_id" {
  description = "Azure resource ID of the workspace. Consumed by the databricks provider (azure_workspace_resource_id) in the platform layer."
  value       = azurerm_databricks_workspace.this.id
}

output "workspace_url" {
  description = "Workspace host URL (includes https://) for the Databricks CLI/provider and bundle profiles."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_name" {
  description = "Workspace name."
  value       = azurerm_databricks_workspace.this.name
}
