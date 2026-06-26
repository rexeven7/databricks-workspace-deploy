# Backend config for the PROD infra state.
# CI overrides key + storage via -backend-config; use_azuread_auth enables OIDC identity.
resource_group_name  = "rg-tfstate"
storage_account_name = "sttfdbxrexeven701"
container_name       = "tfstate"
key                  = "databricks/prod/10-infra.tfstate"
use_azuread_auth     = true
use_oidc             = true
