# Agentic Samples

[![Slack](https://img.shields.io/badge/Slack-4A154B?logo=slack&logoColor=white)](https://app.slack.com/client/T0C70DGFW02)
[![Cluster support](https://img.shields.io/badge/%23cluster--support-green)](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE)

Examples for the [NCHC Open Hackathon](https://www.openhackathons.org/s/siteevent/a0CUP00004AB2oc2AD/se000481).
Each team has an NVIDIA mentor for domain-specific questions. Your mentor shares
the team's pre-created RAP API key in your team Slack channel. For Nano4 access
or RAP key issues, ask [#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE).

Practical examples for getting work done through coding agents such as
[Codex](https://openai.com/codex/), [Claude Code](https://code.claude.com/docs/en/overview),
[OpenCode](https://opencode.ai/), and [Pi](https://pi.dev/). The aim is to let
agents handle as much setup,
execution, and result collection as possible using plain scripts and skills,
without additional harness plugins.

The workflow keeps passwords and MFA codes out of LLM chat by default for better
security. Account website settings and Nano4 authentication stay in your hands.
You may give a rotatable RAP API key to the agent. The agent prompts you with the steps or commands when needed, then resumes the work.
Each example also includes concise steps you can follow manually using the same
scripts.

## 0. Choose the agent environment

Use Ubuntu, macOS, or Windows with WSL2, with Bash, OpenSSH, and rsync 3+.

**Prerequisite:** use an environment where you can enable YOLO or all-permissions
mode. A personal computer is fine if you accept the agent's access to files and
credentials. Containers, dedicated VMs, and Nano4 compute allocations are also
options.

Use OpenCode by default, with Pi as the secondary option for users who prefer
minimalism and customizability. Approval prompts suit sensitive environments
but make this workflow much less efficient.
See [docs/agent-environments.md](docs/agent-environments.md) for launch commands.
Keep persistent agents off cluster login nodes.

## 1. Set up a local agent and RAP

If you already have a Codex or Claude Code subscription, use that agent to help
with setup. Otherwise, [install or update OpenCode](https://opencode.ai/docs/) and start it
from this repository:

```bash
opencode --auto
```

Use its default free model, or select an available free model with `/models`.
Some [OpenCode free models](https://opencode.ai/docs/zen/#privacy) may use your
prompts and code for training or product improvement. Use them for this public
setup, then switch to your team's RAP endpoint for event work. RAP's
[data-protection guidance](https://rap-docs.genai.nchc.org.tw/docs/service_intro/home/#%E7%94%A8%E6%88%B6%E8%B3%87%E6%96%99%E4%BF%9D%E8%AD%B7)
says retained operational records are not used for model training and are deleted
after six months.

Get your team's pre-created RAP API key from your mentor in your team Slack
channel. Ask your agent:

> Configure RAP with Kimi-K3 for OpenCode, preserving existing settings and permissions, then test image reading.

Continue with **RAP + Kimi-K3** for the remaining setup. Use RAP freely during
the hackathon. The event quota is intended to be effectively unlimited for normal
team use, though service rate limits still apply. Pi is the secondary option.
See [docs/rap.md](docs/rap.md) for manual steps and privacy guidance.

## 2. Set up NCHC iService credentials

With your local agent ready, follow
[docs/nchc-iservice.md](docs/nchc-iservice.md#1-nano4-ssh-credentials) for Nano4
SSH credentials and project access. The agent can guide you, but website settings,
machine passwords, and OTP entry stay in your hands.

## 3. Run jobs on Nano4

If you have used Nano4 before, back up existing files you want to keep first.
New users can skip this step. See [docs/nano4.md](docs/nano4.md).

Ask your agent:

> Submit the Nano4 container smoke test and download its logs.

The agent handles setup, submission, and result collection. It prompts you to
run the login command in your own terminal when authentication is needed:

```bash
bash scripts/nano4/login.sh
```

See [docs/nano4.md](docs/nano4.md) for prerequisites, the three login prompts,
manual commands, container preparation, job options, and result downloads.
Skills in `skills/` are linked from `.agents/skills` and `.claude/skills`
for automatic discovery.
