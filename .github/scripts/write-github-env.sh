#!/usr/bin/env bash
# Append KEY=VALUE lines to GITHUB_ENV, using heredoc syntax when values contain spaces.
set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV must be set}"

while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  key="${line%%=*}"
  value="${line#*=}"
  if [[ "$value" == *" "* || "$value" == *$'\t'* ]]; then
    delim="GHENV_${key}_$$"
    {
      echo "${key}<<${delim}"
      echo "$value"
      echo "${delim}"
    } >> "$GITHUB_ENV"
  else
    echo "${key}=${value}" >> "$GITHUB_ENV"
  fi
done
