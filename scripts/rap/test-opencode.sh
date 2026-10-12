#!/usr/bin/env bash
# Read an image fixture with opencode, using its saved RAP credential.
# Usage: bash scripts/rap/test-opencode.sh [MODEL]
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: bash scripts/rap/test-opencode.sh [MODEL]'
  exit 0
fi
[[ $# -le 1 ]] || { echo 'Pass only the model ID.' >&2; exit 2; }
model=${1:-Kimi-K3}
repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
# The prompt names the files without revealing the image's contents.
prompt="Use the read tool to read $repo_dir/examples/rap/image.png. What is in image.png? Describe the image and include its visible text. What model are you? Report your model name if known, otherwise say unknown."
answer=$(opencode run --pure --dir "$repo_dir" --model "nchc-rap/$model" "$prompt")
printf '%s\n' "$answer"

# Check the response without revealing the expected image text in the prompt.
normalized=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
# Check the reported model family too. Self-identification is not proof of routing.
model_family=$(printf '%s' "${model%%-*}" | tr '[:upper:]' '[:lower:]')
for expected in 'the more you buy' 'the more you save'; do
  if [[ "$normalized" != *"$expected"* ]]; then
    printf 'Missing expected text: %s\n' "$expected" >&2
    exit 1
  fi
done
printf 'Requested model: nchc-rap/%s\n' "$model"
if [[ "$normalized" != *"$model_family"* ]]; then
  echo 'Model self-identification did not match. Verify routing in RAP rather than trusting the reply.' >&2
fi
echo 'Image reading test passed.'
