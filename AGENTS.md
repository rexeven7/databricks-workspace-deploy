# AGENTS.md

## Cursor Cloud specific instructions

This repo is **Infrastructure-as-Code**, not a runnable server/app. It ships two
things:

- **Terraform** (`terraform/`) — Azure Databricks workspace + Unity Catalog +
  serverless SQL warehouse, split into two layers (`live/10-infra`,
  `live/20-platform`). See `README.md` and `docs/ARCHITECTURE.md`.
- **Databricks Asset Bundle** (`bundle/`) — a serverless job + notebook.

**Prerequisites (human setup, not the agent by default):** See [docs/DEMO-SETUP.md](docs/DEMO-SETUP.md)
for Azure OIDC, GitHub secrets/variables, and the protected `production`
environment. The default agent workflow does **not** need cloud credentials.

**Platform operator:** standing `BOOTSTRAP_*` in Cursor on the **template** repo.
**Greenfield GO:** [docs/CLIENT-REPO-BOOTSTRAP.md](docs/CLIENT-REPO-BOOTSTRAP.md) — spawn new repo + deploy.

---

## What the cloud agent should do

0. **Client intake** — Greenfield requests: follow
   `.cursor/skills/databricks-client-intake/SKILL.md` — propose architecture, ask
   questions, write proposal. **Do not commit client names to template `main`.**
0c. **GO (spawn client repo)** — When user says GO after approving a proposal: follow
   `.cursor/skills/client-repo-go/SKILL.md` and
   [docs/CLIENT-REPO-BOOTSTRAP.md](docs/CLIENT-REPO-BOOTSTRAP.md). Run
   `scripts/spawn-client-repo.sh`. Deploy happens on the **new repo** via GHA.
0b. **Platform bootstrap / slug demo (template repo only)** — Wire OIDC or quick slug
   deploy on **this** repo: [PLATFORM-BOOTSTRAP.md](docs/PLATFORM-BOOTSTRAP.md).
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
- **Exception:** **demo operator** on the template repo — bootstrap or **GO spawn**
  per [CLIENT-REPO-BOOTSTRAP.md](docs/CLIENT-REPO-BOOTSTRAP.md); never commit client
  names to template `main`.
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
- **Run the `deploy` workflow** with a `deployment_slug` for an isolated sandbox
  sandbox (recommended for demos).

Optional: user approves the protected `production` environment before apply.

---

## Tooling

Terraform `1.9.8` (matches CI), the Databricks CLI, the Azure CLI, and GitHub CLI
are installed in the cloud agent VM via `.cursor/environment.json` →
`scripts/cursor-cloud-install.sh`. `uv` is **not** installed by that script and is
not needed for the offline validation flow (there are no Python dependency files;
the bundle notebook runs on Databricks serverless, not locally). `terraform init`
without `-backend=false` needs Azure creds — use offline init for validation only.

- The install script installs the Databricks CLI to `/usr/local/bin` (needs root)
  and is idempotent, so it is safe to re-run on every cloud-agent session startup.

- `terraform init` adds a platform-specific `h1:` hash to tracked
  `.terraform.lock.hcl` files. That is a local side effect — do **not** commit it
  unless you intend to (run `git checkout -- terraform/live/*/.terraform.lock.hcl`).
