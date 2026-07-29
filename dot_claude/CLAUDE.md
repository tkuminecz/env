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
   via `pi`**, default model `grok-4.5`.
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

## External delegation: GLM + Grok via `pi` or herdr

Tim pays flat-rate subs for z.ai (GLM 5.2) and x.ai SuperGrok (Grok 4.5, grok-build-0.1), both wired into the `pi` coding agent. A delegated task costs nothing against Anthropic quota, and a bad one costs a `git diff` and a discard. So **external is the default for verifiable execution work** — not a special-occasion alternative I reach for when asked. Opus/fable routing is unchanged.

**Route at plan time.** When a plan is approved, tag every step `grok` / `glm` / `claude` before
starting any of them — an untagged step drifts to the expensive lane by inertia. Decompose plans
so steps are delegable in parallel (interface-first, packages disjoint by file ownership); the
`delegate` skill's "Decompose for delegation" section has the mechanics.

**Delegate by default** — don't deliberate, write the brief and go:

- writing tests to a spec, or turning a described bug into a failing test
- mechanical refactors, renames, signature changes across files
- boilerplate scaffolding — new service file sets, charts, config plumbing
- "make this lint / typecheck / format clean"
- doc and comment sweeps
- any fan-out of similar independent chunks

**Don't delegate**:

- anything touching prod, secrets, credentials, or live infra
- DB migrations and other irreversible or hard-to-review changes
- work where writing the spec *is* the hard part — if I can't write the brief, delegating only moves the problem
- anything needing this conversation's context that won't fit in a brief
- final judgment calls: what to ship, what to tell Tim, whether a review finding is real

Two wrappers on PATH, both dry-runnable with `-n`, never hand-composed flags: **`grok-delegate`**
for unattended grok-4.5 package builds via the grok CLI (bakes in kernel sandbox, deny rules,
`--max-turns`, schema-constrained reports; the sub exposes only grok-4.5 there), and
**`pi-delegate`** for everything else — GLM models, **grok-build-0.1** (the mechanical-swarm lane:
fast small edits and wide tiny fan-outs; still unproven in the log — give it reps), quick
one-shots, and session fix loops. It bakes in the mandatory `--thinking low`, re-adds the
permission-gate extension that `-ne` strips, and derives the provider from the model name. Load
the `delegate` skill for the full playbook (brief template, decompose-for-delegation, worktree
pipeline, review step, scorecard). Non-negotiables: require self-verification in every brief,
independently review the diff myself before accepting, and append a row to the skill's `LOG.md`
afterward.
