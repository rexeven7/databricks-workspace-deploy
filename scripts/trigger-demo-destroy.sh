#!/usr/bin/env bash
# Dispatch the destroy workflow for a sandbox or production demo teardown.
# Requires GH_TOKEN + GH_REPO. DESTROY_CONFIRM must match workflow guard rules.
set -euo pipefail

slug="${DEPLOYMENT_SLUG:-${1:-}}"
confirm="${DESTROY_CONFIRM:-${2:-}}"

if [ -z "$slug" ] && [ -z "$confirm" ]; then
  echo "Usage: DEPLOYMENT_SLUG=<slug> DESTROY_CONFIRM=<slug|production> $0" >&2
  echo "   or: $0 <slug> <confirm>" >&2
  exit 1
fi

for var in GH_TOKEN GH_REPO; do
  if [ -z "${!var:-}" ]; then
    echo "Missing required env: $var" >&2
    exit 1
  fi
done

if [ -z "$confirm" ]; then
  echo "Missing DESTROY_CONFIRM (must match slug or 'production' per destroy workflow)" >&2
  exit 1
fi

ref="${DEPLOY_REF:-main}"
log() { printf '%s\n' "$*"; }

args=(-f "confirm=$confirm")
if [ -n "$slug" ]; then
  slug="$(echo "$slug" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  args+=(-f "deployment_slug=$slug")
fi

log "Dispatching destroy workflow (confirm=$confirm, slug=${slug:-<production>})"
gh workflow run destroy.yml \
  -R "$GH_REPO" \
  --ref "$ref" \
  "${args[@]}"

log "Triggered. Open Actions → destroy — review inputs before approving if required."
