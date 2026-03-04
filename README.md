# Claude Code Notify

Tab title indicators and desktop notifications for [Claude Code](https://docs.claude.ai/en/docs/claude-code) on macOS.

Works out of the box on macOS — no additional installation required (`osascript`, `python3` are pre-installed).
Optionally uses [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) for click-to-focus support.

## Features

- **Tab title status** — See Claude's state at a glance:
  - ⚡ Processing
  - ✅ Complete
  - ❓ Waiting for permission
- **Desktop notifications** — Get notified when Claude finishes or needs input
- **Click to focus tab** — Clicking the notification switches to the exact iTerm2 tab (requires `terminal-notifier`)
- **Event-specific sounds** — Different sounds for completion, permission requests, etc.

## Installation

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/hatayama/claude-code-notify/main/install.sh)"
```

<details>
<summary>Manual installation (git clone)</summary>

```bash
git clone https://github.com/hatayama/claude-code-notify.git
cd claude-code-notify
python3 install.py
```

</details>

The installer will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Configure hooks in `~/.claude/settings.json`
3. Add `CLAUDE_TTY` to your shell profile

Restart your terminal after installation.

## Updating

Re-run the install command:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/hatayama/claude-code-notify/main/install.sh)"
```

## Uninstall

```bash
python3 uninstall.py
```

## Customization

### Notification sounds

Override sounds via environment variables in your `~/.zshrc`:

```bash
export CLAUDE_NOTIFY_SOUND_STOP="Funk"           # When Claude stops (default: Funk)
export CLAUDE_NOTIFY_SOUND_PERMISSION="Hero"      # Permission requests (default: Hero)
export CLAUDE_NOTIFY_SOUND_NOTIFICATION="Submarine" # Other notifications (default: Submarine)
```

Available sounds: `/System/Library/Sounds/`

### Override notification text

Use CLI options in `~/.claude/settings.json` hooks:

```json
"command": "~/.claude/hooks/notify.py --title 'Done!' --sound Glass"
```

Options: `--title`, `--message`, `--sound`

## How It Works

### Tab Title

Uses ANSI escape sequences (`\033]0;...\007`) to set the terminal tab title. The `CLAUDE_TTY` environment variable tells the script which terminal to update.

A marker file in `/tmp/claude-iterm2-title-*` stores the current state, which can be used by external scripts (e.g., iTerm2 AutoLaunch) to clear the prefix on tab focus.

### Focus Clearing (iTerm2)

On iTerm2, an AutoLaunch script automatically clears tab title prefixes when you switch to a tab:

- **⚡ (processing)** — **not** cleared on focus (stays visible while Claude is working)
- **✅ (complete)** / **❓ (permission)** — cleared on focus

This requires iTerm2's Python API:

1. iTerm2 > Settings > General > Magic > **Enable Python API**
2. The installer copies the script to `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/`
3. Restart iTerm2 (or reload scripts via Scripts menu)

If the AutoLaunch directory doesn't exist, the installer skips this step and prints setup instructions.

### Notifications

If [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) is installed (`brew install terminal-notifier`), notifications support click-to-focus: clicking a notification activates iTerm2 and switches to the exact tab that triggered it, using the session UUID from `TERM_SESSION_ID`.

Without `terminal-notifier`, falls back to `osascript` (`display notification`) for basic notifications.

### Hooks

The installer configures these [Claude Code hooks](https://docs.claude.ai/en/docs/claude-code/hooks):

| Hook | Action |
|------|--------|
| `UserPromptSubmit` | Set tab title to ⚡ |
| `PreToolUse` | Keep tab title as ⚡ |
| `Notification` (permission_prompt) | Set tab title to ❓ + desktop notification |
| `Stop` | Set tab title to ✅ + desktop notification |

## Requirements

- macOS
- [Claude Code CLI](https://docs.claude.ai/en/docs/claude-code)
- Terminal that supports title escape sequences (iTerm2, Ghostty, Terminal.app, etc.)

## License

MIT
