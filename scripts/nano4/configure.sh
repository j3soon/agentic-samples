#!/usr/bin/env bash
# Save only the Supercomputer account username and project system code. Passwords and OTP stay in SSH.
# Usage: bash scripts/nano4/configure.sh ACCOUNT SYSTEM_CODE
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/configure.sh ACCOUNT SYSTEM_CODE'
  exit 0
fi

repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
config="$repo_dir/secrets/.env"
[[ $# == 2 && $1 =~ ^[a-zA-Z0-9_-]+$ && $2 =~ ^[a-zA-Z0-9_-]+$ ]] || {
  echo 'Usage: configure ACCOUNT SYSTEM_CODE (letters, digits, underscores, hyphens)' >&2; exit 2;
}
mkdir -p "$repo_dir/secrets"
# Store only account identifiers, with permissions restricted to this user.
(umask 077; printf 'NCHC_ISERVICE_SUPERCOMPUTER_ACCOUNT=%s\nNCHC_ISERVICE_PROJECT_SYSTEM_CODE=%s\n' "$1" "$2" > "$config")
chmod 600 "$config"
echo 'Saved username and project system code in secrets/.env.'
exit 0
