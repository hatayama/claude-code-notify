# Claude Code Notify

Tab title indicators and desktop notifications for [Claude Code](https://docs.claude.ai/en/docs/claude-code) on macOS.

**Zero external dependencies** — uses only macOS built-in tools (`osascript`, `python3`).

## Features

- **Tab title status** — See Claude's state at a glance:
  - ⚡ Processing
  - ✅ Complete
  - ❓ Waiting for permission
- **Desktop notifications** — Get notified when Claude finishes or needs input
- **Event-specific sounds** — Different sounds for completion, permission requests, etc.

## Installation

```bash
git clone https://github.com/hatayama/claude-code-notify.git
cd claude-code-notify
./install.sh
```

The installer will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Configure hooks in `~/.claude/settings.json`
3. Add `CLAUDE_TTY` to your shell profile

Restart your terminal after installation.

## Updating

```bash
cd claude-code-notify
git pull
./install.sh
```

## Uninstall

```bash
cd claude-code-notify
./uninstall.sh
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
"command": "~/.claude/hooks/notify.sh --title 'Done!' --sound Glass"
```

Options: `--title`, `--message`, `--sound`

## How It Works

### Tab Title

Uses ANSI escape sequences (`\033]0;...\007`) to set the terminal tab title. The `CLAUDE_TTY` environment variable tells the script which terminal to update.

A marker file in `/tmp/claude-iterm2-title-*` stores the current state, which can be used by external scripts (e.g., iTerm2 AutoLaunch) to clear the prefix on tab focus.

### Notifications

Uses `osascript` to call macOS Notification Center via `display notification`.

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
