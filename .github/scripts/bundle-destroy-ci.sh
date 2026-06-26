#!/usr/bin/env bash
# Destroy the asset bundle in CI (best-effort before Terraform teardown).
set -euo pipefail

: "${DATABRICKS_HOST:?DATABRICKS_HOST is required}"
: "${WAREHOUSE_ID:?WAREHOUSE_ID is required}"
: "${BUNDLE_CATALOG:?BUNDLE_CATALOG is required}"
: "${BUNDLE_SCHEMA:?BUNDLE_SCHEMA is required}"

export DATABRICKS_AUTH_TYPE=azure-cli

databricks bundle destroy -t ci --auto-approve \
  --var="catalog=${BUNDLE_CATALOG}" \
  --var="schema=${BUNDLE_SCHEMA}" \
  --var="warehouse_id=${WAREHOUSE_ID}"
