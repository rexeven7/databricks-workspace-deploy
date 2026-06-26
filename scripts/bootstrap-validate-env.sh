#!/usr/bin/env bash
# Verify bootstrap env vars are set (does not print secret values).
set -euo pipefail

missing=()

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  else
    echo "ok: $name"
  fi
}

echo "Checking bootstrap environment (secrets are not printed)..."

require BOOTSTRAP_AZURE_CLIENT_ID
require BOOTSTRAP_AZURE_CLIENT_SECRET
require BOOTSTRAP_AZURE_TENANT_ID
require BOOTSTRAP_AZURE_SUBSCRIPTION_ID
require GH_TOKEN
require GH_REPO
require STATE_STORAGE_ACCOUNT_NAME
require UC_STORAGE_ACCOUNT_NAME

# Optional with defaults — report if unset
for opt in AZURE_LOCATION STATE_RESOURCE_GROUP_NAME GHA_APP_DISPLAY_NAME; do
  if [ -z "${!opt:-}" ]; then
    echo "optional (default): $opt"
  else
    echo "ok: $opt"
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required variables: ${missing[*]}" >&2
  echo "See docs/PLATFORM-BOOTSTRAP.md" >&2
  exit 1
fi

echo "bootstrap-validate-env: all required variables present"
