#!/usr/bin/env bash
# Resolve Terraform / bundle inputs for CI.
#
# Modes:
#   sandbox  — workflow_dispatch with deployment_slug (ephemeral deploy)
#   production — merge to main or dispatch without slug (GitHub Environment vars)
#
# Writes KEY=VALUE lines to stdout. In CI, pipe through load-deployment-env.sh
# (not raw >> GITHUB_ENV) so values with spaces (e.g. account users) are preserved.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../../scripts/lib/deploy-names.sh
source "$script_dir/../../scripts/lib/deploy-names.sh"

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
schema_name="${VAR_SCHEMA_NAME:-sales}"

if [ -n "${GITHUB_ACTIONS:-}" ] && [ -z "${VAR_STATE_STORAGE_ACCOUNT_NAME:-}" ]; then
  echo "ERROR: GitHub Environment 'production' is missing variable STATE_STORAGE_ACCOUNT_NAME." >&2
  echo "Set it to your existing state storage account (e.g. sttfdbxrexeven701 in rg-tfstate)." >&2
  echo "Slug deploy uses that account with a per-slug state key (e.g. databricks/hike2/10-infra.tfstate)." >&2
  exit 1
fi

emit() { printf '%s\n' "$1"; }

emit "DEPLOYMENT_MODE=$mode"

if [ "$mode" = "sandbox" ]; then
  uc_sa="$(resolve_uc_storage_account_name "$slug")"
  emit "TF_VAR_environment=$slug"
  emit "TF_VAR_location=$location"
  emit "TF_VAR_resource_group_name=rg-dbx-${slug}"
  emit "TF_VAR_workspace_name=dbw-${slug}"
  emit "TF_VAR_uc_storage_account_name=${uc_sa}"
  emit "TF_VAR_catalog_name=$slug"
  emit "TF_VAR_schema_name=$schema_name"
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
  emit "BUNDLE_SCHEMA=$schema_name"
else
  # Production: optional GitHub Environment vars override committed tfvars.
  [ -n "${VAR_WORKSPACE_NAME:-}" ] && emit "TF_VAR_workspace_name=${VAR_WORKSPACE_NAME}"
  [ -n "${VAR_UC_STORAGE_ACCOUNT_NAME:-}" ] && emit "TF_VAR_uc_storage_account_name=${VAR_UC_STORAGE_ACCOUNT_NAME}"
  [ -n "${VAR_RESOURCE_GROUP_NAME:-}" ] && emit "TF_VAR_resource_group_name=${VAR_RESOURCE_GROUP_NAME}"
  [ -n "${VAR_CATALOG_NAME:-}" ] && emit "TF_VAR_catalog_name=${VAR_CATALOG_NAME}"
  [ -n "${VAR_SCHEMA_NAME:-}" ] && emit "TF_VAR_schema_name=${VAR_SCHEMA_NAME}"
  [ -n "${VAR_WAREHOUSE_NAME:-}" ] && emit "TF_VAR_warehouse_name=${VAR_WAREHOUSE_NAME}"
  [ -n "${VAR_ADMIN_GROUP:-}" ] && emit "TF_VAR_admin_group=${VAR_ADMIN_GROUP}"
  [ -n "${VAR_DATA_ENGINEER_GROUP:-}" ] && emit "TF_VAR_data_engineer_group=${VAR_DATA_ENGINEER_GROUP}"
  emit "TF_VAR_state_resource_group_name=$state_rg"
  emit "TF_VAR_state_storage_account_name=$state_sa"
  emit "TF_VAR_state_container_name=tfstate"
  emit "TF_VAR_infra_state_key=databricks/prod/10-infra.tfstate"
  emit "BACKEND_KEY_INFRA=databricks/prod/10-infra.tfstate"
  emit "BACKEND_KEY_PLATFORM=databricks/prod/20-platform.tfstate"
  emit "BUNDLE_CATALOG=${VAR_CATALOG_NAME:-prod}"
  emit "BUNDLE_SCHEMA=$schema_name"
fi

emit "BACKEND_RESOURCE_GROUP=$state_rg"
emit "BACKEND_STORAGE_ACCOUNT=$state_sa"
emit "BACKEND_CONTAINER=tfstate"
