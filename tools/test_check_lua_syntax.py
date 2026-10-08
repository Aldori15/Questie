"""Keep encoding normalization from hiding real addon syntax failures."""
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch

import check_lua_syntax as syntax


class LuaSyntaxTests(unittest.TestCase):
    def test_only_leading_bom_is_removed_and_source_is_not_written(self):
        source = b'-- comment\r\nlocal label = "\xef\xbb\xbf"\r\n'
        for prefix in (b"", b"\xef\xbb\xbf"):
            with self.subTest(prefix=prefix):
                path = Mock()
                path.read_bytes.return_value = prefix + source
                with patch.object(syntax.subprocess, "run") as run:
                    run.return_value = subprocess.CompletedProcess([], 0, b"", b"")
                    syntax.check_lua_file(path, "luac5.1")
                run.assert_called_once_with(["luac5.1", "-p", "-"], input=source, capture_output=True)
                path.write_bytes.assert_not_called()
                path.write_text.assert_not_called()

    def test_failure_reports_original_file_and_compiler_line(self):
        path = Path("broken.lua")
        with patch.object(Path, "read_bytes", return_value=b"local =\n"), \
                patch.object(syntax.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 1, b"", b"luac: stdin:1: syntax error\n")
            with self.assertRaisesRegex(SystemExit, r"broken\.lua: luac: stdin:1: syntax error"):
                syntax.check_lua_file(path, "luac5.1")

    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUAC"), "Set QUESTIE_TEST_LUAC to a Lua compiler")
    def test_compiler_accepts_bom_without_executing_code(self):
        with patch.object(Path, "read_bytes", return_value=b'\xef\xbb\xbferror("must not execute")\n'):
            syntax.check_lua_file(Path("bom.lua"), os.environ["QUESTIE_TEST_LUAC"])

    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUAC"), "Set QUESTIE_TEST_LUAC to a Lua compiler")
    def test_compiler_still_rejects_invalid_lua_after_bom(self):
        with patch.object(Path, "read_bytes", return_value=b"\xef\xbb\xbflocal =\n"):
            with self.assertRaisesRegex(SystemExit, r"invalid\.lua:.*stdin:1:"):
                syntax.check_lua_file(Path("invalid.lua"), os.environ["QUESTIE_TEST_LUAC"])


if __name__ == "__main__":
    unittest.main()
