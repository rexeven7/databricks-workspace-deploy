# The databricks provider is aimed at the workspace created in layer 10.
#
# WHY this is clean: we read layer 10's ALREADY-APPLIED remote state, so
# workspace_id is a KNOWN value at plan time. That is the entire reason we split
# infra (azurerm) from platform (databricks) into two states - it sidesteps the
# classic "a provider configured from a resource created in the same apply"
# chicken-and-egg problem that single-config Azure Databricks setups hit.
provider "databricks" {
  host                        = data.terraform_remote_state.infra.outputs.workspace_url
  azure_workspace_resource_id = data.terraform_remote_state.infra.outputs.workspace_id

  # Local: `az login` → azure-cli auth (default).
  # CI: set DATABRICKS_AUTH_TYPE=azure-cli after azure/login (see terraform.yml).
  # github-oidc-azure works for most resources but not storage credentials, which
  # require an ARM-scoped management token that azure-cli auth supplies.
}
