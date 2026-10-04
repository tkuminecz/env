@~/AGENTS.md

# Model selection for subagents

My interactive model is **Opus 5** (`claude-opus-5[1m]`, set in `settings.json`). That makes fable an
*escalation target* rather than the orchestrator: I route work **up** to it when a task is genuinely
at the top of the difficulty range, and everything else down. A subagent with no `model:` inherits
mine, so pass `model:` explicitly on every spawn — the choice is load-bearing in both directions.

- **fable** — the hardest judgment work, escalated to deliberately. See "Escalating to fable" below for
  the trigger list; it costs 2× opus per token, so it earns the spawn rather than getting it by default.
- **opus** — judgment not yet resolved: codebase exploration/analysis that will feed a plan, spec or design
  work, debugging where the root cause is unknown, and code review. The default when the answer is still open.
- **sonnet** — judgment resolved: executing a concrete plan, mechanical edits, test/doc writing, known-fix
  bugfixes, narrow "where is X" lookups. But this class goes **external by default** (below) — reach for
  sonnet within it only when the result must flow through Agent-tool machinery (structured-output schema,
  worktree isolation, background notification) or the task needs conversation context too large for a brief.
- **haiku** — don't use.

Router — four outcomes:

1. Top-of-range judgment work (the fable list below)? → **fable**, in the background.
2. Open-ended judgment left? → **opus**.
3. No judgment left, and there's a way to verify it (tests/build/lint/typecheck)? → **delegate externally
   via `pi`**, default model `grok-4.6`.
4. Same as 3, but the result needs Agent-tool machinery or this conversation's context? → **sonnet**.

This governs subagents and external delegation only — my own interactive model is set via /model, not here.

## Escalating to fable

Fable's advantage shows on work *above* what other models handle, not on work they already do well —
Anthropic's own guidance is to give it the hardest problems rather than the routine ones. Escalate when
the task is one of these shapes **and** either it's high-stakes/hard-to-reverse, or an opus pass already
ran and came back stuck, empty, or unsure:

- design/architecture documents and specs for a whole feature or subsystem
- decomposing a PRD or roadmap into tickets with a real dependency graph
- root-cause debugging that survived a first serious attempt
- long-horizon autonomous builds — a well-specified system implemented end to end in one run
- cross-cutting refactors whose correctness spans many files or services
- re-reviewing a large or subtle diff when a normal review found nothing but something is still wrong
- repository archaeology — "why is this the way it is", across history

**Do not escalate to fable for:**

- **security review — use opus.** Two independent reasons: fable's documented bug-finding gains explicitly
  *exclude* security-focused analysis, and its cyber classifiers can decline benign security work outright
  (HTTP 200 with `stop_reason: "refusal"`), which surfaces as an empty or truncated result rather than an error.
- anything already well-specified and verifiable — that's pi's lane, and fable is the most expensive way to do it
- quick lookups, mechanical edits, routine review
- a task no one has attempted yet that opus would probably land — at 2× the price, fable earns the escalation

**Briefing a fable subagent is different.** Over-prescriptive, step-by-step prompts measurably *reduce* its
output quality — state the goal, the constraints, and what done looks like, then let it choose the approach.
That is the opposite of how to brief sonnet or an external pi delegate, where enumerated steps help. Run it
in the background: single fable turns on hard tasks routinely take many minutes, and that's expected, not a hang.

## Leverage herdr

When running inside herdr (HERDR_ENV=1), use it actively rather than keeping everything in
one pane: open documents for review in a vertical pane (`glow -p` for markdown), show diffs
there, and run delegated agents or long-running work in their own panes/tabs. Anything Tim
needs to read and react to — a plan, a proposal, a diff — reads better in its own pane than
scrolled through chat. Close panes when their content is dealt with. Load the `herdr` skill
for the mechanics.

## External delegation: GLM, Grok and Codex via `pi`, herdr or queohoh

Tim pays flat-rate subs for z.ai (GLM 5.3 / 5.3-flash / 5.2), x.ai SuperGrok (Grok 4.6, grok-build-0.1) and OpenAI Codex (`gpt-*`, e.g. Codex Luna), all wired into the `pi` coding agent (OpenRouter's DeepSeek models are wired in too, but bill per token). A delegated task costs nothing against Anthropic quota, and a bad one costs a `git diff` and a discard. So **external is the default for verifiable execution work** — not a special-occasion alternative I reach for when asked. Opus/fable routing is unchanged.

**Route at plan time.** When a plan is approved, tag every step `grok` / `glm` / `claude` before
starting any of them — an untagged step drifts to the expensive lane by inertia. Decompose plans
so steps are delegable in parallel (interface-first, packages disjoint by file ownership); the
`delegate` skill's "Decompose for delegation" section has the mechanics.

**The router applies inside skill flows too.** When a skill (`/github-fix-review-feedback`,
`/self-review`, etc.) produces a fix list or work items, tag each item grok/glm/claude before
starting, same as a plan. And for multi-package features, maximum parallel fan-out is the
default — decompose for width first, not a sequential plan with a couple of delegated steps.

**Delegate by default** — don't deliberate, write the brief and go:

- writing tests to a spec, or turning a described bug into a failing test — and for any package
  worth TDD, split it: one delegate writes the RED suite blind, another implements to green and
  may not edit the tests (validated 4/4 A across three providers)
- mechanical refactors, renames, signature changes across files
- boilerplate scaffolding — new service file sets, charts, config plumbing
- "make this lint / typecheck / format clean"
- doc and comment sweeps (then read every rewritten comment against the code, since clarity
  rewrites have introduced false claims)
- any fan-out of similar independent chunks
- final read-only merge-readiness reviews of a big diff → the 4-model panel (grok CLI with
  `--read-only` + glm + deepseek + one opus Agent as reference; `delegate` skill "Read-only
  review panels")

**Don't delegate**:

- anything touching prod, secrets, credentials, or live infra
- applying migrations to any shared database, and other irreversible or hard-to-review changes.
  *Writing* a migration revision against a schema contract I pinned is delegable. All 7 such
  packages graded A (08-20→09-22), and the one defect that turned up was in my contract. The
  brief names the 32-char revision-id cap and requires `upgrade head` then `downgrade` on real
  Postgres, or offline `--sql` with the live run owed to me
- work where writing the spec *is* the hard part — if I can't write the brief, delegating only moves the problem
- anything needing this conversation's context that won't fit in a brief
- live-environment evidence: MCP-backed queries (dagster-plus, Superset, Sentry) and
  in-process harness measurements. Delegates have no MCP, so pair their sweep with a Claude
  lane for that part
- final judgment calls: what to ship, what to tell Tim, whether a review finding is real
- program-sized builds (≳3k changed lines or a whole subsystem): Opus builds those. In the mgc
  ledger, 35 Opus-built lanes had zero C grades. External builders at that size hit lane caps,
  429s and review timeouts, or skipped the gate, and on mgc program rows even 105–260-card rows
  ran past the 6 h cap. Use external only when Anthropic usage is the binding limit, and then
  behind a mechanical gate (skill: "Size line")

Two wrappers on PATH, both dry-runnable with `-n`, never hand-composed flags: **`grok-delegate`**
for unattended grok package builds via the grok CLI — **now the primary and best-graded
lane** (deny rules, `--max-turns 80`, `--read-only` for review lanes, exit 3 when x.ai refuses
for credit, schema-constrained reports; its kernel sandbox needs bubblewrap, not yet installed on
tim-dev, and auto-downgrades where the host denies user namespaces) —
and **`pi-delegate`** for everything else — GLM models, Codex (`-m gpt-5.6-luna`), OpenRouter ids,
**grok-build-0.1** (the mechanical-swarm lane: keep its packages genuinely tiny; its edits land
but its *report phase* is where it dies, so re-run every gate it claims and expect to salvage;
first tim-dev reps 2026-09-26), quick one-shots, and fix loops. It bakes in the mandatory
`--thinking low`, re-adds the permission-gate extension that `-ne` strips, derives the provider
from the model name, and **watchdogs the run by CPU**: the delegate gets its own process group,
tree-CPU is sampled every 20s to a heartbeat file, and a tree burning zero CPU for 6min is killed
as hung (exit 125; 120min backstop cap = 124). `tail -3 <heartbeat>` answers "is it alive?" in a
second — check it early rather than waiting on a notification that never comes for a hang. Load
the `delegate` skill for
the full playbook (brief template, decompose-for-delegation, worktree pipeline, review step,
scorecard). Non-negotiables: require self-verification **with pasted command output** in every
brief, independently review the diff myself before accepting, and append a row to the skill's
`LOG.md` afterward.
