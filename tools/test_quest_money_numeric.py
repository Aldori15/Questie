"""Compare copper previews with independent core float32/component truncation."""
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import unittest


def float32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


class QuestMoneyNumericTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUA"), "Set QUESTIE_TEST_LUA to a Lua 5.2+ interpreter")
    def test_component_rates_and_signed_costs(self):
        rng = random.Random(7400)
        cases = [(50, 50, 1.333, 1.333, True), (-10000, 2200, 2, 3, True),
                 (7400, 2200, 0, 2, True), (7400, 2200, 2, 0, True),
                 (16777217, 2200, 1, 1, False), (50, 50, 1.3, 1, False),
                 (7400, 2200, 2 ** -149, 1, False)]
        for _ in range(1000):
            cases.append((rng.randrange(-1000000, 1000001), rng.randrange(1, 20001) * 50,
                          rng.uniform(0, 10), rng.uniform(0, 10), rng.choice((False, True))))
        rows = []
        for money, xp, normal, bonus, capped in cases:
            normal, bonus = map(float32, (normal, bonus))
            ordinary = money if money < 0 else math.trunc(float32(float32(money) * normal))
            extra = math.trunc(float32(float32(xp * 6) * bonus)) if capped else 0
            expected = ordinary + extra
            self.assertLessEqual(expected, 2147483647)
            self.assertGreaterEqual(expected, -2147483648)
            rows.append("{%d,%d,%.17g,%.17g,%s,%d}" %
                        (money, xp, normal, bonus, str(capped).lower(), expected))
        script = '''
local modules = {}
QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end}
floor = math.floor
local level, rates
UnitLevel = function() return level end
GetInventoryItemID = function() return nil end
QuestieCompat = {GetMaxPlayerLevel = function() return 80 end,
    RewardMoney = {}, RewardMoneyDifficulty = {}, QuestMoneyReward = {}}
modules.QuestieDB = {QueryQuestSingle = function() return 0 end}
modules.QuestieServer = {GetQuestMoneyRates = function() return rates end}
dofile("Database/QuestXP/QuestieXP.lua")
QuestXP, QuestieDB, QuestieServer = modules.QuestXP, modules.QuestieDB, modules.QuestieServer
QuestiePlayer = {GetPlayerLevel = function() return level end, IsMaxLevel = function() return level >= 80 end}
bitband, QUEST_FLAGS_NO_MONEY_FROM_XP = bit32.band, 256
local file = assert(io.open("Compat/QuestLog.lua", "r"))
local source = file:read("*a"); file:close()
assert(load(assert(source:match("(function QuestieCompat.GetQuestLogRewardMoney.-\\nend)"))))()
QuestXP.db[1] = {80, 0}
local cases = {''' + ",\n".join(rows) + '''}
for index, case in ipairs(cases) do
    QuestieCompat.RewardMoney[1] = case[1]
    QuestXP.xpByLevel[80] = {case[2]}
    rates = {normal = case[3], bonus = case[4], maxLevel = 80}
    level = case[5] and 80 or 78
    local actual = QuestieCompat.GetQuestLogRewardMoney(1)
    assert(actual == case[6], "float32 copper case " .. index .. ": " .. actual .. " ~= " .. case[6])
end
'''
        subprocess.run([os.environ["QUESTIE_TEST_LUA"], "-"], input=script, encoding="utf-8", check=True,
                       cwd=Path(__file__).resolve().parents[1])


if __name__ == "__main__":
    unittest.main()
