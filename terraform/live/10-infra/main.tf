# =============================================================================
# Layer 10 - INFRASTRUCTURE (Azure control plane)
# Owns: resource group + the Databricks workspace. Uses ONLY the azurerm provider.
# Separated from layer 20 (platform) so cloud-admin-level changes have their own
# state, blast radius and credentials. See docs/INTERVIEW.md for the rationale.
# =============================================================================

locals {
  common_tags = merge({
    environment = var.environment
    managed_by  = "terraform"
    project     = "databricks-workspace-deploy"
  }, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "workspace" {
  source = "../../modules/workspace"

  workspace_name      = var.workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku                 = var.sku
  tags                = local.common_tags
}

# Storage + access connector for the Unity Catalog catalog's managed location.
module "uc_storage" {
  source = "../../modules/uc_storage"

  access_connector_name = "${var.workspace_name}-uc"
  storage_account_name  = var.uc_storage_account_name
  resource_group_name   = azurerm_resource_group.this.name
  location              = var.location
  tags                  = local.common_tags
}
