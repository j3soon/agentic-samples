#!/usr/bin/env bash
# Write RAP as the default, backing up the existing configuration first.
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
# Overwrite rather than merge. Keep a private copy of any previous settings.
if [[ -f "$config_file" ]]; then
  backup=$(mktemp "$config_file.bak.XXXXXX")
  cat "$config_file" > "$backup"
  printf 'Backup: %s\n' "$backup"
fi
cat > "$config_file" <<'JSON'
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
chmod 600 "$config_file"
printf 'Configured %s\n' "$config_file"
echo 'Give your RAP key to the agent, or use /connect, Other, nchc-rap in OpenCode.'
echo 'Then run: bash scripts/rap/test-opencode.sh'
