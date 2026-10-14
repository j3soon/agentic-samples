#!/usr/bin/env bash
#SBATCH --job-name=resnet-inference
#SBATCH --partition=dev
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=32G
#SBATCH --time=00:20:00
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
image=${1:?Pass the absolute PyTorch SIF path}
max_images=${2:-10000}
echo "PyTorch SIF: $image"

# Upload examples/resnet-inference as example/ before submitting.
srun bash -lc '
  set -e
  if command -v apptainer >/dev/null 2>&1; then
    runtime=apptainer
  else
    command -v singularity >/dev/null 2>&1 || module load singularity
    runtime=singularity
  fi
  exec "$runtime" exec --nv --bind "$SLURM_SUBMIT_DIR:/workspace" --pwd /workspace "$@"
' bash "$image" bash /workspace/example/run-baseline.sh "$max_images"
