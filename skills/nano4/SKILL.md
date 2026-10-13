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
- Default to running the agent locally, on the host, in Docker, or in a
  dedicated VM. Do not run agents on Nano4 login (head) nodes. Compute nodes
  can host agents within Slurm allocations, but H200 jobs require at least one
  GPU and consume budget even while waiting for model responses. Generally
  avoid this. If explicitly requested, run the agent only within an allocated
  compute job. Use the SSH scripts for local agents to prepare containers and
  submit workloads. Release unused allocations. Choose workload
  partitions using the limits and current load below. See
  `docs/agent-environments.md` and the budget guidance in README.
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
  In a container, use a second shell in that same container. Persisted private
  homes retain credentials and settings, but recreating a container closes its
  live SSH connection. Check the shared connection after a restart and request
  login only when needed.
  The README OpenCode Docker workflow keeps the container running after agent
  exit. Relaunch OpenCode with `docker exec` to reuse the live SSH master.
  Follow README step 3's login handoff, using option 2 (Mobile APP PUSH) by
  default. Enter the machine password in the terminal and approve on the phone.
- Set `NCHC_REMOTE_DIR` to a fresh absolute directory for each new submission
  and keep using it for preparation, submission, status, and downloads. Each
  terminal tool call may start a new shell. An `export` in an earlier call does
  not carry over. Prefix every invocation with `NCHC_REMOTE_DIR=/work/USER/RUN`
  using the same concrete absolute path. The job scripts require it and stop
  when it is missing. Reuse that directory after a
  connection failure. The `submission/` marker prevents duplicate submission.
  Inspect `squeue --me` and `sacct` before resolving an uncertain submission.
  Follow `docs/nano4.md#submission-recovery`. Match the working directory before
  restoring a missing job ID. Never remove the marker or resubmit while the
  outcome is uncertain. After confirming rejection, use a fresh run directory.
- Select an image URI, SIF filename, job script, and resource requests that fit
  the user's workload. Use `prepare-sif.sh IMAGE_URI SIF_NAME [SRUN_OPTIONS...]`, then
  `submit.sh JOB_SCRIPT [JOB_ARGS...]`. Use the smoke script only for a requested
  GPU visibility test. Upload workload inputs separately as needed.
  Override Slurm resources with `submit.sh SBATCH_OPTIONS... -- JOB_SCRIPT [JOB_ARGS...]`.
- Before preparation or submission, read `cluster/nano4/excluded-nodes.txt`
  if present. This tracked file contains one unresolved suspected hostname per
  line, without comments or duplicates. `prepare-sif.sh` and `submit.sh` apply it automatically
  and merge any explicit `--exclude` options. Apply it yourself for direct Slurm
  commands. Keep it across sessions.
  Monitor downloaded logs for node-specific CUDA initialization or NCCL/network
  failures. Record each suspect's hostname, job ID, exact error, and local log
  path in ignored `artifacts/nano4-node-issues.md`, and update the node list.
  Separate confirmed observations from possible causes. A warning in a
  successful job or an unidentified failing rank is insufficient to mark every
  allocated node as bad. After confirming failure with accounting, retry in a
  fresh run directory excluding the suspects, with at most two placement retries
  before reporting the unresolved failure. Keep entries until a successful
  targeted check or administrator confirmation resolves them.
  If healthy capacity is unavailable, consider one short targeted check of a
  suspect. Keep the exclusions unless that check succeeds. A busy queue alone
  does not establish recovery.
  Before excluding a node for a missing runtime, check both Apptainer and
  Singularity, including the site Singularity module. Select the runtime on
  each allocated node. Missing Apptainer alone does not establish a node fault.
- Preparation builds in allocated node-local storage and copies the SIF to
  `/work`. Defaults are one GPU, 12 CPUs, and 200G RAM. Increase resources
  proportionally when needed, respecting per-GPU limits. The supplied workflow
  needs no local Apptainer. Recommend compute allocations for large builds to
  avoid shared login-node resource limits. Distinguish this recommendation from
  site policy. The [login-node guide](https://man.twcc.ai/@nano4-manual/BydP-_lvZg)
  also lists compilation and building as login-node functions.
  For custom images, preserve the Dockerfile or definition file and match the
  image architecture to the target nodes. Check build permissions before
  choosing a definition-file build on a local or cluster machine.
  Choose a different SIF name if an existing name has another source. If a
  runtime needs a site module, inspect and load it in the remote scripts.
- Report the job ID. Use `status.sh` for explicit requests or bounded checks, not
  tight polling. Use `download.sh [RELATIVE_PATHS...]` to download logs and artifacts
  into ignored `results/<job-id>/`. Inspect exit codes and downloaded output
  before claiming success. Reauthenticate through the user terminal as needed.
- `exec.sh COMMAND...` runs remote commands. Use `exec.sh bash -lc '...'` for shell
  syntax. `logout.sh` closes the shared connection. Otherwise it has no local
  idle expiration, but the server, network, or local machine may disconnect it.
  Closing the agent or connection does not stop submitted jobs. When requested,
  cancel the specific job with `exec.sh scancel JOB_ID` and check its status.
  Submit only jobs within the user's requested scope.
- Before ending a turn after cluster actions, run `exec.sh squeue --me`.
  Report all of this user's remaining running and pending jobs and all unresolved
  suspected nodes, with their evidence file for later administrator follow-up.
  If the queue check fails, say that the queue is unverified.

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
  A one-GPU workload needing more than four hours can use `8gpus`. Do not request
  extra GPUs or shorten the required runtime just to enter a less busy queue.
- Pass the chosen partition and resources through the scripts' Slurm options.
  Explain the choice briefly. Avoid frequent scheduler polling.
