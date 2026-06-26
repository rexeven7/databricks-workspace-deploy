---
name: databricks-client-intake
description: >-
  Greenfield Databricks client engagement intake: parse a natural-language request,
  apply ai-dev-kit and repo best practices, propose Terraform vs DAB architecture,
  ask structured clarifying questions, then plan phased PRs (no cloud apply).
  Use when the user mentions a new client, workspace setup, dev/prod environments,
  medallion architecture, SDP/LDP, metric views, AI/BI dashboards, Genie spaces,
  or "propose architecture" before implementation.
---

# Databricks client intake (Option C)

Orchestrate **conversation → architecture → questions → phased PRs**. The cloud agent
authors PRs; GitHub Actions applies via OIDC. See `AGENTS.md` and `docs/DEMO-SETUP.md`.

## Phase 0 — Do not code yet

On a request like *"Set up Databricks for client Hike2, dev + prod, full medallion
with SDP, metric view, dashboard, and Genie"*:

1. **Acknowledge scope** in one paragraph (platform + pipelines + consumption layer).
2. **Read** (before proposing):
   - `docs/INTERVIEW.md` — platform vs application split
   - `AGENTS.md` — agent boundaries
   - `.cursor/skills/databricks-bundles/SKILL.md`
   - `.cursor/skills/databricks-spark-declarative-pipelines/SKILL.md`
   - `.cursor/skills/databricks-metric-views/SKILL.md`
   - `.cursor/skills/databricks-dbsql/SKILL.md` (Liquid Clustering, managed tables)
3. **Do not** edit tfvars with client-specific names on `main`, run `terraform apply`,
   or `bundle deploy` unless the user explicitly overrides for a local session.

## Phase 1 — Architecture proposal (required output)

Produce a **Proposed architecture** section with:

### 1.1 Responsibility matrix (Terraform vs DAB)

| Concern | Terraform (slow, privileged) | DAB (fast, app-centric) |
|---------|------------------------------|-------------------------|
| Azure RG, workspace(s), UC metastore binding | ✓ | |
| Catalogs, schemas, volumes, external locations, grants | ✓ | optional overlap — prefer TF for platform |
| SQL warehouse(s), storage credentials | ✓ | |
| Bronze / silver / gold **tables** (ongoing) | bootstrap only | ✓ SDP pipelines |
| Ingestion & transforms | | ✓ SDP + jobs |
| Metric views | | ✓ SQL job task (`WITH METRICS LANGUAGE YAML`) — no native DAB resource |
| AI/BI dashboards | | ✓ `dashboards:` + `.lvdash.json` |
| Genie spaces | | ✓ `genie_spaces:` + `.geniespace.json` (CLI 1.3+, `engine: direct`) |
| SQL alerts, quality monitors | | ✓ DAB resources |
| CI smoke tests | | ✓ `bundle run` after deploy |

### 1.2 Reference topology (adapt per client)

```text
Azure subscription(s)
├── Terraform state (shared RG + storage account)
├── dev:  rg-hike2-dev  → dbw-hike2-dev  → UC catalog hike2_dev  (bronze/silver/gold schemas)
├── prod: rg-hike2-prod → dbw-hike2-prod → UC catalog hike2_prod (bronze/silver/gold schemas)
└── GitHub: OIDC → plan on PR, apply on merge / deploy workflow + slug sandboxes

Bundle (per repo or mono-repo bundle/)
├── pipelines: bronze_ingest → silver_clean → gold_curated   (SDP, serverless)
├── jobs: metric_view_ddl, optional backfill
├── metric views: gold KPIs (SQL task)
├── dashboards: executive.lvdash.json
└── genie_spaces: analyst.geniespace.json (over gold / metric views)
```

### 1.3 Mermaid (include in proposal)

```mermaid
flowchart TB
  subgraph TF["Terraform — platform"]
    WS[Workspaces dev + prod]
    UC[UC catalogs schemas volumes grants]
    WH[Serverless SQL warehouses]
  end
  subgraph DAB["DAB — application"]
    SDP[Bronze → Silver → Gold SDP]
    MV[Metric views SQL job]
    DASH[AI/BI Dashboard]
    GEN[Genie space]
  end
  subgraph CI["GitHub Actions OIDC"]
    PLAN[PR plan + bundle validate]
    APPLY[Apply TF then bundle deploy + smoke run]
  end
  TF --> DAB
  CI --> TF
  CI --> DAB
  SDP --> MV
  MV --> DASH
  MV --> GEN
```

### 1.4 Best-practice callouts (cite ai-dev-kit)

Always mention applicable practices from `docs/INTERVIEW.md` §2, e.g.:

- Two Terraform layers + separate state (10-infra / 20-platform)
- Catalog = environment boundary; schema = domain (bronze/silver/gold or sales)
- Serverless SDP + serverless SQL warehouse
- Managed Delta + Liquid Clustering on gold
- Bundle variables for catalog / schema / warehouse_id across targets
- OIDC in CI, no long-lived secrets
- Genie requires **direct** bundle engine (note CI CLI version implication)

### 1.5 Phased delivery plan (PR slices)

Never one giant PR. Propose order:

| PR | Contents | Risk |
|----|----------|------|
| 1 | Terraform: dual workspace/module params, env resolution for `hike2` | Medium — infra |
| 2 | SDP pipeline skeleton (bronze/silver/gold) + synthetic/demo source | Low — bundle only |
| 3 | Gold table contract + metric view SQL job | Low |
| 4 | Dashboard + Genie (direct engine if needed) | Low — needs warehouse_id vars |
| 5 | CI: extend smoke test (`bundle run` pipeline or job chain) | Low |
| 6 | Docs: client runbook (GitHub Environment vars, not committed secrets) | Low |

## Phase 2 — Clarifying questions (required)

Use **AskQuestion** when available; otherwise numbered list. Group by theme.
**Do not implement until must-have questions are answered** (or user says "use defaults for demo").

### Must-have (block architecture)

1. **Workspace topology**: Two physical workspaces (dev + prod) vs one workspace with dev/prod **catalogs**? (Cost vs isolation trade-off.)
2. **Azure**: Region(s), one subscription or dev/prod subscriptions?
3. **Identity**: Entra groups for admins vs engineers (`account users` ok for demo only?)
4. **GitHub**: Repo strategy — fork this template vs new repo; OIDC bootstrap done or agent documents DEMO-SETUP?
5. **Naming**: Client slug for state keys and resources (e.g. `hike2` → `dbw-hike2-dev`, storage account uniqueness).

### Should-have (shape the medallion demo)

6. **Data source**: Built-in `samples.*`, synthetic (Faker), or client file landing zone?
7. **Domain**: Generic retail/sales vs client-specific entity names?
8. **SDP scope**: Batch medallion only, or include streaming table / CDC example?
9. **Gold metrics**: Which KPIs for the metric view (counts, revenue, ratios)?
10. **Dashboard audience**: Executive summary vs analyst exploration?

### Nice-to-have (consumption layer)

11. **Genie**: Instructions / sample questions — generate from UI template or greenfield JSON?
12. **Alerts**: SQL alert on pipeline freshness or row-count anomaly?
13. **CI**: Run full SDP on every deploy or notebook smoke test only (cost/time)?

### Defaults when user says "demo / interview"

- Region: `eastus2`
- Two catalogs on **one** prod workspace + sandbox slug for throwaway (matches this repo)
- `account users` for grants
- `samples.nyctaxi.trips` or synthetic sales data
- Serverless everywhere
- Metric view: order/trip count + revenue measures
- Genie over gold table + metric view

## Phase 3 — After approval

1. Summarize **decisions** in PR description (architecture appendix).
2. Implement **one PR slice** at a time; run offline Terraform tests per `AGENTS.md`.
3. Open PR with test plan referencing CI jobs (`terraform plan`, `bundle validate`).
4. Babysit until green; tell user to merge or run `deploy` workflow with slug.

## Example opener (Hike2)

> **Proposed architecture for Hike2** — dual-catalog medallion on shared Azure footprint,
> Terraform for workspaces/UC/warehouses, DAB for SDP + metric view + dashboard + Genie.
> Five PRs suggested. Before PR 1, please confirm: (1) two workspaces vs two catalogs,
> (2) region, (3) GitHub repo/OIDC status.

## Anti-patterns

| Do not | Do instead |
|--------|------------|
| Commit `hike2` storage account names to `main` | GitHub Environment vars or slug in `resolve-deployment.sh` |
| Put metric views in Terraform | SQL job in bundle |
| Deploy Genie on legacy TF bundle engine | `engine: direct` + CLI 1.3+ |
| Single PR for TF + SDP + Genie | Phased PRs per table above |
| Skip smoke test | `bundle run` after deploy in CI |

## Related skills

Invoke as needed during implementation:

- `databricks-bundles`, `databricks-spark-declarative-pipelines`
- `databricks-metric-views`, `databricks-dbsql`, `databricks-jobs`
- `databricks-unity-catalog`, `databricks-config`
