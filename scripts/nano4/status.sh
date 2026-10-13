#!/usr/bin/env bash
# Query the recorded job once with squeue and sacct.
# Usage: bash scripts/nano4/status.sh
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/status.sh'
  echo 'Set NCHC_REMOTE_DIR to the run directory for every invocation.'
  exit 0
fi
# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"
require_run_directory
require_connection

# Read the saved job ID. %q quotes the path for the remote shell.
printf -v remote_command 'cat -- %q' "$remote_dir/submission/job-id"
if ! job_id=$(ssh "${ssh_options[@]}" "$target" "$remote_command"); then
  echo 'Could not read the job record. Check SSH and inspect Slurm before retrying.' >&2
  exit 3
fi
if [[ ! "$job_id" =~ ^[0-9]+$ ]]; then
  echo 'Invalid recorded job ID. Inspect Slurm before retrying.' >&2
  exit 3
fi

# Slurm may remove completed jobs from squeue. Always check accounting afterward.
if ! ssh "${ssh_options[@]}" "$target" "squeue -j $job_id"; then
  echo 'Queue query failed. Checking accounting.'
fi
ssh "${ssh_options[@]}" "$target" "sacct -j $job_id --format=JobID,State,ExitCode"
