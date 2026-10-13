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
credentials. Containers and dedicated VMs are also options. Keep the agent local
and use Nano4 allocations for container preparation and workloads.

Use OpenCode by default, with Pi as the secondary option for users who prefer
minimalism and customizability. Approval prompts suit sensitive environments
but make this workflow much less efficient.
See [docs/agent-environments.md](docs/agent-environments.md) for launch commands,
including [OpenCode and Pi in Docker](docs/agent-environments.md#launch-opencode-or-pi-in-docker).
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

Continue with **RAP + Kimi-K3** for event work.
Each team starts with a **NT$20,000 RAP budget**. If you exceed it or need more,
contact your mentor. Additional budget can be requested up to **NT$40,000**.
Service rate limits still apply. Pi is the secondary option.
See [docs/rap.md](docs/rap.md) for manual steps and privacy guidance.

## 2. Set up NCHC iService credentials

With your local agent ready, follow
[docs/nchc-iservice.md](docs/nchc-iservice.md#1-nano4-ssh-credentials) for Nano4
SSH credentials and project access. The agent can guide you, but website settings,
machine passwords, and OTP entry stay in your hands.

## 3. Run jobs on Nano4

Run the agent **locally**, on your computer, in Docker, or in a dedicated VM.
It connects to Nano4 over SSH. The **login node** handles
short setup, file operations, and job management. **Slurm** allocates compute
nodes for container preparation and GPU workloads.
Nano4's [usage rules](https://man.twcc.ai/@nano4-manual/B1zWMYxv-l)
require computational work to go through Slurm.

**Do not run agents on Nano4 login (head) nodes.** These nodes are for short
setup, file operations, and job management.

Running an agent on a compute node is technically feasible within a Slurm
allocation, but H200 compute jobs require at least one GPU. You spend GPU budget
even while the agent waits for a model response. We generally recommend local
execution and reserving cluster allocations for container preparation and
workloads. [Cancel unwanted jobs](docs/nano4.md#cancel-an-unwanted-job)
to release their allocations. Closing the agent does not cancel submitted jobs.

### Compute and RAP budgets

| Service | Budget applies to | Default budget | Maximum with an approved request |
|---|---|---:|---:|
| Nano4 H200 GPU + Forerunner-1 Grace CPU | Each service account, shared across both clusters | NT$5,000 | NT$20,000 |
| RAP model API | Each team | NT$20,000 | NT$40,000 |

Contact your mentor if you exceed your budget or need an increase.
This repository's workload example uses Nano4. See the
[Nano4 partition guide](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe) and
[Forerunner-1 partition guide](https://man.twcc.ai/@f1-manual/partition)
for resource limits.

NCHC's [pricing guide](https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=54)
lists **NT$60 per H200 GPU-hour** for government and academic projects.
At that rate, one GPU for one hour costs NT$60, and a full eight-GPU node costs
**NT$480 per hour**. Estimate compute cost as allocated GPUs × running hours ×
NT$60. Container preparation also uses a paid compute allocation.

### Demo: submit a container smoke test

If you have used Nano4 before, back up existing files you want to keep first.
New users can skip this step. See [docs/nano4.md](docs/nano4.md).

Ask your agent:

> Submit the Nano4 container smoke test in a fresh remote run directory and download its logs.

The agent handles setup, submission, and result collection. It prompts you to
run the login command in your own terminal when authentication is needed:

```bash
bash scripts/nano4/login.sh
```

See [docs/nano4.md](docs/nano4.md) for prerequisites, the three login prompts,
manual commands, container preparation, job options, and result downloads.
Skills in `skills/` are linked from `.agents/skills` and `.claude/skills`
for automatic discovery.
