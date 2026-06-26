---
name: client-repo-go
description: >-
  Execute GO after client intake: spawn a new GitHub repo from the template, bootstrap
  OIDC/secrets for that repo, copy the architecture proposal, and trigger deploy.
  Use when the user says GO, deploy, spin up, or create the client repo after approving
  an architecture proposal. Runs only from the template repo with standing BOOTSTRAP_* secrets.
---

# Client repo GO (spawn + bootstrap + deploy)

## When to use

User approved architecture and said **GO** (or equivalent: "create the repo", "deploy it",
"spin it up"). You are on the **template** repo with operator secrets configured.

**Before GO:** intake should be complete — proposal drafted, must-have questions answered.

Read [docs/CLIENT-REPO-BOOTSTRAP.md](../../../docs/CLIENT-REPO-BOOTSTRAP.md).

## Confirm with user (if not already clear)

| Field | Source |
|-------|--------|
| `CLIENT_SLUG` | User — alphanumeric, e.g. `meridian` |
| `PROPOSAL_FILE` | Path under `docs/architecture-proposals/` (if written during intake) |
| `CLIENT_REPO_NAME` | Optional — default `<slug>-databricks` |

## Execute

```bash
export CLIENT_SLUG="<slug-from-user>"
export PROPOSAL_FILE="docs/architecture-proposals/<proposal-file>.md"   # omit if none
bash scripts/spawn-client-validate-env.sh
bash scripts/spawn-client-repo.sh
```

## Agent rules

| Do | Do not |
|----|--------|
| Run spawn scripts with user-provided slug | Commit client slug/names to **template** `main` |
| Summarize new repo URL + Actions link | `terraform apply` / `bundle deploy` in agent VM |
| Tell user to connect Cursor to the **new repo** for implementation PRs | Merge client-specific proposal to template `main` |
| Echo non-secret outputs (repo name, slug, CI app id) | Print `BOOTSTRAP_*` secret or `GH_TOKEN` |

## After spawn

Tell the user:

1. Open `https://github.com/<org>/<slug>-databricks` → Actions → **deploy**
2. Connect Cursor Cloud Agent to the **client repo** (not the template)
3. Implementation PRs (SDP, dashboards, etc.) happen in the client repo per the proposal phases

## If secrets missing

Point to CLIENT-REPO-BOOTSTRAP.md prerequisites. Do not improvise credentials.

## If user only wanted a proposal (no GO)

Use `databricks-client-intake` skill only — do not run spawn scripts.
