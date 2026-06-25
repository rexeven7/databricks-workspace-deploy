terraform {
  # Partial backend - same pattern as layer 10, but a DIFFERENT state key so the
  # two layers never share state:
  #   terraform init -backend-config=env/dev.backend.hcl
  backend "azurerm" {}
}
