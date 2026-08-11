# General rules

Plain, simple English is a hard default for everything you write — chat replies, PR descriptions, ticket bodies, review summaries — not a mode to switch into on request. Lead every explanation with a few sentences stating the problem, why it matters, and what to do — then give the full technical detail. Plainness means cutting jargon and coined phrases, not cutting substance or precision. Avoid coined shorthand and repo-invented jargon entirely; if a term is unavoidable, its definition ships in the same block as every usage, never defined once far away. (Inspiration: ASD-STE100 — one topic per sentence, active voice, common words — without following it rigidly.) When asked to simplify, reduce jargon, not substance.

When a message contains several questions or asks, answer every one — numbered to match if numbered. If deferring one, say so. A question inside a task message is not optional context; answer it explicitly.

Shape answers for action: when the answer is a command, path, or snippet, lead with it — mechanism and context after. In multi-stage work, restate position at each boundary ("step 3 of 5 done: X; next: Y") and, when backgrounding something long, say what's running and a concrete ETA in minutes. End with the one next action when anything is open. If a list grows past ~5 items, split it into "do now" vs "later". Before sending, check: from the first and last line alone, is it clear what just happened and what to do next?

Use a GAN-style thinking framework — give me specific critiques and concrete suggestions.

When implementing new features, fixing bugs or problems, prefer red/green TDD.

If some things are not working, work through or surface the issues, don't just skip them as not being important, relevant, or necessary to the main task at hand. This applies to issues related to the task (especially ones our work introduced): fix small ones in place, and bring big blocking ones up for discussion. Incidental findings unrelated to the task are different — don't fix them mid-task; mention them at the end and offer to open tickets so they get tracked.

**Don't assume you can't run something.** Always try running tests, servers, or other commands before concluding they won't work. If a command fails, report the actual error — don't preemptively give up.

A subagent or delegate reporting success is a claim, not evidence. Check its report against the acceptance criteria you gave it — require the artifact (pasted output, screenshot, exported file, row counts) before relaying "done". Same for CI: a green check doesn't prove a test ran; confirm it was actually collected and executed.

Once a multi-stage plan is agreed, run it to completion. Finishing one stage and reporting back is not a stopping point; stop only when genuinely blocked on the user's input, and say exactly what you need.

If you spun up infra or services in a worktree, bring them down when you're done using them. If you're leaving them up on purpose, say so and why.

Keep instruction and memory files compact: dedupe on sight, amend existing rules rather than appending new ones, prune rules that no longer fire. When the user corrects a stored belief, delete the wrong memory in the same turn.

Never put ticket numbers in code comments or documentation prose — the only exception is a TODO for an upcoming fix. Before committing, grep added lines for the ticket prefix.

Don't include changelog-like narrations in comments or documents.

# Web search and fetching

Default to `pplx` (Perplexity CLI) for search — current information, news, docs, "what's the state of X". It returns ranked links fast and costs about half a cent per search.

Reach for firecrawl when the job is reading a page rather than finding one:

- JS-rendered pages and SPAs
- crawling a site or a whole docs section
- structured extraction against a schema
- anything needing clicks, forms, or a logged-in session

`pplx content fetch` handles plain static pages and is far cheaper per page, so try it first for simple reads. If it comes back empty or paywalled, switch to firecrawl scrape.

# Git commits

Commit and push autonomously when the change is what was asked and the required checks are green. Ask first only when there's a genuine judgment call for the user — scope changes, design choices, anything outward-facing or hard to reverse.

Use conventional commits.

If a Linear ticket number is available, include it in the commit message, but put it in the body, not the first line. Similarly, you should use the git branch name provided by Linear if possible.

Before committing, make sure to run any available checks for the project, like linter, typechecking, formatting, etc. NEVER force skipping checks in order to commit. It almost always means our change caused a problem or we forget to run `mise run sync`.

Don't typically force push unless necessary. Prefer making new commits when appropriate.

On a long-lived branch, merge latest main regularly — at least before each planning, push, or review cycle — without being told. (Merge, not rebase.)

# Opening PRs & Writing PR descriptions

When writing PR description:
- first is a tldr which should be an explanation of problem and solution in plain & simple english
- then a more thorough summary of the changes. the most important thing is WHY the changes are introduced.
- include "how to test" instructions for the reviewer with steps on how they can test the changes in the PR.
- don't include changelog-like narratives

When a PR is ready to merge or just merged, state what's owed per environment (migrations, resets, sensor enables, backfills) without being asked — including an explicit "nothing owed".

# Commenting on PRs

Whenever replying to comments on PRs, prefix the message indicating that it's an agent responding on behalf of the user. MAKE SURE YOU REFERENCE THE CORRECT GITHUB USER (i.e. tkuminecz). say "> Agent replying on behalf of @tkuminecz"

When replying to a comment, tag who wrote the original comment we are replying to.

If you're replying to a comment with a fix, include the short commit ID that contains the fix. This means you should typically push your commits to the remote before replying.

Don't add replies without showing a draft and confirming with the user.

When you reply to a comment, include a direct link to the reply.

# Writing and running tests

For each test case, you should ALWAYS include a comment explaning what is being tested and the motivation for it.

In general, don't add tests where we're simply constructing an object (esp Pydantic models) and then just asserting that the fields contain what was passed in. Those aren't really valuable.

## Test feedback loop — cheap first, full suite last

Run the cheapest thing that covers what just changed, and escalate a tier only once it's green.
Waiting on a full suite mid-loop is the main source of dead time, and nothing requires it — the
hard rule is about **pushing**, not about every edit.

Tiers, cheapest first, scoped to what was actually touched:

1. the specific test file(s) covering the change, plus format/lint on the touched files
2. typecheck + the touched package's unit tests
3. the full unit suite for the touched domain
4. integration tests
5. the full battery across every touched domain, E2E included

- **Never escalate while a cheaper tier is red.** The cheap failure usually masks the expensive
  result anyway, so the slow run is wasted.
- Escalate when a logical unit of work is done, not after every edit.
- **Tier 5 is a hard gate before every push — and it gates the push, not each commit.** "The
  failure looks like it came from main" is not an exemption. Batch related commits and run the
  full battery once per push batch, never once per logical change.
- **Never foreground-block or sleep-poll on a suite.** Launch tier 3+ suites with Bash
  `run_in_background` and keep working (or end the turn) — the finish notification arrives on its
  own. When the only remaining work is the gate itself, prefer reporting back with the gate running
  in the background over holding the turn open to watch it.
- **The waiting is what actually goes wrong — a backgrounded suite you then block on is worse
  than one you never backgrounded.** After launching, the next tool call must not be a wait on
  that suite. If a wait loop is genuinely unavoidable, it carries `run_in_background: true` too —
  always, no exceptions. A foreground `until ... sleep ... done` burns the full 10-minute Bash
  ceiling doing nothing and is then killed without reporting anything, so you pay the time and
  still have to check again.
- **Never wait on, defer to, or serialize against a test run from another worktree or another
  session.** Worktrees do not collide; there is nothing to take turns with. Do not `pgrep` for
  other people's pytest processes, and never phrase a delay as avoiding a conflict with another
  run. The only legitimate reason to hold off is raw host capacity (RAM/CPU) — and if you invoke
  it, name the resource with a number ("host at 58 of 62 GB"), never the neighbouring run.
- **The no-sleep-poll rule applies to all multi-minute external waits** — suites, CI, factory
  reviews/E2E, PR merges, delegates — not just tests. Poll at minutes, not seconds, in the
  background; this includes code and skills you write. Before concluding an external system
  reported nothing, confirm it actually finished — "no comments yet" is not "no comments".
  When judging whether something is alive or done, use direct evidence (its log, its status
  API), not proxies.

**Skip the deferral when the change class makes cheap tiers blind.** Deferring is safe for pure
logic; it isn't when only the expensive layer can see the bug. Go to integration early for
migrations and schema changes, Restate wire names and handlers, auth / RLS / tenancy, changes to
shared conftest or fixtures, dependency bumps, and anything done while resolving a merge conflict.
A green unit run on those tells you close to nothing.

When a late failure could have been caught by a cheaper tier, add a test at that tier before moving
on — that's how the loop gets faster over time.
