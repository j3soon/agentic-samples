# Nano4 container jobs

First, if you have used Nano4 before, back up any existing files you want to keep
from your home and `/work` directories to storage outside Nano4. New users can
skip this step. This workflow treats Nano4 as a non-sensitive environment.

Complete the [Nano4 credential setup](nchc-iservice.md#1-nano4-ssh-credentials)
first. Use Ubuntu, macOS, or Windows through WSL2 with Bash, OpenSSH, and rsync 3+, and
connect from a permitted IP. Native Windows OpenSSH does not support the
connection sharing used here. No local container runtime is needed.

If OpenSSH or rsync is missing, ask your agent to install it locally. On Ubuntu
or Ubuntu in WSL2, the packages are `openssh-client` and `rsync`. On macOS,
OpenSSH is normally included. Install or upgrade rsync through
[Homebrew](https://formulae.brew.sh/formula/rsync). Use rsync 3 or newer for
`--protect-args`, which preserves paths with spaces. Nano4 already provides rsync.
If installation needs an administrator password, enter it in your own terminal.

Each entry script shows its underlying commands. Open it to read, adapt, or copy
them. Shared account parsing and SSH checks live in
[helpers/ssh.sh](../scripts/nano4/helpers/ssh.sh).

| Script | Underlying commands |
|---|---|
| [configure.sh](../scripts/nano4/configure.sh) | Write account identifiers to `secrets/.env` |
| [login.sh](../scripts/nano4/login.sh) | `ssh` with `ControlMaster` and `ControlPersist` |
| [check.sh](../scripts/nano4/check.sh) | `ssh -O check` and a remote session |
| [logout.sh](../scripts/nano4/logout.sh) | `ssh -O exit` |
| [exec.sh](../scripts/nano4/exec.sh) | `ssh` with quoted command arguments |
| [prepare-sif.sh](../scripts/nano4/prepare-sif.sh) | `rsync`, `ssh`, `srun`, and the container runtime |
| [submit.sh](../scripts/nano4/submit.sh) | `rsync`, `ssh`, and `sbatch` |
| [status.sh](../scripts/nano4/status.sh) | `ssh`, `squeue`, and `sacct` |
| [download.sh](../scripts/nano4/download.sh) | `rsync` over shared SSH |

The entry scripts reuse the same account file and SSH socket. Each accepts `--help`.
Preparation uploads `remote/prepare-sif.sh` and runs it through Slurm.

## Agent workflow

Choose a host that supports YOLO or all-permissions mode. Run a
persistent cluster-hosted agent in a Slurm allocation. On a compute node, use
Slurm commands directly. The SSH scripts below are for an agent outside Nano4.

Start a local agent session in this repository and ask:

> Submit the Nano4 container smoke test.

Skills are stored in `skills/` and linked from `.agents/skills` and
`.claude/skills` for automatic discovery. You do not need to name a skill in
your request when your agent discovers it.

The agent configures access, prepares the container, submits the job, and
collects results. When authentication is needed, it asks you to run
`bash scripts/nano4/login.sh` in a separate interactive terminal. Enter your
password and MFA code into SSH, then tell the agent you are connected. Keep
these secrets out of chat and configuration files.

The terminal and agent must use the same local OS user and, on Windows, the
same WSL distribution. The agent can then reuse the SSH connection until it
closes. Command runners without an interactive terminal, including Codex
CLI's `!` runner, cannot perform this login step.

## Manual workflow

After completing the [iService setup](nchc-iservice.md), you can also run the same steps
yourself. Run all scripts locally from the repository root.

This example prepares Singularity/Apptainer images and runs Slurm jobs on Nano4.
The default job runs `nvidia-smi` inside an NVIDIA NGC PyTorch container on one
H200 GPU.

### 1. Back up existing files

If you have used Nano4 before, complete the backup described above before the
agent starts work. New users can skip this step.

### 2. Configure access

```bash
bash scripts/nano4/configure.sh YOUR_SUPERCOMPUTER_ACCOUNT YOUR_PROJECT_SYSTEM_CODE
bash scripts/nano4/login.sh
```

SSH asks for three inputs. Choose **1 (Mobile APP OTP)**, enter your
Supercomputer (machine) password, not your iService website password, then enter the current OTP from your phone:

```text
$ bash scripts/nano4/login.sh
(YOUR_SUPERCOMPUTER_ACCOUNT@nano4.nchc.org.tw) Please select the 2FA login method.
1. Mobile APP OTP
2. Mobile APP PUSH
3. Email OTP
Login method: 1
(YOUR_SUPERCOMPUTER_ACCOUNT@nano4.nchc.org.tw) Password: [enter your password]
(YOUR_SUPERCOMPUTER_ACCOUNT@nano4.nchc.org.tw) OTP: [enter your phone OTP]
Master running (pid=...)
```

The bracketed values are placeholders. Enter credentials only in your terminal.
The configuration script creates the ignored `secrets/.env` with only the
Supercomputer account and Project system code. Login manages SSH connection
sharing without changing `~/.ssh/config`.
Subsequent commands reuse the connection with no local idle expiration.
Run `logout.sh` to close it. Shutdown closes it, and sleep or network changes
may break it. Run `login.sh` again when needed.
Nano4 may disconnect it earlier. Already submitted Slurm jobs continue running.

### 3. Prepare a container and submit a job

**Run these scripts locally. Apptainer itself runs only on Nano4, inside
an allocated Slurm compute node. You do not need Apptainer or Docker locally.**

```bash
bash scripts/nano4/prepare-sif.sh docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif
bash scripts/nano4/submit.sh cluster/nano4/smoke.slurm container.sif
```

The local [prepare-sif.sh](../scripts/nano4/prepare-sif.sh) uploads
[remote/prepare-sif.sh](../scripts/nano4/remote/prepare-sif.sh), then executes it through
`srun`. The remote script contains the container build commands and can also be
run directly inside an existing compute allocation:

```bash
bash scripts/nano4/remote/prepare-sif.sh /work/YOUR_SUPERCOMPUTER_ACCOUNT/agentic-samples \
  docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif
```

The example uses NGC PyTorch `26.09-py3`. You can supply any supported
container URI and choose its SIF filename. For example:

```bash
bash scripts/nano4/prepare-sif.sh docker://ubuntu:24.04 ubuntu.sif
```

Preparation defaults to one H200 GPU allocation, 12 CPU cores, and 200G RAM
in `dev` for up to four hours, its maximum job time. These CPU and memory
requests follow the
[per-GPU partition limits](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe).
The container build uses CPU and memory. The GPU is reserved because Nano4's
H200 partitions require a GPU allocation.
For builds needing more time, use `--partition=8gpus --time=48:00:00`.

Append standard `srun` options to increase resources when the build needs more.
For example, double the allocation to two GPUs, 24 CPUs, and 400G RAM:

```bash
bash scripts/nano4/prepare-sif.sh docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif \
  --gpus-per-node=2 --cpus-per-task=24 --mem=400G
```

Extraction, cache, and compression use `SLURM_TMPDIR` or `/dev/shm` on the compute
node. The completed SIF is copied to `/work`, and temporary storage is cleaned.
Repeated preparation reuses a SIF with the same recorded source. Choose another
filename for a different image.

`submit.sh` accepts any local Slurm script and passes subsequent arguments to it.
To override its resource requests, use `submit.sh SBATCH_OPTIONS... -- JOB_SCRIPT
[JOB_ARGS...]`.
Put resource requests in that script, write logs under `logs/`, and save output
artifacts under `outputs/`. The remote submission script creates both directories
before submission.
The example script runs `nvidia-smi` by default, or a command you supply:

```bash
bash scripts/nano4/submit.sh cluster/nano4/smoke.slurm ubuntu.sif cat /etc/os-release
```

Choose a command installed in your chosen image. For your own workload, replace
`cluster/nano4/smoke.slurm` with your script and upload any inputs it needs.

The default remote run directory is `/work/<username>/agentic-samples`.
Set `NCHC_REMOTE_DIR` in your local shell for a different directory. **Use a
fresh directory for each new submission.** Repeating `submit.sh` in the same
directory returns the existing job ID to prevent accidental duplicate jobs.
If submission is interrupted without a recorded ID, inspect Slurm before retrying.

```bash
export NCHC_REMOTE_DIR=/work/YOUR_SUPERCOMPUTER_ACCOUNT/my-next-run
```

Only scripts and selected results use the shared login connection. For large
input or output transfers, Nano4's data-transfer service uses port 2222 and
requires separate authentication. If a runtime needs a site module, load it in
the preparation or job script. The submission script uses the lowercase Slurm account form
of your iService Project system code.

### 4. Check and download results

```bash
bash scripts/nano4/status.sh
bash scripts/nano4/download.sh
```

`download.sh` uses rsync over the shared SSH connection to download `logs/`,
`outputs/`, and the submission record into
`results/<job-id>/`, which is ignored by Git. To retrieve other files or
folders, pass paths relative to the remote run directory. Their directory
structure is preserved. Interrupted transfers are kept under `.rsync-partial`
so rerunning the same command can resume them:

```bash
bash scripts/nano4/download.sh logs outputs/my-model.pt
```

The smoke test passes when its downloaded log shows an H200 GPU and Slurm
reports `COMPLETED` with exit code `0:0`. This checks GPU visibility, not PyTorch
operations. Run status queries manually. Nano4 discourages frequent polling.

```bash
bash scripts/nano4/exec.sh hostname  # Optional remote command.
bash scripts/nano4/logout.sh        # Close the shared connection when finished.
```

When authentication expires, run `login.sh` again and resume. For Nano4 access
issues, ask [#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE). Ask your NVIDIA mentor for
domain-specific workload questions. Check host driver compatibility before
running actual PyTorch/CUDA workloads.

[Return to README: run jobs on Nano4](../README.md#3-run-jobs-on-nano4).
