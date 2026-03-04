#!/usr/bin/env python3
"""Tests for install.py / uninstall.py idempotency.

Runs in a temporary HOME to avoid affecting the real environment.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR: Path = Path(__file__).resolve().parent


class InstallTestBase(unittest.TestCase):
    """Base class that sets up a temporary HOME directory."""

    def setUp(self) -> None:
        self.temp_dir: tempfile.TemporaryDirectory[str] = tempfile.TemporaryDirectory()
        self.fake_home: Path = Path(self.temp_dir.name)
        self.hooks_dir: Path = self.fake_home / ".claude" / "hooks"
        self.settings_file: Path = self.fake_home / ".claude" / "settings.json"
        self.zshrc: Path = self.fake_home / ".zshrc"
        self.zshrc.touch()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_install(self) -> subprocess.CompletedProcess[str]:
        """Run install.py with fake HOME."""
        return subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "install.py")],
            env={**os.environ, "HOME": str(self.fake_home)},
            capture_output=True,
            text=True,
        )

    def run_uninstall(self) -> subprocess.CompletedProcess[str]:
        """Run uninstall.py with fake HOME."""
        return subprocess.run(
            [sys.executable, str(SCRIPT_DIR / "uninstall.py")],
            env={**os.environ, "HOME": str(self.fake_home)},
            capture_output=True,
            text=True,
        )

    def read_settings(self) -> dict:
        """Read and parse settings.json."""
        with open(self.settings_file) as f:
            return json.load(f)

    def count_occurrences(self, file_path: Path, text: str) -> int:
        """Count how many times text appears in a file."""
        content: str = file_path.read_text()
        return content.count(text)


class TestFreshInstall(InstallTestBase):
    """Test fresh installation on a clean system."""

    def test_creates_hook_files(self) -> None:
        self.run_install()
        self.assertTrue((self.hooks_dir / "tab_title.py").exists())
        self.assertTrue((self.hooks_dir / "notify.py").exists())

    def test_hook_files_are_executable(self) -> None:
        self.run_install()
        for filename in ["tab_title.py", "notify.py"]:
            mode: int = (self.hooks_dir / filename).stat().st_mode
            self.assertTrue(mode & 0o111, f"{filename} should be executable")

    def test_creates_settings_json(self) -> None:
        self.run_install()
        self.assertTrue(self.settings_file.exists())

    def test_settings_contains_hook_commands(self) -> None:
        self.run_install()
        settings: dict = self.read_settings()
        hooks: dict = settings["hooks"]

        self.assertIn("UserPromptSubmit", hooks)
        self.assertIn("PreToolUse", hooks)
        self.assertIn("Notification", hooks)
        self.assertIn("Stop", hooks)

    def test_settings_contains_tab_title_commands(self) -> None:
        self.run_install()
        content: str = self.settings_file.read_text()
        self.assertIn("tab_title.py on", content)
        self.assertIn("tab_title.py done", content)
        self.assertIn("tab_title.py ask", content)

    def test_settings_contains_notify_command(self) -> None:
        self.run_install()
        content: str = self.settings_file.read_text()
        self.assertIn("notify.py", content)

    def test_settings_disables_builtin_title(self) -> None:
        self.run_install()
        settings: dict = self.read_settings()
        self.assertEqual(settings["env"]["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"], "1")

    def test_adds_claude_tty_to_zshrc(self) -> None:
        self.run_install()
        content: str = self.zshrc.read_text()
        self.assertIn("CLAUDE_TTY", content)


class TestIdempotentInstall(InstallTestBase):
    """Test that re-running install.py does not create duplicates."""

    def test_no_duplicate_hook_entries(self) -> None:
        self.run_install()
        self.run_install()

        content: str = self.settings_file.read_text()
        # tab_title.py on appears in UserPromptSubmit and PreToolUse = 2
        self.assertEqual(self.count_occurrences(self.settings_file, "tab_title.py on"), 2)
        self.assertEqual(self.count_occurrences(self.settings_file, "tab_title.py done"), 1)
        self.assertEqual(self.count_occurrences(self.settings_file, "tab_title.py ask"), 1)

    def test_no_duplicate_claude_tty(self) -> None:
        self.run_install()
        self.run_install()

        self.assertEqual(self.count_occurrences(self.zshrc, "CLAUDE_TTY"), 1)


class TestExistingHooksPreserved(InstallTestBase):
    """Test that pre-existing user hooks are preserved."""

    def test_preserves_custom_hooks(self) -> None:
        self.settings_file.parent.mkdir(parents=True, exist_ok=True)
        custom_settings: dict = {
            "hooks": {
                "Stop": [
                    {
                        "matcher": "",
                        "hooks": [
                            {"type": "command", "command": "~/.claude/hooks/my-custom-hook.sh"},
                        ],
                    },
                ],
            },
        }
        with open(self.settings_file, "w") as f:
            json.dump(custom_settings, f)

        self.run_install()

        content: str = self.settings_file.read_text()
        self.assertIn("my-custom-hook.sh", content)
        self.assertIn("tab_title.py done", content)
        self.assertIn("notify.py", content)


class TestUninstall(InstallTestBase):
    """Test uninstallation."""

    def test_removes_hook_files(self) -> None:
        self.run_install()
        self.run_uninstall()

        self.assertFalse((self.hooks_dir / "tab_title.py").exists())
        self.assertFalse((self.hooks_dir / "notify.py").exists())

    def test_removes_hook_settings(self) -> None:
        self.run_install()
        self.run_uninstall()

        content: str = self.settings_file.read_text()
        self.assertNotIn("tab_title.py", content)
        self.assertNotIn("notify.py", content)

    def test_removes_claude_tty(self) -> None:
        self.run_install()
        self.run_uninstall()

        content: str = self.zshrc.read_text()
        self.assertNotIn("CLAUDE_TTY", content)

    def test_preserves_custom_hooks_after_uninstall(self) -> None:
        self.settings_file.parent.mkdir(parents=True, exist_ok=True)
        custom_settings: dict = {
            "hooks": {
                "Stop": [
                    {
                        "matcher": "",
                        "hooks": [
                            {"type": "command", "command": "~/.claude/hooks/my-custom-hook.sh"},
                        ],
                    },
                ],
            },
        }
        with open(self.settings_file, "w") as f:
            json.dump(custom_settings, f)

        self.run_install()
        self.run_uninstall()

        content: str = self.settings_file.read_text()
        self.assertIn("my-custom-hook.sh", content)


class TestIdempotentUninstall(InstallTestBase):
    """Test that re-running uninstall.py doesn't error."""

    def test_double_uninstall_succeeds(self) -> None:
        self.run_install()
        result1: subprocess.CompletedProcess[str] = self.run_uninstall()
        result2: subprocess.CompletedProcess[str] = self.run_uninstall()

        self.assertEqual(result1.returncode, 0)
        self.assertEqual(result2.returncode, 0)


class TestShToPhMigration(InstallTestBase):
    """Test migration from old .sh files to new .py files."""

    def test_removes_old_sh_files(self) -> None:
        self.hooks_dir.mkdir(parents=True, exist_ok=True)
        (self.hooks_dir / "tab-title.sh").write_text("#!/bin/sh\n")
        (self.hooks_dir / "notify.sh").write_text("#!/bin/sh\n")

        self.run_install()

        self.assertFalse((self.hooks_dir / "tab-title.sh").exists())
        self.assertFalse((self.hooks_dir / "notify.sh").exists())
        self.assertTrue((self.hooks_dir / "tab_title.py").exists())
        self.assertTrue((self.hooks_dir / "notify.py").exists())

    def test_migrates_sh_entries_in_settings(self) -> None:
        self.settings_file.parent.mkdir(parents=True, exist_ok=True)
        old_settings: dict = {
            "env": {"CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"},
            "hooks": {
                "UserPromptSubmit": [
                    {
                        "matcher": "",
                        "hooks": [
                            {"type": "command", "command": "~/.claude/hooks/tab-title.sh on"},
                        ],
                    },
                ],
                "Stop": [
                    {
                        "matcher": "",
                        "hooks": [
                            {"type": "command", "command": "~/.claude/hooks/tab-title.sh done"},
                            {"type": "command", "command": "~/.claude/hooks/notify.sh"},
                        ],
                    },
                ],
            },
        }
        with open(self.settings_file, "w") as f:
            json.dump(old_settings, f)

        self.run_install()

        content: str = self.settings_file.read_text()
        self.assertNotIn("tab-title.sh", content)
        self.assertNotIn("notify.sh", content)
        self.assertIn("tab_title.py on", content)
        self.assertIn("tab_title.py done", content)
        self.assertIn("notify.py", content)

    def test_uninstall_removes_both_old_and_new(self) -> None:
        self.hooks_dir.mkdir(parents=True, exist_ok=True)
        (self.hooks_dir / "tab-title.sh").write_text("#!/bin/sh\n")
        (self.hooks_dir / "notify.sh").write_text("#!/bin/sh\n")

        self.run_install()
        self.run_uninstall()

        self.assertFalse((self.hooks_dir / "tab-title.sh").exists())
        self.assertFalse((self.hooks_dir / "notify.sh").exists())
        self.assertFalse((self.hooks_dir / "tab_title.py").exists())
        self.assertFalse((self.hooks_dir / "notify.py").exists())


if __name__ == "__main__":
    unittest.main()
