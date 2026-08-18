---
name: delegate
description: Route execution work to external subscription models (Grok 4.5 / grok-build via x.ai SuperGrok, GLM 5.2 via z.ai) through the pi CLI or herdr panes. THIS IS THE DEFAULT ROUTE for any task that is well-specified and can verify itself against tests/build/lint/typecheck — ahead of Claude sonnet subagents, which spend Anthropic quota on work these flat-rate subs do for free. Load it BEFORE writing tests to a spec, doing mechanical refactors or renames, scaffolding boilerplate, cleaning up lint/typecheck errors, sweeping docs or comments, or fanning out parallel independent chunks — even when the user has not mentioned delegation. Also load when the user says "delegate", "farm this out", "use pi / GLM / grok / the z.ai or supergrok sub". Skip only for work needing open-ended judgment, prod/secrets/migrations, or this conversation's context.
---

# Delegating to external subscription models

Tim pays flat-rate subscriptions for z.ai (GLM models) and x.ai SuperGrok (Grok models). Both are wired into the `pi` coding agent — z.ai as an API key, x.ai as OAuth tokens (auto-refreshing) in `~/.pi/agent/auth.json`. Marginal cost of a delegated task is zero, so fan out freely; the only budget is undocumented daily/session rate limits on each sub (pi's TUI footer shows usage %).

Delegated agents run with **full autonomy and no permission prompts** (pi has read/bash/edit/write). Only hand them tasks safe to run unattended. Parallel tasks in one repo need worktrees only when their file ownership overlaps or a package needs its own branch/battery — disjoint file-fenced briefs can safely share one checkout (proven across a 7-way fan-out, zero fence violations).

## Which model for which task

All are verified working via `pi --provider <p> --model <m>`. Cost is equal (~zero), so route purely on fit:

| Model | Invoke as | Best at | Avoid for |
|---|---|---|---|
| **grok-4.5** | `--provider xai --model grok-4.5` | Default external workhorse. Strongest external model (#4 AA index, #1 agentic tool use; Terminal-Bench 83.3, SWE-bench Pro 64.7). Fast (~80 tok/s), ~2x more token-efficient than peers. Multi-file changes, harder execution tasks, professional-judgment work. 500K ctx. | Tasks needing >500K context |
| **glm-5.2** | `--provider zai --model glm-5.2` (Tim's pi default) | Repo-scale long context (usable 1M — its headline feature). Iterative run-test-fix loops (measurably better when told to execute and self-verify than one-shot). Self-contained/single-file work, local bug review. Doesn't refuse security-adjacent tasks. Observed (6+ rows): reliably flags false premises in briefs instead of silently applying them — a strong premise-checker and docs/verification-sweep delegate (grok-4.5 is now confirmed at parity on premise checks). Docs caveat: glm drifts on the *semantics* of code it summarizes secondhand — put the exact wording for contract-bearing bullets in the brief. z.ai stalls when 2+ glm runs launch simultaneously — stagger them, and after 2 consecutive zero-CPU stalls reroute the package to grok CLI rather than retrying a third time. The stall pattern also strikes solo staggered runs on bad days (2026-08-13: every glm attempt stalled) — after two strikes anywhere, **drop z.ai for the rest of the day**, not just for that package. | Cross-file reasoning — quality wobbles when correctness spans many files (kilo.ai eval); use grok-4.5 or Claude there |
| **grok-build-0.1** | `--provider xai --model grok-build-0.1` | The mechanical-swarm lane: latency-sensitive small tasks and wide fan-outs of tiny packages — renames, scripted edits, lookups (100+ tok/s). Purpose-trained coding workhorse (SWE-bench Verified 70.8, successor to grok-code-fast). 256K ctx. 6 rows: on genuinely tiny mechanical packages it is an A (gate registration, 4m). Its failure is always the same phase — **the edits land, the report doesn't**: false "ruff clean" on a ruff-failing file, silently dropped coverage, and a sweep that went byte-complete then burned 15s of CPU in 39min and died in verify. Route it mechanical work freely, size the package small, and plan to re-run its gates and salvage its output yourself. | Anything needing judgment; anything gated by a hard external constraint CI can't see (see *Done means*); anything where you would actually rely on the report |
| **grok-4.3** | `--provider xai --model grok-4.3` | Fallback 1M-ctx reasoning model if glm-5.2 is rate-limited on a long-context task. | Generally superseded by grok-4.5 |
| **deepseek-v4-flash-0731** | `--provider openrouter --model deepseek/deepseek-v4-flash-0731` | **Corroboration lane** (10 graded rows: 9 B, 1 A-): in multi-model sweeps and read-only review panels it reliably confirms other models' findings and lands a unique real one roughly every other run (a missed ci-config dep, an untested join, a missing frontend recovery path), but its reports are thinner, it has called authz OK where it wasn't, and its **line-number citations drift (off by up to 200 lines)** — verify by content, never by cite. Slow zero-CPU starts (5–7m) are common and look like hangs; give it a wide `-W`. Pay-per-token via OpenRouter (cheap, not free), and the provider itself flakes some days (hangs, upstream-closed). | Sole coverage of any surface — never the only model on a package; high-stakes or judgment-heavy work; anything where citation precision matters |

Escalate back to **Claude subagents** (per CLAUDE.md routing) when the task holds open-ended judgment, needs conversation context, or must integrate with Agent-tool machinery (structured output schemas, worktree isolation, background notifications).

## Decompose for delegation — at plan time, not as an afterthought

Delegation decided after a plan is written is delegation that mostly doesn't happen. When a plan
is approved, **tag every step `grok` / `glm` / `claude`** before starting any of them — the route
is part of the plan, and an untagged step defaults to the most expensive lane by inertia.

To make steps delegable in parallel rather than sequentially:

- **Interface-first decomposition.** Claude writes the contracts first — signatures, types,
  schemas, test names — and only then carves packages. Packages must be **disjoint by file
  ownership** (each file has exactly one owner this round; the brief's Scope fence states both
  directions).
- **One shared contracts file** in the scratchpad, referenced by absolute path from every brief.
  Cross-package agreement lives there, never in N briefs that can drift.
- **Fan out**: one delegate per package, all launched `run_in_background` in the same message.
  The briefs are the slow part to write; the runs are free and concurrent. Disjoint file fences
  are enough to share one checkout; add a `wt` worktree per package only when a package needs
  its own branch/battery or ownership can't be made disjoint.
- **Sequence against in-flight changes on the same surface.** Don't launch a package while a
  review fix-pass or another builder is still landing changes on files it will read or touch —
  the base moves under it and the reconciliation eats the savings (one clean build graded B
  purely from drift). Launch after the surface settles, or put the pending changes in the brief.
- **Name the seams nobody owns — disjointness guarantees a blind spot.** Every package
  verifying its own fence is exactly why no one tests the file that sits between two fences.
  Live example: three packages added a `virtualColumnId` and all three went green, while
  `retargetRow` in a shared helper silently dropped that id — and it is the write path for
  both derivation engines that run immediately after, so the ticket's headline symptom was
  only half-fixed on precisely the fields it was about. No package owned that file, so no
  package tested it. Before launching, list the files that **read or write the data the round
  changes** and are owned by no package; then either give one package ownership of each, or
  put the list in your own review notes as a required focus area (step 4). Delegates
  frequently spot these from inside their fence and say so in deviations — that same gap was
  named in a deviations report before review confirmed it.
- **Seed the shared interface yourself, before the fan-out.** Committing the shared type and
  the one-line call-site change up front let two genuinely interdependent packages run fully
  concurrent with zero coordination — cheaper than a worktree and cheaper than sequencing.
  Pair it with telling each delegate that its counterpart's half is in flight ("an
  `orAlternative` row may render without a visible 'or' — that is not your bug, assert only
  on what you own"), which is what kept the round free of cross-package test flake.
- **Two-pool rate-limit strategy.** Both subs have undocumented rate limits; a big fan-out on one
  sub can stall the whole round. Split large fan-outs across x.ai and z.ai deliberately —
  glm-5.2 (usable 1M ctx) owns the repo-scale sweep packages; grok takes the multi-file build
  packages. One sub throttling then costs half the round, not all of it.
- **Smoke the providers before committing a fan-out.** Provider health varies by the day, not
  the run: on 2026-08-13 both z.ai and OpenRouter were unusable (every attempt stalled or
  dropped) while grok CLI went clean — the wasted launches, watchdog kills, and relaunches
  cost more than the check. Before a multi-package round that leans on a secondary provider,
  fire a trivial one-shot on it first; if it stalls, route the whole round to grok and stop
  retrying that provider for the day.
- **Cap concurrent launches at 2–3 per provider; stagger the rest.** A 6-way simultaneous launch
  starved BOTH providers: all six runs tripped the CPU-stall watchdog at least once, and z.ai
  stalled both glm runs launched in the same instant. Launch the first 2–3, then release the
  next package as a slot frees (a finished or killed run). On fan-out rounds also pass
  `-W 10` to `pi-delegate` — the 3-minute default stall window is tuned for solo runs and
  false-kills throttled-but-healthy ones. And route the concurrent grok-4.5 packages through
  **grok CLI**, not pi: on the same day pi-grok stalled repeatedly, grok CLI went 4/4 with zero
  stalls (see Path 1b).

### Read-only review panels: the standing shape for merge-readiness reviews

Three graded rounds (PR2419, JUS-2404, JUS-2281) settle it: for a final read-only review of a
big diff, run a **4-model panel** — grok-4.5 @ grok CLI, glm-5.2 @ pi, deepseek @ pi/openrouter,
plus one opus Agent as the reference report — all launched in the same message, all with
`-o <report>` files. Every model has landed a unique real finding at least once, opus is
consistently deepest, and cross-model corroboration is what upgrades a single-model finding to
"real". Verify each unique finding by content (deepseek cites drift). Costs ~10–15m wall-clock
for the whole panel; z.ai/OpenRouter strikes drop that lane, never the panel.

### TDD split: tests and implementation from different delegates

Every B grade in the log shares one failure mode: the delegate's own green tests missed a real
hole — the same mind wrote the code and the proof. For any package worth TDD, split it:

1. **Delegate A** writes the failing test suite from the spec alone — blind to any
   implementation. Tests-as-contract.
2. **Claude reviews the tests** (cheap: read one file against the spec; mutation-test if the
   suite guards something subtle).
3. **Delegate B** implements to green against A's suite, forbidden from editing the tests
   (fence it in the brief; test edits go in the deviations report for Claude to judge).

## Path 1: headless one-shot — use the `pi-delegate` wrapper

```sh
pi-delegate -C <repo-root> "<task>"                  # defaults to grok-4.5, thinking low
pi-delegate -C <repo-root> -m glm-5.2 -f <brief>     # brief file instead of inline task
pi-delegate -n ...                                    # dry-run: print the pi command, don't run
```

`~/bin/pi-delegate` (chezmoi source `bin/executable_pi-delegate`) wraps the raw call so the two
easy-to-forget flags can't be forgotten: `--thinking low` and re-adding the permission-gate
extension that `-ne` strips. It also derives the provider from the model name, so `--provider`
can't drift out of sync with `--model`. Reach for raw `pi` only for flags the wrapper doesn't
expose — and if you need one twice, add it to the wrapper.

The raw equivalent, for reference and debugging:

```sh
cd <workdir> && pi -p --no-session -ne --thinking low \
  -e ~/.pi/agent/git/github.com/tkuminecz/pi-kit/extensions/permission-gate.ts \
  --provider xai --model grok-4.5 \
  "<task>"
```

- `-p` prints the final answer to stdout and exits. `--mode json` (wrapper: `--json`) streams full structured events instead.
- `-ne` skips extension discovery **including MCP servers** — without it every run boots the Notion MCP proxy (~15s + log noise). But `-ne` also strips installed packages, including the permission-gate extension from Tim's `pi-kit` package (blocks rm -rf/sudo/chmod-777 outright in headless runs — verified). Re-add it explicitly: `-ne -e ~/.pi/agent/git/github.com/tkuminecz/pi-kit/extensions/permission-gate.ts`. Shared pi customizations live in that package (`github.com/tkuminecz/pi-kit`, private) — add new extensions there and `pi update --extensions`, never as loose files in `~/.pi/agent/extensions/`.
- **Always set `--thinking low` or `medium`.** Tim's pi default is `high`, which stalled 4+ min on a trivial GLM task; `low` finished the same task in seconds.
- Run via Bash `run_in_background` for anything nontrivial; launch several in parallel for fan-out.
- **Hangs are the single largest cost in the log — arm the watchdog, don't wait for a notification.**
  Four runs have hung with zero work landed (~20h of dead wall-clock): three session-resumes and
  one *fresh* one-shot, so no invocation shape is exempt. The harness reports a hung delegate as
  "running" and the completion notification never arrives.

  **Detect it by CPU, never by elapsed time.** Healthy packages legitimately run 7–45min, so
  "it's been a while" carries no information — and in `-p` mode pi prints only the final answer,
  so an empty output file at minute 5 is equally uninformative. What separates them is work:
  every hang observed sat in `Sl` (blocked on I/O) burning zero CPU, while a live delegate always
  burns CPU somewhere in its process tree. `pi-delegate` therefore:
  - runs the delegate in **its own process group** and samples cumulative CPU across the whole
    group every 20s — so a delegate legitimately blocked waiting on its own `pytest` child still
    counts as alive (verified: parent asleep + busy child → never flagged);
  - **kills the group after 3 minutes of zero tree-CPU** (`-W/--stall <mins>`, `0` disables) and
    exits `125` with a `HUNG` explanation;
  - keeps a 60min total-runtime backstop (`-T/--timeout`, exit `124`) for slow-but-alive runaways;
  - writes every sample to a **heartbeat file**, path echoed to stderr at launch.

  So the answer to "is it alive?" is always one second away — `tail -3 <heartbeat>`: `dcpu>0` and
  `idle=0/N` means working, `idle` climbing means dying. **Check it at ~5 minutes and whenever you
  wonder.** Don't wait on the completion notification, and don't reason about elapsed time.
- **Read the report from the report file, never from a piped stdout.** Both wrappers tee the
  delegate's full stdout to a report file (`-o/--report <path>`, default
  `$TMPDIR/<wrapper>-<pid>.report`, path echoed to stderr at launch). Two review-panel rows
  lost their whole report tail to an orchestrator-side `tail -3` on stdout — the finding was in
  the part that got cut. Pass `-o <scratchpad>/<pkg>.report` and read that file.

  **A watchdog kill is not a verdict of zero work — salvage first, relaunch second.** In the one
  6-way fan-out where all six runs got killed at least once, every kill except one had already
  landed real, completable work; one killed run's edits were byte-complete and only its
  verification phase was lost. Before requeuing a killed package: `git status` + `git diff` the
  tree, run the package's own verification yourself, and relaunch only for what's actually
  missing. Redoing a salvageable package costs more than the hang did.
- pi auto-loads AGENTS.md / CLAUDE.md from cwd — run from the repo root so the agent gets project context (`-nc` disables).
- Follow-up turns: use `--session-id <uuid-you-generate>` instead of `--no-session`; it creates the session if missing and reuses it on later calls (sessions under `~/.pi/agent/sessions/`).

## Path 1b: grok CLI — use the `grok-delegate` wrapper

**Harness split** (head-to-head quality was a near tie, so route by harness capability, not model quality):

- **grok CLI = preferred for unattended grok-4.5 package builds — and mandatory for concurrent ones.** Its harness advantages are exactly what unattended runs want: kernel-enforced `--sandbox`, `--deny` rules, a `--max-turns` runaway cap, and `--json-schema`-constrained completion reports. It is also the reliable lane under load: on a day pi-grok runs stalled repeatedly, grok CLI completed 4/4 packages with zero stalls. The sub exposes ONLY `grok-4.5` in this CLI. It is now the most-used and best-graded lane in the log by a wide margin. One cost, seen in five packages: **a turn cap always bites at the END, so the phase it eats is verification** — the edits are complete and the mutation-RED proofs are simply never run or never reported (salvage-first applies; run the proofs yourself). `grok-delegate` now defaults to `--max-turns 80` for that reason; budget roughly 40 + 8 per proof the brief demands, and raise it further for wide briefs.
- **pi = everything else**: any GLM model, grok-build-0.1, quick one-shots, and fix loops (as fresh one-shots — pi's session-resume is the hang-prone path) — plus one interface across both subs.

`~/bin/grok-delegate` (chezmoi source `bin/executable_grok-delegate`) is the pi-delegate sibling that bakes in the unattended posture so it can't be forgotten: `--permission-mode bypassPermissions` (headless runs can't answer prompts) **plus** the two enforced layers that make that safe — `--sandbox workspace` (kernel-limits writes to the working dir + tmp) and default deny rules (sudo, `rm -rf`, `chmod 777` for pi-kit gate parity, and `git push` — delegates commit, Claude reviews and pushes). Also `--max-turns 80`, `--output-format plain`, `--no-auto-update`.

**The sandbox now auto-downgrades instead of faking success.** grok's sandbox needs unprivileged user namespaces; jb-dev denies them (`bwrap: setting up uid map: Permission denied`) and grok responds by exiting **0** with a one-line error — which reads as a completed run in the task notification and cost a wasted round-trip four separate times. When `--sandbox` is not passed explicitly the wrapper probes the primitive and falls back to `off` with a warning on stderr. Pass `--sandbox` explicitly to opt out of the probe.

```sh
grok-delegate -C <repo-root> -f <brief>               # brief file → native --prompt-file
grok-delegate -C <repo-root> "<task>"                 # inline one-shot
grok-delegate -o <scratchpad>/<pkg>.report ...        # tee full stdout to a report file (also default-on)
grok-delegate --json '<schema>' ...                   # schema-constrained JSON report
grok-delegate -s <session-id> "<fix instructions>"    # resume for a fix loop
grok-delegate -n ...                                  # dry-run: print the grok command
```

Its `--worktree` passthrough refuses to run without an explicit `--worktree-ref` — grok's worktrees are bare (no `wt` hooks: env files, deps, port offsets, certs), so for platform-monorepo packages keep the pipeline `wt switch --create <branch>` first, then `-C <worktree>`.

pi is deliberately minimal but **extensible by design** (extensions, custom tools, skills — Tim: "sort of the intended way to use pi"). If a grok-CLI-only feature becomes a recurring need — approval gating, structured output, a delegation-brief tool — the preferred move is writing a pi extension (`pi install`, `-e <path>`) rather than switching harnesses.

## Path 2: via herdr (runtime-agnostic, user-visible)

Prefer this when the user should be able to watch or take over, or to reuse a warm agent pane. Works with any agent kind herdr supports (pi, claude, codex, gemini, ...).

```sh
herdr agent list                                    # JSON: pane_id, kind, status, cwd, session file
herdr agent prompt <pane_id> "<task>" --wait --timeout <ms>
herdr agent read <pane_id> --lines <N>              # scrape terminal output
herdr agent wait <pane_id> --until idle --timeout <ms>
```

- **`agent_prompt_stalled` is often a false negative**: it fires when the agent finishes inside the 5s state-change window. The reply usually landed — `agent read` the pane before assuming failure.
- For structured output, read the agent's session file instead of scraping: `agent list` exposes it as `agent_session.value` (pi sessions are .jsonl).
- Spawning fresh panes: `herdr workspace create` / `herdr tab create` → `herdr agent start <name> --kind pi --pane <id>`, then prompt/wait/read.
- A pane belongs to the user's workspace — prefer idle panes whose cwd matches the task, and don't hijack a pane mid-conversation.

## Prompting delegated agents

These models share none of your conversation context. Every delegation prompt needs:

1. **Concrete scope** — files/paths involved, what done looks like, acceptance criteria.
2. **A self-verification step** — "run the tests / build / script and report PASS or FAIL with the output." GLM 5.2 in particular performs significantly better when told to execute and self-debug iteratively rather than one-shot.
3. **Explicit wording** — for GLM, prompt phrasing moves results more than thinking level does. Say exactly what to check.

4. **A deviations section** — end the brief with: "In your final report, list every place you deviated from this spec and why." Honest deviations are common and often right, but they can carry product decisions the user should hear about — read them before merging.

Then **verify yourself**: treat the output as an untrusted contribution — diff-review the changes and run the project's full test/lint suite before accepting. Never report delegated work as done on the agent's say-so alone.

## Light path vs full pipeline

Delegates may edit files **directly in the current checkout on the current branch** for small, sequential tasks — uncommitted changes are easy to review with `git diff` and easy to discard, exactly like any other local edit. Don't reach for worktrees by default. The full pipeline below earns its overhead only when work is **parallel** (agents would collide in one checkout) or **package-sized** (a feature/rebuild whose diff deserves its own branch, battery, and review round).

## Build packages: worktree + merge pipeline

For delegations bigger than a one-shot (a feature, a rebuild, parallel packages), use the full pipeline. Calibration from a comparable grok-delegation workflow (~10 packages): the builder is fast, idiomatic, honest about deviations, and green on tests — **and its self-verification is structurally blind to composition bugs**. Independent review caught 3 criticals and ~30 real warnings *after* green tests plus a builder self-review that reported zero findings. So step 4 is not optional.

1. **Brief.** Write a self-contained brief file (builder has no conversation context) to the scratchpad, and point the pi invocation at it (`pi -p ... "Read and execute the brief at <abs path>"`). Sections, all load-bearing:
   - *Goal* — one paragraph, plain english.
   - *Scope* — explicit files/dirs this package owns. For parallel packages, add a fence: "do NOT touch X — owned by another package this round." This is the disjointness contract.
   - *Git hygiene* (**mandatory in every shared-checkout brief**). A shared checkout is safe
     for edits and unsafe for git *state* — the working tree is fenced by the brief, but the
     index, the stash and the hooks are one shared resource that fences cannot partition. Two
     verbatim clauses handle all of it:

     "Do NOT use `git stash`, `git checkout -- <file>`, or `git reset` at any point. Other
     packages have uncommitted work in this checkout and all three silently revert it. To
     restore a file after a mutation proof, keep a byte copy (`cp f /tmp/f.bak` …
     `cp /tmp/f.bak f`) and confirm the restore with `cmp /tmp/f.bak f`."

     "Never run `git commit`. Leave every change uncommitted, and end your report with a
     pasted `git status --porcelain` — every path in it must sit inside your fence."

     Why each word is load-bearing: delegates reach for `stash` unprompted to isolate their
     own work, and a file fence does not stop them because stashing isn't "touching" another
     package's file — naming the mechanism is what stops it. The restore proof must be `cmp`
     against a byte copy, never `git diff --exit-code`: in a no-commit round the file
     legitimately differs from HEAD the whole time, so the check can never pass — and when it
     *does* come back clean, that only proves a revert if the file had no uncommitted work of
     its own, otherwise it silently means that work is gone and gets reported as success.

     **No-commit is the default for every concurrent round, and it has now run clean across
     ~20 concurrent packages** (zero fence violations, zero index collisions). It earns that
     by removing two failure classes outright rather than mitigating them: a bare
     `git commit` after `git add` sweeps whatever a sibling had staged (seen twice in one
     round, once by a *dying* delegate that took three of a sibling's files with it), and
     every pre-commit hook run opens an autostash window in which the tree lies to whoever
     reads it — one delegate concluded the tree had been clobbered and rewrote production
     files from memory while reporting "no production edits from this package", and one
     orchestrator `git status` came back clean mid-window when it wasn't. The orchestrator
     assembles commits at PR time and fixes boundaries once.

     When a delegate commit is genuinely wanted (sequential work, or a package on its own
     branch/worktree), require it **pathspec-limited** — `git commit -m "<msg>" -- <your
     files only>` — and keep bare `git commit` after `git add` banned. In multi-group briefs
     demand *incremental* commits per group: three grok-CLI packages hit the turn cap at the
     end with everything committed and only the report lost, which is the difference between
     an A and a redo.
   - *Read first* — repo docs (AGENTS.md/CLAUDE.md auto-load if run from repo root) plus the exact files touched and any shared-context file (cross-package contracts go in one shared scratchpad file referenced by absolute path from every brief).
   - *Spec* — numbered, testable requirements. Any file content or code behavior the brief
     quotes or asserts must be **verified against the file at brief-writing time** — one brief
     shipped a quote that wasn't in the target file; the delegate caught it, but only a good
     one does. **The same bar applies to any facts sheet or CONTRACT.md the brief points at**:
     the brief-writer owns every error in supplied ground truth (both misses in one otherwise
     clean docs package traced to the facts sheet, not the model). For a package-sized contract
     feeding a fan-out, have an independent opus pass review the contract BEFORE launching
     builders — the one contract gap that reached review was a spec defect no builder could
     have caught.
     The same bar covers **repo conventions the brief prescribes** — a briefed dbt test tag
     (`data_quality`) made the delegate's singular test invisible to the harness and CI per the
     repo's own docs; the delegate followed the brief exactly. Check tag/marker/registration
     conventions against the repo docs before writing them into a spec.
     **Run every command the brief quotes, in the package it names, before shipping the brief.**
     A CONTRACT.md that said `pnpm vitest run <path>` from the repo root skipped the portal's
     jsdom config; both portal delegates then burned turns attributing ~30 phantom failures
     that vanish when the same suite runs from the package. A wrong command does not read as a
     brief defect to the delegate — it reads as a broken repo, and it spends the turn budget
     that the verification phase needed.
     **State known premises you have NOT verified as explicitly unverified** — "treat this as
     false until a test says otherwise" made a delegate correctly disprove a bug instead of
     inventing a fix for it. A shaky premise stated flatly gets implemented.
     **Also fence the delegate's vocabulary**: "do not name packages, briefs, or this
     delegation in code comments — the code outlives the round." Unprompted, 2/2 delegates
     wrote `// Package B` into permanent files; the round after the clause was added, zero did.
   - *Stop conditions* — the brief must say when to stop rather than proceed. Always include
     both: "if production code appears reverted or deleted, STOP and report — do not
     reconstruct it", and "**if a test cannot be made to pass without weakening an assertion
     the spec names, STOP and report** — the implementation is what's on trial, not the
     assertion." The second exists because the weaker fence ("if the test reveals a production
     bug, STOP — do not fix") only half-works: a delegate obeyed it literally, didn't fix the
     bug, and instead bent its own test down to the buggy result and documented the gap as
     "a legitimate difference by design". It wasn't; the acceptance criterion said the two
     paths must match. A weakened assertion is invisible in a green suite.
   - *Done means* — battery green + specific acceptance checks; require a single clean commit —
     except in concurrent shared-checkout rounds, where the default is no delegate commits at all
     (see *Git hygiene*) and the deliverable is a fence-clean `git status --porcelain` instead.
     **When the deliverables include ANY tests — even inside a fix package — require mutation
     RED proofs**: for each core behavior, break the code under test, paste the failing suite
     output, restore byte-identical — with assertions on exact/structural tokens (never bare
     substrings) sitting at the layer where the risk lives (the seam the change exercises, not
     a pure helper next to it). Every suite briefed this way came back clean (7/7 packages);
     every one briefed without it shipped can't-fail or wrong-layer assertions (5/5). Also require
     **fix what you flag**: an issue the builder notices in its own output gets fixed or
     explicitly argued in the deviations report, never just mentioned.
     **Demand evidence, not claims, for every gate**: paste the actual command and its output for
     each of lint / typecheck / tests, plus the git proof matching the round's commit mode —
     `git log --oneline -1` and `git status --porcelain` proving the single clean commit exists
     and nothing was left uncommitted, or (no-commit rounds) `git status --porcelain` alone with
     every path inside the fence. Three rows shipped
     a false or absent gate claim ("ruff clean" on a ruff-failing file; coverage silently dropped;
     a package that never committed at all) — a summary sentence is not evidence, and re-running
     the claimed gates yourself costs seconds.
   - *Forbidden or unavailable test tiers are the orchestrator's tier.* When the brief forbids
     running a tier (integration, real-stack) or the delegate's env lacks it, the delegate is
     structurally blind there — 3 of 4 B grades in one window were exactly this. Before launch,
     enumerate that tier's existing assertions on the semantics the package changes and plan to
     run the tier yourself post-merge. Conversely, an impl brief whose change re-keys shared
     fixtures or literals must tell the delegate to run the *neighboring* suites, not just its
     own — "its tests are green" says nothing about the suite next door.
   - *Hard external constraints* — when correctness depends on a limit that lint/typecheck/CI
     cannot see, name the limit in the brief and require a real-stack proof. Live example: Alembic
     revision ids must fit `alembic_version VARCHAR(32)`; both ids in one package overran it and
     `upgrade head` hard-failed on real Postgres while every CI gate stayed green. Same shape for
     DB column widths, Restate wire-name limits, and identifier caps generally — require the
     delegate to run the thing (`alembic upgrade head` then `downgrade`) and paste the output.
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Read the deviations reports first, then review — always.** The builders' deviations
   sections and their narration are a *review input*, not a formality: they have located the
   confirmed finding ahead of the reviewer three times (the unowned `retargetRow` seam; a
   struggling narration that pinned the exact bad test before the diff was opened; a
   "prescribed mutation was vacuous" note that turned out to be a production bug, not a
   mutation-design problem — **treat a vacuous mutation on the field under test as a bug
   signal, never as a brief defect to work around**). Then capture the diff
   (`git show <sha> > <scratchpad>/<slug>-diff.txt`) and launch a fresh-context **opus**
   review subagent (per CLAUDE.md routing) with: the diff path, changed-file list, domain
   rules, the unowned-seam list from the decompose step, and focus hints *including your own
   suspicions and anything the builder's self-review dismissed*. Builder self-review raises
   the floor; it never substitutes for this. When a delegate documents a divergence as
   "intended by design", check it against the ticket's acceptance criterion rather than
   against the implementation. In read-only audit/sweep reports, the *finding* and its *fix
   sketch* carry different reliability: findings backed by quoted code hold up, but the
   remediation sketch is often wrong (a `ref()` on a column that doesn't exist; a cost the
   sketch attributes to a path that's gated off). Verify sketches independently — a wrong
   sketch does not invalidate the finding, and a real finding does not validate the sketch.
5. **Fix pass, push, cleanup.** Confirmed findings go **back to the builder, not to your own editor** — the builder holds the package context; hand-fixing burns Claude time re-deriving it and silently takes Claude out of the reviewer seat. Fix by hand only when the fix is smaller than the brief for it. **Prefer a fresh one-shot carrying the fix list over resuming the session** (pi session-resume hung 3 of 4 attempts; both fresh fix one-shots finished in ~20m) — a fix list is self-contained enough that the lost context rarely matters. grok CLI resume (`grok-delegate -s <session-id>`) has not hung. Re-run the battery, push, then remove the worktree.
6. If the target branch moved while the builder ran, expect conflicts in shared files — resolve keeping both intents, never discard either side blind.

## Scorecard: log every delegation

`LOG.md` next to this file is the calibration record — it travels with the skill. After each
delegated task finishes its pipeline (including one-shots), append a row: date, task, model @
harness, grade (**A** merged as-is / **B** minor fixes / **C** major rework / **F** discarded),
wall time, what independent review caught that the delegate's self-verification missed, notes.

Logging is not bookkeeping — it is the only input the retro has. A delegation that never got a
row is a delegation the routing table can never learn from. Write the row even when the result
was perfect, especially when it was bad, and record the grade honestly rather than generously.

When routing a new task, skim the distilled-patterns section first: observed history beats
benchmarks, and the table above is downstream of it.

## Retro: keep the approach improving

Two triggers, whichever comes first — **5 new rows** since the last retro, or **14 days** with
at least one new row — **gated by a 1-day cooldown**: never auto-fire within 1 day of `last`,
however many rows pile up (a heavy fan-out day can log 5+ rows in hours; rows just accumulate
until the cooldown lapses). `LOG.md`'s `retro-state` header line carries both counters; read it
when loading this skill (you're reading the file for patterns anyway). On demand:
`/delegate retro` — runs regardless of cooldown.

### Where the retro runs — never inline

**Do not run the retro in the session that tripped the trigger.** It reads the whole log, edits
routing config, and argues with itself about past grades; doing that inline derails whatever the
user was actually working on. When the trigger fires mid-task, say so in one line, launch the
retro in its own herdr workspace, and carry on with the task at hand.

It runs in the **root platform worktree, `~/jb/platform`** (`~/jb` is a symlink to `~/repos`, so
this is the main checkout on `main` — not a feature worktree). Two reasons: the retro's memory
scope is the `-home-tim-repos-platform` project, and a feature worktree's branch state is
irrelevant noise to it. The retro edits dotfiles and chezmoi sources, never repo files, so it
cannot conflict with work in progress there.

Verified recipe:

```sh
# 1. fresh workspace, unfocused so it doesn't steal the user's screen
WS=$(herdr workspace create --cwd ~/jb/platform --label "delegate-retro" --no-focus \
     | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")

# 2. a Claude session in it, pointed straight at the retro
herdr agent start delegate-retro --cwd ~/jb/platform --workspace "$WS" --no-focus \
  -- claude "/delegate retro"

# 3. read progress (NOT --source recent, which returns empty)
herdr agent read delegate-retro --source visible --lines 40

# 4. when it has landed its edits
herdr workspace close "$WS"
```

Gotchas, all confirmed by running them:

- `workspace create` returns the id at `result.workspace.workspace_id` — not `result.workspace_id`.
- `agent read` needs `--source visible`; the default (`recent`) comes back empty.
- `agent start` splits a new pane into the workspace rather than reusing the root pane.
- Close the workspace when done — an abandoned retro workspace is indistinguishable from the
  user's own and will accumulate.

Tell the user the workspace label and that it's running unfocused, so they can attach
(`herdr agent attach delegate-retro`) and take it over if they want a say in the routing changes.

Ask these, in order, against the rows since the last retro:

1. **Grade distribution.** Where do C/F cluster — a model, a task shape, or a brief defect? One
   bad row is noise; the same shape twice is a routing change.
2. **What review caught that self-verification missed.** Is there a recurring *class* (input
   validation, cross-file composition, silent scope creep)? A class that repeats becomes a
   required focus hint in step 4, or a required check in the brief template.
3. **Routing errors both ways.** Any task sent external that should have stayed with Claude —
   and, just as important, any task I kept in-house that belonged on the delegate-by-default
   list. The second failure is invisible unless deliberately looked for; it's the one this whole
   setup exists to fix.
4. **Brief defects.** Did a failure trace back to a missing or vague brief section? Amend the
   template rather than resolving to write better briefs.
5. **Friction.** What made delegation feel more expensive than doing it myself? If the answer is
   a command shape, fix `pi-delegate`; if it's a decision, fix the routing lists in CLAUDE.md.
6. **Kill criterion.** Did review + fixing cost more than doing the task in-house would have? If
   that holds across several rows for a task shape, remove that shape from delegate-by-default.
   The default is a bet, not a commitment.

Then act — a retro that only writes findings is a wasted retro:

- edit the routing table, brief template, or failure-modes list in this file — **in the chezmoi
  source (`dot_claude/skills/delegate/SKILL.md`), then `chezmoi apply` that path and diff-verify
  source vs live before ending the retro.** The 2026-07-27 retro edited the source and never
  applied; the live skill served a stale version for two days.
- edit the delegate-by-default / don't-delegate lists in `~/.claude/CLAUDE.md` (chezmoi source
  `dot_claude/CLAUDE.md` — edit there, then `chezmoi apply` that path, or the next apply reverts it)
- promote repeated observations into **Distilled patterns** and prune the raw rows they came from
- reset the `retro-state` header, and append a one-line retro entry recording what changed

Early on the log is thin and every row moves the picture; once patterns stabilize, prune
aggressively — the log should stay a page, not an archive.

## Known failure modes

- z.ai API calls occasionally flake and need a retry (community-reported; retry once before switching models).
- Rate limits on both subs are undocumented; if a provider throttles, switch to the other sub's equivalent model.
- `--thinking high` on glm-5.2 can stall for minutes — never use it for delegation.
- Headless pi with a hung task: check `ps` for the `pi` child process; kill and rerun at lower thinking.
