# Standing clauses for every delegated brief

These rules apply to your task in addition to the brief that pointed you here. Where the brief
explicitly overrides one of them, follow the brief.

## Git state (shared checkout)

- Do NOT use `git stash`, `git checkout -- <file>`, `git restore`, or `git reset` at any point.
  Other packages have uncommitted work in this checkout and all of these silently revert it.
  To restore a file after a mutation proof, keep a byte copy (`cp f /tmp/f.bak` …
  `cp /tmp/f.bak f`) and confirm the restore with `cmp /tmp/f.bak f`.
- Never run `git commit` unless the brief asks for a commit; if it does, commit
  pathspec-limited: `git commit -m "<msg>" -- <your files only>`. Never `git push`.
- A dirty file outside your fence is someone else's deliberate work-in-progress. Leave it
  byte-for-byte as found. Never restore, revert, or "clean up" a file you do not own by any
  mechanism: git, `cp` from a backup, or re-typing content from memory.
- End your report with a pasted `git status --porcelain`. Every path YOU modified must sit
  inside your fence. Other packages' dirty paths will also appear. Leave them alone and do
  not claim them.

## Stop conditions

- If production code appears reverted or deleted, STOP and report. Do not reconstruct it.
- If a test cannot be made to pass without weakening an assertion the spec names, STOP and
  report. The implementation is on trial, not the assertion.
- If the brief's premise is false, say so with evidence instead of implementing around it.
  Premises marked UNVERIFIED are yours to disprove.

## Vocabulary in permanent files

Code, comments, docstrings and docs outlive this round. Do not write any of these into them:
package names, brief or contract section labels (for example "CONTRACT E3", "§4", "lane B"),
ticket ids in new code, or narration of the change ("now", "no longer", "was changed to").

## Evidence, not claims

For every gate, paste the command and its output: lint, **format check** (`ruff format --check
<files>`; `biome format`/`biome check` for TS — the pre-commit hook runs the formatter, so a
clean `ruff check` alone is not a clean gate), typecheck, and tests. "Clean" without output is
not evidence. The format check covers every file you wrote **or regenerated**, including
generated snapshots and JSON (`pnpm exec biome format --write <file>`), because the hook
reformats them at commit.

When your deliverables include tests, give a mutation-RED proof for each core behaviour:
break the production code under test, paste the failing output, restore it byte-identical
(`cmp`), and paste the passing output. Assert exact or structural tokens, never bare
substrings. Fakes and fixtures pin literal expected values and never re-derive them from the
inputs. Tests written ahead of an implementation still owe that proof, whatever order things
land in. If the implementation isn't there yet, prove RED against its absence or against a
scratch implementation of the contract under `/tmp`. Never write that scratch
implementation in the repo tree, where it breaches your fence and sits in a sibling's way. If a sibling landed it first, mutate the
production code. Never skip the proof because the suite came up green. A skipped test is not a passing test, and a mocked integration test defeats the
purpose of the tier.

If you notice an issue in your own output, fix it or argue it in the deviations report.
Don't just mention it.

## Report

Write the report to the path the brief names. If it names none, print it as your final
answer. End with a **Deviations** section listing every place you departed from the brief
and why, and any file outside your fence that you believe needs a change. Name the file.
Don't edit it. If the brief lists call sites for a change, account for every one: changed, or
left alone and why.
