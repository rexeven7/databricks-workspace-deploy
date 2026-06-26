---
name: client-repo-go
description: >-
  REQUIRED for greenfield deploy on template repo. Spawn new GitHub repo from template,
  bootstrap OIDC, trigger deploy. Use when user says GO, deploy, create the repo,
  spin up, ship it, or approves architecture proposal. NEVER open a PR on template —
  run spawn-client-repo.sh instead. Needs BOOTSTRAP_* and GH_TOKEN in Cursor secrets.
---

# Client repo GO (spawn + bootstrap + deploy)

## This replaces opening a PR

If the user wants a **new client environment**, the deliverable is:

1. New GitHub repo (from template)
2. OIDC wired
3. **deploy** workflow dispatched

**Do not** open a PR on the template repo for this.

Read [docs/CLIENT-REPO-BOOTSTRAP.md](../../../docs/CLIENT-REPO-BOOTSTRAP.md).

## Prerequisites (check before running)

| Secret / var | Required |
|--------------|----------|
| `BOOTSTRAP_AZURE_*` (4) | Yes |
| `GH_TOKEN` | Yes |
| `GH_TEMPLATE_REPO` | Yes |
| `STATE_STORAGE_ACCOUNT_NAME` | Yes |
| `CLIENT_SLUG` | From user in this session |

If missing, tell user to complete [PLATFORM-BOOTSTRAP.md](../../../docs/PLATFORM-BOOTSTRAP.md) Step 0–1 — do not fall back to opening a PR.

## Execute (mandatory commands)

```bash
export CLIENT_SLUG="<slug-from-user>"
export PROPOSAL_FILE="docs/architecture-proposals/<file>.md"   # if draft exists locally
bash scripts/spawn-client-validate-env.sh
bash scripts/spawn-client-repo.sh
```

## Agent rules

| Do | Do not |
|----|--------|
| Run spawn scripts | Open PR on template |
| Summarize `https://github.com/<org>/<slug>-databricks` | `terraform apply` |
| Tell user to reconnect Cursor to **client repo** | Commit client slug to template `main` |

## After spawn

1. User opens client repo → Actions → **deploy**
2. Future implementation PRs happen on the **client repo** only
