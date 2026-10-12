---
name: nano4
description: Prepare container images, submit Slurm jobs, and download results on NCHC Nano4 using shared SSH access, without local container tools or harness plugins.
---

# Nano4 jobs

Run the standalone scripts in `scripts/nano4/` from the repository root.
Read `docs/nano4.md` for access, resource defaults, and command usage. Account
setup is in `docs/nchc-iservice.md`. Requires Bash and OpenSSH on Linux/macOS/WSL. Container preparation runs on Nano4 through Slurm.
Check local Bash, OpenSSH, and rsync 3+ before Nano4 operations. Install missing
tools with the local package manager when needed. Administrator passwords stay
in the user's own terminal. Rsync reuses the authenticated SSH master.


- Before initial setup, ask returning users to back up existing files they want
  to keep. New users can skip this step. Treat Nano4 as non-sensitive, with
  OpenCode as the default agent. YOLO or all-permissions mode is a prerequisite.
  The user chooses the mode, and scripts do not change permissions automatically.
- For a cluster-hosted agent, follow `docs/agent-environments.md`. Run the agent
  in a Slurm allocation. A long-running H200 agent uses `8gpus` with one GPU,
  two CPU cores, and 8 GB RAM, for up to 48 hours. Choose workload partitions
  using the limits and current load below. Use direct Slurm commands from
  compute nodes rather than adding an SSH hop, and submit workloads with `sbatch`.
- Handle setup and jobs with the standalone scripts. When the user must change account
  website settings or run a command manually, explain why and give the exact
  steps or command. Resume after they confirm completion. Never ask them to
  paste passwords or OTP codes into chat. Use their own terminal for login.
- If `secrets/.env` is missing or incomplete, ask for the Supercomputer account username and
  iService Project system code. Run `bash scripts/nano4/configure.sh ACCOUNT SYSTEM_CODE`.
  Keep passwords and OTP codes out of chat and files.
- Run `bash scripts/nano4/check.sh`. When authentication is needed, ask the user to run
  `bash scripts/nano4/login.sh` in a separate interactive terminal under the
  same OS user and environment as the agent. On Windows use the same WSL
  distribution. Codex CLI's `!` runner does not provide the required terminal.
  After the user authenticates, verify with `check.sh` and `exec.sh hostname`.
- Set `NCHC_REMOTE_DIR` to a fresh absolute directory for each new submission
  and keep using it for status and downloads. Reuse that directory after a
  connection failure. The `submission/` marker prevents duplicate submission.
  Inspect `squeue --me` and `sacct` before resolving an uncertain submission.
- Select an image URI, SIF filename, job script, and resource requests that fit
  the user's workload. Use `prepare-sif.sh IMAGE_URI SIF_NAME [SRUN_OPTIONS...]`, then
  `submit.sh JOB_SCRIPT [JOB_ARGS...]`. Use the smoke script only for a requested
  GPU visibility test. Upload workload inputs separately as needed.
  Override Slurm resources with `submit.sh SBATCH_OPTIONS... -- JOB_SCRIPT [JOB_ARGS...]`.
- Preparation builds in allocated node-local storage and copies the SIF to
  `/work`. Defaults are one GPU, 12 CPUs, and 200G RAM. Increase resources
  proportionally when needed, respecting per-GPU limits. Do not run local
  Apptainer or extract layers on the login node.
  Choose a different SIF name if an existing name has another source. If a
  runtime needs a site module, inspect and load it in the remote scripts.
- Report the job ID. Use `status.sh` for explicit requests or bounded checks, not
  tight polling. Use `download.sh [RELATIVE_PATHS...]` to download logs and artifacts
  into ignored `results/<job-id>/`. Inspect exit codes and downloaded output
  before claiming success. Reauthenticate through the user terminal as needed.
- `exec.sh COMMAND...` runs remote commands. Use `exec.sh bash -lc '...'` for shell
  syntax. `logout.sh` closes the shared connection. Otherwise it has no local
  idle expiration, but the server, network, or local machine may disconnect it.
  Submit only jobs within the user's requested scope.

## Choose a partition

Check the [Nano4 partition guide](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe)
and live Slurm settings before planning resources. The published limits are:

| Partition | Hardware | Minimum GPUs | Maximum hours | GPUs per account | Running/pending jobs per user | Hackathon access |
|---|---|---:|---:|---:|---:|---|
| `dev` | H200 (x86_64) | 1 | 4 | 32 | 10/10 | Yes |
| `8gpus` | H200 (x86_64) | 1 | 48 | 32 | 8/10 | Yes |
| `16gpus` | H200 (x86_64) | 8 | 48 | 32 | 6/8 | Yes |
| `32gpus` | H200 (x86_64) | 16 | 24 | 32 | 4/6 | Yes |
| `64gpus` | H200 (x86_64) | 32 | 24 | 64 | 2/4 | Yes |
| `gb200-dev` | GB200 (aarch64) | 1 | 2 | 2 | 2/2 | Yes |
| `gb200-r1` | GB200 (aarch64) | 16 | 24 | 32 | 2/2 | No |
| `gb200-r2` | GB200 (aarch64) | 32 | 12 | 72 | 1/2 | No |

Hackathon access was checked with `sbatch --test-only` using the test project.
All six accessible partitions accepted requests at their maximum runtimes.
`gb200-r1`, `gb200-r2`, and all other visible partitions rejected the project,
including CPU-only partitions. Dry-runs check scheduler acceptance without
allocating resources. Recheck access if the project or cluster policy changes.

H200 allows at most 12 CPU cores and 200 GB RAM per GPU. GB200 requires ARM
binaries and images. Prepare them on `gb200-dev`, not an x86_64 login node.
The GB200 production partitions keep jobs within one rack.

- Use H200 for this hackathon. Use GB200 only when the user explicitly requests it.
- Filter partitions by account/QoS access, GPU count, architecture, runtime,
  and remaining account and user limits. Do not infer limits from partition names.
- Take one load snapshot with `sinfo -s` and `squeue`, and inspect
  `scontrol show partition`. For GPU capacity, compare `CfgTRES` and `AllocTRES`
  in `scontrol show nodes`. Mixed nodes can still have GPUs available.
- Among compatible partitions, prefer the shortest expected wait. If unclear,
  use `sbatch --test-only` with the actual account, resources, and time limit for
  the candidate partitions. Estimates can change and do not guarantee a start.
- Prefer `dev` for short H200 setup and tests when its wait is suitable.
  A one-GPU H200 agent needing more than four hours uses `8gpus`. Do not request
  extra GPUs or shorten the required runtime just to enter a less busy queue.
- Pass the chosen partition and resources through the scripts' Slurm options.
  Explain the choice briefly. Avoid frequent scheduler polling.
