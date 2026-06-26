#!/usr/bin/env bash
# Validate env for spawn-client-repo.sh (does not print secrets).
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

echo "Checking client-repo spawn environment..."

require CLIENT_SLUG
require GH_TEMPLATE_REPO
require BOOTSTRAP_AZURE_CLIENT_ID
require BOOTSTRAP_AZURE_CLIENT_SECRET
require BOOTSTRAP_AZURE_TENANT_ID
require BOOTSTRAP_AZURE_SUBSCRIPTION_ID
require GH_TOKEN
require STATE_STORAGE_ACCOUNT_NAME

slug="$(echo "$CLIENT_SLUG" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
if [ -z "$slug" ]; then
  echo "CLIENT_SLUG must contain at least one alphanumeric character" >&2
  exit 1
fi
export CLIENT_SLUG="$slug"

if [ -z "${GH_ORG:-}" ]; then
  GH_ORG="${GH_TEMPLATE_REPO%%/*}"
  export GH_ORG
  echo "derived: GH_ORG=$GH_ORG"
else
  echo "ok: GH_ORG"
fi

if [ -n "${PROPOSAL_FILE:-}" ] && [ ! -f "$PROPOSAL_FILE" ]; then
  echo "PROPOSAL_FILE not found: $PROPOSAL_FILE" >&2
  exit 1
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required variables: ${missing[*]}" >&2
  echo "See docs/CLIENT-REPO-BOOTSTRAP.md" >&2
  exit 1
fi

echo "spawn-client-validate-env: ok (client slug: $CLIENT_SLUG)"
