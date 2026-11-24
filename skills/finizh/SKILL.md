---
name: finizh
description: Check whether the session's requested work is complete. If not, report remaining tasks, or write one handoff per task with `ho` — and with `ho s`, start a fresh agent for every handoff in its own tab and clone. If complete, commit and push the session's work when possible.
argument-hint: "[ho [s]]"
disable-model-invocation: true
---

# Finizh

When invoked as `finizh` or `/finizh`, audit whether relevant work in this session remains. This is a user-invoked closing workflow, not permission to perform unfinished tasks.

The argument decides what happens to the remaining work:

| Invocation | What to do |
|---|---|
| `finizh` | Return the remaining tasks as a numbered list. Change nothing. |
| `finizh ho` | Write one handoff document per remaining task, list them, then complete and sync the session. |
| `finizh ho s` | Write the handoffs, complete and sync the session **first**, then start one fresh agent per handoff (`ho1`, `ho2`, …) in its own tab and clone. |

## 1. Audit the session

Review the user's requests and decisions in this session, then check relevant artifacts, validation results, and the worktree as needed.

- Count only requested or clearly agreed work. Do not turn brainstorms, rejected ideas, or optional suggestions into unfinished tasks.
- Identify work that is genuinely incomplete, including requested implementation, validation, documentation, or follow-up decisions.
- Do not list work that is already complete or verified.
- Check repository state before deciding what can be committed. Distinguish this session's changes from pre-existing or unrelated changes; never include unrelated work in a commit.
- If attribution or status is unclear, report the uncertainty as remaining work instead of guessing.

## 2. If work remains

Without the `ho` argument, return a concise numbered list of the remaining tasks, each phrased as a concrete next action. Do not begin those tasks or commit and push.

If the argument is exactly `ho` (for example, `finizh ho` or `/finizh ho`):

- Write one handoff document for each remaining task, then return a list with one descriptive handoff name and path per line. Do not return the numbered task list.
- Number the handoffs `ho1`, `ho2`, … in the order you list them, one line each in the form `ho1 — <title> — <path>`. The numbers are how `ho s` later starts the agents, so they must be stable and match the list.
- Continue to the completion procedure afterward: handing off the remaining work completes this session's work.

Save handoffs in the operating system's temporary directory, not in the repository. Use descriptive, filesystem-safe filenames such as `finizh-add-forecast-metric.md`.

Each handoff must be independently usable by a fresh agent that starts in its own clone with no memory of this conversation: state the specific objective, relevant context and decisions, current progress, concrete next steps, constraints, and any required validation. Link to existing artifacts instead of copying their contents. Omit secrets and unrelated conversation details.

With `ho`, create at least one handoff. If the audit finds no remaining tasks, create a single session-complete handoff that records the outcome and relevant artifacts, and states that no follow-up work remains.

## 3. Complete and sync the session

Run this procedure when no work remains or after creating handoffs with `ho`. Commit and push the completed work from this session when possible, even when future tasks have been handed off.

With `ho s`, run this procedure **before** starting any agent: `scripts/session.sh new` clones `origin/main`, so anything still unpushed is invisible to the agents. If the work cannot be committed or pushed, do not start agents on a stale base — report what needs the user's decision.

- Inspect the worktree and diff. Stage only changes attributable to this session and relevant to its completed work. Never use blanket staging when unrelated or pre-existing changes are present.
- If the intended changes cannot be safely distinguished, do not commit; explain what needs the user's decision.
- Before committing, confirm the staged diff contains only the intended work. Use a concise commit message describing it.
- Push the commit if the current branch has a configured upstream and pushing is available. If commit or push fails, report the specific failure without discarding changes or claiming the push succeeded.

## 4. Start one agent per handoff (`ho s`)

Only after the handoffs exist and the session is committed and pushed. Start exactly one agent per handoff, `ho1` first, and never one for a session-complete handoff (nothing remains to implement).

Detect the host rather than asking, and test in this order — these variables leak between harnesses on a machine that runs several (this host exports `OPENCODE=1` into a Pi pane, so `OPENCODE` alone proves nothing):

1. **Pi** — `PI_SESSION_FILE` or `PI_CODING_AGENT=true`: start each agent in a new **tmux window**.
2. **Claude Code** — `CLAUDECODE` or `CLAUDE_CODE_ENTRYPOINT`: **ask** the user whether the agents should be subagents or split panes, then follow the answer.
3. **OpenCode** — `OPENCODE_SESSION_ID` or `OPENCODE=1`: start each agent in a new **tmux window**.

Then use the helper rather than inventing the commands. One call, all handoffs:

```bash
bash <this skill's directory>/scripts/spawn-agents.sh ho1=/tmp/finizh-a.md ho2=/tmp/finizh-b.md
```

It creates one disposable clone per handoff (`scripts/session.sh new ho<N>-<utc>`), opens the tab and starts the agent with the prompt `Implement the ho1. Handoff document: /tmp/finizh-a.md. …`, which also names the clone and tells the agent to commit, push on `main` and remove the clone when done. It prints one line per agent: name, window or pane, clone path, handoff path.

- `--harness pi|opencode|claude` overrides detection when the environment is ambiguous.
- `--dry-run` prints the clone and tab commands and creates nothing.
- **Claude Code, subagents**: do not run the helper. Start one subagent per handoff with the same prompt (`Implement the ho1. Handoff document: …`) and tell the user they share this session's checkout, so this only fits handoffs that touch disjoint files.
- **Claude Code, split panes**: run the helper with `--harness claude`; it splits panes off the current window.
- **Not inside tmux, or the host is unknown**: run the helper with `--dry-run` and give the user the commands to paste. Never report an agent as running when it is not.
- Do not wait on the agents, and do not do their work here. If a spawn fails, say which one and why; the clone may already exist.

## Report

Report the handoffs, if any, and distinguish them from work completed in this session. With `ho s`, also report the agents started: name, tab, clone, and that each begins from the pushed commit. Summarize commit and push status and say whether the session can be closed. If no repository changes need committing, say so explicitly.
