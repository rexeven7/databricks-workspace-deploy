provider "azurerm" {
  features {}

  # Authentication resolution order:
  #   1. ARM_* environment variables  -> used by CI (GitHub Actions + OIDC)
  #   2. Azure CLI (`az login`)        -> used on a developer laptop
  # subscription_id comes from ARM_SUBSCRIPTION_ID (or the active az CLI account),
  # so nothing tenant-specific is hardcoded in the repo.
}
