#!/usr/bin/env bash
# Spawn a Claude Code instance in a new terminal window (fallback).
# Usage: spawn-fallback.sh [-d|--directory DIR] [-h|--horizontal] [PROMPT...]

set -euo pipefail

DIRECTORY=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -h|--horizontal)
      # Ignored in fallback mode — no split pane support
      shift
      ;;
    *)
      if [ -n "$PROMPT" ]; then
        PROMPT="$PROMPT $1"
      else
        PROMPT="$1"
      fi
      shift
      ;;
  esac
done

# Build the claude command
if [ -n "$PROMPT" ]; then
  CLAUDE_CMD="claude \"${PROMPT}\""
else
  CLAUDE_CMD="claude"
fi

# Prepend cd if directory given
if [ -n "$DIRECTORY" ]; then
  CLAUDE_CMD="cd \"${DIRECTORY}\" && ${CLAUDE_CMD}"
fi

OS="$(uname)"

if [ "$OS" = "Darwin" ]; then
  osascript <<EOF
tell application "Terminal"
  activate
  do script "${CLAUDE_CMD}"
end tell
EOF
elif command -v gnome-terminal &>/dev/null; then
  gnome-terminal -- bash -c "${CLAUDE_CMD}; exec bash"
elif command -v xterm &>/dev/null; then
  xterm -e bash -c "${CLAUDE_CMD}; exec bash" &
else
  echo "Error: No supported terminal emulator found." >&2
  exit 1
fi
