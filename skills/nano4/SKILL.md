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
