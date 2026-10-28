"""Quest caches must preserve live state while avoiding unnecessary objects."""
import subprocess
import unittest

from _test_paths import ADDON_ROOT
import db_snapshot


class QuestRequirementCacheTests(unittest.TestCase):
    def test_cached_values_live_overrides_and_replacement_handles(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        result = subprocess.run([lua, "tools/tests/test_quest_requirement_cache.lua"],
                                cwd=ADDON_ROOT, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("fresh handles passed", result.stdout)

    def test_starter_previews_and_active_quest_identity(self):
        try:
            lua = db_snapshot.lua_executable()
        except ValueError:
            self.skipTest("Lua unavailable")
        result = subprocess.run([lua, "tools/tests/test_quest_cache_invalidation.lua"],
                                cwd=ADDON_ROOT, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("stale-draw guards passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
