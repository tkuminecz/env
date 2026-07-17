## Dialectic Context Briefing

**Stated tension:** PR #888 introduces a full pipeline orchestration framework (step declarations, typed bindings, input projection, serde, SDK package) to solve what was originally "remove 3 namespace branch points and unify 2 tables" — is this the right level of abstraction or are we re-implementing Dagster inside Restate?

**Underlying question:** When you already have two orchestration engines (Restate for durable execution, Dagster for batch/ETL), what's the right amount of custom orchestration logic to build on top? Where does "policy-as-config" end and "homegrown workflow engine" begin?

**User's dominant position:** Lean reject. The abstraction weight (AtomicStep, CompositeStep, Wired, projection paths, pipeline serde, step schemas) exceeds the problem's complexity for 2-3 namespaces. The SDK placement implies cross-platform generality that isn't earned by a single consumer.

**Hardest counter they acknowledge:** The original problem is real — ad-hoc branching per namespace is genuinely bad, and unifying the DB schema is the right call. The direction of "less special-case code" is correct.

**Shared assumptions to interrogate:**
- That "policy-as-config" necessarily requires a framework (vs. just being clean code organization)
- That Restate's native composition primitives are insufficient for sequential step dispatch
- That typed input/output contracts between steps require a custom projection/binding system
- That pipeline definition snapshots are needed (vs. just versioning the code)

**Domain:** Technical architecture — specifically, abstraction level selection for infrastructure code

**Stakes:** This PR sets architectural precedent for how Legal Lake (and potentially other domains) model multi-step workflows. If over-abstracted, it becomes a maintenance burden and a framework the team has to learn. If under-abstracted, the namespace branching problem returns with each new namespace.
