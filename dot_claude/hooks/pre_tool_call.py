#!/usr/bin/env python3
"""Safety hook for Claude Code PreToolUse events.

Reads hook input from stdin, checks tool calls against the rules in
rules.json, and outputs a permission decision. A rule either matches a
regex `pattern` or runs a named `check` for cases a regex can't judge.
"""

import glob
import itertools
import json
import os
import re
import shlex
import sys
from collections.abc import Iterator
from pathlib import Path

RULES_PATH = Path.home() / ".claude" / "rules.json"

# Words that can come before a command without being the command.
_KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "}"}
# Commands that run the rest of their words as another command.
_WRAPPERS = {
    "sudo",
    "doas",
    "command",
    "builtin",
    "exec",
    "nohup",
    "env",
    "nice",
    "timeout",
    "time",
    "xargs",
}
_SHELLS = {"bash", "sh", "zsh", "dash"}
_DECLARATIONS = {"export", "local", "declare", "readonly", "typeset"}
_PUNCTUATION = "();<>|&\n"
_ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.DOTALL)
_DURATION = re.compile(r"^\d+(\.\d+)?[smhd]?$")
_HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*\\?(['\"]?)([^\s'\"();<>|&\\]+)\1")
# ${NAME}, ${NAME:-default} (also -, :=, =) and $NAME.
_VARIABLE = re.compile(
    r"\$(?:\{([A-Za-z_][A-Za-z0-9_]*)(?:(:?[-=])([^}]*))?\}|([A-Za-z_][A-Za-z0-9_]*))"
)
_BRACES = re.compile(r"(?<!\$)\{([^{}]*,[^{}]*)\}")
_GLOB_CHARS = set("*?[")


def _strip_heredoc_bodies(command: str) -> str:
    """Drop heredoc bodies: they are input for another program, not shell.

    A `<<` with no end marker below it (e.g. a shift in `$((1 << n))`) is
    not a heredoc, so nothing is dropped for it.
    """
    lines = command.split("\n")
    kept, i = [], 0
    while i < len(lines):
        line = lines[i]
        kept.append(line)
        i += 1
        for match in _HEREDOC.finditer(line):
            end = next(
                (j for j in range(i, len(lines)) if lines[j].strip() == match.group(2)),
                None,
            )
            if end is not None:
                i = end + 1
    return "\n".join(kept)


def _strip_comments(command: str) -> str:
    """Drop `#` comments the way bash does: only at the start of a word,
    outside quotes, and never the newline that ends them."""
    out, i, quote, n = [], 0, None, len(command)
    while i < n:
        c = command[i]
        if quote:
            out.append(c)
            if c == "\\" and quote == '"' and i + 1 < n:
                out.append(command[i + 1])
                i += 1
            elif c == quote:
                quote = None
        elif c == "\\" and i + 1 < n:
            out.append(c)
            out.append(command[i + 1])
            i += 1
        elif c in "'\"":
            quote = c
            out.append(c)
        elif c == "#" and (i == 0 or command[i - 1] in " \t\n;&|()<>"):
            while i < n and command[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def _split_commands(command: str) -> list[list[str]] | None:
    """Split a shell command line into simple commands, each a list of words.

    Quoted text stays one word, so `grep "rm -rf"` is a grep, not an rm.
    Returns None when the line can't be parsed (e.g. unbalanced quotes).
    """
    command = _strip_comments(_strip_heredoc_bodies(command.replace("\\\n", " ")))
    lexer = shlex.shlex(command, posix=True, punctuation_chars=_PUNCTUATION)
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError:
        return None

    commands, words, skip_next = [], [], False
    for token in tokens:
        if token and set(token) <= set(_PUNCTUATION):
            # A redirect's file is not an argument. It only ever skips a
            # word, so a quoted ">" can't swallow the `;` after it.
            skip_next = "<" in token or ">" in token
            if not skip_next and words:
                commands.append(words)
                words = []
        elif skip_next:
            skip_next = False
        else:
            words.append(token)
    if words:
        commands.append(words)
    return commands


def _expand_braces(word: str, limit: int = 64) -> list[str]:
    """Expand {a,b} lists into one word per option, as bash does."""
    match = _BRACES.search(word)
    if not match:
        return [word]
    words = []
    for option in match.group(1).split(","):
        words += _expand_braces(word[: match.start()] + option + word[match.end() :])
        if len(words) >= limit:
            break
    return words[:limit]


def _is_within(path: str, parent: str) -> bool:
    return path == parent or path.startswith(parent.rstrip("/") + "/")


_GIT_HISTORY = "a git repository's history (unpushed commits, stashes, branches)"


def _deny_reason(raw: str, path: str, why: str) -> str:
    return (
        f"`rm -r {raw}` would delete {path}, {why}. "
        "If this is really intended, ask the user to run it."
    )


class _ShellWalker:
    """Walks the simple commands in a command line, tracking `cd` and
    variables. Unknown variables are treated as empty, the worst case."""

    def __init__(self, home: str, env: dict):
        self.home = home
        self.env = {**env, "HOME": home}
        # None means "set from command output at runtime": unknown, non-empty.
        self.assigned: dict[str, str | None] = {}
        self.pwd: str | None = None

    def commands(
        self, command: str, cwd: str | None
    ) -> Iterator[tuple[str, list[str], str | None]]:
        """Yield (name, args, cwd) for each command that runs, looking
        inside `bash -c` and `eval`."""
        commands = _split_commands(command)
        if commands is None:
            # shlex can't read some valid bash; walk each line it can read.
            lines = command.split("\n")
            if len(lines) > 1:
                for line in lines:
                    yield from self.commands(line, cwd)
            return
        for words in commands:
            self.pwd = cwd
            words = self._command_words(words)
            if not words:
                continue
            name, args = os.path.basename(words[0]), words[1:]
            if name in ("cd", "pushd"):
                cwd = self._cd(args, cwd)
            elif name == "popd":
                cwd = None
            elif name in _DECLARATIONS:
                for arg in args:
                    self._assign(arg)
            elif name in _SHELLS and self._shell_script(args) is not None:
                yield from self.commands(self._shell_script(args), cwd)
            elif name == "eval":
                yield from self.commands(" ".join(args), cwd)
            else:
                yield name, args, cwd

    def _command_words(self, words: list[str]) -> list[str]:
        """Skip keywords, assignments and wrappers like sudo to reach the
        command that actually runs."""
        i = 0
        while i < len(words):
            word = words[i]
            if word in _KEYWORDS:
                i += 1
            elif _ASSIGNMENT.match(word):
                self._assign(word)
                i += 1
            elif os.path.basename(word) in _WRAPPERS:
                i += 1
                while i < len(words) and (
                    words[i].startswith("-")
                    or _ASSIGNMENT.match(words[i])
                    or _DURATION.match(words[i])
                ):
                    i += 1
            else:
                break
        return words[i:]

    def _assign(self, word: str) -> None:
        match = _ASSIGNMENT.match(word)
        if not match:
            return
        name, value = match.groups()
        # `X=$(cmd)` lexes as `X=$` then `(`: the value is command output.
        self.assigned[name] = None if value.endswith("$") else self.expand(value)

    def expand(self, word: str) -> str | None:
        """Expand ~ and $VARS. Returns None if the result depends on
        command output we can't see."""
        if word == "~" or word.startswith("~/"):
            word = self.home + word[1:]
        runtime_only = False

        def lookup(match: re.Match) -> str:
            nonlocal runtime_only
            name = match.group(1) or match.group(4)
            if name in self.assigned:
                value = self.assigned[name]
            elif name == "PWD":
                value = self.pwd
            else:
                value = self.env.get(name, "")
            if not value and value is not None and match.group(2):
                value = self.expand(match.group(3))  # ${NAME:-default}
            if value is None:
                runtime_only = True
                return ""
            return value

        expanded = _VARIABLE.sub(lookup, word)
        return None if runtime_only else expanded

    def _absolute(self, path: str, cwd: str | None) -> str | None:
        if os.path.isabs(path):
            return os.path.normpath(path)
        if cwd is None:
            return None
        return os.path.normpath(os.path.join(cwd, path))

    def _cd(self, args: list[str], cwd: str | None) -> str | None:
        targets = [a for a in args if not a.startswith("-") or a == "-"]
        if not targets:
            return self.home
        target = self.expand(targets[0])
        if target is None or target == "-":
            return None
        if not target:
            return self.home  # `cd $EMPTY` is plain `cd`
        return self._absolute(target, cwd)

    @staticmethod
    def _shell_script(args: list[str]) -> str | None:
        """The script string from `bash -c 'script'`, if there is one."""
        for i, arg in enumerate(args):
            if arg.startswith("-") and not arg.startswith("--") and "c" in arg:
                rest = [a for a in args[i + 1 :] if not a.startswith("-")]
                return rest[0] if rest else None
        return None


class _RecursiveRmCheck(_ShellWalker):
    """Judges each `rm -r` target in a command line."""

    def __init__(self, home: str, env: dict, temp_roots: list[str]):
        super().__init__(home, env)
        self.temp_roots = temp_roots

    def check(self, command: str, cwd: str | None) -> str | None:
        for name, args, command_cwd in self.commands(command, cwd):
            if name == "rm":
                reason = self._check_rm(args, command_cwd)
                if reason:
                    return reason
        return None

    def _check_rm(self, args: list[str], cwd: str | None) -> str | None:
        recursive, targets, options_done = False, [], False
        for arg in args:
            if options_done or arg == "-" or not arg.startswith("-"):
                targets.append(arg)
            elif arg == "--":
                options_done = True
            elif arg.startswith("--"):
                recursive |= arg == "--recursive"
            else:
                recursive |= bool(set(arg[1:]) & {"r", "R"})
        if not recursive:
            return None
        for target in targets:
            for word in _expand_braces(target):
                reason = self._target_danger(word, cwd)
                if reason:
                    return reason
        return None

    def _target_danger(self, raw: str, cwd: str | None) -> str | None:
        expanded = self.expand(raw)
        if expanded == "":
            return None  # an empty word deletes nothing
        path = self._absolute(expanded, cwd) if expanded else None
        if path is None:
            # Where it points is unknown, but .git is history wherever it is.
            if os.path.basename((expanded or raw).rstrip("/")) == ".git":
                return _deny_reason(raw, raw, _GIT_HISTORY)
            return None
        for target in self._glob_targets(path):
            why = self._why_irreplaceable(target)
            if why:
                return _deny_reason(raw, target, why)
        return None

    @staticmethod
    def _glob_targets(path: str) -> list[str]:
        """What a path deletes once bash expands its globs. A bare * or .*
        empties its directory, which counts as deleting the directory;
        any other glob is judged by what it matches on disk right now."""
        if not set(path) & _GLOB_CHARS:
            return [path]
        parent, name = os.path.split(path)
        if name in ("*", ".*", "**") and not set(parent) & _GLOB_CHARS:
            return [parent]
        return list(itertools.islice(glob.iglob(path), 1000))

    def _why_irreplaceable(self, path: str) -> str | None:
        if path == "/":
            return "the root of the filesystem"
        if _is_within(self.home, path):
            return (
                "your home directory"
                if path == self.home
                else "which contains your home directory"
            )
        if any(_is_within(path, t) and path != t for t in self.temp_roots):
            return None
        parent = os.path.dirname(path)
        if parent == "/" and os.path.exists(path):
            return "a top-level system directory"
        if parent == self.home and os.path.exists(path):
            return "a top-level folder in your home directory"
        if os.path.basename(path) == ".git":
            return _GIT_HISTORY
        if os.path.exists(os.path.join(path, ".git")):
            return "a whole git repository, including its history"
        return None


def recursive_rm_danger(
    command: str,
    cwd: str | None,
    *,
    home: str | None = None,
    env: dict | None = None,
    temp_roots: list[str] | None = None,
) -> str | None:
    """Return why a recursive rm in `command` can't be undone, or None.

    Only speaks up for deletes that would be a disaster: /, top-level system
    dirs, home or a folder directly in it, a git repo or its .git. Anything
    strictly inside a temp dir is fine. Every other rm is left to the normal
    permission flow.
    """
    env = dict(os.environ if env is None else env)
    home = os.path.normpath(home or os.path.expanduser("~"))
    if temp_roots is None:
        temp_roots = ["/tmp", "/var/tmp"] + (
            [env["TMPDIR"]] if env.get("TMPDIR") else []
        )
    temp_roots = [os.path.normpath(t) for t in temp_roots]
    return _RecursiveRmCheck(home, env, temp_roots).check(command, cwd)


def _new_walker(home: str | None, env: dict | None) -> _ShellWalker:
    env = dict(os.environ if env is None else env)
    return _ShellWalker(os.path.normpath(home or os.path.expanduser("~")), env)


# Database clients that run the SQL they are given.
_SQL_CLIENTS = {
    "psql",
    "pgcli",
    "mysql",
    "mariadb",
    "mycli",
    "sqlite3",
    "duckdb",
    "clickhouse",
    "clickhouse-client",
    "usql",
    "sqlcmd",
    "snowsql",
    "cockroach",
    "bq",
}
_SQL_DROP = re.compile(r"\bDROP\s+(?:TABLE|DATABASE|SCHEMA)\b[^;\n'\"]*", re.IGNORECASE)


def sql_drop(
    command: str,
    cwd: str | None,
    *,
    home: str | None = None,
    env: dict | None = None,
) -> str | None:
    """Return why `command` would drop a table, database or schema, or None.

    Only counts when a database client runs in the command, directly or via
    `docker exec`, `kubectl exec` or `bash -c`, with the SQL as an argument,
    heredoc or pipe. DROP TABLE in docs, grep patterns, commit messages or a
    migration file being written is fine.
    """
    drop = _SQL_DROP.search(command)
    if not drop:
        return None
    walker = _new_walker(home, env)
    for name, args, _ in walker.commands(command, cwd):
        for word in (name, *args):
            if os.path.basename(word) in _SQL_CLIENTS:
                client = os.path.basename(word)
                return f"`{client}` would run `{drop.group(0).strip()}`."
    return None


CHECKS = {
    "recursive-rm": recursive_rm_danger,
    "sql-drop": sql_drop,
}


def load_rules(rules_path: Path) -> list[dict]:
    """Load safety rules from JSON file. Returns empty list if missing or invalid."""
    if not rules_path.exists():
        return []
    try:
        data = json.loads(rules_path.read_text())
        return data.get("rules", [])
    except (json.JSONDecodeError, OSError):
        return []


def get_match_text(tool_name: str, tool_input: dict) -> str | None:
    """Extract the text to match against rules based on tool type."""
    if tool_name == "Bash":
        return tool_input.get("command")
    elif tool_name in ("Write", "Edit"):
        return tool_input.get("file_path")
    return None


def check_rules(
    rules: list[dict], tool_name: str, match_text: str, cwd: str | None = None
) -> dict | None:
    """Check match_text against rules. Returns the highest-severity match or None.

    "block" beats "warn" — if any matching rule blocks, that wins. A named
    check's reason replaces the rule's description.
    """
    best_match = None
    for rule in rules:
        rule_tool = rule.get("tool")
        if rule_tool and rule_tool != tool_name:
            continue

        rule_name = rule.get("name", "")
        check = rule.get("check")
        pattern = rule.get("pattern")
        if check:
            if check not in CHECKS:
                print(
                    f"Error: unknown check '{check}' in rule '{rule_name}'",
                    file=sys.stderr,
                )
                sys.exit(1)
            try:
                reason = CHECKS[check](match_text, cwd)
            except Exception as e:  # noqa: BLE001 — a buggy check must not break every tool call
                print(f"Error: check '{check}' failed: {e!r}", file=sys.stderr)
                continue
            if reason is None:
                continue
            rule = {**rule, "description": reason}
        elif pattern:
            try:
                compiled = re.compile(pattern)
            except re.error as e:
                print(
                    f"Error: invalid regex in rule '{rule_name or pattern}': {e}",
                    file=sys.stderr,
                )
                sys.exit(1)
            if not compiled.search(match_text):
                continue
        else:
            continue

        if rule.get("severity") == "block":
            return rule
        if best_match is None:
            best_match = rule

    return best_match


def make_decision(rule: dict) -> dict:
    """Build the hook output JSON for a matched rule."""
    severity = rule.get("severity", "warn")
    decision = "deny" if severity == "block" else "ask"
    reason = rule.get("description", rule.get("name", "Safety rule triggered"))
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }


def main() -> None:
    try:
        hook_input = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, OSError):
        # Can't parse input — allow by default
        return

    tool_name = hook_input.get("tool_name", "")
    tool_input = hook_input.get("tool_input", {})

    match_text = get_match_text(tool_name, tool_input)
    if match_text is None:
        # Tool type not checked — allow
        return

    rules = load_rules(RULES_PATH)
    if not rules:
        return

    cwd = hook_input.get("cwd")
    matched_rule = check_rules(rules, tool_name, match_text, cwd)
    if matched_rule:
        output = make_decision(matched_rule)
        print(json.dumps(output))


if __name__ == "__main__":
    main()
