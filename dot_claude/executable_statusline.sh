#!/usr/bin/env bash
# Managed by tim-claude-stuff — edit in the repo, not here; install.sh
# overwrites this file (and uses this marker line to recognize its own
# installs, so don't remove it).
#
# Statusline wrapper: runs claude-hud, then appends account/org info to line 1.
# claude-hud has no account/org display option, so we post-process its output.

# Optional user config — lets TTL, the work-account pattern/domain, and an
# explicit node path be overridden without editing this script. Config wins
# over the built-in defaults; env vars set before invoking this script win
# over config (since we only fill in a var here if it's still unset).
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude-statusline/config"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
: "${TTL_SECONDS:=10}"
: "${WORK_PROFILE_PATTERN:=*/jb/*}"
: "${WORK_DOMAIN:=justicebid.com}"
: "${CLAUDE_STATUSLINE_NODE:=}"

# Portable mtime: BSD `stat -f`, else GNU `stat -c`, else 0 (treat as stale).
mtime_of() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

cols=$( { stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 ))

# Resolve node: explicit override, then PATH, then the newest mise install.
# If none is found we don't crash — we just skip running the hud below and
# print only the account suffix.
if [[ -n "$CLAUDE_STATUSLINE_NODE" ]]; then
  NODE="$CLAUDE_STATUSLINE_NODE"
elif command -v node >/dev/null 2>&1; then
  NODE=$(command -v node)
else
  NODE=$(ls -d "$HOME"/.local/share/mise/installs/node/*/bin/node 2>/dev/null | sort -V | tail -1)
fi
PATH="$HOME/.local/bin:$PATH"

# Pick the newest installed claude-hud version so plugin updates don't break this.
HUD=$(ls -d "$HOME"/.claude/plugins/cache/claude-hud/claude-hud/*/dist/index.js 2>/dev/null | sort -V | tail -1)

# Account/org suffix from `claude auth status` — the live credential the
# session will bill, NOT .claude.json's oauthAccount (login-time metadata
# that lags the real token; it burned us on 2026-07-14). auth status takes
# ~0.4s, too slow to block every render: cache per profile with a short
# TTL and refresh in the background, so a /login shows up within seconds
# without ever delaying the bar.
PROFILE="${CLAUDE_CONFIG_DIR:-default}"
CACHE="$HOME/.claude/cache/statusline-account-$(printf '%s' "$PROFILE" | tr -c 'A-Za-z0-9' '_').txt"
mkdir -p "$HOME/.claude/cache"

refresh_cache() {
  local tmp="$CACHE.tmp.$$"
  # python3, not node: node is only needed for the hud, and this must keep
  # working (cheaply) on machines that don't have it.
  command claude auth status 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if d.get("loggedIn"):
    sys.stdout.write(" | ".join(v for v in (d.get("email"), d.get("orgName")) if v))
else:
    sys.stdout.write("not logged in")
' >"$tmp" 2>/dev/null
  # Keep the last known value rather than flashing empty on a hiccup.
  if [[ -s "$tmp" ]]; then mv "$tmp" "$CACHE"; else rm -f "$tmp"; fi
  rm -f "$CACHE.refreshing"
}

now=$(date +%s)
mtime=$(mtime_of "$CACHE")
if [[ ! -s "$CACHE" ]]; then
  refresh_cache # first render for this profile: worth the one-time 0.4s
elif (( now - mtime > TTL_SECONDS )); then
  # Stale: render the cached value now, refresh behind this render. The
  # .refreshing marker stops concurrent renders from piling up spawns;
  # treat a marker older than 30s as a crashed refresh and go again.
  marker_mtime=$(mtime_of "$CACHE.refreshing")
  if (( now - marker_mtime > 30 )); then
    touch "$CACHE.refreshing"
    (refresh_cache &) >/dev/null 2>&1
  fi
fi
SUFFIX=$(<"$CACHE")

# Work sessions (profile matching $WORK_PROFILE_PATTERN) must be on the work
# account — make a mismatch impossible to miss instead of quietly printing
# the wrong email.
DIM=$'\033[2m' RED=$'\033[1;31m' RESET=$'\033[0m'
STYLE="$DIM"
if [[ "$PROFILE" == $WORK_PROFILE_PATTERN && "$SUFFIX" != *"@$WORK_DOMAIN"* ]]; then
  STYLE="$RED"
  SUFFIX="⚠ WRONG ACCOUNT: $SUFFIX"
fi

if [[ -n "$NODE" && -x "$NODE" && -n "$HUD" ]]; then
  OUT=$("$NODE" "$HUD")
else
  OUT="" # no node or no claude-hud: degrade to printing just the account suffix
fi
if [[ -n $SUFFIX ]]; then
  printf '%s\n' "$OUT" | awk -v s="${STYLE} | ${SUFFIX}${RESET}" 'NR==1{print $0 s; next} {print}'
else
  printf '%s\n' "$OUT"
fi
