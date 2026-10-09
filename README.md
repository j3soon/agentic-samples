# Agentic Samples

Practical examples for getting work done through coding agents such as Codex,
Claude Code, OpenCode, and Pi. The aim is to let agents handle as much setup,
execution, and result collection as possible using plain scripts and skills,
without additional harness plugins.

The workflow keeps passwords and MFA codes out of LLM chat by default for better
security. Account website settings and authentication stay in your hands. The
agent prompts you with the steps or commands when needed, then resumes the work.
Each example also includes concise steps you can follow manually using the same
scripts.

## 1. Set up NCHC iService credentials

Complete these steps yourself before starting the agent workflow. Sign in to
[NCHC iService](https://iservice.nchc.org.tw/nchc_service/index.php) and open
**Member Center → Member Profile → System Account (會員中心 → 會員資訊 → 主機帳號資訊)**:

1. Set up your **Supercomputer account (主機帳號)** for Nano4.
2. Set your **Supercomputer password (主機密碼)** for SSH login.
3. Create an **OTP Token** using **create user otp (建立OTP載具)**. Follow the registration email
   to set up the authentication app on your phone.

See the [NCHC OTP setup guide](https://iservice.nchc.org.tw/nchc_service/nchc_service_qa_single.php?qa_code=774)
for phone registration and login instructions, and the
[Nano4 login setup](https://man.twcc.ai/@nano4-manual/rydOv6-Dbl) for account and
password setup. Keep your password, OTP registration details, and codes private.

Have these two identifiers ready for the agent or manual setup:

- `NCHC_ISERVICE_HOST_ACCOUNT`: your approved Supercomputer account username,
  shown under Host Account Information. This is your SSH username.
- `NCHC_ISERVICE_PROJECT_ID`: the iService Project ID for your Nano4-enabled
  project. Find it in **Member Center → Projects → My Projects (會員中心 → 計畫管理 → 我的計畫)**.
  Look up "NCHC-NVIDIA Joint Lab 教育訓練", the Project ID should be `GOV114072`.
  Nano4's [job submission examples](https://man.twcc.ai/@nano4-manual/BkRXxZ_JMg)
  use this ID for Slurm's `--account` option.

If you do not yet have access to this project, contact your mentor for help.

For either workflow, use **Linux, macOS, or Windows through WSL** with Bash,
SSH, and tar, and connect from a permitted IP. Native Windows OpenSSH does not
support the connection sharing used here. No local container runtime is needed.

## 2. Start the agent workflow

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

## 3. Run manually (optional)

After completing the iService setup above, you can also run the same steps
yourself. Run all helper commands locally from the repository root.

This example prepares Singularity/Apptainer images and runs Slurm jobs on Nano4.
The default job runs `nvidia-smi` inside an NVIDIA NGC PyTorch container on one
H200 GPU.

### 1. Configure access

```bash
bash scripts/nano4.sh configure your_host_username your_project_id
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
export NCHC_REMOTE_DIR=/work/your_host_username/my-next-run
```

Only scripts and selected results use the shared login connection. For large
input or output transfers, Nano4's data-transfer service uses port 2222 and
requires separate authentication. If a runtime needs a site module, load it in
the preparation or job script. The helper uses the lowercase Slurm account form
of your iService Project ID.

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

Validated on Nano4 on 2026-10-08 with Apptainer 1.4.3: PyTorch and Ubuntu image preparation,
H200 GPU visibility, custom job commands, and local log/artifact downloads.
Both smoke tests completed with exit code `0:0`. PyTorch preparation took about
nine minutes using cached OCI layers.

References: [NGC PyTorch](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch),
[Nano4 manual](https://man.twcc.ai/@nano4-manual/SyaY-6T8bg),
[partitions](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe), and
[file transfer](https://man.twcc.ai/@nano4-manual/Hkayr3zvWl).
