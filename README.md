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

> Configure RAP with Kimi-K3 for OpenCode, then test image reading.

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

Start a local agent session in this repository and ask:

> Submit the Nano4 container smoke test.

Skills are stored in `skills/` and linked from `.agents/skills` and
`.claude/skills` for automatic discovery. You do not need to name a skill in
your request when your agent discovers it.

The agent configures access, prepares the container, submits the job, and
collects results. When authentication is needed, it asks you to run
`bash scripts/nano4.sh login` in a separate interactive terminal. Enter your
password and MFA code into SSH, then tell the agent you are connected. Keep
these secrets out of chat and configuration files.

The terminal and agent must use the same local OS user and, on Windows, the
same WSL distribution. The agent can then reuse the SSH connection until it
expires. Command runners without an interactive terminal, including Codex
CLI's `!` runner, cannot perform this login step.

### Run manually (optional)

After completing the iService setup above, you can also run the same steps
yourself. Run all helper commands locally from the repository root.

This example prepares Singularity/Apptainer images and runs Slurm jobs on Nano4.
The default job runs `nvidia-smi` inside an NVIDIA NGC PyTorch container on one
H200 GPU.

### 1. Configure access

```bash
bash scripts/nano4.sh configure YOUR_SUPERCOMPUTER_ACCOUNT YOUR_PROJECT_SYSTEM_CODE
bash scripts/nano4.sh login
```

Enter your password and MFA directly into the terminal when SSH requests them.
The helper creates the ignored `secrets/.env` with only the username and project
ID. It manages SSH connection sharing without changing `~/.ssh/config`.
Subsequent commands reuse the connection with no local idle expiration.
Run `logout` to close it. Shutdown closes it, and sleep or network changes
may break it. Run `login` again when needed.
Nano4 may disconnect it earlier. Already submitted Slurm jobs continue running.

### 2. Prepare a container and submit a job

**Run these helper commands locally. Apptainer itself runs only on Nano4, inside
an allocated Slurm compute node. You do not need Apptainer or Docker locally.**

```bash
bash scripts/nano4.sh prepare docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif
bash scripts/nano4.sh submit cluster/nano4/smoke.slurm container.sif
```

The PyTorch tag is the latest NGC release as of 2026-10-08. You can supply any
supported container URI and choose its SIF filename. For example:

```bash
bash scripts/nano4.sh prepare docker://ubuntu:24.04 ubuntu.sif
```

Preparation defaults to one H200 GPU, eight CPU cores, 96 GB RAM, and 30 minutes
in `dev`. Append standard `srun` options to override those defaults, for example
`--mem=128G --time=01:00:00`. Extraction, cache, and compression use
`SLURM_TMPDIR` or `/dev/shm` on the compute node. The completed SIF is copied to
`/work`, and temporary storage is cleaned. Repeated preparation reuses a SIF
with the same recorded source. Choose another filename for a different image.

`submit` accepts any local Slurm script and passes subsequent arguments to it.
Put resource requests in that script, write logs under `logs/`, and save output
artifacts under `outputs/`. The helper creates both directories before submission.
The example script runs `nvidia-smi` by default, or a command you supply:

```bash
bash scripts/nano4.sh submit cluster/nano4/smoke.slurm ubuntu.sif cat /etc/os-release
```

Choose a command installed in your chosen image. For your own workload, replace
`cluster/nano4/smoke.slurm` with your script and upload any inputs it needs.

The default remote run directory is `/work/<username>/agentic-samples`.
Set `NCHC_REMOTE_DIR` in your local shell for a different directory. **Use a
fresh directory for each new submission.** Repeating `submit` in the same
directory returns the existing job ID to prevent accidental duplicate jobs.
If submission is interrupted without a recorded ID, inspect Slurm before retrying.

```bash
export NCHC_REMOTE_DIR=/work/YOUR_SUPERCOMPUTER_ACCOUNT/my-next-run
```

Only scripts and selected results use the shared login connection. For large
input or output transfers, Nano4's data-transfer service uses port 2222 and
requires separate authentication. If a runtime needs a site module, load it in
the preparation or job script. The helper uses the lowercase Slurm account form
of your iService Project system code.

### 3. Check and download results

```bash
bash scripts/nano4.sh status
bash scripts/nano4.sh fetch
```

`fetch` downloads `logs/`, `outputs/`, and the submission record into
`results/<job-id>/`, which is ignored by Git. To retrieve other files or
folders, pass paths relative to the remote run directory:

```bash
bash scripts/nano4.sh fetch logs outputs/my-model.pt
```

The smoke test passes when its downloaded log shows an H200 GPU and Slurm
reports `COMPLETED` with exit code `0:0`. This checks GPU visibility, not PyTorch
operations. Run status queries manually. Nano4 discourages frequent polling.

```bash
bash scripts/nano4.sh exec hostname  # Optional remote command.
bash scripts/nano4.sh logout        # Close the shared connection when finished.
```

When authentication expires, run `login` again and resume. Check host driver
compatibility before running actual PyTorch/CUDA workloads.
