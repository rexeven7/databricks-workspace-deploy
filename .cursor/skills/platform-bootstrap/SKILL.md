---
name: platform-bootstrap
description: >-
  Template-repo operator: wire OIDC on THIS repo or trigger slug deploy/destroy.
  For greenfield clients (new repo on GO), use client-repo-go skill instead.
  Uses standing BOOTSTRAP_* Cursor Runtime Secrets.
---

# Platform bootstrap (template repo only)

> **Greenfield client (new repo on GO):** use `client-repo-go` skill and
> [CLIENT-REPO-BOOTSTRAP.md](../../../docs/CLIENT-REPO-BOOTSTRAP.md) instead.

This skill is for **this template repo** — OIDC wiring or slug-based deploy/destroy
without creating a new repository.

## Gather from the user (every session)

| Question | Used for |
|----------|----------|
| Deployment slug? | `DEPLOYMENT_SLUG` — alphanumeric, e.g. `meridian01` |
| First time on this sub/repo? | Run platform bootstrap (Step 2) |
| Tear down? | `trigger-demo-destroy.sh` with matching confirm |

Do **not** assume a slug from committed files, docs, or past demos.

## Platform bootstrap (once per repo + subscription)

```bash
bash scripts/bootstrap-validate-env.sh
bash scripts/bootstrap-platform.sh
```

## Deploy a demo (typical path)

```bash
export DEPLOYMENT_SLUG="<slug-from-user>"
bash scripts/trigger-demo-deploy.sh
```

Tell the user to watch Actions → **deploy** for progress.

## Destroy a demo

```bash
export DEPLOYMENT_SLUG="<slug-from-user>"
export DESTROY_CONFIRM="<slug-from-user>"   # must match workflow rules
bash scripts/trigger-demo-destroy.sh
```

## Agent rules

| Do | Do not |
|----|--------|
| Run scripts above with user-provided slug | `terraform apply` / `bundle deploy` |
| Summarize CI app id + state SA (non-secret) | Echo `BOOTSTRAP_AZURE_CLIENT_SECRET` or `GH_TOKEN` |
| Open PRs only for generic script/doc fixes | Commit per-client names, IDs, or slugs |
| Keep operator creds in Cursor (user's choice) | Tell user to delete bootstrap secrets after one run |

## If secrets are missing

Point the user to PLATFORM-BOOTSTRAP.md Step 0–1. Do not use personal passwords in chat.
