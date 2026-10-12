#!/usr/bin/env bash
# Download logs and artifacts with rsync over shared SSH.
# Usage: bash scripts/nano4/download.sh [RELATIVE_PATHS...]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/download.sh [RELATIVE_PATHS...]'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"
require_connection

# Download selected paths through the authenticated connection.
# Keep each job's local results separate and avoid downloading the SIF by default.
# %q quotes the path for the remote shell, including spaces.
printf -v remote_command 'cat -- %q' "$remote_dir/submission/job-id"
if ! job_id=$(ssh "${ssh_options[@]}" "$target" "$remote_command"); then
  echo 'Could not read the job record. Check SSH and inspect Slurm before retrying.' >&2
  exit 3
fi
if [[ ! "$job_id" =~ ^[0-9]+$ ]]; then
  echo 'No valid recorded job ID.' >&2
  exit 3
fi
paths=("$@")
if [[ $# == 0 ]]; then
  paths=(logs outputs submission)
fi
sources=()
for path in "${paths[@]}"; do
  if [[ -z "$path" || "$path" == /* || "/$path/" == *'/../'* ]]; then
    echo 'Download paths must be relative to the remote run directory.' >&2
    exit 2
  fi
  # /./ tells --relative where the preserved directory structure starts.
  sources+=("$target:$remote_dir/./$path")
done
destination="$repo_dir/results/$job_id"
mkdir -p "$destination"
# Keep unfinished downloads separately so reruns can resume them.
rsync -a --relative --protect-args --partial-dir=.rsync-partial \
  -e "$rsync_ssh" -- "${sources[@]}" "$destination/"
echo "Downloaded to $destination"
