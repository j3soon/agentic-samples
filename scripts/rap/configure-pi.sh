#!/usr/bin/env bash
# Write RAP as the default, backing up the existing configuration first.
# Usage: bash scripts/rap/configure-pi.sh
set -euo pipefail
umask 077
config_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
mkdir -p "$config_dir"
# Back up both files before replacing them. The separate auth store stays intact.
for config_file in "$config_dir/models.json" "$config_dir/settings.json"; do
  if [[ -f "$config_file" ]]; then
    backup=$(mktemp "$config_file.bak.XXXXXX")
    cat "$config_file" > "$backup"
    printf 'Backup: %s\n' "$backup"
  fi
done
cat > "$config_dir/models.json" <<'JSON'
{
  "providers": {
    "nchc-rap": {
      "name": "NCHC RAP",
      "baseUrl": "https://portal.genai.nchc.org.tw/api/v1",
      "api": "openai-completions",
      "models": [{"id": "Kimi-K3", "name": "Kimi-K3", "input": ["text", "image"]}]
    }
  }
}
JSON
cat > "$config_dir/settings.json" <<'JSON'
{"defaultProvider": "nchc-rap", "defaultModel": "Kimi-K3"}
JSON
chmod 600 "$config_dir/models.json" "$config_dir/settings.json"
printf 'Configured %s\n' "$config_dir"
echo 'Give your RAP key to the agent, or use /login, API key, NCHC RAP in Pi.'
echo 'Then run: bash scripts/rap/test-pi.sh'
