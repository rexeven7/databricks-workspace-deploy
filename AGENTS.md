# AGENTS.md

## Cursor Cloud specific instructions

This repo is **Infrastructure-as-Code**, not a runnable server/app. It ships two
things:

- **Terraform** (`terraform/`) — Azure Databricks workspace + Unity Catalog +
  serverless SQL warehouse, split into two layers (`live/10-infra`,
  `live/20-platform`). See `README.md` and `docs/INTERVIEW.md`.
- **Databricks Asset Bundle** (`bundle/`) — a serverless job + notebook.

**Prerequisites (human setup, not the agent by default):** See [docs/DEMO-SETUP.md](docs/DEMO-SETUP.md)
for Azure OIDC, GitHub secrets/variables, and the protected `production`
environment. The default agent workflow does **not** need cloud credentials.

**Platform bootstrap (demo):** [docs/PLATFORM-BOOTSTRAP.md](docs/PLATFORM-BOOTSTRAP.md) —
temporary `BOOTSTRAP_*` secrets in Cursor; agent runs `scripts/bootstrap-platform.sh`.
Delete bootstrap secrets after; CI OIDC handles deploy.

---

## What the cloud agent should do

0. **Client / greenfield intake** — For requests like a new client workspace, dev+prod,
   medallion, SDP, metric views, dashboards, or Genie: follow
   `.cursor/skills/databricks-client-intake/SKILL.md` — propose architecture and ask
   clarifying questions **before** writing code. **Write the proposal to**
   `docs/architecture-proposals/<client-slug>-<scope>.md` (from `_TEMPLATE.md`); prefer
   a proposal-only PR before implementation. See
   [docs/architecture-proposals/README.md](docs/architecture-proposals/README.md).
0b. **Platform bootstrap (demo only)** — When the user asks to bootstrap OIDC, GitHub
   secrets, or state storage: follow `.cursor/skills/platform-bootstrap/SKILL.md` and
   [docs/PLATFORM-BOOTSTRAP.md](docs/PLATFORM-BOOTSTRAP.md). Run
   `scripts/bootstrap-validate-env.sh` then `scripts/bootstrap-platform.sh` only.
   Never commit secrets.
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
   Link approved architecture proposals from `docs/architecture-proposals/` when
   the change implements a client engagement.
5. **Babysit the PR** — fix scoped CI failures, address review comments, re-push
   until validate/plan jobs are green. Summarize the plan from the Actions job
   summary for the user.

---

## What the cloud agent should NOT do (default)

- **Do not** store or use `ARM_*`, `AZURE_*`, or Databricks secrets for routine PR
  work. CI applies via federated OIDC (see `docs/DEMO-SETUP.md`).
- **Exception:** one-time **platform bootstrap** when user requests it and Cursor
  Secrets are set per [PLATFORM-BOOTSTRAP.md](docs/PLATFORM-BOOTSTRAP.md) — run bootstrap
  scripts only; never commit secret values.
- **Do not** run `terraform apply`, `terraform plan` (needs backend + Azure), or
  `databricks bundle deploy` unless the user explicitly overrides this policy for
  a local session with their own credentials.
- **Do not** run the **destroy** workflow or `terraform destroy` — demo teardown is a
  human action in GitHub Actions, not an agent default.
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
