environment         = "dev"
catalog_name        = "dev"
schema_name         = "sales"
volume_name         = "landing"
admin_group         = "data-platform-admins"
data_engineer_group = "data-engineers"
warehouse_name      = "wh-demo-dev"
warehouse_size      = "2X-Small"

# Locator for layer 10's remote state (must match 10-infra/env/dev.backend.hcl).
state_resource_group_name  = "rg-tfstate"
state_storage_account_name = "sttfstatedbxdemo"
state_container_name       = "tfstate"
infra_state_key            = "databricks/dev/10-infra.tfstate"

tags = {
  cost_center = "data-platform"
}
