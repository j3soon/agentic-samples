#!/usr/bin/env bash
# Write RAP as the default without replacing custom settings or permissions.
# Usage: bash scripts/rap/configure-opencode.sh
set -euo pipefail
umask 077
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
config_file="$config_dir/opencode.json"
if [[ -f "$config_dir/opencode.jsonc" ]]; then
  config_file="$config_dir/opencode.jsonc"
fi
config_file=${OPENCODE_CONFIG:-$config_file}
mkdir -p "$(dirname "$config_file")"
rap_config=$(mktemp "$config_file.XXXXXX")
trap 'rm -f "$rap_config"' EXIT
cat > "$rap_config" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "nchc-rap/Kimi-K3",
  "provider": {
    "nchc-rap": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "NCHC RAP",
      "options": {"baseURL": "https://portal.genai.nchc.org.tw/api/v1"},
      "models": {
        "Kimi-K3": {
          "name": "Kimi-K3",
          "attachment": true,
          "modalities": {"input": ["text", "image"], "output": ["text"]}
        }
      }
    }
  }
}
JSON
# Comparing files needs no JSONC parser and makes repeated setup harmless.
if [[ -e "$config_file" || -L "$config_file" ]]; then
  if ! cmp -s "$rap_config" "$config_file"; then
    printf 'Existing configuration left unchanged: %s\n' "$config_file" >&2
    echo 'Ask your agent to merge only the RAP provider and model shown in this script.' >&2
    echo 'Preserve permissions and other settings. See docs/rap.md#manual-setup.' >&2
    exit 2
  fi
else
  cat "$rap_config" > "$config_file"
  chmod 600 "$config_file"
fi
printf 'Configured %s\n' "$config_file"
echo 'Give your RAP key to the agent, or use /connect, Other, nchc-rap in OpenCode.'
echo 'Then run: bash scripts/rap/test-opencode.sh'
