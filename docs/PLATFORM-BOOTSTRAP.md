# Platform bootstrap (operator credentials)

> **Greenfield clients (talk → proposal → GO → new repo):**
> [CLIENT-REPO-BOOTSTRAP.md](CLIENT-REPO-BOOTSTRAP.md) — this is the main flow.

Standing **operator** credentials in the template repo's Cursor environment wire Azure
and GitHub. For quick slug demos on the template repo itself, see Step 3 below.

**Operator stays in Cursor.** CI applies via GitHub OIDC. Client-specific names belong
in **spawned client repos**, not template `main`.

---

## Security model (read this first)

```text
┌─────────────────────────────────────────────────────────────┐
│  OPERATOR SP (persistent — Cursor Runtime Secrets)          │
│  Owner on demo subscription · wires GitHub · triggers GHA   │
│  Stays in Cursor · rotate secret on a schedule you choose   │
└──────────────────────────┬──────────────────────────────────┘
                           │ creates / configures
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  CI SP (gha-databricks-workspace-deploy)                    │
│  GitHub secrets: AZURE_CLIENT_ID / TENANT / SUBSCRIPTION    │
│  OIDC federated creds: production + pull_request            │
│  Used ONLY by GitHub Actions — not stored in Cursor         │
└──────────────────────────┬──────────────────────────────────┘
                           │ terraform apply / bundle deploy
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Demo stack (ephemeral per deployment_slug)                 │
│  dbw-<slug>, rg-dbx-<slug>, UC catalog <slug>, own state key│
│  Names from resolve-deployment.sh — not from committed code │
└─────────────────────────────────────────────────────────────┘
```

| Rule | Why |
|------|-----|
| **Two identities** | Operator SP configures Azure/GitHub. CI SP applies infra via OIDC only. |
| **Operator stays in Cursor** | Reuse for every demo on your sandbox subscription. |
| **Agent does not apply** | No `terraform apply` / `bundle deploy` in the agent VM. Trigger **deploy** workflow instead. |
| **No hard-wired demos** | Do not commit client slugs, storage account names, or workspace names to `main`. Pass slug in chat; CI derives names at runtime. |
| **Demo subscription** | Personal/sandbox sub — not corporate production. |
| **Fine-grained `GH_TOKEN`** | Single repo: workflow dispatch + secrets/variables admin. |

---

## Step 0 — Create the operator service principal (once, outside Cursor)

An **Owner** on the subscription creates a dedicated operator app. This is the only
secret with broad Azure power in Cursor.

```bash
# Run locally as subscription Owner (not in the agent)
OPERATOR_APP_ID=$(az ad app create --display-name "cursor-operator-dbx-demo" --query appId -o tsv)
az ad sp create --id "$OPERATOR_APP_ID"
OPERATOR_SECRET=$(az ad app credential reset --id "$OPERATOR_APP_ID" --query password -o tsv)

az role assignment create --assignee "$OPERATOR_APP_ID" --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

echo "Save for Cursor Runtime Secrets only:"
echo "BOOTSTRAP_AZURE_CLIENT_ID=$OPERATOR_APP_ID"
echo "BOOTSTRAP_AZURE_CLIENT_SECRET=(shown once above)"
```

You never put the operator secret in git.

---

## Step 1 — Cursor Cloud environment (persistent)

Dashboard → **Cloud Agents** → this repo’s environment → **Secrets**.

### Runtime Secrets (sensitive — leave these in place)

| Name | Value |
|------|--------|
| `BOOTSTRAP_AZURE_CLIENT_ID` | Operator SP app id |
| `BOOTSTRAP_AZURE_CLIENT_SECRET` | Operator SP secret |
| `BOOTSTRAP_AZURE_TENANT_ID` | Entra tenant id |
| `BOOTSTRAP_AZURE_SUBSCRIPTION_ID` | Azure subscription id |
| `GH_TOKEN` | Fine-grained PAT for `GH_REPO` only |

### Environment variables (non-secret — subscription-wide, not per demo)

| Name | Example | Notes |
|------|---------|--------|
| `GH_REPO` | `youruser/databricks-workspace-deploy` | `owner/repo` |
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxyourname01` | Globally unique; **shared** across all slugs on this sub |
| `AZURE_LOCATION` | `eastus2` | Optional; used for every slug deploy |
| `GHA_CLIENT_ID` | *(empty)* | Set only to **reuse** an existing CI app |

**Do not** put per-demo names (`WORKSPACE_NAME`, `UC_STORAGE_ACCOUNT_NAME`, client
slugs) in Cursor env vars unless you intentionally run a fixed **production**
environment — for learning, use **slug deploys** instead (Step 3).

Optional production overrides (only if you need merge-to-main with custom names):
`WORKSPACE_NAME`, `UC_STORAGE_ACCOUNT_NAME`, `RESOURCE_GROUP_NAME`, `CATALOG_NAME`,
`SCHEMA_NAME`, `WAREHOUSE_NAME`, `ADMIN_GROUP`, `DATA_ENGINEER_GROUP`.

---

## Step 2 — Platform bootstrap (once per repo + subscription)

Wires OIDC, state storage, and GitHub secrets. Idempotent.

**Cursor agent prompt:**

> Platform bootstrap per docs/PLATFORM-BOOTSTRAP.md: validate env, run
> `scripts/bootstrap-platform.sh`. Do not commit secrets or client-specific names.

```bash
bash scripts/bootstrap-validate-env.sh
bash scripts/bootstrap-platform.sh
```

Re-run safely if RBAC or federated creds were missed.

---

## Step 3 — Spin up a demo (every time — no re-bootstrap)

Give the agent a **slug** in chat (e.g. `acme01`, `pilot42`). The agent must
**not** commit that slug or derived Azure names to the repo.

**Cursor agent prompt:**

> Deploy demo slug `meridian01` per PLATFORM-BOOTSTRAP.md — trigger the deploy
> workflow only. Do not change committed tfvars or backend files.

```bash
export DEPLOYMENT_SLUG=meridian01
bash scripts/trigger-demo-deploy.sh
```

CI runs **deploy** with `workflow_dispatch`. `resolve-deployment.sh` derives:

| Input | Derived at runtime |
|-------|-------------------|
| `meridian01` | `dbw-meridian01`, `rg-dbx-meridian01`, catalog `meridian01`, state key `databricks/meridian01/…` |

**Tear down** the same slug (human confirmation in workflow UI):

```bash
export DEPLOYMENT_SLUG=meridian01
export DESTROY_CONFIRM=meridian01   # or `production` for prod-mode destroy
bash scripts/trigger-demo-destroy.sh
```

---

## What the agent should and should not do

| Do | Do not |
|----|--------|
| Run bootstrap once per sub/repo | `terraform apply` / `bundle deploy` |
| Trigger deploy/destroy with slug from chat | Commit slug-specific tfvars, backend hcl, or env tables |
| Open PRs for generic template improvements | Put client-specific IDs or env details in template docs |
| Summarize CI app id + state SA (non-secret) | Echo operator secret or `GH_TOKEN` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `MissingSubscription` on role assign | Operator SP needs **Owner** on the subscription |
| `AuthorizationPermissionMismatch` on state | Re-run bootstrap; CI SP needs **Storage Blob Data Contributor** on state SA |
| `gh: Resource not accessible` | PAT needs workflow + secrets/variables scope |
| Storage account name taken | Pick another `STATE_STORAGE_ACCOUNT_NAME` in Cursor env |
| Deploy workflow not found | Check `GH_REPO` matches the connected repo |

Manual RBAC fallback: `APP_ID=… SUB_ID=… STATE_SA=… bash scripts/assign-ci-roles.sh`.

---

## Related

- [DEMO-SETUP.md](DEMO-SETUP.md) — full demo checklist
- [AGENTS.md](../AGENTS.md) — agent boundaries
- `.cursor/skills/platform-bootstrap/SKILL.md` — agent skill
