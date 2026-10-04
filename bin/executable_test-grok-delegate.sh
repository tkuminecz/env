#!/usr/bin/env bash
# Self-contained test suite for grok-delegate (dry-run + fake-binary real mode).
set -u

GROK_DELEGATE="${GROK_DELEGATE:-$HOME/bin/grok-delegate}"
# Scratch dir for temp briefs and captured output. Deliberately NOT the
# script's own directory — this suite is installed into ~/bin, which should
# not collect stray files mid-run.
SCRATCHPAD="$(mktemp -d)"
trap 'rm -rf "$SCRATCHPAD"' EXIT

pass_count=0
fail_count=0

pass() {
	echo "PASS: $1"
	pass_count=$((pass_count + 1))
}

fail() {
	echo "FAIL: $1"
	if [[ -n "${2:-}" ]]; then
		echo "  detail: $2"
	fi
	fail_count=$((fail_count + 1))
}

# Run grok-delegate; capture stdout, stderr, and exit status into globals.
run_gd() {
	local stdout_f stderr_f
	stdout_f="$(mktemp)"
	stderr_f="$(mktemp)"
	set +e
	# Real runs tee a report into $TMPDIR; keep it inside the suite's scratch dir.
	TMPDIR="$SCRATCHPAD" "$GROK_DELEGATE" "$@" >"$stdout_f" 2>"$stderr_f"
	run_status=$?
	set -e
	run_stdout="$(cat "$stdout_f")"
	run_stderr="$(cat "$stderr_f")"
	rm -f "$stdout_f" "$stderr_f"
}

assert_contains() {
	# $1 haystack $2 needle
	case "$1" in
	*"$2"*) return 0 ;;
	*) return 1 ;;
	esac
}

assert_not_contains() {
	case "$1" in
	*"$2"*) return 1 ;;
	*) return 0 ;;
	esac
}

# Install a fake grok on PATH whose behaviour is selected by FAKE_GROK_MODE.
# Also installs a chezmoi stub (exits ${FAKE_CHEZMOI_STATUS:-0}, logs argv to
# $FAKE_CHEZMOI_LOG when set) so tests never depend on real chezmoi state.
install_fake_grok() {
	local fake_bin="$SCRATCHPAD/fakebin-grok"
	mkdir -p "$fake_bin"
	cat >"$fake_bin/grok" <<'FAKE'
#!/usr/bin/env bash
case "${FAKE_GROK_MODE:-ok}" in
ok)
	printf 'final report\n'
	exit 0
	;;
credit)
	echo 'Error: Internal error: {"message": "API error (status 402 Payment Required): Grok Build usage balance exhausted", "http_status": 402}' >&2
	exit 1
	;;
crash)
	echo 'boom' >&2
	exit 7
	;;
empty)
	exit 0
	;;
long)
	head -c 3000 /dev/zero | tr '\0' 'x'
	printf '\n'
	exit 0
	;;
*)
	echo "fake grok: unknown FAKE_GROK_MODE=${FAKE_GROK_MODE}" >&2
	exit 99
	;;
esac
FAKE
	chmod +x "$fake_bin/grok"
	cat >"$fake_bin/chezmoi" <<'CHEZ'
#!/usr/bin/env bash
if [[ -n "${FAKE_CHEZMOI_LOG:-}" ]]; then
	printf '%s\n' "$*" >> "$FAKE_CHEZMOI_LOG"
fi
exit "${FAKE_CHEZMOI_STATUS:-0}"
CHEZ
	chmod +x "$fake_bin/chezmoi"
	export PATH="$fake_bin:$PATH"
}

# --- 1. Default invocation emits core flags ---
# Default max-turns is 80 (raised from 40 so verification/mutation proofs survive).
# Sandbox profile may be auto-downgraded to off when user namespaces are denied;
# assert the flag is present and leave the profile value to test 16.
run_gd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--model" &&
	assert_contains "$run_stdout" "grok-4.6" &&
	assert_contains "$run_stdout" "--permission-mode" &&
	assert_contains "$run_stdout" "bypassPermissions" &&
	assert_contains "$run_stdout" "--sandbox" &&
	assert_contains "$run_stdout" " --max-turns 80 " &&
	assert_contains "$run_stdout" "--output-format" &&
	assert_contains "$run_stdout" "plain" &&
	assert_contains "$run_stdout" "--no-auto-update"; then
	pass "1 default invocation emits core flags"
else
	fail "1 default invocation emits core flags" "status=$run_status stdout=$run_stdout"
fi

# --- 2. Default invocation contains all four baked deny rules ---
# Dry-run output is shell-quoted (spaces become '\ '), so assert on fragments
# that survive quoting rather than the raw rule text.
run_gd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--deny" &&
	assert_contains "$run_stdout" "sudo" &&
	assert_contains "$run_stdout" "rm" &&
	assert_contains "$run_stdout" "-rf" &&
	assert_contains "$run_stdout" "chmod" &&
	assert_contains "$run_stdout" "777" &&
	assert_contains "$run_stdout" "git" &&
	assert_contains "$run_stdout" "push"; then
	pass "2 default baked deny rules present"
else
	fail "2 default baked deny rules present" "status=$run_status stdout=$run_stdout"
fi

# --- 3. --no-default-denies removes baked denies; explicit --deny still appears ---
run_gd -n --no-default-denies --deny "Bash(curl*)" "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--deny" &&
	assert_contains "$run_stdout" "curl" &&
	assert_not_contains "$run_stdout" "sudo" &&
	assert_not_contains "$run_stdout" "rm -rf" &&
	assert_not_contains "$run_stdout" "chmod 777" &&
	assert_not_contains "$run_stdout" "git push"; then
	pass "3 --no-default-denies drops baked denies; explicit --deny kept"
else
	fail "3 --no-default-denies drops baked denies; explicit --deny kept" \
		"status=$run_status stdout=$run_stdout"
fi

# --- 4. --allow passes through ---
run_gd -n --allow "Bash(pnpm*)" "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--allow" &&
	assert_contains "$run_stdout" "pnpm"; then
	pass "4 --allow passes through"
else
	fail "4 --allow passes through" "status=$run_status stdout=$run_stdout"
fi

# --- 5. -m glm-5.2 passes through verbatim (wrapper does not police model names) ---
run_gd -n -m glm-5.2 "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--model" &&
	assert_contains "$run_stdout" "glm-5.2"; then
	pass "5 -m glm-5.2 passes through as --model glm-5.2"
else
	fail "5 -m glm-5.2 passes through as --model glm-5.2" \
		"status=$run_status stdout=$run_stdout"
fi

# --- 6. Inline task string reaches the command as -p ---
run_gd -n "sentinel-task-marker-xyz"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "-p" &&
	assert_contains "$run_stdout" "sentinel-task-marker-xyz"; then
	pass "6 inline task string is passed through as -p"
else
	fail "6 inline task string is passed through as -p" \
		"status=$run_status stdout=$run_stdout"
fi

# --- 7. -f existing brief: --prompt-file + absolute path; no -p ---
tmp_brief="$SCRATCHPAD/tmp-brief-$$.md"
printf 'test brief\n' >"$tmp_brief"
# No local EXIT trap here — the suite-wide one above removes the whole scratch
# dir, and re-trapping EXIT would clobber it.

set +e
(
	cd "$SCRATCHPAD" || exit 99
	rel_name="$(basename "$tmp_brief")"
	"$GROK_DELEGATE" -n -f "$rel_name" >"$SCRATCHPAD/out-$$.txt" 2>"$SCRATCHPAD/err-$$.txt"
	echo $? >"$SCRATCHPAD/status-$$.txt"
)
set -e
run_status="$(cat "$SCRATCHPAD/status-$$.txt")"
run_stdout="$(cat "$SCRATCHPAD/out-$$.txt")"
run_stderr="$(cat "$SCRATCHPAD/err-$$.txt" 2>/dev/null || true)"
rm -f "$SCRATCHPAD/out-$$.txt" "$SCRATCHPAD/err-$$.txt" "$SCRATCHPAD/status-$$.txt"

# Dry-run shell-quotes args; match absolute path as substring. Also ensure
# we did not emit the inline-prompt form (-p ).
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--prompt-file" &&
	assert_contains "$run_stdout" "$tmp_brief" &&
	[[ "$tmp_brief" == /* ]] &&
	assert_not_contains "$run_stdout" "-p "; then
	pass "7 -f relative path expands to --prompt-file absolute; no -p"
else
	fail "7 -f relative path expands to --prompt-file absolute; no -p" \
		"status=$run_status stdout='$run_stdout' expected abs=$tmp_brief"
fi
rm -f "$tmp_brief"

# --- 8. -f on missing path: exit 2, error on stderr, no command on stdout ---
run_gd -n -f "$SCRATCHPAD/no-such-brief-$$.md"
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "brief file not found" &&
	[[ -z "$run_stdout" ]]; then
	pass "8 -f missing path exits 2 with error on stderr"
else
	fail "8 -f missing path exits 2 with error on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 9. Neither task nor -f: exit 2, error on stderr ---
run_gd -n
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "need a task string or --file" &&
	[[ -z "$run_stdout" ]]; then
	pass "9 neither task nor -f exits 2 with error on stderr"
else
	fail "9 neither task nor -f exits 2 with error on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 10. --dir on nonexistent directory: exit 2 ---
run_gd -n --dir "/no/such/dir/grok-delegate-test-$$" "do a thing"
if [[ $run_status -eq 2 ]] &&
	assert_contains "$run_stderr" "no such directory"; then
	pass "10 --dir nonexistent exits 2"
else
	fail "10 --dir nonexistent exits 2" \
		"status=$run_status stderr='$run_stderr'"
fi

# --- 11. --json emits --json-schema; default omits it ---
run_gd -n --json '{"type":"object"}' "do a thing"
json_ok=0
# Schema is shell-quoted in dry-run (braces/quotes escaped); match fragments.
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--json-schema" &&
	assert_contains "$run_stdout" "type" &&
	assert_contains "$run_stdout" "object"; then
	json_ok=1
fi
run_gd -n "do a thing"
def_json_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_not_contains "$run_stdout" "--json-schema"; then
	def_json_ok=1
fi
if [[ $json_ok -eq 1 && $def_json_ok -eq 1 ]]; then
	pass "11 --json emits --json-schema; default omits it"
else
	fail "11 --json emits --json-schema; default omits it" \
		"json_ok=$json_ok def_json_ok=$def_json_ok"
fi

# --- 12. -s emits --resume; default omits it ---
run_gd -n -s abc-123 "do a thing"
resume_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--resume" &&
	assert_contains "$run_stdout" "abc-123"; then
	resume_ok=1
fi
run_gd -n "do a thing"
def_resume_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_not_contains "$run_stdout" "--resume"; then
	def_resume_ok=1
fi
if [[ $resume_ok -eq 1 && $def_resume_ok -eq 1 ]]; then
	pass "12 -s emits --resume; default omits it"
else
	fail "12 -s emits --resume; default omits it" \
		"resume_ok=$resume_ok def_resume_ok=$def_resume_ok"
fi

# --- 13. --worktree without --worktree-ref: exit 2 (named and unnamed forms) ---
run_gd -n --worktree foo "do a thing"
named_ok=0
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "--worktree-ref"; then
	named_ok=1
fi
# Unnamed form: --worktree as last option before the task (next arg is not -*)
# so the task would be consumed as name if we put it next. Put --worktree last
# among options, then the task string starts with a letter so it becomes the name.
# Spec wants `--worktree` as last arg (no value) — that means no task either is
# fine for the error path, or we need a form where worktree has no value.
# Wrapper: if next arg is -* or absent, worktree=__unnamed__.
run_gd -n --worktree
unnamed_ok=0
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "--worktree-ref"; then
	unnamed_ok=1
fi
if [[ $named_ok -eq 1 && $unnamed_ok -eq 1 ]]; then
	pass "13 --worktree without --worktree-ref exits 2 (named + unnamed)"
else
	fail "13 --worktree without --worktree-ref exits 2 (named + unnamed)" \
		"named_ok=$named_ok unnamed_ok=$unnamed_ok named_stderr check"
fi

# --- 14. --worktree with --worktree-ref: named and unnamed forms ---
run_gd -n --worktree feat --worktree-ref main "do a thing"
named_wt_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--worktree" &&
	assert_contains "$run_stdout" "feat" &&
	assert_contains "$run_stdout" "--worktree-ref" &&
	assert_contains "$run_stdout" "main"; then
	named_wt_ok=1
fi
run_gd -n --worktree --worktree-ref main "do a thing"
unnamed_wt_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--worktree" &&
	assert_contains "$run_stdout" "--worktree-ref" &&
	assert_contains "$run_stdout" "main" &&
	assert_not_contains "$run_stdout" "__unnamed__"; then
	unnamed_wt_ok=1
fi
if [[ $named_wt_ok -eq 1 && $unnamed_wt_ok -eq 1 ]]; then
	pass "14 --worktree + --worktree-ref named and unnamed forms"
else
	fail "14 --worktree + --worktree-ref named and unnamed forms" \
		"named_wt_ok=$named_wt_ok unnamed_wt_ok=$unnamed_wt_ok"
fi

# --- 15. Unknown option --nope: exit 2 ---
run_gd -n --nope "do a thing"
if [[ $run_status -eq 2 ]] &&
	assert_contains "$run_stderr" "unknown option" &&
	[[ -z "$run_stdout" ]]; then
	pass "15 unknown option --nope exits 2"
else
	fail "15 unknown option --nope exits 2" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 16. -T and --sandbox overrides replace defaults ---
# --sandbox off skips the user-namespace probe (strict exits 2 on this host).
# Negative check uses the current default of 80, not the old 40.
run_gd -n -T 5 "do a thing"
turns_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" " --max-turns 5 " &&
	assert_not_contains "$run_stdout" " --max-turns 80 "; then
	turns_ok=1
fi
run_gd -n --sandbox off "do a thing"
sandbox_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--sandbox" &&
	assert_contains "$run_stdout" "off" &&
	assert_not_contains "$run_stdout" "--sandbox workspace"; then
	sandbox_ok=1
fi
if [[ $turns_ok -eq 1 && $sandbox_ok -eq 1 ]]; then
	pass "16 -T and --sandbox overrides replace defaults"
else
	fail "16 -T and --sandbox overrides replace defaults" \
		"turns_ok=$turns_ok sandbox_ok=$sandbox_ok status=$run_status stdout=$run_stdout stderr=$run_stderr"
fi

# --- 17. Dry-run stdout starts with cd and contains && grok ---
run_gd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	[[ "$run_stdout" == cd\ * ]] &&
	assert_contains "$run_stdout" " && grok"; then
	pass "17 dry-run stdout starts with cd and contains && grok"
else
	fail "17 dry-run stdout starts with cd and contains && grok" \
		"status=$run_status stdout=$run_stdout"
fi

# --- 18. --read-only adds path-scoped Edit/Write + git mutation denies ---
# Bare Edit/Write would also gate shell redirects and /tmp; path-scoped rules
# keep those usable. Dry-run %q turns Edit(/path/**) into Edit\(/path/\*\*) —
# match fragments that survive quoting.
ro_dir="$(mktemp -d "$SCRATCHPAD/ro-XXXXXX")"
git -C "$ro_dir" init -q
ro_phys="$(cd "$ro_dir" && pwd -P)"
run_gd -n --dir "$ro_dir" --read-only "do a thing"
# The dry-run is %q-quoted by the wrapper itself, so eval rebuilds the exact argv and
# each rule can be checked as a whole `--deny <rule>` pair, not as a loose substring.
eval "ro_argv=(${run_stdout#*&& grok })"
has_deny() {
	local i
	for ((i = 0; i + 1 < ${#ro_argv[@]}; i++)); do
		[[ "${ro_argv[i]}" == --deny && "${ro_argv[i + 1]}" == "$1" ]] && return 0
	done
	return 1
}
if [[ $run_status -eq 0 ]] &&
	has_deny "Edit(${ro_phys}/**)" &&
	has_deny "Write(${ro_phys}/**)" &&
	has_deny "Bash(git add*)" &&
	has_deny "Bash(git commit*)" &&
	has_deny "Bash(git checkout*)" &&
	! has_deny "Edit" && ! has_deny "Write"; then
	pass "18 --read-only emits path-scoped Edit/Write and git denies"
else
	fail "18 --read-only emits path-scoped Edit/Write and git denies" \
		"status=$run_status stdout=$run_stdout phys=$ro_phys"
fi

# --- 19. Bare Edit/Write denies are rejected; path-scoped Edit stays accepted ---
# A bare deny also blocks 2>/dev/null and /tmp writes — force --read-only instead.
bare_edit_ok=0
run_gd -n --deny Edit "do a thing"
if [[ $run_status -eq 2 ]] && assert_contains "$run_stderr" "--read-only"; then
	bare_edit_ok=1
fi
bare_write_ok=0
run_gd -n --deny "Write(**)" "do a thing"
if [[ $run_status -eq 2 ]] && assert_contains "$run_stderr" "--read-only"; then
	bare_write_ok=1
fi
scoped_ok=0
run_gd -n --deny "Edit(/some/dir/**)" "do a thing"
if [[ $run_status -eq 0 ]]; then
	scoped_ok=1
fi
if [[ $bare_edit_ok -eq 1 && $bare_write_ok -eq 1 && $scoped_ok -eq 1 ]]; then
	pass "19 bare Edit/Write denies exit 2; path-scoped Edit accepted"
else
	fail "19 bare Edit/Write denies exit 2; path-scoped Edit accepted" \
		"bare_edit_ok=$bare_edit_ok bare_write_ok=$bare_write_ok scoped_ok=$scoped_ok"
fi

# --- 20–23. Real mode via fake grok: ok / credit / crash / empty ---
# Never invoke the real grok binary; PATH puts the fake first. --sandbox off
# skips the namespace probe so the host's bwrap denial cannot exit 2.
install_fake_grok

# 20. ok: exit 0, report byte-identical to grok stdout (no trailer).
rep20="$SCRATCHPAD/r20.report"
FAKE_GROK_MODE=ok run_gd --sandbox off -o "$rep20" "do a thing"
printf 'final report\n' >"$SCRATCHPAD/expected20"
if [[ $run_status -eq 0 ]] && cmp -s "$rep20" "$SCRATCHPAD/expected20"; then
	pass "20 real-mode ok: exit 0, report byte-identical"
else
	fail "20 real-mode ok: exit 0, report byte-identical" \
		"status=$run_status report='$(cat "$rep20" 2>/dev/null || true)'"
fi

# 21. credit (402): exit 3, PROVIDER REFUSED on stderr, trailer has status + 402.
rep21="$SCRATCHPAD/r21.report"
FAKE_GROK_MODE=credit run_gd --sandbox off -o "$rep21" "do a thing"
if [[ $run_status -eq 3 ]] &&
	assert_contains "$run_stderr" "PROVIDER REFUSED" &&
	assert_contains "$(cat "$rep21")" "grok exited 1" &&
	assert_contains "$(cat "$rep21")" "status 402"; then
	pass "21 real-mode credit: exit 3, PROVIDER REFUSED, trailer has 402"
else
	fail "21 real-mode credit: exit 3, PROVIDER REFUSED, trailer has 402" \
		"status=$run_status stderr='$run_stderr' report='$(cat "$rep21" 2>/dev/null || true)'"
fi

# 22. crash: exit 7, trailer has boom, no PROVIDER REFUSED.
rep22="$SCRATCHPAD/r22.report"
FAKE_GROK_MODE=crash run_gd --sandbox off -o "$rep22" "do a thing"
if [[ $run_status -eq 7 ]] &&
	assert_contains "$(cat "$rep22")" "grok exited 7" &&
	assert_contains "$(cat "$rep22")" "boom" &&
	assert_not_contains "$run_stderr" "PROVIDER REFUSED"; then
	pass "22 real-mode crash: exit 7, trailer has boom, no refusal"
else
	fail "22 real-mode crash: exit 7, trailer has boom, no refusal" \
		"status=$run_status stderr='$run_stderr' report='$(cat "$rep22" 2>/dev/null || true)'"
fi

# 23. empty success: exit 1, trailer notes grok exited 0.
rep23="$SCRATCHPAD/r23.report"
FAKE_GROK_MODE=empty run_gd --sandbox off -o "$rep23" "do a thing"
if [[ $run_status -eq 1 ]] &&
	assert_contains "$(cat "$rep23")" "grok exited 0"; then
	pass "23 real-mode empty: exit 1, trailer has grok exited 0"
else
	fail "23 real-mode empty: exit 1, trailer has grok exited 0" \
		"status=$run_status report='$(cat "$rep23" 2>/dev/null || true)'"
fi

# --- 24. The wrapper waits for its tees to drain before judging the run ---
# The 402 lands on stderr just before grok exits. If the wrapper grepped the stderr
# copy before its tee drained, a credit outage would pass through as a plain exit 1
# with an empty trailer (pi-delegate had exactly that race on its report tee). Only
# the stderr copy is slowed: the report tee is a pipeline member the shell already
# waits for, and slowing it too would hide a missing wait on the stderr tee.
real_tee="$(command -v tee)"
slow_bin="$SCRATCHPAD/slowtee"
mkdir -p "$slow_bin"
printf '#!/usr/bin/env bash\ncase "$*" in *.stderr) sleep 1.5 ;; esac\nexec %q "$@"\n' "$real_tee" >"$slow_bin/tee"
chmod +x "$slow_bin/tee"
rep24="$SCRATCHPAD/r24.report"
rep24b="$SCRATCHPAD/r24b.report"
PATH="$slow_bin:$PATH" FAKE_GROK_MODE=ok run_gd --sandbox off -o "$rep24" "do a thing"
status24=$run_status
PATH="$slow_bin:$PATH" FAKE_GROK_MODE=credit run_gd --sandbox off -o "$rep24b" "do a thing"
if [[ $status24 -eq 0 ]] && cmp -s "$rep24" "$SCRATCHPAD/expected20" &&
	[[ $run_status -eq 3 ]] && assert_contains "$(cat "$rep24b")" "status 402"; then
	pass "24 slow tees: ok run still exit 0 with full report; credit still exit 3"
else
	fail "24 slow tees: ok run still exit 0 with full report; credit still exit 3" \
		"ok status=$status24 credit status=$run_status report='$(cat "$rep24b" 2>/dev/null || true)'"
fi

# --- 25. default sandbox, bwrap absent via override, real run: exit 2, marker absent ---
# Verifies preflight exits 2 without running grok when the bwrap lookup (via GROK_DELEGATE_BWRAP) fails on default sandbox.
marker25="$SCRATCHPAD/grok-ran-25"
stubdir25="$SCRATCHPAD/stubs-25"
mkdir -p "$stubdir25"
cat >"$stubdir25/grok" <<EOF
#!/usr/bin/env bash
touch "$marker25"
printf 'final report\n'
exit 0
EOF
chmod +x "$stubdir25/grok"
GROK_DELEGATE_BWRAP=grok-delegate-test-no-such-bwrap PATH="$stubdir25:$PATH" run_gd "do a thing"
if [[ $run_status -eq 2 ]] &&
	assert_contains "$run_stderr" "needs bubblewrap" &&
	[[ ! -f "$marker25" ]]; then
	pass "25 default sandbox, bwrap absent, real run: exits 2, warns, no grok run"
else
	fail "25 default sandbox, bwrap absent, real run: exits 2, warns, no grok run" \
		"status=$run_status stderr='$run_stderr' marker_present=$( [[ -f "$marker25" ]] && echo yes || echo no )"
fi

# --- 26. --sandbox off, bwrap absent via override, real run: no message, grok ran ---
# Verifies --sandbox off skips the bwrap preflight check (grok still runs even if lookup would fail).
marker26="$SCRATCHPAD/grok-ran-26"
stubdir26="$SCRATCHPAD/stubs-26"
mkdir -p "$stubdir26"
cat >"$stubdir26/grok" <<EOF
#!/usr/bin/env bash
touch "$marker26"
printf 'final report\n'
exit 0
EOF
chmod +x "$stubdir26/grok"
GROK_DELEGATE_BWRAP=grok-delegate-test-no-such-bwrap PATH="$stubdir26:$PATH" run_gd --sandbox off "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_not_contains "$run_stderr" "bubblewrap" &&
	assert_not_contains "$run_stderr" "needs bubblewrap" &&
	[[ -f "$marker26" ]]; then
	pass "26 --sandbox off, bwrap absent, real run: no bwrap msg, grok ran"
else
	fail "26 --sandbox off, bwrap absent, real run: no bwrap msg, grok ran" \
		"status=$run_status stderr='$run_stderr' marker=$( [[ -f "$marker26" ]] && echo yes || echo no )"
fi

# --- 27. default sandbox, bwrap absent via override, dry-run: 0 + cmd on stdout + WARNING on stderr ---
# Verifies dry-run path warns on stderr but still prints the full command and exits 0 (does not hard-fail).
GROK_DELEGATE_BWRAP=grok-delegate-test-no-such-bwrap run_gd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--sandbox workspace" &&
	assert_contains "$run_stderr" "WARNING:" &&
	assert_contains "$run_stderr" "needs bubblewrap"; then
	pass "27 default sandbox, bwrap absent, dry-run: 0, cmd on stdout, WARNING+needs on stderr"
else
	fail "27 default sandbox, bwrap absent, dry-run: 0, cmd on stdout, WARNING+needs on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 28. default sandbox, bwrap present via stub, real run: no message, grok ran ---
# Verifies that when bwrap is found on PATH (no override), preflight passes and grok is invoked.
marker28="$SCRATCHPAD/grok-ran-28"
stubdir28="$SCRATCHPAD/stubs-28"
mkdir -p "$stubdir28"
cat >"$stubdir28/grok" <<EOF
#!/usr/bin/env bash
touch "$marker28"
printf 'final report\n'
exit 0
EOF
chmod +x "$stubdir28/grok"
cat >"$stubdir28/bwrap" <<'BWRAP'
#!/usr/bin/env bash
exit 0
BWRAP
chmod +x "$stubdir28/bwrap"
PATH="$stubdir28:$PATH" run_gd "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_not_contains "$run_stderr" "bubblewrap" &&
	assert_not_contains "$run_stderr" "needs bubblewrap" &&
	[[ -f "$marker28" ]]; then
	pass "28 default sandbox, bwrap present, real run: no msg, grok ran"
else
	fail "28 default sandbox, bwrap present, real run: no msg, grok ran" \
		"status=$run_status stderr='$run_stderr' marker=$( [[ -f "$marker28" ]] && echo yes || echo no )"
fi

# --- 29. A short successful report draws a warning; a full-length one doesn't ---
# grok's plain mode has exited 0 with only its closing summary while the findings
# never reached stdout, and the run read as complete. The warning must not change
# the exit status, and must not fire on a report of real length.
rep29="$SCRATCHPAD/r29.report"
FAKE_GROK_MODE=ok run_gd --sandbox off -o "$rep29" "do a thing"
status29=$run_status
stderr29=$run_stderr
FAKE_GROK_MODE=long run_gd --sandbox off -o "$SCRATCHPAD/r29b.report" "do a thing"
if [[ $status29 -eq 0 ]] && assert_contains "$stderr29" "report is only 13 bytes" &&
	[[ $run_status -eq 0 ]] && assert_not_contains "$run_stderr" "report is only"; then
	pass "29 short report warns without changing exit; long report stays quiet"
else
	fail "29 short report warns without changing exit; long report stays quiet" \
		"short status=$status29 stderr='$stderr29' long status=$run_status stderr='$run_stderr'"
fi

# --- 30. relative -o/--report resolves against caller's cwd, not -C dir ---
# A relative -o must be interpreted in the directory from which the wrapper was
# invoked, even when -C points elsewhere. The wrapper truncates the report before
# it cds into -C and appends after, so an unresolved relative path splits the
# report across two files and leaves the caller's copy empty.
# Uses --sandbox off like other real-mode cases.
caller30="$SCRATCHPAD/c30"
other30="$SCRATCHPAD/o30"
mkdir -p "$caller30" "$other30"
install_fake_grok
stdout_f="$(mktemp)"; stderr_f="$(mktemp)"
set +e
(cd "$caller30" && FAKE_GROK_MODE=ok TMPDIR="$SCRATCHPAD" "$GROK_DELEGATE" --sandbox off -C "$other30" -o rel.report "do a thing") >"$stdout_f" 2>"$stderr_f"
run_status=$?
set -e
run_stdout="$(cat "$stdout_f")"; run_stderr="$(cat "$stderr_f")"
rm -f "$stdout_f" "$stderr_f"
rep30="$caller30/rel.report"
printf 'final report\n' >"$SCRATCHPAD/expected30"
if [[ $run_status -eq 0 ]] &&
   assert_contains "$(cat "$rep30")" "final report" &&
   ! [[ -f "$other30/rel.report" ]]; then
	pass "30 relative report resolves to caller cwd (not -C); contains full stdout, none in workdir"
else
	fail "30 relative report resolves to caller cwd (not -C); contains full stdout, none in workdir" \
		"status=$run_status rep=$(ls -l $caller30/ 2>/dev/null || true) other=$(ls -l $other30/ 2>/dev/null || true) report='$(cat "$rep30" 2>/dev/null || true)'"
fi

# --- 31. FAKE_CHEZMOI_STATUS=1 prints the exact drift warning on stderr (real run) ---
# The warning must appear when chezmoi verify fails, but must not change the
# exit status of a successful run.
install_fake_grok
FAKE_CHEZMOI_STATUS=1 FAKE_CHEZMOI_LOG="$SCRATCHPAD/chezmoi31.log" run_gd --sandbox off "do a thing"
if [[ $run_status -eq 0 ]] &&
   assert_contains "$run_stderr" "delegate: the installed delegate skill or wrappers differ from the chezmoi source. Review with 'chezmoi diff ~/.claude/skills/delegate ~/bin', then 'chezmoi apply' those paths."; then
	pass "31 FAKE_CHEZMOI_STATUS=1 emits exact warning on stderr, exit remains 0"
else
	fail "31 FAKE_CHEZMOI_STATUS=1 emits exact warning on stderr, exit remains 0" \
		"status=$run_status stderr='$run_stderr'"
fi

# --- 32. FAKE_CHEZMOI_STATUS=0 prints no drift warning ---
# When verify would succeed (or no chezmoi), no warning line on stderr.
install_fake_grok
FAKE_CHEZMOI_STATUS=0 run_gd --sandbox off "do a thing"
if [[ $run_status -eq 0 ]] &&
   assert_not_contains "$run_stderr" "delegate: the installed"; then
	pass "32 FAKE_CHEZMOI_STATUS=0 prints no 'delegate: the installed' line"
else
	fail "32 FAKE_CHEZMOI_STATUS=0 prints no 'delegate: the installed' line" \
		"status=$run_status stderr='$run_stderr'"
fi

echo
echo "Results: $pass_count passed, $fail_count failed"
if [[ $fail_count -gt 0 ]]; then
	exit 1
fi
exit 0
