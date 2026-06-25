# Next steps — Option B (GitHub Actions + Azure OIDC) and Option C (Cursor cloud agent)

Hand-off notes to continue in a fresh session. Everything from the live test was
**torn down** — the Azure subscription is clean. The repo, its modules, and the CI
workflow skeletons (`.github/workflows/terraform.yml`, `bundle.yml`) are in place.

Fill in these placeholders from your environment (the values are in your saved
session memory):
- `<SUBSCRIPTION_ID>` — the personal Azure subscription used for testing
- `<TENANT_ID>` — its Entra tenant
- `<GH_REPO>` = `rexeven7/databricks-workspace-deploy`
- Globally-unique storage names for state + UC data

Prereqs each session: `az login --tenant <TENANT_ID>`, then
`az account set --subscription <SUBSCRIPTION_ID>`. On Windows reload PATH after any
install: `$env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")`.

---

## Option B — GitHub Actions deploy via Azure OIDC (no stored secrets)

Goal: merge to `main` → CI runs `terraform apply` (layer 10 → 20) then `bundle deploy`,
authenticated by **federated OIDC** (no client secrets in GitHub). Makes the Actions
tab green and gives you a real "cloud deploy" story.

### B1. Create the Entra app + service principal
```bash
APP_ID=$(az ad app create --display-name "gha-databricks-workspace-deploy" --query appId -o tsv)
az ad sp create --id "$APP_ID"
```

### B2. Grant Azure roles  ⚠️ key gotcha
The repo creates an **`azurerm_role_assignment`** (in `uc_storage`), so the CI identity
must be able to *write role assignments*. Plain **Contributor is not enough** — use
**Owner**, or **Contributor + User Access Administrator**.
```bash
az role assignment create --assignee "$APP_ID" --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"
```

### B3. Federated credentials (one per trigger you want)
```bash
# apply on merge to main, gated by the "production" environment
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-env-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GH_REPO>:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
# (optional) plan on PRs, if you later add creds to the PR job
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-pull-request",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GH_REPO>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### B4. GitHub repo secrets + the protected environment
The workflow reads `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
```bash
gh secret set AZURE_CLIENT_ID       -b "$APP_ID"            -R <GH_REPO>
gh secret set AZURE_TENANT_ID       -b "<TENANT_ID>"        -R <GH_REPO>
gh secret set AZURE_SUBSCRIPTION_ID -b "<SUBSCRIPTION_ID>"  -R <GH_REPO>
# create the "production" environment the apply jobs reference
gh api -X PUT repos/<GH_REPO>/environments/production
```
(These three values aren't truly secret under OIDC; storing as secrets is fine. Add
required-reviewer protection to the `production` environment for a real approval gate.)

### B5. Re-bootstrap remote state (it was deleted in teardown)
```bash
az group create -n rg-tfstate -l eastus2
az storage account create -n <STATE_SA> -g rg-tfstate -l eastus2 \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create -n tfstate --account-name <STATE_SA> --auth-mode key
# Grant the CI identity data access to state (OIDC backend uses AAD, not keys):
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n <STATE_SA> -g rg-tfstate --query id -o tsv)"
```
Then set the real names in `terraform/live/*/env/*.backend.hcl` (`storage_account_name`)
and the `state_storage_account_name` in `terraform/live/20-platform/env/*.tfvars`.
Add `use_azuread_auth = true` to the backend (or `-backend-config="use_azuread_auth=true"`)
so the OIDC identity authenticates to the blob via AAD instead of an account key.

### B6. Set real, globally-unique storage names
`terraform/live/10-infra/env/*.tfvars` currently has **placeholder**
`uc_storage_account_name` values. Either commit real unique names (they're not secret)
or inject in CI via `TF_VAR_uc_storage_account_name`. Same for the state account.

### B7. Bundle CI auth (`bundle.yml`)
Cleanest: reuse the OIDC SP instead of a Databricks OAuth secret.
1. Add the service principal to the Databricks **workspace** (as account admin) and give
   it deploy permissions (and UC privileges for the catalog/schema it touches).
2. Change `bundle.yml` to authenticate via Azure: use `azure/login@v2` (OIDC), then set
   `DATABRICKS_HOST` + `DATABRICKS_AUTH_TYPE=azure-cli` (drop `DATABRICKS_CLIENT_ID/SECRET`).
   The Databricks CLI then rides the same Azure token.
   - Alternative: create a Databricks-managed OAuth secret for an account SP and keep the
     `DATABRICKS_CLIENT_ID` / `DATABRICKS_CLIENT_SECRET` secrets as the workflow expects.

### B8. Verify
Open a PR (validate/test run, no creds) → merge → watch `apply-infra` → `apply-platform`
→ bundle `deploy`. Confirm in the Actions tab. Remember the **two-layer order** and that
layer 20 reads layer 10's remote state.

---

## Option C — Cursor cloud agent that pulls the repo and deploys

Goal: a Cursor **Cloud Agent** clones the repo in an isolated cloud VM, makes changes,
runs `terraform plan`/`validate`, and opens a PR. Pairs best with Option B doing the apply.

### C1. Give Cursor the ai-dev-kit skills
Re-run the installer targeting Cursor (currently only `.claude/` is populated):
```powershell
irm https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/install.ps1 -OutFile install.ps1
.\install.ps1 --tools cursor --skills-profile data-engineer
```
⚠️ On this machine the MCP step fails under `uv` (pywin32 / antivirus). Use
`--skills-only` for a guaranteed install, or build the MCP venv with **pip** (see the
saved memory note for the exact commands). Skills land in `.cursor/`.

### C2. Define the cloud agent environment (`.cursor/environment.json`)
Commit a reproducible env so the agent has Terraform + the Databricks CLI. Example
(verify the exact schema against https://cursor.com/docs/cloud-agent — it evolves):
```json
{
  "agentCanUpdateSnapshot": true,
  "install": "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list && sudo apt-get update && sudo apt-get install -y terraform && curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh"
}
```

### C3. Secrets (set in the Cursor dashboard, NOT committed)
If you let the agent *apply* (not recommended), it needs:
`ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, and either OIDC or
`ARM_CLIENT_SECRET`; plus Databricks auth. **Prefer not to** — see C4.

### C4. The safe pattern (recommended)
Don't store standing cloud credentials in the agent VM. Let the agent only:
`terraform fmt/validate/test` + `databricks bundle validate` → commit → **open a PR**.
Then **Option B's GitHub Actions + OIDC performs the apply**. Talking point: "I never put
cloud credentials in a third-party agent; CI applies via federated identity."

### C5. Run it
Connect the GitHub repo in Cursor, launch a Cloud/Background Agent with a task such as
"add a `staging` environment to both Terraform layers and open a PR", and review the PR.

---

## Quick reference
- Re-deploy locally: `docs/INTERVIEW.md` §4 (runbook).
- Real-world gotchas already solved: `docs/INTERVIEW.md` §7 (Default Storage, identity planes).
- Architecture + the tool-split principle: `README.md`.
