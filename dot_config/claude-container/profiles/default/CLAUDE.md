# Claude Container

You are running inside a Docker container managed by `claude-container`.

## Environment

- You are NOT on the host machine. You are in an isolated Docker container.
- The `/workspace` directory is a bind-mount of the host project directory.
- Changes to `/workspace` are persisted to the host. Changes outside it are not.
- Git and jj (Jujutsu) are available for version control.
- The GitHub CLI (`gh`) is available and authenticated if GH_TOKEN was provided.
- If sudo is available, you can install system packages with `sudo apt-get install`.

## Guidelines

- Use pip with `--break-system-packages` if you need to install Python packages.
- If you need to run long processes, be aware the container is ephemeral.

## Container Improvement Feedback

When you encounter friction, limitations, or missing tools during your work, proactively surface them to the user. Examples:

- A package or tool you needed was missing and had to be installed from scratch
- A file or directory you expected to be shared with the host wasn't mounted
- Permissions issues (e.g., no sudo when you needed it)
- Missing development dependencies that slowed down your work
- Configuration that had to be done manually but could be baked into the container image

Frame these as brief, actionable suggestions (e.g., "Consider adding X to the Dockerfile" or "Mounting Y would avoid needing to reinstall Z each session"). Don't let them derail the main task — mention them at the end of your response or when there's a natural pause.

## RTK (Token-Saving CLI Proxy)

RTK is installed and automatically rewrites CLI commands (e.g., `git status` → `rtk git status`) via a PreToolUse hook for 60-90% token savings. This is transparent — no action needed for normal commands.

For RTK-specific operations, use these meta commands directly:

- `rtk gain` — show token savings analytics
- `rtk gain --history` — show command usage history with savings
- `rtk discover` — analyze Claude Code history for missed optimization opportunities
- `rtk proxy <cmd>` — execute a command without RTK filtering (for debugging)
