@~/AGENTS.md

# Model selection for subagents

When spawning a subagent, set the Agent tool's `model:` by how much open-ended judgment the task still holds — not by task type. A subagent with no `model:` inherits my model and I won't downgrade on my own, so this choice is load-bearing: pass `model:` explicitly on every spawn.

- **opus** — judgment not yet resolved: codebase exploration/analysis that will feed a plan, spec or design work, debugging where the root cause is unknown, and code review (bug-finding recall is worth the tokens). Default when the answer is still open.
- **sonnet** — judgment resolved: executing a concrete plan, mechanical edits, test/doc writing, known-fix bugfixes, and narrow "where is X" lookups. Use it whenever the task is well-specified AND has a way to check itself (tests/build/lint/typecheck) or I'll review the output.
- **fable** — reserve for the hardest long-horizon reasoning; almost always the orchestrator, rarely a subagent. Not a default.
- **haiku** — don't use.

Router: is there open-ended judgment left? No, and there's something to verify against → sonnet; otherwise → opus. This governs SUBAGENTS only — my own interactive model is set separately via /model, not here.

## External delegation: GLM + Grok via `pi` or herdr

Besides Claude subagents, I can delegate to external subscription models — GLM 5.2 (z.ai) and Grok 4.5 / grok-build-0.1 (x.ai SuperGrok) — through the `pi` coding agent headless mode or herdr agent panes. Flat-rate subs, so fan-out costs nothing against Anthropic quota. Treat them as alternatives to **sonnet**: well-specified, self-verifiable execution work. Keep sonnet when the result must flow through Agent-tool machinery (structured output, worktrees, notifications); opus/fable routing is unchanged.

The `delegate` skill is the playbook — load it before delegating. Short version: grok-4.5 is the default external workhorse; glm-5.2 for 1M-context repo-scale work and iterative run-test-fix loops; grok-build-0.1 for quick mechanical tasks. Canonical call: `cd <dir> && pi -p --no-session -ne --thinking low --provider <xai|zai> --model <m> "<task>"` — never leave thinking at the default `high` (it stalls). Always require self-verification in the prompt and verify the result myself.
