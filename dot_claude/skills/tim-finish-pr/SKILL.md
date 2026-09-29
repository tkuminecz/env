---
name: tim-finish-pr
description: Drive a feature branch from "implementation done" to a ready-for-review PR — E2E verify, self-review + factory review in parallel, triage and fix findings, watch CI and CodeRabbit, then undraft and remove WIP. Use when the user says "finish the PR", "run the finish pipeline", or implementation on a worktree branch is complete and needs the full verification/review loop.
---

# Finish a PR

**First: read LESSONS.md in this skill's directory in full** — it holds the traps
previous runs hit. Apply them; don't rediscover them.

Run every stage to completion. Stop only when genuinely blocked on Tim's input, and
say exactly what you need. Finishing one stage and reporting back is not a stopping point.

## Stage 0 — Preconditions

- Branch is pushed and a draft PR with the `WIP` label exists. If not, run `/github-sync-pr`
  and open it as draft + WIP.
- `git status --short` is clean, or every remaining entry is named and justified.
- Merge latest main and resolve conflicts before starting the loop.
- **The stages are strictly ordered.** No stage starts before the prior stage's findings are
  triaged and its fixes are pushed. Backgrounding a poll means keep the session responsive, not
  start the next stage.

## Stage 1 — Local verification against real services (non-negotiable)

**The main session does this itself.** It is not delegated, not replaced by green unit or
integration suites, and not skipped as "can't be exercised locally". Runs have shipped PRs
whose changes were never exercised against a running service; this stage exists to make
that impossible.

1. **Enumerate the affected surface from the diff.** Write the list into the transcript
   before testing anything: every endpoint, handler, Restate service, Dagster job/sensor,
   UI page or component, migration, template, flag, config path, and doc-stated behavior
   the PR touches — including callers of changed code, not just the changed files.
2. **Bring the worktree stack up on the PR's HEAD.** `mise run dev:stack`, `mise run info`,
   migrations applied, `mise run dev:restart <service>` for every service whose code changed
   (a stale process tests the old code). Confirm each affected service is actually serving
   before exercising it.
3. **Exercise every item on the list against the running services.** Real HTTP calls to
   real endpoints, playwright-cli in a real browser for UI, real client files from
   ~/jb/client_data for ingestion/templates, real job runs for pipelines, real handler
   invocations for Restate, DB/lake state read back after each write. Testcontainers and
   fixtures are not the local stack.
4. **Evidence per item, pasted into the transcript:** command output, response bodies,
   screenshots, row counts, log lines. An item without evidence is not verified. The
   checklist with its evidence becomes the PR's "how to test" section.
5. **An item that genuinely cannot run locally** gets a named reason on the list and is
   raised to Tim explicitly — it is never silently dropped, and "the tests cover it" is
   not a reason.

Then spawn an opus subagent to run the same flow independently (browser, real data), as a
second pair of eyes. Its "passed" is a claim, not evidence: require artifacts matching
each acceptance criterion. It supplements the main session's pass; it never replaces it.

Triage anything found; fix red/green; commit.

**Re-verify after every fix round.** Any fix in Stages 2–4 that changes runtime behavior
re-runs the affected checklist items against the restarted stack before the push — a fix
that was only unit-tested is in the same state this stage exists to prevent.

## Stage 2 — Self-review fan-out, then factory review

- Fire self-reviews from multiple models in parallel: an opus subagent, grok (via the grok
  CLI, which can invoke /self-review), deepseek via pi, and GLM via pi.
- Merge and triage all their findings together with `/github-fix-review-feedback` discipline:
  classify each finding, fix real ones red/green, push.
- Only AFTER that triage is done and fixes are pushed, request a factory review via the
  reviewqueued MCP (`request_review`). Poll at minutes, not seconds, in the background. If the
  run finishes but no report publishes, read the KB URL — don't re-request.
- Triage and fix the factory's findings the same way, and push.
- If the combined reviews come back clean on a large, subtle, or cross-cutting diff,
  escalate: one background fable re-review pass (goal + constraints brief, not
  step-by-step) before trusting the clean result.

## Stage 3 — Factory E2E (default: run it)

- **Gate: do not start this stage until the factory review report has been read, its findings
  triaged, and any fixes pushed.** Factory review and factory E2E never run concurrently — E2E
  launched against a commit that review fixes will change is stale on arrival and the run is
  wasted. Overlapping them to save wall-clock is not a tradeoff, it's a re-run.
- Request a factory E2E run (`request_e2e` — this is NOT another review). Skip only when it
  genuinely can't add signal: doc-only changes, or work that can't be exercised in a local dev
  env. Typically finishes in under 30 minutes; poll in the background at minutes.

## Stage 4 — Watch CI and CodeRabbit

- After each push, watch the PR's checks in the background and report state changes only.
- Record known-expected failures (e.g. a deploy check that can't pass until merge) once;
  don't re-raise them.
- A green check doesn't prove a test ran — for new/changed tests, confirm from the run log
  they were collected and executed.
- Fix any CI failures and actionable CodeRabbit comments. Always prefer delegating the
  actual fix implementation to subagents — grok, GLM, or deepseek by default — rather than
  fixing inline; the main session triages, briefs, and verifies. Drafts of any PR replies go
  to Tim for approval before posting.
- A CI failure that survives the first serious fix attempt gets its root-causing escalated
  to a background fable subagent instead of another iteration in the same lane.

## Stage 5 — Finish

- When CI is green and reviews are clear: mark the PR ready for review and remove the `WIP`
  label (this pipeline is the explicit instruction to do so), and add reviewers if Tim named
  them.
- Re-sync the PR description against the final diff: plain English tldr, why, how-to-test
  (the Stage 1 checklist, re-verified on the final commit), no changelog narrative, every
  stated caveat linked to a Linear ticket.
- State what's owed per environment post-merge — or an explicit "nothing owed".
- Bring down the worktree's services and infra unless told to keep them up.
- Report: PR link, review outcomes, CI state, per-env steps.
- Notify Tim via /telegram-notify: PR ready for review (or where the pipeline is blocked
  on him, if it stalled earlier). One message, outcome first.
- Offer to continue into /tim-babysit-pr to watch the PR while human reviews come in.

## Run note — always, last

Append a run note to `~/.claude/pipeline-runs/<YYYYMMDD>-<ticket-or-pr>-finish-pr.md` (5 lines
max): what tripped, any correction Tim made mid-run, and lesson candidates for
/tim-skill-gardener. Nothing tripped → one line saying so. This is a record, not a rule
change — never edit LESSONS.md directly.
