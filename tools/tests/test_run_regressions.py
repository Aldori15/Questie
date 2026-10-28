"""Keep the local regression command aligned with CI's fail-fast suite plan."""
import contextlib
import io
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from _test_paths import ADDON_ROOT
import db_snapshot
import run_regressions as runner


class RegressionRunnerTests(unittest.TestCase):
    def tools(self, optional=True):
        return {name: name if optional or name == "lua" else None for name in runner.TOOL_SPECS}

    @contextlib.contextmanager
    def fixtures(self):
        with db_snapshot.temporary_directory(ADDON_ROOT / "tools/reports") as root:
            tests = root / "tools/tests"
            tests.mkdir(parents=True)
            (tests / "test_a.lua").write_text("-- Run with Lua 5.1 or Lua 5.2\n", encoding="utf-8")
            (tests / "test_z.lua").write_text("-- Run with Lua 5.2\n", encoding="utf-8")
            with patch.object(runner, "ROOT", root):
                yield root

    def invoke(self, tools, *, ci=False, failure=None):
        output = io.StringIO()
        calls = []

        def execute(command, **kwargs):
            calls.append((command, kwargs))
            return SimpleNamespace(returncode=19 if failure and failure(command) else 0)

        with patch.object(runner, "resolve_tools", return_value=tools), \
                patch.object(runner.subprocess, "run", side_effect=execute), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            status = runner.main(["--ci"] if ci else [])
        return status, calls, output.getvalue()

    def test_ci_discovers_all_suites_and_runs_only_marked_suites_on_lua51(self):
        with self.fixtures() as root:
            status, calls, output = self.invoke(self.tools(), ci=True)
        self.assertEqual(status, 0, output)
        commands = [command for command, _ in calls]
        self.assertIn("check_lua_syntax.py", commands[0][2])
        self.assertEqual([Path(command[1]).name for command in commands if command[0] == "lua51"],
                         ["test_a.lua"])
        self.assertEqual([Path(command[1]).name for command in commands if command[0] == "lua"],
                         ["test_a.lua", "test_z.lua"])
        self.assertEqual(sum(command[0] == "luac52" for command in commands), 2)
        self.assertIn("unittest", commands[-1])
        for _, kwargs in calls:
            self.assertEqual(kwargs["cwd"], root)
            self.assertEqual(kwargs["env"]["QUESTIE_TEST_LUA"], "lua")
            self.assertEqual(kwargs["env"]["QUESTIE_TEST_LUAC"], "luac")
            self.assertEqual(kwargs["env"]["PYTHONDONTWRITEBYTECODE"], "1")

    def test_failed_lua_suite_stops_before_later_suites_and_python(self):
        with self.fixtures():
            status, calls, output = self.invoke(self.tools(False), failure=lambda command: command[0] == "lua")
        self.assertEqual(status, 19)
        self.assertEqual(len(calls), 1)
        self.assertNotIn("unittest", calls[0][0])
        self.assertIn("FAILED:", output)

    def test_local_missing_optional_tools_are_reported_without_claiming_ci_passed(self):
        with self.fixtures():
            status, calls, output = self.invoke(self.tools(False))
        self.assertEqual(status, 0, output)
        self.assertEqual(len(calls), 3)
        self.assertEqual(output.count("SKIPPED:"), 3)
        self.assertIn("remain unverified", output)
        self.assertNotIn("All CI regression checks passed", output)

    def test_ci_missing_tools_fail_preflight_without_running_checks(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(runner.shutil, "which", return_value=None), \
                patch.object(runner.subprocess, "run") as execute, \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(["--ci"]), 1)
        execute.assert_not_called()

    def test_explicit_missing_tool_is_an_error_even_when_optional(self):
        with patch.object(runner.shutil, "which", side_effect=lambda value: None if value == "missing" else value):
            with self.assertRaisesRegex(ValueError, "QUESTIE_TEST_LUAC executable was not found"):
                runner.resolve_tools({"QUESTIE_TEST_LUAC": "missing"}, False)


if __name__ == "__main__":
    unittest.main()
