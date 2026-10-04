---
name: delegate
description: Route execution work to external subscription models (Grok 4.6 / grok-build via x.ai SuperGrok, GLM 5.3 via z.ai, Codex Luna via the OpenAI Codex sub) through the pi CLI, herdr panes or queohoh. THIS IS THE DEFAULT ROUTE for any task that is well-specified and can verify itself against tests/build/lint/typecheck — ahead of Claude sonnet subagents, which spend Anthropic quota on work these flat-rate subs do for free. Load it BEFORE writing tests to a spec, doing mechanical refactors or renames, scaffolding boilerplate, cleaning up lint/typecheck errors, sweeping docs or comments, or fanning out parallel independent chunks — even when the user has not mentioned delegation. Also load when the user says "delegate", "farm this out", "use pi / GLM / grok / codex / the z.ai, supergrok or codex sub". Skip only for work needing open-ended judgment, prod/secrets/migrations, or this conversation's context.
---

# Delegating to external subscription models

Tim pays flat-rate subscriptions for z.ai (GLM models), x.ai SuperGrok (Grok models) and OpenAI Codex (`gpt-*` models such as Codex Luna). All three are wired into the `pi` coding agent — z.ai as an API key, x.ai and openai-codex as OAuth tokens (auto-refreshing) in `~/.pi/agent/auth.json`. Marginal cost of a delegated task on those is zero, so fan out freely. The budget is the undocumented daily/session rate limits on each sub (pi's TUI footer shows usage %), plus x.ai's Grok Build usage balance, which ran out mid-round on 2026-09-25 and returned HTTP 402 to every grok launch at once. **OpenRouter** (`vendor/model` ids — the DeepSeek models) is also wired in, but bills per token against account credit: cheap, not free. The Claude sub is flat-rate too — its limit is the usage allowance, which is what delegation protects.

Delegated agents run with **full autonomy and no permission prompts** (pi has read/bash/edit/write). Only hand them tasks safe to run unattended. Parallel tasks in one repo need worktrees only when their file ownership overlaps or a package needs its own branch/battery — disjoint file-fenced briefs can safely share one checkout (proven across a 7-way fan-out, zero fence violations).

## Which model for which task

All verified answering through `pi-delegate -m <id>` on 2026-09-26. Evidence counts include the
mgc-rules-engine calibration ledger (see Scorecard). Route on fit first, then on cost (subs before
OpenRouter):

| Model | `pi-delegate -m` | Best at (evidence) | Avoid for |
|---|---|---|---|
| **grok-4.6** | `grok-4.6` (default of both wrappers) | Default external workhorse and the strongest external **reviewer**: n≈11 review passes (3 logged reviewer-seat A's plus ~8 engine-wave calibration and PR-time reviews) — every finding real, file:line evidence, honest UNVERIFIED lists, and it caught the cross-surface seam class grok-4.5 once missed. **Builder n=1** (tim-dev, 10-04): A on a ~690-line API package (since/until windows on six endpoints) in about 5 min, with mutation proofs on all four behaviours and an honest nine-item deviations list. 500K ctx. | >500K context |
| **grok-4.5** | `grok-4.5` | Previous default. Observed: the log's primary lane, run through grok CLI (see Path 1b). Across 09-25→28 it ran 80 build lanes at 88% A/A-, and its B's were fallout in suites the brief never named, collateral from tools it ran, and fluent comments that said something false, never broken logic. On 09-28→29 it ran 42 lanes at 81% A/A-. The B's were judgment slips at the edge of the brief: it dropped a unique index inside a test transaction to seed a state the schema forbids, wrote through a `/tmp` symlink into a committed file, used a `TYPE_CHECKING`-only name at runtime (ty passed, the route 500'd), let frozenset order reach a retry digest, and shipped a table layout that only a screenshot could show was broken. brief-common now names each one. A 402 from x.ai is an outage for the rest of the day, not a transient. Salvage the tree and send the day's builds to glm, which went 2/2 A as the fallback on 09-25. Builder n=4 in the mgc ledger: A and B on a token-bucket A/B test, B and B as the journal impl seats (faithful to the contract; every escape sat where the contract was silent). Fallback when 4.6 throttles. **grok-4.7** is also on the sub with zero reps; **grok-4.3** remains the 1M-ctx fallback. | — |
| **glm-5.3-flash** | `glm-5.3-flash` | **The most-repped external builder (n=22).** 20 mgc lanes 09-13→09-25: A 1 · A− 4 · B+ 6 · B 6 · C+ 3, and all three C+'s were floor misses caused by the pricing instrument, not the builder. It got better as the briefs got better: the last six (planned by Opus 5/5.5 with every edit site anchored to file:line, rows capped under 400 cards) went A, A−×3, B+, B. Typical result: B+ after one review+fix round. **09-26→10-04:** all four mgc program-9 builds (105–260 cards advanced, under the 400 line) hit the 6 h cap while still progressing, and Opus finished each one (A−, A−, B+, plus one moved). The one cheap program build that finished in one run was the smallest row (deck-weighted 32): A. On tim-dev: implement-to-a-reviewed-suite A (byte-identical to a reference on 812 blocks), a small dbt package A−, and one **C**: to make a mutation proof fire, it changed a behaviour the brief pinned (a 20k-case fuzz found 123 wrong results), and its report claimed a clean typecheck over 11 errors. | Program rows in mgc beyond the smallest (see "Size line"); trusting its gate lines without a re-run |
| **glm-5.3** | `glm-5.3` | n=17. Engine waves as long herdr lanes at thinking high: B by default, A− once from a decisions-of-record brief. Slow: 4–7 h per lane with commit 1 at 2–4 h, about 3× an Opus lane. Non-engine cross-surface work: A (2/2). Greenfield toolchain setup: B (lifecycle gaps, see brief template). It is also the mgc loop's default reviewer, but **its reviews timed out twice on a 7,184-line diff**. **Service packages (tim-dev reader, 09-26→27, n=4): B every time, and every time with one must-fix that only an adversarial opus review found**: a login rate limit bypassable by rotating `X-Forwarded-For`, a semaphore around Restate `ctx.run` that leaked a slot per failed attempt, an abort handler whose synchronous dispatch spawned 392 workers, and tests that left 6 mutants alive. One fix round with mutation proofs closed each. Broad and faithful to the contract, weak on failure paths and attackers. | Reviews of diffs >~3k lines; engine waves where wall time matters (flash and deepseek-v4.1-flash reach the same grade faster); shipping a service package without an adversarial opus review |
| **glm-5.2** | `glm-5.2` | Blind pin batteries with a verbatim corpus, mutation proofs and the deviations clause: **n=15, 12 A / 3 B**. The newest B (reader 3a): 2 of 26 blind tests failed a correct implementation, because they encoded wrong beliefs about a library's API. Running the suite against a throwaway reference implementation found both in about 15 min (see TDD split). Docs from a verified facts sheet: A. Repo-scale long context (usable 1M, its headline feature). Iterative run-test-fix loops: it does measurably better when told to execute and self-verify. It checks premises as well as grok-4.5 does and flags a false brief premise with evidence instead of applying it, so it makes a strong premise-sweep, docs-truth and verification-sweep delegate. It is the log's best blind RED unit-suite writer. It invented the `/tmp` scratch-implementation mutation proof, and its seven RED suites on 09-25→28 graded six A and one B+, where the B+ was a contract gap it flagged itself. On read-only panels it often sits near zero CPU for 10–30m and then lands the round's unique real finding (a strand-PENDING design flaw, a CRITICAL red CI read off the live run, the detached-worktree venv trap). Run those lanes at `-W 20` and don't gate on them. It doesn't refuse security-adjacent tasks, and it was the build fallback when x.ai ran out of credit (2/2 A). Docs caveat: it drifts on the *semantics* of code it summarizes secondhand, so put the exact wording for contract-bearing bullets in the brief. **z.ai stalls are its one recurring failure**, at about one lane per heavy day (09-24, 09-25, 09-26, 09-28). Stalled runs sit at zero CPU, sometimes minutes after a clean smoke or a clean start. Stagger glm launches 150s–3m apart, because simultaneous launches stall. After two strikes in a day, drop z.ai for the rest of the day for every lane the round waits on (builds, RED writers, gating reviews). Non-gating read-only lanes at `-W 20` may still launch, since a stall there costs nothing. A smoke only rules the provider *out*, never in. Salvage a killed build before relaunching it, and read the code under any comment it wrote: on 09-28 a stalled dbt lane left a comment claiming a column move it never made. | Cross-file reasoning — quality wobbles when correctness spans many files (kilo.ai eval); use grok-4.5 or Claude there. Integration-heavy RED suites (a full Trino tier): give glm the unit tier and send the integration tier to grok CLI (missed twice: JUS-3012 F, JUS-2408 B) |
| **codex-luna** | `gpt-5.6-luna -t xhigh` | **Fixer, finisher and reviewer.** Finished two GLM lanes cut off by the 6 h cap or a z.ai 429; its fix rounds on two more came back clean on re-review; as an own-review seat it re-derived headline numbers and caught real measurement defects. **As a builder, n=3: B, B+, C+, and it skipped the verification gate on 2 of the 3** (opened PRs after plain `cargo test`; one shipped 31 regressions). From 10-02 to 10-04 every Codex call failed with "Unable to verify … access", which was an account problem, not a transient, and lasted until Tim fixed it. Tim's fallback order when Anthropic usage binds (mgc, 10-02): GLM → Luna → DeepSeek. Related: **gpt-6-luna** (via OpenRouter, paid) n=1, C. It was fast and honest that it had skipped its mutation proofs. Its tests were too thin to fail, a real input file exposed two bugs its handcrafted fixtures hid, and it then hung silently for 39 min. | Building without a mechanical gate that refuses to open the PR on a regression |
| **deepseek-v4.1-flash** | `deepseek/deepseek-v4.1-flash` (OpenRouter) | Fastest external engine builder: three engine lanes B+×3 (plus one measurement lane A−), about 2 h 45 m kickoff-to-merge against 4–7 h for glm-5.3. It fails the same way at every commit 1: **claims run ahead of pins** (numbers and wire claims stated before the test that proves them exists). The calibration review is load-bearing for it. | Shipping without a calibration review |
| **deepseek-v4-pro-0813** | `deepseek/deepseek-v4-pro-0813` (OpenRouter) | Small measurement and CI lanes: A 2/2, fast, corrected an ADR's own number. | Engine waves (no reps) |
| **deepseek-v4-flash-0731** | `deepseek/deepseek-v4-flash-0731` (OpenRouter) | **Corroboration lane**, pay-per-token via OpenRouter (cheap, not free). Reviewer for small diffs: A on diffs ≤~500 lines; F at ~2,400 (hung twice with zero output). On panels and sweeps it confirms the other models' findings and lands a unique real one about every other run (a missed ci-config dep, an untested join, an unaliased `a + b` that parses as `b`, a preview count that used its own blank predicate, proven with a probe). Its reports are thinner. It has called authz OK where it wasn't, and it has reported "no correctness issues" on diffs where opus found a design-changing defect. **Its HIGHs are unreliable**: on 09-25 two of its headline findings were false (a `.wait()` it said never raises, and a Directory test cited against the SDK file). Verify every deepseek HIGH by content before it enters a fix list. Never trust its line cites, which drift by up to 200 lines. Slow zero-CPU starts (5–7m) look like hangs, so give it `-W 20` and never gate a round on it. Panel grades 09-22→29 were mostly B and B+, with two C's. The second C (09-28, JUS-2267) was again a false HIGH: it said a mapped lake office id is `cfo_` when the proto says `lfo_`. The same day its unique finding on a firm-profile sweep (an ungated email on the approved-rates rung) became a plan decision. Its second lane is spec-driven test writing and small, fully specified builds, where thin prose and drifting cites don't bind. It went A on a RED integration suite, on blind RED unit suites, and on a relationship-removal package (09-28). About half its F's were runs that never started, so a build goes to deepseek only when something else can absorb its loss. The provider itself flakes some days (hangs, upstream closed). As a builder it went B− once when it lost 2 h 20 m wedged on a gated `rm -r`. As an mgc builder (09-28) it timed out at 6 h with 7 of 9 cards done, and Opus finished the lane (B+). The next lane hit a provider error mid-run. | Big-diff reviews; sole coverage of any surface — never the only model on a package; high-stakes or judgment-heavy work; anything where citation precision matters |
| **grok-build-0.1** | `grok-build-0.1` | The mechanical lane: small scripted edits and wide fan-outs of tiny packages, 100+ tok/s, 256K ctx. **pi could not call it until 2026-09-26**: pi sent a reasoning parameter the model rejects (HTTP 400), which helps explain zero rows across three retros. Fixed by registering it with `"reasoning": false` in `~/.pi/agent/models.json` (chezmoi-managed). **First reps (09-26): two wrapper fixes with bash test suites, B and B.** It took ~4.5 min per package; the code and mutation proofs were correct, and one fix round each (1.5–2.5 min) landed every item. It also has the usual weaknesses: its test comments narrated the change, and it built a PATH-filter test that would break once bubblewrap is installed (my brief suggested the approach; it didn't flag the risk). Earlier log (6 rows, none since 08-20): on genuinely tiny mechanical packages it is an A (gate registration, 4m). Its failure is always the same phase — **the edits land, the report doesn't**: false "ruff clean" on a ruff-failing file, silently dropped coverage, and a sweep that went byte-complete then burned 15s of CPU in 39min and died in verify. grok-4.5 @ grok CLI finishes the same tiny packages in 1–3m at A with a report you can trust. Reflex-route mechanical work here, size the package small, and plan to re-run its gates and salvage its output yourself. | Anything needing judgment; anything gated by a hard external constraint CI can't see (see *Done means*); anything where you would actually rely on the report |
| **gpt-6-sol** (Tim's pick) | `pi` interactive in a herdr pane, provider `openai-codex` (pi's current default provider) | Whole-ticket, long-horizon implementation handoffs that Tim chooses to run interactively. Two rows so far (JUS-3071, JUS-3074: 4.5h and 6h, both B). It takes mid-run steers well and keeps to the spec's shape. Without brief-common its tests went vacuous: a memory bound read from a process-lifetime high-water mark, a fail-open test that couldn't fail, and structural guards left pinning dead constant copies. Review it like a first draft and mutation-test its suite. pi can switch models mid-run when the provider rate-limits. On JUS-3071 sol handed over to deepseek-flash at 01:53, so check the pane footer, because the model that actually wrote the code sets how deep the review goes. | Unattended runs; anything the routing table would pick. It is not in the delegate-by-default rotation |

**Size line (mgc ledger, 66 graded lanes to 10-04).** Opus has built 35 lanes with **zero C**,
even though it got the *widest* rows. The first 20 (4.8 ×3, 5 ×16, 5.5 ×1) graded A 4 · A− 10 ·
B+ 3 · B 3, and the 15 Opus 5.5 lanes of 09-26→28 graded A 9 · A− 6. The old line ("external
builders do well under about 400 cards or 3k changed lines") did not hold for mgc *program* rows.
From 09-27, all four GLM-flash program builds at 105–260 cards advanced hit the 6 h cap while
still progressing, and so did a 9-card DeepSeek deck lane. The one cheap program build that
finished in one run was the smallest row (deck-weighted 32). Rule: **program-sized builds go to
Opus** unless Anthropic usage is the binding limit. When it binds, Tim's call (10-02) is GLM-flash
→ Codex Luna → DeepSeek with a 10 h cap, because every cheap build cut off at 6 h was still
making progress.
**Don't switch a lane's builder mid-build unless the lane is dead.** The eight lanes that changed
builder graded A− 4 · B+ 4 with no A, and one of them needed four merges. The sixteen lanes with
a single builder got ten A's. Open question: those cheap builds ran three at a time on one z.ai
sub (PARALLEL-BUILDS=3 from 09-26). One paired rep, the same row built alone, would show whether
the shared sub or the rows themselves made them slow.

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
  **Structural guards are the seam that recurs most.** The repo is full of discovering
  guards that introspect a population, such as a schema snapshot, a seed-mirror twin, a
  hand-pinned `COLUMNS` list, the lake's unlanded/unregistered event carve-outs, and
  column-width snapshots. Any round that adds a column, table, proto event or entity turns
  some of them red, and none of them sits in the fence of the package that caused it.
  Between 08-20 and 09-22 this landed on the orchestrator by omission in five rounds, and
  once it reached the merge panel as a CRITICAL red CI. The check is mechanical: after
  seeding the interface and before the fan-out, run the unit suites of every service the
  round touches against the seed. Each red guard goes on the seam list, then gets an owner
  or goes into your review notes. Include the Dagster root tests
  (`domains/legal-lake/dagster/tests/*.py`, not only its subpackages) whenever a round adds a
  seed event or a raw column. `test_seed_ddl_alignment` went red, unowned, in two JUS-3126
  rounds because the seam sweep ran only the subdirectories.
- **Seed the shared interface yourself, before the fan-out.** Committing the shared type and
  the one-line call-site change up front let two genuinely interdependent packages run fully
  concurrent with zero coordination — cheaper than a worktree and cheaper than sequencing.
  Pair it with telling each delegate that its counterpart's half is in flight ("an
  `orAlternative` row may render without a visible 'or' — that is not your bug, assert only
  on what you own"), which is what kept the round free of cross-package test flake.
- **Spread across pools.** Every sub has undocumented rate limits (a z.ai 429 cut off one mgc
  lane mid-build); a big fan-out on one sub can stall the whole round. Split large fan-outs
  across x.ai, z.ai and openai-codex deliberately — glm (usable 1M ctx) owns the repo-scale
  sweep packages; grok takes the multi-file build packages; Codex takes fix rounds. One sub
  throttling then costs a slice of the round, not all of it.
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
  `-W 10` to `pi-delegate` — the 6-minute default stall window is tuned for solo runs and
  false-kills throttled-but-healthy ones. And route the concurrent grok-4.5 packages through
  **grok CLI**, not pi: on the same day pi-grok stalled repeatedly, grok CLI went 4/4 with zero
  stalls (see Path 1b).
- **Don't run your battery under a delegate's mutation proof.** While a delegate has a
  production file mutated for a RED proof, or is running a stateful integration suite (a
  shared ClickHouse or Restate container), any run of the same suites from the orchestrator
  or from a sibling reads the mutated state. That cost 12 phantom failures in one round and
  one corrupted shared-CH run in another. Run the battery after the round's proofs finish, or
  on a detached worktree. **A live dev stack counts as a reader too.** Hot reload (uvicorn
  WatchFiles) loads a mutated file as soon as it is written. A panel lane's mutation proof
  restarted the backend mid-session and broke a live Restate send, and an orchestrator `sed`
  proof in the same checkout produced a misleading log. While a stack serves the checkout,
  every mutation happens in a detached worktree (`git worktree add --detach <dir> HEAD`) or in
  a `/tmp` copy, and that includes your own. Mind the venv trap there: the `pytest` on PATH
  still imports the original checkout (see *Known failure modes*). Prefer a `cp -r` of the
  one package under test (43 MB for a backend) to a full worktree. On 09-25 an opus lane's
  `/tmp` worktree filled the disk, and a grok lane then emptied other processes' logs in
  `/tmp` to free space (brief-common now fences the shared machine).
- **Don't commit in a shared checkout while delegates are running.** The pre-commit hook's
  autostash takes every delegate's dirty files out of the tree for the length of the hook
  run. On 09-26 that hid a Playwright package's page-object edits from its `tsc` check, and a
  docs lane had to re-verify its edits after an orchestrator commit raced it. Commit between
  rounds, or pathspec-limit the commit and expect the autostash anyway.
- **Real-stack lanes share the host's RAM with the dev stack.** A panel lane's testcontainers
  plus the running dev stack tipped jb-dev into earlyoom on 09-25, and earlyoom kept killing
  the orchestrator's ClickHouse and Trino. While a dev stack is up, run at most one panel lane
  that starts its own containers.

### Read-only review panels: the standing shape for merge-readiness reviews

Three graded rounds (PR2419, JUS-2404, JUS-2281) settle it: for a final read-only review of a
big diff, run a **4-model panel** — grok-4.5 @ grok CLI, glm-5.2 @ pi, deepseek @ pi/openrouter,
plus one opus Agent as the reference report — all launched in the same message, all with
`-o <report>` files. Every model has landed a unique real finding at least once, opus is
consistently deepest, and cross-model corroboration is what upgrades a single-model finding to
"real". Verify each unique finding by content (deepseek cites drift). Costs ~10–15m wall-clock
for the whole panel; z.ai/OpenRouter strikes drop that lane, never the panel.

Twenty further panels (08-20→09-24) sharpened the shape:

- **Gate the round on grok + opus. glm and deepseek report late.** Both often sit near zero
  CPU for 15–30m and then land a real unique finding. Give them `-W 20` and fold their
  reports in when they arrive; don't hold the fix round for them. **Opus is the one lane a
  panel can't lose.** In all four panels of 09-24 the finding that changed the code or the
  merge plan came from opus alone: a transaction-start `now()` that refused a genuinely newer
  event, a leaking env helper, and a prod-wide alert set to fire on the new subscription. The
  external lanes said "no correctness issues" on two of those diffs. They still earn their
  seats through corroboration and doc-level finds, but when opus is out, your reference pass
  has to go as deep as opus would. Across the eight panels of 09-25→28 opus graded A every
  time and was alone on the plan-changing finding in five. grok found the round's top issue
  first twice (the JUS-3119 front door refusing every LEDES submission, and the #3191
  CancelledError leak), and glm matched opus on #2872's HIGH where grok missed it. Two HIGHs
  that no lane found only showed up live: one in the orchestrator's own Para run, and one on
  a lake old enough to have expired snapshots. So keep one live check of your own on every
  panel.
- **Put an "already found / accepted" list in the brief, and a "deliberately not fixed —
  argue if wrong" list.** No reviewer re-reported a known item in any of the four panels
  that carried both lists, and the reviewers still challenged the deliberate choices. Put the
  stated scope of open follow-up tickets on the already-found list too. On PR #3167, opus's M1
  restated JUS-3069's scope and was nearly triaged as a new finding.
- **Let reviewers write and run throwaway real-stack tests, and mutation-test the findings.**
  This turned arguments into proofs, such as an emptied Restate queue reproduced live and nine
  green-staying mutations on a panel that found zero code defects. When every external model
  agrees on a "deliberate design choice", treat it as a reason to re-examine that choice.
- **Never label a premise "verified" in a panel brief.** On PR #3140 the brief called the
  Directory `updated_at` stamp semantics verified. All three external lanes probed hard
  everywhere else and never questioned it, and it was exactly where opus found the defect.
  List what you believe as "orchestrator's belief — challenge it"; that is the same device
  that makes build delegates disprove UNVERIFIED premises.
- **Reviewers who mutation-test must do it off the shared checkout.** A brief with a HARD RULE
  ("mutate only in a detached worktree or a /tmp copy / runtime pytest plugin") went 4/4
  compliant, and the live stack ran undisturbed. The panel before it had no such rule, and
  glm's in-place mutation hot-reloaded the backend under a live test. Launch grok review
  lanes with `grok-delegate --read-only`, never with hand-typed Edit/Write denies (see *Known
  failure modes*), and have every lane remove its own copies. One grok lane left `repo/` and
  `wt/` sandboxes, one of them mode 0100, inside the live worktree, and one glm lane left a
  detached worktree it couldn't remove.
- **Settle a lone dissent against the running stack instead of by vote.** Twice the minority
  finding was the real one (grok over opus once, glm over the other two once).
- **An opus Agent lane can go very late, so give it a clock.** On JUS-3125 the opus lane sat
  70m without writing and reported 8h later. It still had the best unique finding (an empty
  `--project` widening into a host-wide `--yes`). Tell the opus lane to write findings to its
  report as it goes and to finish inside ~30m. When it hasn't landed, gate on grok plus the
  factory review (`/reviewqueued`) and fold opus in as a late round. The factory review
  independently confirmed the top findings on both 09-28 panels it ran alongside.
- **Panel and sweep briefs point at brief-common too.** Its *Read-only lanes* section carries
  the off-checkout mutation rule and the report-to-file rule. On JUS-2993 panel lanes
  byte-mutated the shared tree while a `--reload` backend served a live check, because the
  hand-written panel brief left the HARD RULE out.
- **When opus hits a 429, the panel still works.** The three external lanes plus an
  orchestrator reference pass carried three panels on days when Anthropic's session limit
  took out every Claude reviewer.
- **Each lane's report path goes first in its own launch prompt, with no other lane's path
  anywhere it can see it.** A shared brief listing all four paths still got two lanes (glm and
  deepseek) writing to `review-opus.md`, and deepseek's copy overwrote opus's. Earlier, one
  sweep's deepseek overwrote glm's shared `research-report.md`, and a grok run wrote to /tmp
  because its path lived only in the inline prompt. Keep the shared brief path-free, and give
  each launch line one line naming that lane's own `-o` path.

### TDD split: tests and implementation from different delegates

External-lane B's split into three classes, and the fix for one does not fix the others:

- **Same-mind writes code AND proof** — the delegate's green tests missed a hole a different
  seat would have caught. **The TDD split fixes this class.** It is validated end to end
  (JUS-2079: RED unit + RED integration + implementation + parity, four delegates across three
  providers, 4/4 A, zero orchestrator fixes) — and both test-writers independently disproved a
  false premise in the brief instead of encoding it, which is exactly what a test-as-contract
  author is for.
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
2. **Claude reviews the tests**: read the file against the spec, then run the suite against a
   throwaway reference implementation of the contract. Reading finds missing cases. The
   reference run finds tests that would fail a *correct* implementation, which reading misses:
   2 of 26 on reader 3a, both wrong beliefs about a library's API. The run takes about 15 min.
   For a pure algorithm, keep the reference afterwards and fuzz the delegate's implementation
   against it. On reader 3d that found 123 wrong results in 20k cases behind a green suite.
3. **Delegate B** implements to green against A's suite, forbidden from editing the tests
   (fence it in the brief; test edits go in the deviations report for Claude to judge).

**Mind the RED window.** When A and B run concurrently in one checkout, B's production edits
can land before A ever observes RED. That happened in seven rounds (08-20→09-22). Either launch
A first and B about 5 minutes later, or rely on the fallback that `brief-common.md` now
carries: if the implementation is already there, prove RED by byte-copy mutation of production
code or against a scratch implementation of the contract in `/tmp`. The scratch
implementation came from glm on JUS-3011. It proved six mutations before the real code landed,
and the grok sibling in the same round, briefed without it, never proved RED at all. A detached
worktree at HEAD also works. Otherwise plan to take the RED proof yourself by mutation after
the round.

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
  - **kills the group after 6 minutes of zero tree-CPU** (`-W/--stall <mins>`, `0` disables;
    was 3, raised after three false kills of slow-starting glm/deepseek runs) and
    exits `125` with a `HUNG` explanation;
  - keeps a 120min total-runtime backstop (`-T/--timeout`, exit `124`) for slow-but-alive runaways.
    It was 60, until a live glm-5.3 fix round ran past 60 min and had to be resumed (reader 3c);
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

- **grok CLI = preferred for unattended grok package builds (grok-4.6 default, grok-4.5 also offered) — and mandatory for concurrent ones.** Its harness advantages are exactly what unattended runs want: kernel-enforced `--sandbox`, `--deny` rules, a `--max-turns` runaway cap, and `--json-schema`-constrained completion reports. It is also the reliable lane under load: on a day pi-grok runs stalled repeatedly, grok CLI completed 4/4 packages with zero stalls. It is now the most-used and best-graded lane in the log by a wide margin. **But the sandbox needs bubblewrap, which is not installed on tim-dev** — grok refuses to start under any profile but `off` there, so every grok-delegate run logged on tim-dev used `--sandbox off` and got deny rules only. Until `sudo apt install bubblewrap`, the sandbox advantage is on paper there; the wrapper says so up front. (jb-dev has bwrap but denies user namespaces; see the auto-downgrade below.) The grok CLI also signs itself out (seen 09-02 and 09-26): `grok login` before a round. One cost, seen in five packages: **a turn cap always bites at the END, so the phase it eats is verification** — the edits are complete and the mutation-RED proofs are simply never run or never reported (salvage-first applies; run the proofs yourself). `grok-delegate` now defaults to `--max-turns 80` for that reason; budget roughly 40 + 8 per proof the brief demands, and raise it further for wide briefs.
- **pi = everything else**: any GLM model, grok-build-0.1, Codex, OpenRouter models, quick one-shots, and fix loops (as fresh one-shots — pi's session-resume is the hang-prone path) — one interface across every sub.

`~/bin/grok-delegate` (chezmoi source `bin/executable_grok-delegate`) is the pi-delegate sibling that bakes in the unattended posture so it can't be forgotten: `--permission-mode bypassPermissions` (headless runs can't answer prompts) **plus** the two enforced layers that make that safe — `--sandbox workspace` (kernel-limits writes to the working dir + tmp) and default deny rules (sudo, `rm -rf`, `chmod 777` for pi-kit gate parity, and `git push` — delegates commit, Claude reviews and pushes). Also `--max-turns 80`, `--output-format plain`, `--no-auto-update`.

**The sandbox now auto-downgrades instead of faking success.** grok's sandbox needs unprivileged user namespaces; jb-dev denies them (`bwrap: setting up uid map: Permission denied`) and grok responds by exiting **0** with a one-line error — which reads as a completed run in the task notification and cost a wasted round-trip four separate times. When `--sandbox` is not passed explicitly the wrapper probes the primitive and falls back to `off` with a warning on stderr. An explicit `--sandbox` that the host can't honour exits 2 instead (see *Known failure modes*).

```sh
grok-delegate -C <repo-root> -f <brief>               # brief file → native --prompt-file
grok-delegate -C <repo-root> "<task>"                 # inline one-shot
grok-delegate -o <scratchpad>/<pkg>.report ...        # tee full stdout to a report file (also default-on)
grok-delegate --read-only ...                         # review/research lane: repo writes and git state denied, shell and /tmp open
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
   - *Git hygiene* (**mandatory in every shared-checkout brief**). A shared checkout is safe
     for edits and unsafe for git *state* — the working tree is fenced by the brief, but the
     index, the stash and the hooks are one shared resource that fences cannot partition. Three
     verbatim clauses handle all of it. **Don't retype them. Point every brief at
     `~/.claude/skills/delegate/brief-common.md`** by absolute path. That file carries these
     clauses, the stop conditions, the vocabulary fence and the evidence gates word for word. A
     hand-typed brief that dropped the checkout ban got a sibling's fix reverted with
     `git checkout --` (09-11). The one round with a shared common-clauses file (JUS-3007)
     ran 11 build packages at A/A- with no git-state incidents.

     "Do NOT use `git stash`, `git checkout -- <file>`, or `git reset` at any point. Other
     packages have uncommitted work in this checkout and all three silently revert it. To
     restore a file after a mutation proof, keep a byte copy (`cp f /tmp/f.bak` …
     `cp /tmp/f.bak f`) and confirm the restore with `cmp /tmp/f.bak f`."

     "Never run `git commit`. Leave every change uncommitted, and end your report with a
     pasted `git status --porcelain`. Every path YOU modified must sit inside your fence.
     Other packages' dirty paths will appear too. Leave them alone and don't list them as yours."
     (The older wording, "every path in it must sit inside your fence", can't be satisfied in a
     concurrent round, and two delegates flagged it independently.)

     "A dirty file outside your fence is another package's or the orchestrator's deliberate
     work-in-progress. Leave it byte-for-byte as found — never restore, revert, or 'clean up'
     any file you do not own, by any mechanism (`git checkout`/`git restore`, `cp` from a
     backup, or re-typing content from memory)."

     The third clause exists because two grok packages in one day each reverted the
     orchestrator's deliberate local `compose.yaml` edit while "restoring the shared
     checkout" — the general stash/checkout ban didn't stop it, because tidying a file it
     believed was accidentally dirty read to the delegate as helpfulness, not as a revert.

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
     clean docs package traced to the facts sheet, not the model), and every recipe the brief
     prescribes (a PATH-filter test recipe would have broken once bubblewrap was installed; a
     "run the source file directly" check forced a mode change on a chezmoi `executable_` source).
     Check facts sheets against the API surface, not only the versions: a verified version with
     an unverified API still named a removed vitest function. For a package-sized contract
     feeding a fan-out, have an independent opus pass review the contract BEFORE launching
     builders — the one contract gap that reached review was a spec defect no builder could
     have caught. **Treat that pass's count as a routing signal.** On JUS-3012 it found six
     HIGHs in the ingestion-queue contract. The implementation package built on it still came
     back the log's only C in two windows, followed by two B fix rounds. When the contract
     review finds that much, writing the spec was the hard part, so keep the stateful core
     in-house or split it much finer before you delegate it. The count alone doesn't decide it.
     What matters is whether every HIGH gets resolved in the contract before launch. On JUS-3119
     (5 HIGHs) the core then landed without a fix round. On JUS-3126 r2 (3 HIGHs, including a
     rolling-deploy column drop) the five builds on the fixed contract graded four A and one A-.
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
     **Brief pointers are facts too.** Grep every identifier, module path and package name the
     brief names. JUS-2999 and JUS-3007 briefs shipped four wrong pointers (`MappingIssue.code`
     for `.kind`, a wrong dagster package name). The delegates corrected them, but they spent
     turns on it.
     **A semantic change "everywhere" needs a call-site inventory in the brief.** Run the
     `git grep` yourself, paste the site list, and require the report to account for each site:
     changed, or unchanged and why. The JUS-3007 whitespace narrowing went B because the delegate
     changed the composer and missed two parsers in another package, which broke the round trip.
     This is the second time that "coverage clusters on the path the brief describes" has hit.
     **State known premises you have NOT verified as explicitly unverified** — "treat this as
     false until a test says otherwise" made a delegate correctly disprove a bug instead of
     inventing a fix for it. A shaky premise stated flatly gets implemented.
     **Also fence the delegate's vocabulary**: "do not name packages, briefs, or this
     delegation in code comments — the code outlives the round." Unprompted, 2/2 delegates
     wrote `// Package B` into permanent files; the round after the clause was added, zero did.
     Name the *contract's own labels* too ("CONTRACT E3", "§4", section-id class suffixes)
     and ticket ids in new code. The narrower clause let both kinds through (JUS-2883,
     JUS-2670).
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
     a pure helper next to it). **Test fakes and fixtures must pin literal expected values,
     never re-derive them from the inputs** — one fake re-implemented the exact forbidden
     computation under test (`avg_rate = amount / hours`), which made every assertion against
     it vacuous while staying green. Every suite briefed this way came back clean (7/7 packages);
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
     **The lint gate means the pre-commit hook's gates, not only the linter.** Four packages
     pasted a clean `ruff check`, and then the commit's `ruff format` hook rewrapped their files.
     Require `ruff format --check <files>` (and `biome format` for TS) alongside the lint run.
   - *Forbidden or unavailable test tiers are the orchestrator's tier.* When the brief forbids
     running a tier (integration, real-stack) or the delegate's env lacks it, the delegate is
     structurally blind there — 3 of 4 B grades in one window were exactly this. Before launch,
     enumerate that tier's existing assertions on the semantics the package changes and plan to
     run the tier yourself post-merge. Conversely, an impl brief whose change re-keys shared
     fixtures or literals must tell the delegate to run the *neighboring* suites, not just its
     own — "its tests are green" says nothing about the suite next door. A list of named suites
     is not enough either. On 09-26→28 three packages went green on the suites their briefs
     named and still broke 7 tests in unnamed Dagster suites, 15 fixtures in two files a
     file-list sweep skipped, and a seed guard that only the full Dagster run caught. For a
     change to shared semantics (a mart, a seed or fixture, a shared helper), the gate is the
     whole test directory of each service involved, and brief-common now says so.
   - *Per-shape clauses that keep earning their line.* Each is one sentence in the brief and
     each fixed a whole failure class in a single round:
     - **Integration/real-stack packages**: "a skipped test is not a passing test, and a mocked
       integration test defeats the purpose." Got a real-container result with an honest
       6-passed/91s report instead of a mock standing in for the tier. Budget the wall clock:
       a real-Trino tier ran ~45m, mostly three full dbt session builds, so raise `--max-turns`
       (140 held) and don't read the duration as a hang.
     - **Comment, docstring, and docs truth passes**: "prose only — a changed pass count means
       you changed behaviour." Cheap, self-checking fence; two docs packages landed first time.
       Add "these files only", because a sweep with no file list removed a still-true sentence
       from an AGENTS.md it wasn't given.
     - **Comment clarity passes** (rewriting dense or stale comments) are a riskier shape,
       because they change what the prose says. On JUS-3119 three grok passes fixed 15 wrong or
       stale comments and introduced two false ones: a firm-less row that "still keys and
       lands" when landing rejects it, and a deferral rule stated subtly wrong. An AST compare
       with docstrings blanked proves no code changed. It says nothing about whether the prose
       is true, so read every rewritten sentence against the code yourself. Brief them to give
       a concrete example wherever a rule is abstract, since jargon survived wherever none was
       given. Warn them that `Field(description=)` strings feed the OpenAPI spec and the
       generated clients.
     - **Anything that adds to an AGENTS.md (platform repo)**: don't brief it by default. The
       repo caps inherited AGENTS.md context at 32 KiB (`bash scripts/ci/check-agents-md.sh`,
       also a pre-commit hook). Several ingestion paths sit within bytes of that cap. Between
       08-20 and 09-22 four packages had their AGENTS.md bullets reverted after the hook failed,
       and a fifth landed with 7 bytes to spare. Route the
       rule to the domain doc (`invariants.md`, `schema-mapping.md`, `docs/…`) instead. If a
       line truly belongs in AGENTS.md, run the check before writing the brief and give the
       delegate the byte budget.
     - **Read-only research and premise sweeps**: ask by name for a **"things the plan would get
       wrong"** section, and say outright that "some premises here may be FALSE — saying so with
       evidence is the most valuable thing you can do." Both clauses produced the most valuable
       part of their reports (one killed a ticket work item outright by finding the commit that
       had already fixed it). Also tell it to **run the code to test its claims**: on JUS-2999
       grok read the fixtures and agreed with opus on every design point. Opus ran them and
       found three real defects that grok never saw.
     - **Research or review that depends on live behaviour**: pair the external lanes with one
       Claude lane that holds the MCP servers (dagster-plus, Superset, Sentry) or runs the real
       worker in-process. Delegates have neither. In the 09-24→25 window that lane changed the
       answer three times. On JUS-3074 a sonnet Agent pulled the live dbt error text and
       overturned a premise, because the staging loop had self-healed. On JUS-3071 an opus
       harness found raw_event at ~235 MiB of every landing file and settled the lanes'
       allocator dispute. On JUS-2408 an opus live-verification Agent found an Int128 batch
       drop and two retry-forever paths that the whole 4-model panel missed.
     - **Performance and memory measurement**: require the report to print the env vars that
       shape the number (`MALLOC_ARENA_MAX`, allocator confs, thread counts) and to say which
       environment each figure came from. The platform mise shell exports
       `MALLOC_ARENA_MAX=2`. glm's headline allocator win on JUS-3071 held only under that cap,
       and without it the setting made the peak much worse (2305 MiB).
     - **Code that runs per row, per entity or per line over real data**: "done means" includes
       a timing on realistic volume and a count of I/O round trips. Twice on 09-28 correct code
       came back far too slow: a grid that awaited ~3,000 `get_statistics` calls one after
       another, and a shell env parser 150x slower than the one it replaced (42s over 42
       worktrees, from a subshell per line). Neither delegate measured. The ones briefed to
       measure (SN-P1, SN-P1b, FT-P1) reported their overhead unprompted.
     - **UI layout packages**: "done means" includes a live `playwright-cli` screenshot at the
       widths that matter. jsdom computes no widths. On PV-PAGE every body column sat one to
       the left of its header, and all 1272 vitest tests passed.
     - **Checks that depend on what a reader yields** (CSV/Excel/Parquet inference, a JSON
       relay): the RED brief requires at least one fixture that goes through the real reader.
       JUS-3119's scientific-notation check was tested on String frames. The real CSV reader
       types the column Float64 first, so every tier was green and the feature never fired.
       The next RED brief carried the rule and caught the Excel reader's int-vs-float split up
       front. **Parsers and importers** get the same rule, applied to a real input file:
       require one real-world input as a fixture. A Gutenberg seeder's handcrafted fixtures
       hid both of its real bugs (every `rdf:value`, MIME types included, became a tag, and
       table-of-contents lines became dozens of empty chapters), and one real book showed them.
     - **Security-adjacent packages** (sign-in, sessions, rate limits, API keys): put an
       attacker's list in the brief. It covers spoofed `X-Forwarded-For`, account enumeration,
       in-memory stores that never free entries, secrets reaching logs, and echoed password
       prompts. Warn that the test harness may hide the attack: under vitest, Better Auth saw
       every client as 127.0.0.1 and skipped its origin check, so a bypassable login rate limit
       passed every test (reader 3c). Then send the diff to an adversarial opus review, per
       CLAUDE.md's security rule.
     - **Seeded test worlds**: check the brief's premise against the schema's uniqueness and
       FK constraints before you write it. A premise the schema forbids got "satisfied" by
       dropping an index inside the test transaction (JUS-3132). Require literal pins on the
       absolute count of every table the world seeds, not only the deltas under test. When
       both sides of a comparison go wrong together, the deltas cancel and the test stays green.
     - **Concurrency and ordering in plumbing** (tees, pipes, async fan-out): the test has to
       slow one side on purpose. A fast fake always wins the race. The wrappers' tee-drain race
       went green until only the stderr copy was slowed by 1.5s.
   - *RED proofs must run against the production path, not next to it.* One delegate proved its
     regression in an adjacent side script rather than by mutating the real sink — the claim was
     true, but the proof did not test what it claimed. When you re-verify, mutate the production
     code and watch the briefed test fail.
   - *Hard external constraints* — when correctness depends on a limit that lint/typecheck/CI
     cannot see, name the limit in the brief and require a real-stack proof. Live example: Alembic
     revision ids must fit `alembic_version VARCHAR(32)`; both ids in one package overran it and
     `upgrade head` hard-failed on real Postgres while every CI gate stayed green. Same shape for
     DB column widths, Restate wire-name limits, and identifier caps generally — require the
     delegate to run the thing (`alembic upgrade head` then `downgrade`) and paste the output.
     Two more that bit in the 09-24 window: **Trino's 150-stage query cap**, which dbt's
     PARTITIONED session pushes past on filtered selects (165 stages on one model, 182 on a
     resolution view). The brief should require a real `dbt build`/test run and ban dropping
     tests to get under it. The second is **migration sequence numbers already claimed by open
     PRs**: a ClickHouse `005` collided. Run `gh pr list` over the migrations directory before
     you brief a number. And **row-count parity is not consumer parity**. A ClickHouse sink
     rounded a `9999-12-31` sentinel up to year 10000, which `clickhouse-connect` can't decode,
     so the Superset chart broke while the CH and Trino counts matched exactly. When a sink
     feeds a dashboard or another reader, require a read through that reader's own driver, or
     render it.
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
     test; pool/listener error handlers; an abort, timeout or exit handler that starts new work
     inside the same synchronous dispatch; leaving a page and coming back inside a client cache
     window, not just a reload. Both app builds of the 09-02 batch (the journal UI, reader step 1)
     shipped green with defects from this list, and so did three reader packages on 09-26→27: a
     400-chapter abort that spawned 392 workers in one dispatch, a router cache that restored the
     first visit's position, and a refresh in one field that overwrote another field's pending
     save. Pools and state machines also need a spawn-count or in-flight-count test from the
     start. Timing tests need wide margins and a warm-up, and the brief should spell both out.
   - *Long lanes* (anything past ~1 h): commit the first slice early (lanes that chased a full
     battery mid-loop went 4 h with no commit); run only the touched test targets in the loop
     and the full battery at most twice; when done or waiting on a verdict, **stop and idle —
     never poll a PR** (one lane polled `gh pr view` for 3.5 h); diff against `origin/main`,
     never a local `main` (a stale local main produced a bogus review finding).
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Read the deviations reports first, then review — always, by a different model than the
   builder.** The builders' deviations sections and their narration are a *review input*, not a formality: they have located the
   confirmed finding ahead of the reviewer three times (the unowned `retargetRow` seam; a
   struggling narration that pinned the exact bad test before the diff was opened; a
   "prescribed mutation was vacuous" note that turned out to be a production bug, not a
   mutation-design problem — **treat a vacuous mutation on the field under test as a bug
   signal, never as a brief defect to work around**; the one exception is a mutation
   prescribed *generically across sibling packages* that the sibling's own code path cannot
   structurally reach — a briefed "feed it a newline in the leftover" was vacuous for the
   LEDES reader because its split is `rfind(b"\n")`, so leftover can never hold one. Tell
   them apart by asking whether the mutation is unreachable *by construction* or merely
   *not caught*: unreachable → substitute a mutation that bites in that package; not caught
   → production bug). Then capture the diff
   (`git show <sha> > <scratchpad>/<slug>-diff.txt`) and hand a fresh-context reviewer: the diff
   path, changed-file list, domain rules, the unowned-seam list from the decompose step, and
   focus hints *including your own suspicions and anything the builder's self-review dismissed*.
   Builder self-review and same-tier review raise the floor but miss the cross-surface class
   (widened-row-inherits-combinator-lies, zone-reach in ceremony, decision-offer scope over outer
   spec, copied idiom from an adjacent-but-different primitive). Pick the reviewer by diff shape:
   - **Engine-semantics / new-primitive waves: opus or grok-4.6.** Opus found the whole cross-surface class in the 09-02 batch; grok-4.6 took over the seat on 09-10 (Tim, to move reviews off opus) and found the same class across ~11 passes with no hallucinated findings.
   - **Diffs over ~3k changed lines: opus, grok-4.6 or Codex Luna** — glm-5.3 reviews timed out twice at 7,184 lines, and deepseek-flash hung at 2,400.
   - **Small fix-loop diffs (≲500 lines): deepseek-v4-flash-0731** is the cheap reviewer.
   - **Standing focus hints**, beyond your own: numbers that don't sum or weren't pasted from a command; claims without a pin in the same commit; a widened row reaching an old combinator; lifecycle and concurrency sequences nobody wrote down.
   - **The reviewer picks its own mutations.** The builder's mutations and the brief's mutations both
     miss things. On reader 2a every briefed proof passed, and the opus reviewer's own mutations
     still left six survivors. One test changed its subject in the "before" step, and a "paged"
     test fit on one page. On reader 3d a mis-specified brief mutation pushed the builder to
     change behaviour until the proof fired. Ask the reviewer for 5–10 mutations at the riskiest
     branches, and treat each survivor as a finding.
   - **Re-run every gate the report claims, and gate on the command's own exit code.** A
     "typecheck: no errors" line sat over 11 errors (reader 3d). Separately, a merge gate that
     piped the check through `grep` tested grep's status and let those errors through.

   **Put comment truth on every review's focus list.** In the 09-25→28 window it was the most common thing review caught, in eight rows
   across grok, glm and both gpt-6-sol handoffs. Examples: a docstring saying a size guard ran before FastAPI parsed the
   body when it ran after; comments repeating a premise the same package had disproved; a
   docstring describing a caller that no longer existed; a stalled lane's comment claiming a
   column move it never made. Read each new or changed comment against the code it sits on.
   When a delegate documents a divergence as
   "intended by design", check it against the ticket's acceptance criterion rather than
   against the implementation. In read-only audit/sweep reports, the *finding* and its *fix
   sketch* carry different reliability: findings backed by quoted code hold up, but the
   remediation sketch is often wrong (a `ref()` on a column that doesn't exist; a cost the
   sketch attributes to a path that's gated off). Verify sketches independently — a wrong
   sketch does not invalidate the finding, and a real finding does not validate the sketch. And
   **synthesis stays yours**: on a two-model sweep neither model noticed the repo had already
   settled the open question in its own invariants doc. Models sweep the surface they are
   pointed at; joining that sweep to what the repo already decided is orchestrator work.
5. **Fix pass, push, cleanup.** Confirmed findings go **back to the builder, not to your own editor** — the builder holds the package context; hand-fixing burns Claude time re-deriving it and silently takes Claude out of the reviewer seat. Fix by hand only when the fix is smaller than the brief for it. The same bar applies to a whole package. Two A-graded briefs (JUS-3049, JUS-3044 pkg A) were so close to the finished code that writing the code would have been quicker. When the brief has to spell out every exit path, it is already the code, so write it yourself. **Prefer a fresh one-shot carrying the fix list over resuming the session** (pi session-resume hung 3 of 4 attempts; both fresh fix one-shots finished in ~20m) — a fix list is self-contained enough that the lost context rarely matters. grok CLI resume (`grok-delegate -s <session-id>`) has not hung. Re-run the battery, push, then remove the worktree.
6. If the target branch moved while the builder ran, expect conflicts in shared files — resolve keeping both intents, never discard either side blind.

## Scorecard: log every delegation

`LOG.md` next to this file is the calibration record. **It is per machine**: chezmoi seeds it
once (`create_LOG.md`) and never syncs it, so tim-dev and jb-dev each keep their own, and their
findings meet only in this file's shared source (see the retro's sync step). After each
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
until the cooldown lapses). On demand: `/delegate retro` — runs regardless of cooldown.

**Count the rows, never a stored counter.** `LOG.md`'s `retro-state` header carries
`last=<date> base=<N>`, where `N` is the number of table rows the retro left behind after
compressing. New rows are the table count minus `base`. `N` is written once, by the retro,
from a `grep -c`, so it can't drift the way the old hand-bumped counter did. That counter
undercounted five windows running (7 vs 19, 9 vs 40, 8 vs 14; on tim-dev 6 for 13, then 12 for
21) because fan-outs append in bursts. Dates alone don't work either. The 09-22 retro closed
mid-day, and the 15 rows logged after it that day never counted (the trigger said 8 when the real number was 23). When a retro
ends, set `base` to `grep -cE '^\| [0-9]{4}-' LOG.md`, leaving out any rows other sessions
appended while the retro ran. Nobody reviewed those, and two landed during the 09-28 retro.

Without a `base`, count the rows dated after `last` (`delegate-retro-due` falls back to the same):

```sh
awk -F'|' -v last="$(grep -o 'last=[0-9-]*' ~/.claude/skills/delegate/LOG.md | cut -d= -f2)" \
  '$2 ~ /^ 20[0-9][0-9]-/ && substr($2,2,10) > last' ~/.claude/skills/delegate/LOG.md | wc -l
```

Rows in the project ledgers count toward the trigger too.

**The trigger is checked by the wrappers.** Counting rows correctly did not help, because no
step ever ran the count. The trigger went unchecked from 08-20 to 09-22 while 247 rows piled
up, and the log grew to 144 KB. Both `pi-delegate` and `grok-delegate` now call
`delegate-retro-due` at launch (real runs only). It prints one `delegate: retro due …` line to
stderr once the trigger holds and stays silent otherwise. When that line shows up in a launch's
output, hand the retro off as described below. You can also run `delegate-retro-due` by hand
(exit 0 = due, 1 = not due).

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

**Before step 1, sync the shared source.** Two machines run this retro against one chezmoi
source, and each one only sees its own `LOG.md`. The 09-26 tim-dev retro never saw jb-dev's
four retros from 09-22 to 09-25. When the two were merged on 09-29, nobody applied the merge on
tim-dev, so tim-dev ran the old skill until 10-04. In that time its reader briefs went out
without `brief-common.md`, and one OpenRouter run hung silently for 39 min, where the CPU
watchdog would have killed it at 6. So start with `chezmoi git pull`. Then run
`chezmoi diff ~/.claude/skills/delegate ~/.claude/CLAUDE.md ~/bin` and apply the delegate paths,
after checking that the diff drops no local-only edit. Finish by committing and pushing the
source, so the other machine's next retro starts from yours. Since 10-04 both wrappers warn at
launch when the installed skill or wrappers differ from the source.

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
- set `retro-state` to `last=<today> base=<N>` (see above), and append a one-line retro entry
  recording what changed
- commit and push the chezmoi source (see the sync step)

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
- **A merged source is not an installed skill.** A `git pull` or merge in the chezmoi source
  changes nothing under `~/.claude` or `~/bin` until `chezmoi apply` runs. That has happened
  twice (07-27, and 09-29→10-04 on tim-dev), so the wrappers now print
  `delegate: the installed delegate skill or wrappers differ from the chezmoi source` at
  launch. When that line appears, look at `chezmoi diff` and apply the delegate paths before
  you write the next brief.
- **Waiters that match themselves.** `pgrep -f grok-delegate` or `pkill -f <pattern>` matches
  the waiter's own command line, and that bit two rounds. Use `pgrep -f 'grok-delegat[e]'`.
- **grok CLI can exit 0 with only a preamble** in plain output mode. It captures a
  mid-exploration message, or only the closing summary, as the final answer. It happened again
  on 09-28 (JUS-3038 D4). `grok-delegate` now warns on stderr when a successful report is under
  1500 bytes. brief-common's *Read-only lanes* section tells research and review lanes to
  heredoc the full report to a file before the final message, which is what fixed the rerun.
- **grok CLI report files can come back interleaved** with prose from its parallel sub-agents.
  The findings are still recoverable, so read the whole file and not only the tail.
- **The Write/Edit tools can turn a `\u00a0` escape into a literal NBSP.** On JUS-3007 a brief
  shipped the invisible character and the delegate's test copied it. It reproduced while the
  09-23 retro was writing this very bullet, and the check caught it. In any brief about
  Unicode or whitespace, write the escapes through Python (`chr(92) + "u00a0"`). Both wrappers
  now run `delegate-brief-check` on `-f` briefs and warn on any invisible Unicode (non-ASCII
  spaces, zero-width characters, BOM). A warning means fix the brief and relaunch.
- **Don't pass `--sandbox` explicitly on a host without user namespaces** (jb-dev).
  `--sandbox read-only` breaks there, and it bit a read-only corroboration lane again on 09-23.
  `grok-delegate` now refuses an explicit profile it can't honour (exit 2) instead of letting
  grok fake a success. For a read-only lane, omit `--sandbox` and pass `--read-only`.
- **A bare `--deny Edit` or `--deny Write` kills a grok lane's shell.** grok applies Edit and
  Write deny rules to every path a shell command writes, and `2>/dev/null` counts. With bare
  rules, every command carrying a redirect is refused ("deny rule on edit"), and so is the
  file-write tool in `/tmp`. The JUS-3038 premise lane lost its shell that way on 09-25, went
  static-only, and graded C for wrongly claiming a file didn't exist. The retro reproduced it
  on 09-28 with grok 1.0.41. `grok-delegate --read-only` applies path-scoped rules instead
  (`Edit(<worktree>/**)`, `Write(<worktree>/**)` and the git-state denies). That keeps the shell
  and `/tmp` usable and still blocks repo writes through the edit tool or a shell `>>`. The
  wrapper now refuses a bare Edit/Write deny with exit 2.
- **A provider refusal used to leave an empty report.** x.ai's 402 ("Grok Build usage balance
  exhausted") and a z.ai 429 both print to stderr only, so the `-o` report came back empty and
  said nothing. Both wrappers now copy the delegate's stderr to `<report>.stderr`, append a
  trailer with its last lines to the report on any failed or empty run, and exit **3** on a
  provider refusal. Exit 3 on x.ai means the lane is out for the day, so salvage and reroute.
  A 429 may clear on one relaunch.
- **A detached worktree's tests run the original checkout's code.** mise exports
  `VIRTUAL_ENV` and PATH for the main checkout's `.venv`, and a worktree outside the repo
  inherits them. There the bare `pytest`/`python` imports the workspace packages from the
  *original* source tree (verified 09-25: `jb_platform_sdk.__file__` resolved to
  `~/repos/platform/libs/...`). A mutation made in the worktree never runs, so a mutation
  proof "survives" and a RED-at-HEAD proof tests the dirty main tree. `uv run` is no fix
  either: it builds a fresh root-only `.venv` in the worktree that lacks the workspace
  members (`ModuleNotFoundError`). glm caught this on a panel and fixed it with `PYTHONPATH`.
  brief-common now requires an `import X; print(X.__file__)` check before any proof outside
  the main checkout. Do the same check before your own. `PYTHONPATH` isn't always enough,
  because an editable install of the SDK wins over it when pytest runs from the repo root.
  Two grok lanes hit that on 09-25. One fixed it by importing from the copy and calling
  `pytest.main` in the same interpreter. The other swapped its mutated files into the
  worktree and restored them.
- **Write briefs with the Write tool or a quoted heredoc (`<<'EOF'`).** An unquoted heredoc
  ran a brief's backticks as shell on 09-25 and silently dropped that text from the brief.
- **The auto-mode classifier can block reads of scratchpad report files.** On 09-25 it
  flagged them as "Modify Shared Resources" until Tim approved. Read reports with the Read
  tool on the exact `-o` path rather than through a shell pipeline. Opus Agents hand their
  report back in the completion message, so that one needs no file read.
- **Launch every delegate with `run_in_background`, never a detached `( … &)` subshell.** The
  subshell ran fine, but its completion notification never arrived, so the harness had nothing
  to wake on. A long run detached on purpose (see the parent-harness kill above) needs its own
  completion monitor for the same reason.
- `grok-delegate` has no heartbeat or CPU watchdog, and no `--heartbeat` flag. That's by
  design, since grok CLI hasn't stalled in this log. Use `-T` there for the turn cap. In
  `pi-delegate`, `-T` means wall-clock minutes.
