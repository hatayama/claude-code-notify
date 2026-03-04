#!/usr/bin/env python3
"""Update terminal tab title to reflect Claude Code working state.

Usage: tab_title.py on|off|ask|done

  on   -> prefix title with ⚡ (processing)
  done -> prefix title with ✅ (completed)
  ask  -> prefix title with ❓ (waiting for permission)
  off  -> show title without prefix

Requires CLAUDE_TTY environment variable (e.g. export CLAUDE_TTY=$(tty))
"""

import json
import os
import subprocess
import sys
from pathlib import Path

PREFIXES: dict[str, str] = {
    "on": os.environ.get("CLAUDE_NOTIFY_PREFIX_ON", "⚡"),
    "done": os.environ.get("CLAUDE_NOTIFY_PREFIX_DONE", "✅"),
    "ask": os.environ.get("CLAUDE_NOTIFY_PREFIX_ASK", "❓"),
}


def read_hook_context() -> dict[str, str]:
    """Read JSON hook context from stdin."""
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return {}


def get_title_from_cwd(cwd: str) -> str:
    """Get display title from cwd: git repo name or directory basename."""
    result: subprocess.CompletedProcess[str] = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    if result.returncode == 0 and result.stdout.strip():
        return os.path.basename(result.stdout.strip())
    return os.path.basename(cwd)


def marker_file_path(tty_path: str) -> Path:
    """Get marker file path for the given TTY."""
    sanitized: str = tty_path.replace("/", "-")
    return Path(f"/tmp/claude-iterm2-title-{sanitized}")


def write_tab_title(tty_path: str, title_text: str) -> None:
    """Write ANSI escape sequence to set terminal tab title."""
    if not os.access(tty_path, os.W_OK):
        return
    with open(tty_path, "w") as f:
        f.write(f"\033]0;{title_text}\007")


def main() -> None:
    action: str = sys.argv[1] if len(sys.argv) > 1 else "on"

    target_tty: str = os.environ.get("CLAUDE_TTY", "")
    if not target_tty:
        sys.exit(0)

    context: dict[str, str] = read_hook_context()
    cwd: str = context.get("cwd", "") or os.environ.get("PWD", "")
    if not cwd:
        sys.exit(0)

    title: str = get_title_from_cwd(cwd)
    prefix: str = PREFIXES.get(action, "")
    marker: Path = marker_file_path(target_tty)

    write_tab_title(target_tty, f"{prefix}{title}")

    if action in PREFIXES:
        marker.write_text(f"{action}\n{title}")
    else:
        marker.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
