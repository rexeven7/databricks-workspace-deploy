terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }
}

# Azure-side prerequisites for a Unity Catalog managed location ("bring your own
# storage"). Required on accounts where the metastore has no default storage root
# (UC Default Storage): a new catalog must be given an explicit MANAGED LOCATION
# backed by an external location + storage credential.

# Managed identity that Unity Catalog uses to access the storage account.
resource "azurerm_databricks_access_connector" "this" {
  name                = var.access_connector_name
  resource_group_name = var.resource_group_name
  location            = var.location
  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

# ADLS Gen2 account (hierarchical namespace) that holds the catalog's data.
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # ADLS Gen2 / abfss - required by Unity Catalog
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

# Grant the access connector's identity read/write on the container's data.
resource "azurerm_role_assignment" "uc" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}
