#!/usr/bin/env bash
# Upload a job script and submit it with sbatch. Record its job ID to prevent duplicates.
# Usage: bash scripts/nano4/submit.sh [SBATCH_OPTIONS... --] JOB_SCRIPT [JOB_ARGS...]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/submit.sh [SBATCH_OPTIONS... --] JOB_SCRIPT [JOB_ARGS...]'
  exit 0
fi
# Optional Slurm flags precede --. Keep the original script-first usage valid.
sbatch_options=(--parsable)
if [[ ${1:-} == -* ]]; then
  while [[ $# -gt 0 && $1 != -- ]]; do
    sbatch_options+=("$1")
    shift
  done
  if [[ ${1:-} != -- ]]; then
    echo 'Separate sbatch options and the script with --.' >&2
    exit 2
  fi
  shift
fi
if [[ $# -lt 1 || ! -f $1 ]]; then
  echo 'Usage: submit JOB_SCRIPT [JOB_ARGS...]' >&2
  exit 2
fi
job_script=$1
shift

# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"
require_connection

# Create the run directory and upload the two scripts through shared SSH.
printf -v remote_command 'mkdir -p %q' "$remote_dir"
ssh "${ssh_options[@]}" "$target" "$remote_command"
rsync -a --protect-args -e "$rsync_ssh" -- "$job_script" "$target:$remote_dir/job.slurm"
rsync -a --protect-args -e "$rsync_ssh" -- "$repo_dir/scripts/nano4/remote/submit.sh" "$target:$remote_dir/"
# SSH takes one command string. %q preserves each argument exactly.
printf -v remote_command '%q ' bash "$remote_dir/submit.sh" "$remote_dir" "$project_code" \
  "${sbatch_options[@]}" -- "$@"
ssh "${ssh_options[@]}" "$target" "$remote_command"
