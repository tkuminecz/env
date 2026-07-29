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
| **glm-5.2** | `--provider zai --model glm-5.2` (Tim's pi default) | Repo-scale long context (usable 1M — its headline feature). Iterative run-test-fix loops (measurably better when told to execute and self-verify than one-shot). Self-contained/single-file work, local bug review. Doesn't refuse security-adjacent tasks. Observed (4/4 A on scoped packages): reliably flags false premises in briefs instead of silently applying them — good premise-checker. | Cross-file reasoning — quality wobbles when correctness spans many files (kilo.ai eval); use grok-4.5 or Claude there |
| **grok-build-0.1** | `--provider xai --model grok-build-0.1` | The mechanical-swarm lane: latency-sensitive small tasks and wide fan-outs of tiny packages — renames, scripted edits, lookups (100+ tok/s). Purpose-trained coding workhorse (SWE-bench Verified 70.8, successor to grok-code-fast). 256K ctx. **Benchmark-faith row — still zero LOG.md rows after two retro cycles.** Hard rule until 3 rows exist: the next mechanical task (rename, scripted edit, lint sweep, tiny fan-out package) routes here, not to grok-4.5. | Anything needing judgment |
| **grok-4.3** | `--provider xai --model grok-4.3` | Fallback 1M-ctx reasoning model if glm-5.2 is rate-limited on a long-context task. | Generally superseded by grok-4.5 |

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
- **Two-pool rate-limit strategy.** Both subs have undocumented rate limits; a big fan-out on one
  sub can stall the whole round. Split large fan-outs across x.ai and z.ai deliberately —
  glm-5.2 (usable 1M ctx) owns the repo-scale sweep packages; grok takes the multi-file build
  packages. One sub throttling then costs half the round, not all of it.

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
- pi auto-loads AGENTS.md / CLAUDE.md from cwd — run from the repo root so the agent gets project context (`-nc` disables).
- Follow-up turns: use `--session-id <uuid-you-generate>` instead of `--no-session`; it creates the session if missing and reuses it on later calls (sessions under `~/.pi/agent/sessions/`).

## Path 1b: grok CLI — use the `grok-delegate` wrapper

**Harness split** (head-to-head quality was a near tie, so route by harness capability, not model quality):

- **grok CLI = preferred for unattended grok-4.5 package builds.** Its harness advantages are exactly what unattended runs want: kernel-enforced `--sandbox`, `--deny` rules, a `--max-turns` runaway cap, and `--json-schema`-constrained completion reports. The sub exposes ONLY `grok-4.5` in this CLI.
- **pi = everything else**: any GLM model, grok-build-0.1, quick one-shots, and fix loops on existing pi sessions — plus one interface across both subs.

`~/bin/grok-delegate` (chezmoi source `bin/executable_grok-delegate`) is the pi-delegate sibling that bakes in the unattended posture so it can't be forgotten: `--permission-mode bypassPermissions` (headless runs can't answer prompts) **plus** the two enforced layers that make that safe — `--sandbox workspace` (kernel-limits writes to the working dir + tmp) and default deny rules (sudo, `rm -rf`, `chmod 777` for pi-kit gate parity, and `git push` — delegates commit, Claude reviews and pushes). Also `--max-turns 40`, `--output-format plain`, `--no-auto-update`.

```sh
grok-delegate -C <repo-root> -f <brief>               # brief file → native --prompt-file
grok-delegate -C <repo-root> "<task>"                 # inline one-shot
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
   - *Done means* — battery green + specific acceptance checks; require a single clean commit.
     **When the deliverables include ANY tests — even inside a fix package — require mutation
     RED proofs**: for each core behavior, break the code under test, paste the failing suite
     output, restore byte-identical — with assertions on exact/structural tokens (never bare
     substrings) sitting at the layer where the risk lives (the seam the change exercises, not
     a pure helper next to it). Every suite briefed this way came back clean (n=2); every one
     briefed without it shipped can't-fail or wrong-layer assertions (n=5). Also require
     **fix what you flag**: an issue the builder notices in its own output gets fixed or
     explicitly argued in the deviations report, never just mentioned.
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Independent review — always.** Capture the diff (`git show <sha> > <scratchpad>/<slug>-diff.txt`) and launch a fresh-context **opus** review subagent (per CLAUDE.md routing) with: the diff path, changed-file list, domain rules, and focus hints *including your own suspicions and anything the builder's self-review dismissed*. Builder self-review raises the floor; it never substitutes for this.
5. **Fix pass, push, cleanup.** Confirmed findings go **back to the builder, not to your own editor** — pi: launch with `--session-id <uuid>` so the session exists to resume; grok: `grok-delegate -s <session-id>`. The builder holds the package context; hand-fixing burns Claude time re-deriving it and silently takes Claude out of the reviewer seat. Fix by hand only when the fix is smaller than the brief for it. Re-run the battery, push, then remove the worktree.
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
