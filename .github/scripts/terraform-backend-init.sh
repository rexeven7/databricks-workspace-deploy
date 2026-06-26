#!/usr/bin/env bash
# Init Terraform with AAD-authenticated azurerm backend (OIDC identity).
set -euo pipefail

terraform init -reconfigure \
  -backend-config="resource_group_name=${BACKEND_RESOURCE_GROUP}" \
  -backend-config="storage_account_name=${BACKEND_STORAGE_ACCOUNT}" \
  -backend-config="container_name=${BACKEND_CONTAINER}" \
  -backend-config="key=${1}" \
  -backend-config="use_azuread_auth=true"
