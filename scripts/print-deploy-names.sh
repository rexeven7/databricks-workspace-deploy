#!/usr/bin/env bash
# Show Azure resource names for a manual deploy workflow_dispatch slug.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/deploy-names.sh
source "$SCRIPT_DIR/lib/deploy-names.sh"
print_deploy_names "$@"
