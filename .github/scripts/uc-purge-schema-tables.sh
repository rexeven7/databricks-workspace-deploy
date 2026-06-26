#!/usr/bin/env bash
# Drop application tables in a UC schema so Terraform can destroy the schema (demo teardown).
# Bundle jobs create tables Terraform does not manage — purge before layer-20 destroy.
#
# Requires: DATABRICKS_HOST, WAREHOUSE_ID, UC_CATALOG, UC_SCHEMA
set -euo pipefail

: "${DATABRICKS_HOST:?DATABRICKS_HOST is required}"
: "${WAREHOUSE_ID:?WAREHOUSE_ID is required}"
: "${UC_CATALOG:?UC_CATALOG is required}"
: "${UC_SCHEMA:?UC_SCHEMA is required}"

export DATABRICKS_AUTH_TYPE=azure-cli

execute_sql() {
  local statement="$1"
  local response
  response="$(databricks api post /api/2.0/sql/statements \
    --json "$(jq -n \
      --arg wh "$WAREHOUSE_ID" \
      --arg stmt "$statement" \
      '{warehouse_id: $wh, statement: $stmt, wait_timeout: "50s"}')")"
  local state
  state="$(echo "$response" | jq -r '.status.state // empty')"
  if [ "$state" != "SUCCEEDED" ]; then
    echo "SQL failed ($state): $statement" >&2
    echo "$response" >&2
    return 1
  fi
  echo "$response"
}

echo "Purging application tables in ${UC_CATALOG}.${UC_SCHEMA}..."

# Known smoke-test artifact from bundle/src/ingest_sample.py
execute_sql "DROP TABLE IF EXISTS ${UC_CATALOG}.${UC_SCHEMA}.trips_curated" || true

show_result="$(execute_sql "SHOW TABLES IN ${UC_CATALOG}.${UC_SCHEMA}" || true)"
if [ -n "$show_result" ]; then
  mapfile -t tables < <(echo "$show_result" | jq -r '.result.data_array[]? | .[1] // .[0] // empty' | sed '/^$/d' | sort -u)
  for table in "${tables[@]}"; do
    echo "Dropping ${UC_CATALOG}.${UC_SCHEMA}.${table}..."
    execute_sql "DROP TABLE IF EXISTS ${UC_CATALOG}.${UC_SCHEMA}.${table}" || true
  done
fi

echo "UC schema purge complete."
