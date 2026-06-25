# Offline platform tests.
#   - mock_provider stubs the databricks provider (no workspace needed)
#   - override_data stubs the remote-state lookup (no real state / Azure needed)
# Together these let `terraform test` run on a PR with zero credentials.
mock_provider "databricks" {}

override_data {
  target = data.terraform_remote_state.infra
  values = {
    outputs = {
      workspace_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-databricks-dev/providers/Microsoft.Databricks/workspaces/dbw-demo-dev"
      workspace_url = "https://adb-1234567890.0.azuredatabricks.net"
    }
  }
}

variables {
  environment                = "dev"
  catalog_name               = "dev"
  schema_name                = "sales"
  admin_group                = "data-platform-admins"
  data_engineer_group        = "data-engineers"
  warehouse_name             = "wh-demo-dev"
  state_resource_group_name  = "rg-tfstate"
  state_storage_account_name = "sttfstatedbxdemo"
  infra_state_key            = "databricks/dev/10-infra.tfstate"
}

run "catalog_matches_environment" {
  command = plan

  assert {
    condition     = module.unity_catalog.catalog_name == var.catalog_name
    error_message = "Catalog name must match the environment-specific input."
  }
}

run "schema_full_name_is_two_level" {
  command = plan

  assert {
    condition     = module.unity_catalog.schema_full_name == "${var.catalog_name}.${var.schema_name}"
    error_message = "schema_full_name output must be catalog.schema."
  }
}
