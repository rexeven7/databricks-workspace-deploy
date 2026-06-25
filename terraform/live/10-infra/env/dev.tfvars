environment         = "dev"
location            = "eastus2"
resource_group_name = "rg-databricks-dev"
workspace_name      = "dbw-demo-dev"
sku                 = "premium"

# ADLS Gen2 account for the UC catalog managed location (globally unique - change me).
uc_storage_account_name = "stdbxucdev0001"

tags = {
  cost_center = "data-platform"
  owner       = "data-platform@example.com"
}
