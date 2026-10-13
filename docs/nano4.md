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

Choose a host that supports YOLO or all-permissions mode using
[agent-environments.md](agent-environments.md). Run a
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

**Use a fresh remote run directory for each new submission.** Repeating
`submit.sh` in the same directory returns its existing job ID to prevent
accidental duplicate jobs. In a single interactive terminal, export it once
and keep using that terminal:

```bash
export NCHC_REMOTE_DIR="/work/YOUR_SUPERCOMPUTER_ACCOUNT/smoke-$(date +%Y%m%d-%H%M%S)"
```

Preparation, submission, status, and download scripts require this variable.
Agent terminal tools may start a new shell for every call, so an earlier
`export` is not enough. Prefix each call with the same concrete path, for example
`NCHC_REMOTE_DIR=/work/YOUR_SUPERCOMPUTER_ACCOUNT/smoke-run-1 bash scripts/nano4/status.sh`.
Use the path actually chosen for your run, not a new timestamp on every call.

```bash
bash scripts/nano4/prepare-sif.sh docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif
bash scripts/nano4/submit.sh cluster/nano4/smoke.slurm container.sif
```

The local [prepare-sif.sh](../scripts/nano4/prepare-sif.sh) uploads
[remote/prepare-sif.sh](../scripts/nano4/remote/prepare-sif.sh), then executes it through
`srun`. The remote script contains the container build commands. If you already
have a compute allocation, you can adapt those commands there.

Preparation defaults to one H200 GPU allocation, 12 CPU cores, and 200G RAM
in `dev` for up to four hours, its maximum job time. These CPU and memory
requests follow the
[per-GPU partition limits](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe).
The container build uses CPU and memory. The GPU is reserved because Nano4's
H200 partitions require a GPU allocation.

Extraction, cache, and compression use `SLURM_TMPDIR` or `/dev/shm` on the compute
node. The completed SIF is copied to `/work`, and temporary storage is cleaned.
Repeated preparation reuses a SIF with the same recorded source. Choose another
filename for a different image.

The smoke script runs `nvidia-smi` and saves logs under `logs/`. The submission
script creates `logs/` and `outputs/` before Slurm opens the job's output files.
If submission fails without a recorded ID, follow
[submission recovery](#submission-recovery) before trying again.

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

## Submission recovery

If `submission/` exists without `submission/job-id`, the script stops instead
of risking a duplicate job. This can follow a rejected request or a lost
response after Slurm accepted it. Keep the original directory and marker.
Inspect the queue and accounting through the shared SSH connection:

```bash
bash scripts/nano4/exec.sh squeue --me --format='%.18i %.10T %.30j %Z'
bash scripts/nano4/exec.sh sacct -X --starttime today --format=JobID,State,ExitCode,WorkDir%80
```

[squeue](https://slurm.schedmd.com/squeue.html) shows current jobs.
[sacct](https://slurm.schedmd.com/sacct.html) also shows completed jobs.
Match the working directory to your original `NCHC_REMOTE_DIR`. Replace
`today` with a date before the attempt if it happened on an earlier day.
Accounting can lag, so an empty result alone does not prove rejection.

If a matching job exists, keep its ID and original run directory. Ask your
agent to restore that verified ID in `submission/job-id`, then resume status
and downloads. If the outcome remains uncertain, ask
[#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE)
before submitting again.

After confirming no job was accepted, correct the rejected request and choose
a fresh `NCHC_REMOTE_DIR` as in step 3. Prepare the image and submit there.
Keep the old marker for inspection.

## Other images and resources

These are alternatives to the main smoke test, not its next steps. Each new
job needs a fresh run directory. For example, prepare Ubuntu and print its
release information instead of running `nvidia-smi`:

```bash
export NCHC_REMOTE_DIR="/work/YOUR_SUPERCOMPUTER_ACCOUNT/ubuntu-$(date +%Y%m%d-%H%M%S)"
bash scripts/nano4/prepare-sif.sh docker://ubuntu:24.04 ubuntu.sif
bash scripts/nano4/submit.sh cluster/nano4/smoke.slurm ubuntu.sif cat /etc/os-release
bash scripts/nano4/status.sh
```

`submit.sh` accepts any local Slurm script and passes subsequent arguments to it.
Choose a command installed in your image. For your own workload, replace
`cluster/nano4/smoke.slurm` with your script and upload any inputs it needs.
Put resource requests in that script, write logs under `logs/`, and save output
artifacts under `outputs/`.
To override resource requests, use `submit.sh SBATCH_OPTIONS... -- JOB_SCRIPT
[JOB_ARGS...]`.

This hackathon focuses on H200. Use GB200 only when explicitly requested.
Hackathon projects can use `dev`, `8gpus`, `16gpus`, `32gpus`, `64gpus`,
and `gb200-dev`. Slurm dry-runs accepted all six at their maximum runtimes.
Other visible partitions, including `gb200-r1`, `gb200-r2`, and CPU-only
partitions, rejected the test project. See the
[partition table](../skills/nano4/SKILL.md#choose-a-partition) for limits
and selection guidance. GB200 needs ARM images and binaries.

For builds needing more than four hours, use `--partition=8gpus --time=48:00:00`.
Append standard `srun` options to increase resources when the build needs more.
For example, in a fresh run directory, allocate two GPUs, 24 CPUs, and 400G RAM:

```bash
bash scripts/nano4/prepare-sif.sh docker://nvcr.io/nvidia/pytorch:26.09-py3 container.sif \
  --gpus-per-node=2 --cpus-per-task=24 --mem=400G
```

[Return to README: run jobs on Nano4](../README.md#3-run-jobs-on-nano4).
