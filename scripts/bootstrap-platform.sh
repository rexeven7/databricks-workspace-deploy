#!/usr/bin/env bash
# Platform bootstrap: Entra CI app + OIDC + GitHub secrets + shared Terraform state.
#
# Uses a persistent BOOTSTRAP_* operator service principal (Cursor Runtime Secrets).
# Creates a separate GHA CI app — operator configures; CI applies via OIDC.
#
# Per-demo stacks use deployment_slug + resolve-deployment.sh — not values committed here.
# Required env: see scripts/bootstrap-validate-env.sh and docs/PLATFORM-BOOTSTRAP.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/bootstrap-validate-env.sh"

: "${AZURE_LOCATION:=eastus2}"
: "${STATE_RESOURCE_GROUP_NAME:=rg-tfstate}"
: "${STATE_CONTAINER_NAME:=tfstate}"
: "${GHA_APP_DISPLAY_NAME:=gha-databricks-workspace-deploy}"

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

ensure_federated_credentials_for_repo() {
  local fcred_slug
  fcred_slug="$(echo "$GH_REPO" | tr '[:upper:]' '[:lower:]' | tr '/.' '-')"
  ensure_federated_credential "${fcred_slug}-env-production" "repo:${GH_REPO}:environment:production"
  ensure_federated_credential "${fcred_slug}-pull-request" "repo:${GH_REPO}:pull_request"
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
  # Shared across all slug deploys on this subscription
  set_env_var STATE_RESOURCE_GROUP_NAME "$STATE_RESOURCE_GROUP_NAME"
  set_env_var STATE_STORAGE_ACCOUNT_NAME "$STATE_STORAGE_ACCOUNT_NAME"
  set_env_var AZURE_LOCATION "$AZURE_LOCATION"

  # Production-mode overrides — only when explicitly set (not hard-wired demo defaults)
  for pair in \
    WORKSPACE_NAME:WORKSPACE_NAME \
    UC_STORAGE_ACCOUNT_NAME:UC_STORAGE_ACCOUNT_NAME \
    RESOURCE_GROUP_NAME:RESOURCE_GROUP_NAME \
    CATALOG_NAME:CATALOG_NAME \
    SCHEMA_NAME:SCHEMA_NAME \
    WAREHOUSE_NAME:WAREHOUSE_NAME \
    ADMIN_GROUP:ADMIN_GROUP \
    DATA_ENGINEER_GROUP:DATA_ENGINEER_GROUP; do
    var="${pair%%:*}"
    gh_name="${pair#*:}"
    if [ -n "${!var:-}" ]; then
      set_env_var "$gh_name" "${!var}"
      log "Set production env var: $gh_name"
    fi
  done
}

main() {
  log "=== Platform bootstrap (demo) ==="
  az_login_bootstrap
  ensure_gha_app
  assign_role_if_missing "Owner" "/subscriptions/${BOOTSTRAP_AZURE_SUBSCRIPTION_ID}"
  ensure_federated_credentials_for_repo
  ensure_state_storage
  configure_github
  log ""
  log "=== Bootstrap complete ==="
  log "CI app id (AZURE_CLIENT_ID): $APP_ID"
  log "State: ${STATE_RESOURCE_GROUP_NAME} / ${STATE_STORAGE_ACCOUNT_NAME} / ${STATE_CONTAINER_NAME}"
  log "GitHub: secrets + production environment variables configured on $GH_REPO"
  log ""
  log "NEXT: Deploy a demo with a slug (names are runtime-only, not committed):"
  log "  DEPLOYMENT_SLUG=<slug> bash scripts/trigger-demo-deploy.sh"
  log "Operator BOOTSTRAP_* creds stay in Cursor for future demos."
}

main "$@"
