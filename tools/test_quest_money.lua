-- Run from the addon root with Lua 5.2+. Production receiver and copper calculation.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local ONE, TWO, THREE = 1065353216, 1073741824, 1077936128
local function setup()
    local env = setmetatable({}, {__index = _G})
    local modules, messages, prints, frame, now, level = {}, {}, {}, {}, 0, 78
    local flags = {[4] = 256, [7] = 258}
    env.floor, env.bit = math.floor, bit32
    env.bitband, env.QUEST_FLAGS_NO_MONEY_FROM_XP = bit32.band, 256
    env.GetTime = function() return now end
    env.UnitName = function() return "Tester" end
    env.UnitLevel = function() return level end
    env.GetInventoryItemID = function() return nil end
    env.QuestieCompat = {GetMaxPlayerLevel = function() return 80 end,
        RewardMoney = {[1] = 7400, [2] = -10000, [3] = 100, [4] = 100, [5] = 50, [6] = 100, [7] = 100},
        RewardMoneyDifficulty = {[2] = 1, [3] = 1}, QuestMoneyReward = {[78] = {125}, [80] = {200}}}
    env.Questie = {db = {profile = {}}, Print = function(_, value) prints[#prints + 1] = value end}
    env.SlashCmdList = {}
    env.CreateFrame = function() return frame end
    frame.RegisterEvent = function() end
    frame.SetScript = function(_, name, callback) frame[name] = callback end
    env.SendAddonMessage = function(_, payload) messages[#messages + 1] = payload end
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    modules.QuestieDB = {QueryQuestSingle = function(id, field)
        if field == "questFlags" then return flags[id] or 0 end
        return 0
    end}
    modules.QuestiePlayer = {GetPlayerLevel = function() return level end, IsMaxLevel = function() return level >= 80 end}
    modules.QuestieServerIntegrations = {Initialize = function() end, Refresh = function() end}
    assert(loadfile("Database/QuestXP/QuestieXP.lua", "t", env))()
    local xp = modules.QuestXP
    xp.db = {[1] = {80, 0}, [2] = {80, 0}, [3] = {80, 0}, [4] = {80, 0},
        [5] = {80, 1}, [6] = {-1, 0}, [7] = {80, 0}}
    xp.xpByLevel = {[60] = {1050, 50}, [78] = {2000, 50}, [80] = {2200, 50},
        [81] = {3000, 50}, [90] = {4000, 50}}
    -- Execute the production helper without needing a running quest log/UI.
    local file = assert(io.open("Compat/QuestLog.lua", "r"))
    local source = file:read("*a"); file:close()
    env.QuestXP, env.QuestiePlayer = xp, modules.QuestiePlayer
    env.QuestieDB, env.QuestieServer = modules.QuestieDB, modules.QuestieServer
    assert(load(assert(source:match("(function QuestieCompat.GetQuestLogRewardMoney.-\nend)")), "money helper", "t", env))()
    equal(env.QuestieCompat.GetQuestLogRewardMoney(1), 7400, "fallback before receiver loads")
    assert(loadfile("Modules/Network/QuestieServer.lua", "t", env))()
    local server = modules.QuestieServer
    server:Initialize()
    local sequence = 0
    local function reply(rows, caps, incomplete, protocol, sender)
        sequence = sequence + 1
        local token = messages[#messages]:match("^[^~]+~%d+~([^~]+)~")
        local header = "~" .. (protocol or "15") .. "~" .. token .. "~" .. sequence
        local function receive(value)
            frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", value, "WHISPER", sender or "Tester")
        end
        receive("BEGIN" .. header .. "~" .. (caps or "QUESTMONEY,HEARTBEAT") .. "~" .. #rows .. "~" .. #rows)
        for index, row in ipairs(rows) do receive("PART" .. header .. "~" .. index .. "~" .. row) end
        if not incomplete then receive("END" .. header) end
    end
    local function rates(normal, bonus, maxLevel)
        reply({"P:QUEST_MONEY:" .. (normal or ONE) .. ":" .. (bonus or ONE) .. ":" .. (maxLevel or 80)})
    end
    return {money = env.QuestieCompat.GetQuestLogRewardMoney, rates = rates, reply = reply,
        server = server, xp = xp, env = env, prints = prints, flags = flags,
        level = function(value) level = value end, elapse = function(value) now = now + value end}
end

local s = setup()
s.rates(TWO, THREE)
equal(s.money(1), 14800, "ordinary quest money rate")
equal(s.money(2), -10000, "quest costs remain unchanged")
equal(s.money(3), 250, "level-dependent money table uses character level")
s.rates(THREE, TWO)
equal(s.money(1), 22200, "config change updates money preview")
s.rates(0, TWO)
equal(s.money(1), 0, "zero ordinary money rate")
tests = tests + 1

s = setup(); s.level(80); s.rates(TWO, THREE)
equal(s.money(1), 14800 + 39600, "ordinary and capped-level money rates are independent")
equal(s.money(2), -10000 + 39600, "capped bonus can offset unchanged required money")
equal(s.money(3), 400 + 39600, "level-scaled normal money plus capped bonus")
equal(s.money(4), 200, "no-money-from-XP flag suppresses bonus")
equal(s.money(7), 200, "no-money-from-XP flag with other flags")
s.rates(0, TWO)
equal(s.money(1), 26400, "zero ordinary rate retains bonus")
s.rates(TWO, 0)
equal(s.money(1), 14800, "zero bonus rate retains ordinary money")
equal(s.money(99), 0, "unknown quest has no reward")
tests = tests + 1

s = setup(); s.level(80)
s.rates(1068146622, 1068146622) -- float32 1.333 for each independent component
equal(s.money(5), 465, "truncate each money component before addition")
s.level(78); s.rates(1067869798, ONE) -- float32 1.3
equal(s.money(5), 65, "float32 product rounds before int32 truncation")
s.env.QuestieCompat.RewardMoney[5] = 16777217
s.rates(ONE)
equal(s.money(5), 16777216, "integer-to-float32 conversion of copper")
tests = tests + 1

s = setup(); s.level(60); s.rates(ONE, ONE, 60)
equal(s.money(1), 7400 + 13200, "money capability supplies cap even without QUESTXP")
s.level(80); s.rates(ONE, ONE, 90)
equal(s.money(1), 7400, "above fallback cap but below live cap has no bonus")
s.level(90)
equal(s.money(1), 7400 + 1320, "bonus XP is evaluated at server cap")
s.level(81); s.rates(ONE, ONE, 80)
equal(s.money(6), 100 + 13200, "dynamic-level bonus uses cap rather than over-cap character level")
s.reply({"P:QUEST_MONEY:" .. ONE .. ":" .. ONE .. ":80",
    "P:QUEST_XP:" .. THREE .. ":" .. TWO .. ":1066192077:80"}, "QUESTMONEY,QUESTXP,HEARTBEAT")
equal(s.money(6), 13300, "quest XP rates and aura do not inflate bonus money")
tests = tests + 1

s = setup(); s.level(80); s.rates(TWO, THREE)
s.reply({"P:QUEST_MONEY:" .. THREE .. ":" .. TWO .. ":80"}, nil, true)
equal(s.money(1), 54400, "partial batch retains accepted money rates")
s.elapse(30)
equal(s.server:GetQuestMoneyRates(), nil, "expired money data")
equal(s.money(1), 20600, "expired state restores generated fallback")
s = setup(); s.rates(TWO); s.reply({}, "HEARTBEAT")
equal(s.money(1), 7400, "disabled capability restores fallback")
s = setup(); s.reply({"P:QUEST_MONEY:" .. TWO .. ":" .. THREE .. ":80"}, nil, false, "14")
equal(s.money(1), 7400, "previous protocol cannot apply rates")
tests = tests + 1

s = setup(); s.rates(TWO)
local row = "P:QUEST_MONEY:" .. THREE .. ":" .. TWO .. ":80"
for index, rows in ipairs({{}, {row, row}, {"P:QUEST_MONEY:2139095040:" .. ONE .. ":80"},
    {"P:QUEST_MONEY:" .. ONE .. ":2143289344:80"}, {"P:QUEST_MONEY:3212836864:" .. ONE .. ":80"},
    {"P:QUEST_MONEY:1148850176:" .. ONE .. ":80"}, {"P:QUEST_MONEY:1.5:" .. ONE .. ":80"},
    {"P:QUEST_MONEY:" .. ONE .. ":" .. ONE .. ":0"}, {"P:QUEST_MONEY:" .. ONE .. ":" .. ONE .. ":256"},
    {row .. ":extra"}}) do
    s.reply(rows)
    equal(s.money(1), 14800, "invalid batch is atomic " .. index)
end
s.reply({row}, "HEARTBEAT")
equal(s.money(1), 14800, "unadvertised money row rejected")
s.reply({row}, nil, false, nil, "Imposter")
equal(s.money(1), 14800, "wrong sender rejected")
s.rates(1)
equal(s.money(1), 0, "subnormal ordinary money rate")
s.env.QuestieCompat.RewardMoney[1] = 2000000000
s.rates(TWO)
equal(s.money(1), 2000000000, "unsupported ordinary conversion restores fallback")
s.level(80); s.env.QuestieCompat.RewardMoney[1] = 2147480000
s.rates(ONE, ONE)
equal(s.money(1), 2147493200, "unsupported sum restores complete generated fallback")
tests = tests + 1

s = setup(); s.rates(TWO, THREE)
s.env.SlashCmdList.QUESTIESERVER("money")
assert(s.prints[#s.prints]:find("normal 2x; max-level bonus 3x; server level cap 80", 1, true), "money diagnostic")
s.reply({}, "HEARTBEAT"); s.env.SlashCmdList.QUESTIESERVER("money")
assert(s.prints[#s.prints]:find("using generated rewards", 1, true), "fallback diagnostic")
tests = tests + 1
print("Quest money regression tests passed: " .. tests)
