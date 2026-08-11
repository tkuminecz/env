---
name: dream
description: "Codebase dreaming: fan out unmetered external agents (grok, glm, optionally deepseek) over a domain or subdomain to hunt for improvement opportunities — code smells, sloppy code, useless tests, DRY violations, performance wins, simplification. Read-only exploration, duplicated across models for varying perspectives, synthesized into a verified findings report. Use when Tim says /dream, \"dream on <area>\", \"send agents to look for cleanup opportunities in X\", or wants an open-ended quality sweep of part of the codebase with no specific bug in mind."
---

# Dreaming: open-ended improvement sweeps via external delegates

Send flat-rate external models (grok-4.5, glm-5.2; deepseek as trial lane) wandering
through a domain of the codebase looking for anything worth improving. Unlike `/delegate`
(execution of a known spec) or `/code-review` (a diff), dreaming has **no diff and no
spec** — the deliverable is a triaged, Claude-verified report of opportunities, especially
ones that **simplify the code and make it easier to understand**.

**First: read LESSONS.md in this skill's directory in full** — it holds the traps
previous runs hit. Apply them; don't rediscover them.

Load the `delegate` skill alongside this one — all launch mechanics (pi-delegate flags,
watchdog, stagger rules, provider pools) come from there and are not repeated here.

## Ground rules

- **Read-only.** Delegates must not edit the repo. Each brief fences: "Do not modify any
  file in the repository. Your only output is your report file at <abs path>." Verify with
  `git status` after the round; any dirt gets discarded and noted in LOG.md.
- **Findings are claims.** A delegate citing `file:line` may be paraphrasing or
  hallucinating. Nothing reaches Tim's report unverified (step 4).
- **Duplication is the point.** Sending grok AND glm at the same subarea is cheap and
  yields different perspectives. Cross-model agreement on a finding is the strongest
  quality signal this skill has.
- Marginal cost is ~zero for grok/glm, so err toward more agents, not fewer — bounded
  only by the stagger rules (2–3 concurrent per provider, `-W 10`).

## Procedure

### 1. Scope and carve

Take the target ("legal-lake ingestion", "rate-review frontend", a path). Map it with a
quick `ls`/glob — no deep reading. Then find the **hot spots**: run
`git log --oneline --since='6 months ago' -- <target>` piped through a path-frequency
count — files that keep changing are where an improvement pays off; a smell in code
nobody touches is worth less. If Tim named no subdomain, let the hot spots pick the
subareas. Check `.claude/skills/dream/REJECTED.md` (if it exists) for findings already
declined in past rounds — pass the relevant entries into the briefs as "do not
re-suggest". Carve into **2–5 subareas** along directory/package lines, each small enough to actually read (a few dozen files; glm's 1M ctx tolerates
bigger sweep-style subareas, grok's 500K wants tighter ones). List the subareas and
lens-assignments to Tim in one short block, then launch — don't wait for approval unless
the target itself was ambiguous.

### 2. Write briefs

One brief file per (subarea × model) in the scratchpad. Template:

```
You are exploring part of a codebase looking for improvement opportunities. You are
one of several independent explorers; be opinionated and specific.

READ-ONLY: do not modify, create, or delete any file in the repository. Your only
output is the report file described below.

Area: <abs paths of the subarea>
Also read: the nearest AGENTS.md files above the area, for local conventions.

Look for (in rough priority order):
1. Simplification — code that could be shorter, flatter, or clearer with equal
   behavior; needless indirection; over-abstraction; dead configuration knobs.
   Apply the deletion test to any suspect abstraction: if deleting a wrapper,
   helper, or layer would CONCENTRATE complexity into one obvious place rather
   than just relocate it, that deletion is a finding. Shallow modules — an
   interface nearly as complex as its implementation — are prime targets.
2. DRY violations — real duplicated logic (not incidental similarity).
3. Dead code — unreachable branches, unused exports/functions/fixtures, stale flags.
4. Useless tests — construct-and-assert-fields tests, mocks that return the value
   the assertion repeats, call-count wiring tests, tests that can't fail.
5. Code smells / sloppiness — misleading names, lying comments, inconsistent
   patterns vs. the surrounding code, error handling that swallows or lies.
6. Performance — N+1 queries, per-row work that should batch, quadratic scans,
   queries into paginated joins.

Do NOT report: style nits a formatter would catch, security findings (separate
process), speculative rewrites ("use library X"), or anything requiring a schema
or API contract change.

For each finding, write into the report file (markdown):
- **Title** (one line)
- Category: simplify | dry | dead-code | useless-test | smell | perf
- Location: exact file path(s) and line numbers — quote 1-3 of the actual lines
  so the finding is checkable
- Why it matters (1-3 sentences, plain English)
- Sketch of the fix and rough effort (S/M/L)
- Confidence: high | medium | low

Write the report to: <abs scratchpad path>/findings-<subarea>-<model>.md
Aim for your best 5-15 findings, quality over quantity. End the report with a
"What I'd simplify first" paragraph: if you could make one change to make this
area easier to understand, what would it be?
```

The "quote the actual lines" requirement is load-bearing — it makes step 4 cheap and
hallucinated findings self-evident.

### 3. Fan out

- Default pairing: **every subarea gets grok-4.5 AND glm-5.2** with the identical brief
  (separate brief files only because the report path differs).
- Optionally add **deepseek-v4-flash-0731** on 1–2 subareas as the trial lane (it's
  pay-per-token — cheap, not free; don't make it a full third column without asking).
- Launch per delegate-skill rules: `pi-delegate -C <repo-root> -m <model> -f <brief>`
  with `run_in_background`, max 2–3 concurrent per provider, `-W 10`, release the next
  brief as slots free. Grok concurrency via grok CLI if pi-grok is stalling that day.
- While they run, do NOT sit idle: skim the subareas yourself and note your own top 3
  candidate findings before reading any report — this is your prior for judging theirs.

### 4. Synthesize and verify

1. Collect all report files; note any delegate that died or wrote nothing (re-run or
   drop, don't fabricate).
2. Merge findings across models per subarea. Tag each: **both-models** / grok-only /
   glm-only / deepseek-only.
3. **Verify before reporting**: for every finding you'd surface, open the cited
   file:line and confirm the quoted code exists and the claim holds. Kill findings that
   don't check out; downgrade paraphrase-drift ones. Both-models agreement lowers the
   verification bar, never removes it.
4. Rank by (leverage for understandability) × (confidence) ÷ (effort). Simplifications
   that delete code outrank everything at equal confidence.

### 5. Report to Tim

The deliverable is a **Claude Artifact** — a published page Tim reviews in the browser.
Load the `artifact-design` skill first, write the report as HTML in the scratchpad, and
publish with the Artifact tool (favicon `💤`, keep it stable; one artifact per dream
round — redeploy the same file path for revisions). Design notes: findings as cards
with category/effort/confidence badges and the quoted code lines in `<pre>` blocks;
for the top structural findings, a small before/after mermaid diagram
(`<pre class="mermaid">` renders natively — no CDNs, which the CSP blocks anyway).
Theme-aware per the Artifact tool's rules. Also drop a plain-markdown copy in the
scratchpad, and give the artifact URL in the chat reply. Report structure:

- **TLDR** — 2-4 sentences: the area's overall health and the top 2-3 opportunities.
- **Do now** (≤5 items) vs **Later** — each item: title, location, why, effort,
  which models found it.
- **Dropped in verification** — one line each, so the models' error rate stays visible.
- **Dream themes** — the "what I'd simplify first" answers, merged: recurring
  structural observations that aren't single findings.

Then offer, don't do: open Linear tickets for keepers, and/or spawn fix delegates for
the S-effort verified items (that's a normal `/delegate` round — new briefs, edits
allowed, tests required). No code changes happen inside a dream round.

**Record rejections.** When Tim declines a verified finding for a load-bearing reason
("intentional — Restate wire-name compat", "duplication is deliberate, the two will
diverge"), append one line to `.claude/skills/dream/REJECTED.md`:
`- <area> | <finding title> | <reason> | <date>`. Skip ephemeral reasons ("not now").
This is what keeps repeat dreams over the same domain from re-pitching the same ideas.

### 6. Log

Append one row per delegate to the delegate skill's `LOG.md` (grade the *report
quality*: verified-finding hit rate is the score). Note model-vs-model differences —
that record is what tunes the pairing over time.

## Run note — always, last

Append a run note to `~/.claude/pipeline-runs/<YYYYMMDD>-<context>-dream.md`
(5 lines max): what tripped, any correction Tim made mid-run, and lesson candidates for
/tim-skill-gardener. Nothing tripped → one line saying so. This is a record, not a rule
change — never edit LESSONS.md directly.
