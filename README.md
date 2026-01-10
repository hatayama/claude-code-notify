# Claude Code Notify

Enhanced notification script for [Claude Code](https://docs.claude.ai/en/docs/claude-code) on macOS.

Inspired by [Boris Cherny's workflow](https://x.com/bcherny/status/2007179833990885678) of running multiple Claude instances in parallel with numbered tabs and system notifications.

## Features

- **Tab title display** - Shows actual iTerm2 tab title in notifications
- **Click to focus** - Clicking the notification activates iTerm2 and switches to the originating tab (UUID-based)
- **Non-blocking** - Runs in background so Claude Code doesn't wait for the notification
- **AI-generated messages (optional)** - Uses Claude's direct output or Gemini/OpenAI API for contextual messages

## File Structure

| File | Purpose |
|------|---------|
| `notify.sh` | Core notification script (for most users) |
| `notify-ai.sh` | AI-enhanced version with contextual messages |
| `notify-common.sh` | Shared utilities (sourced by other scripts) |

## Requirements

- macOS
- [iTerm2](https://iterm2.com/) (for tab identification feature)
- [terminal-notifier](https://github.com/julienXX/terminal-notifier)
- [jq](https://stedolan.github.io/jq/)

**For AI features (notify-ai.sh only):**
- Gemini API key or OpenAI API key (optional)

## Installation

### 1. Install dependencies

```bash
brew install terminal-notifier jq
```

### 2. Clone the repository

```bash
git clone https://github.com/hatayama/claude-code-notify.git
# Remember the path where you cloned it (e.g., ~/claude-code-notify)
```

### 3. Configure Claude Code hooks

Add the following to the `hooks` section in your `~/.claude/settings.json`.

**Replace `/path/to/claude-code-notify` with your actual clone path:**

```json
"Stop": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "/path/to/claude-code-notify/notify.sh"
      }
    ]
  }
],
"Notification": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "/path/to/claude-code-notify/notify.sh"
      }
    ]
  }
]
```

<details>
<summary>Full example (if you don't have existing settings)</summary>

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-code-notify/notify.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-code-notify/notify.sh"
          }
        ]
      }
    ]
  }
}
```

</details>

## Default Messages

| Event | Message |
|-------|---------|
| Stop | Response complete |
| SubagentStop | Subagent completed |
| Notification | (message from Claude Code) |
| PermissionRequest | Permission: {tool name} |

## How It Works

### Tab Identification (iTerm2 only)

iTerm2 sets the `TERM_SESSION_ID` environment variable for each session:

```
TERM_SESSION_ID=w0t2p0:UUID
```

The script uses the UUID to reliably identify and select the correct tab, even when tabs are reordered.

**Note**: Ghostty does not support this feature. See [ghostty-org/ghostty#9084](https://github.com/ghostty-org/ghostty/discussions/9084).

### Click Action

Uses AppleScript via `terminal-notifier -execute` to:

1. Activate iTerm2
2. Find the session by UUID
3. Select the window, tab, and session

## Customization

### Show hook event prefix

Add `[Stop]`, `[Notification]`, etc. prefix to messages:

```bash
# ~/.zshrc
export CLAUDE_NOTIFY_SHOW_PREFIX=true
```

### Change notification sounds

```bash
# ~/.zshrc
export CLAUDE_NOTIFY_SOUND_STOP="Funk"           # When Claude stops (default: Funk)
export CLAUDE_NOTIFY_SOUND_NOTIFICATION="Submarine"  # For notifications (default: Submarine)
export CLAUDE_NOTIFY_SOUND_PERMISSION="Hero"     # For permission requests (default: Hero)
```

Available sounds are in `/System/Library/Sounds/`.

### Auto-number tab titles

Add this to your `~/.zshrc` to automatically set tab titles to their tab number:

```bash
# iTerm2: Auto-set tab title to tab number
if [ -n "$TERM_SESSION_ID" ]; then
    TAB_NUM=$(echo "$TERM_SESSION_ID" | sed 's/.*t\([0-9]*\).*/\1/')
    TAB_NUM=$((TAB_NUM + 1))
    echo -ne "\033]0;${TAB_NUM}\007"
fi
```

**Important**: Enable "Applications in terminal may change the title" in iTerm2:
- Settings → Profiles → General → Title → ☑️ Applications in terminal may change the title

**Also**: Disable Claude Code's automatic title updates:

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

## AI-Enhanced Notifications (notify-ai.sh)

For power users who want contextual AI-generated messages, use `notify-ai.sh` instead of `notify.sh`.

### Setup

1. Update your hooks to use `notify-ai.sh`:

```json
"command": "/path/to/claude-code-notify/notify-ai.sh"
```

2. (Optional) Set up an API key for fallback:

```bash
# ~/.zshrc
# Option 1: Gemini (faster, recommended)
export GEMINI_API_KEY="your-api-key-here"

# Option 2: OpenAI
export OPENAI_API_KEY="your-api-key-here"
```

Get your Gemini API key at [Google AI Studio](https://aistudio.google.com/).

### How it works

Message priority:
1. **Direct output** - Reads from `/tmp/claude/last_response.txt` (if Claude writes to it)
2. **AI fallback** - Calls Gemini/OpenAI API to generate a summary from transcript
3. **Default message** - Falls back to standard messages

### Configuration

```bash
# ~/.zshrc

# Which events should use AI messages (comma-separated)
export CLAUDE_NOTIFY_AI_EVENTS="Stop,Notification"

# Custom AI prompt (optional)
export CLAUDE_NOTIFY_AI_PROMPT="Generate a short completion message (max 20 chars). Work content:"
```

## License

MIT
