#!/usr/bin/env bash
# detect-terminal.sh — Detect the current terminal environment.
# Writes the result to ~/.claude/spawn-agent.json so the agent
# knows which spawn method to use from SKILL.md.
#
# If the config file already exists with user preferences (split, agent_command),
# those are preserved — only the "terminal" key is updated.
#
# Usage: bash detect-terminal.sh
# Output: { "terminal": "tmux" | "iterm2" | "terminal-app" | "vscode" | "linux" }

set -euo pipefail

CONFIG_DIR="${HOME}/.claude"
CONFIG_FILE="${CONFIG_DIR}/spawn-agent.json"

# Detect terminal environment
if [ -n "${TMUX:-}" ]; then
  TERMINAL="tmux"
elif [ "${TERM_PROGRAM:-}" = "vscode" ]; then
  TERMINAL="vscode"
elif [ "$(uname)" = "Darwin" ] && [ "${TERM_PROGRAM:-}" = "iTerm.app" ]; then
  TERMINAL="iterm2"
elif [ "$(uname)" = "Darwin" ]; then
  TERMINAL="terminal-app"
else
  TERMINAL="linux"
fi

# Write config, preserving any existing user preferences
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ] && command -v sed &>/dev/null; then
  # If config exists, update just the terminal key
  if grep -q '"terminal"' "$CONFIG_FILE" 2>/dev/null; then
    sed -i.bak "s/\"terminal\": *\"[^\"]*\"/\"terminal\": \"$TERMINAL\"/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  else
    # terminal key doesn't exist yet — add it after the opening brace
    sed -i.bak "s/^{/{\"terminal\": \"$TERMINAL\",/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  fi
else
  # No existing config — create fresh
  printf '{ "terminal": "%s" }\n' "$TERMINAL" > "$CONFIG_FILE"
fi

echo "Detected terminal: $TERMINAL"
echo "Saved to $CONFIG_FILE"
