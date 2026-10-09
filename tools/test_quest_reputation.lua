-- Run from the addon root with Lua 5.2+. Production receiver and reputation preview.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local ONE, TWO, THREE, HALF = 1065353216, 1073741824, 1077936128, 1056964608
local function setup()
    local env = setmetatable({}, {__index = _G})
    local modules, messages, prints, frame, now, human, level = {}, {}, {}, {}, 0, false, 60
    local rewards = {[1] = {{911, 250}}, [2] = {{911, -101}}, [3] = {{911, 250}},
        [4] = {{911, 250}}, [5] = {{911, 250}}, [6] = {{911, 250}}, [7] = {{932, 250}},
        [8] = {{911, 250}}, [9] = {{911, 250}}, [10] = {{999, 250}}, [11] = {{911, -1}},
        [12] = {{911, 250}, {999, 100}}}
    local levels = {[8] = 40, [9] = -1}
    env.UnitName = function() return "Tester" end
    env.UnitLevel = function() return level end
    env.GetTime = function() return now end
    env.ExpandFactionHeader = function() end
    env.GetNumFactions = function() return 0 end
    env.QuestieCompat = {Is335 = true, GetFactionInfo = function() end,
        AzerothCoreReputationRates = {[911] = {2, 3, 4, 5, 6}}}
    env.Questie = {db = {profile = {}}, Print = function(_, message) prints[#prints + 1] = message end}
    env.SlashCmdList = {}
    env.CreateFrame = function() return frame end
    frame.RegisterEvent = function() end
    frame.SetScript = function(_, name, callback) frame[name] = callback end
    env.SendAddonMessage = function(_, payload) messages[#messages + 1] = payload end
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    modules.QuestiePlayer = {HasRequiredRace = function() return human end}
    modules.QuestieDB = {
        factionIDs = {THE_ALDOR = 932, THE_SCRYERS = 934, THE_SHATAR = 935}, raceKeys = {HUMAN = 1},
        QueryQuestSingle = function(id, field)
            if field == "reputationReward" then return rewards[id] end
            if field == "questLevel" then return levels[id] or 60 end
        end,
        IsDailyQuest = function(id) return id == 3 end,
        IsWeeklyQuest = function(id) return id == 4 end,
        IsMonthlyQuest = function(id) return id == 5 end,
        IsRepeatable = function(id) return id >= 3 and id <= 6 end,
    }
    modules.QuestieServerIntegrations = {Initialize = function() end, Refresh = function() end}
    -- Load the reward consumer first, as in the addon; no server getter exists yet.
    assert(loadfile("Modules/QuestieReputation.lua", "t", env))()
    local rep = modules.QuestieReputation
    equal(rep.GetReputationReward(1)[1][2], 500, "generated fallback before receiver loads")
    assert(loadfile("Modules/Network/QuestieServer.lua", "t", env))()
    local server = modules.QuestieServer
    server:Initialize()
    local sequence = 0
    local function reply(rows, caps, incomplete, protocol, sender)
        sequence = sequence + 1
        local token = messages[#messages]:match("^[^~]+~%d+~([^~]+)~")
        local header = "~" .. (protocol or "14") .. "~" .. token .. "~" .. sequence
        local function receive(value)
            frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", value, "WHISPER", sender or "Tester")
        end
        receive("BEGIN" .. header .. "~" .. (caps or "QUESTREP,HEARTBEAT") .. "~" .. #rows .. "~" .. #rows)
        for index, row in ipairs(rows) do receive("PART" .. header .. "~" .. index .. "~" .. row) end
        if not incomplete then receive("END" .. header) end
    end
    local function rates(gain, low, aura, raf, factionRows)
        local rows = {"P:QUEST_REP:" .. (gain or ONE) .. ":" .. (low or ONE) .. ":" .. (aura or 0)
            .. ":" .. (raf or ONE) .. ":51:" .. #(factionRows or {})}
        for _, row in ipairs(factionRows or {}) do rows[#rows + 1] = row end
        reply(rows)
    end
    return {rep = rep, server = server, env = env, rates = rates, reply = reply, rewards = rewards,
        prints = prints, human = function(value) human = value end,
        level = function(value) level = value end, elapse = function(value) now = now + value end}
end
local function reward(s, id, index) return s.rep.GetReputationReward(id)[index or 1][2] end
local function faction(id, a, b, c, d, e)
    return "T:" .. id .. ":" .. table.concat({a, b or a, c or a, d or a, e or a}, ":")
end

local s = setup()
s.rates(TWO)
equal(reward(s, 1), 500, "global reputation gain")
s.rates(THREE)
equal(reward(s, 1), 750, "config change updates live reward")
s.rates(ONE)
equal(reward(s, 1), 250, "complete empty catalog replaces generated faction overrides")
s.rates(ONE, ONE, 0, ONE, {faction(911, ONE, TWO, THREE, HALF, 0)})
for id, expected in pairs({[1] = 250, [3] = 500, [4] = 750, [5] = 125, [6] = 0}) do
    local pairs = s.rep.GetReputationReward(id)
    equal(pairs and pairs[1] and pairs[1][2] or 0, expected, "quest category " .. id)
end
equal(reward(s, 10), 250, "unlisted faction has server default 1x")
equal(s.rewards[1][1][2], 250, "generated base reward is not mutated")
tests = tests + 1

s = setup()
s.human(true)
s.rates(TWO, ONE, 10)
equal(reward(s, 1), 550, "live aura replaces racial calculation, no double bonus")
equal(reward(s, 2), -181, "positive aura reduces reputation loss")
s.human(false)
equal(reward(s, 1), 550, "live non-racial aura")
s.rates(ONE, ONE, -10)
equal(reward(s, 1), 225, "negative aura reduces gains")
equal(reward(s, 2), -111, "negative aura increases losses")
s.rates(ONE, ONE, 100)
equal(s.rep.GetReputationReward(2)[1], nil, "nonpositive loss percent suppresses reward")
s.rates(ONE, ONE, -100)
equal(s.rep.GetReputationReward(1)[1], nil, "nonpositive gain percent suppresses reward")
s.rates(ONE, ONE, 10, TWO)
equal(reward(s, 1), 550, "eligible RAF multiplier")
s.rates(ONE)
equal(reward(s, 1), 250, "aura and RAF removal")
tests = tests + 1

s = setup()
s.rates(TWO, HALF, 0)
equal(reward(s, 8), 250, "grey quest reduction")
equal(reward(s, 1), 500, "current-level quest is not grey")
equal(reward(s, 9), 500, "dynamic-level quest uses character level")
s.rates(TWO, 0)
equal(s.rep.GetReputationReward(8)[1], nil, "zero grey rate")
s.rates(0)
equal(s.rep.GetReputationReward(1)[1], nil, "zero global rate")
s.rates(ONE, ONE, 10)
equal(s.rep.GetReputationReward(11)[1], nil, "fractional negative reward truncates toward zero")
tests = tests + 1

s = setup()
s.rates(TWO)
equal(reward(s, 7), 500, "Aldor primary global rate")
equal(reward(s, 7, 2), -550, "Aldor penalty applies global rate once")
s.rates(TWO, ONE, 10)
equal(reward(s, 7), 550, "Aldor aura")
equal(reward(s, 7, 2), -605, "spillover penalty derives from unrounded primary")
tests = tests + 1

s = setup()
s.rates(THREE)
s.reply({"P:QUEST_REP:" .. TWO .. ":" .. ONE .. ":0:" .. ONE .. ":51:0"}, nil, true)
equal(reward(s, 1), 750, "partial batch preserves live data")
s.elapse(30)
equal(s.server:GetQuestReputationRates(), nil, "expired reputation data")
equal(reward(s, 1), 500, "expiry restores generated faction rates")
s = setup(); s.human(true); s.rates(TWO, ONE, 10)
s.reply({}, "HEARTBEAT")
equal(reward(s, 1), 550, "disabled capability restores generated faction rate and human bonus")
s = setup()
s.reply({"P:QUEST_REP:" .. TWO .. ":" .. ONE .. ":0:" .. ONE .. ":51:0"}, nil, false, "13")
equal(reward(s, 1), 500, "previous protocol cannot apply live rates")
tests = tests + 1

s = setup()
s.rates(THREE)
local header = "P:QUEST_REP:" .. TWO .. ":" .. ONE .. ":0:" .. ONE .. ":51:0"
local invalid = {
    {}, {header, header}, {(header:gsub(":0$", ":1"))}, {header, faction(911, ONE)},
    {(header:gsub(":0$", ":2")), faction(911, ONE), faction(911, ONE)},
    {(header:gsub(":0$", ":1")), faction(911, 2139095040)}, -- infinity
    {(header:gsub(":0$", ":1")), faction(911, 3212836864)}, -- negative
    {(header:gsub(":0$", ":1")), faction(911, 1148850176)}, -- above 1000
    {"P:QUEST_REP:2143289344:" .. ONE .. ":0:" .. ONE .. ":51:0"}, -- NaN
    {(header:gsub(":0:" .. ONE, ":10001:" .. ONE))},
    {(header:gsub(":0:" .. ONE, ":-10001:" .. ONE))},
    {(header:gsub(":51:", ":256:"))}, {(header:gsub(":0$", ":257"))},
    {(header:gsub(":0:" .. ONE, ":1.5:" .. ONE))},
}
for index, rows in ipairs(invalid) do
    s.reply(rows)
    equal(reward(s, 1), 750, "invalid reputation batch is atomic " .. index)
end
s.reply({header}, "HEARTBEAT")
equal(reward(s, 1), 750, "unadvertised rows rejected")
s.reply({header}, nil, false, nil, "Imposter")
equal(reward(s, 1), 750, "other sender rejected")
-- Catalog rows may precede the declaration, but the complete count must match.
s.reply({faction(911, TWO), (header:gsub(":0$", ":1"))})
equal(reward(s, 1), 1000, "unordered complete catalog accepted")
s.rates(ONE)
equal(reward(s, 1), 250, "deleted loaded faction override resets to 1x")
tests = tests + 1

s = setup()
local catalog = {}
for id = 1, 256 do catalog[id] = faction(id, ONE) end
s.rates(TWO, ONE, 0, ONE, catalog)
equal(s.server:GetQuestReputationRates().factionCount, 256, "complete maximum-size catalog")
catalog[#catalog + 1] = faction(257, ONE)
s.rates(THREE, ONE, 0, ONE, catalog)
equal(s.server:GetQuestReputationRates().gain, 2, "oversized catalog cannot replace accepted data")
s.reply({"P:QUEST_XP:" .. TWO .. ":" .. ONE .. ":" .. ONE .. ":80",
    "P:QUEST_REP:" .. THREE .. ":" .. ONE .. ":0:" .. ONE .. ":51:0"}, "QUESTXP,QUESTREP,HEARTBEAT")
equal(s.server:GetQuestXPRates().normal, 2, "XP and reputation capabilities coexist")
equal(reward(s, 1), 750, "reputation alongside XP")
s.rewards[12] = {{911, 250}, {999, 2000000000}}
s.rates(TWO)
equal(reward(s, 12), 500, "unsupported conversion falls back for the whole quest")
equal(reward(s, 12, 2), 2000000000, "no mixed live/generated values on overflow")
s.rewards[7] = {{932, 2000000000}}
s.rates(ONE)
equal(reward(s, 7), 2000000000, "unsupported spillover conversion uses fallback")
equal(reward(s, 7, 2), -2200000000, "existing spillover estimate retained on fallback")
tests = tests + 1

s = setup(); s.rates(TWO, HALF, 10)
s.env.SlashCmdList.QUESTIESERVER("rep 911")
assert(s.prints[#s.prints]:find("Faction 911 quest rates: normal 1x", 1, true), "faction rate diagnostic")
s.env.SlashCmdList.QUESTIESERVER("rep 99999999999999999999999999999")
assert(s.prints[#s.prints]:find("Usage:", 1, true), "invalid diagnostic faction ID")
s.reply({}, "HEARTBEAT"); s.env.SlashCmdList.QUESTIESERVER("rep")
assert(s.prints[#s.prints]:find("using generated faction rates", 1, true), "fallback diagnostic")
tests = tests + 1
print("Quest reputation regression tests passed: " .. tests)
