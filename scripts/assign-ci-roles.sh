#!/usr/bin/env bash
# Assign Azure RBAC roles to the GitHub Actions service principal.
# Requires a signed-in principal with User Access Administrator (or Owner) on the subscription.
#
# Usage (after az login):
#   ./scripts/assign-ci-roles.sh
#
# If this fails with MissingSubscription, assign roles in the Azure Portal instead
# (see docs/DEMO-SETUP.md § "Manual RBAC fallback").

set -euo pipefail

APP_ID="${APP_ID:-327026fe-c20e-4688-a8ca-070602722b73}"
SUB_ID="${SUB_ID:-655e8413-507f-4d8e-afea-68f3d873fd48}"
STATE_RG="${STATE_RG:-rg-tfstate}"
STATE_SA="${STATE_SA:-sttfdbxrexeven701}"

SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
STATE_SA_ID="$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)"

echo "Service principal object id: $SP_OID"
echo "Assigning Owner on subscription $SUB_ID ..."
az role assignment create \
  --assignee-object-id "$SP_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "Owner" \
  --scope "/subscriptions/$SUB_ID"

echo "Assigning Storage Blob Data Contributor on $STATE_SA ..."
az role assignment create \
  --assignee-object-id "$SP_OID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_SA_ID"

echo "Done."
