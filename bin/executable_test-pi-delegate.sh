#!/usr/bin/env bash
# Self-contained test suite for pi-delegate (dry-run + fake-binary real mode).
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

# Install a fake pi on PATH whose behaviour is selected by FAKE_PI_MODE.
# Also installs a chezmoi stub (exits ${FAKE_CHEZMOI_STATUS:-0}, logs argv to
# $FAKE_CHEZMOI_LOG when set) so tests never depend on real chezmoi state.
install_fake_pi() {
	local fake_bin="$SCRATCHPAD/fakebin-pi"
	mkdir -p "$fake_bin"
	cat >"$fake_bin/pi" <<'FAKE'
#!/usr/bin/env bash
case "${FAKE_PI_MODE:-ok}" in
ok)
	printf 'final report\n'
	exit 0
	;;
refuse)
	echo 'Error: 429 Too Many Requests' >&2
	exit 1
	;;
crash)
	echo 'boom' >&2
	exit 7
	;;
*)
	echo "fake pi: unknown FAKE_PI_MODE=${FAKE_PI_MODE}" >&2
	exit 99
	;;
esac
FAKE
	chmod +x "$fake_bin/pi"
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

# --- 14–16. Real mode via fake pi: ok / 429 refusal / crash ---
# Watchdog path (default) so stderr is captured; fake exits immediately.
# -m glm-5.2 => provider zai => refusal must suggest grok-delegate.
install_fake_pi

# 14. ok: exit 0, report byte-identical to pi stdout (no trailer).
rep14="$SCRATCHPAD/p14.report"
hb14="$SCRATCHPAD/p14.heartbeat"
FAKE_PI_MODE=ok run_pd -m glm-5.2 -o "$rep14" --heartbeat "$hb14" "do a thing"
printf 'final report\n' >"$SCRATCHPAD/expected14"
if [[ $run_status -eq 0 ]] && cmp -s "$rep14" "$SCRATCHPAD/expected14"; then
	pass "14 real-mode ok: exit 0, report byte-identical"
else
	fail "14 real-mode ok: exit 0, report byte-identical" \
		"status=$run_status report='$(cat "$rep14" 2>/dev/null || true)' stderr='$run_stderr'"
fi

# 15. 429 refusal: exit 3, PROVIDER REFUSED names zai, suggests grok-delegate.
rep15="$SCRATCHPAD/p15.report"
hb15="$SCRATCHPAD/p15.heartbeat"
FAKE_PI_MODE=refuse run_pd -m glm-5.2 -o "$rep15" --heartbeat "$hb15" "do a thing"
if [[ $run_status -eq 3 ]] &&
	assert_contains "$run_stderr" "PROVIDER REFUSED" &&
	assert_contains "$run_stderr" "zai" &&
	assert_contains "$run_stderr" "grok-delegate" &&
	assert_contains "$(cat "$rep15")" "pi exited 1" &&
	assert_contains "$(cat "$rep15")" "429"; then
	pass "15 real-mode 429: exit 3, suggests grok-delegate"
else
	fail "15 real-mode 429: exit 3, suggests grok-delegate" \
		"status=$run_status stderr='$run_stderr' report='$(cat "$rep15" 2>/dev/null || true)'"
fi

# 16. crash: exit 7, trailer has boom, no PROVIDER REFUSED.
rep16="$SCRATCHPAD/p16.report"
hb16="$SCRATCHPAD/p16.heartbeat"
FAKE_PI_MODE=crash run_pd -m glm-5.2 -o "$rep16" --heartbeat "$hb16" "do a thing"
if [[ $run_status -eq 7 ]] &&
	assert_contains "$(cat "$rep16")" "pi exited 7" &&
	assert_contains "$(cat "$rep16")" "boom" &&
	assert_not_contains "$run_stderr" "PROVIDER REFUSED"; then
	pass "16 real-mode crash: exit 7, trailer has boom, no refusal"
else
	fail "16 real-mode crash: exit 7, trailer has boom, no refusal" \
		"status=$run_status stderr='$run_stderr' report='$(cat "$rep16" 2>/dev/null || true)'"
fi

# --- 17. The wrapper waits for its tees to drain before judging the run ---
# pi's final answer is written just before it exits, so the report tee can still be
# copying when the wrapper checks for an empty report. A bare `wait` does not wait for
# process substitutions, and that race turned a successful run into "empty report,
# exit 1". A tee that sleeps before copying makes the race deterministic.
real_tee="$(command -v tee)"
slow_bin="$SCRATCHPAD/slowtee"
mkdir -p "$slow_bin"
printf '#!/usr/bin/env bash\nsleep 1\nexec %q "$@"\n' "$real_tee" >"$slow_bin/tee"
chmod +x "$slow_bin/tee"
rep17="$SCRATCHPAD/p17.report"
rep17b="$SCRATCHPAD/p17b.report"
PATH="$slow_bin:$PATH" FAKE_PI_MODE=ok run_pd -m glm-5.2 -o "$rep17" --heartbeat "$SCRATCHPAD/p17.hb" "do a thing"
status17=$run_status
PATH="$slow_bin:$PATH" FAKE_PI_MODE=refuse run_pd -m glm-5.2 -o "$rep17b" --heartbeat "$SCRATCHPAD/p17b.hb" "do a thing"
if [[ $status17 -eq 0 ]] && cmp -s "$rep17" "$SCRATCHPAD/expected14" && [[ $run_status -eq 3 ]]; then
	pass "17 slow tees: ok run still exit 0 with full report; refusal still exit 3"
else
	fail "17 slow tees: ok run still exit 0 with full report; refusal still exit 3" \
		"ok status=$status17 report='$(cat "$rep17" 2>/dev/null || true)' refuse status=$run_status"
fi

# --- 18. vendor/model ids route to openrouter ---
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
	pass "18 vendor/model ids route to openrouter with the id unchanged"
else
	fail "18 vendor/model ids route to openrouter with the id unchanged" \
		"luna_ok=$luna_ok ds_ok=$ds_ok stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 19. a z.ai model id with a vendor prefix still goes to openrouter, not zai ---
# glm models are also sold on OpenRouter as "z-ai/glm-*"; the prefix means the
# caller chose OpenRouter billing, so the glm* rule must not capture it.
run_pd -n -m z-ai/glm-5.3 "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openrouter" &&
	assert_not_contains "$run_stdout" "--provider zai"; then
	pass "19 z-ai/glm-* routes to openrouter, not zai"
else
	fail "19 z-ai/glm-* routes to openrouter, not zai" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 20. gpt-* routes to openai-codex ---
# gpt-* ids must reach the flat-rate openai-codex subscription; falling through to
# openrouter would bill per token for the same model.
run_pd -n -m gpt-5.6-luna "do a thing"
if [[ $run_status -eq 0 ]] &&
	assert_contains "$run_stdout" "--provider openai-codex" &&
	assert_contains "$run_stdout" "--model gpt-5.6-luna" &&
	assert_not_contains "$run_stdout" "--provider openrouter"; then
	pass "20 gpt-* routes to openai-codex"
else
	fail "20 gpt-* routes to openai-codex" \
		"status=$run_status stdout='$run_stdout' stderr='$run_stderr'"
fi

# --- 21. relative -o/--report and --heartbeat resolve against caller's cwd, not -C dir ---
# A relative path on -o or --heartbeat must be interpreted in the directory from
# which the wrapper was invoked, even when -C points elsewhere. This prevents the
# report from landing inside the workdir (or a different file being truncated).
# We follow the byte-identical pattern of case 14.
caller21="$SCRATCHPAD/c21"
other21="$SCRATCHPAD/o21"
mkdir -p "$caller21" "$other21"
install_fake_pi
stdout_f="$(mktemp)"; stderr_f="$(mktemp)"
set +e
(cd "$caller21" && FAKE_PI_MODE=ok "$PI_DELEGATE" -C "$other21" -o rel.report --heartbeat rel.hb "do a thing") >"$stdout_f" 2>"$stderr_f"
run_status=$?
set -e
run_stdout="$(cat "$stdout_f")"; run_stderr="$(cat "$stderr_f")"
rm -f "$stdout_f" "$stderr_f"
rep21="$caller21/rel.report"
hb21="$caller21/rel.hb"
printf 'final report\n' >"$SCRATCHPAD/expected21"
if [[ $run_status -eq 0 ]] && cmp -s "$rep21" "$SCRATCHPAD/expected21" &&
   [[ -f "$hb21" ]] &&
   ! [[ -f "$other21/rel.report" ]] && ! [[ -f "$other21/rel.hb" ]]; then
	pass "21 relative report/heartbeat resolve to caller cwd (not -C); files match expected, none in workdir"
else
	fail "21 relative report/heartbeat resolve to caller cwd (not -C); files match expected, none in workdir" \
		"status=$run_status rep=$(ls -l $caller21/ 2>/dev/null || true) other=$(ls -l $other21/ 2>/dev/null || true) report='$(cat "$rep21" 2>/dev/null || true)'"
fi

# --- 22. FAKE_CHEZMOI_STATUS=1 prints the exact drift warning on stderr (real run) ---
# The warning must appear when chezmoi verify fails, but must not change the
# exit status of a successful run.
install_fake_pi
FAKE_CHEZMOI_STATUS=1 FAKE_CHEZMOI_LOG="$SCRATCHPAD/chezmoi22.log" run_pd -m glm-5.2 "do a thing"
if [[ $run_status -eq 0 ]] &&
   assert_contains "$run_stderr" "delegate: the installed delegate skill or wrappers differ from the chezmoi source. Review with 'chezmoi diff ~/.claude/skills/delegate ~/bin', then 'chezmoi apply' those paths."; then
	pass "22 FAKE_CHEZMOI_STATUS=1 emits exact warning on stderr, exit remains 0"
else
	fail "22 FAKE_CHEZMOI_STATUS=1 emits exact warning on stderr, exit remains 0" \
		"status=$run_status stderr='$run_stderr'"
fi

# --- 23. FAKE_CHEZMOI_STATUS=0 prints no drift warning ---
# When verify would succeed (or no chezmoi), no warning line on stderr.
install_fake_pi
FAKE_CHEZMOI_STATUS=0 run_pd -m glm-5.2 "do a thing"
if [[ $run_status -eq 0 ]] &&
   assert_not_contains "$run_stderr" "delegate: the installed"; then
	pass "23 FAKE_CHEZMOI_STATUS=0 prints no 'delegate: the installed' line"
else
	fail "23 FAKE_CHEZMOI_STATUS=0 prints no 'delegate: the installed' line" \
		"status=$run_status stderr='$run_stderr'"
fi

# --- 24. dry-run never invokes chezmoi (no drift check side effects) ---
# A dry run only prints the command; checking chezmoi there would print the drift
# warning on every -n call. The log path goes on the run_pd line so the stub sees it.
log24="$SCRATCHPAD/chezmoi24.log"
FAKE_CHEZMOI_LOG="$log24" FAKE_CHEZMOI_STATUS=1 run_pd -n "do a thing"
if [[ $run_status -eq 0 ]] && [[ ! -s "$log24" ]] &&
	assert_not_contains "$run_stderr" "delegate: the installed"; then
	pass "24 dry-run -n never calls chezmoi"
else
	fail "24 dry-run -n never calls chezmoi" \
		"status=$run_status log='$(cat "$log24" 2>/dev/null || true)' stderr='$run_stderr'"
fi

echo
echo "Results: $pass_count passed, $fail_count failed"
if [[ $fail_count -gt 0 ]]; then
	exit 1
fi
exit 0
