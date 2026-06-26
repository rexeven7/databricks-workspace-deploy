#!/usr/bin/env bash
# Create a new client repo from this template, wire OIDC, and trigger first deploy.
#
# Order: create repo → bootstrap (secrets/OIDC) → seed content → deploy
# Bootstrap must succeed before deploy is dispatched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

bash "$SCRIPT_DIR/spawn-client-validate-env.sh"

: "${AZURE_LOCATION:=eastus2}"
: "${DEPLOY_ON_GO:=true}"
: "${ADMIN_GROUP:=account users}"
: "${DATA_ENGINEER_GROUP:=account users}"
: "${SCHEMA_NAME:=sales}"
: "${SEED_SKIP_ON_FAILURE:=true}"

CLIENT_REPO_NAME="${CLIENT_REPO_NAME:-${CLIENT_SLUG}-databricks}"
GH_REPO="${GH_ORG}/${CLIENT_REPO_NAME}"

export GH_TOKEN
log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

create_repo_if_missing() {
  if gh repo view "$GH_REPO" &>/dev/null; then
    log "Repository already exists: $GH_REPO (continuing)"
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
  sleep 8
}

bootstrap_client_repo() {
  # shellcheck source=lib/deploy-names.sh
  source "$SCRIPT_DIR/lib/deploy-names.sh"
  export GH_REPO
  export WORKSPACE_NAME="dbw-${CLIENT_SLUG}"
  export RESOURCE_GROUP_NAME="rg-dbx-${CLIENT_SLUG}"
  export UC_STORAGE_ACCOUNT_NAME="$(resolve_uc_storage_account_name "$CLIENT_SLUG")"
  export CATALOG_NAME="${CLIENT_SLUG}"
  export WAREHOUSE_NAME="wh-${CLIENT_SLUG}"

  log "UC storage account (layer 10): $UC_STORAGE_ACCOUNT_NAME"
  log "Bootstrapping GitHub + OIDC for $GH_REPO"
  bash "$SCRIPT_DIR/bootstrap-platform.sh"
}

verify_client_secrets() {
  log "Verifying GitHub secrets on $GH_REPO ..."
  for name in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
    if ! gh secret list -R "$GH_REPO" | awk '{print $1}' | grep -qx "$name"; then
      err_msg="Missing GitHub secret $name on $GH_REPO"
      log "ERROR: $err_msg"
      return 1
    fi
    ok_msg="ok: $name"
    log "$ok_msg"
  done
}

seed_client_repo() {
  local tmpdir repo_dir
  tmpdir="$(mktemp -d)"
  repo_dir="$tmpdir/client-repo"

  log "Cloning $GH_REPO to seed client-specific files (via gh)..."
  if ! gh repo clone "$GH_REPO" "$repo_dir" -- --depth 1; then
    if [ "$SEED_SKIP_ON_FAILURE" = "true" ]; then
      warn "Seed clone failed — continuing (bootstrap + deploy still run)."
      warn "Use a classic PAT with 'repo' scope or fine-grained Contents: read/write on all repositories."
      rm -rf "$tmpdir"
      return 0
    fi
    rm -rf "$tmpdir"
    return 1
  fi

  cd "$repo_dir"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"

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
  if [ -n "${PROPOSAL_FILE:-}" ] && [ -f "$REPO_ROOT/$PROPOSAL_FILE" ]; then
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

Deploy: Actions → **deploy** → slug \`${CLIENT_SLUG}\`.
EOF

  git add -A
  if git diff --staged --quiet; then
    log "No seed changes to commit"
  else
    git commit -m "chore: seed ${CLIENT_SLUG} client repo"
    if git push origin HEAD; then
      log "Pushed client seed commit"
    else
      warn "Seed push failed — repo exists but CLIENT.md/proposal may be missing."
    fi
  fi
  rm -rf "$tmpdir"
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
  bootstrap_client_repo
  verify_client_secrets
  seed_client_repo
  trigger_first_deploy
  log ""
  log "=== Client repo ready ==="
  log "Repository: https://github.com/${GH_REPO}"
  log "Watch: Actions → deploy (slug ${CLIENT_SLUG})"
  log ""
  log "NEXT: Connect Cursor Cloud Agent to ${GH_REPO} for implementation PRs."
}

main "$@"
