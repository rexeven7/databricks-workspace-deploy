environment         = "prod"
location            = "eastus2"
resource_group_name = "rg-databricks-prod"
workspace_name      = "dbw-demo-prod"
sku                 = "premium"

tags = {
  cost_center = "data-platform"
  owner       = "data-platform@example.com"
}
