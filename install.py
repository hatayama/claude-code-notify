#!/usr/bin/env python3
"""Claude Code Notify - Installer.

Idempotent: safe to re-run for updates (git pull && python3 install.py)
Zero external dependencies (uses python3 and osascript, both macOS built-in)

Usage:
  python3 install.py [--source-dir DIR]

Options:
  --source-dir DIR  Directory containing hooks/ subdirectory (default: script's own directory)
"""

import argparse
import json
import os
import shutil
import stat
import sys
from pathlib import Path

HOOKS_DIR: Path = Path.home() / ".claude" / "hooks"
SETTINGS_FILE: Path = Path.home() / ".claude" / "settings.json"
ITERM2_AUTOLAUNCH_DIR: Path = (
    Path.home() / "Library" / "Application Support" / "iTerm2" / "Scripts" / "AutoLaunch"
)

HOOK_FILES: list[str] = ["tab_title.py", "notify.py"]
ITERM2_SCRIPTS: list[str] = ["focus_clear_prefix.py"]

CLAUDE_TTY_LINE: str = "export CLAUDE_TTY=$(tty)"
CLAUDE_TTY_COMMENT: str = "# Claude Code Notify - tab title support"

HOOKS_CONFIG: dict[str, list[dict]] = {
    "UserPromptSubmit": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab_title.py on"},
            ],
        },
    ],
    "PreToolUse": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab_title.py on"},
            ],
        },
    ],
    "Notification": [
        {
            "matcher": "permission_prompt",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab_title.py ask"},
                {"type": "command", "command": "~/.claude/hooks/notify.py"},
            ],
        },
    ],
    "Stop": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab_title.py done"},
                {"type": "command", "command": "~/.claude/hooks/notify.py"},
            ],
        },
    ],
}

def parse_args() -> argparse.Namespace:
    """Parse CLI arguments."""
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Claude Code Notify installer",
    )
    parser.add_argument(
        "--source-dir",
        default=str(Path(__file__).resolve().parent),
        help="Directory containing hooks/ subdirectory",
    )
    return parser.parse_args()


def install_hook_scripts(source_dir: Path) -> None:
    """Copy hook scripts to ~/.claude/hooks/ and make them executable."""
    HOOKS_DIR.mkdir(parents=True, exist_ok=True)
    hooks_source: Path = source_dir / "hooks"

    for filename in HOOK_FILES:
        src: Path = hooks_source / filename
        dst: Path = HOOKS_DIR / filename
        shutil.copy2(str(src), str(dst))
        dst.chmod(dst.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    print(f"✓ Hook scripts installed to {HOOKS_DIR}")


def hook_entry_exists(existing_entries: list[dict], new_entry: dict) -> bool:
    """Check if an equivalent hook entry already exists."""
    new_commands: set[str] = {h["command"] for h in new_entry.get("hooks", [])}
    for entry in existing_entries:
        existing_commands: set[str] = {h["command"] for h in entry.get("hooks", [])}
        if entry.get("matcher") == new_entry.get("matcher") and new_commands <= existing_commands:
            return True
    return False


def merge_settings() -> None:
    """Merge hook configuration into ~/.claude/settings.json (idempotent)."""
    if not SETTINGS_FILE.exists():
        SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text("{}\n")

    with open(SETTINGS_FILE) as f:
        settings: dict = json.load(f)

    settings.setdefault("env", {})
    settings.setdefault("hooks", {})

    settings["env"]["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"

    for event_name, entries in HOOKS_CONFIG.items():
        if event_name not in settings["hooks"]:
            settings["hooks"][event_name] = []
        for new_entry in entries:
            if not hook_entry_exists(settings["hooks"][event_name], new_entry):
                settings["hooks"][event_name].append(new_entry)

    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"✓ Hook configuration merged into {SETTINGS_FILE}")


def add_claude_tty_to_profile(profile_path: Path) -> bool:
    """Add CLAUDE_TTY export to a shell profile if not already present."""
    if profile_path.exists():
        content: str = profile_path.read_text()
        if "CLAUDE_TTY" in content:
            return True
    elif profile_path.name != ".zshrc":
        return False

    with open(profile_path, "a") as f:
        f.write(f"\n{CLAUDE_TTY_COMMENT}\n{CLAUDE_TTY_LINE}\n")
    print(f"✓ Added CLAUDE_TTY to {profile_path}")
    return True


def setup_shell_profiles() -> None:
    """Add CLAUDE_TTY to shell profiles."""
    home: Path = Path.home()
    added: bool = False

    if add_claude_tty_to_profile(home / ".zshrc"):
        added = True
    if (home / ".bashrc").exists():
        add_claude_tty_to_profile(home / ".bashrc")
        added = True
    if (home / ".bash_profile").exists():
        add_claude_tty_to_profile(home / ".bash_profile")
        added = True

    if not added:
        print(f"⚠ Could not detect shell profile. Please add manually:")
        print(f"  {CLAUDE_TTY_LINE}")


def install_iterm2_scripts(source_dir: Path) -> bool:
    """Copy iTerm2 AutoLaunch scripts if iTerm2 Python API is set up."""
    if not ITERM2_AUTOLAUNCH_DIR.exists():
        print("⚠ iTerm2 AutoLaunch directory not found — skipping focus-clear script")
        print("  To enable: iTerm2 > Settings > General > Magic > Enable Python API")
        print(f"  Then create: {ITERM2_AUTOLAUNCH_DIR}")
        return False

    iterm2_source: Path = source_dir / "iterm2"
    for filename in ITERM2_SCRIPTS:
        src: Path = iterm2_source / filename
        dst: Path = ITERM2_AUTOLAUNCH_DIR / filename
        # シンボリックリンクが残っている場合は削除してからコピー
        if dst.is_symlink():
            dst.unlink()
        shutil.copy2(str(src), str(dst))

    print(f"✓ iTerm2 scripts installed to {ITERM2_AUTOLAUNCH_DIR}")
    return True


def print_completion(source_dir: Path) -> None:
    """Print completion message."""
    print()
    print("🎉 Installation complete!")
    print()
    print("Tab title indicators:")
    print("  ⚡ Processing")
    print("  ✅ Complete")
    print("  ❓ Waiting for permission")
    print()
    print("To activate, restart your terminal or run:")
    print("  source ~/.zshrc")
    print()
    print("To update later:")
    if (source_dir / "hooks").exists():
        print(f"  cd {source_dir} && git pull && python3 install.py")
    else:
        print('  sh -c "$(curl -fsSL https://raw.githubusercontent.com/hatayama/claude-code-notify/main/install.sh)"')


def main() -> None:
    args: argparse.Namespace = parse_args()
    source_dir: Path = Path(args.source_dir).resolve()

    print("🔔 Claude Code Notify - Installer\n")

    install_hook_scripts(source_dir)
    merge_settings()
    setup_shell_profiles()
    install_iterm2_scripts(source_dir)
    print_completion(source_dir)


if __name__ == "__main__":
    main()
