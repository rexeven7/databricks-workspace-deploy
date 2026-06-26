#!/usr/bin/env bash
# Assign Azure RBAC roles to the GitHub Actions (CI) service principal.
# Requires az login as a principal with User Access Administrator or Owner.
#
# Usage:
#   APP_ID=<ci-app-id> SUB_ID=<subscription-id> STATE_SA=<state-sa> bash scripts/assign-ci-roles.sh
#
# If this fails with MissingSubscription, assign roles in the Azure Portal
# (see docs/DEMO-SETUP.md § "Manual RBAC fallback").

set -euo pipefail

: "${APP_ID:?APP_ID is required (CI service principal application id)}"
: "${SUB_ID:?SUB_ID is required (Azure subscription id)}"
: "${STATE_SA:?STATE_SA is required (state storage account name)}"
: "${STATE_RG:=rg-tfstate}"

SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
STATE_SA_ID="$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)"

echo "Service principal object id: $SP_OID"
echo "Assigning Owner on subscription $SUB_ID ..."
az role assignment create \
  --assignee-object-id "$SP_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "Owner" \
  --scope "/subscriptions/$SUB_ID" \
  2>/dev/null || echo "(Owner assignment may already exist)"

echo "Assigning Storage Blob Data Contributor on $STATE_SA ..."
az role assignment create \
  --assignee-object-id "$SP_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_SA_ID" \
  2>/dev/null || echo "(Storage assignment may already exist)"

echo "Done."
