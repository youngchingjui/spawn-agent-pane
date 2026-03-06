#!/usr/bin/env bash
# Spawn a Claude Code instance in a new tmux split pane.
# Usage: spawn-tmux.sh [-d|--directory DIR] [-h|--horizontal] [PROMPT...]

set -euo pipefail

SPLIT_FLAG="-v"
DIRECTORY=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--directory)
      DIRECTORY="$2"
      shift 2
      ;;
    -h|--horizontal)
      SPLIT_FLAG="-h"
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

# Build tmux split-window command
TMUX_ARGS=("split-window" "$SPLIT_FLAG")

if [ -n "$DIRECTORY" ]; then
  TMUX_ARGS+=("-c" "$DIRECTORY")
fi

TMUX_ARGS+=("$CLAUDE_CMD")

tmux "${TMUX_ARGS[@]}"
