#!/usr/bin/env bash
# Resolve Terraform / bundle inputs for CI.
#
# Modes:
#   sandbox  — workflow_dispatch with deployment_slug (ephemeral interview deploy)
#   production — merge to main or dispatch without slug (GitHub Environment vars)
#
# Writes shell assignments to stdout; caller should: eval "$(.github/scripts/resolve-deployment.sh)"

set -euo pipefail

mode="production"
slug=""

if [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ] && [ -n "${INPUT_DEPLOYMENT_SLUG:-}" ]; then
  mode="sandbox"
  slug="$(echo "${INPUT_DEPLOYMENT_SLUG}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  if [ -z "$slug" ]; then
    echo "deployment_slug must contain at least one alphanumeric character" >&2
    exit 1
  fi
fi

state_rg="${VAR_STATE_RESOURCE_GROUP_NAME:-rg-tfstate}"
state_sa="${VAR_STATE_STORAGE_ACCOUNT_NAME:-sttfstatedbxdemo}"
location="${VAR_AZURE_LOCATION:-eastus2}"

emit() { printf '%s\n' "$1"; }

emit "DEPLOYMENT_MODE=$mode"

if [ "$mode" = "sandbox" ]; then
  sa_suffix="$(echo "$slug" | cut -c1-18)"
  emit "TF_VAR_environment=$slug"
  emit "TF_VAR_location=$location"
  emit "TF_VAR_resource_group_name=rg-dbx-${slug}"
  emit "TF_VAR_workspace_name=dbw-${slug}"
  emit "TF_VAR_uc_storage_account_name=stdbx${sa_suffix}"
  emit "TF_VAR_catalog_name=$slug"
  emit "TF_VAR_schema_name=sales"
  emit "TF_VAR_warehouse_name=wh-${slug}"
  emit "TF_VAR_admin_group=${VAR_ADMIN_GROUP:-account users}"
  emit "TF_VAR_data_engineer_group=${VAR_DATA_ENGINEER_GROUP:-account users}"
  emit "TF_VAR_state_resource_group_name=$state_rg"
  emit "TF_VAR_state_storage_account_name=$state_sa"
  emit "TF_VAR_state_container_name=tfstate"
  emit "TF_VAR_infra_state_key=databricks/${slug}/10-infra.tfstate"
  emit "BACKEND_KEY_INFRA=databricks/${slug}/10-infra.tfstate"
  emit "BACKEND_KEY_PLATFORM=databricks/${slug}/20-platform.tfstate"
  emit "BUNDLE_CATALOG=$slug"
  emit "BUNDLE_SCHEMA=sales"
else
  # Production: optional GitHub Environment vars override committed tfvars (TF_VAR wins).
  [ -n "${VAR_WORKSPACE_NAME:-}" ] && emit "TF_VAR_workspace_name=${VAR_WORKSPACE_NAME}"
  [ -n "${VAR_UC_STORAGE_ACCOUNT_NAME:-}" ] && emit "TF_VAR_uc_storage_account_name=${VAR_UC_STORAGE_ACCOUNT_NAME}"
  [ -n "${VAR_RESOURCE_GROUP_NAME:-}" ] && emit "TF_VAR_resource_group_name=${VAR_RESOURCE_GROUP_NAME}"
  [ -n "${VAR_CATALOG_NAME:-}" ] && emit "TF_VAR_catalog_name=${VAR_CATALOG_NAME}"
  [ -n "${VAR_WAREHOUSE_NAME:-}" ] && emit "TF_VAR_warehouse_name=${VAR_WAREHOUSE_NAME}"
  emit "TF_VAR_state_resource_group_name=$state_rg"
  emit "TF_VAR_state_storage_account_name=$state_sa"
  emit "TF_VAR_state_container_name=tfstate"
  emit "TF_VAR_infra_state_key=databricks/prod/10-infra.tfstate"
  emit "BACKEND_KEY_INFRA=databricks/prod/10-infra.tfstate"
  emit "BACKEND_KEY_PLATFORM=databricks/prod/20-platform.tfstate"
  emit "BUNDLE_CATALOG=${VAR_CATALOG_NAME:-prod}"
  emit "BUNDLE_SCHEMA=sales"
fi

emit "BACKEND_RESOURCE_GROUP=$state_rg"
emit "BACKEND_STORAGE_ACCOUNT=$state_sa"
emit "BACKEND_CONTAINER=tfstate"
