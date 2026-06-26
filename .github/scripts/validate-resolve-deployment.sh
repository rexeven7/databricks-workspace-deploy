#!/usr/bin/env bash
# Offline check: resolve-deployment + GITHUB_ENV writer preserve spaced values.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT

# Minimal parser for GITHUB_ENV files (KEY=VALUE and KEY<<DELIM blocks).
load_github_env_file() {
  local file="$1"
  local key delim value line
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"="* && "$line" != *"<<"* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      export "${key}=${value}"
    elif [[ "$line" == *"<<"* ]]; then
      key="${line%%<<*}"
      delim="${line#*<<}"
      value=""
      while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" == "$delim" ]] && break
        if [ -z "$value" ]; then
          value="$line"
        else
          value+=$'\n'"$line"
        fi
      done
      export "$key=$value"
    fi
  done < "$file"
}

export GITHUB_ENV="$tmp_env"
export VAR_STATE_RESOURCE_GROUP_NAME="rg-tfstate"
export VAR_STATE_STORAGE_ACCOUNT_NAME="sttfstatedbxdemo"
export VAR_ADMIN_GROUP="account users"
export VAR_DATA_ENGINEER_GROUP="account users"

export GITHUB_EVENT_NAME="workflow_dispatch"
export INPUT_DEPLOYMENT_SLUG="meridian"
export VAR_STATE_STORAGE_ACCOUNT_NAME="sttfdbxrexeven701"

out="$(bash "$repo_root/.github/scripts/resolve-deployment.sh")"
echo "$out" | grep TF_VAR_uc_storage_account_name
[[ "$(echo "$out" | grep '^TF_VAR_uc_storage_account_name=' | cut -d= -f2)" =~ ^stdbx[a-z0-9]+$ ]] || {
  echo "invalid uc storage account name" >&2
  exit 1
}

tfvars="$(mktemp)"
resolve_tmp="$(mktemp)"
trap 'rm -f "$tmp_env" "$tfvars" "$resolve_tmp"' EXIT
printf '%s\n' "$out" > "$resolve_tmp"
bash "$repo_root/.github/scripts/write-deployment-tfvars.sh" "$resolve_tmp" "$tfvars"
grep -q 'state_storage_account_name = "sttfdbxrexeven701"' "$tfvars" || {
  echo "deployment.auto.tfvars missing state_storage_account_name override" >&2
  exit 1
}
grep -q 'infra_state_key = "databricks/meridian/10-infra.tfstate"' "$tfvars" || {
  echo "deployment.auto.tfvars missing infra_state_key override" >&2
  exit 1
}

export GITHUB_EVENT_NAME="push"
export INPUT_DEPLOYMENT_SLUG=""
export VAR_STATE_STORAGE_ACCOUNT_NAME="sttfstatedbxdemo"

bash "$repo_root/.github/scripts/resolve-deployment.sh" | bash "$repo_root/.github/scripts/write-github-env.sh"
load_github_env_file "$tmp_env"

[[ "${TF_VAR_admin_group:-}" == "account users" ]] || {
  echo "expected TF_VAR_admin_group='account users', got '${TF_VAR_admin_group:-}'" >&2
  exit 1
}
[[ "${TF_VAR_data_engineer_group:-}" == "account users" ]] || {
  echo "expected TF_VAR_data_engineer_group='account users', got '${TF_VAR_data_engineer_group:-}'" >&2
  exit 1
}

echo "resolve-deployment validation passed"
