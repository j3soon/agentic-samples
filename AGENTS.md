# Repository Guidelines

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
