# AGENTS.md

## Cursor Cloud specific instructions

This repo is **Infrastructure-as-Code**, not a runnable server/app. It ships two
things:

- **Terraform** (`terraform/`) — Azure Databricks workspace + Unity Catalog +
  serverless SQL warehouse, split into two layers (`live/10-infra`,
  `live/20-platform`). See `README.md` and `docs/INTERVIEW.md`.
- **Databricks Asset Bundle** (`bundle/`) — a serverless job + notebook.

### What runs without cloud credentials (the cloud-agent dev workflow)

The Terraform offline path mirrors the CI PR gate (`.github/workflows/terraform.yml`)
and works fully offline. Per layer (`terraform/live/10-infra`, `terraform/live/20-platform`):

```bash
terraform fmt -check -recursive terraform/   # run from repo root
terraform init -backend=false                # MUST use -backend=false; the azurerm backend needs Azure creds + a state storage account
terraform validate
terraform test                               # uses mock_provider / override_data -> no creds, no resources created
```

- `terraform init` adds a platform-specific `h1:` hash to the tracked
  `.terraform.lock.hcl` files. That is a local side effect — do **not** commit it
  unless you intend to (run `git checkout -- terraform/live/*/.terraform.lock.hcl`).

### What needs cloud credentials (intentionally not available to the agent)

- `databricks bundle validate -t dev` calls the workspace `/Me` API (dev mode
  prefixes resources per user), so it requires a real `DATABRICKS_HOST` +
  credentials. It will fail offline with an auth/DNS error — this is expected.
- `terraform plan`/`apply` and any `bundle deploy`/`run` need Azure + Databricks
  auth (`az login`, OIDC, or a `dbx-dev`/`dbx-prod` profile).
- By design (`docs/NEXT-STEPS.md` Option C), the cloud agent should **not** hold
  standing cloud credentials: it runs the offline checks and opens a PR; CI
  performs `apply`/`deploy` via Azure OIDC. Treat missing cloud creds as the
  normal state, not a setup failure.

### Tooling

Terraform `1.9.8` (matches CI), the Databricks CLI, and `uv` are installed by the
startup update script. `uv` lives at `~/.local/bin`. `az` CLI is only needed for
live applies (cloud creds required) and is not installed by default.
