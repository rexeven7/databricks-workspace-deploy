#!/usr/bin/env bash
# One-time platform bootstrap: Entra CI app + OIDC + GitHub secrets/vars + Terraform state.
#
# Uses a temporary BOOTSTRAP_* operator service principal (Cursor Runtime Secrets).
# Creates a separate GHA CI app for GitHub Actions — bootstrap creds can be deleted after.
#
# Required env: see scripts/bootstrap-validate-env.sh and docs/PLATFORM-BOOTSTRAP.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/bootstrap-validate-env.sh"

: "${AZURE_LOCATION:=eastus2}"
: "${STATE_RESOURCE_GROUP_NAME:=rg-tfstate}"
: "${STATE_CONTAINER_NAME:=tfstate}"
: "${GHA_APP_DISPLAY_NAME:=gha-databricks-workspace-deploy}"
: "${WORKSPACE_NAME:=dbw-demo-prod}"
: "${RESOURCE_GROUP_NAME:=rg-databricks-prod}"
: "${CATALOG_NAME:=prod}"
: "${SCHEMA_NAME:=sales}"
: "${WAREHOUSE_NAME:=wh-demo-prod}"
: "${ADMIN_GROUP:=account users}"
: "${DATA_ENGINEER_GROUP:=account users}"

export GH_TOKEN
export AZURE_CORE_ONLY_SHOW_ERRORS=true

log() { printf '%s\n' "$*"; }

az_login_bootstrap() {
  log "Signing in with bootstrap service principal..."
  az login --service-principal \
    -u "$BOOTSTRAP_AZURE_CLIENT_ID" \
    -p "$BOOTSTRAP_AZURE_CLIENT_SECRET" \
    --tenant "$BOOTSTRAP_AZURE_TENANT_ID" --output none
  az account set --subscription "$BOOTSTRAP_AZURE_SUBSCRIPTION_ID"
}

ensure_gha_app() {
  if [ -n "${GHA_CLIENT_ID:-}" ]; then
    log "Reusing existing CI app: $GHA_CLIENT_ID"
    APP_ID="$GHA_CLIENT_ID"
  else
    log "Creating Entra application: $GHA_APP_DISPLAY_NAME"
    APP_ID="$(az ad app list --display-name "$GHA_APP_DISPLAY_NAME" --query "[0].appId" -o tsv)"
    if [ -z "$APP_ID" ] || [ "$APP_ID" = "null" ]; then
      APP_ID="$(az ad app create --display-name "$GHA_APP_DISPLAY_NAME" --query appId -o tsv)"
    fi
    az ad sp create --id "$APP_ID" --output none 2>/dev/null || true
  fi
  export APP_ID
  SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
  export SP_OID
  log "CI application id (GitHub AZURE_CLIENT_ID): $APP_ID"
}

assign_role_if_missing() {
  local role="$1" scope="$2"
  if az role assignment list --assignee "$SP_OID" --scope "$scope" --role "$role" --query "[0].id" -o tsv 2>/dev/null | grep -q .; then
    log "Role $role already assigned on scope (skipping)"
  else
    log "Assigning $role on $scope"
    az role assignment create \
      --assignee-object-id "$SP_OID" \
      --assignee-principal-type ServicePrincipal \
      --role "$role" \
      --scope "$scope" \
      --output none
  fi
}

ensure_federated_credential() {
  local name="$1" subject="$2"
  if az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$name" &>/dev/null; then
    log "Federated credential $name already exists (skipping)"
  else
    log "Creating federated credential: $name"
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$subject\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" --output none
  fi
}

ensure_state_storage() {
  if ! az group show -n "$STATE_RESOURCE_GROUP_NAME" &>/dev/null; then
    log "Creating resource group $STATE_RESOURCE_GROUP_NAME"
    az group create -n "$STATE_RESOURCE_GROUP_NAME" -l "$AZURE_LOCATION" --output none
  fi
  if ! az storage account show -n "$STATE_STORAGE_ACCOUNT_NAME" -g "$STATE_RESOURCE_GROUP_NAME" &>/dev/null; then
    log "Creating state storage account $STATE_STORAGE_ACCOUNT_NAME"
    az storage account create \
      -n "$STATE_STORAGE_ACCOUNT_NAME" \
      -g "$STATE_RESOURCE_GROUP_NAME" \
      -l "$AZURE_LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --min-tls-version TLS1_2 \
      --allow-blob-public-access false \
      --output none
  fi
  if ! az storage container show --name "$STATE_CONTAINER_NAME" --account-name "$STATE_STORAGE_ACCOUNT_NAME" --auth-mode login &>/dev/null; then
    log "Creating blob container $STATE_CONTAINER_NAME"
    az storage container create \
      --name "$STATE_CONTAINER_NAME" \
      --account-name "$STATE_STORAGE_ACCOUNT_NAME" \
      --auth-mode login \
      --output none
  fi
  STATE_SA_ID="$(az storage account show -n "$STATE_STORAGE_ACCOUNT_NAME" -g "$STATE_RESOURCE_GROUP_NAME" --query id -o tsv)"
  assign_role_if_missing "Storage Blob Data Contributor" "$STATE_SA_ID"
}

configure_github() {
  log "Configuring GitHub repo: $GH_REPO"
  gh secret set AZURE_CLIENT_ID -b "$APP_ID" -R "$GH_REPO"
  gh secret set AZURE_TENANT_ID -b "$BOOTSTRAP_AZURE_TENANT_ID" -R "$GH_REPO"
  gh secret set AZURE_SUBSCRIPTION_ID -b "$BOOTSTRAP_AZURE_SUBSCRIPTION_ID" -R "$GH_REPO"
  gh api -X PUT "repos/${GH_REPO}/environments/production" --silent

  set_env_var() {
    gh variable set "$1" --env production --body "$2" -R "$GH_REPO"
  }
  set_env_var STATE_RESOURCE_GROUP_NAME "$STATE_RESOURCE_GROUP_NAME"
  set_env_var STATE_STORAGE_ACCOUNT_NAME "$STATE_STORAGE_ACCOUNT_NAME"
  set_env_var AZURE_LOCATION "$AZURE_LOCATION"
  set_env_var WORKSPACE_NAME "$WORKSPACE_NAME"
  set_env_var UC_STORAGE_ACCOUNT_NAME "$UC_STORAGE_ACCOUNT_NAME"
  set_env_var RESOURCE_GROUP_NAME "$RESOURCE_GROUP_NAME"
  set_env_var CATALOG_NAME "$CATALOG_NAME"
  set_env_var SCHEMA_NAME "$SCHEMA_NAME"
  set_env_var WAREHOUSE_NAME "$WAREHOUSE_NAME"
  set_env_var ADMIN_GROUP "$ADMIN_GROUP"
  set_env_var DATA_ENGINEER_GROUP "$DATA_ENGINEER_GROUP"
}

main() {
  log "=== Platform bootstrap (demo) ==="
  az_login_bootstrap
  ensure_gha_app
  assign_role_if_missing "Owner" "/subscriptions/${BOOTSTRAP_AZURE_SUBSCRIPTION_ID}"
  ensure_federated_credential "gh-env-production" "repo:${GH_REPO}:environment:production"
  ensure_federated_credential "gh-pull-request" "repo:${GH_REPO}:pull_request"
  ensure_state_storage
  configure_github
  log ""
  log "=== Bootstrap complete ==="
  log "CI app id (AZURE_CLIENT_ID): $APP_ID"
  log "State: ${STATE_RESOURCE_GROUP_NAME} / ${STATE_STORAGE_ACCOUNT_NAME} / ${STATE_CONTAINER_NAME}"
  log "GitHub: secrets + production environment variables configured on $GH_REPO"
  log ""
  log "NEXT: Remove BOOTSTRAP_* and GH_TOKEN from Cursor Secrets."
  log "CI deploys via OIDC only. Run deploy workflow or merge to main to create workspace."
}

main "$@"
