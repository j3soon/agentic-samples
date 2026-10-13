#!/usr/bin/env bash
#SBATCH --job-name=nano4-smoke
#SBATCH --partition=dev
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:05:00
#SBATCH --output=logs/slurm-%j.out

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

# The first argument selects the image. Remaining arguments select the command.
# With no command, check GPU visibility using the host driver's nvidia-smi.
image=${1:-container.sif}
if [[ $# -gt 0 ]]; then shift; fi
if [[ $# == 0 ]]; then set -- nvidia-smi; fi
# --nv exposes the allocated NVIDIA GPU and driver libraries to the container.
srun bash -lc '
  set -e
  if command -v apptainer >/dev/null 2>&1; then
    runtime=apptainer
  else
    command -v singularity >/dev/null 2>&1 || module load singularity
    runtime=singularity
  fi
  "$runtime" --version
  exec "$runtime" exec --nv "$@"
' bash "$image" "$@"
