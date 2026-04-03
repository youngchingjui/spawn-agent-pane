#!/usr/bin/env bash
# spawn-iterm.sh — Spawn a Claude agent in iTerm2.
#
# Usage:
#   bash spawn-iterm.sh "Your prompt here"
#   bash spawn-iterm.sh --dir ~/Projects/myproject "Your prompt here"
#   bash spawn-iterm.sh --mode vertical "Your prompt here"
#
# Options:
#   --dir DIR      Working directory for the agent (default: current directory)
#   --mode MODE    How to open: tab (default), vertical, horizontal

set -euo pipefail

# --- Parse arguments ---
DIR="$(pwd)"
MODE="tab"
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      PROMPT="$1"
      shift
      ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "Error: A prompt string is required." >&2
  echo "Usage: bash spawn-iterm.sh [--dir DIR] [--mode tab|vertical|horizontal] \"Your prompt here\"" >&2
  exit 1
fi

if [[ "$MODE" != "tab" && "$MODE" != "vertical" && "$MODE" != "horizontal" ]]; then
  echo "Error: --mode must be tab, vertical, or horizontal (got: $MODE)" >&2
  exit 1
fi

# --- Verify macOS ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: This script requires macOS." >&2
  exit 1
fi

# --- Verify iTerm2 is installed ---
if ! osascript -e 'application id "com.googlecode.iterm2"' &>/dev/null; then
  echo "Error: iTerm2 is not installed." >&2
  exit 1
fi

# --- Read agent command from config ---
CONFIG_FILE="${HOME}/.claude/spawn-agent.json"
AGENT_CMD="claude"
if [[ -f "$CONFIG_FILE" ]] && command -v python3 &>/dev/null; then
  CONFIGURED_CMD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('agent_command','claude'))" 2>/dev/null || true)
  if [[ -n "$CONFIGURED_CMD" ]]; then
    AGENT_CMD="$CONFIGURED_CMD"
  fi
fi

# --- Verify agent command is installed ---
if ! command -v "$AGENT_CMD" &>/dev/null; then
  echo "Error: $AGENT_CMD is not installed." >&2
  exit 1
fi

# --- Resolve directory to absolute path ---
if [[ ! -d "$DIR" ]]; then
  echo "Error: Directory does not exist: $DIR" >&2
  exit 1
fi
DIR="$(cd "$DIR" && pwd)"

# --- Escape single quotes for AppleScript ---
escaped_dir="${DIR//\'/\'\\\'\'}"
escaped_prompt="${PROMPT//\\/\\\\}"
escaped_prompt="${escaped_prompt//\'/\'\\\'\'}"
escaped_prompt="${escaped_prompt//\"/\\\"}"

CMD_TEXT="cd '${escaped_dir}' && ${AGENT_CMD} '${escaped_prompt}'"

# --- Open iTerm2 session based on mode ---
case "$MODE" in
  tab)
    osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  tell current window
    set newTab to (create tab with default profile)
    tell current session of newTab
      write text "${CMD_TEXT}"
    end tell
  end tell
end tell
APPLESCRIPT
    echo "Spawned ${AGENT_CMD} in new iTerm2 tab (dir: ${DIR})"
    ;;
  vertical)
    osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  tell current session of current window
    set newSession to (split vertically with default profile)
  end tell
  tell newSession
    write text "${CMD_TEXT}"
  end tell
end tell
APPLESCRIPT
    echo "Spawned ${AGENT_CMD} in vertical split pane (dir: ${DIR})"
    ;;
  horizontal)
    osascript <<APPLESCRIPT
tell application "iTerm2"
  activate
  tell current session of current window
    set newSession to (split horizontally with default profile)
  end tell
  tell newSession
    write text "${CMD_TEXT}"
  end tell
end tell
APPLESCRIPT
    echo "Spawned ${AGENT_CMD} in horizontal split pane (dir: ${DIR})"
    ;;
esac
