#!/usr/bin/env bash
# Copy the original experiment and tools without the solution or Git history.
# Usage: bash scripts/demos/prepare-scaling.sh DESTINATION [PYTORCH_SIF]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/demos/prepare-scaling.sh DESTINATION [PYTORCH_SIF]'
  exit 0
fi
if [[ $# -lt 1 || $# -gt 2 || -e $1 || -L $1 ]]; then
  echo 'Choose a new destination directory.' >&2
  exit 2
fi
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -d "$repo_dir/examples/pytorch-scaling/reference" || -f "$repo_dir/docs/pytorch-scaling.md" ]] &&
   ! grep -q '^### Reference experiment$' "$repo_dir/README.md"; then
  echo 'Cannot find the reference section to exclude. Check README.md.' >&2
  exit 2
fi
workspace=$1
mkdir -p "$workspace"/{scripts/demos,skills,docs,examples/pytorch-scaling,cluster/nano4,secrets,.agents/skills}
cp "$repo_dir/AGENTS.md" "$repo_dir/.gitignore" "$workspace/"
cp -R "$repo_dir/scripts/nano4" "$repo_dir/scripts/rap" "$workspace/scripts/"
cp "$repo_dir/scripts/demos/prepare-scaling.sh" "$workspace/scripts/demos/"
cp -R "$repo_dir/skills/nano4" "$workspace/skills/"
cp -R "$repo_dir/examples/rap" "$workspace/examples/"
cp -R "$repo_dir/docker" "$workspace/"
cp "$repo_dir/examples/pytorch-scaling/TASK.md" "$workspace/examples/pytorch-scaling/"
# Use the recorded initial version. An isolated copy can also be copied again.
baseline="$repo_dir/examples/pytorch-scaling/reference/initial"
plotter="$repo_dir/examples/pytorch-scaling/reference/plot.py"
if [[ ! -d "$baseline" ]]; then
  baseline="$repo_dir/examples/pytorch-scaling"
  plotter="$baseline/plot.py"
fi
cp "$baseline/"{train.py,train.slurm} "$workspace/examples/pytorch-scaling/"
cp "$plotter" "$workspace/examples/pytorch-scaling/plot.py"
cp "$repo_dir/cluster/nano4/"{smoke.slurm,excluded-nodes.txt} "$workspace/cluster/nano4/"
cp "$repo_dir/docs/"{agent-environments,nchc-iservice,rap}.md "$workspace/docs/"
cp "$repo_dir/secrets/.env.example" "$workspace/secrets/"
ln -s ../../skills/nano4 "$workspace/.agents/skills/nano4"
if [[ -f "$repo_dir/artifacts/nano4-node-issues.md" ]]; then
  mkdir -p "$workspace/artifacts"
  cp "$repo_dir/artifacts/nano4-node-issues.md" "$workspace/artifacts/"
fi

# The reference discussion is omitted from the copied walkthrough and Nano4 guide.
sed -e '/^For workshops, an \[optional clean workspace\]/,+1d' \
  -e '/^### Reference experiment/,$d' "$repo_dir/README.md" > "$workspace/README.md"
sed '/^The optional \[PyTorch scaling guide\]/,+1d' "$repo_dir/docs/nano4.md" > "$workspace/docs/nano4.md"

# These identifiers are safe to reuse. Passwords and OTPs are never stored here.
if [[ -f "$repo_dir/secrets/.env" ]]; then
  # Copy only the two identifiers, even if the source file has extra fields.
  sed -n '/^NCHC_ISERVICE_SUPERCOMPUTER_ACCOUNT=/p; /^NCHC_ISERVICE_PROJECT_SYSTEM_CODE=/p' \
    "$repo_dir/secrets/.env" > "$workspace/secrets/.env"
  chmod 600 "$workspace/secrets/.env"
fi
if [[ $# == 2 ]]; then
  printf '\nPyTorch SIF from step 3: `%s`.\n' "$2" >> "$workspace/examples/pytorch-scaling/TASK.md"
fi
printf 'Prepared %s\n' "$workspace"
echo 'Launch OpenCode here with a fresh private home, then connect RAP and Nano4.'
