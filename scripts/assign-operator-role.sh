#!/usr/bin/env bash
# Assign Owner on a subscription to the Cursor operator SP.
# Run as subscription Owner or User Access Administrator.
#
# Usage:
#   APP_ID=<operator-app-id> SUB_ID=<subscription-id> bash scripts/assign-operator-role.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/az-cli.sh
source "$SCRIPT_DIR/lib/az-cli.sh"

: "${APP_ID:?APP_ID is required (operator application / client id)}"
: "${SUB_ID:?SUB_ID is required (Azure subscription id)}"
: "${ROLE:=Owner}"

APP_ID="$(echo "$APP_ID" | trim_tsv)"
SUB_ID="$(echo "$SUB_ID" | trim_tsv)"

az account set --subscription "$SUB_ID"

SP_OID="$(az_tsv ad sp show --id "$APP_ID" --query id)"
DISPLAY_NAME="$(az_tsv ad sp show --id "$APP_ID" --query displayName)"
SCOPE="/subscriptions/${SUB_ID}"

echo "Operator SP: $DISPLAY_NAME"
echo "App id: $APP_ID"
echo "Object id: $SP_OID"
echo "Assigning $ROLE on $SCOPE ..."

assign_sp_role "$ROLE" "$SCOPE" "$APP_ID" "$SP_OID"
echo "Done."
