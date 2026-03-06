# spawn-agent

A Claude Code plugin for spawning Claude instances in split terminal panes. Supports iTerm2, tmux, and a generic terminal fallback.

## How it works

The plugin automatically detects your terminal environment and spawns a new Claude Code instance in a split pane (or new window as a fallback):

1. **tmux** — detected via `$TMUX` env var, uses `tmux split-window`
2. **iTerm2** — detected via `$TERM_PROGRAM` on macOS, uses AppleScript to split the session
3. **Fallback** — opens a new Terminal.app window on macOS, or tries `gnome-terminal` / `xterm` on Linux

## Installation

### Via skills.sh (Agent Skills standard)

Install the skill into any compatible agent (Claude Code, Cursor, GitHub Copilot, etc.):

```bash
npx skills add youngchingjui/spawn-agent
```

This discovers the `skills/spawn-agent/SKILL.md` and installs it to your agent's skills directory. Use `--list` to preview available skills first, or `-g` for global install:

```bash
npx skills add youngchingjui/spawn-agent --list
npx skills add youngchingjui/spawn-agent -g
```

### As a Claude Code plugin

```bash
claude plugin install youngchingjui/spawn-agent
```

Skills installed as a plugin are namespaced: `/spawn-agent:spawn-agent`.

### Local development

```bash
git clone https://github.com/youngchingjui/spawn-agent.git
claude --plugin-dir ./spawn-agent
```

## Usage

Use the `/spawn-agent` skill from within Claude Code:

```
/spawn-agent Fix the bug in src/auth.ts
```

### With a working directory

```
/spawn-agent -d ~/Projects/myapp Refactor the database layer
```

### Horizontal split

```
/spawn-agent -h Write tests for the API endpoints
```

### Combined

```
/spawn-agent -d ~/Projects/myapp -h Add error handling to the payment flow
```

## Backends

### iTerm2

Splits the current iTerm2 session vertically (default) or horizontally (`-h`). Requires macOS with iTerm2 as the active terminal.

### tmux

Splits the current tmux pane. Uses `-v` (vertical/below) by default, or `-h` (horizontal/right) with the `-h` flag.

### Fallback

Opens a new terminal window. On macOS, uses Terminal.app via AppleScript. On Linux, tries `gnome-terminal` then `xterm`.

## Scripts

The scripts can also be used standalone:

```bash
# Detect terminal environment
./scripts/detect-terminal.sh
# Output: tmux, iterm2, or fallback

# Spawn directly
./scripts/spawn-iterm2.sh -d ~/Projects/myapp "Fix the login bug"
./scripts/spawn-tmux.sh -h "Write unit tests"
./scripts/spawn-fallback.sh "Review the codebase"
```
