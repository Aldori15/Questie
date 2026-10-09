"""Check bounded NPC constructors without regenerating the exported database."""
import os
import re
import subprocess
import unittest

import generate_acore_npc_corrections as npc


class NpcCorrectionBatchTests(unittest.TestCase):
    @staticmethod
    def batches(text):
        return text.split('QuestieCompat.RegisterCorrection("npcData", function()')[1:]

    @staticmethod
    def fixture():
        return {entry: {"name": f"NPC {entry} — patrol", "spawns": {4395: [
            [47.22, 42.4, 0, 0, 571, 0, 0, entry * 10000 + index]
            for index in range(1200)]}} for entry in range(1, 13)}

    def test_byte_budget_preserves_every_npc_and_spawn_identity(self):
        original = self.fixture()
        text = npc.format_corrections_module(original, {})
        npc.validate_lua_fragment(text, "batch fixture")
        batches = self.batches(text)
        self.assertGreater(len(batches), 1)
        merged = {}
        for batch in batches:
            self.assertLess(len(batch.encode("utf-8")), 128 * 1024 + 256)
            start = batch.index("return {") + len("return ")
            table = npc.LuaParser(npc.extract_balanced_braces(batch, start),
                                  {"npcKeys.name": 1, "npcKeys.spawns": 2}).parse()
            for entry, fields in table.items():
                self.assertNotIn(entry, merged)
                merged[entry] = {"name": fields[1], "spawns": fields[2]}
        self.assertEqual(merged, original)
        self.assertEqual(text, npc.format_corrections_module(original, {}), "output is deterministic")

    def test_entry_budget_and_empty_export(self):
        text = npc.format_corrections_module({entry: {"maxLevel": 80} for entry in range(1, 1002)}, {})
        batches = self.batches(text)
        self.assertEqual([len(re.findall(r"^        \[\d+\]", batch, re.M)) for batch in batches], [500, 500, 1])
        self.assertEqual(self.batches(npc.format_corrections_module({}, {})), [])

    def test_oversized_individual_entry_is_rejected_before_writing(self):
        with self.assertRaisesRegex(ValueError, "NPC 123 exceeds"):
            npc.format_corrections_module({123: {"name": "a" * (128 * 1024)}}, {})

    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUA"), "Set QUESTIE_TEST_LUA to a Lua 5.2+ interpreter")
    def test_lua_executes_every_batch_with_small_instruction_arrays(self):
        setup = '''
local keys = {name = 1, spawns = 2}
QuestieLoader = {ImportModule = function(_, name) return name == "QuestieDB" and {npcKeys = keys} or {zoneIDs = {}} end}
local callbacks, seen, count = {}, {}, 0
QuestieCompat = {WOW_PROJECT_ID = 11, WOW_PROJECT_WRATH_CLASSIC = 11,
    RegisterCorrection = function(_, fn) callbacks[#callbacks + 1] = fn end}
'''
        verify = '''
assert(#callbacks > 1)
for _, fn in ipairs(callbacks) do
    -- Lua 5.2's native little-endian dump stores the instruction count here.
    if _VERSION == "Lua 5.2" then
        local dump = string.dump(fn)
        local a,b,c,d = string.byte(dump,30,33)
        assert(a + b*256 + c*65536 + d*16777216 < 131072, "oversized constructor")
    end
    for entry, fields in pairs(fn()) do
        assert(not seen[entry]); seen[entry] = true; count = count + 1
        assert(#fields[2][4395] == 1200)
        assert(fields[2][4395][1][8] == entry * 10000)
        assert(fields[2][4395][1200][8] == entry * 10000 + 1199)
    end
end
assert(count == 12)
'''
        script = setup + npc.format_corrections_module(self.fixture(), {}) + verify
        subprocess.run([os.environ["QUESTIE_TEST_LUA"], "-"], input=script, encoding="utf-8", check=True)


if __name__ == "__main__":
    unittest.main()
