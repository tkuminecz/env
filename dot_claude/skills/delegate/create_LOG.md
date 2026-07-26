# Delegation scorecard

One row per delegated task, appended when its pipeline finishes. Grades: **A** merged as-is · **B** merged after minor fixes · **C** needed major rework · **F** discarded/redone by hand. Review col = findings the builder's own verification missed.

| date | task | model @ harness | grade | time | review findings | notes |
|---|---|---|---|---|---|---|
| 2026-07-25 | token-bucket rate limiter + pytest suite (A/B test) | grok-4.5 @ pi | A | 34s | none | declared 3 honest deviations incl. guarding negative token cost; dodged IEEE-float test trap unprompted |
| 2026-07-25 | token-bucket rate limiter + pytest suite (A/B test) | grok-4.5 @ grok CLI | B | 40s | negative-cost hole: `allow(-100)` inflates bucket past capacity, all 7 self-written tests green | same model, different judgment call on input validation; declared "no deviations" accurately per spec |

## Distilled patterns

(Promote observations here once rows repeat them; fold stable ones into SKILL.md's routing table and prune the raw rows they came from.)

- n=2, same model on both harnesses: harness choice didn't affect speed or quality; feature set (schema output, sandbox vs GLM access) is the real differentiator.
- Green self-written tests + self-review PASS still shipped an input-validation hole — consistent with the coworker's ~10-package calibration that independent review is non-optional.
