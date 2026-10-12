#!/usr/bin/env bash
# Run an explicit command through SSH, quoting each remote argument.
# Usage: bash scripts/nano4/exec.sh COMMAND [ARGS...]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/exec.sh COMMAND [ARGS...]'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"
require_connection

[[ $# -gt 0 ]] || { echo 'exec requires a remote command.' >&2; exit 2; }
# SSH sends a command string. Quote each argument for the remote shell.
printf -v remote_command '%q ' "$@"
ssh "${ssh_options[@]}" "$target" "$remote_command"
exit $?
