#!/usr/bin/env bash
# Dispatch the deploy workflow for an isolated sandbox demo (slug-derived names).
# Requires GH_TOKEN + GH_REPO in env. Slug from DEPLOYMENT_SLUG or first argument.
set -euo pipefail

slug="${DEPLOYMENT_SLUG:-${1:-}}"
if [ -z "$slug" ]; then
  echo "Usage: DEPLOYMENT_SLUG=<slug> $0" >&2
  echo "   or: $0 <slug>" >&2
  exit 1
fi

slug="$(echo "$slug" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
if [ -z "$slug" ]; then
  echo "deployment slug must contain at least one alphanumeric character" >&2
  exit 1
fi

for var in GH_TOKEN GH_REPO; do
  if [ -z "${!var:-}" ]; then
    echo "Missing required env: $var" >&2
    exit 1
  fi
done

ref="${DEPLOY_REF:-main}"
log() { printf '%s\n' "$*"; }

log "Dispatching deploy workflow for slug: $slug (repo: $GH_REPO, ref: $ref)"
gh workflow run deploy.yml \
  -R "$GH_REPO" \
  --ref "$ref" \
  -f "deployment_slug=$slug"

log "Triggered. Open Actions → deploy to watch progress."
log "Derived names (runtime only, not committed): dbw-${slug}, rg-dbx-${slug}, catalog ${slug}"
