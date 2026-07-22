#!/bin/bash
# Shared CLI essentials on Linux — the tools the synced dotfiles expect.
# Re-runs whenever this file changes.
if [ "$(uname -s)" != "Linux" ]; then exit 0; fi
set -euo pipefail
echo "Installing shared apt essentials (sudo may prompt)..."
sudo apt-get install -y \
  zsh git tmux neovim fzf eza direnv ripgrep \
  curl unzip tree btop mosh
