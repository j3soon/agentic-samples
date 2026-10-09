#!/usr/bin/env bash
# Run through srun. Keep image extraction and compression in node-local storage.
set -euo pipefail
: "${SLURM_JOB_ID:?Run this script in a Slurm allocation}"
work_dir=${1:?Pass the absolute persistent working directory}
mkdir -p "$work_dir"
work_dir=$(cd "$work_dir" && pwd)
image_uri=${2:?Pass a container image URI}
image=${3:?Pass the SIF filename}
[[ "$image" =~ ^[a-zA-Z0-9_.-]+\.sif$ ]] || { echo 'Invalid SIF filename.' >&2; exit 2; }

if command -v apptainer >/dev/null 2>&1; then runtime=apptainer
elif command -v singularity >/dev/null 2>&1; then runtime=singularity
else echo 'Load the site container runtime module first.' >&2; exit 2; fi

if [[ -f "$work_dir/$image" ]]; then
  # Reuse only a verified SIF whose recorded source matches the requested image.
  [[ -f "$work_dir/$image.source" && $(cat "$work_dir/$image.source") == "$image_uri" ]] || {
    echo 'This filename already exists with a different or unknown source. Choose another SIF name.' >&2
    exit 2
  }
  "$runtime" inspect "$work_dir/$image" >/dev/null
  echo "Reusing $work_dir/$image"
  exit 0
fi

# Extracting many small files on /work is slow. Use job-local scratch or RAM
# storage instead. /dev/shm usage counts against the allocated memory.
scratch=$(mktemp -d "${SLURM_TMPDIR:-/dev/shm}/nano4-build.${SLURM_JOB_ID}.XXXXXX")
partial="$work_dir/.$image.$SLURM_JOB_ID.partial"
trap 'rm -rf -- "$scratch"; rm -f -- "$partial"' EXIT
mkdir -p "$scratch/tmp" "$scratch/cache"
export TMPDIR="$scratch/tmp"
export APPTAINER_TMPDIR="$TMPDIR" SINGULARITY_TMPDIR="$TMPDIR"
export APPTAINER_CACHEDIR="$scratch/cache" SINGULARITY_CACHEDIR="$scratch/cache"

echo "Preparing on $(hostname), job $SLURM_JOB_ID, scratch $scratch"
# Limit compression threads to the requested CPUs and its buffer to 4 GB.
time "$runtime" build --mksquashfs-args "-processors ${SLURM_CPUS_PER_TASK:-8} -mem 4G" \
  "$scratch/$image" "$image_uri"
"$runtime" inspect "$scratch/$image" >/dev/null
# Publish only after verification and a complete copy to persistent storage.
cp "$scratch/$image" "$partial"
mv "$partial" "$work_dir/$image"
printf '%s\n' "$image_uri" > "$work_dir/$image.source"
echo "Prepared $work_dir/$image"
