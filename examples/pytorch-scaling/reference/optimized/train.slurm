#!/usr/bin/env bash
#SBATCH --job-name=pytorch-scaling
#SBATCH --partition=dev
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-gpu=12
#SBATCH --mem=64G
#SBATCH --time=00:02:00
#SBATCH --output=logs/slurm-%j.out

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
image=${1:?Pass an absolute PyTorch SIF path}
shift
[[ -f train.py ]] || { echo 'Upload train.py to the run directory first.' >&2; exit 2; }
cp train.py outputs/train.py
scontrol show job "$SLURM_JOB_ID" > outputs/slurm-job.txt
printf '%s\n' "$image" > outputs/container.txt

# One Slurm task per node launches one torchrun worker per allocated GPU.
export GPUS_PER_NODE=${SLURM_GPUS_PER_NODE:?Request --gpus-per-node}
[[ "$GPUS_PER_NODE" =~ ^[0-9]+$ ]] || exit 2
# Job-specific names preserve these values through container startup.
read -r SCALING_MASTER_ADDR < <(scontrol show hostnames "$SLURM_JOB_NODELIST")
export SCALING_MASTER_ADDR
export SCALING_MASTER_PORT=$((15000 + SLURM_JOB_ID % 40000))
export OMP_NUM_THREADS=1
export PYTHONUNBUFFERED=1

# Choose the runtime on each node. Some nodes need the shared Singularity module.
# Only the run directory is explicitly mounted. All nodes share its outputs.
srun --nodes="$SLURM_JOB_NUM_NODES" --ntasks="$SLURM_JOB_NUM_NODES" \
  --ntasks-per-node=1 --kill-on-bad-exit=1 \
  --output='logs/node-%N.out' --error='logs/node-%N.err' \
  bash -lc '
    set -e
    if command -v apptainer >/dev/null 2>&1; then
      runtime=apptainer
    else
      command -v singularity >/dev/null 2>&1 || module load singularity
      runtime=singularity
    fi
    "$runtime" --version
    exec "$runtime" exec --nv --bind "$SLURM_SUBMIT_DIR:/workspace" "$@"
  ' bash "$image" bash -c '
    cd /workspace
    nvidia-smi
    exec torchrun --nnodes="$SLURM_JOB_NUM_NODES" \
      --nproc-per-node="$GPUS_PER_NODE" --node-rank="$SLURM_PROCID" \
      --master-addr="$SCALING_MASTER_ADDR" --master-port="$SCALING_MASTER_PORT" \
      --max-restarts=0 --monitor-interval=1 \
      --log-dir="logs/node-$SLURM_NODEID" --redirects=3 --tee=3 \
      train.py --output outputs "$@"
  ' bash "$@"
