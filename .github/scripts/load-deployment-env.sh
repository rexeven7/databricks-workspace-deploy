#!/usr/bin/env bash
# Resolve deployment inputs and append to GITHUB_ENV (space-safe).
# For sandbox slug deploys, also writes env/deployment.auto.tfvars (overrides prod.tfvars).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
resolve_out="$(mktemp)"
trap 'rm -f "$resolve_out"' EXIT

bash "$script_dir/resolve-deployment.sh" > "$resolve_out"
bash "$script_dir/write-github-env.sh" < "$resolve_out"
bash "$script_dir/write-deployment-tfvars.sh" "$resolve_out" "${DEPLOYMENT_TFVARS_PATH:-env/deployment.auto.tfvars}"
