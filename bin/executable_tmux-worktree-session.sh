#!/usr/bin/env bash
set -euo pipefail

WORKTREE_NAME="$1"   # e.g. branch/worktree name
WORKTREE_DIR="$2"    # absolute path to the worktree

# Sanitize session name: replace dots with underscores to avoid
# tmux interpreting them as target separators (session.window.pane)
SESSION_NAME="wt-${WORKTREE_NAME//\./_}"

TMUX_COMMAND="tmux"

# Optional tmux options (e.g., export TMUX_OPTS="-CC" before calling script)
TMUX_OPTS="-CC "

# Ensure directory exists
cd "$WORKTREE_DIR"

if $TMUX_COMMAND has-session -t "$SESSION_NAME" 2>/dev/null; then
  # Session exists
  if [ -n "${TMUX:-}" ]; then
    $TMUX_COMMAND switch-client -t "$SESSION_NAME"
  else
    exec $TMUX_COMMAND $TMUX_OPTS attach-session -t "$SESSION_NAME"
  fi
else
  # Session does not exist: create then switch/attach
  if [ -n "${TMUX:-}" ]; then
    $TMUX_COMMAND $TMUX_OPTS new-session -d -s "$SESSION_NAME" -c "$WORKTREE_DIR"
    $TMUX_COMMAND switch-client -t "$SESSION_NAME"
  else
    exec $TMUX_COMMAND $TMUX_OPTS new-session -s "$SESSION_NAME" -c "$WORKTREE_DIR"
  fi
fi
