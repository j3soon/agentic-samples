#!/usr/bin/env bash
# Runs inside the PyTorch SIF on a Nano4 compute node.
set -euo pipefail
if [[ -z ${SLURM_JOB_ID:-} ]]; then
  echo 'Run this workload through Slurm on Nano4.' >&2
  exit 2
fi
max_images=${1:-10000}
example_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mkdir -p artifacts cache
export TORCH_HOME="$PWD/cache/torch"

# Reuse the container's PyTorch without changing its installed packages.
python -m venv --system-site-packages .venv
.venv/bin/python -m pip install -r "$example_dir/requirements.txt" \
  2>&1 | tee artifacts/setup.log

{
  echo "Job $SLURM_JOB_ID on $(hostname), CPUs ${SLURM_CPUS_PER_TASK:-unknown}"
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
  .venv/bin/python - <<'PY'
import platform
import torch
import torchvision

print("Python", platform.python_version())
print("PyTorch", torch.__version__, "torchvision", torchvision.__version__)
print("CUDA", torch.version.cuda, "cuDNN", torch.backends.cudnn.version())
assert torch.cuda.is_available(), "CUDA required."
print("Device", torch.cuda.get_device_name())
PY
  sha256sum "$example_dir/01_base.py"
} 2>&1 | tee artifacts/environment.log
.venv/bin/python -m pip list --format=freeze > artifacts/packages.txt
# The first run downloads ImageNetV2 into ./data and weights into TORCH_HOME.
.venv/bin/python "$example_dir/01_base.py" "$max_images" \
  2>&1 | tee artifacts/baseline.log
