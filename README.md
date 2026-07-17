# env

Cross-platform (macOS + Linux) machine configuration, managed with [chezmoi](https://www.chezmoi.io/).

Nothing syncs automatically — you always review first, then apply.

## Daily workflow

```sh
chezmoi diff              # preview exactly what would change on this machine
chezmoi apply             # make it so (only when you say so)

chezmoi add ~/.zshrc      # pull a locally-edited file back into the repo
chezmoi cd                # drop into the repo to review / commit / push
chezmoi update            # git pull + apply in one step (still shows nothing silently; use `chezmoi update --dry-run` first if unsure)
```

`chezmoi status` / `chezmoi diff` never touch anything — safe to run any time to see drift
between the repo and the machine (in either direction).

## New machine bootstrap

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tkuminecz/env
```

That installs chezmoi, clones this repo, prompts for the `secrets` flag (say no until
1Password CLI is set up), and applies. On macOS install Homebrew first; the
`run_onchange_brew-bundle` script then installs everything in `dot_Brewfile`.

## Layout

| Path | What |
|---|---|
| `dot_*` | Dotfiles (chezmoi naming: `dot_zshrc` → `~/.zshrc`) |
| `*.tmpl` | Templates — OS conditionals (`.chezmoi.os`) and `$HOME`-relative paths |
| `bin/` | Personal scripts → `~/bin` |
| `dot_config/` | `~/.config` apps: nvim, zed, starship, karabiner, jj, gh, git |
| `dot_claude/` | Claude Code config: settings, skills, hooks, rules |
| `dot_agents/` | Shared agent skills (firecrawl etc.) that `~/.claude/skills` symlinks into |
| `dot_Brewfile` | Homebrew manifest (macOS only, see `.chezmoiignore`) |
| `run_once_*` | One-time bootstrap (oh-my-zsh, plugins, powerlevel10k) |
| `run_onchange_*` | Runs only when its content/hash changes (brew bundle) |
| `legacy/` | The old pre-chezmoi repo contents, kept for reference during migration |

## Secrets (1Password)

Secret-bearing files (`.npmrc`) are templates that read from 1Password at apply time —
tokens never live in this repo. They are ignored until you opt in:

1. Install + sign in: `brew install 1password-cli`, enable **Settings → Developer →
   Integrate with 1Password CLI** in the 1Password app, then `op vault list` to verify.
2. Create the items referenced in `private_dot_npmrc.tmpl`
   (e.g. `op://Private/npm-fontawesome-token/credential`).
3. Flip `secrets = true` in `~/.config/chezmoi/chezmoi.toml` and run `chezmoi apply`.

## Machines

| Machine | OS | Status |
|---|---|---|
| MacBook | macOS | source of truth for initial import (2026-07) |
| _(linux boxes)_ | Linux | pending hydration |
