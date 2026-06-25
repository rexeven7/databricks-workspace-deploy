terraform {
  # 1.6 introduced the native `terraform test` framework used in tests/.
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116" # pinned for reproducible plans across the team
    }
  }
}
