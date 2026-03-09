#!/usr/bin/env bash
# spawn-agent.sh — Open a new terminal pane and run a command in it.
# Supports tmux, iTerm2, and a generic terminal fallback.
#
# Usage:
#   spawn-agent.sh [OPTIONS] -- "COMMAND"
#   spawn-agent.sh --config {get|set|reset} [KEY VALUE]
#
# Options (must come before --):
#   -H, --horizontal    Horizontal split (top-bottom) instead of vertical (side-by-side)
#   -s, --size SIZE     Pane size as a percentage (default: 50)
#   -t, --terminal TYPE Force terminal type (tmux, iterm2, fallback)
#   --dry-run           Print what would be executed without actually spawning
#
# Everything after -- is the command string to run in the new pane.
# Pass as a single quoted string so shell operators work naturally.
# If no command is given, opens an empty shell.
#
# Examples:
#   spawn-agent.sh -- "claude 'Fix the login bug'"
#   spawn-agent.sh -- "cd ~/Projects/myapp && claude 'Refactor the DB'"
#   spawn-agent.sh -H -s 40 -- "htop"
#   spawn-agent.sh -- "cd /tmp && ls -la"
#
# Config file: ~/.claude/spawn-agent.json

set -euo pipefail

CONFIG_FILE="${HOME}/.claude/spawn-agent.json"

# ── Config helpers ──────────────────────────────────────────────────────────

config_read() {
  local key="$1"
  if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG_FILE'))
    v = cfg.get('$key', '')
    if v != '': print(v)
except: pass
" 2>/dev/null
  fi
}

config_write() {
  local key="$1" value="$2"
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [ -f "$CONFIG_FILE" ]; then
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
cfg['$key'] = '$value'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
print(json.dumps(cfg, indent=2))
"
  else
    python3 -c "
import json
cfg = {'$key': '$value'}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
print(json.dumps(cfg, indent=2))
"
  fi
}

config_get_all() {
  if [ -f "$CONFIG_FILE" ]; then
    cat "$CONFIG_FILE"
  else
    echo "No config file found at $CONFIG_FILE"
  fi
}

config_reset() {
  rm -f "$CONFIG_FILE"
  echo "Config reset. Removed $CONFIG_FILE"
}

# ── Config command handling ─────────────────────────────────────────────────

if [[ "${1:-}" == "--config" ]]; then
  action="${2:-}"
  case "$action" in
    get)
      config_get_all
      ;;
    set)
      key="${3:-}"
      value="${4:-}"
      if [ -z "$key" ] || [ -z "$value" ]; then
        echo "Usage: spawn-agent.sh --config set KEY VALUE" >&2
        echo "Valid keys: split_direction (vertical|horizontal), pane_size (1-100)" >&2
        exit 1
      fi
      config_write "$key" "$value"
      ;;
    reset)
      config_reset
      ;;
    *)
      echo "Usage: spawn-agent.sh --config {get|set|reset}" >&2
      exit 1
      ;;
  esac
  exit 0
fi

# ── Quoting helper ──────────────────────────────────────────────────────────

# Join args into a command string, wrapping any that contain spaces in
# single quotes. Args without spaces are left bare.
quote_args() {
  local cmd=""
  for arg in "$@"; do
    if [ -n "$cmd" ]; then
      cmd="$cmd "
    fi
    if [[ "$arg" == *" "* || "$arg" == *"'"* ]]; then
      # Escape existing single quotes, then wrap in single quotes
      local escaped
      escaped="${arg//\'/\'\\\'\'}"
      cmd="$cmd'$escaped'"
    else
      cmd="$cmd$arg"
    fi
  done
  echo "$cmd"
}

# ── Parse arguments ─────────────────────────────────────────────────────────

DIRECTION=""
PANE_SIZE=""
TERMINAL_TYPE=""
DRY_RUN=false
SHELL_CMD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      # If single arg, use it verbatim (user passed a command string).
      # If multiple args, quote any that contain spaces to preserve boundaries.
      if [ $# -eq 1 ]; then
        SHELL_CMD="$1"
      elif [ $# -gt 1 ]; then
        SHELL_CMD="$(quote_args "$@")"
      fi
      break
      ;;
    -H|--horizontal)
      DIRECTION="horizontal"
      shift
      ;;
    -s|--size)
      PANE_SIZE="${2:-}"
      if [ -z "$PANE_SIZE" ]; then
        echo "Error: -s requires a size value" >&2
        exit 1
      fi
      shift 2
      ;;
    -t|--terminal)
      TERMINAL_TYPE="${2:-}"
      if [ -z "$TERMINAL_TYPE" ]; then
        echo "Error: -t requires a terminal type" >&2
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      echo "Usage: spawn-agent.sh [OPTIONS] -- \"COMMAND\"" >&2
      exit 1
      ;;
    *)
      # No -- found yet but got a positional arg — treat rest as command
      if [ $# -eq 1 ]; then
        SHELL_CMD="$1"
      else
        SHELL_CMD="$(quote_args "$@")"
      fi
      break
      ;;
  esac
done

# ── Load config (CLI flags override config values) ──────────────────────────

if [ -z "$DIRECTION" ]; then
  saved_dir="$(config_read split_direction)"
  if [ -n "$saved_dir" ]; then
    DIRECTION="$saved_dir"
  fi
fi
if [ -z "$PANE_SIZE" ]; then
  saved_size="$(config_read pane_size)"
  if [ -n "$saved_size" ]; then
    PANE_SIZE="$saved_size"
  fi
fi

# Default direction is vertical (side-by-side)
DIRECTION="${DIRECTION:-vertical}"

# ── Detect terminal ─────────────────────────────────────────────────────────

detect_terminal() {
  if [ -n "${TMUX:-}" ]; then
    echo "tmux"
  elif [ "$(uname)" = "Darwin" ] && [ "${TERM_PROGRAM:-}" = "iTerm.app" ]; then
    echo "iterm2"
  else
    echo "fallback"
  fi
}

# Always auto-detect unless explicitly overridden with -t flag.
# Terminal type is an environment fact, not a preference.
if [ -z "$TERMINAL_TYPE" ]; then
  TERMINAL_TYPE="$(detect_terminal)"
fi

# ── Spawn: tmux ─────────────────────────────────────────────────────────────

spawn_tmux() {
  # tmux -h = vertical divider (side-by-side, what users call "vertical")
  # tmux -v = horizontal divider (top-bottom, what users call "horizontal")
  if [ "$DIRECTION" = "horizontal" ]; then
    local split_flag="-v"
  else
    local split_flag="-h"
  fi

  local -a args=("split-window" "$split_flag" "-c" "$(pwd)")

  if [ -n "$PANE_SIZE" ]; then
    args+=("-p" "$PANE_SIZE")
  fi

  if [ -n "$SHELL_CMD" ]; then
    # Run via login shell so PATH is fully configured
    args+=("$SHELL" "-lc" "$SHELL_CMD; exec $SHELL")
  fi
  # If no command, tmux opens a default shell automatically

  tmux "${args[@]}"
}

# ── Spawn: iTerm2 ──────────────────────────────────────────────────────────

spawn_iterm2() {
  # iTerm2: "split vertically" = side-by-side, "split horizontally" = top-bottom
  if [ "$DIRECTION" = "horizontal" ]; then
    local iterm_dir="horizontally"
  else
    local iterm_dir="vertically"
  fi

  # Escape the command for embedding in AppleScript
  local escaped_cmd
  escaped_cmd=$(printf '%s' "$SHELL_CMD" | sed 's/\\/\\\\/g; s/"/\\"/g')

  osascript <<EOF
tell application "iTerm2"
  tell current session of current window
    set newSession to (split ${iterm_dir} with default profile)
  end tell
  tell newSession
    write text "cd $(pwd)"
    $([ -n "$SHELL_CMD" ] && echo "write text \"${escaped_cmd}\"")
  end tell
end tell
EOF
}

# ── Spawn: fallback ────────────────────────────────────────────────────────

spawn_fallback() {
  local os
  os="$(uname)"

  local cwd
  cwd="$(pwd)"

  if [ "$os" = "Darwin" ]; then
    local escaped_cmd
    escaped_cmd=$(printf '%s' "$SHELL_CMD" | sed 's/\\/\\\\/g; s/"/\\"/g')
    local escaped_cwd
    escaped_cwd=$(printf '%s' "$cwd" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript <<EOF
tell application "Terminal"
  activate
  $(if [ -n "$SHELL_CMD" ]; then
    echo "do script \"cd '${escaped_cwd}' && ${escaped_cmd}\""
  else
    echo "do script \"cd '${escaped_cwd}'\""
  fi)
end tell
EOF
  elif command -v gnome-terminal &>/dev/null; then
    if [ -n "$SHELL_CMD" ]; then
      gnome-terminal --working-directory="$cwd" -- bash -lc "${SHELL_CMD}; exec \$SHELL"
    else
      gnome-terminal --working-directory="$cwd"
    fi
  elif command -v xterm &>/dev/null; then
    if [ -n "$SHELL_CMD" ]; then
      xterm -e bash -lc "cd '$cwd' && ${SHELL_CMD}; exec \$SHELL" &
    else
      xterm -e bash -lc "cd '$cwd'; exec \$SHELL" &
    fi
  else
    echo "Error: No supported terminal emulator found." >&2
    exit 1
  fi
}

# ── Dry run ─────────────────────────────────────────────────────────────────

if [ "$DRY_RUN" = true ]; then
  echo "terminal=$TERMINAL_TYPE"
  echo "direction=$DIRECTION"
  echo "pane_size=${PANE_SIZE:-default}"
  echo "command=$SHELL_CMD"
  exit 0
fi

# ── Dispatch ────────────────────────────────────────────────────────────────

case "$TERMINAL_TYPE" in
  tmux)     spawn_tmux ;;
  iterm2)   spawn_iterm2 ;;
  fallback) spawn_fallback ;;
  *)
    echo "Error: Unknown terminal type '$TERMINAL_TYPE'. Use tmux, iterm2, or fallback." >&2
    exit 1
    ;;
esac
