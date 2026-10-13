# Choose where to run the agent

**Prerequisite:** choose an environment where you are willing to enable YOLO
or all-permissions mode. This lets the agent work without repeated permission
prompts. It can modify or delete accessible files and use available credentials.
A personal computer is allowed if you accept this access.

Use OpenCode by default. Pi is the secondary option for technical users who want
a minimal core and custom workflows. Its [official positioning](https://pi.dev/) emphasizes
extensibility through skills, extensions, prompt templates, and themes. This is
our recommended audience for Pi's smaller core and customization options.
No extra Pi package or harness plugin is needed for these examples.

## Install OpenCode on Ubuntu

Start here on a fresh Ubuntu host or Ubuntu in WSL2. Install the tools before
asking the agent to clone the repository or access Nano4. In a root container,
omit `sudo` from the first two commands:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl unzip git openssh-client rsync
curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh && bash /tmp/opencode-install.sh
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version
```

These use the [official installer](https://opencode.ai/docs/#install).
The explicit `export` makes the binary available immediately, including when
the installer finds no existing shell profile. Follow its profile instructions
to keep the command available in later terminals. Downloading the installer
before running it makes a failed download visible. If OpenCode is already
installed, update it with `opencode upgrade`.

If you already have Node.js and npm, the official npm installation is another
option:

```bash
npm install -g opencode-ai
opencode --version
```

Then [start OpenCode from this repository](../README.md#1-set-up-a-local-agent-and-rap).
Docker users can instead follow the
[container launch commands](#launch-opencode-or-pi-in-docker) below.

## Launch the agent

Enable YOLO or all-permissions mode in your chosen environment. No repository
script selects these modes automatically. Choose one client.

**OpenCode (default):**

```bash
opencode --auto
```

**Pi (secondary option):**

```bash
pi --approve
```

If you already use Codex, launch with `codex --yolo`. For Claude Code, use
`claude --dangerously-skip-permissions`.
Codex and Claude Code skip permission prompts in these modes. Codex also disables
its sandbox. OpenCode calls this mode `--auto` and still respects explicit deny
rules. Pi runs tools without per-call approvals. `--approve` trusts project
resources for this session and skips the initial project trust prompt. See
[Codex CLI](https://developers.openai.com/codex/cli/reference),
[Claude Code CLI](https://code.claude.com/docs/en/cli-reference),
[OpenCode permissions](https://opencode.ai/docs/permissions/), and
[Pi](https://pi.dev/).

Use one of these four environments. The scripts need Bash. Nano4 access needs
OpenSSH and rsync 3+. The agent can install missing tools locally. On Windows, run these
scripts and the agent in the same WSL2 distribution.

| Environment | Recommended approach |
|---|---|
| Personal computer (macOS, Windows, or Ubuntu) | Enable YOLO mode if you accept access to personal files and credentials |
| Container on a personal computer | Default to OpenCode, with Pi as a secondary option |
| Dedicated VM or disposable machine | Default to OpenCode, with Pi as a secondary option |
| Nano4 compute allocation | Treat as non-sensitive. Default to OpenCode, with Pi as a secondary option |

## 1. Personal computer

You can use your personal computer for this workflow if you accept the access
described above. A container or dedicated VM is another option.

Approval prompts suit sensitive environments but make this workflow much less
efficient.

## 2. Container on a personal computer

Use a container to give the agent a dedicated workspace and its own settings.
The launch commands below mount only the repository and a separate private home.
Files in these mounts remain writable by the agent and survive container removal.
Keep unrelated personal files outside the mounts. Do not mount your whole home
or the Docker socket into the agent container.

The user chooses the harness and permission mode. No repository script
automatically disables approvals. A container still sends model requests to the
selected provider, so choose its data policy separately.

### Launch OpenCode or Pi in Docker

If you are starting with Docker and have not cloned the repository yet, clone
it from your terminal first:

```bash
git clone https://github.com/j3soon/agentic-samples.git ~/nchc-hackathon
cd ~/nchc-hackathon
```

After cloning the repository, run these commands from its root on Linux,
macOS, or Windows through WSL2.
Install [Docker](https://docs.docker.com/get-started/get-docker/) first.
Each image contains one agent and the tools for this repository.
Build with your host UID so SSH can identify the container user.
Mount the project and a separate private home to keep settings, credentials,
and sessions between runs.

**OpenCode:** [Dockerfile](../docker/opencode/Dockerfile), based on the
[official OpenCode Docker image](https://opencode.ai/docs/#install).

```bash
docker build --pull --no-cache --build-arg USER_UID="$(id -u)" -t opencode docker/opencode
mkdir -p "$HOME/docker/opencode"
chmod 700 "$HOME/docker/opencode"
docker run --rm -it --init --name opencode \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  --mount "type=bind,src=$HOME/docker/opencode,dst=/home/agent" \
  opencode --auto
```

OpenCode starts in `/workspace` with the repository's instructions. Use an
available free model for setup, then follow
[manual RAP setup](rap.md#manual-setup) for key entry,
restart, and the image-reading test before continuing to Nano4.

**Pi:** [Dockerfile](../docker/pi/Dockerfile), following
[Pi's plain Docker guide](https://pi.dev/docs/latest/containerization#run-pi-in-plain-docker).

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

In the Pi container shell, follow [manual RAP setup](rap.md#manual-setup),
then launch `pi --approve` and enter your key through `/login` if needed.
`--approve` trusts project resources for this session. Each container home
starts with separate credentials from your host agent.

For setup commands or Nano4 login, open a second terminal in the same container:

```bash
docker exec -it opencode bash
# For Pi instead: docker exec -it pi bash
```

Run `bash scripts/nano4/login.sh` there when the agent requests authentication.
Keep the container running while the agent works. Stopping it closes its SSH
connection, while submitted Slurm jobs continue. Closing the container does not
cancel cluster jobs.
OpenCode uses the official
`latest` image, and Pi installs the current release when built. Update them by
rebuilding. `--pull` refreshes the base images. `--no-cache` reruns installation
steps so Pi picks up the newest package:

```bash
docker build --pull --no-cache --build-arg USER_UID="$(id -u)" -t opencode docker/opencode
docker build --pull --no-cache --build-arg USER_UID="$(id -u)" -t pi docker/pi
```

## 3. Dedicated VM or disposable machine

A dedicated VM can run OpenCode directly without another container. Pi is the
secondary choice for users who prefer a smaller, customizable harness. Use the
launch commands above. Keep unrelated files and credentials off the VM.

## 4. Nano4 compute allocation

First, if you have used Nano4 before, back up any existing files you want to keep
from your home and `/work` directories to storage outside Nano4. New users can
skip this step. This workflow treats Nano4 as a non-sensitive environment.
Use OpenCode by default, with Pi as a secondary option. Its Linux x64 binary
runs directly on H200 compute nodes. The agent does not need Docker or Apptainer.

Run persistent agents on allocated compute resources. Reserve the login node
for short setup, file operations, and job management. This repository does not
run long-lived agents there. Nano4's [usage rules](https://man.twcc.ai/@nano4-manual/B1zWMYxv-l)
require computational work to run through Slurm and discourage frequent status
polling. They do not publish a specific `tmux` lifetime limit.

An agent calling remote model APIs generally needs CPU and memory rather than a
local GPU. Hackathon projects cannot use the CPU-only partitions. The accessible H200
partitions require at least one GPU per job. For long-running
agents, use `8gpus` with one GPU, two CPU cores, and 8 GB RAM. Request the time
needed, up to 48 hours. Use `dev` for short setup and tests, up to 4 hours.
Check the current [partition limits](https://man.twcc.ai/@nano4-manual/SJM_FuxDWe)
before choosing resources.

From a Nano4 login shell, request a compute shell first:

```bash
srun --account=gov114072 --partition=8gpus \
  --nodes=1 --ntasks=1 --gpus-per-node=1 \
  --cpus-per-task=2 --mem=8G --time=08:00:00 --pty bash -l
```

Use your Project system code in lowercase for `--account`, and adjust resources
and time for the task. Start the installed agent from that compute shell after
choosing its permission mode. For laptop-independent execution, submit the
agent command in an `sbatch` job and save logs under `/work`.

`tmux` can preserve a terminal session, but does not extend the allocation or
make a login-node workload appropriate. A compute-node session may end when
its allocation expires. A batch job can continue after your laptop disconnects,
up to its time limit. Submit separate training workloads through `sbatch`.
An agent on a compute node can call `sbatch` directly. Slurm gives each new job
its own allocation, which may use another node. Use `--nodelist` only when the
job must run on a particular node. To run a command within the agent's existing
allocation, use `srun`. Use `--overlap` only when intentionally sharing resources
with another job step. See [sbatch](https://slurm.schedmd.com/sbatch.html) and
[srun](https://slurm.schedmd.com/srun.html).
See [Nano4 job setup](nano4.md) for the underlying commands.

## Authentication in the chosen environment

Enter Nano4 machine passwords and OTPs in your own terminal in the same
environment as the agent. RAP API keys may be given to the agent. A laptop's SSH control socket cannot automatically be
reused inside a different container, VM, or cluster node. Do not expose your
whole home directory just to reuse credentials.

When the agent already runs on Nano4, use Slurm commands directly rather than
adding an SSH hop back to the login node. Account and API credential setup is
in [nchc-iservice.md](nchc-iservice.md).

[Continue in README: set up a local agent and RAP](../README.md#1-set-up-a-local-agent-and-rap).
