# databricks-workspace-deploy

Reusable, parameterized **Azure Databricks** deployment: Terraform stands up the
workspace and governance; a Databricks Asset Bundle ships an example integration.
Built for GitHub Actions with the **free (OSS) Terraform CLI** — no Terraform Cloud.

> ✅ **Validated end-to-end on Azure**: workspace, Unity Catalog (bring-your-own
> storage via an access connector + external location), serverless SQL warehouse,
> and a serverless bundle job that writes a managed, liquid-clustered Delta table.

> Authored with the [Databricks AI Dev Kit](https://github.com/databricks-solutions/ai-dev-kit);
> the Databricks-side patterns below are sourced from its skills (`databricks-bundles`,
> `databricks-jobs`, `databricks-unity-catalog`, `databricks-dbsql`).

## The one principle that ties it together

**Terraform owns infrastructure & governance. Asset Bundles own application code.**

| Concern | Tool | Why |
|---|---|---|
| Workspace, Unity Catalog, SQL warehouse, grants | **Terraform** | Stateful, privileged, slow-changing *platform* |
| Jobs, notebooks, pipelines | **Asset Bundles (DABs)** | Ships *with the code*, fast-changing, developer-owned |
| AI-assisted authoring of both | **ai-dev-kit** | Skills + MCP tools in the editor |

Doing everything in one tool is the trap. The split gives each layer the right
lifecycle, blast radius, and credentials.

## Architecture

```
                 ┌──────────────────────── Terraform (azurerm) ───────────────────────┐
  layer 10       │  Resource Group  ──►  Azure Databricks Workspace (premium)          │
  INFRA          └────────────────────────────────┬───────────────────────────────────┘
                                                   │ workspace_id (via remote state)
                 ┌─────────────────────────────────▼──── Terraform (databricks) ───────┐
  layer 20       │  Unity Catalog: catalog ─► schema ─► volume + least-privilege grants │
  PLATFORM       │  Serverless SQL Warehouse                                            │
                 └────────────────────────────────┬───────────────────────────────────┘
                                                   │ catalog / schema / warehouse_id
                 ┌─────────────────────────────────▼──── Databricks Asset Bundle ───────┐
  INTEGRATION    │  Job (serverless) ─► notebook ─► managed, liquid-clustered Delta table │
                 └──────────────────────────────────────────────────────────────────────┘
```

Two Terraform **state files** (10 and 20), one per layer. Layer 20 reads layer
10's outputs via `terraform_remote_state`, so the `databricks` provider is
configured from an already-known `workspace_id` — avoiding the classic
"provider depends on a resource built in the same apply" problem.

## Repo layout

```
terraform/
  modules/{workspace,uc_storage,unity_catalog,sql_warehouse}/  # reusable, parameterized
                 # uc_storage = access connector + ADLS Gen2 + role (catalog managed location)
  live/
    10-infra/      # azurerm: RG + workspace        (state: .../10-infra.tfstate)
    20-platform/   # databricks: UC + warehouse     (state: .../20-platform.tfstate)
      env/{dev,prod}.tfvars         # per-env values
      env/{dev,prod}.backend.hcl    # per-env state location (partial backend)
      tests/*.tftest.hcl            # offline, mocked tests
bundle/
  databricks.yml         # variables + dev/prod targets
  resources/job.yml      # serverless job
  src/ingest_sample.py   # the notebook
| `.github/workflows/`       # terraform.yml, bundle.yml, deploy.yml, destroy.yml |
docs/INTERVIEW.md        # talking points mapped to sources  ← read this
docs/architecture-proposals/  # client ADRs (Option C intake — agent writes before code)
```

## Prerequisites

- Terraform ≥ 1.7, Databricks CLI, `az` CLI, `uv` (all installed in this repo's setup)
- An Azure subscription + permission to create resource groups & workspaces
- A Unity Catalog metastore assigned to the workspace's region (platform-team owned;
  this repo creates the *catalog* downward, not the metastore itself). New Azure
  workspaces usually auto-provision one.
- The catalog is created with an explicit **managed location** (an external location
  backed by the `uc_storage` access connector). This is required on accounts with UC
  **Default Storage**, where a metastore has no default root.

## Quickstart (live apply)

```bash
# 0. Auth
az login

# 1. Layer 10 — workspace
cd terraform/live/10-infra
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars
WS_URL=$(terraform output -raw workspace_url)

# 2. Layer 20 — Unity Catalog + SQL warehouse
cd ../20-platform
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars
WH_ID=$(terraform output -raw warehouse_id)

# 3. The integration — deploy + run the bundle
databricks auth login --host "$WS_URL" -p dbx-dev
cd ../../../bundle
databricks bundle validate -t dev
databricks bundle deploy   -t dev
databricks bundle run sample_ingest -t dev
```

## Offline checks (no cloud creds — safe anywhere)

```bash
terraform -chdir=terraform/live/10-infra    init -backend=false && terraform -chdir=terraform/live/10-infra    validate && terraform -chdir=terraform/live/10-infra    test
terraform -chdir=terraform/live/20-platform init -backend=false && terraform -chdir=terraform/live/20-platform validate && terraform -chdir=terraform/live/20-platform test
```

## CI/CD

- **PR** → `terraform fmt/validate/test` (mocked) + **resolve-deployment env test** +
  **`terraform plan`** (OIDC) + `bundle validate` (needs a live workspace).
- **Merge to `main`** → `terraform apply` then **`bundle deploy` + `sample_ingest` smoke test** (host/warehouse from Terraform outputs).
- **Bundle-only changes on `main`** → `bundle.yml` deploys from Terraform state.
- **Manual `deploy` workflow** → ephemeral sandbox from a slug (interview demos; no commits).
- **Manual `destroy` workflow** → demo/sandbox teardown (reverse deploy + optional state purge).
- **Catch-up** → Actions → **terraform** → Run workflow → check **bundle_only** if platform already exists.

**One-time platform setup** (Azure OIDC, GitHub secrets/variables, Cursor): [docs/DEMO-SETUP.md](docs/DEMO-SETUP.md).

**Greenfield client intake** (architecture proposals before implementation): [docs/architecture-proposals/README.md](docs/architecture-proposals/README.md).

See [docs/INTERVIEW.md](docs/INTERVIEW.md) for every best practice, *why* it's
there, and *where* it comes from.
