# Client repo GO flow (Cursor → new repo → deploy)

This is the flow you want: **talk in Cursor on the template repo**, review the
architecture proposal, say **GO**, and the agent **creates a new GitHub repo**,
wires OIDC/federation, and **deploys from that repo** — without polluting the
template with client names.

```text
┌──────────────────────────────────────────────────────────────────┐
│  TEMPLATE REPO (this repo) — Cursor control plane                │
│  · Intake conversation + architecture proposal                     │
│  · Standing operator secrets (BOOTSTRAP_*, GH_TOKEN)               │
│  · Agent runs spawn-client-repo.sh on GO — nothing client-specific │
│    committed to template main                                      │
└────────────────────────────┬─────────────────────────────────────┘
                             │ GO
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  CLIENT REPO (new) — e.g. org/meridian-databricks                │
│  · Created from GitHub template                                    │
│  · Proposal + CLIENT.md + state keys committed HERE                │
│  · GitHub secrets + OIDC federated creds for THIS repo             │
│  · deploy workflow → Azure stack for this client                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites (one-time)

### 1. Mark this repo as a GitHub template

GitHub → **Settings** → check **Template repository**.

### 2. Operator service principal (persistent in Cursor)

Run once on your laptop (subscription Owner):

```bash
az login
bash scripts/create-operator-sp.sh
```

Copy all four `BOOTSTRAP_AZURE_*` values into Cursor **Runtime Secrets**. Keep them
for every client — do not delete after each GO.

Details: [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) Step 0–1.

### 3. Cursor Cloud secrets (template repo environment)

**Runtime Secrets**

| Name | Purpose |
|------|---------|
| `BOOTSTRAP_AZURE_CLIENT_ID` | Operator SP |
| `BOOTSTRAP_AZURE_CLIENT_SECRET` | Operator SP secret |
| `BOOTSTRAP_AZURE_TENANT_ID` | Entra tenant |
| `BOOTSTRAP_AZURE_SUBSCRIPTION_ID` | Demo subscription |
| `GH_TOKEN` | Create repos, set secrets, dispatch workflows |

**Environment variables**

| Name | Example | Purpose |
|------|---------|---------|
| `GH_TEMPLATE_REPO` | `youruser/databricks-workspace-deploy` | This template |
| `STATE_STORAGE_ACCOUNT_NAME` | `sttfdbxyourname01` | Shared state SA across clients |
| `AZURE_LOCATION` | `eastus2` | Optional |

`GH_TOKEN` needs: **repo** (admin), **workflow**, ability to **create repos from template**.

---

## Conversation flow (what you do in Cursor web)

### Copy-paste prompts

**Intake (no deploy, no PR):**

> New client `<name>` — propose architecture (medallion / SDP / whatever scope).
> Ask questions first. Do **not** open a PR on this template repo.

**After you approve the proposal:**

> **GO** — slug `<slug>`, spawn the client repo and deploy.

The agent must run `spawn-client-repo.sh`, **not** open a PR.

### Phase 1 — Intake (no deploy, no PR)

Open the **template** repo in Cursor Cloud Agent. Example prompt:

> New client Meridian — dev and prod medallion with SDP, metric view, dashboard,
> and Genie. Propose architecture per best practices. Ask what you need before
> implementing.

The agent follows `.cursor/skills/databricks-client-intake/SKILL.md`:

- Asks clarifying questions
- Shows architecture (matrix, mermaid, phased PRs)
- Writes `docs/architecture-proposals/<slug>.md` **locally** (not a template PR)

Iterate until you approve.

### Phase 2 — GO (repo + deploy — not a PR)

When ready:

> **GO** — spawn client repo for Meridian, slug `meridian`, deploy the stack.

The agent runs:

```bash
export CLIENT_SLUG=meridian
export PROPOSAL_FILE=docs/architecture-proposals/meridian-medallion-full-stack.md
bash scripts/spawn-client-validate-env.sh
bash scripts/spawn-client-repo.sh
```

### What spawn does automatically

1. **`gh repo create`** `org/meridian-databricks` from `GH_TEMPLATE_REPO`
2. **Seeds** the client repo: proposal copy, `CLIENT.md`, Terraform state keys under `databricks/meridian/`
3. **Bootstraps** that repo: `AZURE_*` secrets, `production` env vars, **new OIDC federated credentials** on the shared CI Entra app (one credential pair per repo)
4. **Dispatches** `deploy` workflow on the **client repo** with slug `meridian`
5. GitHub Actions applies Terraform + bundle — agent never runs `terraform apply`

### Phase 3 — After deploy

- Watch **client repo** Actions → deploy
- Connect Cursor Cloud Agent to **`meridian-databricks`** for implementation PRs (SDP, dashboards, etc.)
- Template repo stays clean

---

## Safety rules

| Rule | Why |
|------|-----|
| Template `main` stays generic | Interview/showcase repo; no `meridian` in committed tfvars |
| Client names only in **client repo** | Boundary matches real engagements |
| Operator SP in Cursor; CI SP in GitHub | Agent configures; GHA applies |
| Shared state **account**, per-client **keys** | `databricks/meridian/10-infra.tfstate` |
| Demo subscription only | Operator has Owner |
| Destroy from **client repo** | `destroy` workflow on that repo |

---

## Agent prompt cheat sheet

**Intake only**

> Propose architecture for client X — questions first, no deploy.

**GO**

> GO — spawn repo for client X, slug `<slug>`, use proposal at `docs/architecture-proposals/<file>.md`.

**Implementation (after spawn, on client repo)**

> Implement PR 2 from the approved proposal — SDP bronze/silver/gold skeleton.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| **Agent opened a PR instead of spawning** | Say **GO** explicitly; push latest `main` (skills + `AGENTS.md`); prompt: "do not open a PR — run spawn-client-repo.sh" |
| `Template not found` | Enable **Template repository** on this repo |
| `Resource not accessible` | `GH_TOKEN` needs repo create + admin on org/user |
| Federated credential limit | Entra apps allow many federated creds; names are per-repo |
| Storage account name conflict on deploy | Slug drives `stdbx<slug>` — pick a different slug |
| Repo already exists | Script re-bootstraps and can re-dispatch deploy |

---

## Related

- [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) — operator SP + shared state (lower-level)
- [DEMO-SETUP.md](DEMO-SETUP.md) — manual checklist
- `.cursor/skills/databricks-client-intake/SKILL.md` — intake + GO handoff
- `.cursor/skills/client-repo-go/SKILL.md` — agent steps for GO
