#!/bin/bash
# Install the agent CLIs the synced dotfiles expect: pi (Agent harness)
# and grok (xAI CLI), plus pi's shared pi-kit package. Idempotent — safe to
# re-run whenever this file changes.
#
# Prereqs are installed best-effort: node/npm (pi runs on Node) via mise when
# available, else apt (Debian/Ubuntu) or brew (macOS).

set -euo pipefail

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return
  fi
  echo "node/npm missing — provisioning..."
  if command -v mise >/dev/null 2>&1; then
    mise use -g node@lts
    # mise's shims aren't on PATH in this non-interactive shell; add them
    local mise_bins
    if mise_bins=$(mise bin-paths 2>/dev/null); then
      for d in $mise_bins; do
        case ":$PATH:" in
          *":$d:"*) : ;;
          *) PATH="$d:$PATH" ;;
        esac
      done
      export PATH
    fi
  elif [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install node
  elif [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y nodejs npm
  else
    echo "WARN: could not provision node/npm — pi install will be skipped"
    return 1
  fi
}

install_pi() {
  if command -v pi >/dev/null 2>&1; then
    return
  fi
  ensure_node || return
  echo "installing pi (@earendil-works/pi-coding-agent)..."
  npm install -g @earendil-works/pi-coding-agent
}

install_grok() {
  if [ -x "$HOME/.grok/bin/grok" ] || command -v grok >/dev/null 2>&1; then
    return
  fi
  echo "installing grok (xAI CLI)..."
  curl -fsSL https://x.ai/cli/install.sh | bash
}

install_pi
install_grok

# pi-kit: a shared package exercised by the aliases in dot_zshrc; install is
# a no-op if already present.
if command -v pi >/dev/null 2>&1; then
  pi install git:git@github.com:tkuminecz/pi-kit
fi