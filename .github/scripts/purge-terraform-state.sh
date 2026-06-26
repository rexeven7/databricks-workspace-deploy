#!/usr/bin/env bash
# Remove Terraform state blobs after a successful destroy (demo reset / sandbox cleanup).
# Requires: BACKEND_STORAGE_ACCOUNT, BACKEND_CONTAINER, BACKEND_KEY_INFRA, BACKEND_KEY_PLATFORM
set -euo pipefail

: "${BACKEND_STORAGE_ACCOUNT:?BACKEND_STORAGE_ACCOUNT is required}"
: "${BACKEND_CONTAINER:?BACKEND_CONTAINER is required}"
: "${BACKEND_KEY_INFRA:?BACKEND_KEY_INFRA is required}"
: "${BACKEND_KEY_PLATFORM:?BACKEND_KEY_PLATFORM is required}"

for key in "$BACKEND_KEY_PLATFORM" "$BACKEND_KEY_INFRA"; do
  echo "Deleting state blob: $key"
  if az storage blob show \
    --account-name "$BACKEND_STORAGE_ACCOUNT" \
    --container-name "$BACKEND_CONTAINER" \
    --name "$key" \
    --auth-mode login \
    --output none 2>/dev/null; then
    az storage blob delete \
      --account-name "$BACKEND_STORAGE_ACCOUNT" \
      --container-name "$BACKEND_CONTAINER" \
      --name "$key" \
      --auth-mode login \
      --output none
    echo "Deleted $key"
  else
    echo "Blob not found (already gone): $key"
  fi
done
