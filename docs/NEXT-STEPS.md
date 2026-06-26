# Documentation map

Quick pointers — no environment-specific values here.

| Doc | Use when |
|-----|----------|
| [DEMO-SETUP.md](DEMO-SETUP.md) | One-time Azure + GitHub + Cursor checklist |
| [CLIENT-REPO-BOOTSTRAP.md](CLIENT-REPO-BOOTSTRAP.md) | Greenfield: intake → proposal → **GO** → new repo + deploy |
| [PLATFORM-BOOTSTRAP.md](PLATFORM-BOOTSTRAP.md) | Operator credentials; slug deploy on the template repo |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Design rationale (Terraform vs DAB, layers, OIDC) |
| [architecture-proposals/](architecture-proposals/README.md) | Client intake proposals |
| [AGENTS.md](../AGENTS.md) | Cursor cloud agent boundaries |

**Typical flows**

- **New client:** Cursor on template → proposal → `scripts/spawn-client-repo.sh` on GO.
- **Quick sandbox:** Actions → **deploy** with a slug, or operator triggers `scripts/trigger-demo-deploy.sh`.
- **Teardown:** Actions → **destroy** on the relevant repo.
