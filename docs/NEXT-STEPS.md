# Next steps — Option B (GitHub Actions + Azure OIDC) and Option C (Cursor cloud agent)

Hand-off notes to continue in a fresh session. Everything from the live test was
**torn down** — the Azure subscription is clean. The repo, its modules, and the CI
workflow skeletons are in place.

> **Start here:** [DEMO-SETUP.md](DEMO-SETUP.md) is the single checklist for
> one-time Azure + GitHub + Cursor setup, the interview demo script, and the
> caveat you give reviewers ("I configured this platform once; the repo stays a
> reusable template").

Fill in these placeholders from your environment:
- `<SUBSCRIPTION_ID>` — the personal Azure subscription used for testing
- `<TENANT_ID>` — its Entra tenant
- `<GH_REPO>` = `rexeven7/databricks-workspace-deploy`
- Globally-unique storage names for state + UC data

Prereqs each session: `az login --tenant <TENANT_ID>`, then
`az account set --subscription <SUBSCRIPTION_ID>`.

---

## Option B — GitHub Actions deploy via Azure OIDC (no stored secrets)

Goal: PR → offline validate + **cloud plan** (OIDC). Merge or **deploy** workflow →
`terraform apply` (layer 10 → 20) then `bundle deploy`, authenticated by
**federated OIDC**.

### Workflows (implemented)

| File | Role |
|---|---|
| `.github/workflows/terraform.yml` | PR gate + plan; apply on `main` |
| `.github/workflows/bundle.yml` | PR validate; prod deploy on `main` (OIDC) |
| `.github/workflows/deploy.yml` | **Interview sandbox** — `workflow_dispatch` + slug |
| `.github/workflows/destroy.yml` | **Demo teardown** — reverse deploy; optional state purge |
| `.github/scripts/resolve-deployment.sh` | Runtime names/state keys (keeps `main` generic) |

### B1–B8 bootstrap

Follow the copy-paste blocks in [DEMO-SETUP.md](DEMO-SETUP.md) (Entra app, Owner
role, federated credentials for `environment:production` **and** `pull_request`,
GitHub secrets, state storage with `use_azuread_auth=true`, Environment variables).

### B8. Verify

1. Open a PR → green `validate` + `plan-infra` / `plan-platform` (job summaries).
2. Actions → **deploy** → slug `smoketest01` → full stack.
3. Tear down sandbox (see DEMO-SETUP.md).
4. (Optional) set production Environment vars and merge to `main`.

---

## Option C — Cursor cloud agent

Goal: agent **authors + babysits PRs**; CI **plans and applies** (no secrets in Cursor).

### C1. ai-dev-kit skills

```powershell
irm https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/install.ps1 -OutFile install.ps1
.\install.ps1 --tools cursor --skills-only
```

### C2. Cloud agent environment

`.cursor/environment.json` is committed (Terraform 1.9.8 + Databricks CLI).

### C3–C4. Secrets

**Default:** do not put cloud credentials in Cursor — CI applies via OIDC.

**Optional demo bootstrap:** [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) — temporary
`BOOTSTRAP_*` + `GH_TOKEN` in Cursor Secrets; agent runs `scripts/bootstrap-platform.sh`.
Delete bootstrap secrets after; CI OIDC deploys ongoing.

### C5. Run it

**Greenfield client (full stack):**

> New client Hike2 — dev and prod, full medallion with SDP, metric view, AI/BI
> dashboard, and Genie. Propose architecture per best practices, save to
> `docs/architecture-proposals/`, ask what you need, then open a proposal-only PR
> before any Terraform or bundle code.

Architecture proposals: [docs/architecture-proposals/README.md](architecture-proposals/README.md)

**Small change:**

> We're demoing for a client in eastus2. Add a note to INTERVIEW.md on Liquid
> Clustering trade-offs, run offline Terraform tests, open a PR, and summarize
> what the CI terraform plan will change.

After green CI: user runs **deploy** workflow or merges to `main`.

---

## Production use (future) — repo per client

This template repo stays **neutral** for interviews and demos (slugs, GitHub
Environment vars, architecture proposals — no client names on `main`). For real
client engagements, prefer a **dedicated repo per client** forked from this template.

### Why

| Template repo (demo) | Client repo (production) |
|---|---|
| Agent must not commit `dbw-meridian-dev` to `main` | Client names belong in that repo |
| Isolation via `deployment_slug` + env vars | Isolation via repo boundary + handoff |
| One OIDC federated credential | One federated credential per repo (same Entra app is fine) |

**Shared Terraform state storage is still OK** — use one storage account and
container (`rg-tfstate` / `tfstate`), with **per-client state keys**, e.g.:

```text
databricks/meridian/10-infra.tfstate
databricks/meridian/20-platform.tfstate
```

Extend `resolve-deployment.sh` (or committed backend config in the client repo) to
use that key prefix; no need for a state account per client.

### Agent workflow (sketch)

1. `gh repo create <org>/meridian-databricks --template <this-repo> --private`
2. Bootstrap that repo: `AZURE_*` secrets, `production` environment variables,
   Entra federated credential with subject
   `repo:<org>/meridian-databricks:environment:production` (and `pull_request` if
   planning on PRs).
3. Connect Cursor Cloud Agent to **the client repo** (not the template).
4. Intake → `docs/architecture-proposals/meridian-….md` → implementation PRs in
   that repo only.
5. CI apply/destroy on that repo; template repo unchanged.

### When to stay on the template repo

- Interview demos, quick pilots → **deploy** workflow + slug (no new repo).
- Public showcase of patterns → keep generic `main` here.

### Not started yet

- `docs/CLIENT-REPO-BOOTSTRAP.md` with copy-paste `gh` + `az` commands
- Template flag on GitHub repo settings
- Agent skill step for repo spawn + OIDC registration

---

## Quick reference

- **Demo checklist:** [DEMO-SETUP.md](DEMO-SETUP.md)
- **Agent rules:** [AGENTS.md](../AGENTS.md)
- Re-deploy locally: `docs/INTERVIEW.md` §4
- Gotchas: `docs/INTERVIEW.md` §7
- Architecture: `README.md`
