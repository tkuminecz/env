---
name: delegate
description: Delegate coding tasks to external subscription models (GLM 5.2 via z.ai, Grok 4.5 / grok-build via x.ai SuperGrok) through the pi CLI headless mode or herdr agent panes. Use when offloading well-specified execution work to non-Claude models, when the user says "delegate to pi/GLM/grok", "use the z.ai/supergrok sub", "farm this out", or when fanning out parallel grunt work that would otherwise burn Anthropic quota.
---

# Delegating to external subscription models

Tim pays flat-rate subscriptions for z.ai (GLM models) and x.ai SuperGrok (Grok models). Both are wired into the `pi` coding agent — z.ai as an API key, x.ai as OAuth tokens (auto-refreshing) in `~/.pi/agent/auth.json`. Marginal cost of a delegated task is zero, so fan out freely; the only budget is undocumented daily/session rate limits on each sub (pi's TUI footer shows usage %).

Delegated agents run with **full autonomy and no permission prompts** (pi has read/bash/edit/write). Only hand them tasks safe to run unattended, and use git worktrees when parallel tasks edit the same repo.

## Which model for which task

All are verified working via `pi --provider <p> --model <m>`. Cost is equal (~zero), so route purely on fit:

| Model | Invoke as | Best at | Avoid for |
|---|---|---|---|
| **grok-4.5** | `--provider xai --model grok-4.5` | Default external workhorse. Strongest external model (#4 AA index, #1 agentic tool use; Terminal-Bench 83.3, SWE-bench Pro 64.7). Fast (~80 tok/s), ~2x more token-efficient than peers. Multi-file changes, harder execution tasks, professional-judgment work. 500K ctx. | Tasks needing >500K context |
| **glm-5.2** | `--provider zai --model glm-5.2` (Tim's pi default) | Repo-scale long context (usable 1M — its headline feature). Iterative run-test-fix loops (measurably better when told to execute and self-verify than one-shot). Self-contained/single-file work, local bug review. Doesn't refuse security-adjacent tasks. | Cross-file reasoning — quality wobbles when correctness spans many files (kilo.ai eval); use grok-4.5 or Claude there |
| **grok-build-0.1** | `--provider xai --model grok-build-0.1` | Quick mechanical tasks where latency matters — renames, small scripted edits, lookups. Purpose-trained coding workhorse (SWE-bench Verified 70.8, successor to grok-code-fast). 256K ctx. | Anything needing judgment |
| **grok-4.3** | `--provider xai --model grok-4.3` | Fallback 1M-ctx reasoning model if glm-5.2 is rate-limited on a long-context task. | Generally superseded by grok-4.5 |

Escalate back to **Claude subagents** (per CLAUDE.md routing) when the task holds open-ended judgment, needs conversation context, or must integrate with Agent-tool machinery (structured output schemas, worktree isolation, background notifications).

## Path 1: headless one-shot (`pi -p`)

```sh
cd <workdir> && pi -p --no-session -ne --thinking low \
  --provider xai --model grok-4.5 \
  "<task>"
```

- `-p` prints the final answer to stdout and exits. `--mode json` streams full structured events instead.
- `-ne` skips extension discovery **including MCP servers** — without it every run boots the Notion MCP proxy (~15s + log noise). But `-ne` also strips locally installed safety extensions: if `~/.pi/agent/extensions/permission-gate.ts` exists (it does on Tim's Mac — blocks rm -rf/sudo/chmod-777 outright in headless runs), re-add it explicitly: `-ne -e ~/.pi/agent/extensions/permission-gate.ts`.
- **Always set `--thinking low` or `medium`.** Tim's pi default is `high`, which stalled 4+ min on a trivial GLM task; `low` finished the same task in seconds.
- Run via Bash `run_in_background` for anything nontrivial; launch several in parallel for fan-out.
- pi auto-loads AGENTS.md / CLAUDE.md from cwd — run from the repo root so the agent gets project context (`-nc` disables).
- Follow-up turns: use `--session-id <uuid-you-generate>` instead of `--no-session`; it creates the session if missing and reuses it on later calls (sessions under `~/.pi/agent/sessions/`).

## Path 1b: grok CLI (alternate harness for Grok models)

xAI's own Grok Build CLI (`grok`, npm `@xai-official/grok`) is installed and logged in via SuperGrok OAuth (`grok login` if auth expires). Head-to-head on an identical brief (July 2026), pi+grok-4.5 and grok CLI were a near tie in speed (~35s) and output quality — pick by feature, not quality:

```sh
cd <workdir> && grok -p "<task>" --always-approve --output-format plain
```

Reach for grok CLI over pi when you want: `--json-schema '<schema>'` (constrained structured output), `--permission-mode` / `--sandbox` (stock pi has no permission system; Tim's pi has only the permission-gate extension for dangerous bash), `--worktree` (built-in isolation — but pass `--worktree-ref` explicitly rather than trusting its default base), `--max-turns`, or session resume with forking. Reach for pi when you want GLM models or one interface across both subs. Note the sub only exposes `grok-4.5` in this CLI; `grok-build-0.1` is reachable via pi.

pi is deliberately minimal but **extensible by design** (extensions, custom tools, skills — Tim: "sort of the intended way to use pi"). If a grok-CLI-only feature becomes a recurring need — approval gating, structured output, a delegation-brief tool — the preferred move is writing a pi extension (`pi install`, `-e <path>`) rather than switching harnesses.

## Path 2: via herdr (runtime-agnostic, user-visible)

Prefer this when the user should be able to watch or take over, or to reuse a warm agent pane. Works with any agent kind herdr supports (pi, claude, codex, gemini, ...).

```sh
herdr agent list                                    # JSON: pane_id, kind, status, cwd, session file
herdr agent prompt <pane_id> "<task>" --wait --timeout <ms>
herdr agent read <pane_id> --lines <N>              # scrape terminal output
herdr agent wait <pane_id> --until idle --timeout <ms>
```

- **`agent_prompt_stalled` is often a false negative**: it fires when the agent finishes inside the 5s state-change window. The reply usually landed — `agent read` the pane before assuming failure.
- For structured output, read the agent's session file instead of scraping: `agent list` exposes it as `agent_session.value` (pi sessions are .jsonl).
- Spawning fresh panes: `herdr workspace create` / `herdr tab create` → `herdr agent start <name> --kind pi --pane <id>`, then prompt/wait/read.
- A pane belongs to the user's workspace — prefer idle panes whose cwd matches the task, and don't hijack a pane mid-conversation.

## Prompting delegated agents

These models share none of your conversation context. Every delegation prompt needs:

1. **Concrete scope** — files/paths involved, what done looks like, acceptance criteria.
2. **A self-verification step** — "run the tests / build / script and report PASS or FAIL with the output." GLM 5.2 in particular performs significantly better when told to execute and self-debug iteratively rather than one-shot.
3. **Explicit wording** — for GLM, prompt phrasing moves results more than thinking level does. Say exactly what to check.

4. **A deviations section** — end the brief with: "In your final report, list every place you deviated from this spec and why." Honest deviations are common and often right, but they can carry product decisions the user should hear about — read them before merging.

Then **verify yourself**: treat the output as an untrusted contribution — diff-review the changes and run the project's full test/lint suite before accepting. Never report delegated work as done on the agent's say-so alone.

## Light path vs full pipeline

Delegates may edit files **directly in the current checkout on the current branch** for small, sequential tasks — uncommitted changes are easy to review with `git diff` and easy to discard, exactly like any other local edit. Don't reach for worktrees by default. The full pipeline below earns its overhead only when work is **parallel** (agents would collide in one checkout) or **package-sized** (a feature/rebuild whose diff deserves its own branch, battery, and review round).

## Build packages: worktree + merge pipeline

For delegations bigger than a one-shot (a feature, a rebuild, parallel packages), use the full pipeline. Calibration from a comparable grok-delegation workflow (~10 packages): the builder is fast, idiomatic, honest about deviations, and green on tests — **and its self-verification is structurally blind to composition bugs**. Independent review caught 3 criticals and ~30 real warnings *after* green tests plus a builder self-review that reported zero findings. So step 4 is not optional.

1. **Brief.** Write a self-contained brief file (builder has no conversation context) to the scratchpad, and point the pi invocation at it (`pi -p ... "Read and execute the brief at <abs path>"`). Sections, all load-bearing:
   - *Goal* — one paragraph, plain english.
   - *Scope* — explicit files/dirs this package owns. For parallel packages, add a fence: "do NOT touch X — owned by another package this round." This is the disjointness contract.
   - *Read first* — repo docs (AGENTS.md/CLAUDE.md auto-load if run from repo root) plus the exact files touched and any shared-context file (cross-package contracts go in one shared scratchpad file referenced by absolute path from every brief).
   - *Spec* — numbered, testable requirements.
   - *Done means* — battery green + specific acceptance checks; require a single clean commit.
   - *Out of scope* + the deviations-report requirement.
2. **Worktree per package.** Prefer worktrunk when available — always if the repo has a worktrunk config, generally whenever `wt` is installed: `wt switch --create <branch>` (its hooks make the worktree actually runnable — env files, deps), later `wt merge` and `wt remove` (deletes the branch once merged). Fallback: hand-create from the intended base with `git worktree add <dir> -b <branch> <base-sha>` — never a harness's automatic worktree feature with a defaulted base. If the feature branch advances before launch, `git -C <wt> reset --hard <new-sha>` (safe while the package branch has no commits). Never `git stash` in shared checkouts.
3. **Battery on the merged result, not just the package's own gates.** Merge `--no-ff`, then run the wider suites the touched surfaces feed — path-scoped runs miss cross-cutting breakage.
4. **Independent review — always.** Capture the diff (`git show <sha> > <scratchpad>/<slug>-diff.txt`) and launch a fresh-context **opus** review subagent (per CLAUDE.md routing) with: the diff path, changed-file list, domain rules, and focus hints *including your own suspicions and anything the builder's self-review dismissed*. Builder self-review raises the floor; it never substitutes for this.
5. **Fix pass, push, cleanup.** Apply confirmed findings (delegate mechanical fixes back to the builder if you like), re-run the battery, then remove the worktree.
6. If the target branch moved while the builder ran, expect conflicts in shared files — resolve keeping both intents, never discard either side blind.

## Scorecard: log every delegation

`LOG.md` next to this file is the calibration record — it travels with the skill. After each delegated task finishes its pipeline (including one-shots), append a row: date, task, model @ harness, grade (A merged as-is / B minor fixes / C major rework / F discarded), wall time, what independent review caught that the builder's self-verification missed, notes. When routing a new task, skim the log's distilled-patterns section first — observed history beats benchmarks. When rows accumulate (~30) or a pattern repeats, distill it into the patterns section, fold stable conclusions into the routing table above, and prune the raw rows they came from.

## Known failure modes

- z.ai API calls occasionally flake and need a retry (community-reported; retry once before switching models).
- Rate limits on both subs are undocumented; if a provider throttles, switch to the other sub's equivalent model.
- `--thinking high` on glm-5.2 can stall for minutes — never use it for delegation.
- Headless pi with a hung task: check `ps` for the `pi` child process; kill and rerun at lower thinking.
