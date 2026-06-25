# Native Terraform tests (terraform test). `mock_provider` generates fake values
# for every azurerm resource, so these run with NO Azure credentials - perfect for
# fast PR validation in CI. Source for this pattern: the Databricks "Terraform
# provider" guide (Testing section) recommends mocking the provider so tests run
# without deploying or authenticating.
mock_provider "azurerm" {}

variables {
  environment             = "dev"
  location                = "eastus2"
  resource_group_name     = "rg-databricks-dev"
  workspace_name          = "dbw-demo-dev"
  uc_storage_account_name = "stdbxucdev0001"
}

run "premium_sku_is_default" {
  command = plan

  assert {
    condition     = var.sku == "premium"
    error_message = "Default SKU must be 'premium' so Unity Catalog and serverless SQL are available."
  }
}

run "resource_group_in_configured_region" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.location == var.location
    error_message = "Resource group must be created in the configured region."
  }
}

run "common_tags_include_environment" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.tags["environment"] == var.environment
    error_message = "Every resource must carry an 'environment' tag for cost allocation."
  }
}
