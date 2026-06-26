# Platform bootstrap (safe demo setup)

Wire **Azure OIDC + GitHub secrets + Terraform state** so CI can deploy — without
copy-pasting `az`/`gh` on your laptop. Designed for **Cursor Cloud agents** with
dashboard secrets; works locally too.

**After bootstrap:** delete bootstrap secrets from Cursor. Only the **CI service
principal** (via GitHub OIDC) can deploy.

---

## Security model (read this first)

```text
┌─────────────────────────────────────────────────────────────┐
│  BOOTSTRAP SP (temporary — Cursor Runtime Secrets)          │
│  Owner on subscription · creates CI app · assigns RBAC      │
│  DELETE from Cursor after bootstrap                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ creates
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  CI SP (gha-databricks-workspace-deploy)                    │
│  GitHub secrets: AZURE_CLIENT_ID / TENANT / SUBSCRIPTION    │
│  OIDC federated creds: production + pull_request            │
│  Used ONLY by GitHub Actions — not stored in Cursor         │
└─────────────────────────────────────────────────────────────┘
```

| Rule | Why |
|------|-----|
| **Two identities** | Bootstrap SP is powerful but **short-lived**. CI SP is what GHA uses forever. |
| **Secrets only in Cursor dashboard** | Never commit `BOOTSTRAP_AZURE_CLIENT_SECRET` or `GH_TOKEN`. |
| **Runtime Secret type** | Redacted in agent chat/commits ([Cursor docs](https://cursor.com/docs/cloud-agent/security-network)). |
| **Fine-grained `GH_TOKEN`** | Single repo, `Administration: read/write` + `Secrets: read/write` + `Variables: read/write`. |
| **Demo subscription** | Use a personal/sandbox sub — not production corporate tenant for learning. |
| **Agent does not apply** | Bootstrap only. `terraform apply` stays in GitHub Actions. |

---

## Step 0 — Create the bootstrap service principal (once, outside Cursor)

An **Owner** on the subscription creates a dedicated bootstrap app (5 minutes in Portal
or CLI). This is the only secret with broad power, and you remove it from Cursor after.

```bash
# Run locally as subscription Owner (not in the agent)
BOOTSTRAP_APP_ID=$(az ad app create --display-name "cursor-bootstrap-dbx-demo" --query appId -o tsv)
az ad sp create --id "$BOOTSTRAP_APP_ID"
BOOTSTRAP_SECRET=$(az ad app credential reset --id "$BOOTSTRAP_APP_ID" --query password -o tsv)

az role assignment create --assignee "$BOOTSTRAP_APP_ID" --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

echo "Save for Cursor Runtime Secrets only:"
echo "BOOTSTRAP_AZURE_CLIENT_ID=$BOOTSTRAP_APP_ID"
echo "BOOTSTRAP_AZURE_CLIENT_SECRET=(shown once above)"
```

You never put the bootstrap secret in git.

---

## Step 1 — Cursor Cloud environment secrets

Dashboard → **Cloud Agents** → select this repo’s environment → **Secrets**.

### Runtime Secrets (sensitive)

| Name | Value |
|------|--------|
| `BOOTSTRAP_AZURE_CLIENT_ID` | Bootstrap SP app id |
| `BOOTSTRAP_AZURE_CLIENT_SECRET` | Bootstrap SP secret |
| `BOOTSTRAP_AZURE_TENANT_ID` | Entra tenant id |
| `BOOTSTRAP_AZURE_SUBSCRIPTION_ID` | Azure subscription id |
| `GH_TOKEN` | Fine-grained PAT for `GH_REPO` only |

### Environment variables (non-secret)

| Name | Example | Notes |
|------|---------|--------|
| `GH_REPO` | `youruser/databricks-workspace-deploy` | `owner/repo` |
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxyourname01` | Globally unique, 3–24 lowercase alphanumeric |
| `UC_STORAGE_ACCOUNT_NAME` | `stdbxucprod0001` | Globally unique — production UC storage |
| `AZURE_LOCATION` | `eastus2` | Optional |
| `GHA_CLIENT_ID` | *(empty)* | Set only to **reuse** an existing CI app |

Optional overrides: `WORKSPACE_NAME`, `RESOURCE_GROUP_NAME`, `CATALOG_NAME`, etc.
(see `scripts/bootstrap-platform.sh` defaults).

---

## Step 2 — Run bootstrap (agent or local)

**Cursor agent prompt:**

> Run platform bootstrap per docs/PLATFORM-BOOTSTRAP.md: validate env, then
> `bash scripts/bootstrap-platform.sh`. Do not commit secrets. Summarize results and
> remind me to delete bootstrap secrets from Cursor.

**Local (same secrets exported in shell):**

```bash
bash scripts/bootstrap-validate-env.sh
bash scripts/bootstrap-platform.sh
```

The script is **idempotent** where Azure/GitHub APIs allow (skips existing federated
creds, storage, role assignments).

---

## Step 3 — Tear down bootstrap secrets

Cursor dashboard → delete:

- `BOOTSTRAP_AZURE_CLIENT_*`
- `GH_TOKEN`

Optional: disable or delete the bootstrap Entra app in Azure.

**Keep:** GitHub repo secrets (`AZURE_*`) and the CI service principal — CI needs those.

---

## Step 4 — Verify

1. Actions → **deploy** → slug `smoketest01` → full stack.
2. Actions → **destroy** → same slug → cleanup.
3. Or merge to `main` for production demo vars.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `MissingSubscription` on role assign | Bootstrap SP needs **Owner** on the subscription |
| `AuthorizationPermissionMismatch` on state | Re-run bootstrap; CI SP needs **Storage Blob Data Contributor** on state SA |
| `gh: Resource not accessible` | PAT needs repo admin + secrets/variables scope |
| Storage account name taken | Pick another `STATE_STORAGE_ACCOUNT_NAME` |

Manual RBAC fallback: `bash scripts/assign-ci-roles.sh` (after `az login` as Owner).

---

## Related

- [DEMO-SETUP.md](DEMO-SETUP.md) — full demo checklist
- [AGENTS.md](../AGENTS.md) — agent boundaries
- `.cursor/skills/platform-bootstrap/SKILL.md` — agent skill
