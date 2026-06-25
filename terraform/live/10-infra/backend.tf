terraform {
  # Partial backend configuration. The account/container values are supplied at
  # init time so the same code serves every environment:
  #
  #   terraform init -backend-config=env/dev.backend.hcl
  #   terraform init -backend-config=env/prod.backend.hcl -reconfigure
  #
  # WHY remote state in Azure Blob: shared team state, off developer laptops, and
  # state locking via blob lease (prevents concurrent applies from corrupting
  # state). This is the "free Terraform" path — no paid Terraform Cloud required.
  backend "azurerm" {}
}
