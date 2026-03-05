#!/usr/bin/env python3
"""Claude Code Notify - Uninstaller.

Removes hook scripts, settings.json entries, CLAUDE_TTY from shell profiles,
and marker files.
"""

import glob
import json
import os
from pathlib import Path

HOOKS_DIR: Path = Path.home() / ".claude" / "hooks"
SETTINGS_FILE: Path = Path.home() / ".claude" / "settings.json"
ITERM2_AUTOLAUNCH_DIR: Path = (
    Path.home() / "Library" / "Application Support" / "iTerm2" / "Scripts" / "AutoLaunch"
)

HOOK_FILES: list[str] = ["tab_title.py", "notify.py"]
ITERM2_SCRIPTS: list[str] = ["focus_clear_prefix.py"]

UNINSTALL_COMMENT: str = "# Claude Code Notify - uninstall command"

COMMAND_PREFIXES: list[str] = [
    "~/.claude/hooks/tab_title.py",
    "~/.claude/hooks/notify.py",
]


def remove_hook_files() -> None:
    """Remove hook script files."""
    for filename in HOOK_FILES:
        hook_file: Path = HOOKS_DIR / filename
        if hook_file.exists():
            hook_file.unlink()
            print(f"✓ Removed {hook_file}")


def command_is_ours(command: str) -> bool:
    """Check if a command belongs to claude-code-notify."""
    return any(command.startswith(prefix) for prefix in COMMAND_PREFIXES)


def clean_settings() -> None:
    """Remove hook entries and env settings from settings.json."""
    if not SETTINGS_FILE.exists():
        return

    with open(SETTINGS_FILE) as f:
        settings: dict = json.load(f)

    hooks: dict = settings.get("hooks", {})

    for event_name in list(hooks.keys()):
        filtered: list[dict] = []
        for entry in hooks[event_name]:
            entry_hooks: list[dict] = entry.get("hooks", [])
            remaining: list[dict] = [
                h for h in entry_hooks if not command_is_ours(h.get("command", ""))
            ]
            if remaining:
                entry["hooks"] = remaining
                filtered.append(entry)
        if filtered:
            hooks[event_name] = filtered
        else:
            del hooks[event_name]

    env: dict = settings.get("env", {})
    env.pop("CLAUDE_CODE_DISABLE_TERMINAL_TITLE", None)

    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"✓ Removed hook configuration from {SETTINGS_FILE}")


def remove_claude_tty_from_profile(profile_path: Path) -> None:
    """Remove CLAUDE_TTY lines from a shell profile."""
    if not profile_path.exists():
        return

    content: str = profile_path.read_text()
    if "CLAUDE_TTY" not in content:
        return

    lines: list[str] = content.splitlines(keepends=True)
    filtered: list[str] = []
    skip_next: bool = False

    for line in lines:
        if "# Claude Code Notify - tab title support" in line:
            skip_next = True
            continue
        if skip_next and "CLAUDE_TTY" in line:
            skip_next = False
            continue
        if "export CLAUDE_TTY" in line:
            continue
        skip_next = False
        filtered.append(line)

    profile_path.write_text("".join(filtered))
    print(f"✓ Removed CLAUDE_TTY from {profile_path}")


def remove_uninstall_function(profile_path: Path) -> None:
    """Remove uninstall_claude_code_notify function from a shell profile."""
    if not profile_path.exists():
        return

    content: str = profile_path.read_text()
    if "uninstall_claude_code_notify" not in content:
        return

    lines: list[str] = content.splitlines(keepends=True)
    filtered: list[str] = []
    inside_func: bool = False

    for line in lines:
        if UNINSTALL_COMMENT in line:
            inside_func = True
            continue
        if inside_func:
            if line.rstrip() == "}":
                inside_func = False
                continue
            continue
        filtered.append(line)

    if inside_func:
        raise RuntimeError(
            f"Malformed uninstall block in {profile_path}: missing closing brace."
        )
    profile_path.write_text("".join(filtered))
    print(f"✓ Removed uninstall_claude_code_notify from {profile_path}")


def clean_shell_profiles() -> None:
    """Remove CLAUDE_TTY and uninstall function from all shell profiles."""
    home: Path = Path.home()
    remove_claude_tty_from_profile(home / ".zshrc")
    remove_claude_tty_from_profile(home / ".bashrc")
    remove_claude_tty_from_profile(home / ".bash_profile")
    remove_uninstall_function(home / ".zshrc")


def remove_iterm2_scripts() -> None:
    """Remove iTerm2 AutoLaunch scripts."""
    for filename in ITERM2_SCRIPTS:
        script: Path = ITERM2_AUTOLAUNCH_DIR / filename
        if script.exists(follow_symlinks=False):
            script.unlink()
            print(f"✓ Removed {script}")


def clean_marker_files() -> None:
    """Remove marker files from /tmp."""
    for marker in glob.glob("/tmp/claude-iterm2-title-*"):
        Path(marker).unlink(missing_ok=True)
    print("✓ Cleaned up marker files")


def main() -> None:
    print("🔔 Claude Code Notify - Uninstaller\n")

    remove_hook_files()
    clean_settings()
    clean_shell_profiles()
    remove_iterm2_scripts()
    clean_marker_files()

    print("\n🎉 Uninstall complete!")


if __name__ == "__main__":
    main()
