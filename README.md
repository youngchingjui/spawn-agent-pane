# spawn-agent

An [agent skill](https://github.com/anthropics/agent-skills) that opens split terminal panes and runs commands in them. Works with any compatible agent (Claude Code, Cursor, GitHub Copilot, etc.). Supports tmux, iTerm2, and a generic terminal fallback.

## Features

- **Split pane spawning** — opens a new terminal pane (or window) and runs any command in it
- **Terminal auto-detection** — detects tmux, iTerm2, or falls back to a new window (Terminal.app, gnome-terminal, xterm)
- **Persistent config** — saves preferences (split direction, pane size) to `~/.claude/spawn-agent.json`
- **CLI overrides** — flags always override saved config; config overrides built-in defaults
- **Generic command runner** — not Claude-specific; runs any command after `--` in the new pane
- **Login shell execution** — uses `$SHELL -lc` so your PATH is fully set up (nvm, volta, etc.)
- **Structured argument parsing** — options go before `--`, command goes after; unknown flags are rejected
- **`--dry-run` mode** — prints what would be executed without spawning anything; used by the test suite

## Supported terminals

| Terminal     | Split support                                                                 | Detection method         |
| ------------ | ----------------------------------------------------------------------------- | ------------------------ |
| **tmux**     | Vertical (side-by-side) and horizontal (top-bottom) splits, configurable size | `$TMUX` env var          |
| **iTerm2**   | Vertical and horizontal splits                                                | `$TERM_PROGRAM` on macOS |
| **Fallback** | New window (Terminal.app on macOS, gnome-terminal or xterm on Linux)          | Automatic                |

## Installation

### Via skills.sh (Agent Skills standard)

```bash
npx skills add youngchingjui/spawn-agent
```

Global install (available in all projects):

```bash
npx skills add youngchingjui/spawn-agent -g
```

### As a Claude Code plugin

```bash
claude plugin install youngchingjui/spawn-agent
```

### Local development

```bash
git clone https://github.com/youngchingjui/spawn-agent.git
claude --plugin-dir ./spawn-agent
```

## Usage

```
spawn-agent.sh [OPTIONS] -- "COMMAND"
```

Options go **before** `--`. Everything **after** `--` is the command string to run in the new pane. Pass the command as a quoted string so shell operators (`&&`, `|`, etc.) work naturally.

### Spawning a Claude agent

The primary use case — delegate tasks to parallel Claude Code instances:

```
/spawn-agent Fix the bug in src/auth.ts
```

With a working directory:

```bash
./scripts/spawn-agent.sh -- "cd ~/Projects/myapp && claude 'Refactor the database layer'"
```

### Running any command

```bash
# Monitor logs in a side pane
./scripts/spawn-agent.sh -- "tail -f /var/log/syslog"

# Run a dev server
./scripts/spawn-agent.sh -- "cd ~/Projects/myapp && npm run dev"

# Open htop in a horizontal (top-bottom) split
./scripts/spawn-agent.sh -H -- "htop"

# Custom pane size
./scripts/spawn-agent.sh -s 30 -- "watch -n1 kubectl get pods"

# Chain multiple commands
./scripts/spawn-agent.sh -- "cd /app && npm install && npm start"

# Open an empty shell
./scripts/spawn-agent.sh
```

## Options

| Flag                         | Description                                                      |
| ---------------------------- | ---------------------------------------------------------------- |
| `-H`, `--horizontal`         | Horizontal split (top-bottom) instead of vertical (side-by-side) |
| `-s SIZE`, `--size SIZE`     | Pane size as a percentage (default: 50)                          |
| `-t TYPE`, `--terminal TYPE` | Force terminal type (`tmux`, `iterm2`, `fallback`)               |
| `--dry-run`                  | Print resolved settings and command without spawning             |
| `--config get`               | Show current config                                              |
| `--config set KEY VALUE`     | Set a config value                                               |
| `--config reset`             | Delete config file                                               |

## Configuration

Preferences are saved to `~/.claude/spawn-agent.json`. Terminal type is always auto-detected from your environment — it is not saved to config.

**Priority order:** CLI flags > config file > built-in defaults

```json
{
  "split_direction": "vertical",
  "pane_size": 50
}
```

| Key               | Values                       | Default       | Description                                          |
| ----------------- | ---------------------------- | ------------- | ---------------------------------------------------- |
| `split_direction` | `vertical`, `horizontal`     | `vertical`    | `vertical` = side-by-side, `horizontal` = top-bottom |
| `pane_size`       | `1`–`100`                    | `50`          | Percentage of screen for the new pane                |

```bash
# View config
./scripts/spawn-agent.sh --config get

# Set preferences
./scripts/spawn-agent.sh --config set split_direction horizontal
./scripts/spawn-agent.sh --config set pane_size 40

# Reset
./scripts/spawn-agent.sh --config reset
```

## Testing

The test suite uses `--dry-run` to verify all logic without spawning actual panes. Tests run on any machine with bash and python3 (used for JSON config parsing).

```bash
bash tests/test-spawn-agent.sh
```

### What's tested

**Argument parsing**

- Options (`-H`, `-s`, `-t`) are parsed correctly before `--`
- Everything after `--` becomes the command
- Positional args without `--` are treated as the command
- Unknown flags are rejected with an error
- Missing required values (`-s` without a number, `-t` without a type) error cleanly
- Default direction is vertical (side-by-side)

**Command string**

- Single string command passes through verbatim
- Shell operators (`&&`, `|`, etc.) work naturally inside the quoted string
- Multi-command chains are preserved correctly
- Claude-style invocations (`cd dir && claude 'prompt'`) work as expected

**Config management**

- `--config get` shows "no config" when file doesn't exist
- `--config set` creates the file and writes a key-value pair
- `--config set` on an existing file adds without overwriting other keys
- `--config get` reads back all saved values
- `--config reset` removes the file
- `--config` without a subcommand shows usage
- `--config set` without key/value shows usage

**Config loading & priority**

- Saved `terminal_type`, `split_direction`, and `pane_size` are loaded from config
- CLI flag `-t` overrides config `terminal_type`
- CLI flag `-s` overrides config `pane_size`
- CLI flag `-H` overrides config `split_direction`
- Config values are used when no flags are given

**Terminal detection**

- `$TMUX` env var → detects `tmux`
- `$TERM_PROGRAM=iTerm.app` on macOS → detects `iterm2`
- Neither set → detects `fallback`

**Auto-detection always wins**

- Terminal type is always auto-detected, never read from config
- Even if `terminal_type` is manually set in config, auto-detection takes priority
- `-t` flag still works as a per-invocation override

### Manual testing (per terminal)

These must be tested manually in each terminal environment:

1. **tmux** — Run `./scripts/spawn-agent.sh -t tmux -- "echo hello"`. Verify a side-by-side pane opens with the output, then drops to a shell. Add `-H` and verify it splits top-bottom instead.
2. **iTerm2** — Run `./scripts/spawn-agent.sh -t iterm2 -- "echo hello"`. Verify a new split appears. Test `-H` for horizontal.
3. **Fallback (macOS)** — Run `./scripts/spawn-agent.sh -t fallback -- "echo hello"`. Verify Terminal.app opens a new window with the output.
4. **Claude agent** — Run `./scripts/spawn-agent.sh -- "claude 'What is 2+2?'"`. Verify Claude Code starts in interactive mode (not blank, not `--print` mode).

## Troubleshooting

### Blank pane / command doesn't start

- The script uses a login shell (`$SHELL -lc`) to run commands, so your PATH is fully configured.
- Verify the command works standalone: `which claude`, `which htop`, etc.
- If using a version manager (nvm, volta), ensure it's set up in your shell profile.

### Wrong split direction

- **Vertical** = side-by-side (left/right). **Horizontal** = top-bottom.
- Use `-H` for top-bottom splits.
- Check saved config: `./scripts/spawn-agent.sh --config get`

### Terminal not detected correctly

```bash
# Check what's detected
./scripts/spawn-agent.sh --dry-run

# Override in config
./scripts/spawn-agent.sh --config set terminal_type tmux

# Or override per-invocation
./scripts/spawn-agent.sh -t tmux -- your-command
```
