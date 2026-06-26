#!/usr/bin/env bash
# Shared deploy name resolution (CI + spawn scripts).

# Globally unique UC ADLS account for a sandbox slug (3–24 lowercase alphanumeric).
# Override with VAR_UC_STORAGE_ACCOUNT_NAME or UC_STORAGE_ACCOUNT_NAME in env.
resolve_uc_storage_account_name() {
  local slug="$1"
  local override="${VAR_UC_STORAGE_ACCOUNT_NAME:-${UC_STORAGE_ACCOUNT_NAME:-}}"
  if [ -n "$override" ]; then
    echo "$override" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]' | cut -c1-24
    return
  fi
  local slug_clean hash6 slug_part
  slug_clean="$(echo "$slug" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  hash6="$(printf '%s' "$slug_clean" | sha256sum | cut -c1-6 | tr -d '\r\n')"
  slug_part="$(echo "$slug_clean" | cut -c1-13)"
  echo "stdbx${slug_part}${hash6}" | cut -c1-24
}

# Print resolved names for a slug deploy (debug / manual GHA prep).
print_deploy_names() {
  local slug="${1:-${DEPLOYMENT_SLUG:-}}"
  slug="$(echo "$slug" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  if [ -z "$slug" ]; then
    echo "Usage: DEPLOYMENT_SLUG=<slug> bash scripts/print-deploy-names.sh" >&2
    return 1
  fi
  local state_sa="${VAR_STATE_STORAGE_ACCOUNT_NAME:-${STATE_STORAGE_ACCOUNT_NAME:-sttfstatedbxdemo}}"
  local uc_sa
  uc_sa="$(resolve_uc_storage_account_name "$slug")"
  cat <<EOF
deployment_slug:     $slug
state storage (shared): $state_sa   ← must exist in Azure; set GitHub var STATE_STORAGE_ACCOUNT_NAME
uc storage (new):    $uc_sa   ← created by Terraform layer 10
workspace:           dbw-$slug
resource group:      rg-dbx-$slug
catalog:             $slug
state key:           databricks/$slug/10-infra.tfstate
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  print_deploy_names "$@"
fi
