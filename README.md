# Agentic Samples

[![Slack](https://img.shields.io/badge/Slack-4A154B?logo=slack&logoColor=white)](https://app.slack.com/client/T0C70DGFW02)
[![Cluster support](https://img.shields.io/badge/%23cluster--support-green)](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE)

Examples for the [NCHC Open Hackathon](https://www.openhackathons.org/s/siteevent/a0CUP00004AB2oc2AD/se000481).
This year, we focus on using coding agents to help optimize your workload.
Your role is to set the goal, provide domain knowledge, and judge the evidence.
The agent can inspect code, make changes, run experiments, and collect results.

Think of agents as a team of capable interns, available around the clock.
Give them a clear assignment, a suitable workspace, and a way to check their
work. For optimization, that means a baseline, a correctness test, and a
performance target. Your team's NVIDIA mentor can help with domain questions.

This guide follows five stages, each with a short demonstration:

1. [Understand the agent and model provider](#1-understand-the-agent-and-model-provider).
2. [Give the agent a suitable environment](#2-give-the-agent-a-suitable-environment).
3. [Check single-node GPU access on Nano4](#3-check-single-node-gpu-access-on-nano4).
4. [Run multi-node workloads on Nano4](#4-run-multi-node-workloads-on-nano4).
5. [Use NVIDIA skills for optimization](#5-use-nvidia-skills-for-optimization).

Follow this README for the complete workflow. If your Nano4 account is not set
up, also read [NCHC iService setup](docs/nchc-iservice.md). Other Markdown files
are optional supplementary material. Your agent can consult them as needed.

The guide will be updated during the event. If you encounter issues or want to
suggest improvements, feel free to tag `@Johnson Sun` in
[#cluster-support](https://nchcopenhackathon2026.slack.com/archives/C0C749A0NTE).

## 1. Understand the agent and model provider

In a chat-only exchange, a model can suggest an optimization from the text you
provide. Without access to your code and an execution environment, it cannot
run your workload or verify a speedup. A coding **harness** supplies tools for
reading files, editing code, and running terminal commands. The model uses the
results to choose its next step, forming a
[feedback loop](https://www.anthropic.com/engineering/building-effective-agents).

```mermaid
flowchart LR
    You["Your goals and success criteria"]
    Harness["Harness<br/>OpenCode"]
    Skills["Repository<br/>Instructions and skills"]
    Model["Provider and model<br/>RAP + Kimi-K3"]
    Workspace["Workspace<br/>Code and terminal"]
    You <-->|"Goals and feedback"| Harness
    Skills -->|"Guidance"| Harness
    Harness <-->|"Model API"| Model
    Harness <-->|"Tools and results"| Workspace
```

Choose these three pieces deliberately:

| Piece | What it controls | Our default |
|---|---|---|
| Provider and model | Reasoning, model capabilities, and how sent data is handled | RAP + Kimi-K3 |
| Harness | Tools, sessions, and permissions | OpenCode |
| Execution environment | Accessible files, credentials, and compute resources | A workspace you can give the agent control over |

[Codex](https://openai.com/codex/) and [Claude Code](https://code.claude.com/docs/en/overview)
are alternatives if you already have a subscription.
[Pi](https://pi.dev/) is our secondary option for a smaller, customizable harness.
Prompts describe the goal and constraints. Repository instructions and skills
provide reusable procedures, such as how to submit a Nano4 job.

The provider receives the prompts and file contents sent by the harness.
Some [OpenCode free models](https://docs.opencode.ai/docs/zen/#privacy) may use
this data to improve models, so use them for public setup examples.
For event work, we use RAP. Its
[data-protection guidance](https://rap-docs.genai.nchc.org.tw/docs/service_intro/home/#%E7%94%A8%E6%88%B6%E8%B3%87%E6%96%99%E4%BF%9D%E8%AD%B7)
says retained operational records are not used for model training and are
deleted after six months.

### Demo: start OpenCode and connect RAP

On a host you are comfortable giving the agent access to, use Ubuntu, macOS,
or Windows with WSL2. The examples need Bash, Git, OpenSSH, and rsync 3+.
If your personal machine is unsuitable, use a dedicated VM or start with the
[Docker demo below](#demo-run-the-same-agent-inside-docker), then return to
[Connect RAP in OpenCode](#connect-rap-in-opencode).

**On Ubuntu or Ubuntu in WSL2**, install the tools in your terminal first.
In a root container, omit `sudo`:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl unzip git openssh-client rsync
```

**On Ubuntu, macOS, or WSL2**, install OpenCode with its
[official installer](https://opencode.ai/docs/#install).
If already installed, use `opencode upgrade` and skip the installer:

```bash
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh && bash /tmp/opencode-install.sh
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version
```

The `export` makes OpenCode available in this terminal. Follow the installer's
shell-profile instructions to keep it available in later terminals.
On Windows, use the same Ubuntu WSL2
environment for all commands.

Start in an empty working directory. `--auto` lets the agent work without
repeated approval prompts:

```bash
mkdir -p ~/nchc-hackathon
cd ~/nchc-hackathon
opencode --auto
```

Use an available free model, selecting one with `/models` if needed. Ask:

> ```text
> Clone https://github.com/j3soon/agentic-samples.git into `.`. Check Git, OpenSSH, and rsync 3+, installing missing tools.
> ```

Enter any administrator password only in your own terminal.

After cloning, exit OpenCode with `/exit` and relaunch `opencode --auto` from
the same directory so it starts with the repository's instructions and skills.
If you already have a clone, start the agent there and skip the clone prompt.

#### Connect RAP in OpenCode

Follow this handoff in your chosen host, VM, or Docker session.
Your mentor shares your team's pre-created RAP API key in your team Slack
channel. Ask:

> ```text
> Set up OpenCode with RAP + Kimi-K3 and test image reading.
> ```

The agent can configure the provider before you have entered its key, but the
image test needs authentication. When it asks for the key, enter it locally
with `/connect` → **Other** → provider ID `nchc-rap` → your RAP API key.
You may also give this rotatable key to the agent. See
[credential entry](docs/nchc-iservice.md#enter-the-key-locally).

Exit with `/exit` and restart in the same environment to refresh provider settings:

- **Host or VM:** run `opencode --auto` again from the repository.
- **Docker:** run `docker exec -it opencode opencode --auto` in your host
  terminal. `/exit` leaves the container and its SSH connection running.
  No container restart or rebuild is needed.

Select `nchc-rap/Kimi-K3` with `/models`. In the RAP session, ask:

> ```text
> RAP is connected. Test image reading.
> ```

Continue with **RAP + Kimi-K3** for event work.
Each team starts with a **NT$20,000 RAP budget**. If you exceed it or need more,
contact your mentor. Additional budget can be requested up to **NT$40,000**.
Service rate limits still apply.

**Look for:** the repository in your working directory, RAP selected as the
provider, and a passing image-reading check. The agent should show what it
tested, rather than just say setup is complete.

## 2. Give the agent a suitable environment

You would give an intern access to the files needed for their assignment.
Apply the same judgment to an agent. On a personal machine, full permissions
can expose unrelated files and credentials. Requiring approval for every
command also slows a sequence of edits, tests, and experiments.

Choose a workspace where the agent can work independently. Running directly
on your computer is an option if you accept its access. A dedicated VM or a
Docker container lets you keep unrelated personal files outside the workspace.
Use the commands below for Docker, or the first demo's commands on your host
or dedicated VM.

```mermaid
flowchart LR
    subgraph Local["Local machine or VM"]
        direction TB
        Files["Project directory<br/>Private agent home"]
        subgraph Docker["Optional Docker container"]
            Agent["OpenCode or Pi"]
        end
        Files <-->|"Workspace and home mounts"| Docker
    end
    subgraph Remote["Nano4 cluster"]
        direction TB
        Login["Login / head node<br/>Submit and manage jobs"]
        subgraph Pool["Compute nodes (1, 2, ...)"]
            direction TB
            subgraph Compute["Allocated node"]
                subgraph SIF["Apptainer / Singularity<br/>SIF container"]
                    Workload["Your workload"]
                end
            end
        end
        Login -->|"Slurm allocation"| Pool
    end
    Local -->|"SSH to login node"| Remote
```

There are two different container roles. **Docker runs the agent locally** with
its tools and settings. **Apptainer/Singularity runs your workload on Nano4**
from a SIF image containing its dependencies. You can build that image from a
Docker registry image on allocated cluster resources, without installing the
workload's packages on the login node. Docker is optional for the local agent.
Run Nano4 workloads inside the Apptainer/Singularity container.

The agent can still change files in mounted directories. Mount only its project
and a separate private home. Container isolation controls local access, while
the selected provider's policy controls data sent to the model.

### Demo: run the same agent inside Docker

This demo is optional. If you already run the agent in a suitable container or
dedicated VM, keep that session and continue to [Nano4](#3-check-single-node-gpu-access-on-nano4).
Run Docker build and launch commands on the machine with Docker installed.
Install [Docker Engine or Docker Desktop](https://docs.docker.com/get-started/get-docker/)
on your machine first. You do not need Docker inside the agent container.

If you already have an agent and a clone, ask:

> ```text
> Build the OpenCode Docker image and show me the README launch command.
> ```

If you are starting with Docker and have no clone or agent yet, run this in
your host terminal instead:

```bash
git clone https://github.com/j3soon/agentic-samples.git ~/nchc-hackathon
cd ~/nchc-hackathon
```

From the repository root, build and launch OpenCode:
If your agent already built the image, skip the first line below.

```bash
docker build --pull --no-cache --build-arg USER_UID="$(id -u)" -t opencode docker/opencode
opencode_home=${OPENCODE_PRIVATE_HOME:-"$HOME/docker/opencode"}
mkdir -p "$opencode_home"
chmod 700 "$opencode_home"
docker run -d --init --name opencode \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  --mount "type=bind,src=$opencode_home,dst=/home/agent" \
  --entrypoint sleep opencode infinity
docker exec -it opencode opencode --auto
```

The [OpenCode Dockerfile](docker/opencode/Dockerfile) extends the
[official image](https://opencode.ai/docs/#install) with this repository's tools,
including Python and Matplotlib for plotting.
The workspace appears at `/workspace`. Set `OPENCODE_PRIVATE_HOME` to use a
different private home. The private home keeps settings, credentials, and
sessions between runs. Build with your host UID so SSH can
identify the container user. Keep unrelated personal files outside these mounts
and do not mount the Docker socket.

The container starts with its own settings and credentials. In the container's
OpenCode session, use a free model for setup and follow
[Connect RAP in OpenCode](#connect-rap-in-opencode), including key entry,
relaunching OpenCode in the same container, and testing image reading.

**Look for:** the same project available inside the container, RAP working in
that environment, and settings retained when you relaunch OpenCode.
You can now continue from this agent session.

Exit OpenCode with `/exit` and return with the `docker exec` command above.
The detached container keeps Nano4's SSH connection alive between agent
sessions. To stop it, run `docker stop opencode`. To return after stopping,
run `docker start opencode`, then the `docker exec` command. Stopping or
restarting the container closes SSH, so repeat Nano4 login when needed.

To update OpenCode or change workspace mounts, exit it and run
`docker stop opencode` and `docker rm opencode`. Rebuild when updating,
then rerun the launch block with the intended workspace and private home.
Mounted files and settings persist. `--pull` refreshes the base image and
`--no-cache` reruns installation steps.

<details>
<summary>Pi alternative (optional)</summary>

Pi is our secondary option. From the repository root in your host terminal,
build and open its container shell:

```bash
docker build --pull --no-cache --build-arg USER_UID="$(id -u)" -t pi docker/pi
mkdir -p "$HOME/docker/pi"
chmod 700 "$HOME/docker/pi"
docker run --rm -it --init --name pi --entrypoint bash \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  --mount "type=bind,src=$HOME/docker/pi,dst=/home/node" \
  pi
```

The [Pi Dockerfile](docker/pi/Dockerfile) follows
[Pi's official Docker guide](https://pi.dev/docs/latest/containerization#run-pi-in-plain-docker)
and installs the latest package when built. The setup script below backs up and
replaces Pi's model/settings files. For an existing custom configuration, ask
your current agent to merge the RAP fields instead. In a fresh container home,
configure RAP and launch Pi:

```bash
bash scripts/rap/configure-pi.sh
pi --approve
```

`--approve` trusts project resources for the session and skips the initial
trust prompt. Enter your team's RAP key with `/login` → **API key** → **NCHC RAP**,
or give the rotatable key to the agent to store privately. Reuse existing
authentication if available. The configuration selects RAP + Kimi-K3 by default.
Ask:

> ```text
> Test RAP image reading in Pi.
> ```

Continue to Nano4 below from this Pi session. Exit Pi and its shell when done.
To update, rerun the build and launch commands with the same mounts.
`--no-cache` ensures the package installation picks up the newest release.

</details>

## 3. Check single-node GPU access on Nano4

Run the agent **locally**, on your computer, in Docker, or in a dedicated VM.
It connects to Nano4 over SSH. The **login node** handles
short setup, file operations, and job management. **Slurm** allocates compute
nodes for container preparation and GPU workloads.
Nano4's [usage rules](https://man.twcc.ai/@nano4-manual/B1zWMYxv-l)
require computational work to go through Slurm.

The local agent handles three steps: prepare the SIF, run the workload,
and collect results.

```mermaid
flowchart LR
    subgraph Prepare["1. Prepare SIF"]
        direction TB
        BuildRequest["Login node<br/>Request image build"]
        Build["Compute allocation<br/>Pull registry image<br/>Convert to SIF, save to /work"]
        BuildRequest --> Build
    end
    subgraph Run["2. Run workload"]
        direction TB
        Submit["Login node<br/>Submit Slurm job"]
        Execute["Compute allocation<br/>Run workload in SIF<br/>Save results to /work"]
        Submit --> Execute
    end
    subgraph Results["3. Collect results"]
        direction TB
        Status["Login node<br/>Check job and read results"]
        Download["Local machine<br/>Download logs and outputs"]
        Status --> Download
    end
    Prepare --> Run --> Results
```

Preparation pulls a Docker/OCI image from a registry such as Docker Hub or
NVIDIA NGC, converts it to SIF on an allocated compute node, and saves it to
`/work`. The single-node GPU check uses NVIDIA NGC's PyTorch image. See
[Apptainer's registry support](https://apptainer.org/docs/user/latest/docker_and_oci.html)
for how this conversion works.

For custom dependencies, build a Docker image for H200's `linux/amd64`
architecture, [push it to Docker Hub](https://docs.docker.com/reference/cli/docker/image/push/)
or another registry, and ask the agent to convert that image to SIF.
Alternatively, build a SIF from an
[Apptainer definition file](https://apptainer.org/docs/user/latest/build_a_container.html#building-containers-from-apptainer-definition-files)
on a machine with the required build permissions. Keep the Dockerfile or
definition file as your reproducible build recipe. For large builds on Nano4,
we recommend a Slurm compute allocation to avoid login-node resource limits
and enable more parallel build work. Nano4 lists compilation and building among
[login-node functions](https://man.twcc.ai/@nano4-manual/BydP-_lvZg).

**Do not run agents on Nano4 login (head) nodes.** These nodes are for short
setup, file operations, and job management.

Running an agent on a compute node is technically feasible within a Slurm
allocation, but H200 compute jobs require at least one GPU. You spend GPU budget
even while the agent waits for a model response. We generally recommend local
execution and reserving cluster allocations for container preparation and
workloads. [Cancel unwanted jobs](#check-or-stop-a-job)
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

### Demo: check GPU access on one node with one GPU

Run `nvidia-smi` inside a PyTorch container on one H200 GPU using
[smoke.slurm](cluster/nano4/smoke.slurm). This checks that Slurm allocates the GPU
and that the container can access it. Step 4 builds on this path with actual
PyTorch training across multiple nodes.

If your Nano4 account and project access are not set up, first follow
[NCHC iService credential setup](docs/nchc-iservice.md#1-nano4-ssh-credentials).
If they are ready, continue here. The agent can guide you through setup.
Account website settings, machine passwords, and OTP entry stay in your hands.
Have your **Supercomputer account username** and **Project system code** ready.
The agent will ask for them to configure access. For the event project, the
system code is `GOV114072`. These identifiers can be shared with the agent.
If you have used Nano4 before, back up existing files you want to keep.
New users can skip this backup step.

In your chosen agent session, ask:

> ```text
> Run the Nano4 single-GPU access check and download its logs.
> ```

The agent checks local tools, configures your account identifiers, prepares the
image on allocated compute resources, submits the job, and collects results.
It reports the job ID, run directory, SIF path, and local logs. Keep the SIF path
for step 4. When it requests authentication, open a separate terminal in the
**same environment**:

- **Host or VM:** open another terminal as the same OS user and run
  `cd ~/nchc-hackathon`, or change to your existing clone.
- **OpenCode Docker:** in your host terminal, run `docker exec -it opencode bash`.
- **Pi Docker:** in your host terminal, run `docker exec -it pi bash`.

Docker shells start in `/workspace`. Run this in the chosen terminal:

```bash
bash scripts/nano4/login.sh
```

At login, choose **2 (Mobile APP PUSH)**, enter your Supercomputer machine
password (not the iService website password), then approve the request on
your phone.
Keep them out of chat. A successful login reports `Master running (pid=...)`.

After login succeeds, tell the agent:

> ```text
> Nano4 is connected. Resume the GPU check.
> ```

The agent reuses that SSH connection. A login on your host cannot automatically
authenticate an agent inside a separate container or VM.

**Look for:** a Slurm job ID, status `COMPLETED` with exit code `0:0`, and
downloaded logs showing the H200 GPU from inside the workload container. This
checks GPU visibility and the submission path, not PyTorch computation.

If SSH disconnects, run the login command again and ask the agent to resume
the same run. If submission is uncertain, ask it to inspect the queue and
accounting before retrying. This avoids accidentally submitting twice.

#### Open an interactive shell (optional)

`login.sh` keeps an authenticated SSH master running in the background.
Using the same `ControlPath` opens another shell through that connection
without repeating authentication. Run this from the repository root, as the
same local OS user and in the same host, VM, or container used for login.
Replace `YOUR_SUPERCOMPUTER_ACCOUNT` with your Nano4 username:

```bash
bash scripts/nano4/login.sh
ssh -t -p 22 \
  -o "ControlPath=$HOME/.ssh/nano4-control/%C" \
  -o ControlMaster=no -o BatchMode=yes \
  YOUR_SUPERCOMPUTER_ACCOUNT@nano4.nchc.org.tw \
  env "NANO4_EXCLUDED_NODES=$(paste -sd, cluster/nano4/excluded-nodes.txt)" bash -l
```

`login.sh` reuses a working master or asks you to authenticate in this terminal.
If SSH reports `Permission denied (keyboard-interactive)`, the master was not
reused. Run `bash scripts/nano4/check.sh` in the same environment to check it,
then rerun `login.sh` if needed. Enter passwords and approve phone requests
only through your own terminal and phone.

You are now on a **Nano4 login node**. The command carries the repository's
current node exclusions into this shell. To open a **compute-node shell**,
run the following there. It reserves one H200 GPU for up to ten minutes and
uses compute credits. Replace `gov114072` if using another project's
lowercase system code:

```bash
srun --account=gov114072 --partition=dev \
  --nodes=1 --ntasks=1 --gpus-per-node=1 --cpus-per-task=1 \
  --mem=2G --time=00:10:00 --chdir=/tmp --immediate=10 \
  ${NANO4_EXCLUDED_NODES:+--exclude="$NANO4_EXCLUDED_NODES"} \
  --pty bash -l
```

The conditional `--exclude` option avoids suspected nodes when the list is
nonempty. If resources are unavailable, the command exits after its short
allocation wait. Run `hostname` in either shell to confirm where you are.
Use `exit` to leave the compute shell and release its allocation, then `exit`
again to leave the login shell. The SSH master remains available.
If it disconnects, rerun `login.sh` locally. To close the master deliberately,
run `bash scripts/nano4/logout.sh` locally. See the
[Nano4 guide](docs/nano4.md#interactive-shells) for connection details.

#### Check or stop a job

Ask your agent:

> ```text
> Check Nano4 job JOB_ID and download its logs.
> ```

To stop an unwanted job, replace `JOB_ID` with its numeric ID and ask:

> ```text
> Cancel Nano4 job JOB_ID and check the remaining jobs.
> ```

You can also cancel it directly in the same environment, from the repository:

```bash
bash scripts/nano4/exec.sh scancel JOB_ID
```

Closing the agent, Docker container, or SSH connection does not cancel jobs.
Keep the container running while you need its shared SSH connection.

Once the single-node GPU check passes, continue to the scaling experiment below.

## 4. Run multi-node workloads on Nano4

A **weak scaling** experiment keeps work per GPU fixed. Adding GPUs increases
the total work, ideally without increasing runtime. This example trains a
Transformer on synthetic data with PyTorch DDP. It needs no dataset download
and measures performance, not model quality. GPU workers exchange gradients
within and across nodes.

| GPUs | Nodes | Global batch |
|---:|---:|---:|
| 1 | 1 | 128 |
| 8 | 1 | 1024 |
| 16 | 2 | 2048 |
| 32 | 4 | 4096 |

Each GPU handles 128 sequences per step. One measured interval follows warmup,
targeting 10 to 30 seconds and under one minute including warmup. The two-minute
Slurm limit allows startup and cleanup. Queue waits, downloads, and agent
responses take additional time.

### Demo: run, explain, and rerun

Start with the provided implementation, which reproduces a CPU allocation
issue encountered in an earlier experiment. Continue in your current agent
session and reuse the SIF from step 3. Ask:

> ```text
> Run examples/pytorch-scaling/reference/initial/train.py on Nano4 with 1, 8, 16, and 32 GPUs for a weak-scaling test. Keep the provided resource defaults.
> ```

**Look for:** four completed jobs, downloaded logs and verified checkpoints,
and a weak scaling plot. Submit the GPU configurations independently so Slurm
can run them in parallel. The [task brief](examples/pytorch-scaling/TASK.md) keeps
the workload fixed and asks the agent to preserve the baseline.

Then ask:

> ```text
> Why is scaling bad? Fix it and rerun.
> ```

**Look for:** an explanation of the CPU bottleneck, a second sweep with more
CPUs, and a comparison of timings and losses. The agent reports remaining
jobs and updates the tracked [node exclusions](cluster/nano4/excluded-nodes.txt)
when it encounters node failures. If SSH disconnects, repeat step 3's login
handoff and tell the agent to resume.

For workshops, an [optional clean workspace](docs/pytorch-scaling.md#optional-clean-workspace)
omits the optimized version and recorded results.

### Reference experiment

The [initial and optimized versions](examples/pytorch-scaling/reference/README.md)
use the same trainer. Only CPU allocation changes: **1 CPU per GPU** initially,
then **12 CPUs per GPU**, Nano4's [published H200 maximum](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe).
An eight-GPU node therefore receives 8 cores initially and 96 after the fix.

Initial scaling:

![Initial PyTorch weak scaling with 1 CPU per GPU](docs/assets/pytorch-scaling-initial.png)

Optimized scaling:

![Optimized PyTorch weak scaling with 12 CPUs per GPU](docs/assets/pytorch-scaling-optimized.png)

Weak scaling efficiency is the single-GPU time divided by the time at a larger
GPU count. Each sweep uses its own single-GPU baseline. Compare absolute times
between the two CPU settings as well as the curves.
These measurements illustrate the example. Results depend on placement and load.
The optional [reference guide](docs/pytorch-scaling.md) gives manual commands
and the measured timings.

## 5. Use NVIDIA skills for optimization

**Skills** give an agent product-specific instructions, references, and tools.
This resnet-inference example demonstrates an optimization loop followed by
an NVIDIA Nsight Systems skill review that makes the result easier to assess.

Start with [minimal ResNet-152 inference](examples/resnet-inference/01_base.py)
on 10,000 ImageNetV2 images, using pretrained weights, FP32, and batch size 1.
Continue in your current agent session and reuse the PyTorch SIF from step 3.
Keep the agent local. Run preparation, inference, and profiling on Nano4
compute nodes through Slurm. No local GPU is needed.

### Demo: measure, optimize, and review

First ask:

> ```text
> Run examples/resnet-inference/01_base.py on Nano4.
> ```

The [Slurm script](examples/resnet-inference/baseline.slurm) requests one H200
and 12 CPUs. The [workload script](examples/resnet-inference/run-baseline.sh)
prepares dependencies and downloads the inputs on the compute node.

**Look for:** a completed job, downloaded logs, images per second, top-1/top-5
accuracy, and an environment record. The original timer skips the first image.
The [task brief](examples/resnet-inference/TASK.md) requires matching timing
boundaries before comparing versions.

Then ask:

> ```text
> Optimize this code, run it on Nano4, inspect the results, and repeat until no worthwhile improvements remain.
> ```

The agent chooses libraries and tools from measurements and can discover skills
along the way. It records each attempt in `artifacts/resnet-inference/journal.md`,
including failed trials and keep-or-revert decisions. The task brief preserves
correctness and resources and sets a bounded experiment budget.

**Look for:** repeated measured experiments, a baseline-to-best comparison,
prediction-agreement checks, and a journal updated after every attempt. Treat
2× as a milestone and continue while worthwhile gains remain. Logs, source
snapshots, and reports belong under ignored `artifacts/resnet-inference/`.

Finally ask:

> ```text
> Use the Nsight Systems skill to explain the baseline and optimized execution for human review.
> ```

The agent follows the bundled skill's setup and analysis workflow and writes
`artifacts/resnet-inference/review.md`. It links evidence for retained changes,
explains failures and remaining opportunities, and gives reproduction commands.
Benchmark timings exclude profiling overhead.

**Look for:** matching baseline and optimized `.nsys-rep` files, visual timelines,
capture-health checks, and explanations tied to NVTX ranges, CUDA calls,
transfers, and GPU execution. Review correctness and added complexity alongside
the measured gain. Ask your NVIDIA mentor to review the evidence for your workload.
The optional [resnet-inference guide](docs/resnet-inference.md) gives manual commands.

### Recorded resnet-inference example

The agent discovered TensorRT's ONNX quickstart and DALI's dynamic-mode skills
during optimization. They guided engine validation and GPU preprocessing.
The Nsight Systems skill then checked the captures and reviewed the result.

On one H200 with 12 CPUs, the paired full-dataset measurements reached
**52.7× throughput**, with **99.05% prediction agreement** and **66.99%/87.22%
top-1/top-5 accuracy**. The bars show medians and ranges of three unprofiled runs:

![ResNet inference throughput across baseline, batched PyTorch, TensorRT, and DALI stages](docs/assets/resnet-inference-throughput.png)

The intermediate stages used other allocations with the same one-H200 and
12-CPU requests. Their differences also include placement and load variation.

The Nsight comparison uses **31 ms windows** from matching 256-image captures.
The baseline processes one image per batch, while TensorRT runs batches of 128
in FP16. GPU rows show recorded execution. Host NVTX ranges include waiting:

![Baseline and optimized execution in equal-duration windows](docs/assets/resnet-inference-timeline.png)

Batching and TensorRT reduce repeated launch work. Across the full captures,
GPU kernels fall from **170,240 to 748**. Deferring accuracy readback reduces
GPU-to-CPU copies from **512 to two**. DALI's GPU preprocessing appears in orange
before the blue main GPU execution.

The marked region separates four JPEG preprocessing streams. Around
**70 microseconds**, two orange kernels overlap a purple host-to-device copy:

![Concurrent JPEG kernels and a copy on separate CUDA streams](docs/assets/resnet-inference-overlap.png)

The skill's `cuda_gpu_time_util_map` recipe corroborated kernel concurrency.
The optimized crop uses the second batch, after observed library loads. This
two-batch capture shows brief preprocessing overlap. It cannot establish
sustained pipeline overlap or measure hardware SM utilization.

The final code is [dali.py](examples/resnet-inference/reference/dali.py).
The optional [recorded guide](docs/resnet-inference.md#recorded-example) gives
reproduction commands, measurements, skill sources, and limitations.
Results depend on hardware, load, and the accuracy contract.

## Appendix: NVIDIA skills

NVIDIA publishes skills for its tools and CUDA-X libraries. Some are bundled
with the product, such as Nsight Systems' analysis pack. Others live in product
repositories. Availability and APIs depend on the installed version.

| Skill | What it helps the agent do | Official source |
|---|---|---|
| `nsight-systems` | Capture CUDA/NVTX activity, check reports, and explain execution | [Bundled Nsight Systems pack](https://docs.nvidia.com/nsight-systems/AnalysisGuide/#ai-assisted-analysis) |
| `trt-onnx-quickstart` | Build a TensorRT engine from ONNX and verify numerical agreement | [TensorRT repository](https://github.com/NVIDIA/TensorRT/tree/main/.agents/skills/trt-onnx-quickstart) |
| `dali-dynamic-mode` | Develop GPU data preprocessing with DALI's imperative API | [DALI repository](https://github.com/NVIDIA/DALI/tree/main/skills/dali-dynamic-mode) |

You do not always need to find and install skills yourself. An agent can discover
their readable `SKILL.md` files while inspecting installed tools or exploring
official documentation. Discovery depends on its tools and the available sources.
Ask it to report which skills it actually read or followed. Ordinary documentation
lookup alone does not establish skill use. Referenced scripts and dependencies
must also be available when the pack requires them.

[NVIDIA/skills](https://github.com/NVIDIA/skills) is a broader discovery catalog,
including guidance across NVIDIA products and mirrored product skills.
Ask your agent:

> ```text
> Find NVIDIA skills relevant to this workload.
> ```

You can point the agent directly at a skill directory. The corresponding library,
profiler, and runtime still need to be prepared in the workload environment.

## Optional supplementary material

If you want to understand the underlying commands, ask your agent directly:

> ```text
> Explain the commands you used and where to find them.
> ```

To document the session:

> ```text
> Review our full conversation history and document the process as a standalone HTML report. Serve it and share the URL with me.
> ```

To check the work with independent reviewers:

> ```text
> Launch subagents for adversarial review. Verify their findings, fix worthwhile issues, and validate the changes.
> ```

Bun's [rewrite with Claude](https://bun.com/blog/bun-in-rust#adversarial-review)
used separate contexts for implementation and adversarial review.

The walkthrough above is sufficient for getting started. Read these when you
want more detail or manual alternatives:

- [Agent environments](docs/agent-environments.md): permissions, isolation,
  installation alternatives, and why the Docker mounts are scoped this way.
- [RAP](docs/rap.md): provider configuration, privacy details, and image tests.
- [Nano4](docs/nano4.md): manual Slurm commands, resource choices, and recovery.
- [PyTorch scaling reference](docs/pytorch-scaling.md): initial and optimized
  versions, manual commands, and CPU allocation comparisons.
- [ResNet inference](docs/resnet-inference.md): manual Nano4 commands and
  profiling guidance.

## Your role

Agents are getting better at doing the work, but you're still responsible for
the result. You don't need to understand every line, but you should be able to
explain how the pieces fit together, what the important parts do, and where a
speedup comes from. Check their explanations against the code, tests, and
measurements.

Agents can still make mistakes or take
[costly detours](https://www.anthropic.com/engineering/building-effective-agents).
Your experience helps you set priorities, spot wrong turns, and keep time and
cost under control. Give the agent room to work out the details and challenge
your assumptions.

After a big change, ask what changed, why, how it was checked, and what's still
uncertain. Keep [asking questions and working through explanations](https://www.anthropic.com/research/AI-assistance-coding-skills)
until you can explain it in your own words. Use each task as a chance to learn
more about how your code works.
