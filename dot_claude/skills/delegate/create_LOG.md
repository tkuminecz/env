# Delegation scorecard

<!-- retro-state: last=2026-07-27 rows_since=1 -->

One row per delegated task, appended when its pipeline finishes. Grades: **A** merged as-is · **B** merged after minor fixes · **C** needed major rework · **F** discarded/redone by hand. Review col = findings the builder's own verification missed.

Retro fires at `rows_since` = 5, or 14 days past `last` with at least one new row — see SKILL.md
"Retro". Bump `rows_since` with every row you append; reset both fields when a retro runs.

| date | task | model @ harness | grade | time | review findings | notes |
|---|---|---|---|---|---|---|
| 2026-07-25 | token-bucket rate limiter + pytest suite (A/B test) | grok-4.5 @ pi | A | 34s | none | declared 3 honest deviations incl. guarding negative token cost; dodged IEEE-float test trap unprompted |
| 2026-07-25 | token-bucket rate limiter + pytest suite (A/B test) | grok-4.5 @ grok CLI | B | 40s | negative-cost hole: `allow(-100)` inflates bucket past capacity, all 7 self-written tests green | same model, different judgment call on input validation; declared "no deviations" accurately per spec |
| 2026-07-27 | 12-case bash test suite for the new `pi-delegate` wrapper (first real, non-A/B delegation) | grok-4.5 @ pi | B | 77s | mutation testing found the suite couldn't detect the prompt being dropped from the inline-task path — only the `--file` path was covered, i.e. the wrapper's core job was untested. Added case 13. | Brief delivered via `-f`. Followed scope exactly, touched nothing outside its one file, cleaned up its temp files, correctly reported "no wrapper bugs" rather than inventing some. All 4 declared deviations accurate and sensible (quoting-aware assertions, `--mode` vs `--model` prefix collision). Two nits I fixed after: wrote temp files into its own dir, and an inner `trap ... EXIT` that would clobber a suite-wide one. |

## Distilled patterns

(Promote observations here once rows repeat them; fold stable ones into SKILL.md's routing table and prune the raw rows they came from.)

- n=2, same model on both harnesses: harness choice didn't affect speed or quality; feature set (schema output, sandbox vs GLM access) is the real differentiator.
- Green self-written tests + self-review PASS still shipped an input-validation hole — consistent with the coworker's ~10-package calibration that independent review is non-optional.
- **Mutation-test delegated test suites** (n=1, but it paid immediately). When the deliverable is tests, "all cases pass" is nearly content-free — the delegate wrote the tests *and* the thing that makes them pass. Break the code under test 3–4 ways and confirm the suite goes red; that is what surfaced the uncovered path here. Cheap: one loop, seconds.
- Watch for **coverage that clusters on the path the brief described most vividly**. The brief spelled out the `--file` absolute-path case in detail and got thorough coverage there, while the plainer inline-task path — mentioned only in passing — went untested. Enumerate the boring paths explicitly in briefs.
