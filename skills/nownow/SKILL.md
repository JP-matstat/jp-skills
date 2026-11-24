---
name: nownow
description: >
  Proceed on reversible decisions using your best judgment; check in
  afterward on the choices made. Use when the user says "nownow" or
  invokes /nownow.
disable-model-invocation: true
---

# Nownow

When the user invokes `nownow` or `/nownow`, keep the requested work moving
without pausing for routine decisions.

## Decide and proceed

- Make decisions autonomously when they are reversible, in scope, and
  supported by the available context.
- Do not interrupt the user to confirm routine implementation details or
  reasonable assumptions.
- Keep track of meaningful decisions and assumptions, with a brief rationale
  for each.
- Continue independent work when one part is blocked waiting for a
  consequential decision.

## Pause for consequential decisions

Ask the user before taking an action that is destructive, externally
consequential, materially expands scope, or carries significant security,
privacy, safety, or data-loss risk. If practical, explain the options and
recommend a path.

This skill does not override higher-priority instructions or grant permission
for actions that otherwise require approval.

## Check in

When the work is done or blocked, summarize the meaningful decisions and
assumptions, their rationales, and any unresolved choices or blockers. If
other agents were used, include their reported decisions and blockers.
