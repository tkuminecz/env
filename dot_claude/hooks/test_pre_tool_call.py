"""Tests for pre_tool_call.py. Run: python3 test_pre_tool_call.py"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(HOOKS_DIR))
# chezmoi would deploy a __pycache__ left next to the hook.
sys.dont_write_bytecode = True

import pre_tool_call


class RecursiveRmDangerTest(unittest.TestCase):
    """The rm check only speaks up for deletes you could not undo."""

    def setUp(self):
        # A fake home with a repo in it, so tests control what exists on disk.
        self.root = tempfile.mkdtemp()
        self.home = os.path.join(self.root, "home")
        self.repo = os.path.join(self.home, "projects", "app")
        self.scratch_root = os.path.join(self.root, "tmp")
        os.makedirs(os.path.join(self.repo, ".git"))
        os.makedirs(os.path.join(self.repo, "node_modules"))
        os.makedirs(os.path.join(self.repo, "app.egg-info"))
        os.makedirs(os.path.join(self.repo, "web", "node_modules"))
        os.makedirs(os.path.join(self.repo, "pkg", "__pycache__"))
        os.makedirs(os.path.join(self.home, ".cache", "pip"))
        os.makedirs(os.path.join(self.scratch_root, "pytest-of-tim"))

    def tearDown(self):
        shutil.rmtree(self.root)

    def danger(self, command, cwd=None, env=None):
        return pre_tool_call.recursive_rm_danger(
            command,
            cwd or self.repo,
            home=self.home,
            env=env or {},
            temp_roots=[self.scratch_root],
        )

    # --- deletes that must be blocked ---

    def test_blocks_filesystem_root(self):
        # The classic disaster; nothing else matters if this slips through.
        self.assertIsNotNone(self.danger("rm -rf /"))

    def test_blocks_home_directory_in_every_spelling(self):
        # ~, $HOME and the literal path all name the same irreplaceable dir.
        for cmd in ("rm -rf ~", "rm -rf $HOME", f"rm -rf {self.home}/"):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.danger(cmd, env={"HOME": self.home}), cmd)

    def test_blocks_top_level_system_directory(self):
        # /usr exists on every box this runs on; wiping it bricks the machine.
        self.assertIsNotNone(self.danger("rm -rf /usr"))

    def test_blocks_top_level_folder_in_home(self):
        # ~/projects holds every repo; one level down from home is too broad.
        self.assertIsNotNone(self.danger("rm -rf ~/projects"))

    def test_blocks_whole_repository_and_its_history(self):
        # Unpushed commits, stashes and branches live only in .git.
        self.assertIsNotNone(self.danger("rm -rf .git"))
        self.assertIsNotNone(self.danger(f"rm -rf {self.repo}"))

    def test_blocks_glob_that_empties_home(self):
        # `cd ~ && rm -rf *` never names home, but deletes all of it.
        self.assertIsNotNone(self.danger("cd ~ && rm -rf *"))

    def test_blocks_path_built_from_unknown_variable(self):
        # If $DIR is empty at runtime this becomes `rm -rf /*`.
        self.assertIsNotNone(self.danger('rm -rf "$DIR/"*'))

    def test_uses_variable_assigned_earlier_in_same_command(self):
        # $D is set in the command itself, so we know it points at home.
        self.assertIsNotNone(self.danger(f"D={self.home}; rm -rf $D"))

    def test_sees_through_flag_spellings_and_wrappers(self):
        # Split flags, long flags, -R, full path to rm, sudo and `--` all
        # still run a recursive delete of /.
        for cmd in (
            "rm -r -f /",
            "rm --recursive /",
            "rm -Rf /",
            "/bin/rm -rf /",
            "sudo rm -rf /",
            "rm -rf -- /",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.danger(cmd), cmd)

    def test_sees_later_commands_in_a_chain(self):
        # A harmless first command must not hide a dangerous second one.
        for cmd in ("ls; rm -rf ~", "true && rm -rf ~", "echo hi\nrm -rf ~"):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.danger(cmd), cmd)

    def test_sees_into_nested_shell(self):
        # `bash -c '...'` runs its string as a command, so check it too.
        self.assertIsNotNone(self.danger("bash -c 'rm -rf ~'"))

    def test_trailing_comment_does_not_hide_next_line(self):
        # Agents annotate lines with `# ...`; the comment ends at the newline,
        # so the next line is still a command. A mid-word `#` (as in $#) is
        # not a comment at all.
        for cmd in (
            f"cd {self.repo}  # repo root\nrm -rf .git",
            "echo $#; rm -rf ~",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.danger(cmd), cmd)

    def test_quoted_angle_bracket_is_not_a_redirect(self):
        # A quoted ">" is text; treating it as a redirect swallowed the `;`
        # and glued the rm onto the echo.
        self.assertIsNotNone(self.danger('echo ">"; rm -rf ~'))

    def test_shift_operator_is_not_a_heredoc(self):
        # `<<` in arithmetic has no end marker below it, so nothing after it
        # may be dropped as heredoc body.
        self.assertIsNotNone(self.danger("echo $((1 << n))\nrm -rf ~"))

    def test_escaped_heredoc_marker_is_recognised(self):
        # `<<\EOF` is a heredoc too; its body (with a stray apostrophe) must
        # be dropped, or parsing fails and the rm after it goes unchecked.
        cmd = "cat > notes.txt <<\\EOF\nit's fine\nEOF\nrm -rf ~"
        self.assertIsNotNone(self.danger(cmd))

    def test_blocks_git_dir_even_when_its_location_is_unknown(self):
        # We can't see what `git rev-parse` prints, but a target named .git
        # is repository history wherever it lives.
        for cmd in (
            'ROOT=$(git rev-parse --show-toplevel); rm -rf "$ROOT/.git"',
            'ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" && rm -rf .git',
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.danger(cmd), cmd)

    def test_cd_to_empty_variable_means_home(self):
        # An unquoted empty `cd $X` is plain `cd`, which goes home, so this
        # is `rm -rf ~/*` when PROJECT_DIR is unset.
        self.assertIsNotNone(self.danger("cd $PROJECT_DIR && rm -rf *"))

    def test_expands_brace_lists(self):
        # {a,b} names each path separately; here one of them is a whole repo.
        self.assertIsNotNone(self.danger("rm -rf ~/projects/{app,other}"))
        self.assertIsNone(self.danger("rm -rf {node_modules,dist}"))

    def test_uses_default_of_unset_variable(self):
        # ${TARGET:-$HOME} falls back to home when TARGET is unset.
        self.assertIsNotNone(self.danger('rm -rf "${TARGET:-$HOME}"'))

    def test_pwd_follows_cd(self):
        # $PWD is wherever the command has cd'd to, not the hook's own dir.
        cmd = f'cd {self.repo}/node_modules && rm -rf "$PWD"/*'
        self.assertIsNone(self.danger(cmd))

    def test_glob_matching_a_home_folder_is_blocked(self):
        # ~/.c* matches ~/.cache (and ~/.config, ~/.claude on a real box).
        self.assertIsNotNone(self.danger("rm -rf ~/.c*"))

    def test_reason_names_the_path(self):
        # A specific reason lets the agent (and Tim) see what was at stake.
        reason = self.danger("rm -rf ~/projects")
        self.assertIn(os.path.join(self.home, "projects"), reason)

    # --- everyday deletes that must stay quiet ---

    def test_ignores_rm_mentioned_in_text(self):
        # grep patterns, echo strings and PR comment bodies are not commands.
        for cmd in (
            'grep -c "rm -rf" ORCHESTRATION.md',
            "echo 'never run rm -rf ~'",
            'gh pr comment 1 --body "Superseded: the rm -rf ~ rule"',
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.danger(cmd), cmd)

    def test_ignores_rm_inside_heredoc_body(self):
        # Heredoc bodies are data for another program, not shell commands.
        cmd = "python3 - <<'EOF'\nrule = '''\nrm -rf ~\n'''\nEOF\necho done"
        self.assertIsNone(self.danger(cmd))

    def test_ignores_rm_in_comment(self):
        # Shell comments never run.
        self.assertIsNone(self.danger("# rm -rf ~\nls"))

    def test_allows_scratch_and_temp_dirs(self):
        # Agents clean their scratchpads constantly; these are disposable.
        scratch = os.path.join(self.scratch_root, "claude", "scratchpad")
        for cmd in (f"rm -rf {scratch}/copy", f"S={scratch}; rm -rf $S/*"):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.danger(cmd), cmd)

    def test_allows_build_output_inside_repo(self):
        # node_modules, target dirs and generated files are rebuildable.
        for cmd in (
            "rm -rf node_modules && pnpm install",
            f"cd {self.repo} && rm -rf target-before",
            "rm -rf crates/gym/findings/run-*",
            "find . -name __pycache__ -exec rm -rf {} +",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.danger(cmd), cmd)

    def test_globs_are_judged_by_what_they_match(self):
        # These globs sit in a repo root or directly in a temp root, but
        # only match build output or scratch dirs, so nothing is at stake.
        for cmd in (
            "rm -rf build/ dist/ *.egg-info",
            "rm -rf */node_modules",
            "rm -rf **/__pycache__",
            f"rm -rf {self.scratch_root}/pytest-*",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.danger(cmd), cmd)

    def test_ignores_comment_after_command(self):
        # A comment or a quoted "#" that mentions rm is not an rm.
        for cmd in ("ls # rm -rf ~", 'echo "# rm -rf ~"'):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.danger(cmd), cmd)

    def test_allows_deep_paths_in_home(self):
        # Two levels under home is specific enough to leave to the normal
        # permission flow instead of blocking outright.
        self.assertIsNone(self.danger("rm -rf ~/.cache/pip"))

    def test_ignores_non_recursive_rm(self):
        # Plain rm cannot remove directories, so it cannot wipe a tree.
        self.assertIsNone(self.danger("rm ~"))
        self.assertIsNone(self.danger("rm -f ~/notes.txt"))

    def test_unparseable_command_is_left_alone(self):
        # Bash would reject this too; the hook must not crash or block.
        self.assertIsNone(self.danger('rm -rf "unterminated'))


class SqlDropTest(unittest.TestCase):
    """The DROP check only asks when a database client would run the drop."""

    def drop(self, command):
        return pre_tool_call.sql_drop(
            command, "/home/u/projects/app", home="/home/u", env={}
        )

    def test_flags_drop_sent_to_a_database_client(self):
        # SQL given to a client as an argument, a heredoc or a pipe, even
        # through docker or bash -c, really runs.
        for cmd in (
            'psql "$DATABASE_URL" -c "DROP TABLE users"',
            "psql -c 'drop database reader_test'",
            'docker compose exec -T db psql -U postgres -c "DROP SCHEMA public CASCADE"',
            "psql <<'EOF'\nDROP TABLE users;\nEOF",
            'echo "DROP TABLE users;" | psql',
            'sqlite3 app.db "DROP TABLE users"',
            'mysql -e "DROP DATABASE app"',
            "bash -c 'psql -c \"DROP TABLE x\"'",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNotNone(self.drop(cmd), cmd)

    def test_reason_quotes_the_statement(self):
        # Seeing which table is at stake makes the prompt worth reading.
        reason = self.drop('psql -c "DROP TABLE users; SELECT 1"')
        self.assertIn("DROP TABLE users", reason)

    def test_ignores_drop_that_no_client_runs(self):
        # Docs, grep patterns, commit messages and migration files being
        # written all mention DROP TABLE without running it; the old regex
        # fired on every one of these.
        for cmd in (
            "cat > docs/schema.md <<'EOF'\nNever run DROP TABLE on prod.\nEOF",
            'grep -rn "DROP TABLE" migrations/',
            'git commit -m "fix: drop table creation race"',
            "cat > migrations/0003.sql <<'EOF'\nDROP TABLE old;\nEOF",
        ):
            with self.subTest(cmd=cmd):
                self.assertIsNone(self.drop(cmd), cmd)

    def test_ignores_client_running_other_sql(self):
        # Running psql is normal; only a drop is worth a prompt.
        self.assertIsNone(self.drop('psql -c "SELECT count(*) FROM users"'))


class CheckRulesTest(unittest.TestCase):
    """rules.json entries can still use a plain regex instead of a check."""

    def test_regex_pattern_rule_matches(self):
        # No shipped rule uses a regex any more, but the format supports it
        # and a new rule may be written that way.
        rule = {"tool": "Bash", "pattern": r"terraform\s+destroy", "severity": "warn"}
        self.assertEqual(
            pre_tool_call.check_rules([rule], "Bash", "terraform destroy"), rule
        )
        self.assertIsNone(pre_tool_call.check_rules([rule], "Bash", "terraform plan"))


class HookEndToEndTest(unittest.TestCase):
    """Runs the hook the way Claude Code does, with the shipped rules.json."""

    def setUp(self):
        self.home = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.home, ".claude"))
        shutil.copy(
            HOOKS_DIR.parent / "rules.json",
            os.path.join(self.home, ".claude", "rules.json"),
        )

    def tearDown(self):
        shutil.rmtree(self.home)

    def run_hook(self, command):
        payload = {
            "tool_name": "Bash",
            "tool_input": {"command": command},
            "cwd": self.home,
        }
        result = subprocess.run(
            [sys.executable, str(HOOKS_DIR / "pre_tool_call.py")],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env={**os.environ, "HOME": self.home},
            check=True,
        )
        return json.loads(result.stdout) if result.stdout.strip() else None

    def test_dangerous_rm_is_denied_with_reason(self):
        # Deny (not ask) so an unattended agent is told why instead of
        # stalling on a prompt nobody will answer.
        out = self.run_hook("rm -rf /")["hookSpecificOutput"]
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertIn("/", out["permissionDecisionReason"])

    def test_everyday_rm_produces_no_decision(self):
        # No output means the normal permission flow decides, as for any
        # other command.
        self.assertIsNone(self.run_hook("rm -rf /tmp/some-scratch/out"))

    def test_env_reads_are_not_guarded(self):
        # Reading .env files is deliberately allowed: the guard prompted far
        # more often than it helped, so there is no .env rule at all.
        self.assertIsNone(self.run_hook("cat .env"))

    def test_drop_in_docs_is_quiet_but_drop_via_psql_asks(self):
        # The shipped rules.json wires the DROP check: a grep for DROP TABLE
        # passes, a drop sent to psql still asks.
        self.assertIsNone(self.run_hook('grep -rn "DROP TABLE" docs/'))
        out = self.run_hook('psql -c "DROP TABLE users"')["hookSpecificOutput"]
        self.assertEqual(out["permissionDecision"], "ask")

    def test_force_pushes_are_not_guarded(self):
        # Force pushing is deliberately allowed: the prompt interrupted
        # routine rebased-branch updates, so there is no force-push rule.
        self.assertIsNone(self.run_hook("git push origin main --force"))
        self.assertIsNone(self.run_hook("git push -f origin feature"))


if __name__ == "__main__":
    unittest.main()
