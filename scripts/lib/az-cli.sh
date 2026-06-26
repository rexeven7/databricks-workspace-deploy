#!/usr/bin/env bash
# Shared helpers for local Azure CLI scripts (Git Bash on Windows safe).
#
# `az ... -o tsv` often includes a trailing CR on MINGW64, which breaks ARM scopes
# and causes MissingSubscription on role assignment.

trim_tsv() {
  tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Usage: SUB_ID="$(az_tsv account show --query id)"
az_tsv() {
  az "$@" -o tsv 2>/dev/null | trim_tsv
}

assign_sp_role() {
  local role="$1" scope="$2" app_id="$3" sp_oid="$4"
  if az role assignment list \
    --assignee "$sp_oid" \
    --scope "$scope" \
    --role "$role" \
    --subscription "$(echo "$scope" | sed -n 's|.*/subscriptions/\([^/]*\).*|\1|p')" \
    --query "[0].id" -o tsv 2>/dev/null | trim_tsv | grep -q .; then
    return 0
  fi
  # Prefer app id + principal type (most reliable across CLI versions).
  if az role assignment create \
    --assignee "$app_id" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope" \
    --only-show-errors 2>/dev/null; then
    return 0
  fi
  az role assignment create \
    --assignee-object-id "$sp_oid" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope"
}
