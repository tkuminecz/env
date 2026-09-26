#!/usr/bin/env bash
# Self-contained test suite for ~/bin/pi-delegate (dry-run only).
set -u

PI_DELEGATE="${PI_DELEGATE:-$HOME/bin/pi-delegate}"
# Scratch dir for the temp brief and captured output. Deliberately NOT the
# script's own directory — this suite is installed into ~/bin, which should
# not collect stray files mid-run.
SCRATCHPAD="$(mktemp -d)"
trap 'rm -rf "$SCRATCHPAD"' EXIT
GATE="$HOME/.pi/agent/git/github.com/tkuminecz/pi-kit/extensions/permission-gate.ts"

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

# Run pi-delegate; capture stdout, stderr, and exit status into globals.
run_pd() {
	local stdout_f stderr_f
	stdout_f="$(mktemp)"
	stderr_f="$(mktemp)"
	set +e
	"$PI_DELEGATE" "$@" >"$stdout_f" 2>"$stderr_f"
	run_status=$?
	set -e
	run_stdout="$(cat "$stdout_f")"
	run_stderr="$(cat "$stderr_f")"
	rm -f "$stdout_f" "$stderr_f"
}

assert_contains() {
	# $1 haystack $2 needle $3 case label suffix
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

# --- 1. Default invocation resolves to --provider xai --model grok-4.6 ---
# Every bare `pi-delegate "<task>"` call gets the default, so a wrong default silently
# moves all delegation to another model or provider.
run_pd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider" &&
	assert_contains "$run_stdout" "xai" &&
	assert_contains "$run_stdout" "--model" &&
	assert_contains "$run_stdout" "grok-4.6"; then
	pass "1 default provider/model is xai / grok-4.6"
else
	fail "1 default provider/model is xai / grok-4.6" "status=$run_status stdout=$run_stdout"
fi

# --- 2. --thinking low is present by default ---
run_pd -n "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--thinking" &&
	assert_contains "$run_stdout" "low"; then
	pass "2 default --thinking low is present"
else
	fail "2 default --thinking low is present" "status=$run_status stdout=$run_stdout"
fi

# --- 3. glm-* -> zai; grok-* -> xai ---
run_pd -n -m glm-5.2 "do a thing"
glm_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider" &&
	assert_contains "$run_stdout" "zai" &&
	assert_contains "$run_stdout" "glm-5.2"; then
	glm_ok=1
fi
run_pd -n -m grok-build-0.1 "do a thing"
grok_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider" &&
	assert_contains "$run_stdout" "xai" &&
	assert_contains "$run_stdout" "grok-build-0.1"; then
	grok_ok=1
fi
if [[ $glm_ok -eq 1 && $grok_ok -eq 1 ]]; then
	pass "3 glm-* routes to zai; grok-* routes to xai"
else
	fail "3 glm-* routes to zai; grok-* routes to xai" "glm_ok=$glm_ok grok_ok=$grok_ok"
fi

# --- 4. Unrecognized model exits 2; error on stderr not stdout ---
# An id no arm matches must fail loudly (exit 2, message on stderr) instead of guessing
# a provider; llama-4 is used because glm*, grok*, gpt* and vendor/model ids all route.
run_pd -n -m llama-4 "do a thing"
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "cannot infer provider" &&
	[[ -z "$run_stdout" ]]; then
	pass "4 unrecognized model exits 2 with error on stderr"
else
	fail "4 unrecognized model exits 2 with error on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 5. --file on missing path exits 2 with error on stderr ---
run_pd -n --file "$SCRATCHPAD/no-such-brief-$$.md"
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "brief file not found" &&
	[[ -z "$run_stdout" || "$run_stdout" != *"pi"* ]]; then
	pass "5 --file missing path exits 2 with error on stderr"
else
	fail "5 --file missing path exits 2 with error on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 6. --file existing file: prompt contains absolute path from relative path ---
tmp_brief="$SCRATCHPAD/tmp-brief-$$.md"
printf 'test brief\n' >"$tmp_brief"
# No local EXIT trap here — the suite-wide one above removes the whole scratch
# dir, and re-trapping EXIT would clobber it.

# Invoke with a path relative to SCRATCHPAD by cd'ing there
set +e
(
	cd "$SCRATCHPAD" || exit 99
	rel_name="$(basename "$tmp_brief")"
	"$PI_DELEGATE" -n --file "$rel_name" >"$SCRATCHPAD/out-$$.txt" 2>"$SCRATCHPAD/err-$$.txt"
	echo $? >"$SCRATCHPAD/status-$$.txt"
)
set -e
run_status="$(cat "$SCRATCHPAD/status-$$.txt")"
run_stdout="$(cat "$SCRATCHPAD/out-$$.txt")"
run_stderr="$(cat "$SCRATCHPAD/err-$$.txt" 2>/dev/null || true)"
rm -f "$SCRATCHPAD/out-$$.txt" "$SCRATCHPAD/err-$$.txt" "$SCRATCHPAD/status-$$.txt"

# Dry-run shell-quotes the prompt (spaces -> '\ '), so match the absolute
# path as a substring rather than the unquoted full sentence.
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "$tmp_brief" &&
	[[ "$tmp_brief" == /* ]] &&
	assert_contains "$run_stdout" "Read" &&
	assert_contains "$run_stdout" "execute" &&
	assert_contains "$run_stdout" "brief"; then
	pass "6 --file relative path expands to absolute path in prompt"
else
	fail "6 --file relative path expands to absolute path in prompt" \
		"status=$run_status stdout='$run_stdout' expected abs=$tmp_brief"
fi
rm -f "$tmp_brief"

# --- 7. Neither task nor --file exits 2 with error on stderr ---
run_pd -n
if [[ $run_status -eq 2 ]] &&
	[[ -n "$run_stderr" ]] &&
	assert_contains "$run_stderr" "need a task string or --file" &&
	[[ -z "$run_stdout" ]]; then
	pass "7 neither task nor --file exits 2 with error on stderr"
else
	fail "7 neither task nor --file exits 2 with error on stderr" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 8. --session puts --session-id; default has --no-session ---
run_pd -n --session 12345678-1234-1234-1234-123456789abc "do a thing"
sess_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--session-id" &&
	assert_contains "$run_stdout" "12345678-1234-1234-1234-123456789abc" &&
	assert_not_contains "$run_stdout" "--no-session"; then
	sess_ok=1
fi
run_pd -n "do a thing"
def_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--no-session" &&
	assert_not_contains "$run_stdout" "--session-id"; then
	def_ok=1
fi
if [[ $sess_ok -eq 1 && $def_ok -eq 1 ]]; then
	pass "8 --session vs default --no-session"
else
	fail "8 --session vs default --no-session" "sess_ok=$sess_ok def_ok=$def_ok"
fi

# --- 9. --json adds --mode json; default does not ---
run_pd -n --json "do a thing"
json_ok=0
# Match '--mode json' as a pair; bare '--mode' is a prefix of '--model'.
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--mode json"; then
	json_ok=1
fi
run_pd -n "do a thing"
def_json_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_not_contains "$run_stdout" "--mode json"; then
	def_json_ok=1
fi
if [[ $json_ok -eq 1 && $def_json_ok -eq 1 ]]; then
	pass "9 --json adds --mode json; default omits it"
else
	fail "9 --json adds --mode json; default omits it" "json_ok=$json_ok def_json_ok=$def_json_ok stdout_default check"
fi

# --- 10. --dir on nonexistent directory exits 2 ---
run_pd -n --dir "/no/such/dir/pi-delegate-test-$$" "do a thing"
if [[ $run_status -eq 2 ]] &&
	assert_contains "$run_stderr" "no such directory"; then
	pass "10 --dir nonexistent exits 2"
else
	fail "10 --dir nonexistent exits 2" \
		"status=$run_status stderr='$run_stderr'"
fi

# --- 11. permission-gate extension passed via -e when gate file exists ---
run_pd -n "do a thing"
if [[ -f "$GATE" ]]; then
	if [[ $run_status -eq 0 ]] &&
		assert_contains "$run_stdout" "-e" &&
		assert_contains "$run_stdout" "$GATE"; then
		pass "11 permission-gate extension passed via -e (gate present)"
	else
		fail "11 permission-gate extension passed via -e (gate present)" \
			"status=$run_status stdout=$run_stdout"
	fi
else
	# Gate missing: wrapper should warn on stderr and omit -e GATE
	if [[ $run_status -eq 0 ]] &&
		assert_contains "$run_stderr" "permission-gate extension missing" &&
		assert_not_contains "$run_stdout" "$GATE"; then
		pass "11 permission-gate missing: warning on stderr, no -e gate (gate absent on machine)"
	else
		fail "11 permission-gate missing path" \
			"status=$run_status stdout=$run_stdout stderr=$run_stderr"
	fi
fi

# --- 12. unknown option exits 2 rather than being forwarded ---
run_pd -n --nope "do a thing"
if [[ $run_status -eq 2 ]] &&
	assert_contains "$run_stderr" "unknown option" &&
	[[ -z "$run_stdout" ]]; then
	pass "12 unknown option --nope exits 2"
else
	fail "12 unknown option --nope exits 2" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 13. the inline task string actually reaches the command as the prompt ---
# Without this, dropping "$prompt" from the final exec leaves every case above
# green except the --file one: the wrapper's core job would be untested.
run_pd -n "sentinel-task-marker-xyz"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "sentinel-task-marker-xyz"; then
	pass "13 inline task string is passed through as the prompt"
else
	fail "13 inline task string is passed through as the prompt" \
		"status=$run_status stdout='$run_stdout'"
fi

# --- 14. vendor/model ids route to openrouter ---
# OpenRouter model ids are always "<vendor>/<model>", so the slash is what marks
# them; the id must reach pi unchanged because OpenRouter needs the vendor prefix.
run_pd -n -m openai/gpt-6-luna "do a thing"
luna_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openrouter" &&
	assert_contains "$run_stdout" "--model openai/gpt-6-luna"; then
	luna_ok=1
fi
run_pd -n -m deepseek/deepseek-v4-flash-0731 "do a thing"
ds_ok=0
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openrouter" &&
	assert_contains "$run_stdout" "--model deepseek/deepseek-v4-flash-0731"; then
	ds_ok=1
fi
if [[ $luna_ok -eq 1 && $ds_ok -eq 1 ]]; then
	pass "14 vendor/model ids route to openrouter with the id unchanged"
else
	fail "14 vendor/model ids route to openrouter with the id unchanged" \
		"luna_ok=$luna_ok ds_ok=$ds_ok stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 15. a z.ai model id with a vendor prefix still goes to openrouter, not zai ---
# glm models are also sold on OpenRouter as "z-ai/glm-*"; the prefix means the
# caller chose OpenRouter billing, so the glm* rule must not capture it.
run_pd -n -m z-ai/glm-5.3 "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openrouter" &&
	assert_not_contains "$run_stdout" "--provider zai"; then
	pass "15 z-ai/glm-* routes to openrouter, not zai"
else
	fail "15 z-ai/glm-* routes to openrouter, not zai" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 16. gpt-* routes to openai-codex ---
# gpt-* ids must reach the flat-rate openai-codex subscription; falling through to
# openrouter would bill per token for the same model.
run_pd -n -m gpt-5.6-luna "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openai-codex" &&
	assert_contains "$run_stdout" "--model gpt-5.6-luna" &&
	assert_not_contains "$run_stdout" "--provider openrouter"; then
	pass "16 gpt-* routes to openai-codex"
else
	fail "16 gpt-* routes to openai-codex" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

echo
echo "Results: $pass_count passed, $fail_count failed"
if [[ $fail_count -gt 0 ]]; then
	exit 1
fi
exit 0
