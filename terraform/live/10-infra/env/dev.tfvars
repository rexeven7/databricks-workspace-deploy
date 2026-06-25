environment         = "dev"
location            = "eastus2"
resource_group_name = "rg-databricks-dev"
workspace_name      = "dbw-demo-dev"
sku                 = "premium"

tags = {
  cost_center = "data-platform"
  owner       = "data-platform@example.com"
}
