#!/usr/bin/env bash
# Self-contained test suite for ~/bin/grok-delegate (dry-run only).
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
	"$GROK_DELEGATE" "$@" >"$stdout_f" 2>"$stderr_f"
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

# --- 1. Default invocation emits core flags ---
run_gd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--model" &&
	assert_contains "$run_stdout" "grok-4.5" &&
	assert_contains "$run_stdout" "--permission-mode" &&
	assert_contains "$run_stdout" "bypassPermissions" &&
	assert_contains "$run_stdout" "--sandbox" &&
	assert_contains "$run_stdout" "workspace" &&
	assert_contains "$run_stdout" " --max-turns 40 " &&
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
run_gd -n -T 5 "do a thing"
turns_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" " --max-turns 5 " &&
	assert_not_contains "$run_stdout" " --max-turns 40 "; then
	turns_ok=1
fi
run_gd -n --sandbox strict "do a thing"
sandbox_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--sandbox" &&
	assert_contains "$run_stdout" "strict" &&
	assert_not_contains "$run_stdout" "--sandbox workspace"; then
	sandbox_ok=1
fi
if [[ $turns_ok -eq 1 && $sandbox_ok -eq 1 ]]; then
	pass "16 -T and --sandbox overrides replace defaults"
else
	fail "16 -T and --sandbox overrides replace defaults" \
		"turns_ok=$turns_ok sandbox_ok=$sandbox_ok"
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

echo
echo "Results: $pass_count passed, $fail_count failed"
if [[ $fail_count -gt 0 ]]; then
	exit 1
fi
exit 0
