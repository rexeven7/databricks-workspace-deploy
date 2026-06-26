#!/usr/bin/env bash
# Create a new client repo from this template, wire OIDC, and trigger first deploy.
#
# Run from the TEMPLATE repo (Cursor control plane). Operator creds stay in Cursor.
# Client-specific names live in the NEW repo only — never committed to template main.
#
# Required: CLIENT_SLUG, GH_TEMPLATE_REPO, BOOTSTRAP_*, GH_TOKEN, STATE_STORAGE_ACCOUNT_NAME
# Optional: PROPOSAL_FILE, CLIENT_REPO_NAME, DEPLOY_ON_GO (default true), SCHEMA_NAME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$SCRIPT_DIR/spawn-client-validate-env.sh"

: "${AZURE_LOCATION:=eastus2}"
: "${DEPLOY_ON_GO:=true}"
: "${ADMIN_GROUP:=account users}"
: "${DATA_ENGINEER_GROUP:=account users}"
: "${SCHEMA_NAME:=sales}"

CLIENT_REPO_NAME="${CLIENT_REPO_NAME:-${CLIENT_SLUG}-databricks}"
GH_REPO="${GH_ORG}/${CLIENT_REPO_NAME}"
sa_suffix="$(echo "$CLIENT_SLUG" | cut -c1-18)"

export GH_TOKEN
log() { printf '%s\n' "$*"; }

create_repo_if_missing() {
  if gh repo view "$GH_REPO" &>/dev/null; then
    log "Repository already exists: $GH_REPO (continuing with bootstrap)"
    return 0
  fi
  log "Creating repository from template: $GH_TEMPLATE_REPO → $GH_REPO"
  gh repo create "$GH_REPO" \
    --template "$GH_TEMPLATE_REPO" \
    --private \
    --description "Databricks platform — ${CLIENT_SLUG}" \
    --disable-wiki \
    --disable-issues
  log "Waiting for template generation..."
  sleep 5
}

seed_client_repo() {
  local tmpdir repo_dir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  repo_dir="$tmpdir/client-repo"

  log "Cloning $GH_REPO to seed client-specific files..."
  git -c "http.extraHeader=AUTHORIZATION: bearer ${GH_TOKEN}" \
    clone --depth 1 "https://github.com/${GH_REPO}.git" "$repo_dir"

  cd "$repo_dir"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"

  # State keys and storage account name for this client (fine in client repo).
  for backend in \
    terraform/live/10-infra/env/prod.backend.hcl \
    terraform/live/20-platform/env/prod.backend.hcl; do
    if [ -f "$backend" ]; then
      sed -i.bak \
        -e "s|key[[:space:]]*=[[:space:]]*\"databricks/prod/|key                  = \"databricks/${CLIENT_SLUG}/|" \
        -e "s|storage_account_name = \".*\"|storage_account_name = \"${STATE_STORAGE_ACCOUNT_NAME}\"|" \
        "$backend"
      rm -f "${backend}.bak"
    fi
  done

  for tfvars in terraform/live/20-platform/env/prod.tfvars terraform/live/10-infra/env/prod.tfvars; do
    if [ -f "$tfvars" ]; then
      sed -i.bak \
        -e "s|state_storage_account_name = \".*\"|state_storage_account_name = \"${STATE_STORAGE_ACCOUNT_NAME}\"|" \
        "$tfvars" 2>/dev/null || true
      rm -f "${tfvars}.bak" 2>/dev/null || true
    fi
  done

  mkdir -p docs/architecture-proposals
  if [ -n "${PROPOSAL_FILE:-}" ]; then
    dest_name="$(basename "$PROPOSAL_FILE")"
    cp "$REPO_ROOT/$PROPOSAL_FILE" "docs/architecture-proposals/$dest_name"
    log "Copied proposal → docs/architecture-proposals/$dest_name"
  fi

  cat > CLIENT.md <<EOF
# ${CLIENT_SLUG} — Databricks platform

Spawned from template [\`${GH_TEMPLATE_REPO}\`](https://github.com/${GH_TEMPLATE_REPO}).

| Item | Value |
|------|--------|
| Client slug | \`${CLIENT_SLUG}\` |
| Workspace | \`dbw-${CLIENT_SLUG}\` |
| State key prefix | \`databricks/${CLIENT_SLUG}/\` |
| Catalog | \`${CLIENT_SLUG}\` |

Architecture proposal: see \`docs/architecture-proposals/\`.

Deploy: Actions → **deploy** → slug \`${CLIENT_SLUG}\` (or merge to \`main\` after production env vars are set).
EOF

  git add -A
  if git diff --staged --quiet; then
    log "No seed changes to commit"
  else
    git commit -m "chore: seed ${CLIENT_SLUG} client repo"
    git push origin HEAD
    log "Pushed client seed commit"
  fi
}

bootstrap_client_repo() {
  export GH_REPO
  export WORKSPACE_NAME="dbw-${CLIENT_SLUG}"
  export RESOURCE_GROUP_NAME="rg-dbx-${CLIENT_SLUG}"
  export UC_STORAGE_ACCOUNT_NAME="stdbx${sa_suffix}"
  export CATALOG_NAME="${CLIENT_SLUG}"
  export WAREHOUSE_NAME="wh-${CLIENT_SLUG}"

  log "Bootstrapping GitHub + OIDC for $GH_REPO"
  bash "$SCRIPT_DIR/bootstrap-platform.sh"
}

trigger_first_deploy() {
  if [ "$DEPLOY_ON_GO" != "true" ]; then
    log "DEPLOY_ON_GO=false — skipping workflow dispatch"
    return 0
  fi
  export DEPLOYMENT_SLUG="$CLIENT_SLUG"
  log "Triggering first deploy from $GH_REPO"
  bash "$SCRIPT_DIR/trigger-demo-deploy.sh"
}

main() {
  log "=== Spawn client repo: $CLIENT_SLUG ==="
  create_repo_if_missing
  seed_client_repo
  bootstrap_client_repo
  trigger_first_deploy
  log ""
  log "=== Client repo ready ==="
  log "Repository: https://github.com/${GH_REPO}"
  log "Watch: Actions → deploy (slug ${CLIENT_SLUG})"
  log ""
  log "NEXT: Connect Cursor Cloud Agent to ${GH_REPO} for implementation PRs."
  log "Template repo (${GH_TEMPLATE_REPO}) stays generic — no client names on main."
}

main "$@"
