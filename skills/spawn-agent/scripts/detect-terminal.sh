#!/usr/bin/env bash
# Detect the current terminal environment.
# Prints one of: tmux, iterm2, fallback

if [ -n "$TMUX" ]; then
  echo "tmux"
elif [ "$(uname)" = "Darwin" ] && [ "$TERM_PROGRAM" = "iTerm.app" ]; then
  echo "iterm2"
else
  echo "fallback"
fi
