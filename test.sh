#!/bin/sh
# Tests for install.sh / uninstall.sh idempotency
# Runs in a temporary HOME to avoid affecting the real environment
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

# --- Test helpers ---
assert_file_exists() {
    if [ -f "$1" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL: expected file to exist: %s\n' "$1"
    fi
}

assert_file_not_exists() {
    if [ ! -f "$1" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL: expected file to NOT exist: %s\n' "$1"
    fi
}

assert_file_contains() {
    if grep -qF "$2" "$1" 2>/dev/null; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL: expected "%s" in %s\n' "$2" "$1"
    fi
}

assert_file_not_contains() {
    if ! grep -qF "$2" "$1" 2>/dev/null; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL: expected "%s" NOT in %s\n' "$2" "$1"
    fi
}

assert_json_count() {
    FILE="$1"
    PATTERN="$2"
    EXPECTED="$3"
    ACTUAL=$(grep -c "$PATTERN" "$FILE" 2>/dev/null || echo "0")
    if [ "$ACTUAL" = "$EXPECTED" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL: expected %s occurrences of "%s" in %s, got %s\n' "$EXPECTED" "$PATTERN" "$FILE" "$ACTUAL"
    fi
}

# --- Setup temp HOME ---
TEMP_HOME=$(mktemp -d)
REAL_HOME="$HOME"
export HOME="$TEMP_HOME"

cleanup() {
    export HOME="$REAL_HOME"
    rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

# Create .zshrc so install.sh can add CLAUDE_TTY
touch "$TEMP_HOME/.zshrc"

printf '🧪 Running tests...\n\n'

# ========================================
# Test 1: Fresh install
# ========================================
printf '1. Fresh install\n'
"$SCRIPT_DIR/install.sh" > /dev/null 2>&1

assert_file_exists "$TEMP_HOME/.claude/hooks/tab-title.sh"
assert_file_exists "$TEMP_HOME/.claude/hooks/notify.sh"
assert_file_exists "$TEMP_HOME/.claude/settings.json"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "tab-title.sh on"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "tab-title.sh done"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "tab-title.sh ask"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "notify.sh"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "CLAUDE_CODE_DISABLE_TERMINAL_TITLE"
assert_file_contains "$TEMP_HOME/.zshrc" "CLAUDE_TTY"
printf '  %d passed\n\n' "$PASS"

# ========================================
# Test 2: Idempotent re-install (no duplicates)
# ========================================
printf '2. Idempotent re-install\n'
PREV_PASS=$PASS
"$SCRIPT_DIR/install.sh" > /dev/null 2>&1

# Each hook command should appear exactly once
assert_json_count "$TEMP_HOME/.claude/settings.json" "tab-title.sh on" "2"
assert_json_count "$TEMP_HOME/.claude/settings.json" "tab-title.sh done" "1"
assert_json_count "$TEMP_HOME/.claude/settings.json" "tab-title.sh ask" "1"

# CLAUDE_TTY should appear only once in .zshrc
assert_json_count "$TEMP_HOME/.zshrc" "CLAUDE_TTY" "1"
printf '  %d passed\n\n' "$((PASS - PREV_PASS))"

# ========================================
# Test 3: Install with existing settings.json
# ========================================
printf '3. Install with pre-existing hooks in settings.json\n'
PREV_PASS=$PASS

# Reset: create settings.json with existing user hooks
cat > "$TEMP_HOME/.claude/settings.json" << 'EXISTING'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "~/.claude/hooks/my-custom-hook.sh"}
        ]
      }
    ]
  }
}
EXISTING

"$SCRIPT_DIR/install.sh" > /dev/null 2>&1

# Existing hook should be preserved
assert_file_contains "$TEMP_HOME/.claude/settings.json" "my-custom-hook.sh"
# Our hooks should also be present
assert_file_contains "$TEMP_HOME/.claude/settings.json" "tab-title.sh done"
assert_file_contains "$TEMP_HOME/.claude/settings.json" "notify.sh"
printf '  %d passed\n\n' "$((PASS - PREV_PASS))"

# ========================================
# Test 4: Uninstall
# ========================================
printf '4. Uninstall\n'
PREV_PASS=$PASS
"$SCRIPT_DIR/uninstall.sh" > /dev/null 2>&1

assert_file_not_exists "$TEMP_HOME/.claude/hooks/tab-title.sh"
assert_file_not_exists "$TEMP_HOME/.claude/hooks/notify.sh"
assert_file_not_contains "$TEMP_HOME/.claude/settings.json" "tab-title.sh"
assert_file_not_contains "$TEMP_HOME/.claude/settings.json" "notify.sh"
assert_file_not_contains "$TEMP_HOME/.zshrc" "CLAUDE_TTY"
# Existing user hook should be preserved after uninstall
assert_file_contains "$TEMP_HOME/.claude/settings.json" "my-custom-hook.sh"
printf '  %d passed\n\n' "$((PASS - PREV_PASS))"

# ========================================
# Test 5: Uninstall is idempotent (no errors on second run)
# ========================================
printf '5. Idempotent uninstall\n'
PREV_PASS=$PASS
"$SCRIPT_DIR/uninstall.sh" > /dev/null 2>&1

assert_file_not_exists "$TEMP_HOME/.claude/hooks/tab-title.sh"
assert_file_not_exists "$TEMP_HOME/.claude/hooks/notify.sh"
printf '  %d passed\n\n' "$((PASS - PREV_PASS))"

# ========================================
# Results
# ========================================
printf '━━━━━━━━━━━━━━━━━━━━━━\n'
if [ "$FAIL" -eq 0 ]; then
    printf '✅ All %d tests passed\n' "$PASS"
else
    printf '❌ %d passed, %d failed\n' "$PASS" "$FAIL"
    exit 1
fi
