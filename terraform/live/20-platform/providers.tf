# The databricks provider is aimed at the workspace created in layer 10.
#
# WHY this is clean: we read layer 10's ALREADY-APPLIED remote state, so
# workspace_id is a KNOWN value at plan time. That is the entire reason we split
# infra (azurerm) from platform (databricks) into two states - it sidesteps the
# classic "a provider configured from a resource created in the same apply"
# chicken-and-egg problem that single-config Azure Databricks setups hit.
provider "databricks" {
  azure_workspace_resource_id = data.terraform_remote_state.infra.outputs.workspace_id

  # Auth: ARM_* env / OIDC in CI, or `az login` locally. The provider exchanges
  # Azure AD tokens for Databricks tokens automatically - no PATs to store.
}
