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
| **glm-5.2** | `--provider zai --model glm-5.2` (Tim's pi default) | Repo-scale long context (usable 1M — its headline feature). Iterative run-test-fix loops (measurably better when told to execute and self-verify than one-shot). Self-contained/single-file work, local bug review. Doesn't refuse security-adjacent tasks. Observed (6+ rows): reliably flags false premises in briefs instead of silently applying them — a strong premise-checker and docs/verification-sweep delegate (grok-4.5 is now confirmed at parity on premise checks). Docs caveat: glm drifts on the *semantics* of code it summarizes secondhand — put the exact wording for contract-bearing bullets in the brief. z.ai stalls when 2+ glm runs launch simultaneously — stagger them, and after 2 consecutive zero-CPU stalls reroute the package to grok CLI rather than retrying a third time. **Read-only panel and design lanes:** glm repeatedly sat at near-zero CPU for 10–20+ min and then delivered the round's unique real finding (a design-changing strand-PENDING catch, a per-file-terminal PermissionError, a CRITICAL red-CI catch from reading the live run). On read-only lanes use `-W 20` and let the round proceed without it; the two-strike rule still applies to 0-byte deaths. The stall pattern also strikes solo staggered runs on bad days (2026-08-13: every glm attempt stalled) — after two strikes anywhere, **drop z.ai for the rest of the day** for every lane the round waits on (builds, RED writers, gating reviews), not just for that package. Non-gating read-only lanes at `-W 20` may still launch, because a stall there costs nothing. On 09-24 two glm lanes stalled, and two other read-only glm lanes that same day sat at zero CPU for 6–10m and then graded A, one of them with the window's deepest unique findings. A passing smoke does not clear the day: on 2026-08-19 both real runs stalled minutes after a clean smoke — the smoke only rules a provider *out*, never in; the two-strike rule is the real gate. **09-22→23:** 7/7 A, zero stalls, runs staggered 150s apart. That covered a spec-first RED suite (it invented the scratch-impl mutation proof), a Trino parity suite, a docs sweep, a design review with exact filter-length math, and two contract transcriptions. **09-23→24:** zero stalls again with ~3m staggers, and a glm premise sweep found a bare-subscription hazard that neither grok nor the orchestrator saw. The one F was a RED suite for a full Trino integration tier. It ran into the 90m backstop and left its scratch implementation in the tree rather than /tmp. **09-24→25:** 7 of 9 lanes delivered. The two misses were z.ai stalls on 09-24. One was an integration RED writer that wrote a correct test in ~3m and then stalled before RED. That is the second integration-RED miss, so the rule in the next column is confirmed. The other was a research lane that burned 6s of CPU in 40m. On panels glm went A twice. It independently mutation-proved a finding and caught the detached-worktree venv trap (see *Known failure modes*). | Cross-file reasoning — quality wobbles when correctness spans many files (kilo.ai eval); use grok-4.5 or Claude there. Integration-heavy RED suites (a full Trino tier): give glm the unit tier and send the integration tier to grok CLI (missed twice: JUS-3012 F, JUS-2408 B) |
| **grok-build-0.1** | `--provider xai --model grok-build-0.1` | **Dormant — zero rows since 08-20.** grok-4.5 @ grok CLI now finishes the same tiny packages in 1–3m at A with a report you can trust, so there is no latency gap left for this lane to fill; reach for it only on a swarm too wide for grok CLI's rate limit. The mechanical-swarm lane: latency-sensitive small tasks and wide fan-outs of tiny packages — renames, scripted edits, lookups (100+ tok/s). Purpose-trained coding workhorse (SWE-bench Verified 70.8, successor to grok-code-fast). 256K ctx. 6 rows: on genuinely tiny mechanical packages it is an A (gate registration, 4m). Its failure is always the same phase — **the edits land, the report doesn't**: false "ruff clean" on a ruff-failing file, silently dropped coverage, and a sweep that went byte-complete then burned 15s of CPU in 39min and died in verify. Route it mechanical work freely, size the package small, and plan to re-run its gates and salvage its output yourself. | Anything needing judgment; anything gated by a hard external constraint CI can't see (see *Done means*); anything where you would actually rely on the report |
| **grok-4.3** | `--provider xai --model grok-4.3` | Fallback 1M-ctx reasoning model if glm-5.2 is rate-limited on a long-context task. | Generally superseded by grok-4.5 |
| **deepseek-v4-flash-0731** | `--provider openrouter --model deepseek/deepseek-v4-flash-0731` | **Corroboration lane** (10 graded rows: 9 B, 1 A-): in multi-model sweeps and read-only review panels it reliably confirms other models' findings and lands a unique real one roughly every other run (a missed ci-config dep, an untested join, a missing frontend recovery path), but its reports are thinner, it has called authz OK where it wasn't, and its **line-number citations drift (off by up to 200 lines)** — verify by content, never by cite. Slow zero-CPU starts (5–7m) are common and look like hangs; give it a wide `-W`. One A on a different shape: writing a RED integration suite from a spec — a role where its weaknesses (thin prose, drifting cites) don't bind, and it disproved a half-wrong brief premise instead of encoding it. Treat spec-driven test-writing as its one non-corroboration lane, still never as sole coverage. Pay-per-token via OpenRouter (cheap, not free), and the provider itself flakes some days (hangs, upstream-closed). **08-20→09-22 (34 lanes):** quality held — a tiny contract-suite implementation and two blind RED unit suites all graded A, and one read-only sweep produced a round's most valuable finding — but **5 of its 11 F's in the window were runs that never became runs** (zero files, single-digit CPU over 20–30m). Three of those were build packages. So keep it **off the critical path**: a build package goes to deepseek only when something else can absorb its loss. On read-only panels give it `-W 20` and never wait on it. **09-22→23:** 2/2 finished (A-, A), on an independent design review with accurate cites and on a contract transcription it was deliberately kept off the critical path for. **09-23→24:** it graded B on all four panels. Twice it reported "no correctness issues" on a diff where opus found a design-changing defect, and once it wrote its report over opus's file. Its research-panel lane (A-) still landed two unique guards. **09-25:** B+ and A- on two panels, with one unique real find: an unaliased `a + b` parses as `b`, which is a false pass. | Sole coverage of any surface — never the only model on a package; high-stakes or judgment-heavy work; anything where citation precision matters |

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
  or goes into your review notes.
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
  still imports the original checkout (see *Known failure modes*).

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
  has to go as deep as opus would.
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
  glm's in-place mutation hot-reloaded the backend under a live test.
- **Settle a lone dissent against the running stack instead of by vote.** Twice the minority
  finding was the real one (grok over opus once, glm over the other two once).
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

Every B grade in the log shares one failure mode: the delegate's own green tests missed a real
hole — the same mind wrote the code and the proof. Splitting it is now validated end to end
(JUS-2079: RED unit + RED integration + implementation + parity, four delegates across three
providers, 4/4 A, zero orchestrator fixes) — and both test-writers independently disproved a
false premise in the brief instead of encoding it, which is exactly what a test-as-contract
author is for. For any package worth TDD, split it:

1. **Delegate A** writes the failing test suite from the spec alone — blind to any
   implementation. Tests-as-contract.
2. **Claude reviews the tests** (cheap: read one file against the spec; mutation-test if the
   suite guards something subtle).
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
  - **kills the group after 6 minutes of zero tree-CPU** (`-W/--stall <mins>`, `0` disables;
    was 3, raised after three false kills of slow-starting glm/deepseek runs) and
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
     clean docs package traced to the facts sheet, not the model). For a package-sized contract
     feeding a fan-out, have an independent opus pass review the contract BEFORE launching
     builders — the one contract gap that reached review was a spec defect no builder could
     have caught. **Treat that pass's count as a routing signal.** On JUS-3012 it found six
     HIGHs in the ingestion-queue contract. The implementation package built on it still came
     back the log's only C in two windows, followed by two B fix rounds. When the contract
     review finds that much, writing the spec was the hard part, so keep the stateful core
     in-house or split it much finer before you delegate it.
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
     own — "its tests are green" says nothing about the suite next door.
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
     you brief a number.
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Read the deviations reports first, then review — always.** The builders' deviations
   sections and their narration are a *review input*, not a formality: they have located the
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
   sketch does not invalidate the finding, and a real finding does not validate the sketch. And
   **synthesis stays yours**: on a two-model sweep neither model noticed the repo had already
   settled the open question in its own invariants doc. Models sweep the surface they are
   pointed at; joining that sweep to what the repo already decided is orchestrator work.
5. **Fix pass, push, cleanup.** Confirmed findings go **back to the builder, not to your own editor** — the builder holds the package context; hand-fixing burns Claude time re-deriving it and silently takes Claude out of the reviewer seat. Fix by hand only when the fix is smaller than the brief for it. The same bar applies to a whole package: one A-graded brief (JUS-3049) was so close to the finished code that writing the code would have been quicker. **Prefer a fresh one-shot carrying the fix list over resuming the session** (pi session-resume hung 3 of 4 attempts; both fresh fix one-shots finished in ~20m) — a fix list is self-contained enough that the lost context rarely matters. grok CLI resume (`grok-delegate -s <session-id>`) has not hung. Re-run the battery, push, then remove the worktree.
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
until the cooldown lapses). On demand: `/delegate retro` — runs regardless of cooldown.

**Count the rows, never a stored counter.** `LOG.md`'s `retro-state` header carries
`last=<date> base=<N>`, where `N` is the number of table rows the retro left behind after
compressing. New rows are the table count minus `base`. `N` is written once, by the retro,
from a `grep -c`, so it can't drift the way the old hand-bumped counter did. That counter
undercounted five windows running (7 vs 19, 9 vs 40, 8 vs 14) because fan-outs append in
bursts. Dates alone don't work either. The 09-22 retro closed mid-day, and the 15 rows logged
after it that day never counted (the trigger said 8 when the real number was 23). When a retro
ends, set `base` to `grep -cE '^\| [0-9]{4}-' LOG.md`.

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
- set `retro-state` to today's date, and append a one-line retro entry recording what changed

Early on the log is thin and every row moves the picture; once patterns stabilize, prune
aggressively — the log should stay a page, not an archive.

## Known failure modes

- z.ai API calls occasionally flake and need a retry (community-reported; retry once before switching models).
- Rate limits on both subs are undocumented; if a provider throttles, switch to the other sub's equivalent model.
- `--thinking high` on glm-5.2 can stall for minutes — never use it for delegation.
- Headless pi with a hung task: check `ps` for the `pi` child process; kill and rerun at lower thinking.
- **Waiters that match themselves.** `pgrep -f grok-delegate` or `pkill -f <pattern>` matches
  the waiter's own command line, and that bit two rounds. Use `pgrep -f 'grok-delegat[e]'`.
- **grok CLI can exit 0 with only a preamble** in plain output mode. It captures a
  mid-exploration message as the final answer. Relaunch with a first brief line that says
  "finish the investigation, then output your findings in full".
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
  grok fake a success. For a read-only lane, omit `--sandbox` and deny Edit/Write and
  `git add`/`commit` with `--deny`.
- **A detached worktree's tests run the original checkout's code.** mise exports
  `VIRTUAL_ENV` and PATH for the main checkout's `.venv`, and a worktree outside the repo
  inherits them. There the bare `pytest`/`python` imports the workspace packages from the
  *original* source tree (verified 09-25: `jb_platform_sdk.__file__` resolved to
  `~/repos/platform/libs/...`). A mutation made in the worktree never runs, so a mutation
  proof "survives" and a RED-at-HEAD proof tests the dirty main tree. `uv run` is no fix
  either: it builds a fresh root-only `.venv` in the worktree that lacks the workspace
  members (`ModuleNotFoundError`). glm caught this on a panel and fixed it with `PYTHONPATH`.
  brief-common now requires an `import X; print(X.__file__)` check before any proof outside
  the main checkout. Do the same check before your own.
- **Write briefs with the Write tool or a quoted heredoc (`<<'EOF'`).** An unquoted heredoc
  ran a brief's backticks as shell on 09-25 and silently dropped that text from the brief.
- **The auto-mode classifier can block reads of scratchpad report files.** On 09-25 it
  flagged them as "Modify Shared Resources" until Tim approved. Read reports with the Read
  tool on the exact `-o` path rather than through a shell pipeline. Opus Agents hand their
  report back in the completion message, so that one needs no file read.
- **Launch every delegate with `run_in_background`, never a detached `( … &)` subshell.** The
  subshell ran fine, but its completion notification never arrived, so the harness had nothing
  to wake on.
- `grok-delegate` has no heartbeat or CPU watchdog, and no `--heartbeat` flag. That's by
  design, since grok CLI hasn't stalled in this log. Use `-T` there for the turn cap. In
  `pi-delegate`, `-T` means wall-clock minutes.
