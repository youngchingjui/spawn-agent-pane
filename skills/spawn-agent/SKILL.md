---
name: spawn-agent
description: "Spawn a new agent instance in a split terminal pane. Supports iTerm2, tmux, and generic terminal fallback. Use when delegating tasks to a parallel agent or working on multiple things simultaneously."
disable-model-invocation: true
metadata:
  author: youngchingjui
  version: "2.0.0"
---

# Spawn Agent

Open a new split terminal pane and run a command in it.

## Instructions

The script `spawn-agent.sh` opens a new terminal pane and runs whatever command you give it. Options go before `--`, and the command goes after.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" [OPTIONS] -- "COMMAND"
```

### Options

| Flag                         | Description                                                              |
| ---------------------------- | ------------------------------------------------------------------------ |
| `-H`, `--horizontal`         | Horizontal split (top-bottom) instead of default vertical (side-by-side) |
| `-s SIZE`, `--size SIZE`     | Pane size as a percentage (default: 50)                                  |
| `-t TYPE`, `--terminal TYPE` | Force terminal type (`tmux`, `iterm2`, `fallback`)                       |

### Spawning a Claude agent

To delegate a task to a parallel Claude Code agent, pass the full command as a single string after `--`:

```bash
# Spawn Claude in a specific directory with a prompt
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" -- "cd ~/Projects/myapp && claude 'Fix the login bug'"

# Spawn Claude in the current directory
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" -- "claude 'Write tests for the API'"

# With options
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" -H -s 40 -- "cd ~/Projects/myapp && claude 'Refactor the database layer'"
```

### Running other commands

The script is not limited to Claude — you can run any command:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" -- "htop"
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" -- "cd /var/log && tail -f syslog"
```

### Config management

The script saves user preferences (split direction, pane size) to `~/.claude/spawn-agent.json`. Terminal type is always auto-detected.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" --config get
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" --config set split_direction vertical
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" --config set pane_size 40
bash "${CLAUDE_SKILL_DIR}/scripts/spawn-agent.sh" --config reset
```

## Critical rules

- **Avoid** using `--print` or `-p` flags with `claude`. The spawned agent must run in **interactive mode**.
- Use `$ARGUMENTS` as the prompt text when spawning Claude.
- Pass the command as a single quoted string after `--` so shell operators like `&&` and `|` work naturally.
