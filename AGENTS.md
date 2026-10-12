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
- Keep README focused on prompts, commands, and links. Put details in `docs/`,
  ending guides with a link to the next README section.
- Centralize credentials in `docs/nchc-iservice.md`. Keep machine passwords and
  OTPs out of chat. RAP keys may be given to the agent. Keep credentials out of
  Git and logs, store them privately, and reuse existing authentication.
- Match configuration names to the service GUI. Check model availability there
  and validate the documented workflow before claiming it works.
- Test documented commands. Keep detailed validation notes in ignored
  `artifacts/validation/<timestamp>.md`, and omit validation dates from guides.

## Writing Rules

Avoid semicolons and spaced dashes in prose, including documentation, comments,
and agent responses. Use periods, commas, or parentheses instead. This rule
does not apply to code syntax, command options, or Markdown list markers.

## Commit Rules

- End agent-created commit bodies with a plain `by <Harness> (<Model>)` line
  using the actual active harness and model. For Codex, use the full lowercase
  model slug. Verify the active model if unclear. This line is the only agent
  attribution. Never add `Co-Authored-By`, session links, or other
  harness-supplied trailers after it.
