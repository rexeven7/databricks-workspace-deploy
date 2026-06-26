# Demo & interview setup

> **Caveat for reviewers and interviewers:** Everything below is **one-time
> platform setup** on *your* Azure subscription and GitHub repo. The repo on
> `main` stays a **reusable template** — customer-specific names and state keys
> are injected at deploy time (GitHub Environment variables or a
> `workflow_dispatch` slug), not committed to source control. You do this setup
> once; the live demo is "open Cursor → agent opens a PR → CI plans → you
> approve → Actions deploys."

---

## Bootstrap status (this repo)

| Step | Status |
|---|---|
| Entra app `gha-databricks-workspace-deploy` | Done — `AZURE_CLIENT_ID` = `327026fe-c20e-4688-a8ca-070602722b73` |
| OIDC federated credentials (production + PR) | Done |
| GitHub secrets (`AZURE_*`) | Done |
| GitHub `production` environment variables (state, location, groups) | Done |
| State RG `rg-tfstate` + SA `sttfdbxrexeven701` + container `tfstate` | Done |
| **RBAC for CI service principal** | **You must complete** — see below |
| `.cursor/skills` (ai-dev-kit data-engineer profile) | Done |
| First sandbox deploy | Run **deploy** workflow after RBAC |
| Layer 20 Databricks auth | CI sets `DATABRICKS_AUTH_TYPE=azure-cli` after `azure/login` (needed for UC storage credentials) |

### Manual RBAC fallback (required if `assign-ci-roles.sh` fails)

Your signed-in user can create resources but may lack permission to assign roles
(`MissingSubscription` from `az role assignment`). An subscription **Owner** must
grant the CI service principal:

1. Azure Portal → **Subscriptions** → *Taylor Farms* → **Access control (IAM)**
2. **Add role assignment** → **Owner** → members → search `gha-databricks-workspace-deploy`
3. Storage account `sttfdbxrexeven701` → **Access control (IAM)** → **Storage Blob Data Contributor** → same SP

Or, from a shell where you have UAA/Owner:

```bash
bash scripts/assign-ci-roles.sh
```

---

## What you set up ahead of time (checklist)

### Azure (one subscription is enough)

| Item | Notes |
|---|---|
| Azure subscription | Personal or interview sandbox sub. Contributor alone is **not** enough — the UC storage module creates `azurerm_role_assignment`, so the CI identity needs **Owner** or **Contributor + User Access Administrator**. |
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
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxrexeven701` | State storage account |
| `AZURE_LOCATION` | `eastus2` | Region for sandbox deploys |
| `WORKSPACE_NAME` | `dbw-demo-prod` | Production workspace (merge-to-main path) |
| `UC_STORAGE_ACCOUNT_NAME` | `stdbxucprod0001` | UC ADLS account (globally unique) |
| `RESOURCE_GROUP_NAME` | `rg-databricks-prod` | Production RG |
| `CATALOG_NAME` | `prod` | UC catalog |
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
| GitHub repo connected | Cursor dashboard → connect `rexeven7/databricks-workspace-deploy` |
| `.cursor/environment.json` | Committed — installs Terraform + Databricks CLI in the agent VM |
| **No** cloud secrets in Cursor | Agent runs offline checks + opens PRs; **GitHub Actions applies** via OIDC |
| ai-dev-kit skills | `install.ps1 --tools cursor --skills-only --skills-profile data-engineer --silent` → `.cursor/skills/` (committed) |

### Entra app bootstrap (copy-paste)

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
| **deploy** | Manual (`workflow_dispatch`) | **Interview path:** slug → isolated state + resources → Terraform → bundle + smoke test |
| **destroy** | Manual (`workflow_dispatch`) | **Demo teardown:** reverse of deploy; optional state purge for clean re-apply |

### Tear down a demo environment

Use the **destroy** workflow (not the Azure portal alone — that leaves stale Terraform state).

**Sandbox** (same slug as deploy):

1. Actions → **destroy** → Run workflow.
2. `deployment_slug`: e.g. `interviewjun25` (normalized to alphanumeric).
3. `confirm`: type the normalized slug exactly (`interviewjun25`).
4. Leave **purge_state** checked for a clean slate before the next deploy.

**Production demo** (GitHub Environment vars footprint):

1. Actions → **destroy** → leave `deployment_slug` empty.
2. `confirm`: type `production`.
3. Approve the `production` environment if reviewers are configured.

What it does: `bundle destroy` (best-effort) → Terraform destroy layer 20 → layer 10 →
optionally deletes state blobs in `rg-tfstate` (does **not** delete the state storage account).

What it does **not** do: remove `rg-tfstate`, Entra OIDC app, or GitHub secrets. UC catalog
metadata in the account metastore may need manual cleanup in the account console after workspace
deletion.

**Not for real client production** — use change-managed destroy outside this template.

Legacy manual destroy (if needed): see interview sandbox section below.

### If Terraform ran but the bundle did not (catch-up)

This can happen when platform was applied before bundle deploy was wired into CI, or when only workflow files changed on `main` (apply is skipped; bundle is not).

1. **Easiest:** merge/push any change under `bundle/**` — `bundle.yml` deploys from Terraform state (no manual vars).
2. **Or:** Actions → **terraform** → Run workflow → check **bundle_only** → Run.

After deploy, CI runs the `sample_ingest` job automatically (populates `prod.sales.trips_curated`).

### Interview sandbox deploy (no commits to `main`)

1. Actions → **deploy** → Run workflow.
2. `deployment_slug`: e.g. `interview-jun25` (alphanumeric; drives names + state prefix `databricks/interview-jun25/`).
3. Optionally check **run_bundle_job**.
4. Approve the `production` environment if reviewers are configured.
5. Watch layer 10 → 20 → bundle complete.

Resources created (example slug `interviewjun25`):

- `rg-dbx-interviewjun25`, `dbw-interviewjun25`, `stdbxinterviewjun25`, catalog `interviewjun25`.

Tear down when finished (from a machine with `az login`):

```bash
cd terraform/live/10-infra
terraform init -backend-config=resource_group_name=rg-tfstate \
  -backend-config=storage_account_name=<STATE_SA> \
  -backend-config=container_name=tfstate \
  -backend-config=key=databricks/interviewjun25/10-infra.tfstate \
  -backend-config=use_azuread_auth=true
terraform destroy -var-file=env/prod.tfvars \
  -var=resource_group_name=rg-dbx-interviewjun25 \
  -var=workspace_name=dbw-interviewjun25 \
  -var=uc_storage_account_name=stdbxinterviewjun25
# repeat for layer 20, then delete state blobs if desired
```

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

## Verify Option B end-to-end

1. **PR only:** push a branch with a trivial Terraform comment → green `validate` + `plan-infra` / `plan-platform`.
2. **Sandbox:** run **deploy** with slug `smoketest01` → confirm workspace + job in Azure/Databricks UI.
3. **Tear down** the sandbox.
4. (Optional) set production env vars and merge to `main` for a fixed prod stack.

---

## Multi-customer / consulting reuse

| Pattern | When |
|---|---|
| **This repo stays generic on `main`** | Always — modules + example tfvars only |
| **`workflow_dispatch` slug per demo/client** | Ephemeral sandboxes, interviews |
| **GitHub Environment per long-lived client** | Same repo, different `vars` + OIDC subject `environment:client-acme` |
| **Template repo → fork per client** | Long engagements; client owns their repo and secrets |

Do **not** commit client-specific storage account names or state backends to `main`.

---

## Related docs

- [NEXT-STEPS.md](NEXT-STEPS.md) — original Option B/C hand-off (bootstrap commands)
- [INTERVIEW.md](INTERVIEW.md) — talking points and architecture
- [AGENTS.md](../AGENTS.md) — what the cloud agent should and should not do
