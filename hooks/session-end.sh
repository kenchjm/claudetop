#!/bin/bash
# session-end.sh — Claude Code SessionEnd hook
# Appends one JSONL record per session to ~/.claude/claudetop-history.jsonl
#
# Register in ~/.claude/settings.json:
#   "hooks": { "SessionEnd": [{ "type": "command", "command": "/path/to/session-end.sh" }] }

set -euo pipefail

HISTORY_FILE="$HOME/.claude/claudetop-history.jsonl"
JSON=$(cat)

# Detect git branch from project directory
PROJECT_DIR=$(echo "$JSON" | jq -r '.workspace.project_dir // .cwd // ""')
GIT_BRANCH=""
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/.git" ]; then
  GIT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null) || true
fi

jq -c \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg tag "${CLAUDETOP_TAG:-}" \
  --arg branch "$GIT_BRANCH" \
  '{
    timestamp:       $timestamp,
    session_id:      (.session_id // ""),
    project:         ((.workspace.project_dir // .cwd // "") | split("/") | last),
    project_dir:     (.workspace.project_dir // .cwd // ""),
    model:           (.model.id // ""),
    duration_ms:     (.cost.total_duration_ms // 0),
    cost_usd:        (.cost.total_cost_usd // 0),
    input_tokens:    (.context_window.total_input_tokens // 0),
    output_tokens:   (.context_window.total_output_tokens // 0),
    lines_added:     (.cost.total_lines_added // 0),
    lines_removed:   (.cost.total_lines_removed // 0),
    context_used_pct:(.context_window.used_percentage // 0),
    tag:             $tag,
    branch:          $branch
  }' <<< "$JSON" >> "$HISTORY_FILE"

# Reset iTerm2 terminal on session end — back to default colors, clear title/badge
if [ -n "${CLAUDETOP_ITERM:-}" ]; then
  TTY_MAP="$HOME/.claude/claudetop-iterm-ttys"
  SESSION_ID="${ITERM_SESSION_ID:-}"

  # Try PPID fallback if no session ID in env
  if [ -z "$SESSION_ID" ] && [ -f "$TTY_MAP" ]; then
    PARENT_TTY=$(ps -p $PPID -o tty= 2>/dev/null | tr -d ' ')
    if [ -n "$PARENT_TTY" ] && [ "$PARENT_TTY" != "??" ]; then
      PARENT_TTY="/dev/${PARENT_TTY}"
      SESSION_ID=$(grep "=${PARENT_TTY}$" "$TTY_MAP" 2>/dev/null | head -1 | cut -d= -f1)
    fi
  fi

  # Reset the specific TTY if we found the session
  _reset_tty() {
    local tty="$1" sid="$2"
    [ -n "$tty" ] && [ -w "$tty" ] || return
    printf "\033]1337;SetColors=bg=default\007" > "$tty"
    printf "\033]1;\007" > "$tty"
    printf "\033]1337;SetBadgeFormat=\007" > "$tty"
    # Mark state file as stale so watcher stops
    [ -n "$sid" ] && echo "timestamp=0" > "$HOME/.claude/claudetop-iterm-state.${sid}"
  }

  if [ -n "$SESSION_ID" ] && [ -f "$TTY_MAP" ]; then
    MY_TTY=$(grep "^${SESSION_ID}=" "$TTY_MAP" 2>/dev/null | tail -1 | cut -d= -f2-)
    _reset_tty "$MY_TTY" "$SESSION_ID"
  else
    # Fallback: reset ALL mapped TTYs (session is ending, be thorough)
    if [ -f "$TTY_MAP" ]; then
      while IFS='=' read -r sid tty; do
        _reset_tty "$tty" "$sid"
      done < "$TTY_MAP"
    fi
  fi
fi
