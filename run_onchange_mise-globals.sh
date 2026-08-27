#!/bin/sh
# Baseline global mise tools — tools the synced dotfiles expect on every machine
# (e.g. ~/bin/firecrawl symlinks to the firecrawl-cli shim). Re-runs whenever this
# file changes. mise stays sole owner of ~/.config/mise/config.toml; this script
# only declares the baseline via `mise use -g` (idempotent, installs if missing).
if ! command -v mise >/dev/null 2>&1; then
  echo "mise not installed; skipping global tool baseline"
  exit 0
fi
mise use -g \
  node@lts \
  npm:firecrawl-cli@latest \
  rust@latest \
  usage@latest
