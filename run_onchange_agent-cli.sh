#!/bin/bash
# Install the agent CLIs the synced dotfiles expect: pi (Agent harness)
# and grok (xAI CLI), plus pi's shared pi-kit package. Idempotent — safe to
# re-run whenever this file changes.
#
# Runs inside chezmoi's non-interactive apply, where mise activation from
# .zshrc does NOT apply, so node/npm may be invisible. We establish the
# paths we need up front: ~/.local/bin (our install target) + mise bins.

set -euo pipefail

# -- paths -------------------------------------------------------------

# Where we install pi + grok binaries (zshrc already adds this to PATH)
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# mise-installed tools (node/npm, firecrawl, ...) live in mise's shims/bin
# dirs; add them so "node" and "npm" resolve in this non-interactive shell.
ensure_mise_path() {
  local d bins
  if command -v mise >/dev/null 2>&1; then
    bins="$(mise bin-paths 2>/dev/null || true)"
    for d in $bins "$HOME/.local/share/mise/shims"; do
      case ":$PATH:" in
        *":$d:"*) : ;;
        *) PATH="$d:$PATH" ;;
      esac
    done
    export PATH
  fi
}

# -- installation -------------------------------------------------------

install_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return
  fi
  echo "node/npm missing — provisioning..."
  if command -v mise >/dev/null 2>&1; then
    mise use -g node@lts
    ensure_mise_path
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
  install_node || return
  echo "installing pi (@earendil-works/pi-coding-agent)..."
  # Explicit prefix (~/.local) keeps pi out of mise shims, which have no
  # version binding for arbitrary npm-global tools and error at runtime.
  npm install -g --prefix "$HOME/.local" @earendil-works/pi-coding-agent
}

install_grok() {
  if [ -x "$HOME/.local/bin/grok" ] || command -v grok >/dev/null 2>&1; then
    return
  fi
  echo "installing grok (xAI CLI)..."
  curl -fsSL https://x.ai/cli/install.sh | bash
}

# -- run ---------------------------------------------------------------

ensure_mise_path
install_pi
install_grok

# pi-kit: shared package exercised by the aliases in dot_zshrc; no-op if
# already present.
if command -v pi >/dev/null 2>&1; then
  pi install git:git@github.com:tkuminecz/pi-kit
fi