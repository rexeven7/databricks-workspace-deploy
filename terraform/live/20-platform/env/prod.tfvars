environment         = "prod"
catalog_name        = "prod"
schema_name         = "sales"
volume_name         = "landing"
admin_group         = "account users"
data_engineer_group = "account users"
warehouse_name      = "wh-demo-prod"
warehouse_size      = "Small"

# Locator for layer 10's remote state (must match 10-infra/env/prod.backend.hcl).
state_resource_group_name  = "rg-tfstate"
state_storage_account_name = "sttfstatedbxdemo"
state_container_name       = "tfstate"
infra_state_key            = "databricks/prod/10-infra.tfstate"

tags = {
  cost_center = "data-platform"
}
