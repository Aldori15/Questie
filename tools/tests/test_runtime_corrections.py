"""The live load graph uses four runtime files and preserves dynamic behavior."""
import subprocess
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot


class RuntimeCorrectionTests(unittest.TestCase):
    def test_manifest_loads_four_runtime_modules_and_no_expansion_fix_files(self):
        paths, _ = db_snapshot.source_files(ADDON_ROOT)
        for kind in ("Item", "NPC", "Object", "Quest"):
            self.assertEqual(paths.count(f"Database/Corrections/{kind}RuntimeCorrections.lua"), 1)
            for expansion in ("classic", "tbc", "wotlk"):
                self.assertNotIn(f"Database/Corrections/{expansion}{kind}Fixes.lua", paths)

    def test_faction_precedence_helpers_and_all_darkmoon_locations(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        result = subprocess.run([lua, "tools/tests/test_runtime_corrections.lua"], cwd=ADDON_ROOT,
                                capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Runtime correction consolidation tests passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
