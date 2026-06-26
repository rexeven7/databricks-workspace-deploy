#!/usr/bin/env bash
# Guard workflow_dispatch destroy: user must type the normalized slug or "production".
set -euo pipefail

confirm="${INPUT_CONFIRM:-}"
slug_raw="${INPUT_DEPLOYMENT_SLUG:-}"

if [ -z "$confirm" ]; then
  echo "confirm input is required" >&2
  exit 1
fi

if [ -n "$slug_raw" ]; then
  expected="$(echo "$slug_raw" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  if [ -z "$expected" ]; then
    echo "deployment_slug must contain at least one alphanumeric character" >&2
    exit 1
  fi
  mode="sandbox"
else
  expected="production"
  mode="production"
fi

if [ "$confirm" != "$expected" ]; then
  echo "Confirmation mismatch: expected exactly '$expected', got '$confirm'" >&2
  exit 1
fi

echo "Destroy confirmed for $mode ($expected)"
