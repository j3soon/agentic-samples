# RAP for OpenCode and Pi

Use **RAP + Kimi-K3** with OpenCode by default. Pi is the secondary option for
users who prefer a smaller, customizable harness. No harness plugin is needed.

Choose an [agent environment](agent-environments.md) suitable for YOLO or
all-permissions mode. Get your team's pre-created RAP API key from your mentor
in your team Slack channel. See [credential setup](nchc-iservice.md#2-rap-api-key).

Ask your agent:

> Configure RAP with Kimi-K3 for OpenCode, preserving existing settings and permissions, then test image reading.

You may give the rotatable RAP API key to the agent, or enter it through your
client's local prompt. RAP does not require a Nano4 SSH connection.

## Start an agent for setup

Use your existing Codex or Claude Code subscription to configure RAP if available.
See [launch commands](agent-environments.md#launch-the-agent). Otherwise,
[install the current OpenCode release](https://opencode.ai/docs/) and run
`opencode --auto` from this repository. If already installed, use `opencode upgrade`
first. The current free tier requires OpenCode 1.18.0 or newer. Use its default
free model, or choose an available free model with `/models`. Free model availability changes. Use public examples for setup.

Ask the agent to configure RAP + Kimi-K3 for OpenCode using your team's key.
After configuration, restart OpenCode or select `nchc-rap/Kimi-K3` with `/models`.
Use that endpoint for the remaining setup. Nano4 iService credentials are needed
only when you move on to cluster jobs.

## Privacy

Agents send prompts and file contents to the selected model endpoint. For private
code, choose an endpoint that excludes your data from model training. Some
[OpenCode free models](https://opencode.ai/docs/zen/#privacy) may use prompts to
improve models. Use them only for public examples while setting up RAP.

We recommend your team's RAP endpoint for event work. RAP's official
[data-protection guidance](https://rap-docs.genai.nchc.org.tw/docs/service_intro/home/#%E7%94%A8%E6%88%B6%E8%B3%87%E6%96%99%E4%BF%9D%E8%AD%B7)
explicitly covers its multi-model API service. It says the backend retains only
necessary operational logs for maintenance, troubleshooting, and usage statistics.
These records are not used for model training or other non-service purposes and
are deleted after six months.

If you prefer your own Codex or Claude Code subscription instead of RAP, review
your account's data controls and disable model improvement where enabled before
using private code. See
[Codex account policies](https://learn.chatgpt.com/docs/auth) and
[Claude Code data usage](https://code.claude.com/docs/en/data-usage).
Excluding data from training does not necessarily mean no logs are retained.

## Manual setup

Use Bash on Linux, macOS, or Windows through WSL. Run commands from the
repository root, with the client installed in the same environment:

```bash
bash scripts/rap/configure-opencode.sh
```

If a custom configuration already exists, the script leaves it unchanged and
stops. Ask your agent:

> Merge the RAP provider and model fields from scripts/rap/configure-opencode.sh into my existing OpenCode config. Preserve other providers, settings, comments, and permissions. Do not change permission rules.

For Pi instead:

```bash
bash scripts/rap/configure-pi.sh
```

If needed, [enter your key locally](nchc-iservice.md#enter-the-key-locally).
Reuse existing authentication when available.

## What the scripts change

The scripts use visible `cat` commands to write JSON, making RAP + Kimi-K3 the
default. Credential stores are left intact.

OpenCode setup creates a private config if none exists. Repeating setup with
the same generated config leaves it unchanged. It stops on a custom JSON or
JSONC config so an agent can merge the RAP fields without losing other settings
or changing permission rules. No JSONC parser or extra dependency is needed.

Pi setup replaces `models.json` and `settings.json`, backing up existing files
with private permissions first. Other settings and providers in those files are
replaced. The script prints its backup paths. Restore a previous configuration
by copying its backup over the corresponding config file:

```bash
cp "YOUR_BACKUP_FILE" "YOUR_CONFIG_FILE"
```

OpenCode uses `opencode.jsonc` if present, otherwise `opencode.json`, under
`~/.config/opencode/`. The script honors `XDG_CONFIG_HOME` and `OPENCODE_CONFIG`.
Pi uses `models.json` and `settings.json` under `~/.pi/agent/`, or
`PI_CODING_AGENT_DIR` when set.

Both scripts enable text and image input. Pi uses `input: ["text", "image"]`.
OpenCode uses `attachment: true` and `modalities.input: ["text", "image"]`.
The backend must also support images. Client settings alone do not prove that
it can read an image.

## Test image reading

After configuring the provider and entering your key, run the test for your client.

**OpenCode:**

```bash
bash scripts/rap/test-opencode.sh
```

**Pi instead:**

```bash
bash scripts/rap/test-pi.sh
```

Each script asks what is in `examples/rap/image.png` and requests the read tool.
The answer must include `THE MORE YOU BUY` and `THE MORE YOU SAVE`, ignoring case.
The prompts do not reveal these captions. See the [image fixture](../examples/rap/README.md).

The tests also ask which model is answering and print the requested model ID.
For Kimi-K3, a matching self-description mentions Kimi. A mismatch produces a
warning. Self-reported names do not prove routing, so verify the model ID through
RAP metadata or provider records.

Pi runs with only the read tool, no saved session, and no extensions, skills,
prompt templates, or context files. OpenCode runs without external plugins.
Both tests require a backend that supports images. Client settings alone do not
add vision to a text-only model.

To test another configured model, pass its exact ID, for example
`bash scripts/rap/test-pi.sh GLM-5.2`. The scripts contain the underlying native
client commands: [test-opencode.sh](../scripts/rap/test-opencode.sh) and
[test-pi.sh](../scripts/rap/test-pi.sh).

## Other models or endpoints

The default base URL is `https://portal.genai.nchc.org.tw/api/v1`.
Other potential models include `NVIDIA-Nemotron-3-Ultra-550B-A55B` and `GLM-5.2`.
Availability varies across providers. Check the exact model ID, base URL, and
image support in the [portal appendix](nchc-iservice.md#appendix-rap-portal).
Edit the scripts' visible JSON or ask the agent to configure those values.
The clients append `/chat/completions`, so omit that suffix from the base URL.
For a text-only model, use `input: ["text"]` and set OpenCode's `attachment` to
`false`.

For key or access issues, ask
[#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE).
Keep keys out of logs, command-line arguments, and tracked configuration.

Scripts: [configure-opencode.sh](../scripts/rap/configure-opencode.sh) and
[configure-pi.sh](../scripts/rap/configure-pi.sh).
References: [OpenCode custom providers](https://opencode.ai/docs/providers/#custom-provider),
[Pi custom models](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/models.md),
and [Pi settings](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md).

[Continue in README: set up NCHC iService credentials](../README.md#2-set-up-nchc-iservice-credentials).
