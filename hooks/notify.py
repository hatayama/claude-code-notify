#!/usr/bin/env python3
"""Claude Code desktop notification script (macOS).

Reads JSON context from stdin and displays notifications with event-specific sounds.
Uses terminal-notifier if available (click-to-focus support),
falls back to osascript (macOS built-in). No hard dependencies.
Forks to background to avoid blocking Claude Code.

Usage: notify.py [options]
  -t, --title TITLE      Override notification title
  -m, --message MESSAGE  Override notification message
  -s, --sound SOUND      Override notification sound
  -a, --activate ID      App bundle ID to activate on click (auto-detected if omitted)

Environment variables:
  CLAUDE_NOTIFY_SOUND_STOP         Sound for Stop events (default: Funk)
  CLAUDE_NOTIFY_SOUND_PERMISSION   Sound for permission prompts (default: Hero)
  CLAUDE_NOTIFY_SOUND_NOTIFICATION Sound for other notifications (default: Submarine)
  CLAUDE_NOTIFY_SOUND_DEFAULT      Default sound (default: Funk)
"""

import argparse
import json
import os
import shutil
import subprocess
import sys


TERMINAL_BUNDLE_IDS: dict[str, str] = {
    "ghostty": "com.mitchellh.ghostty",
    "iTerm.app": "com.googlecode.iterm2",
    "Apple_Terminal": "com.apple.Terminal",
    "vscode": "com.microsoft.VSCode",
}


def parse_args() -> argparse.Namespace:
    """Parse CLI arguments."""
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Claude Code notification",
    )
    parser.add_argument("-t", "--title", default="")
    parser.add_argument("-m", "--message", default="")
    parser.add_argument("-s", "--sound", default="")
    parser.add_argument("-a", "--activate", default="")
    return parser.parse_args()


def read_hook_context() -> dict[str, str]:
    """Read JSON hook context from stdin."""
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return {}


def resolve_notification_params(
    context: dict[str, str],
    args: argparse.Namespace,
) -> tuple[str, str, str]:
    """Determine title, message, and sound from context and CLI args."""
    hook_event: str = context.get("hook_event_name", "")
    notification_type: str = context.get("notification_type", "")
    json_message: str = context.get("message", "")

    if hook_event == "Stop":
        sound: str = os.environ.get("CLAUDE_NOTIFY_SOUND_STOP", "Funk")
        message: str = json_message or "Response complete"
        title: str = "Claude Code - Complete"
    elif hook_event == "Notification":
        if notification_type == "permission_prompt":
            sound = os.environ.get("CLAUDE_NOTIFY_SOUND_PERMISSION", "Hero")
            title = "Claude Code - Permission"
        else:
            sound = os.environ.get("CLAUDE_NOTIFY_SOUND_NOTIFICATION", "Submarine")
            title = "Claude Code - Notification"
        message = json_message or "Notification"
    else:
        sound = os.environ.get("CLAUDE_NOTIFY_SOUND_DEFAULT", "Funk")
        message = json_message or "Claude Code notification"
        title = "Claude Code"

    if args.title:
        title = args.title
    if args.message:
        message = args.message
    if args.sound:
        sound = args.sound

    return title, message, sound


def get_iterm2_session_uuid() -> str:
    """Extract iTerm2 session UUID from TERM_SESSION_ID (format: w0t1p0:UUID)."""
    session_id: str = os.environ.get("TERM_SESSION_ID", "")
    if ":" in session_id:
        return session_id.split(":", 1)[1]
    return ""


def detect_activate_bundle_id() -> str:
    """Auto-detect terminal app bundle ID from TERM_PROGRAM."""
    term_program: str = os.environ.get("TERM_PROGRAM", "")
    return TERMINAL_BUNDLE_IDS.get(term_program, "")


def build_iterm2_focus_script(session_uuid: str) -> str:
    """Build AppleScript command to focus a specific iTerm2 tab by session UUID."""
    return (
        'osascript -e \'tell application "iTerm2"\n'
        "    activate\n"
        "    repeat with aWindow in windows\n"
        "        repeat with aTab in tabs of aWindow\n"
        "            repeat with aSession in sessions of aTab\n"
        f'                if unique id of aSession is "{session_uuid}" then\n'
        "                    select aWindow\n"
        "                    select aTab\n"
        "                    select aSession\n"
        "                    return\n"
        "                end if\n"
        "            end repeat\n"
        "        end repeat\n"
        "    end repeat\n"
        "end tell'"
    )


def notify_via_terminal_notifier(
    title: str,
    message: str,
    sound: str,
    subtitle: str,
    activate: str,
    session_uuid: str,
) -> None:
    """Send notification using terminal-notifier."""
    cmd: list[str] = [
        "terminal-notifier",
        "-title", title,
        "-message", message,
        "-sound", sound,
    ]
    if subtitle:
        cmd.extend(["-subtitle", subtitle])

    if session_uuid:
        execute_cmd: str = build_iterm2_focus_script(session_uuid)
        cmd.extend(["-execute", execute_cmd])
    elif activate:
        cmd.extend(["-activate", activate])

    subprocess.run(cmd, capture_output=True)


def notify_via_osascript(
    title: str,
    message: str,
    sound: str,
    subtitle: str,
) -> None:
    """Send notification using osascript (fallback)."""
    subtitle_part: str = f' subtitle "{subtitle}"' if subtitle else ""
    script: str = (
        f'display notification "{message}" '
        f'with title "{title}"{subtitle_part} '
        f'sound name "{sound}"'
    )
    subprocess.run(["osascript", "-e", script], capture_output=True)


def send_notification(
    title: str,
    message: str,
    sound: str,
    subtitle: str,
    activate: str,
) -> None:
    """Send desktop notification via best available method."""
    session_uuid: str = get_iterm2_session_uuid()

    if shutil.which("terminal-notifier"):
        notify_via_terminal_notifier(
            title, message, sound, subtitle, activate, session_uuid,
        )
    else:
        notify_via_osascript(title, message, sound, subtitle)


def main() -> None:
    args: argparse.Namespace = parse_args()
    context: dict[str, str] = read_hook_context()

    title, message, sound = resolve_notification_params(context, args)

    cwd: str = context.get("cwd", "") or os.environ.get("PWD", "")
    subtitle: str = os.path.basename(cwd) if cwd else ""

    activate: str = args.activate or detect_activate_bundle_id()

    # Fork to background so Claude Code is not blocked
    pid: int = os.fork()
    if pid > 0:
        # Parent exits immediately
        return

    # Child process sends notification
    send_notification(title, message, sound, subtitle, activate)


if __name__ == "__main__":
    main()
