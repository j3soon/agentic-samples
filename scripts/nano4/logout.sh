#!/usr/bin/env bash
# Close the shared SSH connection. Submitted jobs keep running.
# Usage: bash scripts/nano4/logout.sh
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/logout.sh'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"

ssh "${ssh_options[@]}" -O exit "$target"
