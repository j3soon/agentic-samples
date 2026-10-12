#!/usr/bin/env bash
# Check both the shared SSH socket and a remote session.
# Usage: bash scripts/nano4/check.sh
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/check.sh'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"

check_master
ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true
