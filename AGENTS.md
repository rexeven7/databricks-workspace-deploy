# AGENTS.md

## Cursor Cloud specific instructions

This repo is **Infrastructure-as-Code**, not a runnable server/app. It ships two
things:

- **Terraform** (`terraform/`) — Azure Databricks workspace + Unity Catalog +
  serverless SQL warehouse, split into two layers (`live/10-infra`,
  `live/20-platform`). See `README.md` and `docs/INTERVIEW.md`.
- **Databricks Asset Bundle** (`bundle/`) — a serverless job + notebook.

**Prerequisites (human setup, not the agent):** See [docs/DEMO-SETUP.md](docs/DEMO-SETUP.md)
for Azure OIDC, GitHub secrets/variables, and the protected `production`
environment. The agent does not need cloud credentials.

---

## What the cloud agent should do

1. **Gather parameters in conversation** — region, deployment slug, catalog/schema
   names, feature requests. Do not ask the user to edit tfvars by hand unless they
   prefer it; prefer documenting runtime overrides (GitHub Environment vars or
   `workflow_dispatch` slug via `.github/scripts/resolve-deployment.sh`).
2. **Author changes** — Terraform modules, bundle resources, docs, workflow tweaks.
3. **Run offline checks** (no cloud creds):

```bash
terraform fmt -check -recursive terraform/   # run from repo root
terraform -chdir=terraform/live/10-infra    init -backend=false && terraform -chdir=terraform/live/10-infra    validate && terraform -chdir=terraform/live/10-infra    test
terraform -chdir=terraform/live/20-platform init -backend=false && terraform -chdir=terraform/live/20-platform validate && terraform -chdir=terraform/live/20-platform test
```

4. **Open a PR** with summary, test plan, and notes on what CI `terraform plan`
   will show (plan runs in GitHub Actions with OIDC — the agent does not run plan).
5. **Babysit the PR** — fix scoped CI failures, address review comments, re-push
   until validate/plan jobs are green. Summarize the plan from the Actions job
   summary for the user.

---

## What the cloud agent should NOT do

- **Do not** store or use `ARM_*`, `AZURE_*`, or Databricks secrets. CI applies
  via federated OIDC (see `docs/DEMO-SETUP.md`).
- **Do not** run `terraform apply`, `terraform plan` (needs backend + Azure), or
  `databricks bundle deploy` unless the user explicitly overrides this policy for
  a local session with their own credentials.
- **Do not** commit client-specific globally-unique names (storage accounts,
  workspace names) to `main`. Use sandbox slugs or document GitHub Environment
  variables instead.

`databricks bundle validate` calls the workspace API and requires credentials — it
runs in CI, not in the default cloud-agent workflow.

---

## After the PR is green

Tell the user to either:

- **Merge to `main`** — applies production values from the GitHub `production`
  environment (if configured), or
- **Run the `deploy` workflow** with a `deployment_slug` for an isolated interview
  sandbox (recommended for demos).

Optional: user approves the protected `production` environment before apply.

---

## Tooling

Terraform `1.9.8` (matches CI), the Databricks CLI, and `uv` are installed in the
cloud agent VM via `.cursor/environment.json`. `terraform init` without
`-backend=false` needs Azure creds — use offline init for validation only.

- `terraform init` adds a platform-specific `h1:` hash to tracked
  `.terraform.lock.hcl` files. That is a local side effect — do **not** commit it
  unless you intend to (run `git checkout -- terraform/live/*/.terraform.lock.hcl`).
