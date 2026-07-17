#!/usr/bin/env python3
"""Safety hook for Claude Code PreToolUse events.

Reads hook input from stdin, checks tool calls against configurable
regex rules in rules.json, and outputs a permission decision.
"""

import json
import re
import sys
from pathlib import Path

RULES_PATH = Path.home() / ".claude" / "rules.json"


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


def check_rules(rules: list[dict], tool_name: str, match_text: str) -> dict | None:
    """Check match_text against rules. Returns the highest-severity match or None.

    "block" beats "warn" — if any matching rule blocks, that wins.
    """
    best_match = None
    for rule in rules:
        rule_tool = rule.get("tool")
        if rule_tool and rule_tool != tool_name:
            continue

        pattern = rule.get("pattern")
        if not pattern:
            continue

        try:
            compiled = re.compile(pattern)
        except re.error as e:
            rule_name = rule.get("name", pattern)
            print(
                f"Error: invalid regex in rule '{rule_name}': {e}",
                file=sys.stderr,
            )
            sys.exit(1)

        if compiled.search(match_text):
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

    matched_rule = check_rules(rules, tool_name, match_text)
    if matched_rule:
        output = make_decision(matched_rule)
        print(json.dumps(output))


if __name__ == "__main__":
    main()
