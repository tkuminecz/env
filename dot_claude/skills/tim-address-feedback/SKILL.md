---
name: tim-address-feedback
description: Middle phase of a PR — Tim has reviewed the draft WIP PR and given questions or feedback. Answer the questions, turn the feedback into a mini plan, get approval, implement, and push. Repeats until Tim is happy and invokes /tim-finish-pr. Use when Tim gives feedback or asks questions on an in-progress draft PR.
---

# Address PR feedback

**First: read LESSONS.md in this skill's directory in full** — it holds the traps
previous runs hit. Apply them; don't rediscover them.

A mini plan → approve → implement loop, run once per round of Tim's feedback on a draft
`WIP` PR. When he's happy with everything, he'll invoke /tim-finish-pr — that's not this
skill's job.

## Stage 1 — Answer and triage

- Answer every question Tim asked, explicitly and numbered to match — plain English first,
  then the technical detail. Questions are not optional context; none get dropped.
- Triage each piece of feedback: what change it implies, its blast radius, and anything it
  conflicts with. If a point seems wrong or costly, say so with reasoning — but if Tim
  pushes back twice, switch to his direction or state plainly why it's impossible.
- Merge latest main before planning the fixes.

## Stage 2 — Mini plan

- For a non-trivial round, produce a short plan: each feedback item mapped to concrete
  changes, tagged grok / glm / deepseek / claude, red/green where behavior changes.
  Escalate to a fable subagent only if the feedback reopens design-level decomposition.
- Open the plan for review in a herdr vertical pane (`glow -p`); close it once decided.
- For trivial rounds (typos, renames, a one-liner), skip the ceremony: state what you'll do
  in a sentence or two and proceed unless Tim objects.

## Stage 3 — Implement and push

- Execute the approved mini plan, delegating implementation to the tagged lanes; the main
  session briefs, integrates, and independently reviews each diff. Delegate briefs require
  self-verification with pasted output.
- Run the test tiers cheap-first, scoped to what changed.
- **Verify against real running services before the push — non-negotiable.** For every
  feedback item that changes runtime behavior, the main session (not a delegate, not the
  suite) restarts the changed services on the worktree stack (`mise run dev:restart`),
  exercises the affected endpoint / handler / job / UI / template against them, and
  pastes the evidence (output, screenshot, row count) under that item in the report.
  Green tests are not a substitute; an item that truly can't run locally gets a named
  reason in the report, never a silent skip.
- Push to the PR, and re-sync the PR description if behavior or scope changed.
- Report back: what changed per feedback item, answers to anything still open, and
  anything you deliberately didn't do and why. If the round ran long and Tim has likely
  stepped away, send the same summary line via /telegram-notify. Then wait for Tim's
  next round — or his /tim-finish-pr.

## Run note — always, last

Append a run note to `~/.claude/pipeline-runs/<YYYYMMDD>-<ticket-or-pr>-address-feedback.md` (5 lines
max): what tripped, any correction Tim made mid-run, and lesson candidates for
/tim-skill-gardener. Nothing tripped → one line saying so. This is a record, not a rule
change — never edit LESSONS.md directly.
