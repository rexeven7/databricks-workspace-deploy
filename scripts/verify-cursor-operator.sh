#!/usr/bin/env bash
# Preflight: verify Cursor operator secrets before GO / spawn.
# Does not print secret values. Exit 1 on hard failures.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/az-cli.sh
source "$SCRIPT_DIR/lib/az-cli.sh"

failures=0
warn() { printf 'WARN: %s\n' "$*" >&2; }
ok() { printf 'ok: %s\n' "$*"; }
die() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }

trim_env() {
  local name="$1"
  if [ -n "${!name:-}" ]; then
    printf -v "$name" '%s' "$(echo "${!name}" | trim_tsv)"
    export "$name"
  fi
}

echo "=== verify-cursor-operator ==="

for v in BOOTSTRAP_AZURE_CLIENT_ID BOOTSTRAP_AZURE_CLIENT_SECRET BOOTSTRAP_AZURE_TENANT_ID \
  BOOTSTRAP_AZURE_SUBSCRIPTION_ID GH_TOKEN GH_TEMPLATE_REPO STATE_STORAGE_ACCOUNT_NAME; do
  trim_env "$v"
  if [ -z "${!v:-}" ]; then
    die "missing $v"
  else
    ok "$v is set"
  fi
done

export GH_TOKEN
export AZURE_CORE_ONLY_SHOW_ERRORS=true

if ! gh auth status -h github.com &>/dev/null; then
  die "GH_TOKEN invalid — gh auth failed"
else
  ok "GH_TOKEN accepted by gh"
fi

if gh repo view "$GH_TEMPLATE_REPO" &>/dev/null; then
  ok "template repo readable: $GH_TEMPLATE_REPO"
else
  die "cannot read template repo $GH_TEMPLATE_REPO (token needs repo access)"
fi

if ! az login --service-principal \
  -u "$BOOTSTRAP_AZURE_CLIENT_ID" \
  -p "$BOOTSTRAP_AZURE_CLIENT_SECRET" \
  --tenant "$BOOTSTRAP_AZURE_TENANT_ID" --output none 2>/dev/null; then
  die "BOOTSTRAP_AZURE_* login failed (check client id, secret, tenant)"
else
  ok "operator SP login succeeded"
fi

if az account set --subscription "$BOOTSTRAP_AZURE_SUBSCRIPTION_ID" --output none 2>/dev/null \
  && az account show --query id -o tsv 2>/dev/null | trim_tsv | grep -q "^${BOOTSTRAP_AZURE_SUBSCRIPTION_ID}$"; then
  sub_name="$(az account show --query name -o tsv | trim_tsv)"
  ok "operator SP can access subscription: $sub_name"
else
  die "operator SP has no access to subscription $BOOTSTRAP_AZURE_SUBSCRIPTION_ID"
  echo "  Fix locally (Owner login):" >&2
  echo "    APP_ID=$BOOTSTRAP_AZURE_CLIENT_ID SUB_ID=$BOOTSTRAP_AZURE_SUBSCRIPTION_ID bash scripts/assign-operator-role.sh" >&2
fi

# Git write check: create a throwaway private repo, push, delete (optional skip)
if [ "${VERIFY_GH_WRITE:-true}" = "true" ]; then
  test_repo="${GH_ORG:-${GH_TEMPLATE_REPO%%/*}}/cursor-operator-preflight-$$"
  if gh repo create "$test_repo" --private --description "preflight delete me" &>/dev/null; then
    if gh repo clone "$test_repo" /tmp/cursor-preflight-$$ -- --depth 1 &>/dev/null; then
      ok "GH_TOKEN can create and clone repos"
    else
      warn "GH_TOKEN created repo but clone failed — use classic PAT with 'repo' scope or fine-grained: Contents read/write on all repos"
      failures=$((failures + 1))
    fi
    gh repo delete "$test_repo" --yes &>/dev/null || true
    rm -rf "/tmp/cursor-preflight-$$" 2>/dev/null || true
  else
    warn "could not create test repo (may still work if template spawn permissions differ)"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "Fix failures before GO. See docs/CLIENT-REPO-BOOTSTRAP.md § Troubleshooting." >&2
  exit 1
fi

echo "verify-cursor-operator: all checks passed"
