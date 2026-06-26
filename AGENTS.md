# AGENTS.md

## Cursor Cloud — pick the right mode first

| User intent | Repo | Agent action | **Do not** |
|-------------|------|--------------|------------|
| **New client / greenfield** ("set up X", medallion, dev+prod) | **This template** | Intake in **chat** → proposal file in **working tree only** → on **GO** run `spawn-client-repo.sh` | Open a PR on this repo; commit client names to `main` |
| **GO / deploy / create the repo** | **This template** | `.cursor/skills/client-repo-go/SKILL.md` → `scripts/spawn-client-repo.sh` | Open a PR; `terraform apply` |
| **Change template code/docs** | This template | Offline tests → **PR** on this repo | Client-specific tfvars on `main` |
| **Build SDP/dashboards after spawn** | **Client repo** (e.g. `acme-databricks`) | PRs on **that** repo | Work on template repo |

**Greenfield deliverable is a new GitHub repo + deploy workflow run — not a PR here.**

Operator secrets (`BOOTSTRAP_*`, `GH_TOKEN`, `GH_TEMPLATE_REPO`) → [CLIENT-REPO-BOOTSTRAP.md](docs/CLIENT-REPO-BOOTSTRAP.md).

---

## What this repo ships

- **Terraform** (`terraform/`) — workspace, Unity Catalog, serverless SQL warehouse (`10-infra` / `20-platform`). See [ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Databricks Asset Bundle** (`bundle/`) — serverless job + notebook.

---

## Mode A — Greenfield client (template repo)

1. Follow `.cursor/skills/databricks-client-intake/SKILL.md` — questions, architecture in chat, draft proposal under `docs/architecture-proposals/` **locally** (do **not** push a PR to template `main` unless user explicitly asks to add a generic *example* only).
2. When user says **GO** (or "create the repo", "deploy it", "spin it up", "looks good ship it"):
   - Follow `.cursor/skills/client-repo-go/SKILL.md`
   - Run `scripts/spawn-client-validate-env.sh` and `scripts/spawn-client-repo.sh`
   - Report new repo URL + Actions link
3. Tell user to **reconnect Cursor to the client repo** for implementation PRs.

## Mode B — Template maintenance (this repo only)

1. Gather parameters in conversation.
2. Edit Terraform / bundle / docs.
3. Offline checks:

```bash
terraform fmt -check -recursive terraform/
terraform -chdir=terraform/live/10-infra    init -backend=false && terraform -chdir=terraform/live/10-infra    validate && terraform -chdir=terraform/live/10-infra    test
terraform -chdir=terraform/live/20-platform init -backend=false && terraform -chdir=terraform/live/20-platform validate && terraform -chdir=terraform/live/20-platform test
```

4. Open a **PR on this repo**; babysit CI plan/validate.

## Mode C — Operator (standing secrets configured)

- Bootstrap / slug demo on template: [PLATFORM-BOOTSTRAP.md](docs/PLATFORM-BOOTSTRAP.md)
- Never `terraform apply` in the agent VM for client stacks — GHA deploys via OIDC

---

## Hard rules

- **No PR on template repo** for client-specific proposals or implementation.
- **No** `terraform apply` / `bundle deploy` in agent VM (exception: user explicitly overrides locally).
- **No** client storage account or workspace names committed to **template** `main`.
- **Destroy** workflows — human-triggered in GitHub Actions, not agent default.

`databricks bundle validate` needs workspace creds — runs in CI, not default agent workflow.

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
