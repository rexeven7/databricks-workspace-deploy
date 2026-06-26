#!/usr/bin/env bash
# Drop application tables/views/volumes in a UC schema (and catalog-wide leftovers)
# so Terraform can destroy the schema and external location.
#
# Uses SQL statement API catalog/schema context — not `SHOW … IN catalog.schema`
# (Databricks rejects cross-catalog schema references for SHOW VIEWS).
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
  local schema="${2:-$UC_SCHEMA}"
  local response
  response="$(databricks api post /api/2.0/sql/statements \
    --json "$(jq -n \
      --arg wh "$WAREHOUSE_ID" \
      --arg stmt "$statement" \
      --arg catalog "$UC_CATALOG" \
      --arg schema "$schema" \
      '{warehouse_id: $wh, statement: $stmt, catalog: $catalog, schema: $schema, wait_timeout: "50s"}')")"
  local state
  state="$(echo "$response" | jq -r '.status.state // empty')"
  if [ "$state" != "SUCCEEDED" ]; then
    echo "SQL failed ($state): $statement" >&2
    echo "$response" >&2
    return 1
  fi
  echo "$response"
}

drop_from_show() {
  local show_sql="$1"
  local drop_kind="$2"
  local result

  result="$(execute_sql "$show_sql")"
  mapfile -t names < <(echo "$result" | jq -r '.result.data_array[]? | .[1] // .[0] // empty' | sed '/^$/d' | sort -u)
  for name in "${names[@]}"; do
    echo "Dropping ${drop_kind} ${UC_CATALOG}.${UC_SCHEMA}.${name}..."
    execute_sql "DROP ${drop_kind} IF EXISTS ${UC_CATALOG}.${UC_SCHEMA}.${name}" || true
  done
}

drop_catalog_tables() {
  local result schema table

  result="$(execute_sql \
    "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema') AND table_name IS NOT NULL" \
    "information_schema")" || return 0

  while IFS=$'\t' read -r schema table; do
    [ -n "$schema" ] && [ -n "$table" ] || continue
    echo "Dropping TABLE ${UC_CATALOG}.${schema}.${table}..."
    execute_sql "DROP TABLE IF EXISTS ${UC_CATALOG}.${schema}.${table}" "$schema" || true
  done < <(echo "$result" | jq -r '.result.data_array[]? | @tsv')

  result="$(execute_sql \
    "SELECT table_schema, table_name FROM information_schema.views WHERE table_schema NOT IN ('information_schema') AND table_name IS NOT NULL" \
    "information_schema")" || return 0

  while IFS=$'\t' read -r schema table; do
    [ -n "$schema" ] && [ -n "$table" ] || continue
    echo "Dropping VIEW ${UC_CATALOG}.${schema}.${table}..."
    execute_sql "DROP VIEW IF EXISTS ${UC_CATALOG}.${schema}.${table}" "$schema" || true
  done < <(echo "$result" | jq -r '.result.data_array[]? | @tsv')
}

echo "Purging application objects in ${UC_CATALOG}.${UC_SCHEMA}..."

for _ in 1 2 3; do
  drop_from_show "SHOW VIEWS" VIEW || true
  drop_from_show "SHOW TABLES" TABLE || true
  drop_from_show "SHOW VOLUMES" VOLUME || true
done

echo "Scanning catalog ${UC_CATALOG} for remaining managed tables/views..."
drop_catalog_tables || true

echo "UC purge complete."
