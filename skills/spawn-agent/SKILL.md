---
name: spawn-agent
description: "Spawn a new Claude Code instance in a split terminal pane. Supports iTerm2, tmux, and generic terminal fallback. Use when delegating tasks to a parallel agent or working on multiple things simultaneously."
disable-model-invocation: true
metadata:
  author: youngchingjui
  version: "1.0.0"
---

# Spawn Agent

Spawn a new Claude Code instance in a split terminal pane.

## Instructions

1. First, detect the terminal environment by running:

```bash
bash "$CLAUDE_SKILL_DIR/../../scripts/detect-terminal.sh"
```

2. Based on the output, run the matching spawn script from the same scripts directory:

   - `tmux` → `bash "$CLAUDE_SKILL_DIR/../../scripts/spawn-tmux.sh"`
   - `iterm2` → `bash "$CLAUDE_SKILL_DIR/../../scripts/spawn-iterm2.sh"`
   - `fallback` → `bash "$CLAUDE_SKILL_DIR/../../scripts/spawn-fallback.sh"`

3. Pass through any arguments the user provided. Use `$ARGUMENTS` as the prompt text. If the user specified a directory with `-d`, pass that through as well. If the user requested a horizontal split, pass `-h`.

Example:

```bash
bash "$CLAUDE_SKILL_DIR/../../scripts/spawn-iterm2.sh" -d ~/Projects/myapp $ARGUMENTS
```
