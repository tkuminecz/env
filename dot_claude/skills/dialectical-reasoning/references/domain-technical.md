# Technical Architecture Domain Calibration

## When the Domain Is Technical Architecture

Technical architecture decisions have unique properties that require calibration:

1. **Constraints are real and specific.** Abstract principles ("simplicity is good") mean nothing without concrete operational context. Thesis and Antithesis must be grounded in specific constraints: team size, current scale, operational maturity, existing tech debt, deployment frequency.

2. **The right answer changes over time.** Most architecture debates are actually debates about *timing*. "Are microservices right?" is almost always a proxy for "are microservices right *now*, for *this team*, at *this scale*?"

3. **Conway's Law is almost always a shared assumption to interrogate.** "The architecture decision is constrained by team structure" is often treated as a given. Challenge it: the decision can also *shape* team structure.

4. **The synthesis is often operational, not architectural.** The best synthesis frequently isn't a new architecture pattern — it's a *process* or *decision criterion* for when to apply each approach.

## Specific Shared Assumptions to Interrogate

For most technical debates, probe these:

**Scale assumption:** "We need to design for [scale]." Are both sides assuming the same scale? Is the assumed scale correct? What's the cost of premature scale optimization?

**Team structure assumption:** "Given that we have N teams working on this..." Is team structure actually fixed? Would a different architecture support a different, more effective team structure?

**Reversibility assumption:** "Once we choose X, we're committed." Is this actually true? What is the real cost of changing direction later? Irreversibility is often overstated.

**Operational maturity assumption:** "We have [level] of operational capability." Both sides often assume current capability is fixed. Synthesis sometimes involves a capability investment that enables a third path.

**Codebase state assumption:** "Given our existing codebase..." Both sides often treat current technical debt as a constraint. Sometimes the synthesis is: "This decision can't be made without addressing [specific debt] first."

## Common Technical Synthesis Patterns

**The Migration Path Synthesis:**
Neither architecture is the destination — one is the current state and one is the target. The synthesis is: "Start with [A]. Migrate to [B] when [specific trigger]. Here's the incremental path."

**The Seam Synthesis:**
Both architectures can coexist at a boundary. The synthesis identifies *where* to place the seam between them and what interface contracts it requires.

**The Capability Investment Synthesis:**
Both positions are correct *given certain capabilities*. The synthesis is: "Invest in [capability]. With that capability in place, [approach] becomes viable."

**The Reversibility Synthesis:**
"Design for X now, make the migration to Y cheap." If reversibility is low-cost, the apparent commitment to one approach dissolves.

## Example: Kafka vs Pub/Sub for Event Streaming

**Typical thesis:** Kafka — full control over partitioning, replay semantics, high throughput, exact-once delivery with careful implementation.

**Typical antithesis:** Pub/Sub — fully managed, scales automatically, integrates with GCP ecosystem, lower operational overhead for typical event-driven patterns.

**Common shared assumptions to interrogate:**
- "We know what our throughput requirements are" (often untrue early)
- "Our team has Kafka operational expertise" (or will acquire it)
- "The GCP vendor lock-in cost is/isn't acceptable"

**Typical synthesis direction:**
Start with Pub/Sub for its operational simplicity. The migration trigger to Kafka is: (1) replay semantics beyond 7-day Pub/Sub retention become required, (2) consumer group coordination semantics are needed, or (3) throughput exceeds managed service limits. Design event schemas to be broker-agnostic from day one using CloudEvents or similar standard.

## Common Anti-Patterns in Technical Dialectics

**Resume-driven architecture:** Both positions are "what the architect wants to work with" rather than "what the system needs." Interrogate the proposer's implicit incentives.

**Scale-of-the-day decisions:** Designing for the scale described in a blog post, not the actual scale of the system. Both positions often project the wrong scale.

**Analysis paralysis disguised as rigor:** The dialectic is being used to delay a decision, not make a better one. Signal: no proposed synthesis is ever "good enough." If this is happening, the synthesis should be: "Here's the decision criterion. Use it."
