#!/bin/sh
# Claude Code Notification Script (Core)
# https://github.com/hatayama/claude-code-notify
#
# Features:
# - Tab title display (iTerm2 only)
# - Click to focus the originating tab (uses session UUID for reliable targeting)
# - Non-blocking background execution
#
# Requirements:
# - macOS
# - terminal-notifier (brew install terminal-notifier)
# - jq (brew install jq)
# - iTerm2 (for tab identification)
#
# For AI-generated messages, use notify-ai.sh instead

# Read JSON from stdin first (must be synchronous)
INPUT=$(cat)

# Run everything else in background to not block Claude Code
(

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/notify-common.sh"

# Initialize
parse_input
get_session_uuid
get_tab_title
determine_sound

# Get default message
NOTIFY_MESSAGE=$(get_default_message)

# Add prefix if enabled
add_prefix_if_enabled

# Show notification
show_notification

) &
