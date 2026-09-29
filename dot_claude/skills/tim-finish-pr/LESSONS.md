# Lessons — finish-pr

Read fully before Stage 0. Cap: 15 entries — adding #16 means pruning the weakest.
Each entry: the trap, then the check that avoids it. Curated by /tim-skill-gardener; don't
edit ad hoc mid-run (propose a lesson candidate in the run note instead).

1. Factory review and factory E2E are different requests on the same reviewqueued MCP —
   `request_review` vs `request_e2e`. Substituting one for the other has happened repeatedly;
   if the E2E tools aren't visible, the MCP needs re-adding/restart — say which tool is
   missing, don't run the nearest neighbor.
2. A factory run can finish without publishing a report — read the KB URL instead of
   re-requesting.
3. An E2E subagent's "passed" has been wrong three times running — require artifacts
   (exported file, screenshots, row counts) matching each acceptance criterion before
   accepting the report.
4. Green CI doesn't mean the tests ran — data-hub E2E specs were green-but-never-collected
   for months. For new/changed tests, confirm collection count in the run log.
5. A PR merge-conflict blocks CI entirely (no run at all, not a failure) — check
   `gh pr view --json mergeable` before reading absence of checks as pending.
6. PR descriptions drift from the diff across fix rounds — behavioral claims have been
   caught stale. Re-verify every claim against the final diff before undrafting.
7. Before posting anything to the PR, check an equivalent comment/review isn't already
   there — duplicate posts have happened.
8. Factory E2E has been launched while the factory review was still in flight, repeatedly. The
   order is local E2E + self-reviews → factory review (report read, findings fixed, pushed) →
   factory E2E. Backgrounding the review poll is not permission to start Stage 3; confirm the
   review report exists and its fixes are pushed before calling `request_e2e`.
9. Local verification has been skipped or left entirely to a subagent — run notes for four of
   eight recent runs never mention it, and PRs shipped with changes no one exercised against
   a running service. The main session enumerates the affected surface, restarts the changed
   services, and pastes evidence per item before Stage 2 starts; green suites don't count.
