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
- The one exception is collateral from a tool you ran. If a code generator, formatter or lint
  fixer rewrote files outside your fence, restore exactly those files to their pre-run bytes.
  Take `cp` backups before you run it, and list the restored files in your report.
- Run formatters and fixers only on files you changed. Never run `ruff format` on JSON or
  YAML, because it rewrote a JSON snapshot as a Python dict. Don't sweep a lint rule across
  lines you didn't touch. One em-dash sweep changed 69 lines, SQLAlchemy column comments
  among them, and `alembic check` drifted.
- End your report with a pasted `git status --porcelain`. Every path YOU modified must sit
  inside your fence. Other packages' dirty paths will also appear. Leave them alone and do
  not claim them.

## The shared machine

- Never delete, truncate, move or chmod anything outside your fence and your own scratch
  directory, including other processes' logs in `/tmp`. If the disk fills (ENOSPC) or memory
  runs out, STOP and report. Don't free space.
- Scratch copies, worktrees, sandboxes, fetched docs and caches go in your own directory
  under `/tmp`, or the scratch dir the brief names, never inside the repo. Remove them when
  you finish and list anything you couldn't remove.
- For a mutation copy, `cp -r` the one package under test (tens of MB) rather than adding a
  full worktree, which has filled this host's disk.
- Never symlink from a scratch copy into the repo. Copy the file. A write through one such
  symlink replaced a committed 1155-line `dev.env` with a single line.
- Any script you write that writes to a database (a seeder, a perf script, a backfill) first
  checks which database it is connected to (`SELECT current_database()` or the equivalent)
  and refuses anything but the test database. A perf script once ran against the real database
  because it was given a `DATABASE_URL` with a query string.

## Stop conditions

- If production code appears reverted or deleted, STOP and report. Do not reconstruct it.
- If a test cannot be made to pass without weakening an assertion the spec names, STOP and
  report. The implementation is on trial, not the assertion.
- If the brief's premise is false, say so with evidence instead of implementing around it.
  Premises marked UNVERIFIED are yours to disprove.
- If a structural guard goes red on your change (a test that iterates a population, such as
  every seed dict, a schema snapshot, or every compose file), decide whether your change or
  the guard's population is wrong. Report a wrong population. Don't change production code
  just to satisfy a guard.
- If the test state the brief describes can only be seeded by dropping or altering a
  constraint, an index or a trigger, the schema forbids that state and the premise is false.
  STOP and report it. Never change the schema inside a test to make a scenario possible.
- If a mutation leaves every test green, report it as a test gap, or as a mutation that can't
  reach the code. Never change the behaviour the brief specifies just so a proof fires. A
  builder once moved where a distance was measured to make its proof go red. That broke 123 of
  20k fuzzed cases, and the suite stayed green.

## Permanent files: vocabulary and truth

Code, comments, docstrings and docs outlive this round. Do not write any of these into them:
package names, brief or contract section labels (for example "CONTRACT E3", "§4", "lane B"),
ticket ids in new code, narration of the change ("now", "no longer", "was changed to"), or
descriptions of the pre-fix state ("today", "currently", "until the fix lands").

Every comment and docstring you write or rewrite is a claim about the code. Before you
report, re-read each one against the code it describes. Don't describe behaviour you didn't
implement or a caller you didn't check, and don't repeat a premise you disproved. A rewrite
that reads more clearly but says something false is worse than the original. Where a rule is
abstract, give a concrete example. Leave Pydantic `Field(description=...)` strings and
similar schema text alone unless the brief lists them, because they feed the OpenAPI spec and
every generated client.

## Evidence, not claims

For every gate, paste the command and its output: lint, **format check** (`ruff format --check
<files>`; `biome format` or `biome check` for TS), typecheck, and tests. The pre-commit hook
runs the formatter, so a clean `ruff check` alone is not a clean gate. "Clean" without output
is not evidence. The format check covers every file you wrote **or regenerated**, including
generated snapshots and JSON (`pnpm exec biome format --write <file>`), because the hook
reformats them at commit.

The test gate is the whole unit test directory of every service you touch, not only the
files the brief names, plus the REST or route suite for any endpoint your change reaches.
Structural guards and route-level failures sit in suites nobody listed. When you change
behaviour that other code shares (a dbt mart, a seed or fixture, a shared helper), that
includes the integration directories too.

When your deliverables include tests, give a mutation-RED proof for each core behaviour:
break the production code under test, paste the failing output, restore it byte-identical
(`cmp`), and paste the passing output. Assert exact or structural tokens, never bare
substrings. Fakes and fixtures pin literal expected values and never re-derive them from the
inputs. Don't write call-count or listener spies (`assert_called_once`,
`toHaveBeenCalledTimes`), existence-only asserts, or mocks that echo the asserted value.

Tests written ahead of an implementation still owe that proof, whatever order things land in.
If the implementation isn't there yet, prove RED against its absence or against a scratch
implementation of the contract under `/tmp`. Never write that scratch implementation in the
repo tree, where it breaches your fence and sits in a sibling's way. If a sibling landed it
first, mutate the production code. Each RED must fail for the reason its test name gives. If
every test fails at the same early step (a 422 on a new body shape, an import error), that
RED proves nothing about the assertions after it, so prove those against the scratch
implementation. Never skip the proof because the suite came up green. A skipped test is not
a passing test, and a mocked integration test defeats the purpose of the tier.

Any proof run outside the main checkout (a detached worktree or a `/tmp` copy) must first
show which source it imports. The `pytest`/`python` on PATH belongs to the main checkout's
`.venv` and imports the *original* tree, so your mutation would never run. Before the proof,
paste `python -c 'import <pkg>; print(<pkg>.__file__)'`, run with the same interpreter you
test with, and confirm that the path is inside your copy. If it isn't, set `PYTHONPATH` to
your copy's package directories and check again. An editable install can still win over
`PYTHONPATH`. In that case, import from your copy inside one interpreter and call
`pytest.main([...])` from it, then confirm `__file__` again. Never copy mutated files into
the shared checkout to get around it.

Traps that no gate here catches:

- Never change production code to make a test double fit. Change the double.
- A name imported only under `if TYPE_CHECKING:` must not appear in a runtime expression,
  such as the first argument of `cast()` or an `isinstance`. ty passes it and the route
  raises `NameError`. Quote it (`cast("list[T]", rows)`).
- Never let set or frozenset iteration order reach output, an error message, a stored payload
  or a digest. String hashing differs per process, so the same input comes out in a different
  order. Iterate in the source's order or sort.
- When a check depends on what a reader yields (CSV or Excel inference, a JSON relay), at
  least one test goes through the real reader. A hand-built frame of the type you expect hides
  the type the reader actually produces.
- A seeded test world pins the absolute count of every table it seeds, not only the deltas
  under test. When both sides of a comparison go wrong together, the deltas cancel.
- A before/after test must not change the thing under test in its "before" step, or the
  "after" assertion can pass for the wrong reason. A test that claims to cover paging needs
  fixtures that fill at least two pages.

If you notice an issue in your own output, fix it or argue it in the deviations report.
Don't just mention it.

## Read-only lanes (reviews, sweeps, research)

- Mutate only in a `/tmp` copy, a detached worktree or a runtime pytest plugin, never in the
  shared checkout. A dev stack may be hot-reloading it, so an in-place mutation reaches a live
  service. Remove your copies when you finish.
- Run the code to test your claims. A finding backed by a run beats one backed by a read.
- Before your final message, write the full report to the file the launch prompt names, with
  a quoted heredoc (`cat > <path> <<'EOF'`). Then print it as well. The final message alone
  has come back as just a preamble or a closing summary.

## Report

Write the report to the path the brief names. If it names none, print it as your final
answer. End with a **Deviations** section listing every place you departed from the brief
and why, and any file outside your fence that you believe needs a change. Name the file.
Don't edit it. If the brief lists call sites for a change, account for every one: changed, or
left alone and why.
