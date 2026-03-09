#!/usr/bin/env bash
# Test suite for spawn-agent.sh
# Uses --dry-run to verify argument parsing, config loading, and command building
# without actually spawning any terminal panes.
#
# Run: bash tests/test-spawn-agent.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPAWN="$SCRIPT_DIR/skills/spawn-agent/scripts/spawn-agent.sh"

# Use a temp config file so we don't touch the real one
export CONFIG_FILE_OVERRIDE=""
TEMP_DIR="$(mktemp -d)"
FAKE_CONFIG="$TEMP_DIR/spawn-agent.json"
trap 'rm -rf "$TEMP_DIR"' EXIT

PASSED=0
FAILED=0
TOTAL=0

# ── Helpers ────────────────────────────────────────────────────────────────

pass() {
  PASSED=$((PASSED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  PASS: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  FAIL: $1"
  echo "    expected: $2"
  echo "    got:      $3"
}

assert_output_contains() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    pass "$description"
  else
    fail "$description" "$expected" "$actual"
  fi
}

assert_output_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$description"
  else
    fail "$description" "$expected" "$actual"
  fi
}

assert_exit_code() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    pass "$description"
  else
    fail "$description" "exit $expected" "exit $actual"
  fi
}

# Run the script with --dry-run and capture output.
# --dry-run must go BEFORE -- since everything after -- is the command.
run_dry() {
  local -a pre_args=()
  local -a post_args=()
  local saw_separator=false

  for arg in "$@"; do
    if [ "$arg" = "--" ]; then
      saw_separator=true
      pre_args+=("--dry-run" "--")
    elif [ "$saw_separator" = true ]; then
      post_args+=("$arg")
    else
      pre_args+=("$arg")
    fi
  done

  # If no -- was found, just append --dry-run
  if [ "$saw_separator" = false ]; then
    pre_args+=("--dry-run")
  fi

  if [ ${#post_args[@]} -gt 0 ]; then
    HOME="$TEMP_DIR" bash "$SPAWN" "${pre_args[@]}" "${post_args[@]}" 2>&1 || true
  else
    HOME="$TEMP_DIR" bash "$SPAWN" "${pre_args[@]}" 2>&1 || true
  fi
}

# ── Tests: Argument Parsing ────────────────────────────────────────────────

echo ""
echo "=== Argument Parsing ==="

# Test 1: Basic command after --
output=$(run_dry -t tmux -- echo hello)
assert_output_contains "basic command passes through" "command=echo hello" "$output"
assert_output_contains "defaults to vertical" "direction=vertical" "$output"
assert_output_contains "terminal type from flag" "terminal=tmux" "$output"

# Test 2: Horizontal flag
output=$(run_dry -t tmux -H -- echo hello)
assert_output_contains "-H sets horizontal direction" "direction=horizontal" "$output"

# Test 3: Long-form --horizontal
output=$(run_dry -t tmux --horizontal -- echo hello)
assert_output_contains "--horizontal sets horizontal direction" "direction=horizontal" "$output"

# Test 4: Size flag
output=$(run_dry -t tmux -s 40 -- echo hello)
assert_output_contains "-s sets pane size" "pane_size=40" "$output"

# Test 5: Terminal type flag
output=$(run_dry -t iterm2 -- echo hello)
assert_output_contains "-t sets terminal type" "terminal=iterm2" "$output"

# Test 6: No command — opens empty shell
output=$(run_dry -t tmux)
assert_output_contains "no command yields empty command" "command=" "$output"

# Test 7: Command without -- separator
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux --dry-run echo hello world 2>&1 || true)
assert_output_contains "command without -- works" "command=echo hello world" "$output"

# Test 8: All options combined
output=$(run_dry -t tmux -H -s 30 -- ls -la)
assert_output_contains "combined: terminal" "terminal=tmux" "$output"
assert_output_contains "combined: direction" "direction=horizontal" "$output"
assert_output_contains "combined: size" "pane_size=30" "$output"
assert_output_contains "combined: command" "command=ls -la" "$output"

# ── Tests: Command String ─────────────────────────────────────────────────

echo ""
echo "=== Command String ==="

# Test 9: Single string command passes through verbatim
output=$(run_dry -t tmux -- "cd /tmp && ls")
assert_output_contains "single string passes through" "command=cd /tmp && ls" "$output"

# Test 10: Pipe in single string
output=$(run_dry -t tmux -- "ls | grep foo")
assert_output_contains "pipe in string works" "command=ls | grep foo" "$output"

# Test 11: Chained commands in single string
output=$(run_dry -t tmux -- "cd /app && npm install && npm start")
assert_output_contains "multi-chain works" "command=cd /app && npm install && npm start" "$output"

# Test 12: Claude-style invocation
output=$(run_dry -t tmux -- "cd ~/Projects/myapp && claude 'Fix the login bug'")
assert_output_contains "claude invocation" "command=cd ~/Projects/myapp && claude 'Fix the login bug'" "$output"

# Test 13: Simple command
output=$(run_dry -t tmux -- "htop")
assert_output_contains "simple command" "command=htop" "$output"

# Test 14: Multi args preserve quoting (claude "say hello" → claude 'say hello')
output=$(run_dry -t tmux -- claude "say hello")
assert_output_contains "multi args preserve quoting" "command=claude 'say hello'" "$output"

# Test 15: Multi args without quotes stay simple
output=$(run_dry -t tmux -- echo hello world)
assert_output_contains "simple multi args" "command=echo hello world" "$output"

# ── Tests: Config Management ──────────────────────────────────────────────

echo ""
echo "=== Config Management ==="

# Test 14: Config get with no file
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config get 2>&1)
assert_output_contains "config get with no file" "No config file" "$output"

# Test 15: Config set creates file
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config set terminal_type tmux 2>&1)
assert_output_contains "config set writes value" "tmux" "$output"

# Test 16: Config get after set
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config get 2>&1)
assert_output_contains "config get reads saved value" "tmux" "$output"

# Test 17: Config set adds to existing file
HOME="$TEMP_DIR" bash "$SPAWN" --config set split_direction horizontal >/dev/null 2>&1
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config get 2>&1)
assert_output_contains "config preserves terminal_type" "tmux" "$output"
assert_output_contains "config adds split_direction" "horizontal" "$output"

# Test 18: Config reset removes file
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config reset 2>&1)
assert_output_contains "config reset confirms removal" "Config reset" "$output"
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config get 2>&1)
assert_output_contains "config file is gone after reset" "No config file" "$output"

# ── Tests: Config Loading ─────────────────────────────────────────────────

echo ""
echo "=== Config Loading ==="

# Test 19: Config values are used when no flags given
HOME="$TEMP_DIR" bash "$SPAWN" --config set split_direction horizontal >/dev/null 2>&1
HOME="$TEMP_DIR" bash "$SPAWN" --config set pane_size 30 >/dev/null 2>&1
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux --dry-run -- echo test 2>&1)
assert_output_contains "config loads split_direction" "direction=horizontal" "$output"
assert_output_contains "config loads pane_size" "pane_size=30" "$output"

# Test 20: CLI flags override config
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux -s 70 --dry-run -- echo test 2>&1)
assert_output_contains "CLI -s overrides config size" "pane_size=70" "$output"

# Test 21: Config direction used when no -H flag
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux --dry-run -- echo test 2>&1)
assert_output_contains "config direction used when no flag" "direction=horizontal" "$output"

# Test: terminal_type in config is ignored — auto-detection wins
HOME="$TEMP_DIR" bash "$SPAWN" --config set terminal_type iterm2 >/dev/null 2>&1
output=$(HOME="$TEMP_DIR" TMUX="/tmp/tmux" bash "$SPAWN" --dry-run -- echo test 2>&1)
assert_output_contains "config terminal_type ignored, auto-detects instead" "terminal=tmux" "$output"

# Clean up for remaining tests
HOME="$TEMP_DIR" bash "$SPAWN" --config reset >/dev/null 2>&1

# ── Tests: Terminal Detection ──────────────────────────────────────────────

echo ""
echo "=== Terminal Detection ==="

# Test 22: TMUX env var detected
HOME="$TEMP_DIR" bash "$SPAWN" --config reset >/dev/null 2>&1
output=$(HOME="$TEMP_DIR" TMUX="/tmp/tmux-1000/default,12345,0" bash "$SPAWN" --dry-run -- echo test 2>&1)
assert_output_contains "TMUX env var detects tmux" "terminal=tmux" "$output"

# Test 23: iTerm2 detected on macOS
HOME="$TEMP_DIR" bash "$SPAWN" --config reset >/dev/null 2>&1
if [ "$(uname)" = "Darwin" ]; then
  output=$(HOME="$TEMP_DIR" TMUX="" TERM_PROGRAM="iTerm.app" bash "$SPAWN" --dry-run -- echo test 2>&1)
  assert_output_contains "TERM_PROGRAM detects iterm2" "terminal=iterm2" "$output"
else
  pass "iTerm2 detection (skipped — not macOS)"
fi

# Test 24: Fallback when nothing matches
HOME="$TEMP_DIR" bash "$SPAWN" --config reset >/dev/null 2>&1
output=$(HOME="$TEMP_DIR" TMUX="" TERM_PROGRAM="other" bash "$SPAWN" --dry-run -- echo test 2>&1)
assert_output_contains "fallback when no match" "terminal=fallback" "$output"

# ── Tests: Error Handling ──────────────────────────────────────────────────

echo ""
echo "=== Error Handling ==="

# Test 25: Unknown option
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux --bogus -- echo test 2>&1 || true)
assert_output_contains "unknown option rejected" "Unknown option" "$output"

# Test 26: -s without value
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t tmux -s 2>&1 || true)
assert_output_contains "-s without value errors" "requires a size" "$output"

# Test 27: -t without value
output=$(HOME="$TEMP_DIR" bash "$SPAWN" -t 2>&1 || true)
assert_output_contains "-t without value errors" "requires a terminal" "$output"

# Test 28: --config without subcommand
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config 2>&1 || true)
assert_output_contains "--config without action shows usage" "Usage" "$output"

# Test 29: --config set without key/value
output=$(HOME="$TEMP_DIR" bash "$SPAWN" --config set 2>&1 || true)
assert_output_contains "--config set without args shows usage" "Usage" "$output"

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════"
echo "  Results: $PASSED/$TOTAL passed, $FAILED failed"
echo "════════════════════════════════"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
