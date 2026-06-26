# Backend config for the DEV infra state.
# NOTE: storage_account_name must be globally unique - change before first init.
resource_group_name  = "rg-tfstate"
storage_account_name = "sttfstatedbxdemo"
container_name       = "tfstate"
key                  = "databricks/dev/10-infra.tfstate"
use_azuread_auth     = true
use_oidc             = true
