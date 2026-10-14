#!/usr/bin/env bash
# Open a persistent SSH connection from your own interactive terminal.
# Usage: bash scripts/nano4/login.sh
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/login.sh'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"

# A running master is useful only if it can also open remote sessions.
if check_master 2>/dev/null; then
  if ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true; then
    exit 0
  fi
  echo 'Replacing a connection that cannot open remote sessions.' >&2
  ssh "${ssh_options[@]}" -O exit "$target"
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  echo 'Authentication requires your terminal. Run: bash scripts/nano4/login.sh' >&2
  exit 10
fi
# Probe idle connections every 30 seconds. Allow five minutes of missed replies.
ssh "${ssh_options[@]}" -o ControlMaster=yes -o ControlPersist=yes \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -Nf "$target"
check_master
ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true
