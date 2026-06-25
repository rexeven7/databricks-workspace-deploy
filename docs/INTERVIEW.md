# Interview crib sheet

Everything in this repo, *why* it's there, and *where the practice comes from* —
so you can defend each decision out loud.

---

## 1. The 30-second opener

> "I separate the platform from the application. **Terraform** owns the
> infrastructure and governance — the workspace, Unity Catalog, the SQL
> warehouse, the grants — because that's stateful, privileged, and slow-moving.
> **Databricks Asset Bundles** own the code — jobs, notebooks, pipelines —
> because that ships with the app and changes fast. I used the **ai-dev-kit** to
> author both with Databricks' own codified best practices. Everything is
> parameterized per environment and runs through GitHub Actions with OIDC, so
> there are no long-lived secrets."

If they say *"just do it all in Terraform"* → bundles generate Terraform under
the hood anyway, but they give developers a code-centric workflow, dev-mode
isolation, and `bundle run`; pushing notebooks through raw Terraform couples app
deploys to infra state and privileges. The split is deliberate.

---

## 2. Best practices → why → source

| Practice | Why | Where it comes from |
|---|---|---|
| **Two layers / two state files** (10-infra, 20-platform) | Different blast radius & credentials; layer 20 reads layer 10's *applied* output so the `databricks` provider gets a known `workspace_id` — no same-apply chicken-and-egg | Databricks/HashiCorp guidance on provider config; classic Azure Databricks gotcha |
| **`modules/` vs `live/`** | Reusable logic separated from thin per-env composition | [HashiCorp standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure) |
| **Partial backend + `-var-file` per env** | One root per layer serves all envs → dev and prod run *identical* code, no drift | [Terraform partial backend config](https://developer.hashicorp.com/terraform/language/backend#partial-configuration) |
| **Remote state in Azure Blob (locking)** | Shared, off-laptop, lease-based locking; "free Terraform" (no paid Cloud) | [azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm) |
| **Pinned provider versions** (`~>`) | Reproducible plans across the team & CI | [Provider version constraints](https://developer.hashicorp.com/terraform/language/providers/requirements#version-constraints) |
| **`terraform test` with `mock_provider` / `override_data`** | Unit-test config offline, with zero cloud creds, on every PR | Databricks "Terraform provider" guide → *Testing*; [TF test docs](https://developer.hashicorp.com/terraform/language/tests) |
| **OIDC auth in CI** (`ARM_USE_OIDC`) | Federated identity → no client secrets stored in GitHub | [Azure OIDC + GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect) |
| **plan on PR, apply on merge (protected env)** | Human review gate before any infra mutation | GitHub Environments + Terraform CI convention |
| **premium workspace SKU** | Unity Catalog, RBAC, serverless SQL all require it | Azure Databricks tiers |
| **Catalog = environment, schema = domain** | Clean isolation + governance boundary | ai-dev-kit `databricks-dbsql` skill |
| **`isolation_mode = ISOLATED` catalog** | Catalog bound only to workspaces you grant, not the whole metastore | Unity Catalog binding |
| **Least-privilege grants; `READ_VOLUME`/`WRITE_VOLUME`** | Engineers get day-to-day rights, admins own the catalog; volume privileges differ from table privileges | ai-dev-kit `databricks-unity-catalog` / `databricks-bundles` skills |
| **Serverless SQL warehouse, low auto-stop** | Sub-minute start, IWM, Photon+PQE on by default, pay-only-while-running | ai-dev-kit `databricks-dbsql` skill |
| **Bundle `variables` for catalog/schema/warehouse** | Same code → dev & prod unchanged | ai-dev-kit `databricks-bundles` skill |
| **`mode: development` vs `production`** | Dev isolates & prefixes per-user and pauses schedules; prod is shared/strict | ai-dev-kit `databricks-bundles` skill |
| **Serverless job (no cluster block)** | No cluster to size or pay for idle; fastest path | ai-dev-kit `databricks-jobs` skill |
| **Managed table + Liquid Clustering + `CREATE OR REPLACE`** | Replaces partitioning/Z-ORDER; preserves time travel; predictive optimization | ai-dev-kit `databricks-dbsql` skill |
| **`DECIMAL` for money, `ANALYZE TABLE`, `COMMENT`** | Precision, better query plans, discoverability for AI/BI | ai-dev-kit `databricks-dbsql` skill |

---

## 3. Likely questions & crisp answers

**Q: How do you handle multiple environments?**
A: One root module per layer; environment is selected at init/apply via
`-backend-config=env/<env>.backend.hcl` and `-var-file=env/<env>.tfvars`. Dev and
prod execute the same code — only inputs and the state key differ. Trade-off vs.
separate `dev/`/`prod/` directories: less duplication, but you must be disciplined
about which var-file you pass (CI pins it per job).

**Q: Why two state files instead of one config?**
A: Blast radius and the provider chicken-and-egg. The `databricks` provider needs
the workspace URL/ID; if that resource is created in the same apply, the provider
can't be configured at plan time. Splitting infra from platform means layer 20
reads layer 10's *already-applied* state, so `workspace_id` is known. It also lets
a cloud-admin own layer 10 and a workspace-admin own layer 20.

**Q: How is state locked?**
A: The azurerm backend takes a **blob lease** automatically on write — concurrent
applies are blocked. State also lives off the laptop and is versioned in the
storage account.

**Q: Secrets?**
A: None stored. CI uses Azure **OIDC** federation (`ARM_USE_OIDC=true`,
client/tenant/subscription IDs as non-secret vars); the Databricks provider
exchanges Azure AD tokens for Databricks tokens. The bundle uses an OAuth M2M
service principal.

**Q: How do you test infra without spending money?**
A: `terraform test` with `mock_provider` (and `override_data` to stub the
remote-state lookup). It validates logic and assertions with **no credentials and
no resources created** — that's the PR gate.

**Q: Terraform vs. Asset Bundles — when each?**
A: Terraform for anything stateful/governed/cross-service (workspace, UC, grants,
warehouses, network). Bundles for code artifacts (jobs, pipelines, notebooks,
dashboards) that version with the application.

**Q: Why is the warehouse serverless?**
A: Fastest start, auto-scale/auto-stop so idle cost is ~zero, and all 2025 engine
optimizations (PQE, Photon vectorized shuffle) are on automatically. Per Databricks'
own guidance, serverless is the default for most workloads.

**Q: Why Liquid Clustering instead of partitioning?**
A: It's Databricks' default recommendation for all new tables — change keys
anytime, incremental maintenance, and it replaces both partitioning and Z-ORDER.
Partitioning only wins for very large tables with a stable low-cardinality key.

---

## 4. Live-demo runbook

```bash
az login

# Layer 10
cd terraform/live/10-infra
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars      # ~5-10 min for the workspace

# Layer 20
cd ../20-platform
terraform init -backend-config=env/dev.backend.hcl
terraform apply -var-file=env/dev.tfvars

# Integration
databricks auth login --host "$(terraform -chdir=../10-infra output -raw workspace_url)" -p dbx-dev
cd ../../../bundle
databricks bundle validate -t dev
databricks bundle deploy   -t dev
databricks bundle run sample_ingest -t dev
```

**If they don't give you cloud creds**, run the offline path and talk through it:

```bash
terraform -chdir=terraform/live/10-infra    init -backend=false && terraform -chdir=terraform/live/10-infra    test
terraform -chdir=terraform/live/20-platform init -backend=false && terraform -chdir=terraform/live/20-platform test
cd bundle && databricks bundle validate -t dev
```

---

## 5. Known gotchas (mention before they ask — shows maturity)

- **Metastore**: this repo creates the catalog downward; a UC metastore must
  already be assigned to the region (platform-team responsibility). I'd manage
  that in a separate account-level Terraform config using the account provider.
- **`storage_account_name`** for state is globally unique — change it before first init.
- **Bundle `profile`** names (`dbx-dev`/`dbx-prod`) must exist via `databricks auth login`.
- **`warehouse_id`** is wired by hand here; in a fuller setup I'd source it from the
  layer-20 output (or a `lookup`) so the bundle never hardcodes an id.
- **Custom groups** (`data-engineers`, `data-platform-admins`) must exist in the
  account/workspace; you can't grant the `admins` group on jobs.

---

## 6. How the ai-dev-kit fits

It's **not** an IaC tool — it's the AI dev environment. The installer drops
Databricks **skills** (20 best-practice playbooks) and an **MCP server** (75+
tools) into the repo, so Claude Code / Cursor can author and operate Databricks
resources with Databricks' own conventions. In this repo it shaped the bundle
structure, the job/notebook patterns, and the Unity Catalog / Delta best practices
cited above.

---

## 7. Proven on Azure — real-world findings

This was deployed and verified on a live Azure subscription (workspace → UC →
serverless warehouse → bundle job → 21,856-row managed, liquid-clustered table).
Three snags came up that are worth being able to speak to:

1. **UC Default Storage** — on newer accounts the metastore has no storage root, so
   `CREATE CATALOG` fails unless you give it a **managed location**. The fix (and the
   production-correct pattern) is bring-your-own-storage: an Azure **access connector**
   (managed identity) → **Storage Blob Data Contributor** on an ADLS Gen2 container →
   a UC **storage credential** + **external location** → the catalog's `storage_root`
   points beneath it. That's the `uc_storage` module + the external location in
   `unity_catalog`.

2. **Warehouse ACLs vs UC grants use different identity planes.** SQL warehouse
   permissions take **workspace** groups (`users`), but Unity Catalog grants require
   **account-level** principals (`account users`, or an account group / user) —
   workspace-local groups are rejected. The repo decouples these (`warehouse_user_group`
   vs `data_engineer_group`).

3. **The access connector's role assignment must propagate** before UC validates the
   external location. Splitting infra (layer 10) from platform (layer 20) gives that a
   natural gap; if you ever apply too fast, just re-apply.

**Auth that worked, with zero secrets:** `az login` → the `azurerm` provider, the
`databricks` provider (`azure_workspace_resource_id` + Azure CLI), and the bundle
profile (`azure_workspace_resource_id`) all authenticate off the same Azure AD login.
