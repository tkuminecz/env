---
name: dialectical-reasoning
description: Applies a structured dialectical method (thesis → antithesis → synthesis) to any problem, decision, or argument. Use when the user wants to stress-test a position, resolve a genuine tension between two views, escape a false dichotomy, make a high-stakes decision with unclear tradeoffs, or build a deeper mental model of a domain. Trigger phrases: "thesis-antithesis-synthesis", "steelman", "devil's advocate", "stress-test this idea", "both sides", "Hegelian dialectic", "false dichotomy", "resolve the tension", "what am I missing", "argue against me".
allowed-tools: "Read,Write,Task"
version: 1.0.0
---

# Dialectical Reasoning Skill

A structured method for advancing understanding through productive contradiction. Works by committing to opposing positions at full strength, then synthesizing a higher-order understanding that neither side alone could produce.

## Philosophical Grounding

This skill implements three nested frameworks. Read them before executing — they determine *how* you reason, not merely *why*.

**Hegel — Determinate Negation:** The goal is not compromise. *Aufhebung* (sublation) simultaneously cancels, preserves, and elevates both positions. The antithesis must identify the specific failure mode of the thesis — "wrong in this particular way" — because that specificity is a signpost pointing toward what's missing. A synthesis that could have been proposed by either side without dialectical work is a failure. The synthesis should make the original contradiction feel *inevitable* in retrospect.

**Socratic Elenchus — Examine Assumptions:** Before positions are formulated, hidden premises must be surfaced. Most intellectual stuck-points are not disagreements about conclusions — they are disagreements about unstated assumptions both sides share. The interview phase exists to surface these.

**Boyd — Creative Induction:** You cannot synthesize genuinely new understanding by recombining ideas within a single frame. After the antithesis is established, decompose both positions into atomic claims stripped of their original framing. Then cross-domain connections become visible. This is not optional — Gödel proves you cannot verify a closed system from within it, and any inward-only refinement increases conceptual entropy.

**Anti-sycophancy rule:** The dialectic's value comes from full commitment to each position. Hedging, false balance, or rushing to synthesis destroys the method. Hold tension open as long as it is productive.

---

## When to Use

**Use when:**
- User wants to stress-test a position against the strongest possible counter
- User is genuinely torn between two paths and the tension feels real, not just a preference
- A decision has real stakes and tradeoffs are unclear
- User wants to build a deeper model of a domain, not just pick an answer
- Two design/architecture/strategy positions are in conflict with legitimate arguments on both sides

**Do NOT use when:**
- The question has a straightforwardly correct empirical answer
- One side is obviously correct and the "tension" is not genuine
- User wants a quick recommendation — use direct analysis instead
- Time constraints make multi-phase dialectical work impractical

---

## Phases Overview

```
Phase 1: Elenctic Interview     — Surface the real question and hidden assumptions
Phase 2: Thesis Formulation     — State the strongest version of Position A
Phase 3: Antithesis Formulation — State the strongest version of Position B  
Phase 4: Determinate Negation   — Identify specific failure modes of each; decompose to atoms
Phase 5: Synthesis (Aufhebung)  — Produce something neither side could alone
Phase 6: Validation             — Test synthesis against each position's strongest objection
Phase 7: Recursion (Optional)   — Use synthesis as new thesis; recurse if depth needed
```

---

## Phase 1: Elenctic Interview

Goal: Surface the real question, hidden assumptions, and the user's belief burden before any positions are formed.

**Execute:**

1. Ask the user to state the tension or decision in one sentence.
2. Ask: *"What would you believe if you were forced to pick a side right now?"* (This reveals the dominant position — the belief burden.)
3. Ask: *"What's the strongest argument against that position that you find hardest to dismiss?"*
4. Ask: *"What hidden assumption do both sides of this debate share that might be wrong?"*
5. Identify the underlying question beneath the stated question — often the stated tension is a proxy for a deeper one. Name it explicitly and confirm with the user.
6. Write a context briefing to `{baseDir}/tmp/context-briefing.md` before proceeding.

**Context briefing structure:**
```
## Dialectic Context Briefing
**Stated tension:** [one sentence]
**Underlying question:** [the deeper question this proxies]
**User's dominant position:** [what they lean toward and why]
**Hardest counter they acknowledge:** [their own best antithesis]
**Shared assumptions to interrogate:** [premises both sides accept uncritically]
**Domain:** [technical / strategic / philosophical / personal / policy]
**Stakes:** [what is actually at risk in the decision]
```

---

## Phase 2: Thesis Formulation

Goal: Produce the strongest possible version of Position A — the position the user leans toward or the conventional view.

**Read `{baseDir}/references/steelmanning-guide.md` before executing.**

**Requirements:**
- State the core claim in one sentence.
- Identify the underlying *value* or *principle* the position optimizes for (not just what it advocates).
- Present the three strongest supporting arguments — not the most common arguments, the *best* ones.
- Acknowledge what the thesis *sacrifices* or gets wrong at the margins. A steelman that claims no weaknesses is a strawman.
- Use imperative framing: argue as if you *believe* this position, not as if you are reporting on it.

**Output format:**
```markdown
## Thesis: [one-sentence claim]

**Core Principle:** [what value this position fundamentally optimizes for]

**Strongest Arguments:**
1. [Argument A — specific, not generic]
2. [Argument B — structural, not anecdotal]  
3. [Argument C — addresses the hardest counterexample]

**What This View Sacrifices:**
[Honest acknowledgment of real costs — 2-3 sentences]
```

---

## Phase 3: Antithesis Formulation

Goal: Produce the strongest possible version of Position B — a genuine negation, not a weak counter.

**Requirements:**
- The antithesis must negate the thesis's *core principle*, not just its surface conclusions. Attacking a conclusion while sharing the same underlying framework is not a real antithesis.
- Apply the same steelmanning rigor as Phase 2.
- If spawning a subagent via `Task` for the antithesis: instruct the subagent to believe its position fully — no hedging, no false balance, no acknowledgment of the thesis as a valid alternative. The subagent is an advocate, not a judge.
- Decor relation check: does the antithesis genuinely use a *different framework* from the thesis, or does it just reach a different conclusion using the same framework? If the latter, revise.

**Subagent prompt template (if using Task):**
```
You are arguing that [ANTITHESIS POSITION] with full conviction. Your job is to produce
the strongest possible case for this view. Do not hedge. Do not concede that the
opposing view has merit — your task is to be a fully committed advocate, not a balanced 
analyst. The user will handle balance. You handle belief.

Context: [paste context briefing]

Produce: core claim, underlying principle, three strongest arguments, what you'd need to 
see to change your mind (this is NOT a concession — it's a claim about evidence standards).
```

**Output format:** Mirror Phase 2 format.

---

## Phase 4: Determinate Negation

Goal: Identify the *specific failure mode* of each position — not "it's wrong" but "wrong in this particular way, pointing here."

**You perform this phase yourself (do not delegate to subagents).**

**Read `{baseDir}/references/negation-guide.md` before executing.**

**Step 4.1 — Internal tensions:**
Where does each position's own logic undermine itself? Find the place where the thesis's reasoning, if taken to its logical conclusion, produces a result the thesis itself rejects. Do the same for the antithesis. These are the productive contradictions.

**Step 4.2 — Shared assumptions:**
What premise do *both* positions accept without questioning? This shared premise is often the actual site of the error. Surfacing it frequently dissolves the apparent contradiction.

**Step 4.3 — Boydian decomposition:**
Shatter both positions into atomic claims. Strip each claim from its source position. List 10-15 atomic claims from Thesis and 10-15 from Antithesis. These are now freed from their frameworks.

Then: scan for cross-domain isomorphisms. Do any atomic claims from Thesis connect to atomic claims from Antithesis in unexpected ways — not to resolve them, but because they are describing the *same underlying structure* from different angles?

**Step 4.4 — Determinate negation statement:**
Complete this template:
```
The thesis fails because: [specific failure mode, not just "it's wrong"]
The antithesis fails because: [specific failure mode]
Both positions fail because they share the assumption that: [shared premise]
The real question is therefore: [reframed question]
```

**HARD STOP:** Present Phase 4 analysis to the user before proceeding to Phase 5. 
Ask: *"Does this decomposition capture the tension correctly? Is there a domain, example, or piece of evidence neither side considered?"*

---

## Phase 5: Synthesis (Aufhebung)

Goal: Produce a synthesis that cancels both positions as complete truths, preserves the genuine insight in each, and elevates to something neither could produce alone.

**Read `{baseDir}/references/synthesis-guide.md` before executing.**

**Requirements:**
- The synthesis must make the original contradiction feel *predictable in retrospect* — as if it were a necessary consequence of a deeper structure now made visible.
- **Reversibility check (Boyd):** trace each claim in the synthesis back to specific atomic parts from Phase 4.3. Any claim that cannot be traced needs scrutiny — it may be an unexamined assumption smuggled in.
- **Compromise failure check:** If the synthesis could be paraphrased as "a bit of A and a bit of B," it is not an Aufhebung. Revision required.
- **Level check:** The synthesis should operate at a *higher* level of abstraction than both positions — not by escaping the tension but by reframing what the tension is about.

**Common synthesis patterns (see `{baseDir}/references/synthesis-guide.md` for full catalog):**

| Pattern | Structure | Use When |
|---------|-----------|----------|
| Temporal | Do A then B, sequenced by lifecycle stage | Positions optimize for different phases |
| Conditional | A in context X, B in context Y | Positions are optimal under different constraints |
| Dimensional | Optimize A on one axis, B on another orthogonal axis | The tradeoff is false — both achievable on separate dimensions |
| Higher-Order | Both A and B are means to the same deeper end; find better means | Positions are tactics, not ends |
| Compensating | Lean toward A; use B's principle as a guardrail | One position is correct for primary goal; the other provides risk mitigation |

**Output format:**
```markdown
## Synthesis: [one-sentence claim at higher level of abstraction]

**What this preserves from the Thesis:** [specific insight, not just "the good parts"]
**What this preserves from the Antithesis:** [specific insight]
**What this cancels from both:** [the shared false premise or framing]
**The reframed question:** [the question the synthesis answers, which is different from the original question]
**New tradeoffs introduced:** [what the synthesis sacrifices that both prior positions avoided — honest accounting]
**Reversibility trace:** [one sentence per synthesis claim, tracing it to atomic parts]
```

---

## Phase 6: Validation

Goal: Test whether the synthesis survives adversarial scrutiny.

**Adversarial check — run one or both:**

**Option A — Monk Validation (via Task):**
Send the synthesis summary to a fresh subagent instructed to argue as the hardest-hit position. Prompt:
```
You are a committed advocate of [THESIS/ANTITHESIS]. You have just read the following 
synthesis: [synthesis]. Your task: identify every way this synthesis either (a) 
covertly adopts your opponent's framing rather than genuinely transcending it, or 
(b) loses the genuine insight your position contained. Be maximally adversarial.
```

**Option B — Hostile Auditor (via Task):**
Fresh subagent, no prior context, strongest available model. Prompt:
```
Audit this synthesis for logical failures: [synthesis + atomic decomposition from Phase 4.3].
Check: (1) Does each synthesis claim trace to the atomic parts? (2) Is this synthesis 
actually a compromise in disguise? (3) What hidden assumption does the synthesis itself 
smuggle in? (4) What does it fail to account for?
```

**Sustained juxtaposition test:**
Sometimes refusing to synthesize is the right move. Ask: is the contradiction more *productive held open* than resolved? If both positions contain genuine insight that a synthesis would flatten, present them as a productive tension with explicit framing rather than forcing a premature resolution.

**Refinement:** Present validation findings to user one at a time (not as a list). Revise synthesis for each accepted critique before moving to Phase 7.

---

## Phase 7: Recursion (Optional)

Use the synthesis as the new thesis and recurse if:
- The synthesis opened new questions that weren't visible before
- The user wants deeper analysis
- The synthesis feels incomplete — productive but not yet fully realized

**Before proposing recursion directions:**
Generate 5-8 candidate directions first (internal — do not show the user). Then cluster into 2-4 proposed directions. This prevents predictable/obvious recursion choices.

Track the dialectic queue in `{baseDir}/tmp/dialectic-queue.md`:
```markdown
## Dialectic Queue
**Completed rounds:** [N]
**Current synthesis:** [one sentence]
**Candidate next directions:**
- [Direction 1]
- [Direction 2]
- [Direction 3]
```

---

## Quick-Start Mode

For lower-stakes use or when the user explicitly wants faster output, collapse to three phases:

**Phase Q1 — Frame:** In 2-3 exchanges, establish the thesis and antithesis positions. Skip deep interview.
**Phase Q2 — Steelman both:** Apply Phase 2 and Phase 3 rigor, but in one pass each. No subagents.
**Phase Q3 — Synthesis:** Apply Phase 5 directly. Skip validation unless user requests it.

**Signal to use Quick-Start:** User says "quickly", "briefly", "rough sketch", or the domain has low stakes.

---

## Domain Calibrations

Apply these calibrations by domain before executing phases:

**Technical architecture decisions (e.g., monolith vs. microservices, Kafka vs. Pub/Sub):**
- Thesis/antithesis must be grounded in specific operational constraints, not abstract principles
- Shared assumptions to interrogate: scale assumptions, team structure assumptions, operational maturity assumptions
- Synthesis often lives in the temporal or conditional pattern: "right now vs. at scale" or "for this team vs. a different team"
- See `{baseDir}/references/domain-technical.md`

**Strategic / product decisions (e.g., build vs. buy, growth vs. profitability):**
- Frame around principal values (speed, optionality, unit economics, market position)
- Synthesis often reframes the goal, not the tactics
- Validate against specific customer/market evidence, not abstract reasoning
- See `{baseDir}/references/domain-strategic.md`

**Philosophical / first-principles questions:**
- Full seven-phase process recommended
- Subagent monks work well here — deep belief commitment produces better output
- Cross-domain analogies are high-value in Phase 4.3 Boydian decomposition

**Personal decisions (career, tradeoffs, commitments):**
- Phase 1 interview is critical — the real question is almost always different from the stated question
- Apply Belief Burden Catalog (see `{baseDir}/references/belief-burden-catalog.md`)
- Synthesis frequently involves *reframing the stakes*, not picking between options

---

## Files

- `references/steelmanning-guide.md` — Full steelmanning methodology and anti-strawman checklist
- `references/negation-guide.md` — Determinate negation, internal tensions, Boydian decomposition  
- `references/synthesis-guide.md` — Complete synthesis pattern catalog with examples
- `references/belief-burden-catalog.md` — Cognitive style patterns and belief burden calibration
- `references/domain-technical.md` — Technical architecture calibration guide
- `references/domain-strategic.md` — Strategic decision calibration guide
- `tmp/` — Working files (context-briefing.md, dialectic-queue.md) — created at runtime

---

## Anti-Patterns (Do Not Do These)

- **Rushing to synthesis** — The antithesis phase must be fully committed before you move on. Premature synthesis is just the thesis wearing a moderate costume.
- **Symmetric hedging** — "Both sides have valid points" is not analysis. It's what you produce *instead of* analysis.
- **Strawmanning the antithesis** — If the antithesis is weak, the synthesis is trivial. Make each position as strong as possible.
- **Sycophantic synthesis** — Do not locate the user's implicit preference and converge on it. The synthesis should sometimes surprise the user.
- **Dissolving upward** — Do not resolve tension by moving to a higher abstraction so general that it says nothing. ("The real answer is: it depends on context." This is not a synthesis.)
- **Compromise disguised as synthesis** — 50% A + 50% B is a weighted average, not an Aufhebung.
