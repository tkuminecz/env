# Steelmanning Guide

## What Is Steelmanning?

Steelmanning is the practice of presenting an opposing position in its *strongest, most charitable form* — the version its most sophisticated advocates would recognize as fair, even favorable. It is the opposite of strawmanning (misrepresenting a position to make it easier to defeat).

The goal is not to be fair for politeness reasons. The goal is strategic: a weak antithesis produces a trivial synthesis. The stronger the antithesis, the more valuable the synthesis.

## Anti-Strawman Checklist

Before finalizing any thesis or antithesis formulation, check each item:

- [ ] **Recognition test**: Would a committed advocate of this position recognize this as a fair representation? If not, strengthen it.
- [ ] **Principle test**: Have you identified the *underlying value* the position optimizes for, not just what it advocates? (e.g., "microservices" advocates often value *operational independence*, not microservices per se.)
- [ ] **Best-case test**: Are you presenting the position as it performs *under optimal conditions*, not worst-case or with incompetent execution?
- [ ] **Steel argument test**: Are the supporting arguments the *best* available, not the most common? Popular arguments are often not the strongest ones.
- [ ] **Honest weakness test**: Does the steelman acknowledge real tradeoffs? A position claiming no weaknesses is not a steelman — it's a caricature in the other direction.

## Common Strawman Patterns to Avoid

**Scope reduction**: Applying a general position only to narrow cases where it fails.
- Strawman: "Microservices are great, but only at Netflix scale."
- Steelman: "Microservices optimize for team autonomy and independent deployability. At *any* scale where multiple teams work on the same codebase, coordination costs accumulate — microservices make those costs explicit and manageable."

**Motive attribution**: Assigning bad motives to explain a position rather than engaging its logic.
- Strawman: "People advocate for remote work because they want to avoid accountability."
- Steelman: "Remote-first advocates argue that physical co-location is a proxy for trust, and that organizations that can't operate effectively asynchronously have underlying trust and process deficits that co-location merely masks."

**Cherry-picking failure cases**: Building the antithesis from the position's worst-case applications.

**False weakening**: Presenting a position in qualified, hedged language that its advocates don't use.

## Underlying Value Extraction

Before articulating arguments, identify the fundamental value the position optimizes for. This is the level at which synthesis becomes possible.

| Surface Position | Deeper Value |
|-----------------|--------------|
| "Use a monolith" | Simplicity of mental model; operational coherence |
| "Use microservices" | Team autonomy; independent deployability |
| "Move fast and break things" | Learning rate; optionality through iteration |
| "Move slowly and correctly" | Accumulated knowledge; trust; reversibility |
| "Centralize decisions" | Coherence; efficiency; alignment |
| "Decentralize decisions" | Speed; local knowledge; motivation |

The synthesis almost always operates at the level of underlying values, not surface positions.

## Steelman Template

```markdown
## [Position Name]: [One-sentence core claim]

**Underlying Value:** [What this position fundamentally optimizes for]

**Best Arguments:**
1. [Most sophisticated structural argument — not the most common]
2. [Empirical or historical argument — specific evidence, not vibes]
3. [Argument that addresses the hardest objection to this position]

**What This Position Sacrifices:**
[2-3 sentences on genuine tradeoffs the position accepts. Frame as intentional tradeoffs, not failures.]

**What Would Change This View:**
[What evidence or argument would genuinely update this position — stated as a claim about evidence standards, not a concession]
```
