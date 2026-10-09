-- Run from the addon root with Lua 5.2+. Production receiver and XP calculation.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function setup()
    local env = setmetatable({}, {__index = _G})
    local modules, messages, frame, now, level, equipped = {}, {}, {}, 0, 60, true
    local flags = {[2] = 8, [3] = 264}
    env.floor, env.bit = math.floor, bit32
    env.GetTime = function() return now end
    env.UnitName = function() return "Tester" end
    env.UnitLevel = function() return level end
    env.GetInventoryItemID = function(_, slot) return equipped and slot == 1 and 42985 or nil end
    env.QuestieCompat = {Is335 = true, GetMaxPlayerLevel = function() return 80 end,
        GetQuestLogRewardMoney = function() return 0 end}
    env.Questie = {db = {profile = {}}, Print = function() end}
    env.SlashCmdList = {}
    env.CreateFrame = function() return frame end
    frame.RegisterEvent = function() end
    frame.SetScript = function(_, name, callback) frame[name] = callback end
    env.SendAddonMessage = function(_, payload) messages[#messages + 1] = payload end
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    modules.QuestieDB = {QueryQuestSingle = function(id, field) return field == "specialFlags" and flags[id] or 0 end}
    modules.QuestieServerIntegrations = {Initialize = function() end, Refresh = function() end}
    -- Match the addon's early XP load before the receiver is loaded.
    assert(loadfile("Database/QuestXP/QuestieXP.lua", "t", env))()
    local xp = modules.QuestXP
    xp.db = {[1] = {60, 0}, [2] = {60, 0}, [3] = {60, 0}, [4] = {-1, 0}, [5] = {60, 1}}
    xp.xpByLevel = {[60] = {1050, 50}}
    xp.itemQuestXPBonuses = {[42985] = {10}}
    equal(xp:GetQuestLogRewardXP(1), 1155, "fallback before receiver loads")
    assert(loadfile("Modules/Network/QuestieServer.lua", "t", env))()
    local server = modules.QuestieServer
    server:Initialize()
    local sequence = 0
    local function reply(rows, caps, incomplete, protocol)
        sequence = sequence + 1
        local token = messages[#messages]:match("^[^~]+~%d+~([^~]+)~")
        local header = "~" .. (protocol or "15") .. "~" .. token .. "~" .. sequence
        frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", "BEGIN" .. header .. "~" .. (caps or "QUESTXP,HEARTBEAT")
            .. "~" .. #rows .. "~" .. #rows, "WHISPER", "Tester")
        for index, row in ipairs(rows) do
            frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", "PART" .. header .. "~" .. index .. "~" .. row, "WHISPER", "Tester")
        end
        if not incomplete then frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", "END" .. header, "WHISPER", "Tester") end
    end
    local function rates(normal, df, aura, maxLevel)
        reply({"P:QUEST_XP:" .. normal .. ":" .. df .. ":" .. aura .. ":" .. (maxLevel or 80)})
    end
    return {xp = xp, server = server, env = env, modules = modules, rates = rates, reply = reply,
        level = function(value) level = value end, equip = function(value) equipped = value end,
        elapse = function(value) now = now + value end}
end

local s = setup()
s.rates(1073741824, 1077936128, 1065353216) -- 2x normal, 3x DF, 1x aura
equal(s.xp:GetQuestLogRewardXP(1), 2100, "normal rate replaces local equipment bonus")
equal(s.xp:GetQuestLogRewardXP(2), 3150, "DF rate")
equal(s.xp:GetQuestLogRewardXP(3), 3150, "DF flag with other special flags")
equal(s.xp:GetQuestLogRewardXP(4), 2100, "dynamic-level quest")
equal(s.xp:GetQuestLogRewardXP(99), 0, "unknown quest remains unknown")
s.rates(1073741824, 1077936128, 1066192077) -- aura 1.1
equal(s.xp:GetQuestLogRewardXP(1), 2310, "heirloom bonus counted once")
s.equip(false)
equal(s.xp:GetQuestLogRewardXP(1), 2310, "live aura can represent non-equipment bonuses")
s.rates(1073741824, 1077936128, 1065353216)
equal(s.xp:GetQuestLogRewardXP(1), 2100, "aura removal updates live calculation")
tests = tests + 1

s = setup()
s.rates(1068146622, 1065353216, 1066192077) -- float32 1.333, 1, 1.1
equal(s.xp:GetQuestLogRewardXP(1), 1538, "truncate rate before aura")
s.rates(1067869798, 1065353216, 1065353216) -- float32 1.3
equal(s.xp:GetQuestLogRewardXP(5), 65, "float32 product rounds before integer truncation")
s.rates(0, 1065353216, 1065353216)
equal(s.xp:GetQuestLogRewardXP(1), 0, "zero rate is authoritative")
s.rates(1065353216, 0, 0)
equal(s.xp:GetQuestLogRewardXP(1), 0, "zero aura is authoritative")
s.rates(1, 1065353216, 1065353216)
equal(s.server:GetQuestXPRates().normal, math.ldexp(1, -149), "subnormal float decoded")
equal(s.xp:GetQuestLogRewardXP(1), 0, "subnormal XP rate")
s.xp.xpByLevel[60] = {5000000}
s.rates(1148846080, 1065353216, 1065353216) -- 1000x would overflow core uint32 XP
equal(s.xp:GetQuestLogRewardXP(1), 5500000, "unsupported uint32 conversion uses safe generated fallback")
tests = tests + 1

s = setup()
s.rates(1073741824, 1065353216, 1065353216, 90)
s.level(81)
equal(s.xp:GetQuestLogRewardXP(1), 220, "live server cap allows XP above fallback cap")
s.level(90)
equal(s.xp:GetQuestLogRewardXP(1), 0, "server cap suppresses XP")
equal(s.xp:GetQuestLogRewardXP(1, true), 220, "hypothetical max-level XP display")
s.level(80)
-- Execute the actual money helper with its production base-XP call.
local file = assert(io.open("Compat/QuestLog.lua", "r"))
local source = file:read("*a"); file:close()
s.env.QuestiePlayer = {GetPlayerLevel = function() return 80 end, IsMaxLevel = function() return true end}
s.env.QuestXP, s.env.QuestieDB, s.env.QuestieServer = s.xp, s.modules.QuestieDB, s.server
s.env.bitband, s.env.QUEST_FLAGS_NO_MONEY_FROM_XP = bit32.band, 256
s.env.QuestieCompat.RewardMoney, s.env.QuestieCompat.RewardMoneyDifficulty = {[1] = 100}, {}
assert(load(assert(source:match("(function QuestieCompat.GetQuestLogRewardMoney.-\nend)")), "money helper", "t", s.env))()
equal(s.env.QuestieCompat.GetQuestLogRewardMoney(1), 760, "money uses unmodified XP")
s.rates(1077936128, 1065353216, 1066192077)
equal(s.env.QuestieCompat.GetQuestLogRewardMoney(1), 760, "XP and aura changes do not inflate max-level money")
tests = tests + 1

s = setup()
s.rates(1073741824, 1065353216, 1065353216)
s.reply({"P:QUEST_XP:1077936128:1065353216:1065353216:80"}, nil, true)
equal(s.xp:GetQuestLogRewardXP(1), 2100, "incomplete batch retains previous rates")
s.elapse(30)
equal(s.server:GetQuestXPRates(), nil, "expired state is unavailable")
equal(s.xp:GetQuestLogRewardXP(1), 1155, "expiry restores equipment fallback")
s = setup()
s.rates(1073741824, 1065353216, 1065353216)
s.reply({}, "HEARTBEAT")
equal(s.xp:GetQuestLogRewardXP(1), 1155, "disabled capability restores fallback")
s = setup()
s.reply({"P:QUEST_XP:1073741824:1065353216:1065353216:80"}, nil, false, "14")
equal(s.xp:GetQuestLogRewardXP(1), 1155, "protocol mismatch restores fallback")
tests = tests + 1

local invalid = {
    "-1", "2147483648", "2139095040", "2143289344", "4294967296", "1148846081", "1.0", "NaN", "1e3", "",
}
for _, value in ipairs(invalid) do
    for index = 1, 3 do
        s = setup()
        s.rates(1073741824, 1065353216, 1065353216)
        local fields = {"1065353216", "1065353216", "1065353216"}
        fields[index] = value
        s.reply({"P:QUEST_XP:" .. table.concat(fields, ":") .. ":80"})
        equal(s.xp:GetQuestLogRewardXP(1), 2100, "invalid multiplier cannot replace accepted state")
    end
end
for _, rows in ipairs({{}, {"P:QUEST_XP:1065353216:1065353216:1065353216"},
    {"P:QUEST_XP:1065353216:1065353216:1065353216:0"}, {"P:QUEST_XP:1065353216:1065353216:1065353216:256"},
    {"P:QUEST_XP:1065353216:1065353216:1065353216:80:extra"},
    {"P:QUEST_XP:1065353216:1065353216:1065353216:80", "P:QUEST_XP:1065353216:1065353216:1065353216:80"}}) do
    s = setup(); s.reply(rows)
    equal(s.server:HasCapability("QUESTXP"), false, "incomplete or duplicate XP state rejected")
end
s = setup(); s.reply({"P:QUEST_XP:1065353216:1065353216:1065353216:80"}, "HEARTBEAT")
equal(s.server:GetQuestXPRates(), nil, "unadvertised XP row rejected")
tests = tests + 1

print("Quest XP: " .. tests .. " regression groups passed")
