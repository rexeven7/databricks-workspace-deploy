# Platform demo setup

> **Template caveat:** One-time platform setup runs on *your* Azure subscription and
> GitHub repo. Committed files use **placeholder** names — real values come from GitHub
> Environment variables, operator bootstrap, or `workflow_dispatch` slugs at deploy time.

---

## Platform wiring checklist (your instance)

Complete once per **subscription + GitHub repo**. Use
[PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) with standing Cursor operator secrets, or
the manual steps below.

| Step | How to verify |
|---|---|
| Entra CI app + OIDC federated credentials | GitHub secrets `AZURE_*` set |
| State RG + storage account + `tfstate` container | Bootstrap script or Portal |
| CI SP **Owner** on subscription | Deploy workflow plan/apply succeeds |
| CI SP **Storage Blob Data Contributor** on state SA | `terraform init` with OIDC backend |
| Cursor operator secrets (`BOOTSTRAP_*`, `GH_TOKEN`) | Agent can run bootstrap + trigger deploy |

### Manual RBAC fallback (if bootstrap role assignment fails)

Your signed-in user can create resources but may lack permission to assign roles
(`MissingSubscription` from `az role assignment`). A subscription **Owner** must
grant the CI service principal:

1. Azure Portal → **Subscriptions** → your sandbox sub → **Access control (IAM)**
2. **Add role assignment** → **Owner** → members → search `gha-databricks-workspace-deploy`
3. State storage account → **Access control (IAM)** → **Storage Blob Data Contributor** → same SP

Or, from a shell where you have UAA/Owner:

```bash
APP_ID="<CI_APP_ID>" SUB_ID="<SUBSCRIPTION_ID>" STATE_SA="<STATE_SA>" bash scripts/assign-ci-roles.sh
```

---

## What you set up ahead of time (checklist)

### Azure (one subscription is enough)

| Item | Notes |
|---|---|
| Azure subscription | Personal or sandbox sub. Contributor alone is **not** enough — the UC storage module creates `azurerm_role_assignment`, so the CI identity needs **Owner** or **Contributor + User Access Administrator**. |
| Entra tenant ID | Used as `AZURE_TENANT_ID`. |
| UC metastore in region | Required for catalog creation. New Azure workspaces usually get one automatically. |
| Remote state storage | Resource group `rg-tfstate`, storage account (globally unique name), container `tfstate`. Created once; all deployments share it with **different state keys** per slug/environment. |
| Tear-down discipline | Use the **destroy** workflow (demo/sandbox only) or `terraform destroy` per slug. Never delete `rg-tfstate` unless re-bootstrapping. |

### GitHub repo

| Item | Where | Notes |
|---|---|---|
| `AZURE_CLIENT_ID` | Repository **secret** | Entra app (service principal) appId |
| `AZURE_TENANT_ID` | Repository **secret** | Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Repository **secret** | Target subscription |
| `production` environment | Settings → Environments | Optional **required reviewers** = human approval gate before apply |
| Federated credential | Entra app | `repo:<owner>/<repo>:environment:production` for apply/deploy |
| Federated credential (PR plan) | Entra app | `repo:<owner>/<repo>:pull_request` for `terraform plan` on PRs |
| `Storage Blob Data Contributor` | On state storage account | For OIDC identity (`use_azuread_auth=true`) |

#### GitHub Environment **variables** (production)

These override committed `prod.tfvars` at runtime (`TF_VAR_*`). Names are not secret.

| Variable | Example | Purpose |
|---|---|---|
| `STATE_RESOURCE_GROUP_NAME` | `rg-tfstate` | State backend RG |
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfstatedbxdemo` | State storage account (globally unique — pick yours) |
| `AZURE_LOCATION` | `eastus2` | Region for sandbox deploys |
| `WORKSPACE_NAME` | `dbw-demo-prod` | Production workspace (merge-to-main path) |
| `UC_STORAGE_ACCOUNT_NAME` | `stdbxucprod0001` | UC ADLS account (globally unique) |
| `RESOURCE_GROUP_NAME` | `rg-databricks-prod` | Production RG |
| `CATALOG_NAME` | `prod` | UC catalog |
| `SCHEMA_NAME` | `sales` | Domain schema within the catalog (bundle + UC purge) |
| `WAREHOUSE_NAME` | `wh-demo-prod` | SQL warehouse |
| `ADMIN_GROUP` | `account users` | UC catalog admin principal |
| `DATA_ENGINEER_GROUP` | `account users` | UC engineer grants |

`DATABRICKS_HOST` and `WAREHOUSE_ID` are **not** required for deploy — CI reads them from Terraform state outputs. Optional: set `DATABRICKS_HOST` only if you want `bundle validate` on PRs before any workspace exists.

Optional bundle PR validate secrets (only if `DATABRICKS_HOST` is set for early PR validation):

| Secret | Purpose |
|---|---|
| `DATABRICKS_CLIENT_ID` | OAuth M2M SP for validate-only |
| `DATABRICKS_CLIENT_SECRET` | OAuth secret |

Prefer **OIDC + `DATABRICKS_AUTH_TYPE=azure-cli`** for deploy (no Databricks secret) once a workspace exists.

### Cursor (cloud agent)

| Item | Notes |
|---|---|
| GitHub repo connected | Cursor dashboard → connect `<owner>/<repo>` |
| `.cursor/environment.json` | Committed — installs Terraform + Databricks CLI in the agent VM |
| **Default: no cloud secrets** | Agent runs offline checks + opens PRs; **GitHub Actions applies** via OIDC |
| **Demo operator** | Standing `BOOTSTRAP_*` + `GH_TOKEN` — spawns client repos on GO |
| ai-dev-kit skills | `install.ps1 --tools cursor --skills-only --skills-profile data-engineer --silent` → `.cursor/skills/` (committed) |

**Greenfield flow:** intake + proposal on this repo → **GO** spawns a client repo →
[CLIENT-REPO-BOOTSTRAP.md](CLIENT-REPO-BOOTSTRAP.md).

Slug-only demos on **this** repo (no new repo): [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md).

Legacy manual commands (reference only):


Replace placeholders, run once locally (`az login`):

```bash
APP_ID=$(az ad app create --display-name "gha-databricks-workspace-deploy" --query appId -o tsv)
az ad sp create --id "$APP_ID"
az role assignment create --assignee "$APP_ID" --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-env-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GH_REPO>:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-pull-request",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GH_REPO>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

gh secret set AZURE_CLIENT_ID       -b "$APP_ID"            -R <GH_REPO>
gh secret set AZURE_TENANT_ID       -b "<TENANT_ID>"        -R <GH_REPO>
gh secret set AZURE_SUBSCRIPTION_ID -b "<SUBSCRIPTION_ID>"  -R <GH_REPO>
gh api -X PUT "repos/<GH_REPO>/environments/production"
```

State bootstrap:

```bash
az group create -n rg-tfstate -l eastus2
az storage account create -n <STATE_SA> -g rg-tfstate -l eastus2 \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create -n tfstate --account-name <STATE_SA> --auth-mode key
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n <STATE_SA> -g rg-tfstate --query id -o tsv)"
```

Set `STATE_STORAGE_ACCOUNT_NAME` on the `production` environment to `<STATE_SA>`.

---

## CI/CD workflows (what runs when)

| Workflow | Trigger | What it does |
|---|---|---|
| **terraform** | PR | Offline `fmt` / `validate` / `test` + **cloud `plan`** (OIDC) posted to job summary |
| **terraform** | Push to `main` (`terraform/**`) | Apply layer 10 → 20, then **bundle deploy + `sample_ingest` smoke test** |
| **terraform** | Manual dispatch, `bundle_only` | Deploy/update bundle and run `sample_ingest` (platform already exists) |
| **bundle** | PR | `bundle validate` (optional; needs `DATABRICKS_HOST` env var) |
| **bundle** | Push to `main` (`bundle/**`) | `bundle deploy -t ci` + `sample_ingest` smoke test |
| **deploy** | Manual (`workflow_dispatch`) | Slug → isolated state + resources → Terraform → bundle + smoke test |
| **destroy** | Manual (`workflow_dispatch`) | **Demo teardown:** reverse of deploy; optional state purge for clean re-apply |

### Tear down a demo environment

Use the **destroy** workflow (not the Azure portal alone — that leaves stale Terraform state).

**Sandbox** (same slug as deploy):

1. Actions → **destroy** → Run workflow.
2. `deployment_slug`: e.g. `demojun25` (normalized to alphanumeric).
3. `confirm`: type the normalized slug exactly (`demojun25`).
4. Leave **purge_state** checked for a clean slate before the next deploy.

**Production demo** (GitHub Environment vars footprint):

1. Actions → **destroy** → leave `deployment_slug` empty.
2. `confirm`: type `production`.
3. Approve the `production` environment if reviewers are configured.

What it does: `bundle destroy` (best-effort) → **drop tables/views/volumes** in the
Terraform-managed schema (catalog/schema from state; SQL API context, no hardcoded names)
→ sync `force_destroy` on external location → Terraform destroy layer 20 → layer 10 →
optionally deletes state blobs in `rg-tfstate` (does **not** delete the state storage account).

What it does **not** do: remove `rg-tfstate`, Entra OIDC app, or GitHub secrets. UC catalog
metadata in the account metastore may need manual cleanup in the account console after workspace
deletion.

Legacy manual destroy: use the destroy workflow above; local `terraform destroy` is
only needed when debugging outside CI.

### If Terraform ran but the bundle did not (catch-up)

This can happen when platform was applied before bundle deploy was wired into CI, or when only workflow files changed on `main` (apply is skipped; bundle is not).

1. **Easiest:** merge/push any change under `bundle/**` — `bundle.yml` deploys from Terraform state (no manual vars).
2. **Or:** Actions → **terraform** → Run workflow → check **bundle_only** → Run.

After deploy, CI runs the `sample_ingest` job automatically (populates `prod.sales.trips_curated`).

### Slug sandbox deploy (no commits to `main`)

**Prerequisite:** GitHub → Environments → **production** must have:

| Variable | Your value |
|----------|------------|
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxrexeven701` (your existing state SA) |
| `STATE_RESOURCE_GROUP_NAME` | `rg-tfstate` |
| `AZURE_LOCATION` | `eastus2` |

The slug does **not** pick the state storage account — it only picks the **state key**
inside that account (e.g. `databricks/hike2/10-infra.tfstate`). Terraform layer 10
still creates a **new** UC data storage account per slug (e.g. `stdbxhike2af2c33`).

1. Actions → **deploy** → Run workflow.
2. `deployment_slug`: e.g. `Hike2` (normalized to `hike2`).
3. Optionally check **run_bundle_job**.
4. Approve the `production` environment if reviewers are configured.
5. Watch layer 10 → 20 → bundle complete.

Preview locally: `VAR_STATE_STORAGE_ACCOUNT_NAME=sttfdbxrexeven701 DEPLOYMENT_SLUG=Hike2 bash scripts/print-deploy-names.sh`

**Not for real client production** — use change-managed destroy outside this template.

---

## Cursor cloud agent demo script

**Agent does (no cloud credentials in Cursor):**

1. Gather parameters in chat (region, slug, catalog layout, feature request).
2. Edit Terraform / bundle / docs; run offline `terraform fmt`, `validate`, `test`.
3. Open a PR with a clear description and test plan.
4. Babysit the PR: fix CI failures, summarize the **terraform plan** from the Actions job summary.

**You do:**

1. Review the PR and the plan output.
2. Approve the `production` environment (if configured).
3. Merge **or** run the **deploy** workflow with the agreed slug.

**Talking point:** AI accelerates authoring and review; federated CI holds credentials and performs apply. The template repo never gets locked to one client.

Example agent prompt:

> Add a `staging` target to the bundle and document the variable wiring. Run offline
> Terraform tests, open a PR, and summarize what the CI terraform plan will change.

---

## Verify end-to-end

1. **PR only:** push a branch with a trivial Terraform comment → green `validate` + `plan-infra` / `plan-platform`.
2. **Sandbox:** run **deploy** with slug `smoketest01` → confirm workspace + job in Azure/Databricks UI.
3. **Tear down** the sandbox.
4. (Optional) set production env vars and merge to `main` for a fixed prod stack.

---

## Multi-customer reuse

| Pattern | When |
|---|---|
| **Template stays generic on `main`** | Always |
| **CLIENT-REPO GO flow** | New client — spawn dedicated repo ([CLIENT-REPO-BOOTSTRAP.md](CLIENT-REPO-BOOTSTRAP.md)) |
| **`workflow_dispatch` slug** | Quick throwaway sandbox on the template repo |
| **GitHub Environment per client** | Same repo, different `vars` + OIDC subject |

Do **not** commit client-specific storage account names or state backends to **template** `main`.

---

## Related docs

- [CLIENT-REPO-BOOTSTRAP.md](CLIENT-REPO-BOOTSTRAP.md) — talk → proposal → GO → new repo + deploy
- [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) — operator credentials + slug demos on template
- [NEXT-STEPS.md](NEXT-STEPS.md) — documentation map
- [ARCHITECTURE.md](ARCHITECTURE.md) — design rationale
- [AGENTS.md](../AGENTS.md) — what the cloud agent should and should not do
