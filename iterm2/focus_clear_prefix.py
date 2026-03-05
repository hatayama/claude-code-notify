#!/usr/bin/env python3
"""
iTerm2 AutoLaunch daemon: clear tab title prefix on focus.

When Claude Code is running, hook scripts set ⚡ or ❓ prefixes
on the tab title and write a marker file at:
  /tmp/claude-iterm2-title-<tty_id>

Marker file format (2 lines):
  <action>   (on|done|ask)
  <title>    (plain title without prefix)

Behavior:
  - Focus in (tab switch / window activate): clear prefix (except ⚡ "on")
  - Focus out (tab switch away): clear only if action is "done"
"""
import os
import sys
import time
import iterm2


def _marker_path(tty: str) -> str:
    return "/tmp/claude-iterm2-title-" + tty.replace("/", "-")


def _read_marker(path: str) -> tuple[str, str] | None:
    """Read marker file. Returns (action, title) or None."""
    try:
        with open(path, "r") as f:
            lines = f.read().strip().split("\n")
    except FileNotFoundError:
        return None
    if len(lines) >= 2:
        return (lines[0], lines[1])
    return None


def _clear_title(tty: str, title: str, marker: str) -> None:
    """Write plain title to TTY and remove marker file."""
    osc: str = f"\033]0;{title}\007"
    try:
        with open(tty, "w") as f:
            f.write(osc)
    except OSError:
        pass
    try:
        os.remove(marker)
    except OSError:
        pass


async def _get_session_tty(app: iterm2.App) -> str | None:
    window = app.current_terminal_window
    if not window:
        return None
    tab = window.current_tab
    if not tab:
        return None
    session = tab.current_session
    if not session:
        return None
    # セッションが閉じた直後にAPI呼び出しするとRPCExceptionになる
    try:
        tty: str | None = await session.async_get_variable("tty")
    except iterm2.rpc.RPCException:
        return None
    return tty


async def _clear_prefix_for_active_session(app: iterm2.App) -> None:
    tty = await _get_session_tty(app)
    if not tty:
        return

    marker_path = _marker_path(tty)
    result = _read_marker(marker_path)
    if result is None:
        return

    action, title = result
    # ⚡️（処理中）はフォーカスで消さない。Stopフックで"done"に変わった時に消える
    if action == "on":
        return
    _clear_title(tty, title, marker_path)


async def _clear_done_for_previous_session(
    app: iterm2.App, previous_tty: str | None
) -> None:
    """Clear ✅ prefix when leaving a tab that has completed."""
    if not previous_tty:
        return

    marker_path = _marker_path(previous_tty)
    result = _read_marker(marker_path)
    if result is None:
        return

    action, title = result
    if action == "done":
        _clear_title(previous_tty, title, marker_path)


async def main(connection: iterm2.Connection) -> None:
    app = await iterm2.async_get_app(connection)

    previous_tty: str | None = await _get_session_tty(app)

    async with iterm2.FocusMonitor(connection) as monitor:
        while True:
            update = await monitor.async_get_next_update()

            focus_in: bool = False

            if update.selected_tab_changed:
                try:
                    await _clear_done_for_previous_session(app, previous_tty)
                except OSError as e:
                    print(f"focus_clear_prefix: {e}", file=sys.stderr)
                focus_in = True

            if update.window_changed:
                reason = update.window_changed.event
                if reason == iterm2.FocusUpdateWindowChanged.Reason.TERMINAL_WINDOW_BECAME_KEY:
                    focus_in = True

            if update.application_active is not None and update.application_active.application_active:
                focus_in = True

            if focus_in:
                try:
                    await _clear_prefix_for_active_session(app)
                except OSError as e:
                    print(f"focus_clear_prefix: {e}", file=sys.stderr)
                previous_tty = await _get_session_tty(app)


def run_with_retry() -> None:
    """iTerm2との接続が切れた場合に自動再起動する。"""
    MAX_RETRIES: int = 5
    RETRY_INTERVAL_SEC: int = 3

    for attempt in range(MAX_RETRIES):
        try:
            iterm2.run_forever(main)
        except (OSError, iterm2.rpc.RPCException) as e:
            print(
                f"focus_clear_prefix: crashed ({e}), "
                f"retrying {attempt + 1}/{MAX_RETRIES}",
                file=sys.stderr,
            )
            time.sleep(RETRY_INTERVAL_SEC)
        else:
            break


run_with_retry()
