# spawn-agent

An [agent skill](https://github.com/anthropics/agent-skills) that enables agents to spawn independent, parallel agents in separate terminal panes. Works with tmux, iTerm2, Terminal.app, VS Code, and Linux terminals.

## Why?

Many agents (Claude Code, Codex, etc.) have built-in sub-agent support — but those sub-agents run within the same thread, invisible to the user, designed for quick autonomous tasks. This skill enables a different pattern: **spawn a fully independent agent in its own terminal pane** where the user can watch it, interact with it, and guide it.

## How it works

This skill is **markdown-first** — [SKILL.md](skills/spawn-agent/SKILL.md) contains all the instructions the agent needs. The agent determines the terminal environment from saved config, environment variables, or by asking the user, then runs the appropriate spawn command directly. No complex scripts required.

## Installation

### Via skills.sh

```bash
npx skills add youngchingjui/spawn-agent
```

Global install:

```bash
npx skills add youngchingjui/spawn-agent -g
```

### As a Claude Code plugin

```bash
claude plugin install youngchingjui/spawn-agent
```

## Usage

```
/spawn-agent Fix the bug in src/auth.ts
```

The agent crafts a detailed prompt and spawns a new agent instance in a separate pane to handle the task.

## What's in SKILL.md?

[SKILL.md](skills/spawn-agent/SKILL.md) is the file the agent reads at runtime. It covers:

- **Why spawn externally** — how this differs from built-in sub-agents
- **How to determine the spawn method** — saved config, environment variables, asking the user, helper script
- **Spawn commands for each terminal** — tmux, iTerm2, Terminal.app, VS Code, Linux
- **Configuration** — user preferences stored in `~/.claude/spawn-agent.json` (terminal type, split direction, agent command)
- **Best practices** — interactive mode, detailed prompts, issue tracking
