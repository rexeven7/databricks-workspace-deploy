#!/usr/bin/env bash
# Drop application tables/views in a UC schema so Terraform can destroy the schema.
# Bundle and jobs create objects Terraform does not manage — purge before layer-20 destroy.
# No table names are hardcoded; discovers objects via SHOW TABLES / SHOW VIEWS.
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

drop_objects() {
  local show_sql="$1"
  local drop_kind="$2"
  local result names name

  result="$(execute_sql "$show_sql" || true)"
  [ -n "$result" ] || return 0

  mapfile -t names < <(echo "$result" | jq -r '.result.data_array[]? | .[1] // .[0] // empty' | sed '/^$/d' | sort -u)
  for name in "${names[@]}"; do
    echo "Dropping ${drop_kind} ${UC_CATALOG}.${UC_SCHEMA}.${name}..."
    execute_sql "DROP ${drop_kind} IF EXISTS ${UC_CATALOG}.${UC_SCHEMA}.${name}" || true
  done
}

echo "Purging application objects in ${UC_CATALOG}.${UC_SCHEMA}..."

# Repeat until empty — drops handle one "layer" per pass (e.g. views before tables).
for _ in 1 2 3; do
  drop_objects "SHOW VIEWS IN ${UC_CATALOG}.${UC_SCHEMA}" VIEW
  drop_objects "SHOW TABLES IN ${UC_CATALOG}.${UC_SCHEMA}" TABLE
done

echo "UC schema purge complete."
