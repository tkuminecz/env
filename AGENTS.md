# General rules

Use simpler and plainer english style of explanation.

Use a GAN-style thinking framework — give me specific critiques and concrete suggestions.

When implementing new features, fixing bugs or problems, prefer red/green TDD.

If some things are not working, work through or surface the issues, don't just skip them as not being important, relevant, or necessary to the main task at hand.

**Don't assume you can't run something.** Always try running tests, servers, or other commands before concluding they won't work. If a command fails, report the actual error — don't preemptively give up.

Generally don't include ticket numbers in code comments unless referring to an upcoming fix (i.e. like a TODO comment).

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

You should let the user review changes before committing, unless the user has instructed you to eagerly commit.

Use conventional commits.

If a Linear ticket number is available, include it in the commit message, but put it in the body, not the first line. Similarly, you should use the git branch name provided by Linear if possible.

Before committing, make sure to run any available checks for the project, like linter, typechecking, formatting, etc. NEVER force skipping checks in order to commit. It almost always means our change caused a problem or we forget to run `mise run sync`.

Don't typically force push unless necessary. Prefer making new commits when appropriate.

# Opening PRs & Writing PR descriptions

When writing PR description:
- first is a tldr which should be an explanation of problem and solution in plain & simple english
- then a more thorough summary of the changes. the most important thing is WHY the changes are introduced.
- include "how to test" instructions for the reviewer with steps on how they can test the changes in the PR.
- don't include changelog-like narratives

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
  own. `until pgrep ...; sleep` loops burn a 10-minute Bash timeout per iteration doing nothing.
  When the only remaining work is the gate itself, prefer reporting back with the gate running in
  the background over holding the turn open to watch it.
- **Suite serialization is per docker stack, not per machine.** A worktree with its own
  `.env.worktree` (isolated stack) only needs to serialize against pytest runs inside that same
  worktree — scope any `pgrep -f` check to the worktree path. A worktree in shared docker mode
  (no `.env.worktree`) shares the MAIN checkout's containers and must serialize against it.

**Skip the deferral when the change class makes cheap tiers blind.** Deferring is safe for pure
logic; it isn't when only the expensive layer can see the bug. Go to integration early for
migrations and schema changes, Restate wire names and handlers, auth / RLS / tenancy, changes to
shared conftest or fixtures, dependency bumps, and anything done while resolving a merge conflict.
A green unit run on those tells you close to nothing.

When a late failure could have been caught by a cheaper tier, add a test at that tier before moving
on — that's how the loop gets faster over time.
