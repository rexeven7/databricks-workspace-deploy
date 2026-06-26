#!/usr/bin/env bash
# Run terraform with prod.tfvars + optional CI-generated deployment.auto.tfvars (slug overrides).
set -euo pipefail
vars=(-var-file=env/prod.tfvars)
if [ -f env/deployment.auto.tfvars ]; then
  vars+=(-var-file=env/deployment.auto.tfvars)
fi
exec terraform "$@" "${vars[@]}"
