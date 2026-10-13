#!/usr/bin/env bash
# Source this helper for account configuration and shared SSH connection options.
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
config="$repo_dir/secrets/.env"
if [[ ! -f "$config" ]]; then
  echo 'Run bash scripts/nano4/configure.sh ACCOUNT SYSTEM_CODE first.' >&2
  exit 2
fi

# Read identifiers as data. Never execute the configuration file.
username=''
project_code=''
while IFS='=' read -r key value; do
  value=${value%$'\r'}
  case "$key" in
    NCHC_ISERVICE_SUPERCOMPUTER_ACCOUNT) username=$value ;;
    NCHC_ISERVICE_PROJECT_SYSTEM_CODE) project_code=$value ;;
  esac
done < "$config"
if [[ ! $username =~ ^[a-zA-Z0-9_-]+$ || ! $project_code =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo 'Configure a valid Supercomputer account and Project system code first.' >&2
  exit 2
fi

remote_dir=${NCHC_REMOTE_DIR:-/work/$username/agentic-samples}
if [[ "$remote_dir" != /* || "$remote_dir" == *$'\n'* ]]; then
  echo 'Remote directory must be absolute and contain no newlines.' >&2
  exit 2
fi

# OpenSSH hashes the host, user, and port into %C to name the private socket.
control_dir="$HOME/.ssh/nano4-control"
mkdir -p "$control_dir"
chmod 700 "$control_dir"
ssh_options=(-p 22 -o "ControlPath=$control_dir/%C" -o ConnectTimeout=15)
target="$username@nano4.nchc.org.tw"

check_master() {
  ssh "${ssh_options[@]}" -O check "$target"
}

require_connection() {
  if ! check_master >/dev/null 2>&1; then
    echo 'Authentication needed. Run bash scripts/nano4/login.sh in your terminal, then retry.' >&2
    exit 10
  fi
  # An expired connection must fail instead of asking the agent for credentials.
  ssh_options+=(-o BatchMode=yes -o ControlMaster=no)
  # Rsync accepts an SSH command string. Quote the socket path for spaces.
  rsync_ssh="ssh -p 22 -o \"ControlPath=$control_dir/%C\" -o BatchMode=yes -o ControlMaster=no -o ConnectTimeout=15"
}

require_run_directory() {
  if [[ -z ${NCHC_REMOTE_DIR:-} ]]; then
    echo 'Set NCHC_REMOTE_DIR for this command. Use a fresh directory for a new job.' >&2
    echo 'Reuse the same directory for retries, status, and downloads.' >&2
    exit 2
  fi
}

# Merge the local node list with caller exclusions into one Slurm option.
load_slurm_options() {
  slurm_options=()
  local excluded='' node_file="$repo_dir/cluster/nano4/excluded-nodes.txt"
  if [[ -s "$node_file" ]]; then
    excluded=$(paste -sd, "$node_file")
    printf 'Avoiding suspected nodes: %s\n' "$excluded" >&2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --exclude=*) excluded="${excluded:+$excluded,}${1#*=}" ;;
      -x?*) excluded="${excluded:+$excluded,}${1#-x}" ;;
      --exclude|-x)
        if [[ $# -lt 2 || $2 == -* ]]; then
          echo 'Pass a node list after --exclude or -x.' >&2
          return 2
        fi
        shift
        excluded="${excluded:+$excluded,}$1"
        ;;
      *) slurm_options+=("$1") ;;
    esac
    shift
  done
  if [[ -n "$excluded" ]]; then
    slurm_options+=("--exclude=$excluded")
  fi
}
