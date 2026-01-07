# Claude Code Notify

Enhanced notification script for [Claude Code](https://docs.claude.ai/en/docs/claude-code) on macOS.

Inspired by [Boris Cherny's workflow](https://x.com/bcherny/status/2007179833990885678) of running multiple Claude instances in parallel with numbered tabs and system notifications.

## Features

- **Tab identification** - Shows which iTerm2 tab the notification is from (e.g., "*** 2 ***")
- **Click to focus** - Clicking the notification activates iTerm2 and switches to the originating tab
- **Non-blocking** - Runs in background so Claude Code doesn't wait for the notification
- **AI-generated messages (optional)** - Uses Gemini or OpenAI API to generate contextual completion messages

## Requirements

- macOS
- [iTerm2](https://iterm2.com/) (for tab identification feature)
- [terminal-notifier](https://github.com/julienXX/terminal-notifier)
- [jq](https://stedolan.github.io/jq/)
- Gemini API key or OpenAI API key (optional, for AI-generated messages)

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
],
"PermissionRequest": [
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
    ],
    "PermissionRequest": [
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

## How It Works

### Tab Identification (iTerm2 only)

iTerm2 sets the `TERM_SESSION_ID` environment variable for each session:

```
TERM_SESSION_ID=w0t2p0:UUID
```

Format: `w{window}t{tab}p{pane}:{UUID}`

This allows the script to identify which tab triggered the notification, even for background tabs.

**Note**: Ghostty does not support this feature. See [ghostty-org/ghostty#9084](https://github.com/ghostty-org/ghostty/discussions/9084).

### Click Action

Uses AppleScript via `terminal-notifier -execute` to:

1. Activate iTerm2
2. Select the specific tab that triggered the notification

## Customization

### Auto-number tab titles (recommended)

Add this to your `~/.zshrc` to automatically set tab titles to their tab number (like Boris Cherny's workflow):

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

**Also**: Disable Claude Code's automatic title updates by adding to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

### AI-generated messages (optional)

By default, the script shows simple messages like "Task completed". If you want AI-generated contextual messages:

1. Set up an API key (Gemini recommended for speed):

```bash
# ~/.zshrc
# Option 1: Gemini (faster, recommended)
export GEMINI_API_KEY="your-api-key-here"

# Option 2: OpenAI
export OPENAI_API_KEY="your-api-key-here"
```

Get your Gemini API key at [Google AI Studio](https://aistudio.google.com/).

2. Optionally customize the prompt:

```bash
# ~/.zshrc
export CLAUDE_NOTIFY_AI_PROMPT="Generate a short completion message in pirate speak (max 20 chars). Work content:"
```

The script reads the transcript, extracts recent context, and calls the API to generate a short completion message. If both keys are set, Gemini is used (faster response).

### Change notification sounds

Set environment variables to customize sounds for each event type:

```bash
# ~/.zshrc
export CLAUDE_NOTIFY_SOUND_STOP="Funk"           # When Claude stops (default: Funk)
export CLAUDE_NOTIFY_SOUND_NOTIFICATION="Submarine"  # For notifications (default: Submarine)
export CLAUDE_NOTIFY_SOUND_PERMISSION="Hero"     # For permission requests (default: Hero)
```

Available sounds are in `/System/Library/Sounds/`.

### Use a different terminal

Replace `com.googlecode.iterm2` with your terminal's bundle identifier and adjust the AppleScript accordingly.

## Known Limitations

- **Tab identification only works with iTerm2** - Other terminals don't provide session IDs

## License

MIT
