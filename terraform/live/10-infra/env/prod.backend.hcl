# Backend config for the PROD infra state.
resource_group_name  = "rg-tfstate"
storage_account_name = "sttfstatedbxdemo"
container_name       = "tfstate"
key                  = "databricks/prod/10-infra.tfstate"
