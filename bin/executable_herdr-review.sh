#!/usr/bin/env bash
set -euo pipefail

# herdr-based successor to tmux-review-session.sh / review-pr.
#
# Usage: herdr-review.sh <pr-number>
#
# Reviews live in a dedicated herdr session ("pr-reviews", override with
# REVIEW_SESSION) so they don't clutter the default session. The session's
# server runs headless and detached, so closing whichever terminal (or
# Raycast) launched the review never kills the agents. Each PR gets its
# own workspace (labeled pr-<N>) with three tabs:
#
#   tab orchestrator — bootstrap + orchestration (this script)
#   tab review       — claude-review   | claude /github-review-pr N
#   tab analysis     — claude-overview | claude-risk-level
#
# All four agents start in parallel. When the first three finish, their
# in-session output is sent to the PR review agent as feedback so it can
# update its report; the PR agent ends with a link to the review file.
#
# Stages (dispatched on $1):
#   <pr>        launch: ensure the pr-reviews server is up, create the
#               pr-<N> workspace, start --bootstrap in an orchestrator
#               pane; attach when run interactively outside herdr
#   --bootstrap inside the orchestrator pane: account check, repo
#               update, hand off to wt (worktree create/switch)
#   --run       inside the worktree (via wt): the orchestration itself

# Raycast (and other launchers) invoke this with a minimal environment,
# and a server we start here passes its environment on to every pane it
# spawns. Make PATH self-sufficient and recover the launchd ssh-agent
# socket so git over ssh works in those panes.
PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || true)"
  if [[ -n "$SSH_AUTH_SOCK" ]]; then
    export SSH_AUTH_SOCK
  fi
fi

REPO="${REVIEW_PR_REPO:-$HOME/jb/platform}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-7200}"
PICKUP_TIMEOUT_SECONDS="${PICKUP_TIMEOUT_SECONDS:-60}"

# Dedicated herdr session for PR reviews. Every herdr subcommand honors
# HERDR_SOCKET_PATH; exporting it pins all calls — including from panes
# this script spawns — to the pr-reviews session, even when the script is
# invoked from inside a pane of a different session.
SESSION="${REVIEW_SESSION:-pr-reviews}"
export HERDR_SOCKET_PATH="$HOME/.config/herdr/sessions/$SESSION/herdr.sock"

# Account selection: ~/jb/.envrc sets CLAUDE_CONFIG_DIR=~/jb/.claude via
# direnv, giving everything under ~/jb the work (justicebid) profile.
# herdr launches agent argv directly — no interactive shell, so the
# direnv hook never fires. Agents are therefore wrapped in
# `direnv exec <dir>` to apply the .envrc, and this guard bails unless
# the profile that will actually be used holds a work account.
#
# The guard asks `claude auth status` — the CLI's own report of the
# credential it will use — rather than reading oauthAccount out of
# .claude.json, which is /login-time metadata that can lag or disagree
# with the live token (observed 2026-07-14: reviews billed the personal
# account while the metadata guard passed).
REVIEW_ACCOUNT_DOMAIN="${REVIEW_ACCOUNT_DOMAIN:-justicebid.com}"

# --dangerously-allow-any-account (any position, any stage) or
# REVIEW_DANGEROUSLY_ALLOW_ANY_ACCOUNT=1 skips the account guard. The
# flag is stripped from the positional args here and re-appended to
# child invocations so it survives the launch → bootstrap → run chain.
ALLOW_ANY_ACCOUNT="${REVIEW_DANGEROUSLY_ALLOW_ANY_ACCOUNT:-0}"
_args=()
for _a in "$@"; do
  if [[ "$_a" == "--dangerously-allow-any-account" ]]; then
    ALLOW_ANY_ACCOUNT=1
  else
    _args+=("$_a")
  fi
done
set -- ${_args[@]+"${_args[@]}"}
ACCOUNT_FLAG=""
[[ "$ALLOW_ANY_ACCOUNT" == 1 ]] && ACCOUNT_FLAG="--dangerously-allow-any-account"

check_account() {
  local dir="$1"
  local active
  active="$(direnv exec "$dir" claude auth status 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    d = {}
print(d.get("email", "") if d.get("loggedIn") else "")
')"
  if [[ "$ALLOW_ANY_ACCOUNT" == 1 ]]; then
    echo "WARNING: account guard disabled (--dangerously-allow-any-account); active account: '${active:-none}'" >&2
    return 0
  fi
  if [[ "$active" != *"@$REVIEW_ACCOUNT_DOMAIN" ]]; then
    echo "error: live Claude account for $dir is '${active:-none / not logged in}', expected an @$REVIEW_ACCOUNT_DOMAIN account." >&2
    echo "Run 'claude /login' from that directory and select the correct account, then re-run." >&2
    echo "(Override the domain with REVIEW_ACCOUNT_DOMAIN, or bypass with --dangerously-allow-any-account.)" >&2
    exit 1
  fi
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

# All herdr commands emit JSON; jget extracts a value via a python
# expression evaluated against the parsed response as `r`.
jget() {
  python3 -c "import sys, json; r = json.load(sys.stdin); print($1)"
}

workspace_id_by_label() {
  herdr workspace list |
    jget "next((w['workspace_id'] for w in r['result']['workspaces'] if w.get('label') == '$WORKSPACE_LABEL'), '')"
}

# Make sure the pr-reviews server is up. Fully detach it (nohup + no tty
# stdin) so it runs headless and survives the launching terminal (or
# Raycast) going away — attached clients are just views onto it.
ensure_server() {
  herdr workspace list >/dev/null 2>&1 && return 0
  echo "Starting herdr server (session '$SESSION')..."
  (nohup herdr --session "$SESSION" server </dev/null >/dev/null 2>&1 &)
  for _ in $(seq 1 20); do
    herdr workspace list >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  echo "error: herdr server for session '$SESSION' did not come up" >&2
  exit 1
}

# Block until the user presses Enter *after this point*. Anything typed
# into this pane earlier (a stray Enter while the run was in progress)
# sits buffered in the pty and would satisfy the read instantly — drain
# it first. If the read ever fails (EOF), retry in a slow loop rather
# than exiting: macOS sleep rejects 'infinity', and herdr closes the
# pane the moment this process dies. Integer -t only — /usr/bin/env
# bash resolves to macOS bash 3.2.
hold_pane() {
  while read -r -t 1 _; do :; done
  while ! read -r _; do sleep 1; done
}

# herdr closes a pane when its process exits; on failure, hold the pane
# open so the error stays readable instead of vanishing with the pane.
hold_on_failure() {
  local code=$?
  if [[ $code -ne 0 ]]; then
    echo
    echo "herdr-review failed (exit $code). Press Enter to close this pane."
    hold_pane
  fi
}

# ---------------------------------------------------------------------------
# Stage 1 (default): launch — workspace + orchestrator pane, then attach
# ---------------------------------------------------------------------------
if [[ "${1:-}" != "--bootstrap" && "${1:-}" != "--run" ]]; then
  PR_NUMBER="${1:?usage: herdr-review.sh <pr-number>}"

  require herdr
  require python3

  ensure_server

  # One workspace per PR so concurrent reviews each get their own space.
  WORKSPACE_LABEL="${WORKSPACE_LABEL:-pr-$PR_NUMBER}"
  WORKSPACE_ID="$(workspace_id_by_label)"
  ROOT_TAB_ID=""
  if [[ -z "$WORKSPACE_ID" ]]; then
    WS_JSON="$(herdr workspace create --cwd "$REPO" --label "$WORKSPACE_LABEL" --no-focus)"
    WORKSPACE_ID="$(echo "$WS_JSON" | jget "r['result']['workspace']['workspace_id']")"
    ROOT_TAB_ID="$(echo "$WS_JSON" | jget "r['result']['tab']['tab_id']")"
  fi

  # The orchestrator gets its own tab; drop the tab's root shell pane so
  # the bootstrap process is the only thing in it. Running the bootstrap
  # inside herdr keeps git/wt output (and failures) visible next to the
  # agents instead of in whatever terminal launched this.
  TAB_JSON="$(herdr tab create --workspace "$WORKSPACE_ID" --label orchestrator --no-focus)"
  ORCH_TAB_ID="$(echo "$TAB_JSON" | jget "r['result']['tab']['tab_id']")"
  ORCH_ROOT_PANE="$(echo "$TAB_JSON" | jget "r['result']['root_pane']['pane_id']")"

  herdr agent start "pr-$PR_NUMBER-orchestrator" --cwd "$REPO" --tab "$ORCH_TAB_ID" --no-focus -- \
    "$SCRIPT_PATH" --bootstrap "$PR_NUMBER" ${ACCOUNT_FLAG:+"$ACCOUNT_FLAG"} >/dev/null
  herdr pane close "$ORCH_ROOT_PANE" >/dev/null
  # A fresh workspace comes with a default shell tab ("1"); drop it now
  # that the orchestrator tab exists to keep it from being the last tab.
  if [[ -n "$ROOT_TAB_ID" ]]; then
    herdr tab close "$ROOT_TAB_ID" >/dev/null
  fi
  herdr workspace focus "$WORKSPACE_ID" >/dev/null
  herdr tab focus "$ORCH_TAB_ID" >/dev/null

  echo "Review of PR #$PR_NUMBER running in herdr session '$SESSION' (workspace '$WORKSPACE_LABEL')."

  # Attach when running interactively outside herdr. Raycast (no tty) and
  # in-herdr invocations manage their own clients.
  if [[ -z "${HERDR_ENV:-}" && -t 0 ]]; then
    exec herdr --session "$SESSION"
  fi
  echo "Attach with: herdr session attach $SESSION"
  exit 0
fi

MODE="$1"

# ---------------------------------------------------------------------------
# Stage 2 (--bootstrap): inside the orchestrator pane — repo update, wt
# ---------------------------------------------------------------------------
if [[ "$MODE" == "--bootstrap" ]]; then
  PR_NUMBER="${2:?usage: herdr-review.sh --bootstrap <pr-number>}"

  require wt
  require direnv
  require python3
  trap hold_on_failure EXIT

  check_account "$REPO"

  # Docker isn't required for the review itself, but the worktree's
  # docker-setup hook stalls its port scan badly when Docker is down, and
  # `mise run up` needs it. Best-effort: launch OrbStack in the background
  # (-g: don't steal focus) so it boots while git fetches, then give it a
  # moment below — but never fail the review over it.
  DOCKER_WAS_DOWN=0
  if ! docker info >/dev/null 2>&1; then
    DOCKER_WAS_DOWN=1
    echo "Docker not running — starting OrbStack in the background..."
    open -ga OrbStack 2>/dev/null || true
  fi

  cd "$REPO"
  # The review only needs origin refs to be fresh — wt builds the
  # worktree from them, not from this checkout. The primary checkout is
  # kept parked on an up-to-date main so it never goes stale (e.g. left
  # on a merged branch whose upstream was deleted), but that's
  # best-effort: never fail the review over the primary checkout.
  git fetch --prune origin
  if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    echo "Switching primary checkout back to main..."
    git switch main ||
      echo "warning: could not switch to main (dirty checkout?); continuing" >&2
  fi
  if [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    git pull --ff-only ||
      echo "warning: 'git pull' failed; continuing with fetched refs" >&2
  fi

  if [[ "$DOCKER_WAS_DOWN" == 1 ]]; then
    for _ in $(seq 1 15); do
      docker info >/dev/null 2>&1 && break
      sleep 2
    done
    if docker info >/dev/null 2>&1; then
      echo "Docker is up."
    else
      echo "warning: Docker still not available; continuing without it —" >&2
      echo "worktree setup's port scan may be slow and 'mise run up' won't work." >&2
    fi
  fi

  # wt expands the {{...}} templates and runs the command inside the
  # worktree. Not exec'd: if wt or the orchestration fails, set -e plus
  # the EXIT trap hold this pane open with the error visible.
  wt -C "$REPO" switch \
    -x "$SCRIPT_PATH --run {{worktree_name}} {{worktree_path}} ${PR_NUMBER}${ACCOUNT_FLAG:+ $ACCOUNT_FLAG}" \
    "pr:${PR_NUMBER}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Stage 3 (--run): the orchestration, running inside the orchestrator pane
# ---------------------------------------------------------------------------
WORKTREE_NAME="$2" # branch/worktree name (from wt template)
WORKTREE_DIR="$3"  # absolute path to the worktree (from wt template)
PR_NUMBER="$4"     # GitHub PR number

require herdr
require direnv
require python3
require claude
require claude-overview
require claude-risk-level
require claude-review
trap hold_on_failure EXIT

# Agent labels include the worktree name so concurrent reviews of
# different worktrees don't collide. Sanitize characters herdr targets
# may treat specially (e.g. the ':' in "pr:1884").
LABEL_PREFIX="${LABEL_PREFIX:-${WORKTREE_NAME//[^a-zA-Z0-9_-]/_}}"

WORKSPACE_LABEL="${WORKSPACE_LABEL:-pr-$PR_NUMBER}"

OVERVIEW_LABEL="${OVERVIEW_LABEL:-$LABEL_PREFIX-overview}"
RISK_LABEL="${RISK_LABEL:-$LABEL_PREFIX-risk-level}"
REVIEW_LABEL="${REVIEW_LABEL:-$LABEL_PREFIX-review}"
PR_REVIEW_LABEL="${PR_REVIEW_LABEL:-$LABEL_PREFIX-review-pr}"

check_account "$WORKTREE_DIR"

cd "$WORKTREE_DIR"

WORKSPACE_ID="$(workspace_id_by_label)"
[[ -n "$WORKSPACE_ID" ]] || {
  echo "error: workspace '$WORKSPACE_LABEL' not found" >&2
  exit 1
}

# Create a tab holding two agents side by side: start both in the tab,
# then close the tab's root shell pane, leaving a 50/50 vertical split.
# Echoes "tab_id pane1_id pane2_id".
start_agent_pair() {
  local tab_label="$1" name1="$2" cmd1="$3" name2="$4" cmd2="$5"
  local tab_json tab_id root_pane p1 p2

  tab_json="$(herdr tab create --workspace "$WORKSPACE_ID" --label "$tab_label" --no-focus)"
  tab_id="$(echo "$tab_json" | jget "r['result']['tab']['tab_id']")"
  root_pane="$(echo "$tab_json" | jget "r['result']['root_pane']['pane_id']")"

  echo "Starting agents: $name1, $name2 (tab $tab_label)" >&2
  # Commands run under `direnv exec` so the ~/jb/.envrc profile
  # (CLAUDE_CONFIG_DIR) applies, matching an interactive shell.
  p1="$(herdr agent start "$name1" --cwd "$WORKTREE_DIR" --tab "$tab_id" --no-focus -- \
    direnv exec "$WORKTREE_DIR" bash -c "$cmd1" | jget "r['result']['agent']['pane_id']")"
  p2="$(herdr agent start "$name2" --cwd "$WORKTREE_DIR" --tab "$tab_id" --no-focus -- \
    direnv exec "$WORKTREE_DIR" bash -c "$cmd2" | jget "r['result']['agent']['pane_id']")"
  herdr pane close "$root_pane" >/dev/null

  echo "$tab_id $p1 $p2"
}

# Claude's herdr integration reports semantic state: working while it
# processes, idle once the response is finished. Wait for the agent to
# pick up its prompt (working), then for it to finish (idle). The first
# wait is best-effort: a fast agent may already be idle again.
wait_done() {
  local name="$1"
  echo "Waiting for $name to finish..."
  herdr agent wait "$name" --status working --timeout "$((PICKUP_TIMEOUT_SECONDS * 1000))" >/dev/null 2>&1 || true
  herdr agent wait "$name" --status idle --timeout "$((TIMEOUT_SECONDS * 1000))" >/dev/null
}

send_prompt() {
  local name="$1"
  local pane_id="$2"
  local text="$3"
  herdr agent send "$name" "$text" >/dev/null
  # Claude's TUI ingests large pastes asynchronously; an Enter that lands
  # mid-paste is swallowed. Pause, press Enter, and confirm the agent
  # actually started working — retrying if the keypress was dropped.
  local attempt
  for attempt in 1 2 3; do
    sleep 2
    herdr pane send-keys "$pane_id" enter >/dev/null
    if herdr agent wait "$name" --status working --timeout 15000 >/dev/null 2>&1; then
      return 0
    fi
    echo "Enter didn't register on $name (attempt $attempt), retrying..." >&2
  done
  echo "warning: $name may not have received the prompt; check its pane" >&2
}

# Two agent tabs, two panes each, all four agents in parallel. The review
# tab comes first, then analysis. The PR review agent starts drafting its
# report immediately; the others' feedback is sent to it once they finish.
read -r REVIEW_TAB _ PR_REVIEW_PANE < <(
  start_agent_pair review \
    "$REVIEW_LABEL" "claude-review" \
    "$PR_REVIEW_LABEL" "claude '/github-review-pr $PR_NUMBER' --permission-mode auto --model opus"
)
read -r ANALYSIS_TAB _ _ < <(
  start_agent_pair analysis \
    "$OVERVIEW_LABEL" "claude-overview" \
    "$RISK_LABEL" "claude-risk-level"
)

wait_done "$OVERVIEW_LABEL"
wait_done "$RISK_LABEL"
wait_done "$REVIEW_LABEL"

# The pre-review agents keep their output in-session only; capture it
# straight from their panes rather than via files on disk.
OVERVIEW_OUT="$(herdr agent read "$OVERVIEW_LABEL" --source recent-unwrapped)"
RISK_OUT="$(herdr agent read "$RISK_LABEL" --source recent-unwrapped)"
REVIEW_OUT="$(herdr agent read "$REVIEW_LABEL" --source recent-unwrapped)"

# Let the PR review agent finish its initial report before sending the
# feedback, so the follow-up wait can't match the wrong turn.
wait_done "$PR_REVIEW_LABEL"

# read -d '' instead of FEEDBACK="$(cat <<EOF …)": macOS bash 3.2 (which
# /usr/bin/env resolves to) can't parse quotes inside a heredoc nested in
# a command substitution. read exits nonzero at EOF, hence the || true.
read -r -d '' FEEDBACK <<EOF || true
incorporate the following feedback from other agents and update the report:

$OVERVIEW_OUT

----

$RISK_OUT

----

$REVIEW_OUT

----

After that, check the PR for any comments or feedback and remove anything from our report that's already been brought up. You can move any already-raised findings to their own section at the end.

Number the findings in the report: critical findings as C1, C2, … and warnings as W1, W2, … (e.g. **C1.** [Security] **<title>**). Renumber if updates change the list.

The report must always read as a standalone document reflecting only its current state. Fold every change silently into the body: no "Corrections", "Revisions", or "Updates" sections, and no wording that refers to earlier versions of the report or to the fact that it was revised.

----

When all finished, output a clickable link to the review file, formatted as a file:// URL with the absolute path (e.g. file:///Users/tim/jb/worktree/review.md). Output the bare URL on its own line — no markdown link syntax, no backticks, no surrounding text.

Then ask whether I want the report posted to PR #$PR_NUMBER as a top-level comment. Only post after I confirm. If I confirm: post the review file's contents EXACTLY as written — no summarizing, trimming, or rewording of any kind. Post it with gh, prefixing the comment body with this line followed by a blank line:
> Agent posting on behalf of @tkuminecz
EOF

echo "Sending pre-review feedback to $PR_REVIEW_LABEL..."
send_prompt "$PR_REVIEW_LABEL" "$PR_REVIEW_PANE" "$FEEDBACK"

wait_done "$PR_REVIEW_LABEL"
herdr tab focus "$REVIEW_TAB" >/dev/null

echo
echo "Review complete — the '$PR_REVIEW_LABEL' pane has the report, the review file link, and can post to PR #$PR_NUMBER."
format_duration() {
  local total="$1" h m s parts=""
  h=$((total / 3600))
  m=$((total % 3600 / 60))
  s=$((total % 60))
  [[ $h -gt 0 ]] && parts="${h}h "
  [[ $m -gt 0 || $h -gt 0 ]] && parts="${parts}${m}m "
  echo "${parts}${s}s"
}

echo "Finished in $(format_duration "$SECONDS")."

# Keep this pane (and therefore the orchestrator tab) open — herdr closes
# the pane when its process exits.
echo "Press Enter to close this tab."
hold_pane
