#!/usr/bin/env bash
# Submit once from the run directory and record the Slurm job ID.
set -euo pipefail
work_dir=$1
project_code=$2
shift 2
cd "$work_dir"
account=$(printf '%s' "$project_code" | tr '[:upper:]' '[:lower:]')

# Slurm options come before --. The remaining arguments go to the job script.
sbatch_options=()
while [[ $# -gt 0 && $1 != -- ]]; do
  sbatch_options+=("$1")
  shift
done
if [[ ${1:-} != -- ]]; then
  echo 'Separate Slurm options and job arguments with --.' >&2
  exit 2
fi
shift

if [[ -f submission/job-id ]]; then
  echo "Already submitted job $(cat submission/job-id). Use scripts/nano4/status.sh."
  exit 0
fi
# A durable marker prevents automatic duplicate submission after a lost response.
if ! mkdir submission; then
  echo 'Submission outcome is uncertain. Inspect squeue/sacct before retrying.' >&2
  exit 3
fi
mkdir -p logs outputs
# Slurm opens output files before the job starts, so their directories must exist.
cp job.slurm submission/job.slurm
if job_id=$(sbatch --account="$account" "${sbatch_options[@]}" job.slurm "$@"); then
  # Slurm can append a cluster name after the numeric ID.
  job_id=${job_id%%;*}
  if [[ ! "$job_id" =~ ^[0-9]+$ ]]; then
    echo 'Unexpected sbatch response. Inspect Slurm before retrying.' >&2
    exit 3
  fi
  printf '%s\n' "$job_id" > submission/job-id
  echo "Submitted job $job_id"
else
  echo 'Submission failed. Inspect Slurm and the submission marker before retrying.' >&2
  exit 3
fi
