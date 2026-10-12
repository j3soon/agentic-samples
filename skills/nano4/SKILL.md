---
name: nano4
description: Prepare container images, submit Slurm jobs, and download results on NCHC Nano4 using shared SSH access, without local container tools or harness plugins.
---

# Nano4 jobs

Use `scripts/nano4.sh` from the repository root. Read `README.md` for access,
resource defaults, and command usage. Requires Bash and OpenSSH locally on
Linux/macOS/WSL. Container preparation runs on Nano4 through Slurm.

- Handle setup and jobs with the helper. When the user must change account
  website settings or run a command manually, explain why and give the exact
  steps or command. Resume after they confirm completion. Never ask them to
  paste passwords or OTP codes into chat. Use their own terminal for login.
- If `secrets/.env` is missing or incomplete, ask for the host username and
  iService Project system code, then run `configure USER PROJECT`. Keep passwords and
  OTP codes out of chat and files.
- Run `check`. When authentication is needed, ask the user to run
  `bash scripts/nano4.sh login` in a separate interactive terminal under the
  same OS user and environment as the agent. On Windows use the same WSL
  distribution. Codex CLI's `!` runner does not provide the required terminal.
  After the user authenticates, verify with `check` and `exec hostname`.
- Set `NCHC_REMOTE_DIR` to a fresh absolute directory for each new submission
  and keep using it for status and downloads. Reuse that directory after a
  connection failure. The `submission/` marker prevents duplicate submission.
  Inspect `squeue --me` and `sacct` before resolving an uncertain submission.
- Select an image URI, SIF filename, job script, and resource requests that fit
  the user's workload. Use `prepare IMAGE_URI SIF_NAME [SRUN_OPTIONS...]`, then
  `submit JOB_SCRIPT [JOB_ARGS...]`. Use the smoke script only for a requested
  GPU visibility test. Upload workload inputs separately as needed.
- Preparation builds in allocated node-local storage and copies the SIF to
  `/work`. Do not run local Apptainer or extract layers on the login node.
  Choose a different SIF name if an existing name has another source. If a
  runtime needs a site module, inspect and load it in the remote scripts.
- Report the job ID. Use `status` for explicit requests or bounded checks, not
  tight polling. Use `fetch [RELATIVE_PATHS...]` to download logs and artifacts
  into ignored `results/<job-id>/`. Inspect exit codes and downloaded output
  before claiming success. Reauthenticate through the user terminal as needed.
- `exec COMMAND...` runs remote commands. Use `exec bash -lc '...'` for shell
  syntax. `logout` closes the shared connection. Otherwise it has no local
  idle expiration, but the server, network, or local machine may disconnect it.
  Submit only jobs within the user's requested scope.
