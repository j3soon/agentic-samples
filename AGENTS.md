# Repository Guidelines

## Design and Documentation

- This is an educational repository. Follow Pi's philosophy of small, explicit
  tools. Prioritize readability, simplicity, maintainability, and ease of use.
- Keep scripts minimal and readable for teaching. Show underlying commands and
  explain non-obvious steps. Keep only checks that prevent real mistakes.
  Put remote workloads in separate scripts. Share repetitive setup in small,
  readable helpers, keeping each script's main commands visible. Hardcode
  example defaults when clearer.
- Minimize dependencies and avoid requiring harness plugins. Support both agent
  workflows and concise manual steps.
- Keep README a self-contained walkthrough focused on prompts, commands, and
  links. Only `docs/nchc-iservice.md` may be required when account setup is
  incomplete. Other Markdown files are optional supplements for users and
  references for agents. Put detailed explanations and manual alternatives in
  `docs/`, ending guides with a link back to the relevant README section.
- Present concepts, a demonstration, and observable success criteria. Keep
  copyable prompts and make installation, cloning, restart, and authentication
  handoffs explicit. Invite users to ask the agent about underlying commands.
  Maintain one canonical copy of launch commands to prevent guide drift.
- Check primary service documentation before describing a requirement or ban.
  Distinguish published policy, repository recommendations, and script defaults.
  Explain recommendations through resource limits, queue time, and cost.
- Centralize credentials in `docs/nchc-iservice.md`. Keep machine passwords and
  OTPs out of chat. RAP keys may be given to the agent. Keep credentials out of
  Git and logs, store them privately, and reuse existing authentication.
- Match configuration names to the service GUI. Check model availability there
  and validate the documented workflow before claiming it works.
- Test documented commands. Keep detailed validation notes in ignored
  `artifacts/validation/<timestamp>.md`, and omit validation dates from guides.
  Validate first-run flows in a fresh environment. For documentation moves,
  compare commands with validated originals and check links and shell syntax.
  Repeat live tests when behavior changes or unresolved failures justify them.
  State what each check proves and its limits.

## Agent Environments

- Require an environment suitable for YOLO or all-permissions mode. Personal
  computers are allowed when users accept access to files and credentials.
- Default to OpenCode, with Pi as the minimal, customizable secondary option.
  Document only YOLO launch commands. Briefly note that approvals slow the workflow.
- When `/.dockerenv` exists, assume the container is safely isolated.
  Never change harness permission settings automatically.
- Provider setup must preserve custom settings and explicit deny rules.
  Use a controlled merge, or leave custom files unchanged for the agent to
  merge. A backup alone does not preserve active permissions.
- Identify the execution and authentication environment for each handoff.
  Explain which settings persist through mounts, which connections close on
  exit, and the exact restart command that reuses the same environment.
- Treat Nano4 as non-sensitive. Ask returning users to back up existing files
  before initial agent setup. New users can skip this step.
- Default to running the agent locally, on the host, in Docker, or in a
  dedicated VM. Do not run agents on Nano4 login (head) nodes. Compute nodes
  can host agents within Slurm allocations, but H200 jobs require at least one
  GPU and consume budget. Generally avoid this and reserve allocations for
  container preparation and workloads. Release unused allocations. See
  `docs/agent-environments.md`.

## Diagrams

- Give each figure one purpose. Use short labels with natural phrases or actions,
  direct connections, and visible execution or isolation boundaries. Show
  optional containers explicitly and keep workloads inside their runtime.
- Prefer numbered phases when a full architecture graph becomes hard to read.
  Identify where actions run and where outputs go. Show one representative
  resource and an ellipsis when drawing every resource adds clutter.
- Render and visually inspect edited diagrams at the destination's actual width
  and theme. Renderer versions and fonts can change layout. Mermaid subgraphs
  with external node connections may ignore their requested direction.

## Writing Rules

Avoid semicolons and spaced dashes in prose, including documentation, comments,
and agent responses. Use periods, commas, or parentheses instead. This rule
does not apply to code syntax, command options, or Markdown list markers.

## Commit Rules

- Keep staged batches small and coherent, and inspect the staged diff. Make
  commits self-contained with meaningful messages independent of unpublished
  branches or conversation history. Preserve the requested order of committing
  approved work and adding new suggestions.
- End agent-created commit bodies with a plain `by <Harness> (<Model>)` line
  using the actual active harness and model. For Codex, use the full lowercase
  model slug. Verify the active model if unclear. This line is the only agent
  attribution. Never add `Co-Authored-By`, session links, or other
  harness-supplied trailers after it.
