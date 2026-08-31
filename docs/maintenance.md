# Maintenance — periodic update checks

Nothing here runs itself; these are the cadence commands the fleet runs on.
Pick a rhythm (monthly is a good default) and run them from a machine you
care about. All are idempotent — re-running is safe.

## Tool update check (every month or so)

```sh
# pi itself + every installed pi extension/package together.
# NOTE: plain `pi update` updates pi ONLY. Extensions need --all.
pi update --all

# Agent Skills CLI (skills from github sources, e.g. progress-check).
npx skills update -g
npx skills list          # shows installed + versions to eyeball staleness

# chezmoi-managed env — pull the shared source and see what changes.
chezmoi update  --dry-run   # preview only; run `chezmoi update` to apply
```

Use it as the "anything new?" pass, then:

- `pi update` self / `pi update <source>` — update one thing
- `npx skills add <owner>/<repo> --skill <name> -g` — (re)add a skill,
  then `chezmoi add` the new files + updated `~/.agents/.skill-lock.json`
- after a pi self-update, **watch pi's startup output for extension
  compatibility warnings**

## Known gotchas this repo has hit

- **pi extensions can lose their applied runtime patch after a pi
  self-update**, even when versions look unchanged. If an extension
  "stops working" after `pi update`, reinstall it (forces re-init):

  ```sh
  pi update --force --extensions        # or:
  pi remove <source> && pi install <source>
  ```

  Real case: `@99percentpeople/pi-thinking-fold` stopped folding after a
  pi update; a forced reinstall restored it at the *same* version.

- **Third-party skills are pinned when committed** (they're vendored into
  this repo). Updating means re-running the skills CLI for that source,
  then committing the diff. There's no auto-update for vendored skills —
  that's the point of the periodic pass above.

- `~/.agents/.skill-lock.json` records the installed skills + their exact
  source commit state. Keep it in sync with what CI/new machines expect
  by committing it after installs/updates.