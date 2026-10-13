#!/usr/bin/env bash
# Upload remote/prepare-sif.sh, then run it with srun on a compute node.
# Usage: bash scripts/nano4/prepare-sif.sh IMAGE_URI SIF_NAME [SRUN_OPTIONS...]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/nano4/prepare-sif.sh IMAGE_URI SIF_NAME [SRUN_OPTIONS...]'
  echo 'Set NCHC_REMOTE_DIR to the run directory for every invocation.'
  exit 0
fi
if [[ $# -lt 2 || ! $2 =~ ^[a-zA-Z0-9_.-]+\.sif$ ]]; then
  echo 'Usage: prepare IMAGE_URI SIF_NAME [SRUN_OPTIONS...]' >&2
  exit 2
fi
image_uri=$1
image_name=$2
shift 2

# Shared account parsing and SSH options stay in one readable helper.
source "$(dirname "${BASH_SOURCE[0]}")/helpers/ssh.sh"
load_slurm_options "$@"
require_run_directory
require_connection
account=$(printf '%s' "$project_code" | tr '[:upper:]' '[:lower:]')
printf -v remote_command 'mkdir -p %q' "$remote_dir"
ssh "${ssh_options[@]}" "$target" "$remote_command"
# Copy the remote script as a file, then execute it through Slurm.
rsync -a --protect-args -e "$rsync_ssh" -- "$repo_dir/scripts/nano4/remote/prepare-sif.sh" "$target:$remote_dir/"
# Use the CPU and memory allowance for one H200 GPU allocation.
# Extra srun options override these defaults for larger builds.
printf -v remote_command '%q ' srun --account="$account" --partition=dev \
  --nodes=1 --ntasks=1 --gpus-per-node=1 --cpus-per-task=12 --mem=200G \
  --time=04:00:00 "${slurm_options[@]}" bash -l "$remote_dir/prepare-sif.sh" "$remote_dir" "$image_uri" "$image_name"
ssh "${ssh_options[@]}" "$target" "$remote_command"
