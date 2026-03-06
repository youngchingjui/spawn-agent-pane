#!/usr/bin/env bash
# Spawn a Claude Code instance in a new iTerm2 split pane.
# Usage: spawn-iterm2.sh [-d|--directory DIR] [-h|--horizontal] [PROMPT...]

set -euo pipefail

DIRECTION="vertically"
DIRECTORY=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -h|--horizontal)
      DIRECTION="horizontally"
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
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g')
  CLAUDE_CMD="claude \"${ESCAPED_PROMPT}\""
else
  CLAUDE_CMD="claude"
fi

# Prepend cd if directory given
if [ -n "$DIRECTORY" ]; then
  ESCAPED_DIR=$(printf '%s' "$DIRECTORY" | sed 's/\\/\\\\/g; s/"/\\"/g')
  CLAUDE_CMD="cd \"${ESCAPED_DIR}\" && ${CLAUDE_CMD}"
fi

osascript <<EOF
tell application "iTerm2"
  tell current session of current window
    set newSession to (split ${DIRECTION} with default profile)
  end tell
  tell newSession
    write text "${CLAUDE_CMD}"
  end tell
end tell
EOF
