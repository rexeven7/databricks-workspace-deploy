#!/usr/bin/env bash
# Resolve deployment inputs and append to GITHUB_ENV (space-safe).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$script_dir/resolve-deployment.sh" | bash "$script_dir/write-github-env.sh"
