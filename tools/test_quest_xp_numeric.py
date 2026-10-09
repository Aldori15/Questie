"""Compare production Lua forecasts with independent core float32 reward arithmetic."""
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import unittest


def float32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def base_reward(value):
    if value <= 100:
        return 5 * ((value + 2) // 5)
    if value <= 500:
        return 10 * ((value + 5) // 10)
    if value <= 1000:
        return 25 * ((value + 12) // 25)
    return 50 * ((value + 25) // 50)


class QuestXPNumericTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUA"), "Set QUESTIE_TEST_LUA to a Lua 5.2+ interpreter")
    def test_float32_products_and_separate_uint32_truncations(self):
        rng = random.Random(335)
        cases = [(50, 1.3, 1), (1050, 1.333, 1.1), (20000, 0, 1), (20000, 1, 0),
                 (1050, 2 ** -149, 1), (1050, 1000, 1), (20000, 1, 1000)]
        for _ in range(1000):
            cases.append((rng.randrange(1, 1000000), rng.uniform(0, 100), rng.uniform(0, 10)))
        rows = []
        for base, rate, aura in cases:
            rate, aura = float32(rate), float32(aura)
            xp = math.floor(float32(float32(base_reward(base)) * rate))
            expected = math.floor(float32(float32(xp) * aura))
            self.assertLessEqual(expected, 4294967295)
            rows.append(f"{{{base},{rate:.17g},{aura:.17g},{expected}}}")
        script = '''
local modules = {}
QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end}
floor = math.floor
UnitLevel = function() return 60 end
GetInventoryItemID = function() return nil end
QuestieCompat = {GetMaxPlayerLevel = function() return 80 end}
modules.QuestieDB = {QueryQuestSingle = function() return 0 end}
local rates
modules.QuestieServer = {GetQuestXPRates = function() return rates end}
dofile("Database/QuestXP/QuestieXP.lua")
local xp = modules.QuestXP
xp.db[1] = {60, 0}
local cases = {''' + ",\n".join(rows) + '''}
for index, case in ipairs(cases) do
    xp.xpByLevel[60] = {case[1]}
    rates = {normal = case[2], dungeonFinder = 1, aura = case[3], maxLevel = 80}
    local actual = xp:GetQuestLogRewardXP(1)
    assert(actual == case[4], "float32 case " .. index .. ": " .. actual .. " ~= " .. case[4])
end
'''
        subprocess.run([os.environ["QUESTIE_TEST_LUA"], "-"], input=script, encoding="utf-8", check=True,
                       cwd=Path(__file__).resolve().parents[1])


if __name__ == "__main__":
    unittest.main()
