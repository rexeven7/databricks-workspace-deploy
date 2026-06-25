terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }
}

# The Azure Databricks workspace. This is the only control-plane resource the
# project team manages directly. The "managed resource group" (the VMs, NSGs,
# storage that back compute) is created and owned by Databricks automatically.
#
# WHY premium SKU by default: Unity Catalog, fine-grained RBAC, and serverless
# SQL all require the premium tier. Standard exists only for legacy use.
resource "azurerm_databricks_workspace" "this" {
  name                          = var.workspace_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  managed_resource_group_name   = var.managed_resource_group_name
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}
