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

## Step 0 — Create the operator service principal (once, on your laptop)

This is the **only** step that uses your personal Azure login. Everything after
goes into **Cursor Secrets** and stays there for every client demo.

**Prereq:** you are **Owner** (or can create app registrations + assign roles) on
the demo subscription.

```bash
az login
az account set --subscription "<your-demo-subscription>"
bash scripts/create-operator-sp.sh
```

The script:

1. Creates (or reuses) Entra app `cursor-operator-dbx-demo`
2. Adds a client secret (`--append` so old secrets are not wiped)
3. Assigns **Owner** on the subscription using the service principal **object id**
   (not the app id — the old copy-paste `az role assignment --assignee $APP_ID`
   often fails with `PrincipalNotFound`)
4. Prints all four `BOOTSTRAP_AZURE_*` values — copy them into Cursor **Runtime Secrets**

| Cursor secret | Source |
|---------------|--------|
| `BOOTSTRAP_AZURE_CLIENT_ID` | script output |
| `BOOTSTRAP_AZURE_CLIENT_SECRET` | script output (**once**) |
| `BOOTSTRAP_AZURE_TENANT_ID` | script output |
| `BOOTSTRAP_AZURE_SUBSCRIPTION_ID` | script output |

You never put the operator secret in git.

**If role assignment still fails:** wait 1–2 minutes after app creation and re-run
the script, or assign Owner manually in Portal → Subscription → IAM → members →
search `cursor-operator-dbx-demo`.

---

## Step 1 — Cursor Cloud environment (persistent)

Dashboard → **Cloud Agents** → this repo’s environment → **Secrets**.

### Runtime Secrets (sensitive — leave these in place)

| Name | Value |
|------|--------|
| `BOOTSTRAP_AZURE_CLIENT_ID` | From Step 0 |
| `BOOTSTRAP_AZURE_CLIENT_SECRET` | From Step 0 |
| `BOOTSTRAP_AZURE_TENANT_ID` | From Step 0 |
| `BOOTSTRAP_AZURE_SUBSCRIPTION_ID` | From Step 0 |
| `GH_TOKEN` | Fine-grained PAT — see scopes below |

### Environment variables (non-secret)

| Name | Example | When needed |
|------|---------|-------------|
| `GH_TEMPLATE_REPO` | `youruser/databricks-workspace-deploy` | **GO flow** — spawn client repos from this template |
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxyourname01` | Shared Terraform state SA (globally unique) |
| `AZURE_LOCATION` | `eastus2` | Optional |
| `GH_REPO` | `youruser/databricks-workspace-deploy` | Only for **slug demos on the template repo** (not GO) |
| `GHA_CLIENT_ID` | *(empty)* | Reuse existing CI Entra app if you already created one |

**`GH_TOKEN` scopes (fine-grained PAT):**

- **GO flow:** access to your user/org + **Administration** on repos you create from
  template + **Secrets and variables** + **Actions** (workflow dispatch)
- **Template slug demo only:** single-repo admin is enough

**Do not** put per-client slugs or workspace names in Cursor env vars. Those come
from chat at GO time (`CLIENT_SLUG`) or deploy workflow input.

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
| `MissingSubscription` on role assign | **Git Bash on Windows:** re-run `bash scripts/create-operator-sp.sh` (CRLF fix). Or: `APP_ID=<id> SUB_ID=<sub> bash scripts/assign-operator-role.sh` |
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
