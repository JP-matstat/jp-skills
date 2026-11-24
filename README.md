# jp-skills

Agent skills I use. Each one is a plain `SKILL.md` folder with an optional
`scripts/` directory, so it works in any coding agent that reads a skills folder
(Pi, Claude Code, OpenCode, anything else with the same convention).

| Skill | What it does | Invoke |
|---|---|---|
| [split-test-impl](skills/split-test-impl/) | Develop a slice from a spec with two isolated agents: one writes the tests and freezes them, a second implements from the spec alone and never sees the suite. Blindness is enforced by two private repositories, not by good intentions. | `/split-test-impl`, or the skill itself |
| [nownow](skills/nownow/) | Keep the work moving: decide reversible things yourself, track the decisions and their rationale, stop only for what is destructive, externally consequential or materially out of scope. Report the decisions at the end. | `/nownow`, "nownow" |
| [finizh](skills/finizh/) | Audit whether the session's requested work is complete. If not, list what remains, or write one handoff per remaining task; if complete, commit and push. `finizh ho s` starts one fresh agent per handoff in its own clone and tab. | `/finizh`, `/finizh ho`, `/finizh ho s` |

## Install

Copy the skills you want into your agent's skills folder:

```bash
git clone https://github.com/JP-matstat/jp-skills /tmp/jp-skills
mkdir -p .agents/skills
cp -r /tmp/jp-skills/skills/* .agents/skills/     # or just the ones you want
```

Or keep one checkout and link them, so `git pull` updates them all:

```bash
ln -s /path/to/jp-skills/skills/nownow .agents/skills/nownow
```

Claude Code reads `~/.claude/skills/` (and `.claude/skills/` in a project);
OpenCode and Pi read `.agents/skills/` (or their configured skills directory).

## Layout

```
skills/
├── split-test-impl/     SKILL.md, REFERENCE.md, scripts/sti.sh, its own tests
├── nownow/              SKILL.md
└── finizh/              SKILL.md, scripts/spawn-agents.sh
```

Each `SKILL.md` is self-contained and names its own scripts as
`<this skill's directory>/scripts/...`, so a skill can be copied out of this
repository on its own. `finizh ho s` also expects the surrounding project to
provide `scripts/session.sh new <id>` (the disposable-clone convention); it finds
the project root from the skill's own location, and `LOGISTIK_CANONICAL` /
`LOGISTIK_SESSIONS_DIR` override that.

## License

MIT — see [LICENSE](LICENSE).
