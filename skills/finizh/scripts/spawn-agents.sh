#!/usr/bin/env bash
# Start one fresh coding agent per handoff, each in its own disposable clone
# and its own terminal tab. Used by the finizh skill: `finizh ho s`.
#
#   spawn-agents.sh [--harness pi|opencode|claude] [--dry-run] ho1=PATH [ho2=PATH ...]
#
# The canonical repository is found from the skill's own location (the first
# ancestor holding scripts/session.sh); LOGISTIK_CANONICAL and
# LOGISTIK_SESSIONS_DIR override it.
#
# Host detection (first match wins, because these variables leak between
# harnesses on a machine that runs several — a host may export OPENCODE=1 into
# a Pi pane):
#   PI_SESSION_FILE / PI_CODING_AGENT=true     -> pi
#   CLAUDECODE / CLAUDE_CODE_ENTRYPOINT        -> claude
#   OPENCODE_SESSION_ID / OPENCODE=1           -> opencode
#   nothing                                    -> unknown (refuse, ask for --harness)
#
# Layout:
#   pi, opencode  new tmux window named after the handoff (`ho1`)
#   claude        new tmux pane, split off the current window
#
# Every agent is started with `Implement the ho<N>. Handoff document: <path>.`
# and a tail telling it to work in its clone, commit and push on main, and then
# remove the clone. The clone is created with scripts/session.sh new (ADR 0020),
# so two handoffs never write the same tree, and the parent session never gets a
# second writer.
set -euo pipefail

TMUX_BIN=${FINIZH_TMUX_BIN:-tmux}
SHELL_BIN=${SHELL:-/bin/sh}

harness=""
dry_run=0
handoffs=()

die() { printf 'spawn-agents: %s\n' "$*" >&2; exit 1; }

# Locate the repository this skill is installed in: the skill lives at
# <repo>/.agents/skills/finizh/scripts, so the first ancestor holding
# scripts/session.sh is the canonical tree. LOGISTIK_CANONICAL overrides it.
if [ -n "${LOGISTIK_CANONICAL:-}" ]; then
    CANONICAL=$LOGISTIK_CANONICAL
else
    CANONICAL=""
    probe=$(cd "$(dirname "$0")" && pwd)
    for _ in 1 2 3 4 5 6; do
        if [ -f "$probe/scripts/session.sh" ]; then CANONICAL=$probe; break; fi
        probe=$(dirname "$probe")
        [ "$probe" = "/" ] && break
    done
    [ -n "$CANONICAL" ] || die "cannot find scripts/session.sh above the skill; set LOGISTIK_CANONICAL=<repo>"
fi

# The session clones sit beside the canonical tree (/srv/logistik-sessions for
# /srv/logistik); LOGISTIK_SESSIONS_DIR overrides it.
SESSIONS=${LOGISTIK_SESSIONS_DIR:-$(dirname "$CANONICAL")/$(basename "$CANONICAL")-sessions}
SESSION_SH=${FINIZH_SESSION_SH:-$CANONICAL/scripts/session.sh}

usage() {
    cat <<'EOF'
usage: spawn-agents.sh [--harness pi|opencode|claude] [--dry-run] ho1=PATH [ho2=PATH ...]

  --harness NAME   override host detection
  --dry-run        print the clone and tab commands; create nothing
  -h, --help       this text

One argument per handoff: its name (`ho1`, `ho2`, ...) and the handoff document.
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --harness) [ $# -ge 2 ] || die "--harness needs a value"; harness=$2; shift 2 ;;
        --harness=*) harness=${1#*=}; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; while [ $# -gt 0 ]; do handoffs+=("$1"); shift; done ;;
        -*) die "unknown option '$1' (see --help)" ;;
        *) handoffs+=("$1"); shift ;;
    esac
done

[ ${#handoffs[@]} -gt 0 ] || { usage >&2; exit 2; }

if [ -z "$harness" ]; then
    if [ -n "${PI_SESSION_FILE:-}" ] || [ "${PI_CODING_AGENT:-}" = "true" ]; then
        harness=pi
    elif [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
        harness=claude
    elif [ -n "${OPENCODE_SESSION_ID:-}" ] || [ "${OPENCODE:-}" = "1" ]; then
        harness=opencode
    else
        usage >&2
        die "cannot tell which coding agent this is; pass --harness pi|opencode|claude (or --dry-run)"
    fi
fi

case $harness in
    pi|opencode|claude) ;;
    *) die "unknown harness '$harness' (pi, opencode or claude)" ;;
esac

if [ "$dry_run" -eq 0 ]; then
    [ -n "${TMUX:-}" ] || die "not inside tmux: there is no tab to open. Use --dry-run and report the commands instead"
    command -v "$TMUX_BIN" >/dev/null 2>&1 || die "$TMUX_BIN not found"
    [ -x "$SESSION_SH" ] || die "$SESSION_SH not found (set LOGISTIK_CANONICAL or FINIZH_SESSION_SH)"
fi

tmux_session=""
if [ "$dry_run" -eq 0 ]; then
    # A dry run must not touch tmux at all, not even to ask its name.
    tmux_session=$("$TMUX_BIN" display-message -p '#{session_name}' 2>/dev/null || true)
fi
tmux_target=()
if [ -n "$tmux_session" ]; then tmux_target=(-t "$tmux_session"); fi

printf 'spawn-agents: host=%s handoffs=%s dry-run=%s\n' \
    "$harness" "${#handoffs[@]}" "$([ "$dry_run" -eq 1 ] && echo yes || echo no)"

for pair in "${handoffs[@]}"; do
    name=${pair%%=*}
    path=${pair#*=}
    [ "$name" != "$pair" ] || die "'$pair' is not hoN=PATH"
    case $name in
        ho[0-9]|ho[0-9][0-9]) ;;
        *) die "'$name' is not a handoff name (expected ho1, ho2, ...)" ;;
    esac
    [ -f "$path" ] || die "handoff document not found: $path"

    clone_id="$name-$(date -u +%Y%m%dT%H%M%SZ)"
    clone="$SESSIONS/$clone_id"
    prompt="Implement the $name. Handoff document: $path. Work in the clone $clone, commit and push on main when it is done and verified, then remove the clone with scripts/session.sh rm $clone_id."

    case $harness in
        pi) launcher="pi $(printf '%q' "$prompt")" ;;
        opencode) launcher="opencode --prompt $(printf '%q' "$prompt")" ;;
        claude) launcher="claude $(printf '%q' "$prompt")" ;;
    esac
    # Keep the tab alive after the agent exits, so its last screen is not lost
    # and the clone path is still on screen.
    tab_cmd="$launcher; exec $(printf '%q' "$SHELL_BIN")"

    if [ "$harness" = claude ]; then
        tmux_cmd=("$TMUX_BIN" split-window -d -P -F '#{pane_id}' -c "$clone" "${tmux_target[@]}" "$tab_cmd")
    else
        tmux_cmd=("$TMUX_BIN" new-window -d -P -F '#{window_index}' -n "$name" -c "$clone" "${tmux_target[@]}" "$tab_cmd")
    fi

    if [ "$dry_run" -eq 1 ]; then
        printf '\n%s -> %s in %s\n' "$name" "$path" "$clone"
        printf '  clone:  %s new %s\n' "$SESSION_SH" "$clone_id"
        printf '  tab:   %s\n' "${tmux_cmd[*]}"
        continue
    fi

    "$SESSION_SH" new "$clone_id" >/dev/null || die "clone failed for $name ($clone_id); nothing started"
    [ -d "$clone" ] || die "clone $clone is missing after '$SESSION_SH new $clone_id'"

    if tab=$("${tmux_cmd[@]}"); then
        kind=window
        if [ "$harness" = claude ]; then kind=pane; fi
        printf '%-4s %-6s %-4s %-8s clone %s  handoff %s\n' \
            "$name" "$kind" "$tab" "$harness" "$clone" "$path"
    else
        die "clone $clone is ready but the $harness tab did not open; start it there by hand"
    fi
done

if [ "$dry_run" -eq 1 ]; then
    printf '\nspawn-agents: dry run — nothing created\n'
else
    printf '\nspawn-agents: started %s agent(s); each works in its own clone on main\n' "${#handoffs[@]}"
fi
