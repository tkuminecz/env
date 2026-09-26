---
name: delegate
description: Route execution work to external subscription models (Grok 4.6 / grok-build via x.ai SuperGrok, GLM 5.3 via z.ai, Codex Luna via the OpenAI Codex sub) through the pi CLI, herdr panes or queohoh. THIS IS THE DEFAULT ROUTE for any task that is well-specified and can verify itself against tests/build/lint/typecheck — ahead of Claude sonnet subagents, which spend Anthropic quota on work these flat-rate subs do for free. Load it BEFORE writing tests to a spec, doing mechanical refactors or renames, scaffolding boilerplate, cleaning up lint/typecheck errors, sweeping docs or comments, or fanning out parallel independent chunks — even when the user has not mentioned delegation. Also load when the user says "delegate", "farm this out", "use pi / GLM / grok / codex / the z.ai, supergrok or codex sub". Skip only for work needing open-ended judgment, prod/secrets/migrations, or this conversation's context.
---

# Delegating to external subscription models

Tim pays flat-rate subscriptions for z.ai (GLM models), x.ai SuperGrok (Grok models) and OpenAI Codex (`gpt-*` models such as Codex Luna). All three are wired into the `pi` coding agent — z.ai as an API key, x.ai and openai-codex as OAuth tokens (auto-refreshing) in `~/.pi/agent/auth.json`. Marginal cost of a delegated task on those is zero, so fan out freely; the only budget is undocumented daily/session rate limits on each sub (pi's TUI footer shows usage %). **OpenRouter** (`vendor/model` ids — the DeepSeek models) is also wired in, but bills per token against account credit: cheap, not free. The Claude sub is flat-rate too — its limit is the usage allowance, which is what delegation protects.

Delegated agents run with **full autonomy and no permission prompts** (pi has read/bash/edit/write). Only hand them tasks safe to run unattended. Parallel tasks in one repo need worktrees only when their file ownership overlaps or a package needs its own branch/battery — disjoint file-fenced briefs can safely share one checkout (proven across a 7-way fan-out, zero fence violations).

## Which model for which task

All verified answering through `pi-delegate -m <id>` on 2026-09-26. Evidence counts include the
mgc-rules-engine calibration ledger (see Scorecard). Route on fit first, then on cost (subs before
OpenRouter):

| Model | `pi-delegate -m` | Best at (evidence) | Avoid for |
|---|---|---|---|
| **grok-4.6** | `grok-4.6` (default of both wrappers) | Default external workhorse and the strongest external **reviewer**: n≈11 review passes (3 logged reviewer-seat A's plus ~8 engine-wave calibration and PR-time reviews) — every finding real, file:line evidence, honest UNVERIFIED lists, and it caught the cross-surface seam class grok-4.5 once missed. **Builder reps: none yet** — the default rests on reviewer evidence plus being the grok CLI's own default; log the first builds. 500K ctx. | >500K context |
| **grok-4.5** | `grok-4.5` | Previous default. Builder n=4: A and B on a token-bucket A/B test, B and B as the journal impl seats (faithful to the contract; every escape sat where the contract was silent). Fallback when 4.6 throttles. **grok-4.7** is also on the sub with zero reps; **grok-4.3** remains the 1M-ctx fallback. | — |
| **glm-5.3-flash** | `glm-5.3-flash` | **The most-repped external builder (n=22).** 20 mgc lanes 09-13→09-25: A 1 · A− 4 · B+ 6 · B 6 · C+ 3, and all three C+'s were floor misses caused by the pricing instrument, not the builder. It got better as the briefs got better: the last six (planned by Opus 5/5.5 with every edit site anchored to file:line, rows capped under 400 cards) went A, A−×3, B+, B. Typical result: B+ after one review+fix round. | Program-sized builds (≳3k changed lines): it hit the 6 h lane cap once and a z.ai 429 mid-lane once. See "Size line" below |
| **glm-5.3** | `glm-5.3` | n=17. Engine waves as long herdr lanes at thinking high: B by default, A− once from a decisions-of-record brief. Slow: 4–7 h per lane with commit 1 at 2–4 h, about 3× an Opus lane. Non-engine cross-surface work: A (2/2). Greenfield toolchain setup: B (lifecycle gaps, see brief template). It is also the mgc loop's default reviewer, but **its reviews timed out twice on a 7,184-line diff**. | Reviews of diffs >~3k lines; engine waves where wall time matters (flash and deepseek-v4.1-flash reach the same grade faster) |
| **glm-5.2** | `glm-5.2` | Blind pin batteries with a verbatim corpus, mutation proofs and the deviations clause: **n=13, 85% A**. Docs from a verified facts sheet: A. Usable 1M context. Flags false premises in a brief rather than applying them. | Cross-file reasoning — quality wobbles when correctness spans many files |
| **codex-luna** | `gpt-5.6-luna -t xhigh` | **Fixer, finisher and reviewer.** Finished two GLM lanes cut off by the 6 h cap or a z.ai 429; its fix rounds on two more came back clean on re-review; as an own-review seat it re-derived headline numbers and caught real measurement defects. **As a builder, n=3: B, B+, C+, and it skipped the verification gate on 2 of the 3** (opened PRs after plain `cargo test`; one shipped 31 regressions). | Building without a mechanical gate that refuses to open the PR on a regression |
| **deepseek-v4.1-flash** | `deepseek/deepseek-v4.1-flash` (OpenRouter) | Fastest external engine builder: three engine lanes B+×3 (plus one measurement lane A−), about 2 h 45 m kickoff-to-merge against 4–7 h for glm-5.3. It fails the same way at every commit 1: **claims run ahead of pins** (numbers and wire claims stated before the test that proves them exists). The calibration review is load-bearing for it. | Shipping without a calibration review |
| **deepseek-v4-pro-0813** | `deepseek/deepseek-v4-pro-0813` (OpenRouter) | Small measurement and CI lanes: A 2/2, fast, corrected an ADR's own number. | Engine waves (no reps) |
| **deepseek-v4-flash-0731** | `deepseek/deepseek-v4-flash-0731` (OpenRouter) | Reviewer for small diffs: A on diffs ≤~500 lines; F at ~2,400 (hung twice with zero output). As a builder, B− once: it lost 2 h 20 m wedged on a gated `rm -r`. | Big-diff reviews; building |
| **grok-build-0.1** | `grok-build-0.1` | The mechanical lane: small scripted edits and wide fan-outs of tiny packages, 100+ tok/s, 256K ctx. **pi could not call it until 2026-09-26**: pi sent a reasoning parameter the model rejects (HTTP 400), which helps explain zero rows across three retros. Fixed by registering it with `"reasoning": false` in `~/.pi/agent/models.json` (chezmoi-managed). **First reps (09-26): two wrapper fixes with bash test suites, B and B.** It took ~4.5 min per package; the code and mutation proofs were correct, and one fix round each (1.5–2.5 min) landed every item. It also has the usual weaknesses: its test comments narrated the change, and it built a PATH-filter test that would break once bubblewrap is installed (my brief suggested the approach; it didn't flag the risk). Reflex-route mechanical work here. | Anything needing judgment |

**Size line (from 43 graded mgc lanes).** The 20 Opus-built lanes (4.8 ×3, 5 ×16, 5.5 ×1) graded
A 4 · A− 10 · B+ 3 · B 3, with **zero C**, even though Opus got the *widest* rows, which makes the
comparison conservative. External builders did well on rows under about 400 cards or 3k changed
lines. Above that they hit lane caps, 429s and review timeouts (GLM), or skipped the gate (Codex).
Tim's mgc calls follow this: on 09-20, split by size; on 09-25, every lane step onto Opus 5.5 at
high effort for rounds 14–15, noting the Claude sub is flat-rate too. Rule: **program-sized builds go to Opus** unless
Anthropic usage is the binding limit. In that case use Codex Luna behind a mechanical gate, with
GLM-flash taking the small rows.

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
- **Spread across pools.** Every sub has undocumented rate limits (a z.ai 429 cut off one mgc
  lane mid-build); a big fan-out on one sub can stall the whole round. Split large fan-outs
  across x.ai, z.ai and openai-codex deliberately — glm (usable 1M ctx) owns the repo-scale
  sweep packages; grok takes the multi-file build packages; Codex takes fix rounds. One sub
  throttling then costs a slice of the round, not all of it.

### TDD split: tests and implementation from different delegates

External-lane B's split into three classes, and the fix for one does not fix the others:

- **Same-mind writes code AND proof** — the delegate's green tests missed a hole a different
  seat would have caught. **The TDD split fixes this class.**
- **Shared-spec holes** — both seats read the same contract, so they share its blind spots.
  The first two split rounds (journal, n=4 seat rows, all B) showed it: most first-merge
  failures were contract defects (a per-test isolation claim that was really per-file, an
  unstated element structure, a microtask recipe one tick short), and the one data-corrupting
  bug (a stale async response landing under a newer day) sat in a sequence the contract never
  mentioned. **Only the contract review catches these** — an independent opus pass over the
  contract *before* launching either seat. A split without that review costs two briefs and
  still ships the B.
- **Cross-surface reach the in-package tests can't see** (n=6/6 engine-semantics waves in the
  09-02 batch) — the code is right on its own surface but its interaction with an existing
  combinator, decision layer, zone-reach law, or widened row inheriting old combinator lies
  fails. **The TDD split does not help here** — only the calibration review does (Build
  packages step 4).

TDD-split mechanics (applies to the first class; step 0 covers the second):

0. **Claude gets the contract reviewed** by a fresh opus pass before either seat launches —
   ask it specifically for unstated sequences (concurrency, ordering, lifecycle) and for
   harness claims (isolation, timing recipes) the contract asserts without having run them.

1. **Delegate A** writes the failing test suite from the spec alone — blind to any
   implementation. Tests-as-contract.
2. **Claude reviews the tests** (cheap: read one file against the spec; mutation-test if the
   suite guards something subtle).
3. **Delegate B** implements to green against A's suite, forbidden from editing the tests
   (fence it in the brief; test edits go in the deviations report for Claude to judge).

## Path 1: headless one-shot — use the `pi-delegate` wrapper

```sh
pi-delegate -C <repo-root> "<task>"                  # defaults to grok-4.6, thinking low
pi-delegate -C <repo-root> -m glm-5.3-flash -f <brief>  # brief file instead of inline task
pi-delegate -m gpt-5.6-luna -t xhigh -f <brief>       # Codex Luna on the openai-codex sub
pi-delegate -n ...                                    # dry-run: print the pi command, don't run
```

`~/bin/pi-delegate` (chezmoi source `bin/executable_pi-delegate`) wraps the raw call so the two
easy-to-forget flags can't be forgotten: `--thinking low` and re-adding the permission-gate
extension that `-ne` strips. It also derives the provider from the model name (`glm*` → zai,
`grok*` → xai, `gpt*` → openai-codex, `vendor/model` ids → OpenRouter), so `--provider`
can't drift out of sync with `--model`. Mind the cost difference: `gpt-6-luna` rides the flat
Codex sub, `openai/gpt-6-luna` pays OpenRouter per token for the same model. Reach for raw `pi` only for flags the wrapper doesn't
expose — and if you need one twice, add it to the wrapper.

The raw equivalent, for reference and debugging:

```sh
cd <workdir> && pi -p --no-session -ne --thinking low \
  -e ~/.pi/agent/git/github.com/tkuminecz/pi-kit/extensions/permission-gate.ts \
  --provider xai --model grok-4.6 \
  "<task>"
```

- `-p` prints the final answer to stdout and exits. `--mode json` (wrapper: `--json`) streams full structured events instead.
- `-ne` skips extension discovery **including MCP servers** — without it every run boots the Notion MCP proxy (~15s + log noise). But `-ne` also strips installed packages, including the permission-gate extension from Tim's `pi-kit` package (blocks rm -rf/sudo/chmod-777 outright in headless runs — verified). Re-add it explicitly: `-ne -e ~/.pi/agent/git/github.com/tkuminecz/pi-kit/extensions/permission-gate.ts`. Shared pi customizations live in that package (`github.com/tkuminecz/pi-kit`, private) — add new extensions there and `pi update --extensions`, never as loose files in `~/.pi/agent/extensions/`.
- **One-shots: `--thinking low`** (the wrapper default). Tim's pi default is `high`, which stalled 4+ min on a trivial GLM task; `low` finished the same task in seconds. Long autonomous lanes are different: the mgc lane rule runs GLM and DeepSeek at `high` and Codex at `xhigh`. Nobody has A/B-tested whether `high` earns its wall time there. glm-5.3 lanes at `high` ran about 3× slower per PR than Opus lanes, and a `low` glm-5.3 greenfield build finished in 17 min at grade B. One paired rep (the same small row at `low` and at `high`) would settle it.
- Run via Bash `run_in_background` for anything nontrivial; launch several in parallel for fan-out.
- pi auto-loads AGENTS.md / CLAUDE.md from cwd — run from the repo root so the agent gets project context (`-nc` disables).
- Follow-up turns: use `--session-id <uuid-you-generate>` instead of `--no-session`; it creates the session if missing and reuses it on later calls (sessions under `~/.pi/agent/sessions/`).

## Path 1b: grok CLI — use the `grok-delegate` wrapper

**Harness split** (head-to-head quality was a near tie, so route by harness capability, not model quality):

- **grok CLI = preferred for unattended grok package builds** (grok-4.6 default, grok-4.5 also offered). Its harness advantages are exactly what unattended runs want: kernel-enforced `--sandbox`, `--deny` rules, a `--max-turns` runaway cap, and `--json-schema`-constrained completion reports. **But the sandbox needs bubblewrap, which is not installed on this box** — grok refuses to start under any profile but `off`, so every logged grok-delegate run used `--sandbox off` and got deny rules only. Until `sudo apt install bubblewrap`, the sandbox advantage is on paper; the wrapper says so up front. The grok CLI also signs itself out (seen 09-02 and 09-26): `grok login` before a round.
- **pi = everything else**: any GLM model, grok-build-0.1, Codex, OpenRouter models, quick one-shots, and fix loops on existing pi sessions — one interface across every sub.

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

## Path 3: queued chains — queohoh (the `qoo` skill)

For a multi-step chain that should run without a Claude session babysitting it — planner →
build → review → fix → auto-merge, with post-run hooks that escalate a big diff's fix round to a
stronger model — queue it on queohoh (load the `qoo` skill). Its catalog names models as
`pi/zai-glm-5.3-flash`, `pi/codex-luna-xhigh`, `claude/claude-opus-5.5-1m`; config lives in
`~/.config/queohoh/`. mgc-rules-engine runs its whole build loop there and keeps its own grade
ledger (see Scorecard). Headless pi under queohoh *blocks* a gated command instead of prompting —
unlike an interactive herdr pane, where the same gate prompts and wedges the lane.

## Prompting delegated agents

These models share none of your conversation context. Every delegation prompt needs:

1. **Concrete scope** — files/paths involved, what done looks like, acceptance criteria.
2. **A self-verification step** — "run the tests / build / script and report PASS or FAIL with the output." GLM 5.2 in particular performs significantly better when told to execute and self-debug iteratively rather than one-shot.
3. **Explicit wording** — for GLM, prompt phrasing moves results more than thinking level does. Say exactly what to check.

4. **A deviations section** — end the brief with: "In your final report, list every place you deviated from this spec and why." Honest deviations are common and often right, but they can carry product decisions the user should hear about — read them before merging. Beyond product decisions, this clause has repeatedly surfaced *bugs in the surrounding code the brief pointed at* (ADR-vs-code mismatches, ambiguous CR readings, brief pins that can't discriminate the bug) — non-optional.

5. **Concrete pointers to prior art** — when a brief is close to another that succeeded, name it: "check how scry is observed elsewhere in the resume loop." Cheap, and observed to close a specific gap class (a wave-battery brief went B → A on the next rep after adding one such pointer).

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
     clean docs package traced to the facts sheet, not the model), and every recipe the brief
     prescribes (a PATH-filter test recipe would have broken once bubblewrap was installed; a
     "run the source file directly" check forced a mode change on a chezmoi `executable_` source).
     Check facts sheets against the API surface, not only the versions: a verified version with
     an unverified API still named a removed vitest function. For a package-sized contract
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
   - *For engine / new-primitive / wave briefs specifically*, three clauses have repeatedly
     been the difference between escape and catch. Include them in the Spec section verbatim:
     **(a) ADR table must sum to the claimed card/behavior delta** — force the arithmetic in
     the ADR itself (n=5 waves with unsummed ADRs carried a mis-attribution the builder didn't
     catch). **(b) Commit the new primitive/decision-kind FIRST**, before any grammar or test
     edits — one stall run without this step-0 burned ~50min in a survey/compaction loop
     before a step-ordered correction unstuck it; costs nothing to require. **(c) Name
     "widened row × existing combinator" as an explicit review target** — a new row reaching
     an old combinator inherits every lie the old combinator carries (probe-proven critical
     escape once; the class is generic to any spec-combinator that gets a new input shape).
   - *Claims and numbers* — two clauses for every package that reports counts or makes claims
     about its own behavior. The ADR-must-sum clause alone did not stop the escapes. Builders
     wrote the table and still typed wrong numbers into it (n≥7 in the 09-10→09-25 batch:
     "17+5 written as 23", "+74 for +70", a table that summed to 73 under a hardcoded 75, "+76
     at the lane's head" against 66 at main). **(a) Numbers are pasted, never typed**: every
     count in a title, ADR, table or PR body comes from a command run at HEAD, and the brief
     names that command. **(b) Every claim names its pin**: each behavior the commit message or
     ADR claims cites the test that proves it, in the same commit. "Claims ahead of pins" was
     deepseek-v4.1-flash's commit-1 failure on 3 of 3 engine reps.
   - *Lifecycle and concurrency* — for any service, app or scaffold brief, list the sequences a
     green end-to-end run never exercises and require a test or an argued deviation for each:
     shutdown with open streams or in-flight requests; one throwing or async subscriber
     isolated from the publisher; a stale async response arriving after a newer one; tasks the
     runner executes in parallel that must be ordered; test resources shared per file vs per
     test; pool/listener error handlers. Both app builds this batch (the journal UI, reader
     step 1) shipped green with defects from this list.
   - *Long lanes* (anything past ~1 h): commit the first slice early (lanes that chased a full
     battery mid-loop went 4 h with no commit); run only the touched test targets in the loop
     and the full battery at most twice; when done or waiting on a verdict, **stop and idle —
     never poll a PR** (one lane polled `gh pr view` for 3.5 h); diff against `origin/main`,
     never a local `main` (a stale local main produced a bogus review finding).
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Independent review — always, by a different model than the builder.** Capture the diff (`git show <sha> > <scratchpad>/<slug>-diff.txt`) and hand a fresh-context reviewer: the diff path, changed-file list, domain rules, and focus hints *including your own suspicions and anything the builder's self-review dismissed*. Builder self-review and same-tier review raise the floor but miss the cross-surface class (widened-row-inherits-combinator-lies, zone-reach in ceremony, decision-offer scope over outer spec, copied idiom from an adjacent-but-different primitive). Pick the reviewer by diff shape:
   - **Engine-semantics / new-primitive waves: opus or grok-4.6.** Opus found the whole cross-surface class in the 09-02 batch; grok-4.6 took over the seat on 09-10 (Tim, to move reviews off opus) and found the same class across ~11 passes with no hallucinated findings.
   - **Diffs over ~3k changed lines: opus, grok-4.6 or Codex Luna** — glm-5.3 reviews timed out twice at 7,184 lines, and deepseek-flash hung at 2,400.
   - **Small fix-loop diffs (≲500 lines): deepseek-v4-flash-0731** is the cheap reviewer.
   - **Standing focus hints**, beyond your own: numbers that don't sum or weren't pasted from a command; claims without a pin in the same commit; a widened row reaching an old combinator; lifecycle and concurrency sequences nobody wrote down.
5. **Fix pass, push, cleanup.** Confirmed findings go **back to the builder, not to your own editor** — pi: launch with `--session-id <uuid>` so the session exists to resume; grok: `grok-delegate -s <session-id>`. The builder holds the package context; hand-fixing burns Claude time re-deriving it and silently takes Claude out of the reviewer seat. Fix by hand only when the fix is smaller than the brief for it. Re-run the battery, push, then remove the worktree.
6. If the target branch moved while the builder ran, expect conflicts in shared files — resolve keeping both intents, never discard either side blind.

## Scorecard: log every delegation

`LOG.md` next to this file is the calibration record — it travels with the skill. After each
delegated task finishes its pipeline (including one-shots), append a row **at the end of the
file** (the table is the file's last section, so an append lands in it): date, task, model @
harness, grade (**A** merged as-is / **B** minor fixes / **C** major rework / **F** discarded),
wall time, what independent review caught that the delegate's self-verification missed, notes.

**Project ledgers.** A project that runs its own loop and grades its own lanes does not
double-log here. `LOG.md`'s header lists those ledgers (today: mgc-rules-engine's
`docs/orchestration/HANDOFF.md` → `## Calibration`), and the retro reads them as a second input.
The listed ledgers are the retro's only view of those lanes; LOG.md got no mgc rows after
09-12, while that ledger graded 43 lanes.

Logging is not bookkeeping — it is the only input the retro has. A delegation that never got a
row is a delegation the routing table can never learn from. Write the row even when the result
was perfect, especially when it was bad, and record the grade honestly rather than generously.

When routing a new task, skim the distilled-patterns section first: observed history beats
benchmarks, and the table above is downstream of it.

## Retro: keep the approach improving

Two triggers, whichever comes first — **5 new rows** since the last retro, or **14 days** with
at least one new row — **gated by a 1-day cooldown**: never auto-fire within 1 day of `last`,
however many rows pile up (a heavy fan-out day can log 5+ rows in hours; rows just accumulate
until the cooldown lapses). `LOG.md`'s `retro-state` header carries only `last=<date>`; count
new rows instead of keeping a counter (the hand-kept counter drifted at two retros running:
6 for 13, then 12 for 21):

```sh
awk -F'|' -v last="$(grep -o 'last=[0-9-]*' ~/.claude/skills/delegate/LOG.md | cut -d= -f2)" \
  '$2 ~ /^ 20[0-9][0-9]-/ && substr($2,2,10) > last' ~/.claude/skills/delegate/LOG.md | wc -l
```

Rows in the project ledgers count toward the trigger too. On demand: `/delegate retro` — runs
regardless of cooldown.

### Where the retro runs — never inline

**Do not run the retro in the session that tripped the trigger.** It reads the whole log, edits
routing config, and argues with itself about past grades; doing that inline derails whatever the
user was actually working on. When the trigger fires mid-task, say so in one line, launch the
retro in its own herdr workspace, and carry on with the task at hand.

It runs in the **root platform checkout, `~/jb/platform`** (the main checkout on `main` — not a
feature worktree). Two reasons: the retro's memory scope is the `-home-tim-jb-platform` project,
and a feature worktree's branch state is irrelevant noise to it. The retro edits dotfiles and chezmoi sources, never repo files, so it
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

Ask these, in order, against the rows since the last retro **and** the project-ledger rows
since the same date:

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
aggressively — the log should stay a page, not an archive. Pruned rows move verbatim to
`LOG-archive.md` beside it (LOG.md is not in version control: chezmoi only creates it once),
so a later retro can re-grade from the raw record.

## Known failure modes

- z.ai API calls occasionally flake and need a retry (community-reported; retry once before switching models).
- Rate limits on every sub are undocumented; if a provider throttles, switch to another sub's equivalent model. A z.ai 429 has cut off a long lane mid-build — plan a continuation (Codex finished it).
- `--thinking high` on glm-5.2 can stall for minutes — never use it for one-shots.
- Headless pi with a hung task: check `ps` for the `pi` child process; kill and rerun at lower thinking.
- **A model pi doesn't list can fail on the reasoning parameter.** pi treats an unlisted model as reasoning-capable and sends `reasoningEffort`; grok-build-0.1 answered HTTP 400 to every call until it was registered with `"reasoning": false` in `~/.pi/agent/models.json` (chezmoi `dot_pi/agent/models.json`). A one-line `pi-delegate -m <id> "Reply with exactly: PONG"` before routing to a new id catches this in seconds.
- **The permission gate wedges interactive panes.** In a herdr pi pane, a gated command (`rm -r` on a `__pycache__`) *prompts* and waits for a human; a queued orchestrator message cannot unwedge it (2 h 20 m lost across two wedges in one lane). Headless `-p` runs block the command instead. Watchers of interactive lanes must grep the pane for the prompt.
- **Long background runs can be killed by the parent harness** (a grok-4.6 review died mid-run, cause unknown). Launch long runs detached (`nohup`/`setsid`) with a completion monitor.
- **Idle reapers kill silent steps.** A runner's 12-minute idle reap killed GLM lanes during a silent 50-minute test batch (the queohoh fork now waits 60 minutes). Any watchdog on a delegate must allow for its longest silent step.
- **grok CLI: no sandbox without bubblewrap, and it signs out.** See Path 1b.
