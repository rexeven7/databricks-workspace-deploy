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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/az-cli.sh
source "$SCRIPT_DIR/lib/az-cli.sh"

: "${APP_ID:?APP_ID is required (CI service principal application id)}"
: "${SUB_ID:?SUB_ID is required (Azure subscription id)}"
: "${STATE_SA:?STATE_SA is required (state storage account name)}"
: "${STATE_RG:=rg-tfstate}"

APP_ID="$(echo "$APP_ID" | trim_tsv)"
SUB_ID="$(echo "$SUB_ID" | trim_tsv)"
STATE_SA="$(echo "$STATE_SA" | trim_tsv)"

az account set --subscription "$SUB_ID"

SP_OID="$(az_tsv ad sp show --id "$APP_ID" --query id)"
STATE_SA_ID="$(az_tsv storage account show -n "$STATE_SA" -g "$STATE_RG" --query id)"

echo "Service principal object id: $SP_OID"
echo "Assigning Owner on subscription $SUB_ID ..."
assign_sp_role "Owner" "/subscriptions/$SUB_ID" "$APP_ID" "$SP_OID" \
  || echo "(Owner assignment failed — assign in Portal if needed)"

echo "Assigning Storage Blob Data Contributor on $STATE_SA ..."
assign_sp_role "Storage Blob Data Contributor" "$STATE_SA_ID" "$APP_ID" "$SP_OID" \
  || echo "(Storage assignment failed — assign in Portal if needed)"

echo "Done."
