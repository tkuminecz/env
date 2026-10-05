# Delegation scorecard

<!-- retro-state: last=2026-08-10 base=0 -->

One row per delegated task, appended when its pipeline finishes. Grades: **A** merged as-is · **B** merged after minor fixes · **C** needed major rework · **F** discarded/redone by hand. Review col = findings the builder's own verification missed.

Retros run only when Tim asks (`/delegate retro`); nothing triggers one automatically. `base` is
the number of dated table rows the last retro left behind, so every row past it is new.

**The rows table is the LAST section of this file — append new rows to the bottom of the
table, which is the bottom of the file.** (Two retros in a row found rows appended in the
wrong place; the table now lives last so the append-to-bottom instinct is correct.) Keep the
column order exactly `date | task | model @ harness | grade | time | review findings | notes`
— four rows in the last window swapped task/model and broke scanability.

## Distilled patterns

(Promote observations here once rows repeat them; fold stable ones into SKILL.md's routing table and prune the raw rows they came from.)

- **Grades have plateaued at excellent; the residual defect class is brief-induced tier
  blindness.** ~30 packages this window: 26 A/A-, 4 B, no C/F. 3 of the 4 B causes were the
  brief withholding the verification tier where the risk lived — "don't run integration" hid
  two tests pinning the old semantics; unit mocks structurally can't see real-CH lifecycle
  bugs; a docs recipe was never actually executed. When a brief forbids or lacks a tier, the
  orchestrator owns that tier's assertions (now in SKILL brief template).
- **Disjoint fences guarantee an unowned seam, and that is where the surviving real bug lives.**
  Enumerate the files that read/write the round's data and are owned by nobody; assign or
  review them explicitly. Same class: changes that re-key shared fixtures/literals must be
  briefed to run the neighboring suites.
- **Premise-checking is now a two-model capability.** glm's long-standing strength, and
  grok-4.5 confirmed at parity twice in one window (rewrote a doc to the truth against my
  false claim; treated a reviewer's miscount as unverified). State shaky premises as
  explicitly unverified — both models then disprove them instead of implementing them.
- **Read-only audit packages earn a rotation slot.** Cheap (~5m), and one found two real
  out-of-scope gaps that became a fix package. They are also the right lane for reviewing my
  own work — a fresh context has no stake in the cut being lossless.
- **Never trust the pasted gate — re-run it.** Report truncation/turn-cap keeps eating the
  evidence tail on the grok lane while the edits sit complete; and one "pre-existing suite
  errors" claim was simply wrong. Salvage-first after any kill; run the missing proofs
  yourself rather than requeuing.
- **Read the deviations report before the diff.** It repeatedly names the confirmed finding
  ahead of the reviewer. A vacuous mutation on the field under test is a bug signal; a
  divergence called "intended by design" gets checked against the acceptance criterion. The
  STOP conditions must name assertion-weakening explicitly — a green suite hides a bent test.
- **No-commit concurrent shared checkout is settled** (~25+ clean concurrent packages, zero
  fence or index collisions). Interface-first seeding beats sequencing and worktrees for
  interdependent packages. Fix passes go to a **fresh one-shot with a fix list** — beat
  hand-fixing twice this window; never session-resume pi.
- **Weak-test defects track the brief, not the model.** Mutation-RED-briefed suites stay
  clean; un-briefed ones ship can't-fail assertions. Brief-writer owns command correctness
  too — run every command the brief quotes (including doc *recipes*, whose effect must be
  verified, not just their syntax) before shipping.
- **grok-4.5 @ grok CLI is the primary lane** — best-graded, reliable under concurrency, now
  also the docs fallback when z.ai flakes. Costs: turn cap eats the report tail; sandbox
  auto-downgrades on jb-dev (wrapper handles it).
- **glm-5.2: sweeps and premise checks; feed it exact wording for contract-bearing doc
  bullets** (it drifts on semantics of code summarized secondhand). After 2 consecutive z.ai
  zero-CPU stalls, reroute to grok — don't retry a third time.
- **grok-build-0.1: genuinely tiny mechanical packages only**; edits land, reports lie.
- **Constraints CI cannot see** (identifier length caps, DB column widths): name the limit in
  the brief and require a real-stack proof with pasted output.
- **Provider starvation trips the watchdog on healthy runs.** Cap concurrent launches at 2–3
  per provider, `-W 10` on fan-outs, detect hangs by tree-CPU never elapsed time — but note
  tree-CPU does not discriminate for API-bound read-only tasks (pi blocks on network I/O).
- Coverage clusters on the path the brief describes most vividly; enumerate the boring paths.

## Retro history

- 2026-08-10 (on-demand) — ~30 packages since 08-05 (26 A/A- / 4 B / 1 z.ai hang; no C, no F).
  Grades plateaued; the new dominant B class is **brief-induced tier blindness** (3 of 4 B's:
  forbidden integration tier hid pinned-semantics tests; mock-only env hid real-CH lifecycle
  bugs; a docs recipe shipped unexecuted). Changes: SKILL brief template gained a
  *forbidden/unavailable tiers are the orchestrator's tier* section plus the
  run-the-neighboring-suites rule; glm routing row gained the exact-wording-for-contract-bullets
  caveat and the reroute-after-2-z.ai-stalls rule; grok-4.5 noted as premise-check parity.
  Also promoted: read-only audit packages in rotation; fresh fix-list one-shots over
  hand-fixing. Log restructured with the rows table last (rows had AGAIN landed below Retro
  history — counter said 6, truth ~27 — and 4 rows had swapped columns). Compressed 27 rows
  to 6. No CLAUDE.md routing-list changes; kill criterion not met anywhere.
- 2026-08-05 (on-demand) — 26 rows / 35 graded packages (24 A / 9 B / 2 salvaged F; **no C, no
  true F**). Best window on record, and the finding is that **the residual defects are
  orchestrator-owned**: 5 of 9 B causes were my contract, my command, my unstated env gap, my
  unfenced test. Two genuinely new classes: (1) **the unowned seam** — disjoint fences mean the
  file between two packages is tested by nobody; (2) **assertion-weakening** — a delegate obeyed
  "don't fix the bug" by bending its test to the buggy result. Changes: `grok-delegate`
  `--max-turns` 40→80 + sandbox auto-downgrade probe; SKILL gained unowned-seam decompose step,
  *Stop conditions*, brief-command verification, vocabulary fence, unverified-premise device,
  deviations-first review. Compressed 26 rows to 6.
- 2026-07-31 (on-demand) — 7 rows / ~13 graded packages (6 A / 5 B / 2 F). Every degradation was
  infrastructure-owned: provider starvation under a 6-way simultaneous launch, two shared-index
  commit sweeps, one autostash-window confusion. Changes: concurrency cap (2–3 per provider,
  `-W 10`), salvage-first after any kill, no-delegate-commits default for concurrent rounds, grok
  CLI made the mandatory lane for concurrent grok-4.5 packages. Compressed 12 rows to 5.
- 2026-07-30 (on-demand) — 13 rows / 18 packages (9 A / 6 B / 1 C / 2 F). Hangs, not quality: 4
  hung runs ≈25h dead → `pi-delegate` CPU-stall watchdog. Second class: false gate claims (4×) →
  *Done means* demands pasted output plus commit proof. The single C traced to a constraint CI
  can't see (Alembic id >32 chars) → *Hard external constraints* brief section.
- 2026-07-29 (pm) — 9 rows (4 A / 5 B). Blame flipped to orchestrator-owned causes →
  facts-sheet/contract verification bar, pre-fan-out opus contract review, sequencing rule;
  mutation-RED widened to any package containing tests. Added the 1-day auto-fire cooldown.
- 2026-07-29 — 10 rows (8 A / 2 B). B's clustered 100% on test deliverables with can't-fail
  assertions → mutation-RED + exact-token assertions added to *Done means*. Shared-checkout +
  fences promoted to default. Found the live SKILL.md stale since 07-27 (source edited, never
  applied) → added the diff-verify step to the retro checklist.

## Rows

| date | task | model @ harness | grade | time | review findings | notes |
|---|---|---|---|---|---|---|
| 2026-08-05 | JUS-2052 bounded-fold drain divergence, 4 pkgs (twin-equivalence test / docs corollary / read-only audit / batch_id fix) | 3× grok-4.5 (2 CLI, 1 pi) + glm-5.2 @ pi | A ×3, B ×1 | 3–12m | B: docs recipe named `seed_cv_local.py --truncate` for clearing staging rows, but the script only DELETEs raw tables — the recipe was never executed. | Win: the read-only audit pkg found two real out-of-scope gaps (batch_id detection-only; observations never selects staging), both verified in source and turned into the fix pkg. |
| 2026-08-06 | JUS-1982 invoice reverse-ETL to CH, 10 pkgs (A–F build, G–I2 restructure) | 9× grok-4.5 @ grok CLI + glm-5.2 @ pi | A ×6, A- ×3, B ×1 | 6–25m each | B (pkg B): 3 real-CH lifecycle bugs + unguarded param — invisible to unit mocks by design, closed in fix pass F. A- dings all minor (logging config, gate-key vocab = contract defect, eager loads). One false "pre-existing suite errors" claim — re-run gates yourself. | glm pkg C flagged the frozen contract's Trino BOOLEAN cast bug + env_secrets gap. Pkg I STOPPED correctly on the uv-member shadowing hazard and produced the options table that shaped I2. Fresh one-shot fix pass worked; stop-conditions paid for themselves. |
| 2026-08-06 | JUS-2023 review-feedback: coverage-gap tests, contract-doc edits, PR #2274 doc corrections | 2× grok-4.5 @ grok CLI (+1 retake), glm-5.2 hung | A ×2, A- ×1, glm F (infra) | 4–25m | Zero code defects. grok caught a flaw in MY brief (seed collided with a watermark test's premise) and a false premise in a doc brief (dim_matters has no mapping gate) — grok premise-check parity confirmed. | glm z.ai stall at 3m zero-CPU, zero work; relaunched on grok fine. Docs retake surfaced a real pre-existing doc bug via deviations but preserved the wrong phrasing — deviations need acting on, not just reading. |
| 2026-08-10 | JUS-2272, 4 pkgs (blind TDD tests / RE2J twin impl / docs / 11-fix literal-drift pass) | 3× grok-4.5 @ grok CLI + glm-5.2 @ pi | A ×4 | 4–25m | Impl pkg didn't run the neighboring integration suite (brief didn't ask) → 11 literal-drift failures surfaced only in my full-suite run — brief defect. TDD pkg's "own pytest session" caveat was a real CI breaker no fence owned. | Fix-list one-shot to a fresh delegate beat hand-fixing. glm discovered the one-build-per-session memory-connector limit empirically and designed around it honestly. |
| 2026-08-10 | JUS-2128, 4 pkgs (dbt_refresh_views tables / alert-policies revival / rev-2 test-quality refactors / rev-2 doc fixes) | 3× grok-4.5 @ grok CLI + glm-5.2 @ pi-delegate | A ×3, B ×1 | 6–18m | B (glm docs): misdescribed the fold-drift check and repeated the overstatement the round existed to kill — semantics drift on secondhand code summaries; feed exact wording. | grok caught RUN_FAILURE→JOB_FAILURE via Dagster docs, the brief's own test miscount (12 vs 9), and STOPPED at an out-of-fence ci-config edit. |
| 2026-08-10 | JUS-2260 coverage adds + JUS-2273 review, 3 pkgs (injectivity tests / 8 pre-flight fixes + tests / 7-finding docs) | 3× grok-4.5 @ grok-delegate | A ×2, B ×1 | 9–35m | B (2273 pkg A): missed TWO integration tests pinning the old no-retry semantics — the brief forbade running that tier, so the brief blinded it. 2260 report tail truncated; re-ran all 163 tests myself, green. | Docs pkg rerouted from glm after two consecutive z.ai stalls — grok took the docs lane fine. Forbidden-tier assertions are the orchestrator's to enumerate. |
