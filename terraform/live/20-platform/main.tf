# =============================================================================
# Layer 20 - PLATFORM (inside the workspace)
# Owns: Unity Catalog (catalog/schema/volume/grants) + serverless SQL warehouse.
# Uses ONLY the databricks provider, pointed at the layer-10 workspace.
# =============================================================================

locals {
  common_tags = merge({
    environment = var.environment
    managed_by  = "terraform"
    project     = "databricks-workspace-deploy"
  }, var.tags)
}

# Read layer 10's outputs (workspace id/url) from its remote state.
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = var.infra_state_key
  }
}

module "unity_catalog" {
  source = "../../modules/unity_catalog"

  catalog_name        = var.catalog_name
  schema_name         = var.schema_name
  volume_name         = var.volume_name
  environment         = var.environment
  admin_group         = var.admin_group
  data_engineer_group = var.data_engineer_group
}

module "sql_warehouse" {
  source = "../../modules/sql_warehouse"

  warehouse_name      = var.warehouse_name
  cluster_size        = var.warehouse_size
  data_engineer_group = var.data_engineer_group
  tags                = local.common_tags
}
