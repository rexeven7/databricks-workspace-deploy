environment         = "prod"
location            = "eastus2"
resource_group_name = "rg-databricks-prod"
workspace_name      = "dbw-demo-prod"
sku                 = "premium"

# ADLS Gen2 account for the UC catalog managed location (globally unique - change me).
uc_storage_account_name = "stdbxucprod0001"

tags = {
  cost_center = "data-platform"
  owner       = "data-platform@example.com"
}
