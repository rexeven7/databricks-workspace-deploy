#!/usr/bin/env bash
# Create the Cursor operator service principal (Step 0).
# Run locally while logged in as subscription Owner: az login
# Prints non-secret IDs; secret is shown once — copy to Cursor Runtime Secrets.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/az-cli.sh
source "$SCRIPT_DIR/lib/az-cli.sh"

DISPLAY_NAME="${OPERATOR_DISPLAY_NAME:-cursor-operator-dbx-demo}"
ROLE="${OPERATOR_ROLE:-Owner}"
CREATE_SECRET="${OPERATOR_CREATE_SECRET:-true}"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

if ! az account show &>/dev/null; then
  log "Run 'az login' first." >&2
  exit 1
fi

SUBSCRIPTION_ID="$(az_tsv account show --query id)"
TENANT_ID="$(az_tsv account show --query tenantId)"
SUBSCRIPTION_NAME="$(az_tsv account show --query name)"

az account set --subscription "$SUBSCRIPTION_ID"

log "Subscription: $SUBSCRIPTION_NAME"
log "Subscription id: $SUBSCRIPTION_ID"
log "Tenant id: $TENANT_ID"
log ""

existing="$(az ad app list --display-name "$DISPLAY_NAME" --query "[0].appId" -o tsv 2>/dev/null | trim_tsv || true)"
if [ -n "$existing" ] && [ "$existing" != "null" ]; then
  log "App '$DISPLAY_NAME' already exists — reusing app id $existing"
  APP_ID="$existing"
else
  log "Creating Entra application: $DISPLAY_NAME"
  APP_ID="$(az ad app create \
    --display-name "$DISPLAY_NAME" \
    --sign-in-audience AzureADMyOrg \
    --query appId -o tsv | trim_tsv)"
  log "Created app id: $APP_ID"
fi

az ad sp create --id "$APP_ID" --output none 2>/dev/null || true
log "Waiting for service principal propagation..."
sleep 10

SP_OID="$(az_tsv ad sp show --id "$APP_ID" --query id)"
SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

SECRET=""
if [ "$CREATE_SECRET" = "true" ]; then
  SECRET="$(az ad app credential reset \
    --id "$APP_ID" \
    --append \
    --display-name "cursor-operator" \
    --years 1 \
    --query password -o tsv | trim_tsv)"
else
  log "OPERATOR_CREATE_SECRET=false — skipping new client secret"
fi

log "Assigning $ROLE on subscription..."
if assign_sp_role "$ROLE" "$SCOPE" "$APP_ID" "$SP_OID"; then
  log "Role $ROLE assigned (or already present)."
else
  warn "Could not assign $ROLE automatically."
  warn "Run as subscription Owner:"
  warn "  APP_ID=$APP_ID SUB_ID=$SUBSCRIPTION_ID bash scripts/assign-operator-role.sh"
  warn "Or Portal → Subscription → IAM → Add role assignment → $ROLE → $DISPLAY_NAME"
fi

log ""
log "=== Copy to Cursor → Cloud Agents → Runtime Secrets ==="
log "BOOTSTRAP_AZURE_CLIENT_ID=$APP_ID"
if [ -n "$SECRET" ]; then
  log "BOOTSTRAP_AZURE_CLIENT_SECRET=$SECRET"
else
  log "BOOTSTRAP_AZURE_CLIENT_SECRET=(unchanged — use existing secret in Cursor)"
fi
log "BOOTSTRAP_AZURE_TENANT_ID=$TENANT_ID"
log "BOOTSTRAP_AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
log ""
log "Also add GH_TOKEN (PAT) and env vars GH_TEMPLATE_REPO + STATE_STORAGE_ACCOUNT_NAME."
log "Never commit these values to git."
