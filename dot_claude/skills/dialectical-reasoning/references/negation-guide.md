# Determinate Negation Guide

## What Is Determinate Negation?

In Hegel's dialectic, negation is not simply "this is wrong." That is *abstract* negation — it cancels a position but provides no direction. *Determinate* negation identifies **the specific way** a position fails — and that specificity is a signpost pointing toward what's missing.

"The thesis is wrong because it ignores X" — where X is precisely the element the synthesis must incorporate.

## Internal Tension Analysis

The most productive contradictions come from within a position's own logic.

**Method:** Ask of each position — "If I take this position's reasoning to its logical conclusion, what result does it produce that the position itself would reject?"

**Examples:**

*"Move fast and break things" taken to its logical conclusion:* 
→ Speed without feedback loops produces accumulated technical debt so severe it eliminates the very optionality that speed was supposed to create. The position undermines its own goal.

*"Design everything upfront" taken to its logical conclusion:*
→ Perfect upfront design requires knowing requirements that can only be discovered through implementation. The position requires knowledge it cannot have until you do the thing it says you should complete before starting.

Both internal tensions point toward the synthesis: **feedback-driven iteration with explicit constraint management** — fast where feedback is available, deliberate where it isn't.

## Shared Assumption Excavation

The deepest interventions attack *premises both positions share* — not the conclusions where they differ.

**Method:** Ask — "What must both sides believe for this debate to make sense in the form it's taken?"

**Example:** The monolith vs. microservices debate often shares the assumption that *the team structure is fixed and external to the architecture decision*. Challenge that: Conway's Law suggests causation runs both ways. The shared assumption, once visible, frequently dissolves the apparent dilemma.

**Shared assumption types to look for:**
- Temporal assumptions (both sides assume the current conditions persist)
- Scale assumptions (both sides reason about the same scale)
- Team/organization assumptions (both assume the same org structure)
- Resource assumptions (both assume the same constraint set)
- Goal assumptions (both assume the same success metric)

## Boydian Decomposition

Boyd's insight: **you cannot synthesize genuinely new understanding within a single conceptual framework.** Creative induction requires first shattering existing wholes into atoms, then finding cross-domain connections among the atoms.

**Step 1 — Destructive Deduction:**
Extract 10-15 atomic claims from the Thesis and 10-15 from the Antithesis. Strip each claim from its source position. The atoms should be as simple as possible — one claim per item. Do not include the framing or the source position.

**Example atoms from a "monolith vs microservices" dialectic:**
```
From Thesis (monolith side):
- Shared memory is faster than network calls
- A single deployable unit has simpler operational requirements
- Debugging across a single process is tractable
- Schema migration is coordinated in a single codebase
- Team onboarding is easier with one service to understand

From Antithesis (microservices side):
- Independent deployability decouples team release cycles
- Service boundaries enforce interface contracts
- Failure isolation prevents cascading failures
- Services can be scaled independently
- Technology heterogeneity becomes possible at service boundaries
```

**Step 2 — Cross-Domain Injection:**
Look for structural isomorphisms between atoms from *different* positions. Look for analogies in unrelated domains (biological systems, city planning, legal systems, manufacturing). Cross-domain connections are the raw material of synthesis.

**Step 3 — Synthesis material:**
List 3-5 cross-domain connections or structural isomorphisms that weren't visible before decomposition.

## Determinate Negation Statement Template

Complete this before proceeding to Phase 5:

```markdown
## Determinate Negation Analysis

**The Thesis specifically fails because:**
[One specific failure mode — not "it's wrong" but "wrong in this way, pointing here"]

**The Antithesis specifically fails because:**
[One specific failure mode — pointing in the same direction from the other side]

**Both positions share the hidden assumption that:**
[The unexamined premise both accept — this is the real site of the error]

**The real question is therefore:**
[The reframed question that the shared assumption was preventing both sides from asking]

**Atomic decomposition cross-connections:**
- [Connection 1: Atom X from Thesis ↔ Atom Y from Antithesis]
- [Connection 2]
- [Connection 3]

**Candidate synthesis direction:**
[One sentence — the direction the decomposition points toward. This is a starting point for Phase 5, not the synthesis itself.]
```
