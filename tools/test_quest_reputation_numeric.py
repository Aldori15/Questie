"""Compare production reputation previews with independent float32 core arithmetic."""
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import unittest


def float32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


class QuestReputationNumericTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("QUESTIE_TEST_LUA"), "Set QUESTIE_TEST_LUA to a Lua 5.2+ interpreter")
    def test_signed_rewards_and_core_float32_operation_order(self):
        rng = random.Random(933)
        cases = [(250, 2, 1, 10, 1, 1, False), (-101, 2, 1, 10, 1, 1, False),
                 (250, 1, 0, 0, 1, 1, True), (250, 1, 1, 0, 0, 1, False),
                 (250, 1, 1, -100, 1, 1, False), (-250, 1, 1, 100, 1, 1, False),
                 (250, 1, 1, 0, 2 ** -149, 1, False)]
        for _ in range(1000):
            cases.append((rng.choice((-1, 1)) * rng.randrange(1, 20001), rng.uniform(0, 10),
                          rng.uniform(0, 1), rng.randrange(-150, 151), rng.uniform(0, 10),
                          rng.uniform(1, 3), rng.choice((False, True))))
        rows = []
        for base, gain, low, aura, faction, raf, grey in cases:
            gain, low, faction, raf = map(float32, (gain, low, faction, raf))
            percent = float32(100 + (aura if base > 0 else -aura))
            if grey:
                percent = float32(percent * low)
            value = 0.0
            if percent > 0 and faction > 0:
                percent = float32(percent * faction)
                percent = float32(percent * raf)
                value = float32(float32(float32(base) * percent) / 100.0)
                value = float32(value * gain)
            expected = math.trunc(value)
            rows.append("{%d,%.17g,%.17g,%d,%.17g,%.17g,%s,%d}" %
                        (base, gain, low, aura, faction, raf, str(grey).lower(), expected))
        script = '''
local modules = {}
QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end}
ExpandFactionHeader = function() end
GetNumFactions = function() return 0 end
UnitLevel = function() return 60 end
QuestieCompat = {Is335 = true, GetFactionInfo = function() end}
modules.QuestiePlayer = {HasRequiredRace = function() return false end}
local base, grey, rates
modules.QuestieDB = {
    factionIDs = {THE_ALDOR = 932, THE_SCRYERS = 934, THE_SHATAR = 935}, raceKeys = {HUMAN = 1},
    QueryQuestSingle = function(_, field)
        if field == "reputationReward" then return {{911, base}} end
        if field == "questLevel" then return grey and 40 or 60 end
    end,
    IsDailyQuest = function() return false end, IsWeeklyQuest = function() return false end,
    IsMonthlyQuest = function() return false end, IsRepeatable = function() return false end}
modules.QuestieServer = {GetQuestReputationRates = function() return rates end}
dofile("Modules/QuestieReputation.lua")
local cases = {''' + ",\n".join(rows) + '''}
for index, case in ipairs(cases) do
    base, grey = case[1], case[7]
    rates = {gain = case[2], lowLevel = case[3], auraModifier = case[4], recruitAFriend = case[6],
        grayLevel = 51, factions = {[911] = {case[5], case[5], case[5], case[5], case[5]}}}
    local reward = modules.QuestieReputation.GetReputationReward(1)
    local actual = reward[1] and reward[1][2] or 0
    assert(actual == case[8], "float32 reputation case " .. index .. ": " .. actual .. " ~= " .. case[8])
end
'''
        subprocess.run([os.environ["QUESTIE_TEST_LUA"], "-"], input=script, encoding="utf-8", check=True,
                       cwd=Path(__file__).resolve().parents[1])


if __name__ == "__main__":
    unittest.main()
