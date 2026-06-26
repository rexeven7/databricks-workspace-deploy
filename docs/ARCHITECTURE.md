# Architecture & design rationale

Why this repo is structured the way it is — platform vs application, layers, CI,
and operational lessons from live Azure deployments.

---

## 1. Elevator summary

> Separate **platform** from **application**. **Terraform** owns infrastructure
> and governance — workspace, Unity Catalog, SQL warehouse, grants — because that
> is stateful, privileged, and slow-moving. **Databricks Asset Bundles** own
> jobs, notebooks, and pipelines because they ship with the app and change fast.
> The **ai-dev-kit** skills encode Databricks' own best practices. Everything is
> parameterized per environment and runs through GitHub Actions with OIDC — no
> long-lived secrets in CI.

**Terraform-only pushback:** bundles generate Terraform under the hood, but they
give developers a code-centric workflow, dev-mode isolation, and `bundle run`.
Pushing notebooks through raw Terraform couples app deploys to infra state and
privileges. The split is deliberate.

---

## 2. Best practices → why → source

| Practice | Why | Where it comes from |
|---|---|---|
| **Two layers / two state files** (10-infra, 20-platform) | Different blast radius & credentials; layer 20 reads layer 10's *applied* output so the `databricks` provider gets a known `workspace_id` — no same-apply chicken-and-egg | Databricks/HashiCorp guidance on provider config; classic Azure Databricks gotcha |
| **`modules/` vs `live/`** | Reusable logic separated from thin per-env composition | [HashiCorp standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure) |
| **Partial backend + `-var-file` per env** | One root per layer serves all envs → dev and prod run *identical* code, no drift | [Terraform partial backend config](https://developer.hashicorp.com/terraform/language/backend#partial-configuration) |
| **Remote state in Azure Blob (locking)** | Shared, off-laptop, lease-based locking | [azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm) |
| **Pinned provider versions** (`~>`) | Reproducible plans across the team & CI | [Provider version constraints](https://developer.hashicorp.com/terraform/language/providers/requirements#version-constraints) |
| **`terraform test` with `mock_provider` / `override_data`** | Unit-test config offline, with zero cloud creds, on every PR | Databricks Terraform provider → *Testing*; [TF test docs](https://developer.hashicorp.com/terraform/language/tests) |
| **OIDC auth in CI** (`ARM_USE_OIDC`) | Federated identity → no client secrets stored in GitHub | [Azure OIDC + GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect) |
| **plan on PR, apply on merge (protected env)** | Human review gate before any infra mutation | GitHub Environments + Terraform CI convention |
| **premium workspace SKU** | Unity Catalog, RBAC, serverless SQL all require it | Azure Databricks tiers |
| **Catalog = environment, schema = domain** | Clean isolation + governance boundary | ai-dev-kit `databricks-dbsql` skill |
| **`isolation_mode = ISOLATED` catalog** | Catalog bound only to workspaces you grant, not the whole metastore | Unity Catalog binding |
| **Least-privilege grants; `READ_VOLUME`/`WRITE_VOLUME`** | Engineers get day-to-day rights, admins own the catalog | ai-dev-kit `databricks-unity-catalog` / `databricks-bundles` skills |
| **Serverless SQL warehouse, low auto-stop** | Sub-minute start, pay-only-while-running | ai-dev-kit `databricks-dbsql` skill |
| **Bundle `variables` for catalog/schema/warehouse** | Same code → dev & prod unchanged | ai-dev-kit `databricks-bundles` skill |
| **`mode: development` vs `production`** | Dev isolates & prefixes per-user; prod is shared/strict | ai-dev-kit `databricks-bundles` skill |
| **Serverless job (no cluster block)** | No cluster to size or pay for idle | ai-dev-kit `databricks-jobs` skill |
| **Managed table + Liquid Clustering + `CREATE OR REPLACE`** | Replaces partitioning/Z-ORDER; preserves time travel | ai-dev-kit `databricks-dbsql` skill |
| **`DECIMAL` for money, `ANALYZE TABLE`, `COMMENT`** | Precision, better query plans, discoverability for AI/BI | ai-dev-kit `databricks-dbsql` skill |

---

## 3. FAQ-style design answers

**How do you handle multiple environments?**
One root module per layer; environment is selected at init/apply via
`-backend-config=env/<env>.backend.hcl` and `-var-file=env/<env>.tfvars`. Dev and
prod execute the same code — only inputs and the state key differ.

**Why two state files instead of one config?**
Blast radius and the provider chicken-and-egg. Layer 20 reads layer 10's
*already-applied* state so `workspace_id` is known at plan time.

**How is state locked?**
The azurerm backend takes a **blob lease** on write — concurrent applies are blocked.

**Secrets?**
CI uses Azure **OIDC** (`ARM_USE_OIDC=true`). The bundle uses OAuth M2M or
`DATABRICKS_AUTH_TYPE=azure-cli` after workspace exists.

**How do you test infra without cloud creds?**
`terraform test` with `mock_provider` and `override_data` — the PR gate.

**Terraform vs. Asset Bundles — when each?**
Terraform for workspace, UC, grants, warehouses. Bundles for jobs, pipelines,
notebooks, dashboards.

---

## 4. Local deploy runbook

```bash
az login

# Layer 10
cd terraform/live/10-infra
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars

# Layer 20
cd ../20-platform
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars

# Bundle
databricks auth login --host "$(terraform -chdir=../10-infra output -raw workspace_url)" -p dbx-dev
cd ../../../bundle
databricks bundle validate -t dev
databricks bundle deploy   -t dev
databricks bundle run sample_ingest -t dev
```

**Offline path (no cloud creds):**

```bash
terraform -chdir=terraform/live/10-infra    init -backend=false && terraform -chdir=terraform/live/10-infra    test
terraform -chdir=terraform/live/20-platform init -backend=false && terraform -chdir=terraform/live/20-platform test
cd bundle && databricks bundle validate -t dev
```

---

## 5. Known gotchas

- **Metastore**: a UC metastore must already be assigned to the region. Account-level
  metastore management belongs in a separate Terraform config with the account provider.
- **`storage_account_name`** for state is globally unique — set yours before first init.
- **Bundle `profile`** names (`dbx-dev`/`dbx-prod`) must exist via `databricks auth login`.
- **`warehouse_id`**: prefer sourcing from layer-20 Terraform output so the bundle
  never hardcodes an id.
- **Custom groups** must exist in the account/workspace before UC grants reference them.

---

## 6. ai-dev-kit role

Not an IaC tool — it installs Databricks **skills** (best-practice playbooks) and
an **MCP server** into the repo so Cursor / Claude can author resources with
Databricks conventions. It shaped bundle structure, job/notebook patterns, and UC
/Delta practices cited above.

---

## 7. Operational notes (live Azure)

Patterns validated on Azure (workspace → UC → serverless warehouse → bundle job →
managed Delta table):

1. **UC Default Storage** — when the metastore has no storage root, catalogs need a
   **managed location**. Production pattern: access connector → Storage Blob Data
   Contributor on ADLS → UC storage credential + external location → catalog
   `storage_root` (`uc_storage` + `unity_catalog` modules).

2. **Warehouse ACLs vs UC grants** — warehouse permissions use **workspace** groups;
   UC grants need **account-level** principals (`account users`). The repo decouples
   `warehouse_user_group` vs `data_engineer_group`.

3. **Access connector RBAC propagation** — role assignment must propagate before UC
   validates the external location. The two-layer apply gives a natural gap; re-apply
   if validation races.

**Auth without stored secrets:** `az login` → `azurerm` provider, `databricks`
provider (`azure_workspace_resource_id`), and bundle profile share the same Azure AD
session.
