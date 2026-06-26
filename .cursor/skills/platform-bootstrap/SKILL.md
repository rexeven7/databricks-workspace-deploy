---
name: platform-bootstrap
description: >-
  One-time Azure OIDC + GitHub secrets + Terraform state bootstrap for demo
  subscriptions. Uses BOOTSTRAP_* Cursor Runtime Secrets (temporary operator SP).
  Use when the user asks to bootstrap, wire OIDC, set up GitHub secrets, spin up
  a new demo subscription, or run platform bootstrap. Do not use for routine PR work.
---

# Platform bootstrap (demo)

## Before running

1. Read [docs/PLATFORM-BOOTSTRAP.md](../../../docs/PLATFORM-BOOTSTRAP.md) — **two-SP security model**.
2. Confirm the user created a **bootstrap SP** (Owner) and added Cursor Secrets per the doc.
3. **Never** commit secrets, paste secrets into repo files, or log secret values.

## Steps

```bash
bash scripts/bootstrap-validate-env.sh
bash scripts/bootstrap-platform.sh
```

## Agent rules

| Do | Do not |
|----|--------|
| Run validate + bootstrap scripts | `terraform apply` / `bundle deploy` |
| Summarize CI app id + state SA name (non-secret) | Echo `BOOTSTRAP_AZURE_CLIENT_SECRET` or `GH_TOKEN` |
| Remind user to **delete bootstrap secrets** from Cursor after success | Store bootstrap creds in repo or PR description |
| Open a PR only if bootstrap **script** needs fixing | Put client workspace names on `main` unless user explicitly wants generic script changes |

## After success

Tell the user:

1. Remove `BOOTSTRAP_AZURE_*` and `GH_TOKEN` from Cursor Secrets.
2. Run **deploy** workflow with a test slug, or merge to `main`.
3. CI uses OIDC only — no standing cloud creds in Cursor for day-to-day agents.

## If bootstrap secrets are missing

Point the user to PLATFORM-BOOTSTRAP.md Step 0–1. Do not improvise with personal passwords in chat.
