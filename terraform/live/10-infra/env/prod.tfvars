environment         = "prod"
location            = "eastus2"
resource_group_name = "rg-databricks-prod"
workspace_name      = "dbw-demo-prod"
sku                 = "premium"

# Example values — production deploys override via GitHub Environment variables
# (WORKSPACE_NAME, UC_STORAGE_ACCOUNT_NAME, …) or workflow_dispatch slug inputs.
# See docs/DEMO-SETUP.md.
uc_storage_account_name = "stdbxucprod0001"

tags = {
  cost_center = "data-platform"
  owner       = "data-platform@example.com"
}
