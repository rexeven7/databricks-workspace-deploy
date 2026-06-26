#!/usr/bin/env bash
# Deploy the asset bundle in CI using the `ci` target (azure-cli auth).
# Requires: DATABRICKS_HOST, WAREHOUSE_ID, BUNDLE_CATALOG, BUNDLE_SCHEMA
set -euo pipefail

: "${DATABRICKS_HOST:?DATABRICKS_HOST is required}"
: "${WAREHOUSE_ID:?WAREHOUSE_ID is required}"
: "${BUNDLE_CATALOG:?BUNDLE_CATALOG is required}"
: "${BUNDLE_SCHEMA:?BUNDLE_SCHEMA is required}"

export DATABRICKS_AUTH_TYPE=azure-cli

databricks bundle validate -t ci \
  --var="catalog=${BUNDLE_CATALOG}" \
  --var="schema=${BUNDLE_SCHEMA}" \
  --var="warehouse_id=${WAREHOUSE_ID}"

if [[ "${BUNDLE_DEPLOY_VALIDATE_ONLY:-}" == "true" ]]; then
  exit 0
fi

databricks bundle deploy -t ci \
  --var="catalog=${BUNDLE_CATALOG}" \
  --var="schema=${BUNDLE_SCHEMA}" \
  --var="warehouse_id=${WAREHOUSE_ID}"
