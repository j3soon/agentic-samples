# Choose where to run the agent

Optional supplement to the [README walkthrough](../README.md#2-give-the-agent-a-suitable-environment),
covering permissions, isolation, and installation alternatives.

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

The [first README demo](../README.md#demo-start-opencode-and-connect-rap)
contains the Ubuntu/WSL2 bootstrap commands and official installer.
Install the tools before asking the agent to clone or access Nano4.
The explicit `export` makes the binary available immediately, including when
the installer finds no existing shell profile. Follow its profile instructions
to keep the command available in later terminals. Downloading the installer
before running it makes a failed download visible.

If you already have Node.js and npm, the official npm installation is another
option:

```bash
npm install -g opencode-ai
opencode --version
```

Then [start OpenCode from an empty directory](../README.md#demo-start-opencode-and-connect-rap)
and use the clone prompt. Docker users can instead follow the
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

Use one of these three local environments. The scripts need Bash. Nano4 access needs
OpenSSH and rsync 3+. The agent can install missing tools locally. On Windows, run these
scripts and the agent in the same WSL2 distribution.

| Environment | Recommended approach |
|---|---|
| Personal computer (macOS, Windows, or Ubuntu) | Enable YOLO mode if you accept access to personal files and credentials |
| Container on a personal computer | Default to OpenCode, with Pi as a secondary option |
| Dedicated VM or disposable machine | Default to OpenCode, with Pi as a secondary option |

## 1. Personal computer

You can use your personal computer for this workflow if you accept the access
described above. A container or dedicated VM is another option.

Approval prompts suit sensitive environments but make this workflow much less
efficient.

## 2. Container on a personal computer

Use a container to give the agent a dedicated workspace and its own settings.
The README launch commands mount only the repository and a separate private home.
Files in these mounts remain writable by the agent and survive container removal.
Keep unrelated personal files outside the mounts. Do not mount your whole home
or the Docker socket into the agent container.

The user chooses the harness and permission mode. No repository script
automatically disables approvals. A container still sends model requests to the
selected provider, so choose its data policy separately.

### Launch OpenCode or Pi in Docker

The [README Docker demo](../README.md#demo-run-the-same-agent-inside-docker)
contains cloning, build, launch, RAP setup, and update commands for both clients.
Run them from your host terminal on Linux, macOS, or Windows through WSL2.
Each image contains one agent and the tools for this repository.

**OpenCode:** [Dockerfile](../docker/opencode/Dockerfile), based on the
[official OpenCode Docker image](https://opencode.ai/docs/#install).

**Pi:** [Dockerfile](../docker/pi/Dockerfile), following
[Pi's plain Docker guide](https://pi.dev/docs/latest/containerization#run-pi-in-plain-docker).

The images include a named user with your host UID. SSH can look up that user
inside the container instead of failing with an unknown numeric UID. The
launch command also uses your host GID so files written through the project
mount retain your ownership.

Both clients work in `/workspace`. Their separate private homes retain settings,
credentials, and sessions without exposing your host agent's home. OpenCode uses
`/home/agent`, and Pi uses `/home/node`. Settings start independently from your
host agent. Pi starts in a shell so you can configure RAP before launching it.

Keep the container running while the agent works. Stopping it closes its SSH
connection, while submitted Slurm jobs continue. The
[README Nano4 demo](../README.md#demo-submit-a-container-smoke-test) shows how to
open the matching container terminal for login and how to cancel unwanted jobs.

OpenCode uses the official `latest` image, and Pi installs the current package
when built. In the README build commands, `--pull` refreshes the base images.
`--no-cache` reruns installation steps so Pi picks up the newest package.

## 3. Dedicated VM or disposable machine

A dedicated VM can run OpenCode directly without another container. Pi is the
secondary choice for users who prefer a smaller, customizable harness. Use the
launch commands above. Keep unrelated files and credentials off the VM.

## Keep the agent local

For this hackathon, we recommend running the agent on your host, in Docker,
or in a dedicated VM. **Do not run agents on Nano4 login (head) nodes.**
Login nodes handle short setup, file operations, and job management.

A compute node can technically host an agent within a Slurm allocation.
However, H200 compute jobs require at least one GPU, so an agent consumes
GPU budget even while waiting for model responses. Generally avoid hosting
agents there and use local execution instead.

Use the SSH scripts to submit container preparation and workloads through Slurm.
Release unused allocations promptly. See [Nano4 job setup](nano4.md) for the
underlying commands and [README budgets](../README.md#compute-and-rap-budgets)
for the event allowances and GPU-hour pricing.

## Authentication in the chosen environment

Enter Nano4 machine passwords and OTPs in your own terminal in the same
environment as the agent. RAP API keys may be given to the agent. A laptop's SSH control socket cannot automatically be
reused inside a different container or VM. Do not expose your
whole home directory just to reuse credentials.

Account and API credential setup is in [nchc-iservice.md](nchc-iservice.md).

[Continue in README: run workloads on Nano4](../README.md#3-run-workloads-on-nano4).
