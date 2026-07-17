#!/usr/bin/env bash
set -euo pipefail

WORKTREE_NAME="$1" # branch/worktree name (from wt template)
WORKTREE_DIR="$2"  # absolute path to the worktree (from wt template)
PR_NUMBER="$3"     # GitHub PR number

# Sanitize session name: replace dots with underscores to avoid
# tmux interpreting them as target separators (session.window.pane).
# Matches the naming used by tmux-worktree-session.sh so this and wtmux
# share a session for the same worktree.
SESSION_NAME="wt-${WORKTREE_NAME//\./_}"

TMUX_COMMAND="tmux"

# Control-mode opts apply only to the attaching client, not the
# detached management commands below.
TMUX_OPTS="-CC "

cd ~/jb/platform
git fetch origin
git pull

cd "$WORKTREE_DIR"

if $TMUX_COMMAND has-session -t "$SESSION_NAME" 2>/dev/null; then
  # Session already exists: just switch/attach, don't clobber its windows.
  if [ -n "${TMUX:-}" ]; then
    $TMUX_COMMAND switch-client -t "$SESSION_NAME"
  else
    exec $TMUX_COMMAND $TMUX_OPTS attach-session -t "$SESSION_NAME"
  fi
  exit 0
fi

# Fresh session: build three review windows. Targets use window names
# (not indices) so a non-zero base-index doesn't matter.
$TMUX_COMMAND new-session -d -s "$SESSION_NAME" -c "$WORKTREE_DIR" -n overview
$TMUX_COMMAND send-keys -t "$SESSION_NAME:overview" "claude-overview" Enter

$TMUX_COMMAND new-window -t "$SESSION_NAME" -c "$WORKTREE_DIR" -n review
$TMUX_COMMAND send-keys -t "$SESSION_NAME:review" "claude-review" Enter

$TMUX_COMMAND new-window -t "$SESSION_NAME" -c "$WORKTREE_DIR" -n risk-level
$TMUX_COMMAND send-keys -t "$SESSION_NAME:risk-level" "claude-risk-level" Enter

$TMUX_COMMAND new-window -t "$SESSION_NAME" -c "$WORKTREE_DIR" -n review-pr
$TMUX_COMMAND send-keys -t "$SESSION_NAME:review-pr" "claude '/github-review-pr ${PR_NUMBER}'" Enter

# Land on the overview window.
$TMUX_COMMAND select-window -t "$SESSION_NAME:overview"

if [ -n "${TMUX:-}" ]; then
  $TMUX_COMMAND switch-client -t "$SESSION_NAME"
else
  exec $TMUX_COMMAND $TMUX_OPTS attach-session -t "$SESSION_NAME"
fi
