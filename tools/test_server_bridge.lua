-- Run from the addon directory with Lua 5.2+; no client or server is required.
-- Exercise the production receiver and integrations with a simulated addon channel.
local tests = 0
local function equal(actual, expected, context)
    assert(actual == expected, context .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function printed(s, prefix)
    for index = #s.prints, 1, -1 do
        if s.prints[index]:sub(1, #prefix) == prefix then return s.prints[index] end
    end
    return nil
end

local function setup()
    local env = setmetatable({}, {__index = _G})
    local modules, messages, states, prints, cleared = {}, {}, {}, {}, {}
    local now, frame, refreshes = 0, {}, 0
    local profile = {showEventQuests = true, showScourgeInvasionQuests = false, showSunsReachQuests = false}
    env.GetTime = function() return now end
    env.UnitName = function() return "Tester" end
    env.IsInInstance = function() return false, "none" end
    env.QuestieCompat = {Is335 = true, addonName = "Questie-335"}
    env.GetAddOnMetadata = function(name, field)
        assert(name == "Questie-335" and field == "Version", "addon metadata lookup")
        return "9.9.4-335"
    end
    env.Questie = {db = {profile = profile}, Print = function(_, message) prints[#prints + 1] = message end}
    env.SlashCmdList = {}
    env.CreateFrame = function() return frame end
    frame.RegisterEvent = function() end
    frame.SetScript = function(_, name, callback) frame[name] = callback end
    env.SendAddonMessage = function(prefix, payload, distribution, target)
        messages[#messages + 1] = {prefix = prefix, payload = payload, distribution = distribution, target = target}
    end
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    modules.QuestieEvent = {
        GetServerQuestRegistrations = function() return {} end,
        IsQuestVisibleForExpansion = function() return true end,
        IsServerQuestActive = function(id) return states[id] end,
        SetServerQuestStates = function(value)
            local changed = false
            for id, state in pairs(value) do if states[id] ~= state then changed = true end end
            for id in pairs(states) do if value[id] == nil then changed = true end end
            states = value
            return changed
        end,
        SetServerDarkmoonLocations = function() return false end,
        RefreshAvailableQuests = function() refreshes = refreshes + 1 end,
    }
    modules.QuestieQuestBlacklist = {ScourgeInvasionQuests = {}}
    modules.QuestieDB = {QueryQuestSingle = function(id) return "Quest " .. id end}
    modules.AvailableQuests = {
        ClearUnavailableQuestForLiveTransition = function(id) cleared[id] = true end,
        InvalidateWintergraspSpawnVisibility = function() end,
    }
    assert(loadfile("Modules/Network/QuestieServerIntegrations.lua", "t", env))()
    assert(loadfile("Modules/Network/QuestieServer.lua", "t", env))()
    local server = modules.QuestieServer
    server:Initialize()
    local sequence, snapshotSequence = 0, nil
    local function receive(payload, sender, distribution)
        frame.OnEvent(frame, "CHAT_MSG_ADDON", "QSTSVR", payload, distribution or "WHISPER", sender or "Tester")
    end
    local function header(version)
        local requestedVersion, token = messages[#messages].payload:match("^[^~]+~(%d+)~([^~]+)~")
        return "~" .. (version or requestedVersion) .. "~" .. token .. "~" .. sequence
    end
    local function reply(rows, caps, sender, version, dropped)
        sequence = sequence + 1
        snapshotSequence = sequence
        local batchHeader = header(version)
        receive("BEGIN" .. batchHeader .. "~" .. caps .. "~" .. #rows .. "~" .. #rows, sender)
        for index, row in ipairs(rows) do
            if dropped ~= index then receive("PART" .. batchHeader .. "~" .. index .. "~" .. row, sender) end
        end
        if dropped ~= "END" then receive("END" .. batchHeader, sender) end
        return sequence
    end
    local function snapshot(active, finished, heartbeat)
        return reply({"E:63:0:0:" .. (active and "1" or "0"), "E:64:424:1:0", "P:KA_FINISHED:" .. finished},
            "EVENTS,KALUAK" .. (heartbeat and ",HEARTBEAT" or ""))
    end
    local function heartbeat(confirmed, sender)
        sequence = sequence + 1
        local payload = "ALIVE" .. header() .. "~" .. tostring(confirmed or snapshotSequence)
        receive(payload, sender)
        return payload
    end
    local function info(protocol, status, version, revision)
        local token = messages[#messages].payload:match("^[^~]+~%d+~([^~]+)~")
        receive("INFO~1~" .. token .. "~" .. (protocol or "15") .. "~" .. (version or "0.1.0")
            .. "~" .. (revision or "abc1234") .. "~" .. (status or "READY"))
    end
    return {
        env = env, modules = modules,
        server = server, messages = messages, profile = profile, prints = prints, cleared = cleared,
        reply = reply, snapshot = snapshot, heartbeat = heartbeat, receive = receive, info = info,
        refreshes = function() return refreshes end,
        gate = function(id) return states[id] end,
        elapse = function(seconds) now = now + seconds end,
        advance = function(seconds) now = now + seconds; frame.OnUpdate(frame) end,
        refresh = function() modules.QuestieServerIntegrations:Refresh() end,
        event = function(name) frame.OnEvent(frame, name) end,
    }
end

local function availabilitySetup(s)
    local env, modules = s.env, s.modules
    local drawn, scheduled, queries = {}, {}, {}
    env.time, env.date = os.time, os.date
    env.bit = bit32
    env.UnitFactionGroup = function() return "Alliance" end
    env.GetRealmName = function() return "Test realm" end
    env.GetQuestGreenRange = function() return 100 end
    env.QuestieCompat.C_QuestLog = {IsOnQuest = function(id) return modules.QuestiePlayer.currentQuestlog[id] ~= nil end}
    env.QuestieCompat.GetQuestResetTime = function() return 3600 end
    env.QuestieCompat.GetServerTime = function()
        return 1791302400, {year = 2026, month = 10, day = 6, hour = 12, weekday = 3}
    end
    env.Questie.db.char = {complete = {}, hidden = {}}
    env.Questie.LOWLEVEL_RANGE, env.Questie.LOWLEVEL_OFFSET = "range", "offset"
    env.Questie.db.profile.lowLevelStyle = "default"
    env.Questie.Debug = function() end
    modules.ZoneDB = {zoneIDs = {ICECROWN = 210}, GetDungeons = function() return {} end}
    modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return 80 end,
        HasRequiredRace = function() return true end}
    modules.QuestieQuest = {private = {}}
    modules.l10n = setmetatable({}, {__call = function(_, text) return text end})
    assert(loadfile("Database/QuestieDB.lua", "t", env))()
    local db = modules.QuestieDB
    db.questData, db.autoBlacklist = {}, {}
    db.QueryQuestSingle = function(id, field)
        if field == "name" then return db.questData[id] and ("Quest " .. id) end
        return queries[id] and queries[id][field]
    end
    db.GetQuest = function(id) return {Id = id, Starts = {}, tagInfoWasCached = true} end
    db.IsDailyQuest = function(id) return id < 24000 end
    db.IsWeeklyQuest = function(id) return id >= 24000 end
    db.IsMonthlyQuest = function() return false end
    db.IsRepeatable, db.IsPvPQuest, db.IsDungeonQuest, db.IsRaidQuest = function() return false end,
        function() return false end, function() return false end, function() return false end
    db.IsLevelRequirementsFulfilled = function(id) return not (queries[id] and queries[id].tooHigh) end
    db.IsComplete = function() return 0 end
    db.IsTrivial = function() return false end
    db.IsAzerothCoreAvailabilityConditionFulfilled = function(_, id)
        return not (queries[id] and queries[id].blockedCondition)
    end
    db.private.CheckAchievementRequirements = function() return true end
    modules.DailyQuests = modules.DailyQuests or {}
    modules.DailyQuests.ShouldBeHidden = function() return false end
    modules.DailyQuests.IsAtDailyQuestLimit = function() return false end
    local corrections = modules.QuestieCorrections
    corrections.hiddenQuests = {}
    -- Initialize only the character caches used by production IsDoable.
    for _, fn in ipairs({db.IsDoable, db.IsDoableVerbose}) do
        for i = 1, 100 do
            local name = debug.getupvalue(fn, i)
            if not name then break end
            if name == "QuestieCorrectionshiddenQuests" then debug.setupvalue(fn, i, corrections.hiddenQuests) end
            if name == "Questiedbcharhidden" then debug.setupvalue(fn, i, env.Questie.db.char.hidden) end
        end
    end
    modules.QuestieEvent.IsEventQuestInCurrentExpansion = function() return false end
    modules.QuestieQuestBlacklist.AQWarEffortQuests = {}
    modules.QuestieQuestBlacklist.SunsReachQuests = {}
    modules.QuestieLib.GetEffectiveQuestLevel = function() return 80, 1, 0 end
    modules.IsleOfQuelDanas = {GetHiddenQuests = function() return {} end}
    modules.QuestieIconVisibility = {IsEnabledAnywhere = function() return true end}
    modules.QuestieTooltips = {lookupKeysByQuestId = {}, RemoveAvailableQuest = function() end}
    modules.QuestieMap = {questIdFrames = {}, ForQuestFrames = function(_, id) return drawn[id] end,
        UnloadQuestFrames = function(_, id) drawn[id] = nil end}
    modules.ThreadLib = {
        Thread = function(fn, _, _, callback)
            scheduled[#scheduled + 1] = {fn = fn, callback = callback}
            return {}
        end,
        ThreadCallbackInstant = function(fn, callback) fn(); if callback then callback(true) end end,
    }
    assert(loadfile("Modules/Quest/AvailableQuests.lua", "t", env))()
    local available = modules.AvailableQuests
    available.DrawAvailableQuest = function(quest) drawn[quest.Id] = true end
    local function calculate()
        available.CalculateAndDrawAll()
        while #scheduled > 0 do
            local task = table.remove(scheduled, 1)
            local co = coroutine.create(task.fn)
            repeat
                local ok, err = coroutine.resume(co)
                assert(ok, err)
            until coroutine.status(co) == "dead"
            task.callback(true)
        end
    end
    return available, db, queries, drawn, calculate
end

local function gates(s, first, second)
    equal(s.gate(24803), first, "24803 gate")
    equal(s.gate(24806), second, "24806 gate")
end

local s = setup()
equal(s.messages[1].payload:sub(1, 9), "WATCH~15~", "heartbeat protocol discovery")
gates(s, nil, nil)
s.snapshot(true, "0")
equal(s.server:HasCapability("KALUAK"), true, "Kalu'ak capability")
equal(s.server:IsKaluakDerbyFinished(), false, "no winner")
gates(s, true, false)
equal(s.server:IsEventActive(64), false, "pool event is not required")
s.snapshot(true, "1")
gates(s, false, true)
equal(s.cleared[24806], true, "winner transition clears observed unavailable quest")
s.snapshot(false, "1")
gates(s, false, false)
s.snapshot(true, "0")
gates(s, true, false)
equal(s.cleared[24803], true, "NPC recreation restores winner quest")
tests = tests + 1

s.snapshot(true, "?")
equal(s.server:IsKaluakDerbyFinished(), nil, "unloaded AI is unknown")
gates(s, nil, nil)
s.snapshot(false, "?")
gates(s, false, false)
s.reply({"E:63:0:0:1"}, "EVENTS")
gates(s, nil, nil)
s.reply({"P:KA_FINISHED:1"}, "KALUAK")
gates(s, nil, nil)
tests = tests + 1

s.snapshot(true, "1")
s.profile.showEventQuests = false
s.refresh()
gates(s, nil, nil)
s.profile.showEventQuests = true
s.refresh()
gates(s, false, true)
s.advance(31)
equal(s.server:IsKaluakDerbyFinished(), nil, "expired AI state")
gates(s, nil, nil)
s.advance(5)
equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "fixed protocol survives an outage")
tests = tests + 1

s = setup()
s.snapshot(true, "0")
s.reply({"E:63:0:0:1", "P:KA_FINISHED:1"}, "EVENTS,KALUAK", "Imposter")
gates(s, true, false)
for _, badRows in ipairs({
    {"E:63:0:0:1", "P:KA_FINISHED:2"},
    {"E:63:0:0:1", "P:KA_FINISHED:"},
    {"E:63:0:0:1", "P:KA_FINISHED:0", "P:KA_FINISHED:1"},
    {"E:63:0:0:1"},
}) do
    s.reply(badRows, "EVENTS,KALUAK")
    gates(s, true, false)
end
s.reply({"E:63:0:0:1", "P:KA_FINISHED:1"}, "EVENTS,KALUAK", nil, "2")
gates(s, true, false)
tests = tests + 1

s = setup()
for _, version in ipairs({"2", "3", "4", "5", "9", "12", "13", "14"}) do
    s.reply({"E:63:0:0:1", "P:KA_FINISHED:1"}, "EVENTS,KALUAK", nil, version)
    equal(s.server:HasCapability("EVENTS"), false, "unsupported protocol rejected")
    gates(s, nil, nil)
end
s.advance(5)
equal(#s.messages, 1, "timeout does not downgrade")
s.advance(55)
equal(s.messages[2].payload:sub(1, 9), "WATCH~15~", "retry retains current protocol")
s.snapshot(true, "1", true)
gates(s, false, true)
tests = tests + 1

s = setup()
s.snapshot(true, "0")
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Kalu'ak"), "[Server bridge] Kalu'ak turn-ins 63: true; derby finished: false", "diagnostic")
s.snapshot(true, "1")
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Kalu'ak"), "[Server bridge] Kalu'ak turn-ins 63: true; derby finished: true", "winner diagnostic")
tests = tests + 1

-- Idle renewal preserves the snapshot/token and avoids availability refreshes.
s = setup()
local firstSnapshot = s.snapshot(true, "0", true)
local firstToken = s.messages[1].payload:match("^WATCH~15~([^~]+)~")
local refreshes = s.refreshes()
for _ = 1, 9 do
    s.advance(10)
    s.heartbeat()
    equal(s.server:HasCapability("HEARTBEAT"), true, "idle state stays fresh")
    gates(s, true, false)
end
for index = 2, #s.messages do
    equal(s.messages[index].payload, "ACK~15~" .. firstToken .. "~" .. firstSnapshot, "lightweight lease renewal")
end
equal(s.refreshes(), refreshes, "heartbeats do not refresh quest icons")
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Updates"), "[Server bridge] Updates this session: 1 snapshots, 9 heartbeats", "idle counters")
tests = tests + 1

-- A changed snapshot becomes the next renewal's baseline.
local changedSnapshot = s.snapshot(true, "1", true)
gates(s, false, true)
s.advance(10)
equal(s.messages[#s.messages].payload, "ACK~15~" .. firstToken .. "~" .. changedSnapshot, "acknowledge latest state")
s.heartbeat()
gates(s, false, true)
tests = tests + 1

-- A heartbeat naming a missed snapshot requests a complete replacement.
s = setup()
s.snapshot(true, "0", true)
local originalRequest = s.messages[1].payload
s.advance(10)
s.heartbeat(999)
s.advance(1)
equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "missed snapshot resync")
assert(s.messages[#s.messages].payload ~= originalRequest, "resync must rotate the token")
s.snapshot(true, "1", true)
gates(s, false, true)
tests = tests + 1

-- Wrong senders, tokens, versions, malformed values and replay cannot refresh state.
s = setup()
s.snapshot(true, "0", true)
s.advance(10)
local token = s.messages[1].payload:match("^WATCH~15~([^~]+)~")
s.receive("ALIVE~15~" .. token .. "~2~1", "Imposter")
s.receive("ALIVE~3~" .. token .. "~2~1")
s.receive("ALIVE~15~wrongtoken~2~1")
s.receive("ALIVE~15~" .. token .. "~2~bad")
s.receive("ALIVE~15~" .. token .. "~2~1~extra")
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Live state"):find("Live state %(10s%)"), "invalid heartbeats must not refresh age")
local validHeartbeat = s.heartbeat()
s.advance(10)
s.receive(validHeartbeat)
s.server:PrintStatus()
local latestStatus = printed(s, "[Server bridge] Live state")
assert(latestStatus and latestStatus:find("Live state %(10s%)"), "replay must not reset snapshot age")
s.advance(21)
equal(s.server:HasCapability("HEARTBEAT"), false, "replay cannot prevent expiry")
gates(s, nil, nil)
tests = tests + 1

-- An expired or missing snapshot cannot be created/revived by ALIVE alone.
s = setup()
s.receive("ALIVE~15~" .. s.messages[1].payload:match("^WATCH~15~([^~]+)~") .. "~1~1")
equal(s.server:HasCapability("HEARTBEAT"), false, "heartbeat before snapshot ignored")
s.snapshot(true, "0", true)
s.elapse(31)
s.heartbeat()
equal(s.server:HasCapability("HEARTBEAT"), false, "expired heartbeat rejected before frame update")
s.advance(0)
s.heartbeat()
equal(s.server:HasCapability("HEARTBEAT"), false, "expired snapshot stays expired")
gates(s, nil, nil)
s.snapshot(true, "1", true)
gates(s, false, true)
tests = tests + 1

-- Missing PART/END packets must recover rather than prolong stale availability.
for _, dropped in ipairs({1, "END"}) do
    s = setup()
    s.snapshot(true, "0", true)
    s.advance(10)
    s.reply({"E:63:0:0:1", "P:KA_FINISHED:1"}, "EVENTS,KALUAK,HEARTBEAT", nil, nil, dropped)
    s.heartbeat()
    gates(s, true, false)
    s.advance(6)
    s.heartbeat()
    s.advance(1)
    equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "incomplete snapshot recovery")
    s.snapshot(true, "1", true)
    gates(s, false, true)
end
tests = tests + 1

-- A missing renewal reply (e.g. lost server subscription) recovers with WATCH.
s = setup()
s.snapshot(true, "0", true)
s.advance(20)
equal(s.messages[#s.messages].payload:sub(1, 7), "ACK~15~", "renewal request")
s.advance(5)
equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "renewal timeout recovery")
s.snapshot(true, "1", true)
gates(s, false, true)
tests = tests + 1

-- New subscriptions require a full snapshot, not renewal of the old catalog.
s = setup()
s.snapshot(true, "0", true)
s.advance(10)
s.server:WatchWorldState(999)
s.advance(0)
assert(s.messages[#s.messages].payload:match("^WATCH~15~[^~]+~198,999$"), "changed subscriptions require WATCH")
s.reply({"W:198:0", "W:999:123"}, "VALUES,HEARTBEAT")
equal(s.server:GetWorldState(999), 123, "new subscription value")
tests = tests + 1

-- Unadvertised heartbeats are ignored; no module applies no overrides.
s = setup()
s.snapshot(true, "1")
equal(s.server:HasCapability("KALUAK"), true, "independent capability state")
s.heartbeat()
equal(s.server:HasCapability("HEARTBEAT"), false, "unadvertised keepalive ignored")
s.advance(20)
equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "missing capability retains current protocol")
s = setup()
s.advance(5)
s.advance(55)
for _, message in ipairs(s.messages) do
    assert(message.payload:match("^WATCH~15~"), "no module must not renew or downgrade")
end
gates(s, nil, nil)
tests = tests + 1

-- Version metadata describes the handshake and cannot establish state freshness.
s = setup()
s.info()
equal(s.server:HasCapability("EVENTS"), false, "metadata does not create live state")
gates(s, nil, nil)
s.server:PrintStatus()
equal(s.prints[1], "[Server bridge] Client: Questie 9.9.4-335; protocol 15", "client version diagnostic")
equal(s.prints[2], "[Server bridge] Server: mod-questie-bridge 0.1.0; protocol 15; AC revision abc1234 (last handshake 0s ago)", "server build diagnostic")
assert(printed(s, "[Server bridge] Waiting"), "metadata still awaits a complete snapshot")
s.snapshot(true, "0", true)
s.advance(10)
s.heartbeat()
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Server:"):find("last handshake 10s ago", 1, true), "heartbeat does not refresh metadata age")
tests = tests + 1

-- A mismatch is explicit and blocks state until a compatible full connection.
s = setup()
s.info("99", "MISMATCH", "0.2.0", "def5678")
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Last handshake:"):find("client requires 15, server provides 99", 1, true), "mismatch diagnostic")
equal(s.server:HasCapability("EVENTS"), false, "mismatched connection has no state")
s.reply({"E:63:0:0:1", "P:KA_FINISHED:1"}, "EVENTS,KALUAK", nil, "99")
gates(s, nil, nil)
s.advance(60)
equal(s.messages[#s.messages].payload:sub(1, 9), "WATCH~15~", "mismatch does not downgrade")
s.info()
s.snapshot(true, "1", true)
gates(s, false, true)
tests = tests + 1

-- Disabled is distinguishable from a server that never answered.
s = setup()
s.info("15", "DISABLED")
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Last handshake:"):find("disabled", 1, true), "disabled diagnostic")
gates(s, nil, nil)
s.advance(60)
s.info()
s.snapshot(true, "0", true)
gates(s, true, false)
tests = tests + 1

-- Sender/channel/token checks, bounds and status consistency protect diagnostics.
s = setup()
token = s.messages[1].payload:match("^WATCH~15~([^~]+)~")
local metadata = "INFO~1~" .. token .. "~15~0.1.0~abc1234~READY"
s.receive(metadata, "Imposter")
s.receive(metadata, "Tester", "PARTY")
s.receive("INFO~1~wrongtoken~15~0.1.0~abc1234~READY")
s.receive("INFO~2~" .. token .. "~15~0.1.0~abc1234~READY")
s.info("0", "READY")
s.info("06", "READY")
s.info("65536", "MISMATCH")
s.info("15", "MISMATCH")
s.info("99", "READY")
s.info("99", "DISABLED")
s.info("15", "INVALID")
s.info("15", "READY", "bad|version")
s.info("15", "READY", "0.1.0", string.rep("a", 65))
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Server version"), "[Server bridge] Server version information unavailable.", "invalid metadata rejected")
s.advance(5)
s.receive(metadata)
s.server:PrintStatus()
assert(printed(s, "[Server bridge] No bridge response"), "no response diagnostic")
equal(printed(s, "[Server bridge] Server version"), "[Server bridge] Server version information unavailable.", "timed-out metadata rejected")
tests = tests + 1

-- Duplicate/late metadata cannot replace the first handshake or stop live state.
s = setup()
s.info()
s.info("99", "MISMATCH", "9.0.0")
s.snapshot(true, "0", true)
s.info("15", "DISABLED")
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Server:"):find("0.1.0; protocol 15", 1, true), "first metadata retained")
gates(s, true, false)
s.advance(20)
s.info("99", "MISMATCH")
gates(s, true, false)
s.heartbeat()
equal(s.server:HasCapability("HEARTBEAT"), true, "renewal metadata ignored")
tests = tests + 1

-- Metadata during recovery cannot revive an expired snapshot or count as an update.
s = setup()
s.info()
s.snapshot(true, "0", true)
s.advance(31)
s.info()
equal(s.server:HasCapability("HEARTBEAT"), false, "recovery metadata cannot revive state")
gates(s, nil, nil)
s.snapshot(true, "1", true)
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Updates"), "[Server bridge] Updates this session: 2 snapshots, 0 heartbeats", "metadata not counted as state updates")
gates(s, false, true)
tests = tests + 1

-- Pool membership is explicit; nonmembers stay unknown, not inactive.
s = setup()
s.reply({"Q:13830:5676:1", "Q:13832:5676:0", "Q:24579:5678:1"}, "QUESTPOOLS,HEARTBEAT")
equal(s.server:IsPooledQuestActive(13830), true, "selected daily")
equal(s.server:IsPooledQuestActive(13832), false, "inactive daily")
equal(s.server:IsPooledQuestActive(24579), true, "selected weekly")
equal(s.server:IsPooledQuestActive(99999), nil, "ordinary quest is not inferred inactive")
equal(s.server:GetQuestPoolId(13832), 5676, "membership")
equal(s.refreshes(), 1, "pool discovery refreshes availability without event changes")
s.reply({"Q:13830:5676:1", "Q:13832:5676:0", "Q:24579:5678:1"}, "QUESTPOOLS,HEARTBEAT")
equal(s.refreshes(), 1, "identical selection does not redraw icons")
equal(table.concat(s.server:GetPooledQuests(5676), ","), "13830,13832", "sorted pool members")
equal(#s.server:GetPooledQuests(999), 0, "unknown pool")
s.server:PrintStatus()
equal(printed(s, "[Server bridge] Quest pools:"),
    "[Server bridge] Quest pools: 2 pools, 3 quests, 2 selected, 0 unknown to Questie", "pool summary")
s.env.SlashCmdList.QUESTIESERVER("pool 5676")
assert(printed(s, "[Server bridge] Pool 5676: 13832 inactive"), "targeted pool diagnostic")
s.env.SlashCmdList.QUESTIESERVER("pool 0")
assert(printed(s, "[Server bridge] Usage:"), "invalid command rejected")
tests = tests + 1

-- Multiple selections and empty catalogs are valid; no one-per-pool assumption.
s.reply({"Q:13830:5676:1", "Q:13832:5676:1"}, "QUESTPOOLS,HEARTBEAT")
equal(s.refreshes(), 2, "pool rotation refreshes availability")
equal(s.server:IsPooledQuestActive(13832), true, "multi-selection pool")
s.reply({}, "QUESTPOOLS,HEARTBEAT")
equal(s.refreshes(), 3, "membership removal refreshes availability")
equal(#s.server:GetPooledQuests(), 0, "complete empty catalog")
equal(s.server:IsPooledQuestActive(13830), nil, "removed membership becomes unknown")
tests = tests + 1

-- Malformed/duplicate rows cannot partially replace a valid selection.
s = setup()
s.reply({"Q:13830:5676:1"}, "QUESTPOOLS,HEARTBEAT")
for _, rows in ipairs({
    {"Q:13830:5676:0", "Q:13830:5677:1"}, {"Q:0:5676:1"}, {"Q:13830:0:1"},
    {"Q:4294967296:5676:1"}, {"Q:13830:4294967296:1"}, {"Q:13830:5676:2"},
    {"Q:13830:5676:"}, {"Q:13830:5676:0:extra"},
}) do
    s.reply(rows, "QUESTPOOLS,HEARTBEAT")
    equal(s.server:IsPooledQuestActive(13830), true, "bad pool batch rejected atomically")
end
s.reply({"Q:13830:5676:0"}, "HEARTBEAT")
equal(s.server:IsPooledQuestActive(13830), true, "unadvertised pool data rejected")
s.reply({"Q:13830:5676:0"}, "QUESTPOOLS,HEARTBEAT", "Imposter")
equal(s.server:IsPooledQuestActive(13830), true, "wrong sender rejected")
tests = tests + 1

-- A larger catalog is discovered without a client-maintained membership list.
local rows = {}
for id = 1, 162 do rows[id] = "Q:" .. (100000 + id) .. ":10000:" .. (id == 162 and "1" or "0") end
s = setup()
s.reply(rows, "QUESTPOOLS,HEARTBEAT")
equal(#s.server:GetPooledQuests(), 162, "162 members accepted")
equal(s.server:IsPooledQuestActive(100162), true, "new member discovered")
s.modules.QuestieDB.QueryQuestSingle = function() return nil end
s.server:PrintStatus()
assert(printed(s, "[Server bridge] Quest pools:"):find("162 unknown to Questie", 1, true), "unknown data diagnosed")
s.env.SlashCmdList.QUESTIESERVER("pool 10000")
assert(printed(s, "[Server bridge] Pool 10000: 100162 selected - unknown to Questie"), "unknown quest safely displayed")
tests = tests + 1

-- Production availability, database checks and peer observations use live selection.
s = setup()
local available, db, queries, drawn, calculate = availabilitySetup(s)
for _, id in ipairs({13830, 13832, 24579, 24580, 999}) do db.questData[id] = true end
available.RemoveQuestsForToday(28742, {13830, 24579, 999})
equal(available.IsUnavailableForCurrentReset(13830), true, "preexisting daily observation")
equal(available.IsUnavailableForCurrentReset(24579), true, "preexisting weekly observation")
s.reply({"Q:13830:5676:1", "Q:13832:5676:0", "Q:24579:5678:1", "Q:24580:5678:0"}, "QUESTPOOLS,HEARTBEAT")
equal(available.IsUnavailableForCurrentReset(13830), false, "live daily overrides stale observation")
equal(available.IsUnavailableForCurrentReset(24579), false, "live weekly overrides stale observation")
equal(available.IsUnavailableForCurrentReset(999), true, "ordinary observation preserved")
equal(db.IsDoable(13832), false, "production IsDoable pool gate")
local explanation = db.IsDoableVerbose(24580, false, true, true)
assert(explanation:find("Not selected by server", 1, true), "verbose weekly gate")
calculate()
equal(drawn[13830], true, "selected daily drawn before NPC visit")
equal(drawn[24579], true, "selected weekly drawn")
equal(drawn[13832], nil, "inactive daily hidden")
equal(drawn[24580], nil, "inactive weekly hidden")
equal(drawn[999], nil, "unpooled observation still hides quest")
available.RemoveQuestsForToday(28742, {13830})
available.MergeUnavailableQuestSnapshot({daily = {{npcId = 28742, questIds = {13830}}}})
equal(drawn[13830], true, "peer inference cannot remove selected icon")
tests = tests + 1

-- Rotation removes old choices; selected state never bypasses personal requirements.
s.reply({"Q:13830:5676:0", "Q:13832:5676:1", "Q:24579:5678:0", "Q:24580:5678:1"}, "QUESTPOOLS,HEARTBEAT")
calculate()
equal(drawn[13830], nil, "old daily removed")
equal(drawn[13832], true, "new daily drawn")
equal(drawn[24579], nil, "old weekly removed")
equal(drawn[24580], true, "new weekly drawn")
s.env.Questie.db.char.complete[24580] = true
calculate()
equal(drawn[24580], nil, "completion preserved")
s.env.Questie.db.char.complete[24580] = nil
s.env.Questie.db.char.hidden[13832] = true
queries[24580] = {blockedCondition = true}
equal(db.IsDoable(13832), false, "selected pool cannot bypass manual hiding")
equal(db.IsDoable(24580), false, "selected pool cannot bypass character conditions")
calculate()
equal(drawn[13832], nil, "manual hiding preserved")
equal(drawn[24580], nil, "character conditions preserved")
s.env.Questie.db.char.hidden[13832] = nil
queries[13832] = {tooHigh = true}
available.ResetLevelRequirementCache()
calculate()
equal(drawn[13832], nil, "level requirements preserved")
tests = tests + 1

-- Expiry/capability removal restores observations without changing saved data.
queries[13832], queries[24580] = nil, nil
available.ResetLevelRequirementCache()
s.reply({"Q:13830:5676:1", "Q:24579:5678:1"}, "QUESTPOOLS,HEARTBEAT")
calculate()
equal(drawn[13830], true, "selected before expiry")
s.advance(31)
equal(s.server:IsPooledQuestActive(13830), nil, "expired selection unknown")
equal(available.IsUnavailableForCurrentReset(13830), true, "original daily fallback restored")
equal(available.IsUnavailableForCurrentReset(24579), true, "original weekly fallback restored")
calculate()
equal(drawn[13830], nil, "fallback map filter restored")
s.reply({"Q:13830:5676:1"}, "QUESTPOOLS,HEARTBEAT")
calculate()
equal(drawn[13830], true, "reconnection restores selection")
s.reply({}, "HEARTBEAT")
calculate()
equal(drawn[13830], nil, "disabled capability restores fallback")
tests = tests + 1

-- Accepted pooled quests remain doable and keep their child quests after rotation.
s = setup()
available, db, queries, drawn, calculate = availabilitySetup(s)
db.questData[12501], db.questData[12502] = true, true
queries[12501] = {childQuests = {12502}}
s.modules.QuestiePlayer.currentQuestlog[12501] = {}
s.reply({"Q:12501:386:0"}, "QUESTPOOLS,HEARTBEAT")
equal(db.IsDoable(12501), true, "accepted pooled quest remains doable")
local activeExplanation = db.IsDoableVerbose(12501, false, true, true)
assert(activeExplanation:find("Player is on quest", 1, true), "accepted quest remains active in Journey")
calculate()
equal(drawn[12502], true, "accepted parent still exposes child quest")
tests = tests + 1

-- Idle heartbeats preserve selection; dropped rotation requests a full replacement.
s = setup()
s.reply({"Q:13830:5676:1", "Q:13832:5676:0"}, "QUESTPOOLS,HEARTBEAT")
for _ = 1, 6 do s.advance(10); s.heartbeat() end
equal(s.server:IsPooledQuestActive(13830), true, "idle pool selection remains fresh")
s.reply({"Q:13830:5676:0", "Q:13832:5676:1"}, "QUESTPOOLS,HEARTBEAT", nil, nil, 2)
equal(s.server:IsPooledQuestActive(13830), true, "partial rotation never applied")
s.advance(6)
s.heartbeat()
s.advance(1)
assert(s.messages[#s.messages].payload:match("^WATCH~15~"), "missed rotation requests snapshot")
s.reply({"Q:13830:5676:0", "Q:13832:5676:1"}, "QUESTPOOLS,HEARTBEAT")
equal(s.server:IsPooledQuestActive(13832), true, "rotation recovered")
tests = tests + 1

-- Public battlefield state and explicit scripted gates are independent of direct pools.
s = setup()
s.reply({"P:WG_STATE:1:0:0", "R:13177:1", "R:13179:0", "R:13154:1", "R:13196:0"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetWintergraspState().defender, 0, "Alliance controls Wintergrasp")
equal(s.server:GetWintergraspState().battle, false, "peace is not a blanket quest gate")
equal(s.server:IsWintergraspQuestActive(13177), true, "defending quest")
equal(s.server:GetQuestAvailabilityState(13179), false, "attacking quest hidden")
equal(s.server:GetQuestAvailabilityState(999), nil, "unreported quest remains unknown")
equal(table.concat(s.server:GetStateControlledQuests(), ","), "13154,13177,13179,13196", "sorted scripted catalog")
local state = s.server:GetWintergraspState()
state.defender = 1
equal(s.server:GetWintergraspState().defender, 0, "state API returns a copy")
s.env.SlashCmdList.QUESTIESERVER("wintergrasp")
assert(printed(s, "[Server bridge] Wintergrasp:"):find("defender Alliance; attacker Horde", 1, true), "faction diagnostic")
assert(printed(s, "[Server bridge] Wintergrasp quest 13179 inactive"), "scripted gate diagnostic")
tests = tests + 1

-- Battle start changes diagnostics, but identical quest gates do not redraw icons.
local refreshes = s.refreshes()
s.reply({"P:WG_STATE:1:1:0", "R:13177:1", "R:13179:0", "R:13154:1", "R:13196:0"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetWintergraspState().battle, true, "battle started")
equal(s.refreshes(), refreshes, "battle flag alone does not redraw available quests")
s.reply({"P:WG_STATE:1:0:1", "R:13177:0", "R:13179:1", "R:13154:0", "R:13196:1"}, "WINTERGRASP,HEARTBEAT")
equal(s.refreshes(), refreshes + 1, "control change refreshes availability")
equal(s.server:GetQuestAvailabilityState(13196), true, "selected indirect attacking variant")
s.reply({"P:WG_STATE:0:0:1", "R:13177:0", "R:13179:1", "R:13154:0", "R:13196:1"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetWintergraspState().enabled, false, "disabled battlefield is still initialized")
equal(s.server:GetQuestAvailabilityState(13196), true, "scripted gates do not invent an enabled requirement")
tests = tests + 1

-- Direct selections and faction gates combine; neither positive result overrides a negative.
s = setup()
s.reply({"P:WG_STATE:1:0:1", "R:13154:0", "R:13196:1", "Q:13154:385:1", "Q:13196:9000:0"},
    "WINTERGRASP,QUESTPOOLS,HEARTBEAT")
equal(s.server:IsPooledQuestActive(13154), true, "defending pool selection remains reported")
equal(s.server:GetQuestAvailabilityState(13154), false, "pool selection cannot bypass wrong role")
equal(s.server:GetQuestAvailabilityState(13196), false, "custom direct pool can also restrict attacking variant")
equal(#s.server:GetStateControlledQuests(), 2, "overlapping catalogs are deduplicated")
s.reply({"P:WG_STATE:1:0:1", "R:13154:0", "R:13196:1"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetQuestAvailabilityState(13196), true, "Wintergrasp works with QuestPools disabled")
tests = tests + 1

-- Malformed state and gates cannot replace an earlier valid complete snapshot.
s = setup()
s.reply({"P:WG_STATE:1:0:0", "R:13177:1"}, "WINTERGRASP,HEARTBEAT")
for _, bad in ipairs({
    {"P:WG_STATE:1:0:2", "R:13177:0"}, {"P:WG_STATE:2:0:0"}, {"P:WG_STATE:1:2:0"},
    {"P:WG_STATE:?:0:?"}, {"P:WG_STATE:1:0:0:extra"}, {"P:WG_STATE:1:0:0", "P:WG_STATE:1:0:1"},
    {"P:WG_STATE:1:0:0", "R:13177:0", "R:13177:1"}, {"P:WG_STATE:1:0:0", "R:0:1"},
    {"P:WG_STATE:1:0:0", "R:4294967296:1"}, {"P:WG_STATE:1:0:0", "R:13177:2"},
    {"P:WG_STATE:1:0:0", "R:13177:1:extra"}, {"P:WG_STATE:?:?:?", "R:13177:0"}, {"R:13177:0"},
}) do
    s.reply(bad, "WINTERGRASP,HEARTBEAT")
    equal(s.server:GetQuestAvailabilityState(13177), true, "bad Wintergrasp batch rejected atomically")
end
s.reply({"P:WG_STATE:1:0:0", "R:13177:0"}, "HEARTBEAT")
equal(s.server:GetQuestAvailabilityState(13177), true, "Wintergrasp data without capability rejected")
s.reply({"P:WG_STATE:1:0:0", "R:13177:0"}, "WINTERGRASP,HEARTBEAT", "Imposter")
equal(s.server:GetQuestAvailabilityState(13177), true, "wrong sender rejected")
tests = tests + 1

-- Production map/Journey filtering overrides stale NPC observations and preserves personal restrictions.
s = setup()
available, db, queries, drawn, calculate = availabilitySetup(s)
for _, id in ipairs({13154, 13196, 13177, 13179}) do db.questData[id] = true end
available.RemoveQuestsForToday(31052, {13196})
s.reply({"P:WG_STATE:1:0:1", "R:13154:0", "R:13196:1", "R:13177:0", "R:13179:1"}, "WINTERGRASP,HEARTBEAT")
equal(available.IsUnavailableForCurrentReset(13196), false, "live attack variant overrides old NPC inference")
equal(db.IsDoable(13154), false, "wrong-role defending quest blocked")
assert(db.IsDoableVerbose(13154, false, true, true):find("Wintergrasp quest inactive", 1, true), "Journey reason")
calculate()
equal(drawn[13196], true, "indirect attack variant drawn before gossip")
equal(drawn[13154], nil, "wrong-role quest not drawn")
available.RemoveQuestsForToday(31052, {13196})
available.MergeUnavailableQuestSnapshot({daily = {{npcId = 31052, questIds = {13196}}}})
equal(drawn[13196], true, "comms cannot remove permitted attacking variant")
s.env.Questie.db.char.hidden[13196] = true
queries[13179] = {blockedCondition = true}
calculate()
equal(drawn[13196], nil, "manual visibility preserved")
equal(drawn[13179], nil, "personal conditions preserved")
s.env.Questie.db.char.hidden[13196], queries[13179] = nil, nil
s.env.Questie.db.char.complete[13196] = true
calculate()
equal(drawn[13196], nil, "completion preserved")
s.env.Questie.db.char.complete[13196] = nil
s.reply({"P:WG_STATE:1:0:0", "R:13154:1", "R:13196:0", "R:13177:1", "R:13179:0"}, "WINTERGRASP,HEARTBEAT")
calculate()
equal(drawn[13154], true, "control transition draws defending variant")
equal(drawn[13196], nil, "control transition removes attacking variant")
tests = tests + 1

-- Accepted quests survive control changes; disabled/unknown/expired reporting restores fallback.
s.modules.QuestiePlayer.currentQuestlog[13196] = {}
equal(db.IsDoable(13196), true, "accepted quest survives a control change")
assert(db.IsDoableVerbose(13196, false, true, true):find("Player is on quest", 1, true), "Journey retains accepted quest")
s.modules.QuestiePlayer.currentQuestlog[13196] = nil
s.reply({"P:WG_STATE:?:?:?"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetWintergraspState().loaded, false, "uninitialized battlefield is explicit")
equal(s.server:GetQuestAvailabilityState(13196), nil, "uninitialized battlefield keeps fallback")
equal(available.IsUnavailableForCurrentReset(13196), true, "old inference restored")
s.reply({"P:WG_STATE:1:0:1", "R:13196:1"}, "WINTERGRASP,HEARTBEAT")
calculate()
equal(drawn[13196], true, "reconnection restores authoritative state")
for _ = 1, 4 do s.advance(10); s.heartbeat() end
equal(s.server:GetQuestAvailabilityState(13196), true, "idle heartbeats preserve Wintergrasp state")
s.advance(31)
equal(s.server:GetWintergraspState(), nil, "expired Wintergrasp state unavailable")
equal(available.IsUnavailableForCurrentReset(13196), true, "expiry restores old inference")
s.reply({"P:WG_STATE:1:0:1", "R:13196:1"}, "WINTERGRASP,HEARTBEAT")
s.reply({}, "HEARTBEAT")
equal(s.server:GetQuestAvailabilityState(13196), nil, "configuration removal restores fallback")
equal(available.IsUnavailableForCurrentReset(13196), true, "configuration removal retains observations")
tests = tests + 1

-- An incomplete control change cannot alter gates; heartbeat mismatch requests replacement.
s = setup()
s.reply({"P:WG_STATE:1:0:0", "R:13177:1", "R:13179:0"}, "WINTERGRASP,HEARTBEAT")
s.reply({"P:WG_STATE:1:0:1", "R:13177:0", "R:13179:1"}, "WINTERGRASP,HEARTBEAT", nil, nil, 3)
equal(s.server:GetWintergraspState().defender, 0, "partial control change not applied")
equal(s.server:GetQuestAvailabilityState(13177), true, "old complete gates retained")
s.advance(6)
s.heartbeat()
s.advance(1)
assert(s.messages[#s.messages].payload:match("^WATCH~15~"), "missed control change requests a complete snapshot")
s.reply({"P:WG_STATE:1:0:1", "R:13177:0", "R:13179:1"}, "WINTERGRASP,HEARTBEAT")
equal(s.server:GetWintergraspState().defender, 1, "control change recovered")
equal(s.server:GetQuestAvailabilityState(13179), true, "replacement gates applied")
tests = tests + 1

-- Scripted spawn phases use live control, independently of player quest progress.
s = setup()
local env, modules = s.env, s.modules
env.bit, env.unpack = bit32, table.unpack
env.Questie.db.char = {complete = {}}
env.IsInInstance = function() return false end
assert(loadfile("Modules/Phasing.lua", "t", env))()
local phasing, phases = modules.Phasing, modules.Phasing.phases
local keep, camp = phases.WINTERGRASP_ALLIANCE_KEEP, phases.WINTERGRASP_ALLIANCE_CAMP
local hordeKeep, hordeCamp = phases.WINTERGRASP_HORDE_KEEP, phases.WINTERGRASP_HORDE_CAMP
local function visibility(aKeep, aCamp, hKeep, hCamp)
    for phase, expected in pairs({[keep] = aKeep, [camp] = aCamp, [hordeKeep] = hKeep, [hordeCamp] = hCamp}) do
        equal(phasing.IsSpawnDataVisible({48.6, 24.29, phase}), expected, "spawn phase " .. phase)
    end
end
visibility(true, true, true, true)
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
visibility(true, false, false, true)
s.reply({"P:WG_STATE:0:1:1"}, "WINTERGRASP,HEARTBEAT")
visibility(false, true, true, false)
env.IsInInstance = function() return true, "party" end
env.GetInstanceInfo = function() return "Test", "party", 1 end
env.QuestieCompat.GetCurrentPlayerMinimapWorldPosition = function() return 0, 0, 571 end
equal(phasing.IsSpawnDataVisible({1, 2, keep, 1, 571}), false, "ownership still restricts matching difficulty")
equal(phasing.IsSpawnDataVisible({1, 2, camp, 1, 571}), true, "visible phase and matching difficulty")
equal(phasing.IsSpawnDataVisible({1, 2, camp, 2, 571}), false, "difficulty restriction retained")
env.GetInstanceInfo = function() return "Test", "party", 2 end
equal(phasing.IsSpawnDataVisible({1, 2, camp, 2, 571}), true, "matching heroic difficulty retained")
env.IsInInstance = function() return false end
s.reply({"P:WG_STATE:?:?:?"}, "WINTERGRASP,HEARTBEAT")
visibility(true, true, true, true)
equal(phasing.IsSpawnVisible(phases.HAR_KOA_AT_ALTAR), true, "Har'koa initial phase retained")
env.Questie.db.char.complete[12685] = true
equal(phasing.IsSpawnVisible(phases.HAR_KOA_AT_ALTAR), false, "Har'koa completion retained")
equal(phasing.IsSpawnVisible(phases.HAR_KOA_AT_ZIM_TORGA), true, "Har'koa destination retained")
tests = tests + 1

-- Ownership refreshes even an empty quest-gate catalog; idle heartbeats do not redraw.
local manualRefreshes, questRefreshes = 0, 0
modules.QuestieMap = {
    RefreshWintergraspManualNotes = function() manualRefreshes = manualRefreshes + 1 end,
    RefreshWintergraspStarterLocations = function() end,
}
modules.QuestieQuest = {RefreshWintergraspSpawnVisibility = function() questRefreshes = questRefreshes + 1 end}
env.Questie.started = true
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
equal(manualRefreshes, 1, "first ownership refreshes manual notes")
equal(questRefreshes, 1, "first ownership refreshes accepted quests")
local availableRefreshes = s.refreshes()
s.reply({"P:WG_STATE:1:1:0"}, "WINTERGRASP,HEARTBEAT")
s.advance(10); s.heartbeat()
equal(manualRefreshes, 1, "battle and heartbeat do not redraw spawns")
equal(s.refreshes(), availableRefreshes, "battle and heartbeat do not redraw available quests")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
equal(manualRefreshes, 2, "ownership change refreshes spawns without any quest gate")
s.advance(31)
visibility(true, true, true, true)
equal(manualRefreshes, 3, "expiry restores static manual notes")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
equal(manualRefreshes, 4, "reconnect restores spawn filtering")
s.reply({}, "HEARTBEAT")
equal(manualRefreshes, 5, "capability removal restores static notes")
tests = tests + 1

-- Exercise production manual NPC notes, including hidden requests and explicit removal.
env._G = env
env.QuestieCompat.HBD, env.QuestieCompat.HBDPins = {}, {}
env.QuestieCompat.C_Timer, env.QuestieCompat.C_Map = {}, {}
modules.ZoneDB = {GetDungeonLocation = function() return nil end, IsDungeonZone = function() return false end}
modules.l10n = setmetatable({}, {__call = function(_, text) return text end})
modules.WeaponMasterSkills = {AppendSkillsToTitle = function(title) return title end}
local npc = {id = 31109, name = "Legoso", friendly = true, minLevel = 80, maxLevel = 80,
    minLevelHealth = 1, maxLevelHealth = 1, spawns = {[4197] = {{48.6, 24.29, keep}, {71.6, 32.08, camp}}}}
modules.QuestieDB.GetNPC = function() return npc end
modules.QuestieFramePool = {UnloadFrame = function(_, frame) env[frame.name] = nil end}
assert(loadfile("Modules/Map/QuestieMap.lua", "t", env))()
local map, serial = modules.QuestieMap, 0
map.DrawManualIcon = function(_, data, zone, x, y, typ)
    typ = typ or "any"
    serial = serial + 1
    local name = "manual" .. serial
    env[name] = {name = name, data = data, zone = zone, x = x, y = y}
    map.manualFrames[typ] = map.manualFrames[typ] or {}
    map.manualFrames[typ][data.id] = map.manualFrames[typ][data.id] or {}
    table.insert(map.manualFrames[typ][data.id], name)
end
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
map:ShowNPC(31109, "custom-icon", 0.9, "custom-title", {{"custom-body"}}, true, "search", true)
local frames = map:GetManualFrames(31109, "search")
equal(#frames, 1, "only fortress note drawn")
equal(frames[1].x, 48.6, "scripted fortress location")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
frames = map:GetManualFrames(31109, "search")
equal(#frames, 1, "only outside camp note drawn")
equal(frames[1].x, 71.6, "scripted camp location")
equal(frames[1].data.Icon, "custom-icon", "manual icon preserved")
equal(frames[1].data.IconScale, 0.9, "manual scale preserved")
equal(frames[1].data.ManualTooltipData.Title, "custom-title", "manual title preserved")
equal(frames[1].data.ManualTooltipData.Body[1][1], "custom-body", "manual body preserved")
s.reply({}, "HEARTBEAT")
equal(#map:GetManualFrames(31109, "search"), 2, "no bridge restores both static locations")
map:UnloadManualFrames(31109, "search")
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
equal(#map:GetManualFrames(31109, "search"), 0, "removed manual note does not return")
npc.spawns = {[4197] = {{48.6, 24.29, hordeKeep}}}
map:ShowNPC(31109, nil, nil, nil, nil, nil, "hidden")
equal(#map:GetManualFrames(31109, "hidden"), 0, "hidden manual request has no frames")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
equal(#map:GetManualFrames(31109, "hidden"), 1, "hidden request returns when visible")
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
map:ResetManualFrames("hidden")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
equal(#map:GetManualFrames(31109, "hidden"), 0, "reset removes hidden requests too")
tests = tests + 1

-- Closest-starter clustering must not keep a previously visible camp location.
npc.spawns = {[4197] = {{48.6, 24.29, keep}, {71.6, 32.08, camp}}}
modules.QuestiePlayer.currentQuestlog = {[10] = true}
modules.QuestieDB.GetQuest = function() return {Starts = {NPC = {31109}}} end
env.QuestieCompat.HBD.GetPlayerWorldPosition = function() return 0, 0 end
env.QuestieCompat.HBD.GetPlayerZone = function() return 123 end
env.QuestieCompat.HBD.GetWorldCoordinatesFromZone = function(_, x, y) return x * 100, y * 100 end
modules.ZoneDB.GetUiMapIdByAreaId = function() return 123 end
modules.QuestieLib.Euclid = function(_, _, _, x, y) return math.sqrt(x * x + y * y) end
equal(map:FindClosestStarter()[10].x, 71.6, "attacker starter cached at camp")
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
equal(map:FindClosestStarter()[10].x, 48.6, "ownership invalidates nearest starter cache")
tests = tests + 1

-- Production accepted-quest refresh includes objective spawn data and finisher-only quests.
env.QuestieCompat.GetQuestLogIndexByID = function(id) return modules.QuestiePlayer.currentQuestlog[id] and 1 end
local queued, unloaded, targets, populated = {}, {}, {}, {}
env.coroutine = setmetatable({running = function() return nil end}, {__index = coroutine})
modules.ThreadLib = {ThreadCallbackInstant = function(fn, callback)
    queued[#queued + 1] = function() fn(); callback(true) end
end}
modules.TrackerUtils = {ClearTomTomTargetForQuest = function(_, id) targets[id] = true end}
modules.AutoRoute = {ScheduleUpdate = function() end}
modules.QuestiePlayer.currentQuestlog = {
    [1] = {Id = 1, Finisher = {Type = "monster", Id = 31109}},
    [2] = {Id = 2, Objectives = {{isUpdated = true, AlreadySpawned = {[31109] = {}},
        spawnList = {{Spawns = npc.spawns}}}}},
    [3] = {Id = 3, SpecialObjectives = {{isUpdated = true, spawnList = {{Spawns = npc.spawns}}}}},
    [4] = {Id = 4, Objectives = {{isUpdated = true, spawnList = {{Spawns = {[12] = {{1, 2}}}}}}}},
}
map.UnloadQuestFrames = function(_, id) unloaded[id] = true end
assert(loadfile("Modules/Quest/QuestieQuest.lua", "t", env))()
local questModule = modules.QuestieQuest
questModule.PopulateObjectiveNotes = function(_, quest) populated[quest.Id] = true end
questModule:RefreshWintergraspSpawnVisibility()
equal(#queued, 3, "only affected accepted quests queued")
equal(modules.QuestiePlayer.currentQuestlog[2].Objectives[1].isUpdated, false, "normal objective dirty")
equal(next(modules.QuestiePlayer.currentQuestlog[2].Objectives[1].AlreadySpawned), nil, "hidden objective spawn cache reset")
equal(modules.QuestiePlayer.currentQuestlog[3].SpecialObjectives[1].isUpdated, false, "special objective dirty")
modules.QuestiePlayer.currentQuestlog[3] = nil
for _, callback in ipairs(queued) do callback() end
equal(populated[1], true, "finisher-only quest redrawn")
equal(populated[2], true, "objective quest redrawn")
equal(populated[3], nil, "abandoned quest not revived by queued refresh")
equal(unloaded[4], nil, "unrelated quest frames retained")
equal(targets[1], true, "old navigation target cleared")
tests = tests + 1

-- Quests that stay available must replace their old starter notes when control changes.
s = setup()
available, db, queries, drawn, calculate = availabilitySetup(s)
env, modules = s.env, s.modules
env.IsInInstance = function() return false end
assert(loadfile("Modules/Phasing.lua", "t", env))()
phasing, phases = modules.Phasing, modules.Phasing.phases
local officers = {
    [31153] = {spawns = {[4197] = {{50, 18, phases.WINTERGRASP_ALLIANCE_KEEP},
        {72, 32, phases.WINTERGRASP_ALLIANCE_CAMP}}}},
    [31151] = {spawns = {[4197] = {{49, 18, phases.WINTERGRASP_HORDE_KEEP},
        {22, 34, phases.WINTERGRASP_HORDE_CAMP}}}},
}
db.GetNPC = function(_, id) return officers[id] end
db.GetQuest = function(id)
    return {Id = id, Starts = {NPC = id == 13181 and {31153} or id == 13183 and {31151} or {}},
        tagInfoWasCached = true}
end
for _, id in ipairs({13181, 13183, 999}) do db.questData[id] = true end
modules.QuestieMap.RefreshWintergraspStarterLocations = function() end
modules.QuestieMap.RefreshWintergraspManualNotes = function() end
modules.QuestieQuest.RefreshWintergraspSpawnVisibility = function() end
local drawCounts, availableUnloads = {}, 0
available.DrawAvailableQuest = function(quest)
    drawCounts[quest.Id] = (drawCounts[quest.Id] or 0) + 1
    local locations = {}
    for _, id in ipairs(quest.Starts.NPC) do
        for _, points in pairs(officers[id].spawns) do
            for _, point in ipairs(points) do
                if phasing.IsSpawnDataVisible(point) then locations[#locations + 1] = point[1] end
            end
        end
    end
    drawn[quest.Id] = table.concat(locations, ",")
end
modules.QuestieMap.UnloadQuestFrames = function(_, id, _, noteType)
    equal(noteType, "available", "redraw unloads available notes only")
    availableUnloads = availableUnloads + 1
    drawn[id] = nil
end
env.Questie.started = true
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT")
calculate()
equal(drawn[13181], "50", "Alliance victory initially at fortress")
equal(drawn[13183], "22", "Horde victory initially at camp")
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT")
calculate()
equal(drawn[13181], "72", "still-available Alliance victory moves to camp")
equal(drawn[13183], "49", "still-available Horde victory moves to fortress")
equal(availableUnloads, 2, "old officer notes removed before replacement")
equal(drawCounts[999], 1, "unrelated available quest not redrawn")
calculate()
s.reply({"P:WG_STATE:1:1:1"}, "WINTERGRASP,HEARTBEAT")
s.advance(10); s.heartbeat(); calculate()
equal(drawCounts[13181], 2, "idle refresh and battle alone retain cached notes")
s.advance(31); calculate()
equal(drawn[13181], "50,72", "expiry replaces cached notes with both static locations")
equal(drawn[13183], "49,22", "expiry restores Horde static locations")
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT"); calculate()
equal(drawn[13181], "50", "reconnect replaces static notes with fortress")
env.Questie.db.char.hidden[13181] = true
s.reply({"P:WG_STATE:1:0:1"}, "WINTERGRASP,HEARTBEAT"); calculate()
equal(drawn[13181], nil, "ownership redraw preserves manual hide")
env.Questie.db.char.hidden[13181] = nil
calculate()
equal(drawn[13181], "72", "unhide uses current camp location")
s.reply({"P:WG_STATE:1:0:0"}, "WINTERGRASP,HEARTBEAT"); calculate()
equal(drawn[13181], "50", "reverse transition moves Alliance victory to fortress")
equal(drawn[13183], "22", "reverse transition moves Horde victory to camp")
tests = tests + 1

-- Progress presentation reads the existing production snapshot and quest families.
s = setup()
env, modules = s.env, s.modules
env.unpack = table.unpack
env.Questie.Colorize = function(_, text) return text end
assert(loadfile("Localization/l10n.lua", "t", env))()
assert(loadfile("Localization/Translations/ServerProgress.lua", "t", env))()
assert(loadfile("Database/Corrections/QuestieQuestBlacklist.lua", "t", env))()
modules.QuestieJourneyUtils = {GetZoneName = function(_, id) return "Zone " .. id end}
assert(loadfile("Modules/Network/QuestieServerProgress.lua", "t", env))()
local progress = modules.QuestieServerProgress
local function progressText(id) return table.concat(progress:GetQuestLines(id), "\n") end
equal(progressText(11524), "", "no bridge means no progress UI")
equal(progressText(9085), "", "unknown Scourge state adds no text")
for _, phaseCase in ipairs({
    {0, "Staging Area", 3244, "Sanctum"}, {1, "Sanctum", 3233, "Armory"}, {2, "Armory", 3238, "Harbor"},
}) do
    s.reply({"U:3426:" .. phaseCase[1], "U:" .. phaseCase[3] .. ":25"}, "QUELDANAS,HEARTBEAT")
    equal(progressText(11524), "Sun's Reach: Phase " .. (phaseCase[1] + 1) .. " (" .. phaseCase[2]
        .. ")\n" .. phaseCase[4] .. " reclamation: 25%", "phase and next reclamation percentage")
end
s.reply({"U:3426:3", "U:3223:25", "U:3275:0", "U:3269:75", "U:3228:100"}, "QUELDANAS,HEARTBEAT")
local text = progressText(11520)
assert(text:find("Portal construction: 75%", 1, true), "portal percentage")
assert(text:find("Anvil construction: 100%", 1, true), "reported 100 percent preserved")
assert(text:find("Alchemy Lab construction: 25%", 1, true), "alchemy percentage")
assert(text:find("Monument construction: 0%", 1, true), "zero percentage preserved")
equal(progressText(999), "", "unrelated quest has no progress")
assert(progressText(11521):find("Phase 4 (Harbor)", 1, true), "unlocked replacement quest has progress context")
s.reply({"U:3426:3", "U:3223:-1", "U:3275:101"}, "QUELDANAS,HEARTBEAT")
equal(progressText(11520), "Sun's Reach: Phase 4 (Harbor)", "invalid percentages and omitted projects stay absent")
tests = tests + 1

-- Scourge status and remaining counts use the six exact AC indicator/count pairs.
local scourgeRows = {"P:SC_ACTIVE:1", "U:2219:7"}
for _, pair in ipairs({{2260, 2279}, {2261, 2280}, {2262, 2281}, {2264, 2282}, {2263, 2283}, {2259, 2284}}) do
    scourgeRows[#scourgeRows + 1] = "U:" .. pair[1] .. ":1"
    scourgeRows[#scourgeRows + 1] = "U:" .. pair[2] .. ":2"
end
s.reply(scourgeRows, "SCOURGE,HEARTBEAT")
text = progressText(9085)
assert(text:find("Scourge Invasion: Active\nBattles won: 7", 1, true), "active status and battles won")
for _, id in ipairs({16, 4, 46, 139, 440, 618}) do
    assert(text:find("Zone " .. id .. ": Necropolises remaining: 2", 1, true), "matching zone count " .. id)
end
s.reply({"P:SC_ACTIVE:1", "U:2260:1", "U:2279:-1"}, "SCOURGE,HEARTBEAT")
equal(progressText(9085), "Scourge Invasion: Active\nZone 16: Under attack", "partial progress does not invent counts")
s.reply({"P:SC_ACTIVE:1", "U:2219:0", "U:2260:0", "U:2261:0", "U:2262:0", "U:2264:0", "U:2263:0", "U:2259:0"},
    "SCOURGE,HEARTBEAT")
equal(progressText(9085), "Scourge Invasion: Active\nBattles won: 0\nNo active necropolis invasions reported.", "confirmed zero zones")
s.reply({"P:SC_ACTIVE:0", "U:2219:99"}, "SCOURGE,HEARTBEAT")
equal(progressText(9085), "Scourge Invasion: Inactive", "inactive state suppresses old progress values")
tests = tests + 1

-- Production Journey tooltip hook displays progress only for fresh related data.
local tooltipLines = {}
env.GameTooltip = {
    IsShown = function() return false end, SetOwner = function() end,
    SetFrameStrata = function() end, Show = function() end,
    AddLine = function(_, line) tooltipLines[#tooltipLines + 1] = line end,
}
env._G = {QuestieJourneyFrame = {frame = {GetParent = function() return {} end}}}
modules.QuestieDB.GetQuest = function(id) return {Id = id, level = 70, name = "Quest", Description = "Description"} end
modules.QuestieLib = {FormatQuestText = function(_, text) return text end}
modules.QuestieJourney = {private = {}}
assert(loadfile("Modules/Journey/QuestieJourneyPrivates.lua", "t", env))()
s.reply({"U:3426:3", "U:3223:25"}, "QUELDANAS,HEARTBEAT")
modules.QuestieJourney.private.ShowJourneyTooltip({GetUserData = function() return 11520 end})
equal(tooltipLines[4], "World Progress", "Journey tooltip hook adds heading")
equal(tooltipLines[6], "Alchemy Lab construction: 25%", "Journey tooltip hook adds progress")
s.advance(31)
tooltipLines = {}
modules.QuestieJourney.private.ShowJourneyTooltip({GetUserData = function() return 11520 end})
equal(#tooltipLines, 2, "stale state leaves original Journey tooltip")
tests = tests + 1

-- The visible details label updates locally, expires, recovers, and detaches on release.
local created, layouts, label = 0, 0
env.LibStub = function(name)
    equal(name, "AceGUI-3.0", "widget library")
    return {Create = function(_, kind)
        equal(kind, "Label", "progress widget type")
        created = created + 1
        label = {frame = {}, callbacks = {}}
        label.SetFullWidth = function(_, value) label.fullWidth = value end
        label.SetWidth = function(_, value) label.width = value end
        label.SetText = function(_, value) label.text = value; label.height = value == "" and 0 or 20 end
        label.SetHeight = function(_, value) label.height = value end
        label.SetCallback = function(_, name, callback) label.callbacks[name] = callback end
        label.frame.SetScript = function(_, name, callback) label.frame[name] = callback end
        return label
    end}
end
local container = {AddChild = function() end, DoLayout = function() layouts = layouts + 1 end}
progress:AddQuestDetails(container, 11520)
equal(label.text, "", "stale bridge adds no visible progress")
equal(label.height, 0, "initially missing progress consumes no height")
equal(label.width, 0, "initially missing progress consumes no width")
equal(label.fullWidth, false, "empty progress does not reserve a Flow layout row")
progress:AddQuestDetails(container, 999)
equal(created, 1, "unrelated quest adds no progress widget")
s.reply({"U:3426:3", "U:3223:25"}, "QUELDANAS,HEARTBEAT")
label.frame.OnUpdate(label.frame, 1)
equal(created, 1, "connection uses existing details widget")
assert(label.text:find("Alchemy Lab construction: 25%", 1, true), "initial details progress")
equal(label.fullWidth, true, "connected progress expands to a full-width row")
local refreshCount = s.refreshes()
s.reply({"U:3426:3", "U:3223:30"}, "QUELDANAS,HEARTBEAT")
label.frame.OnUpdate(label.frame, 1)
assert(label.text:find("Alchemy Lab construction: 30%", 1, true), "open details updates without reopening")
equal(s.refreshes(), refreshCount, "progress-only change does not redraw available quests")
local layoutCount = layouts
s.advance(10); s.heartbeat(); label.frame.OnUpdate(label.frame, 1)
equal(layouts, layoutCount, "unchanged heartbeat does not relayout details")
s.advance(31); label.frame.OnUpdate(label.frame, 1)
equal(label.text, "", "expiry removes progress text")
equal(label.height, 0, "expired progress consumes no label height")
s.reply({"U:3426:3", "U:3223:40"}, "QUELDANAS,HEARTBEAT")
label.frame.OnUpdate(label.frame, 1)
assert(label.text:find("Alchemy Lab construction: 40%", 1, true), "reconnect restores visible details")
s.reply({}, "HEARTBEAT"); label.frame.OnUpdate(label.frame, 1)
equal(label.text, "", "disabled progress capability clears displayed text")
label.callbacks.OnRelease(label)
equal(label.frame.OnUpdate, nil, "released pooled widget has no update callback")
tests = tests + 1

-- Draw the production quest details through its UI hook, not only the progress helper.
local detailWidgets = {}
env.LibStub = function()
    return {Create = function(_, kind)
        local widget = {frame = {}, text = {SetFontObject = function() end}, callbacks = {}}
        widget.SetText = function(_, value) widget.value = value end
        widget.SetCallback = function(_, name, callback) widget.callbacks[name] = callback end
        widget.frame.SetScript = function(_, name, callback) widget.frame[name] = callback end
        setmetatable(widget, {__index = function() return function() end end})
        detailWidgets[#detailWidgets + 1] = widget
        return widget
    end}
end
env.UnitLevel = function() return 70 end
env.Questie.db.char = {complete = {}, hidden = {}}
modules.QuestieJourneyUtils.Spacer = function() end
modules.QuestieCorrections = {hiddenQuests = {}}
modules.QuestieReputation = {GetReputationReward = function() return nil end}
modules.QuestieLib.GetEffectiveQuestLevel = function() return 70 end
modules.QuestieLib.GetRaceString = function() return "" end
modules.QuestieLib.GetClassString = function() return "" end
modules.QuestieDB.QueryQuestSingle = function(_, field)
    if field == "requiredLevel" or field == "questLevel" then return 70 end
end
modules.QuestieDB.IsRepeatable = function() return false end
modules.QuestieDB.IsDoableVerbose = function() return "", false end
modules.QuestieDB.GetNPC = function() return {id = 1, name = "NPC"} end
assert(loadfile("Modules/Journey/QuestDetailsFrame.lua", "t", env))()
s.reply({"U:3426:3", "U:3223:25"}, "QUELDANAS,HEARTBEAT")
modules.QuestDetailsFrame:Draw(container, {Id = 11520, name = "Quest", Description = "Description", Starts = {NPC = {1}}})
local foundProgress = false
for _, widget in ipairs(detailWidgets) do
    if type(widget.value) == "string" and widget.value:find("World Progress\nSun's Reach: Phase 4", 1, true) then
        foundProgress = true
    end
end
equal(foundProgress, true, "production details hook adds world progress block")
tests = tests + 1

-- Non-holiday event gates exercise the real event override/fallback implementation,
-- production IsDoable and the available-icon calculation together.
do
    local s = setup()
    s.env.QuestieCompat.IsQuestCompletedOnServer = function() return false end
    local available, db, queries, drawn, calculate = availabilitySetup(s)
    local event = s.modules.QuestieEvent
    local corrections = s.modules.QuestieCorrections
    event.private = {}
    assert(loadfile("Database/Corrections/QuestieEvent.lua", "t", s.env))()
    local ids = {25444, 25445, 25446, 25461, 25470, 25480, 25495}
    for _, id in ipairs(ids) do db.questData[id] = true end
    db.questData[999] = true
    db.IsDailyQuest, db.IsWeeklyQuest = function() return false end, function() return false end

    -- No bridge means no override and the pre-existing ordinary quest behavior.
    calculate()
    equal(drawn[25444], true, "ordinary fallback before bridge discovery")
    s.reply({"E:61:0:0:0"}, "EVENTS,HEARTBEAT")
    for _, id in ipairs(ids) do
        equal(event.IsServerQuestActive(id), false, "inactive non-holiday gate " .. id)
        equal(db.IsDoable(id), false, "inactive event hides ordinary quest " .. id)
        equal(event.activeQuests[id], nil, "ordinary classification retained " .. id)
    end
    equal(event.IsServerQuestActive(999), nil, "unrelated quest is not gated")
    local explanation, _, reason = db.IsDoableVerbose(25444, false, true, true)
    assert(explanation:find("Event inactive", 1, true), "Journey identifies inactive non-holiday event")
    equal(reason, db.DoableStates.EVENT_INACTIVE, "non-holiday event reason")
    calculate()
    equal(drawn[25444], nil, "inactive event removes starter icon")
    equal(drawn[999], true, "unrelated starter remains")
    tests = tests + 1

    s.reply({"E:61:0:0:1"}, "EVENTS,HEARTBEAT")
    for _, id in ipairs(ids) do
        equal(event.IsServerQuestActive(id), true, "active non-holiday gate " .. id)
        equal(event.activeQuests[id], nil, "activation does not bypass ordinary level filters " .. id)
        equal(event:IsEventQuestInCurrentExpansion(id), false, "not classified as a seasonal quest " .. id)
    end
    calculate()
    equal(drawn[25444], true, "event start restores eligible starter")
    s.env.Questie.db.char.hidden[25444] = true
    queries[25445] = {blockedCondition = true}
    queries[25446] = {tooHigh = true}
    queries[25470] = {preQuestSingle = {25446}}
    s.env.Questie.db.char.complete[25461] = true
    available.ResetLevelRequirementCache()
    calculate()
    equal(drawn[25444], nil, "manual hide preserved")
    equal(drawn[25445], nil, "character condition preserved")
    equal(drawn[25446], nil, "level filter preserved")
    equal(drawn[25461], nil, "completed quest stays hidden")
    equal(drawn[25470], nil, "unfinished prerequisite keeps later quest hidden")
    s.env.Questie.db.char.complete[25446] = true
    calculate()
    equal(drawn[25470], true, "completing prerequisite unlocks later event quest")
    s.env.Questie.db.char.hidden[25444] = nil
    calculate()
    equal(drawn[25444], true, "manual unhide restores eligible starter")
    tests = tests + 1

    -- This quest chain uses ordinary visibility, independent of seasonal holiday settings.
    s.profile.showEventQuests = false
    s.refresh()
    equal(event.IsServerQuestActive(25444), true, "seasonal setting does not remove ordinary gate")
    s.reply({"E:61:0:0:0"}, "EVENTS,HEARTBEAT")
    calculate()
    equal(drawn[25444], nil, "seasonal setting cannot expose a stopped event")
    s.modules.QuestiePlayer.currentQuestlog[25444] = {Objectives = {}}
    assert(db.IsDoableVerbose(25444, false, true, true):find("Player is on quest", 1, true),
        "Journey retains accepted quest status when event stops")
    equal(s.env.Questie.db.char.complete[25461], true, "event changes preserve completion history")
    tests = tests + 1

    -- Missing event rows, disabled EVENTS, expiry and reconnection restore the original state.
    s.reply({"E:63:0:0:0"}, "EVENTS,HEARTBEAT")
    equal(event.IsServerQuestActive(25444), nil, "missing event is unknown")
    equal(corrections.hiddenQuests[25444], nil, "unknown event restores ordinary fallback")
    s.reply({"E:61:0:0:0"}, "EVENTS,HEARTBEAT")
    s.reply({}, "HEARTBEAT")
    equal(event.IsServerQuestActive(25444), nil, "disabled EVENTS removes override")
    equal(corrections.hiddenQuests[25444], nil, "disabled EVENTS restores fallback")
    s.reply({"E:61:0:0:0"}, "EVENTS,HEARTBEAT")
    s.advance(31)
    equal(event.IsServerQuestActive(25444), nil, "expired event gate is unknown")
    equal(corrections.hiddenQuests[25444], nil, "expiry restores ordinary fallback")
    s.reply({"E:61:0:0:1"}, "EVENTS,HEARTBEAT")
    equal(event.IsServerQuestActive(25444), true, "reconnection restores live event state")
    tests = tests + 1

    -- Pre-existing correction hides are restored rather than lost on capability removal.
    s.reply({}, "HEARTBEAT")
    corrections.hiddenQuests[25470] = true
    s.reply({"E:61:0:0:1"}, "EVENTS,HEARTBEAT")
    equal(corrections.hiddenQuests[25470], nil, "live active state overrides event fallback")
    s.reply({}, "HEARTBEAT")
    equal(corrections.hiddenQuests[25470], true, "original correction hide restored")
    tests = tests + 1
end

-- ICC state is personal raid context, not a global quest-pool selection.
do
    local ids = {24869, 24870, 24871, 24872, 24873, 24874, 24875, 24876, 24877, 24878, 24879, 24880}
    local families = {
        [24869] = {24869, 24875}, [24872] = {24872, 24880},
        [24873] = {24873, 24878}, [24874] = {24874, 24879},
    }
    local function iccRows(instance, difficulty, family, respiteReady, team)
        local rows = {"P:ICC_STATE:" .. instance .. ":" .. difficulty .. ":" .. family
            .. ":" .. (respiteReady and "1" or "0") .. ":" .. team}
        local active
        if family == 24870 then
            active = team == 0 and ({24871, 24876})[difficulty % 2 + 1]
                or ({24870, 24877})[difficulty % 2 + 1]
        elseif families[family] and (family ~= 24872 or respiteReady) then
            active = families[family][difficulty % 2 + 1]
        end
        for _, id in ipairs(ids) do rows[#rows + 1] = "I:" .. id .. ":" .. (id == active and "1" or "0") end
        return rows, active
    end

    -- Every difficulty and faction variant can be received without contaminating global pools.
    local s = setup()
    s.reply(iccRows(100, 0, 0, false, 0), "ICC,HEARTBEAT")
    equal(s.server:GetICCState().family, 0, "fresh raid has no weekly family yet")
    for _, id in ipairs(ids) do equal(s.server:IsICCQuestActive(id), false, "before Marrowgar gate " .. id) end
    equal(s.server:IsICCQuestActive(999), nil, "ordinary quest has no ICC gate")
    equal(#s.server:GetStateControlledQuests(), 12, "all twelve variants included in live availability")
    equal(s.server:IsPooledQuestActive(24869), nil, "ICC does not invent direct PoolMgr membership")
    s.env.SlashCmdList.QUESTIESERVER("icc")
    assert(printed(s, "[Server bridge] ICC:"):find("not selected", 1, true), "pre-Marrowgar diagnostic")
    for difficulty = 0, 3 do
        for team = 0, 1 do
            for _, family in ipairs({24869, 24870, 24872, 24873, 24874}) do
                local rows, active = iccRows(100, difficulty, family, true, team)
                s.reply(rows, "ICC,HEARTBEAT")
                equal(s.server:GetICCState().difficulty, difficulty, "reported raid difficulty")
                for _, id in ipairs(ids) do
                    equal(s.server:IsICCQuestActive(id), id == active, "ICC difficulty/family/faction gate " .. id)
                end
            end
        end
    end
    local state = s.server:GetICCState()
    state.family = 999
    equal(s.server:GetICCState().family, 24874, "public context is a copy")
    tests = tests + 1

    -- Independent addon connections follow different instances and retain saved choices on re-entry.
    local other = setup()
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    other.reply(iccRows(200, 1, 24873, false, 1), "ICC,HEARTBEAT")
    equal(s.server:IsICCQuestActive(24869), true, "first raid's family")
    equal(other.server:IsICCQuestActive(24878), true, "second raid's family and size")
    equal(other.server:IsICCQuestActive(24869), false, "second raid cannot inherit first raid choice")
    s.reply({"P:ICC_STATE:0:0:0:0:0"}, "ICC,HEARTBEAT")
    equal(s.server:GetICCState().inside, false, "outside context reported explicitly")
    equal(s.server:IsICCQuestActive(24869), nil, "leaving raid restores unknown selection")
    equal(s.server:GetICCQuests(), nil, "no current-instance catalog outside raid")
    s.env.SlashCmdList.QUESTIESERVER("icc")
    assert(printed(s, "[Server bridge] ICC:"):find("outside the raid", 1, true), "outside diagnostic")
    equal(other.server:IsICCQuestActive(24878), true, "leaving first raid cannot affect another player")
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    equal(s.server:IsICCQuestActive(24869), true, "re-entering a saved raid restores its choice")
    tests = tests + 1

    -- Respite remains selected but unavailable until Valithria is rescued.
    s.reply(iccRows(100, 2, 24872, false, 0), "ICC,HEARTBEAT")
    equal(s.server:GetICCState().family, 24872, "Respite selected while locked")
    equal(s.server:IsICCQuestActive(24872), false, "Respite waits for Valithria")
    s.env.SlashCmdList.QUESTIESERVER("icc")
    assert(printed(s, "[Server bridge] ICC: Respite unlock pending"), "unlock diagnostic")
    s.reply(iccRows(100, 2, 24872, true, 0), "ICC,HEARTBEAT")
    equal(s.server:IsICCQuestActive(24872), true, "Valithria rescue unlocks selected 10-player quest")
    equal(s.server:IsICCQuestActive(24880), false, "25-player variant remains inactive")
    tests = tests + 1

    -- Real availability and Journey checks preserve observations, personal filters and accepted quests.
    s = setup()
    local available, db, queries, drawn, calculate = availabilitySetup(s)
    for _, id in ipairs(ids) do db.questData[id] = true end
    available.RemoveQuestsForToday(38471, {24869})
    equal(available.IsUnavailableForCurrentReset(24869), true, "fallback NPC observation exists")
    s.reply(iccRows(100, 0, 0, false, 0), "ICC,HEARTBEAT")
    calculate()
    equal(drawn[24869], nil, "no weekly icon before selection")
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    calculate()
    equal(drawn[24869], true, "selected weekly icon appears without talking to NPC")
    equal(drawn[24873], nil, "other family's icon hidden")
    equal(drawn[24875], nil, "other raid size hidden")
    assert(db.IsDoableVerbose(24873, false, true, true):find("ICC weekly quest inactive", 1, true),
        "Journey explains instance selection gate")
    available.MergeUnavailableQuestSnapshot({weekly = {{npcId = 38471, questIds = {24869}}}})
    equal(drawn[24869], true, "peer observations cannot override the current instance")
    s.env.Questie.db.char.hidden[24869] = true
    calculate()
    equal(drawn[24869], nil, "manual hiding preserved")
    s.env.Questie.db.char.hidden[24869] = nil
    queries[24869] = {blockedCondition = true}
    calculate()
    equal(drawn[24869], nil, "character conditions preserved")
    queries[24869] = {tooHigh = true}
    available.ResetLevelRequirementCache()
    calculate()
    equal(drawn[24869], nil, "level filters preserved")
    queries[24869] = nil
    available.ResetLevelRequirementCache()
    s.env.Questie.db.char.complete[24869] = true
    calculate()
    equal(drawn[24869], nil, "weekly completion preserved")
    s.env.Questie.db.char.complete[24869] = nil
    s.modules.QuestiePlayer.currentQuestlog[24873] = {Objectives = {}}
    equal(db.IsDoable(24873), true, "accepted quest survives a different instance choice")
    assert(db.IsDoableVerbose(24873, false, true, true):find("Player is on quest", 1, true),
        "Journey retains accepted status")
    tests = tests + 1

    -- Direct custom pool membership still cannot bypass or be bypassed by the instance rule.
    local rows = iccRows(100, 0, 24869, false, 0)
    rows[#rows + 1], rows[#rows + 2] = "Q:24869:10000:0", "Q:24873:10000:1"
    s.reply(rows, "ICC,QUESTPOOLS,HEARTBEAT")
    equal(s.server:GetQuestAvailabilityState(24869), false, "inactive custom pool overrides permitted instance")
    equal(s.server:GetQuestAvailabilityState(24873), false, "selected custom pool cannot bypass inactive family")
    equal(#s.server:GetStateControlledQuests(), 12, "combined catalog deduplicates quest IDs")
    tests = tests + 1

    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    s.reply({"P:ICC_STATE:0:0:0:0:0"}, "ICC,HEARTBEAT")
    equal(available.IsUnavailableForCurrentReset(24869), true, "leaving restores original observation")
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    s.reply({}, "HEARTBEAT")
    equal(s.server:IsICCQuestActive(24869), nil, "disabled ICC restores fallback")
    equal(available.IsUnavailableForCurrentReset(24869), true, "disabled feature retains observation history")
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    s.advance(31)
    equal(s.server:GetICCState(), nil, "expired instance state unavailable")
    equal(available.IsUnavailableForCurrentReset(24869), true, "expiry restores fallback")
    s.reply({"P:ICC_STATE:?:?:?:?:?"}, "ICC,HEARTBEAT")
    equal(s.server:IsICCQuestActive(24869), nil, "unsupported/unobserved script stays unknown")
    tests = tests + 1

    -- Reject malformed state atomically rather than replacing a known selection with partial gates.
    s = setup()
    s.reply(iccRows(100, 0, 24869, false, 0), "ICC,HEARTBEAT")
    for _, rows in ipairs({
        {"I:24869:1"}, {"P:ICC_STATE:100:0:24869:0:0"},
        {"P:ICC_STATE:100:0:24869:0:0", "I:24875:1"},
        {"P:ICC_STATE:100:0:24869:0:0", "I:24869:1", "I:24869:0"},
        {"P:ICC_STATE:0:0:0:0:0", "I:24869:0"},
        {"P:ICC_STATE:?:?:?:?:?", "I:24869:0"},
        {"P:ICC_STATE:?:0:?:?:?"}, {"P:ICC_STATE:0:1:0:0:0"},
        {"P:ICC_STATE:100:4:24869:0:0", "I:24869:1"},
        {"P:ICC_STATE:100:0:24869:2:0", "I:24869:1"},
        {"P:ICC_STATE:100:0:24869:0:2", "I:24869:1"},
        {"P:ICC_STATE:4294967296:0:24869:0:0", "I:24869:1"},
        {"P:ICC_STATE:100:0:24869:0:0", "I:0:1"},
        {"P:ICC_STATE:100:0:24869:0:0", "I:24869:2"},
        {"P:ICC_STATE:100:0:24869:0:0", "I:24869:1", "P:ICC_STATE:100:0:24869:0:0"},
    }) do
        s.reply(rows, "ICC,HEARTBEAT")
        equal(s.server:IsICCQuestActive(24869), true, "bad ICC batch retains previous complete state")
    end
    s.reply(iccRows(200, 0, 24873, false, 0), "HEARTBEAT")
    equal(s.server:GetICCState().instance, 100, "unadvertised ICC rows rejected")
    s.reply(iccRows(200, 0, 24873, false, 0), "ICC,HEARTBEAT", "Imposter")
    equal(s.server:GetICCState().instance, 100, "wrong sender cannot change instance")
    tests = tests + 1

    -- Travel invalidates gates immediately and changes tokens to reject old replies/heartbeats.
    s = setup()
    s.env.IsInInstance = function() return true, "raid" end
    local rows = iccRows(100, 0, 24869, false, 0)
    rows[#rows + 1] = "E:61:0:0:0"
    s.reply(rows, "ICC,EVENTS,HEARTBEAT")
    local oldToken = s.messages[#s.messages].payload:match("^WATCH~15~([^~]+)~")
    local oldHeartbeat = s.heartbeat()
    s.event("PLAYER_ENTERING_WORLD")
    equal(s.server:IsICCQuestActive(24869), nil, "travel clears old instance gate immediately")
    equal(s.server:IsEventActive(61), false, "travel preserves fresh global event state")
    s.receive(oldHeartbeat)
    equal(s.server:GetICCState(), nil, "old heartbeat cannot restore raid context")
    s.advance(2)
    local newToken = s.messages[#s.messages].payload:match("^WATCH~15~([^~]+)~")
    assert(newToken and newToken ~= oldToken, "instance travel requests new token")
    s.receive("BEGIN~15~" .. oldToken .. "~999~ICC,HEARTBEAT~1~1")
    s.receive("PART~15~" .. oldToken .. "~999~1~P:ICC_STATE:0:0:0:0:0")
    s.receive("END~15~" .. oldToken .. "~999")
    equal(s.server:GetICCState(), nil, "in-flight old snapshot rejected")
    s.reply(iccRows(200, 1, 24873, false, 0), "ICC,HEARTBEAT")
    equal(s.server:GetICCState().instance, 200, "new instance confirmed")
    equal(s.server:IsICCQuestActive(24878), true, "new raid choice replaces old choice")
    equal(s.server:IsICCQuestActive(24869), false, "old choice inactive in new raid")
    s.env.IsInInstance = function() return false, "none" end
    s.event("ZONE_CHANGED_NEW_AREA")
    equal(s.server:IsICCQuestActive(24878), nil, "leaving clears old raid choice")
    s.advance(2)
    s.reply({"P:ICC_STATE:0:0:0:0:0"}, "ICC,HEARTBEAT")
    equal(s.server:GetICCState().inside, false, "outside state confirmed after travel")
    tests = tests + 1
end

-- Load the actual completion/reset compatibility code with a deterministic clock
-- and cancellable timers. The server clock deliberately differs by six hours.
local RESET_EPOCH = 1791388800
local function resetRows(weekly, monthly, serverTime)
    return {"P:QUEST_RESETS:" .. weekly .. ":" .. monthly,
        "P:SERVER_TIME:" .. (serverTime or RESET_EPOCH)}
end

local function resetSetup(state, character)
    local env, compat = state.env, state.env.QuestieCompat
    env.time, env.date, env.bit = os.time, os.date, bit32
    env.ERR_QUEST_COMPLETE_S, env.DAILY_QUESTS_REMAINING = "%s completed.", "%d dailies remaining"
    env.Questie.db.char = character or {complete = {}, weekly = {}, monthly = {}, daily = {}}
    env.Questie.db.profile.resetDailyQuests = true
    env.Questie.db.profile.weeklyResetHour = 6
    env.Questie.started = true
    env.Questie.Debug = function() end
    local draws, timers = 0, {}
    state.modules.AvailableQuests.CalculateAndDrawAll = function() draws = draws + 1 end
    local db = state.modules.QuestieDB
    db.IsWeeklyQuest = function(id) return id == 10 end
    db.IsMonthlyQuest = function(id) return id == 20 end
    db.IsDailyQuest = function(id) return id == 30 end
    db.IsRepeatable = function(id) return id == 10 or id == 20 or id == 30 end
    compat.GetServerTime = function()
        local timestamp = RESET_EPOCH + 21600 + env.GetTime()
        local currentDate = os.date("*t", timestamp)
        currentDate.weekday = currentDate.wday
        return timestamp, currentDate
    end
    compat.C_Timer = {After = function(delay, callback)
        assert(delay > 0 and delay <= 1800, "bounded positive timer")
        local timer = {due = env.GetTime() + delay, callback = callback}
        timer.Cancel = function() timer.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end}
    assert(loadfile("Compat/QuestLog.lua", "t", env))()
    return {
        char = env.Questie.db.char, compat = compat,
        draws = function() return draws end,
        runTimers = function()
            local due = {}
            for _, timer in ipairs(timers) do
                if not timer.cancelled and timer.due <= env.GetTime() then
                    timer.cancelled = true
                    due[#due + 1] = timer.callback
                end
            end
            for _, callback in ipairs(due) do callback() end
        end,
    }
end

-- Heartbeats renew freshness without moving the original server clock sample.
do
    local state = setup()
    state.reply(resetRows(RESET_EPOCH + 100, RESET_EPOCH + 1000), "RESETS,HEARTBEAT")
    state.advance(10)
    state.heartbeat()
    equal(state.server:GetQuestResetTimes().serverTime, RESET_EPOCH + 10, "clock advances across heartbeat")
    state.advance(10)
    state.heartbeat()
    equal(state.server:GetQuestResetTimes().serverTime, RESET_EPOCH + 20, "heartbeat does not rebase sample")
    state.env.SlashCmdList.QUESTIESERVER("resets")
    assert(printed(state, "[Server bridge] Weekly quest reset:"):find("in 80s", 1, true), "reset countdown")
    state.advance(31)
    equal(state.server:GetQuestResetTimes(), nil, "expired timing unavailable")
    state.env.SlashCmdList.QUESTIESERVER("resets")
    assert(printed(state, "[Server bridge] Server quest reset timing unavailable"), "fallback diagnostic")
    tests = tests + 1
end

-- Only complete, advertised, valid timing batches can replace live reset data.
do
    local state = setup()
    state.reply(resetRows(RESET_EPOCH + 100, RESET_EPOCH + 1000), "RESETS,HEARTBEAT")
    local invalid = {
        {"P:QUEST_RESETS:0:100", "P:SERVER_TIME:100"},
        {"P:QUEST_RESETS:100:0", "P:SERVER_TIME:100"},
        {"P:QUEST_RESETS:4294967296:100", "P:SERVER_TIME:100"},
        {"P:QUEST_RESETS:100:200", "P:SERVER_TIME:0"},
        {"P:QUEST_RESETS:100:200", "P:SERVER_TIME:-1"},
        {"P:QUEST_RESETS:100:200"}, {"P:SERVER_TIME:100"},
        {"P:QUEST_RESETS:100:200", "P:SERVER_TIME:100", "P:SERVER_TIME:101"},
        {"P:QUEST_RESETS:100:200", "P:QUEST_RESETS:100:200", "P:SERVER_TIME:100"},
    }
    for _, rows in ipairs(invalid) do
        state.reply(rows, "RESETS,HEARTBEAT")
        equal(state.server:GetQuestResetTimes().weekly, RESET_EPOCH + 100, "malformed timing preserves old batch")
    end
    state.reply(resetRows(100, 200, 50), "HEARTBEAT")
    equal(state.server:GetQuestResetTimes().weekly, RESET_EPOCH + 100, "unadvertised timing rejected")
    state.reply(resetRows(100, 200, 50), "RESETS,HEARTBEAT", "Imposter")
    equal(state.server:GetQuestResetTimes().weekly, RESET_EPOCH + 100, "wrong sender timing rejected")
    tests = tests + 1
end

-- First adoption corrects a guessed deadline without deleting completions.
do
    local state = setup()
    local reset = resetSetup(state)
    reset.char.weekly, reset.char.monthly = {[10] = true}, {[20] = true}
    reset.char.complete = {[10] = true, [20] = true, [30] = true, [40] = true}
    reset.char.weeklyResetTime, reset.char.monthlyResetTime = RESET_EPOCH - 1, RESET_EPOCH - 1
    state.reply(resetRows(RESET_EPOCH + 100, RESET_EPOCH + 1000), "RESETS,HEARTBEAT")
    equal(reset.char.complete[10], true, "adoption preserves weekly completion")
    equal(reset.char.complete[20], true, "adoption preserves monthly completion")
    equal(reset.char.weeklyResetTime, RESET_EPOCH + 21600 + 100, "deadline translated to fallback clock")
    equal(reset.char.serverQuestResetTimes.weekly, RESET_EPOCH + 100, "Unix marker retained")
    equal(state.profile.weeklyResetDay, nil, "user reset day not overwritten")
    tests = tests + 1
end

-- Crossing the deadline waits for the actual server rollover, then clears once.
do
    local state = setup()
    local reset = resetSetup(state)
    state.reply(resetRows(RESET_EPOCH + 10, RESET_EPOCH + 100), "RESETS,HEARTBEAT")
    reset.compat.SetQuestComplete(10)
    reset.compat.SetQuestComplete(20)
    reset.char.complete[30], reset.char.complete[40] = true, true
    state.elapse(11)
    reset.runTimers()
    equal(reset.char.complete[10], true, "deadline alone does not clear completion")
    state.reply(resetRows(RESET_EPOCH + 604810, RESET_EPOCH + 100, RESET_EPOCH + 11), "RESETS,HEARTBEAT")
    equal(reset.char.complete[10], nil, "weekly rollover clears completion")
    equal(reset.char.weekly[10], nil, "weekly history cleared")
    equal(reset.char.complete[20], true, "weekly rollover leaves monthly completion")
    equal(reset.char.complete[30], true, "daily completion unaffected")
    equal(reset.char.complete[40], true, "ordinary completion unaffected")
    reset.compat.SetQuestComplete(10)
    state.reply(resetRows(RESET_EPOCH + 604810, RESET_EPOCH + 100, RESET_EPOCH + 11), "RESETS,HEARTBEAT")
    equal(reset.char.complete[10], true, "duplicate snapshot does not clear current cycle")
    state.elapse(90)
    state.reply(resetRows(RESET_EPOCH + 604810, RESET_EPOCH + 2592100, RESET_EPOCH + 101), "RESETS,HEARTBEAT")
    equal(reset.char.complete[20], nil, "monthly rollover clears completion")
    equal(reset.char.monthly[20], nil, "monthly history cleared")
    equal(reset.char.complete[10], true, "monthly rollover leaves current weekly completion")
    assert(reset.draws() >= 2, "availability redrawn for each reset")
    tests = tests + 1
end

-- Changing a future schedule reschedules without treating it as a completed reset.
do
    local state = setup()
    local reset = resetSetup(state)
    state.reply(resetRows(RESET_EPOCH + 10, RESET_EPOCH + 100), "RESETS,HEARTBEAT")
    reset.compat.SetQuestComplete(10)
    state.elapse(5)
    state.reply(resetRows(RESET_EPOCH + 20, RESET_EPOCH + 100, RESET_EPOCH + 5), "RESETS,HEARTBEAT")
    state.elapse(6)
    reset.runTimers()
    equal(reset.char.complete[10], true, "cancelled old deadline cannot clear history")
    equal(reset.char.serverQuestResetTimes.weekly, RESET_EPOCH + 20, "replacement deadline recorded")
    tests = tests + 1
end

-- Each returning character catches up independently from its own saved deadline.
do
    local characters = {}
    for index = 1, 2 do
        local state = setup()
        local reset = resetSetup(state)
        state.reply(resetRows(RESET_EPOCH + 10, RESET_EPOCH + 100), "RESETS,HEARTBEAT")
        reset.compat.SetQuestComplete(10)
        reset.compat.SetQuestComplete(20)
        characters[index] = reset.char
    end
    for _, char in ipairs(characters) do
        local state = setup()
        local reset = resetSetup(state, char)
        state.reply(resetRows(RESET_EPOCH + 604810, RESET_EPOCH + 2592100, RESET_EPOCH + 101), "RESETS,HEARTBEAT")
        equal(reset.char.complete[10], nil, "offline weekly catch-up")
        equal(reset.char.complete[20], nil, "offline monthly catch-up")
    end
    tests = tests + 1
end

-- Disabling/losing the capability preserves entries and lets fallback timers continue.
do
    for _, expire in ipairs({false, true}) do
        local state = setup()
        local reset = resetSetup(state)
        state.reply(resetRows(RESET_EPOCH + 100, RESET_EPOCH + 1000), "RESETS,HEARTBEAT")
        reset.compat.SetQuestComplete(10)
        reset.compat.SetQuestComplete(20)
        if expire then state.advance(31) else state.reply({}, "HEARTBEAT") end
        equal(state.server:GetQuestResetTimes(), nil, "timing capability removed")
        equal(reset.char.complete[10], true, "removal preserves weekly history")
        equal(reset.char.complete[20], true, "removal preserves monthly history")
        state.elapse(101)
        reset.runTimers()
        equal(reset.char.complete[10], nil, "fallback timer clears due weekly history")
        equal(reset.char.complete[20], true, "fallback does not clear future monthly history")
    end
    tests = tests + 1
end

-- Fallback weekly migration is per-character; disabled automatic resets are respected.
do
    local state = setup()
    local reset = resetSetup(state)
    reset.char.weekly[10], reset.char.complete[10] = true, true
    state.profile.weeklyResetTime = RESET_EPOCH + 21500
    reset.compat.ResetWeeklyQuests()
    equal(reset.char.complete[10], true, "startup waits briefly for authoritative timing")
    state.elapse(5)
    reset.runTimers()
    equal(reset.char.complete[10], nil, "expired legacy weekly marker migrated and cleared")
    assert(reset.char.weeklyResetTime > reset.compat.GetServerTime(), "next weekly fallback calculated")
    reset.char.complete[10], reset.char.weekly[10] = true, true
    state.profile.resetDailyQuests = false
    state.reply(resetRows(RESET_EPOCH + 10, RESET_EPOCH + 100), "RESETS,HEARTBEAT")
    state.elapse(101)
    reset.runTimers()
    equal(reset.char.complete[10], true, "disabled auto reset preserves history")
    tests = tests + 1
end

-- A late first snapshot corrects an expired guess before it can delete history.
do
    local state = setup()
    local reset = resetSetup(state)
    reset.char.weeklyResetTime = RESET_EPOCH
    reset.char.monthlyResetTime = RESET_EPOCH
    reset.char.weekly[10], reset.char.monthly[20] = true, true
    reset.char.complete[10], reset.char.complete[20] = true, true
    reset.compat.RefreshServerQuestResets()
    state.elapse(4)
    reset.runTimers()
    equal(reset.char.complete[10], true, "expired weekly guess retained before handshake")
    equal(reset.char.complete[20], true, "expired monthly guess retained before handshake")
    state.reply(resetRows(RESET_EPOCH + 100, RESET_EPOCH + 1000, RESET_EPOCH + 4), "RESETS,HEARTBEAT")
    state.elapse(2)
    reset.runTimers()
    equal(reset.char.complete[10], true, "first snapshot corrects weekly deadline without deletion")
    equal(reset.char.complete[20], true, "first snapshot corrects monthly deadline without deletion")
    tests = tests + 1
end

-- Completion queries cannot re-merge old periodic entries after a server rollover.
do
    local state = setup()
    local reset = resetSetup(state)
    state.env.GetQuestResetTime = function() return 3600 end
    state.env.GetQuestsCompleted = function(completed)
        completed[10], completed[20], completed[40] = true, true, true
    end
    state.modules.QuestiePlayer.GetPlayerLevel = function() return 80 end
    reset.compat.Merge = function(destination, source)
        for key, value in pairs(source) do destination[key] = value end
    end
    state.reply(resetRows(RESET_EPOCH + 10, RESET_EPOCH + 100), "RESETS,HEARTBEAT")
    reset.compat.SetQuestComplete(10)
    reset.compat.SetQuestComplete(20)
    reset.compat:QUEST_QUERY_COMPLETE("QUEST_QUERY_COMPLETE")
    equal(reset.compat.IsQuestCompletedOnServer(10), true, "raw weekly completion cached")
    equal(reset.compat.IsQuestCompletedOnServer(20), true, "raw monthly completion cached")
    state.reply(resetRows(RESET_EPOCH + 604810, RESET_EPOCH + 2592100, RESET_EPOCH + 101), "RESETS,HEARTBEAT")
    equal(reset.compat.IsQuestCompletedOnServer(10), false, "rollover clears raw weekly cache")
    equal(reset.compat.IsQuestCompletedOnServer(20), false, "rollover clears raw monthly cache")
    equal(reset.char.complete[40], true, "rollover preserves queried ordinary quest")
    state.env.GetQuestsCompleted = function(completed) completed[40] = true end
    reset.compat:QUEST_QUERY_COMPLETE("QUEST_QUERY_COMPLETE")
    equal(reset.char.complete[10], nil, "query does not re-merge expired weekly completion")
    equal(reset.char.complete[20], nil, "query does not re-merge expired monthly completion")
    tests = tests + 1
end

-- Phase visibility is local, authoritative, and independent of quest eligibility.
local phaseMasks = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 19, 32, 35, 51, 64, 65, 66, 71,
    128, 129, 131, 175, 192, 193, 194, 195, 196, 197, 198, 204, 231, 243, 255, 256, 257,
    384, 448, 449, 510, 511, 65535, 2147483647, 4294967295}
local function phaseRows(mask, normal, captured, shared, everywhere, map, area, zone)
    map, area, zone = map or 571, area or 4477, zone or 210
    local rows = {"P:PHASE_CONTEXT:" .. map .. ":" .. area .. ":" .. mask .. ":" .. zone}
    local overrides = {[1] = normal, [2] = captured, [3] = shared, [4294967295] = everywhere}
    for _, spawnMask in ipairs(phaseMasks) do
        rows[#rows + 1] = "F:" .. area .. ":" .. spawnMask .. ":" .. (overrides[spawnMask] or "1")
    end
    return rows
end
do
    local state = setup()
    state.env.bit = bit32
    assert(loadfile("Modules/Phasing.lua", "t", state.env))()
    local filter = state.modules.Phasing
    local normal = {10, 20, 0, 1, 571, 1, 4477}
    local phased = {11, 21, 0, 1, 571, 2, 4477}
    equal(filter.IsSpawnDataVisible(normal), true, "no capability keeps ordinary spawn")
    equal(filter.IsSpawnDataVisible(phased), true, "no capability keeps phased spawn")
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible(normal), true, "phase 1 location visible")
    equal(filter.IsSpawnDataVisible(phased), false, "phase 2 location hidden")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 2, 4501}), true, "other story region unaffected")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 530, 2, 4477}), true, "other map unaffected")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 1024, 4477}), true, "unknown mask keeps fallback")
    equal(filter.IsSpawnDataVisible({10, 20}), true, "unannotated coordinates unchanged")
    state.reply(phaseRows(2, "0", "1"), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible(normal), false, "phase transition hides old location")
    equal(filter.IsSpawnDataVisible(phased), true, "phase transition shows new location")
    -- The server can use custom exact-equality policy; don't reconstruct decisions from the raw mask.
    state.reply(phaseRows(2, "1", "0", "0", "0"), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible(normal), true, "server decision wins over bit-overlap guess")
    equal(filter.IsSpawnDataVisible(phased), false, "authoritative false retained")
    state.reply(phaseRows(2, "0", "1", nil, nil, 571, 4501, 210), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible(normal), true, "adjacent area keeps remote locations")
    equal(filter.IsSpawnDataVisible(phased), true, "adjacent area does not infer remote phase")
    state.reply(phaseRows(2, "0", "1"), "PHASES,HEARTBEAT")
    state.event("ZONE_CHANGED")
    equal(state.server:GetPhaseContext(), nil, "area transition invalidates previous context immediately")
    equal(filter.IsSpawnDataVisible(normal), true, "pending area context falls back")
    state.advance(2)
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible(phased), false, "new context replaces old area state")
    state.advance(31)
    equal(filter.IsSpawnDataVisible(phased), true, "expired bridge restores fallback")
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    state.reply({}, "HEARTBEAT")
    equal(filter.IsSpawnDataVisible(phased), true, "disabled capability restores fallback")
    tests = tests + 1
end
do
    for _, rows in ipairs({
        {"P:PHASE_CONTEXT:571:4477:1:210"}, -- missing decisions
        {"F:4477:1:1"}, -- missing context
        {"P:PHASE_CONTEXT:571:4501:1:210", "F:4477:1:1"}, -- wrong area
        {"P:PHASE_CONTEXT:530:4477:1:210", "F:4477:1:1"}, -- wrong map
        {"P:PHASE_CONTEXT:571:4477:4294967296:210"}, -- invalid uint32
        {"P:PHASE_CONTEXT:571:4477:1:65536"}, -- invalid zone
    }) do
        local state = setup()
        state.reply(rows, "PHASES,HEARTBEAT")
        equal(state.server:GetPhaseContext(), nil, "incomplete or cross-region phase batch rejected")
    end
    local state = setup()
    local rows = phaseRows(1, "1", "0")
    rows[#rows + 1] = "F:4477:1:0"
    state.reply(rows, "PHASES,HEARTBEAT")
    equal(state.server:GetPhaseContext(), nil, "duplicate phase decisions rejected")
    tests = tests + 1
end
do
    local state = setup()
    local dirty, manual, quests = 0, 0, 0
    state.modules.AvailableQuests.InvalidateSpawnVisibility = function() dirty = dirty + 1 end
    state.modules.QuestieMap = {
        RefreshDynamicStarterLocations = function() end,
        RefreshDynamicManualNotes = function() manual = manual + 1 end,
    }
    state.modules.QuestieQuest = {RefreshSpawnVisibility = function() quests = quests + 1 end}
    state.env.Questie.started = true
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    equal(dirty, 1, "first context invalidates starter caches")
    equal(manual, 1, "first context refreshes manual locations")
    equal(quests, 1, "first context refreshes accepted quest locations")
    state.advance(10); state.heartbeat()
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    equal(dirty, 1, "unchanged snapshots and heartbeats do not redraw")
    state.reply(phaseRows(2, "0", "1"), "PHASES,HEARTBEAT")
    equal(dirty, 2, "phase transition replaces locations even when quest gates stay unchanged")
    state.advance(31)
    equal(manual, 3, "expiry refreshes manual fallback")
    equal(quests, 3, "expiry refreshes accepted quest fallback")
    tests = tests + 1
end

-- Production manual notes switch locations and preserve explicit removal for NPCs and objects.
do
    local state = setup()
    local env, mods = state.env, state.modules
    env._G, env.bit, env.unpack = env, bit32, table.unpack
    env.QuestieCompat.HBD, env.QuestieCompat.HBDPins = {}, {}
    env.QuestieCompat.C_Timer, env.QuestieCompat.C_Map = {}, {}
    mods.ZoneDB = {GetDungeonLocation = function() return nil end, IsDungeonZone = function() return false end}
    mods.l10n = setmetatable({}, {__call = function(_, text) return text end})
    mods.WeaponMasterSkills = {AppendSkillsToTitle = function(title) return title end}
    local spawns = {[210] = {{10, 20, 0, 1, 571, 1, 4477}, {11, 21, 0, 1, 571, 2, 4477}}}
    mods.QuestieDB.GetNPC = function() return {id = 29343, name = "Sliver", friendly = true,
        minLevel = 80, maxLevel = 80, minLevelHealth = 1, maxLevelHealth = 1, spawns = spawns} end
    mods.QuestieDB.GetObject = function() return {id = 192000, name = "Object", spawns = spawns} end
    mods.QuestieFramePool = {UnloadFrame = function(_, frame) env[frame.name] = nil end}
    assert(loadfile("Modules/Phasing.lua", "t", env))()
    assert(loadfile("Modules/Map/QuestieMap.lua", "t", env))()
    local map, serial = mods.QuestieMap, 0
    map.DrawManualIcon = function(_, data, zone, x, y, typ)
        typ, serial = typ or "any", serial + 1
        local name = "phaseManual" .. serial
        env[name] = {name = name, data = data, x = x, y = y}
        map.manualFrames[typ] = map.manualFrames[typ] or {}
        map.manualFrames[typ][data.id] = map.manualFrames[typ][data.id] or {}
        table.insert(map.manualFrames[typ][data.id], name)
    end
    mods.AvailableQuests.InvalidateSpawnVisibility = function() end
    mods.QuestieQuest = {RefreshSpawnVisibility = function() end}
    env.Questie.started = true
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT")
    map:ShowNPC(29343)
    map:ShowObject(192000)
    map:ShowObject(192000, nil, nil, nil, nil, nil, "search")
    equal(map:GetManualFrames(29343)[1].x, 10, "manual NPC starts in mask-1 location")
    equal(map:GetManualFrames(-192000)[1].x, 10, "default object uses negative frame key")
    equal(map:GetManualFrames(192000, "search")[1].x, 10, "typed object retains existing frame key")
    state.reply(phaseRows(2, "0", "1"), "PHASES,HEARTBEAT")
    equal(#map:GetManualFrames(29343), 1, "old NPC marker removed")
    equal(map:GetManualFrames(29343)[1].x, 11, "NPC marker follows phase")
    equal(#map:GetManualFrames(-192000), 1, "old object marker removed")
    equal(map:GetManualFrames(-192000)[1].x, 11, "object marker follows phase")
    equal(map:GetManualFrames(192000, "search")[1].x, 11, "typed object marker follows phase")
    map:UnloadManualFrames(-192000)
    state.reply(phaseRows(2, "0", "1", nil, nil, 571, 4501, 210), "PHASES,HEARTBEAT")
    equal(#map:GetManualFrames(29343), 2, "manual NPC restores both fallback locations")
    equal(#map:GetManualFrames(-192000), 0, "explicitly removed object is not resurrected")
    equal(#map:GetManualFrames(192000, "search"), 2, "typed object restores fallback locations")
    tests = tests + 1
end

-- Still-available quests must replace cached locations on a story-phase transition.
do
    local state = setup()
    local available, db, _, drawn, calculate = availabilitySetup(state)
    local mods, env = state.modules, state.env
    env.IsInInstance = function() return false end
    assert(loadfile("Modules/Phasing.lua", "t", env))()
    local spawns = {[210] = {{10, 20, 0, 1, 571, 1, 4477}, {11, 21, 0, 1, 571, 2, 4477}}}
    db.GetNPC = function() return {spawns = spawns} end
    db.GetQuest = function(id) return {Id = id, Starts = {NPC = {29343}}, tagInfoWasCached = true} end
    db.questData[999] = true
    mods.QuestieMap.RefreshDynamicStarterLocations = function() end
    mods.QuestieMap.RefreshDynamicManualNotes = function() end
    mods.QuestieQuest.RefreshSpawnVisibility = function() end
    local draws = 0
    available.DrawAvailableQuest = function(quest)
        local points = {}
        for _, point in ipairs(spawns[210]) do
            if mods.Phasing.IsSpawnDataVisible(point) then points[#points + 1] = point[1] end
        end
        draws = draws + 1
        drawn[quest.Id] = table.concat(points, ",")
    end
    env.Questie.started = true
    state.reply(phaseRows(1, "1", "0"), "PHASES,HEARTBEAT"); calculate()
    equal(drawn[999], "10", "available quest has initial phase location")
    state.reply(phaseRows(2, "0", "1"), "PHASES,HEARTBEAT"); calculate()
    equal(drawn[999], "11", "still-available quest replaces cached phase location")
    equal(draws, 2, "phase transition redrew cached quest")
    state.advance(10); state.heartbeat(); calculate()
    equal(draws, 2, "heartbeat preserves location cache")
    state.advance(31); calculate()
    equal(drawn[999], "10,11", "expiry restores static available quest locations")
    tests = tests + 1
end

local function regionalPhaseRows(map, area, zone, mask)
    local rows = phaseRows(mask, nil, nil, nil, nil, map, area, zone)
    for index, spawnMask in ipairs(phaseMasks) do
        rows[index + 1] = "F:" .. area .. ":" .. spawnMask .. ":"
            .. (bit32.band(mask, spawnMask) ~= 0 and "1" or "0")
    end
    return rows
end

-- Each region uses actual server decisions, with exact map/subarea isolation.
do
    for _, context in ipairs({
        {571, 4501, 210, 128}, {571, 4438, 67, 8}, {609, 4356, 4298, 192},
        {0, 4281, 139, 256}, {571, 4172, 65, 2}, {571, 4020, 3537, 2},
        {571, 4216, 394, 2}, {571, 4325, 66, 2}, {0, 153, 85, 64},
        {0, 1497, 1497, 128}, {1, 1637, 1637, 64},
    }) do
        local state = setup()
        state.env.bit = bit32
        assert(loadfile("Modules/Phasing.lua", "t", state.env))()
        local map, area, zone, mask = table.unpack(context)
        state.reply(regionalPhaseRows(map, area, zone, mask), "PHASES,HEARTBEAT")
        assert(state.server:GetPhaseRegion(state.server:GetPhaseContext()), "supported region accepted")
        local filter = state.modules.Phasing
        equal(filter.IsSpawnDataVisible({10, 20, 0, 1, map, 1, area}), false, "normal-phase location hidden")
        equal(filter.IsSpawnDataVisible({10, 20, 0, 1, map, mask, area}), true, "current-phase location visible")
        equal(filter.IsSpawnDataVisible({10, 20, 0, 1, map, 1, area + 1}), true, "remote subarea uses fallback")
        equal(filter.IsSpawnDataVisible({10, 20, 0, 1, map + 1, 1, area}), true, "remote map uses fallback")
        state.server:PrintPhaseStatus()
        assert(printed(state, "[Server bridge] Story-phase locations:"), "regional diagnostic")
    end
    tests = tests + 1
end

-- Storm Peaks object composites and DK stage masks are bitsets, not phase numbers.
do
    local state = setup()
    state.env.bit = bit32
    assert(loadfile("Modules/Phasing.lua", "t", state.env))()
    state.reply(regionalPhaseRows(571, 4495, 67, 4), "PHASES,HEARTBEAT")
    local filter = state.modules.Phasing
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 5, 4495}), true, "early anvil mask 5 overlaps phase 4")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 8, 4495}), false, "later anvil initially hidden")
    state.reply(regionalPhaseRows(571, 4495, 67, 8), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 5, 4495}), false, "early anvil removed")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 571, 8, 4495}), true, "later anvil shown")
    state.reply(regionalPhaseRows(609, 4356, 4298, 192), "PHASES,HEARTBEAT")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 609, 64, 4356}), true, "DK shared stage includes phase 64")
    equal(filter.IsSpawnDataVisible({10, 20, 0, 1, 609, 128, 4356}), true, "DK shared stage includes phase 128")
    tests = tests + 1
end

-- Identical masks in another area/map must invalidate locations even when decisions are unchanged.
do
    local state = setup()
    local redraws = 0
    state.modules.AvailableQuests.InvalidateSpawnVisibility = function() redraws = redraws + 1 end
    state.modules.QuestieMap = {RefreshDynamicStarterLocations = function() end, RefreshDynamicManualNotes = function() end}
    state.modules.QuestieQuest = {RefreshSpawnVisibility = function() end}
    state.env.Questie.started = true
    state.reply(regionalPhaseRows(571, 4501, 210, 2), "PHASES,HEARTBEAT")
    state.reply(regionalPhaseRows(571, 4504, 210, 2), "PHASES,HEARTBEAT")
    equal(redraws, 2, "same phase in another area refreshes cached locations")
    state.reply(regionalPhaseRows(609, 4342, 4298, 2), "PHASES,HEARTBEAT")
    equal(redraws, 3, "same phase on another map refreshes cached locations")
    state.advance(10); state.heartbeat()
    equal(redraws, 3, "steady regional state does not redraw")
    state.reply({"P:PHASE_CONTEXT:571:4613:1:4395"}, "PHASES,HEARTBEAT")
    equal(redraws, 4, "unsupported zone restores fallback")
    tests = tests + 1
end

-- A full catalog with an extra foreign area or missing/unknown mask is still invalid.
do
    for _, modification in ipairs({"foreign", "missing", "unknown", "zone"}) do
        local state = setup()
        local rows = regionalPhaseRows(571, 4438, 67, 4)
        if modification == "foreign" then rows[#rows + 1] = "F:4495:4:1"
        elseif modification == "missing" then table.remove(rows)
        elseif modification == "unknown" then rows[#rows + 1] = "F:4438:1024:1"
        else rows[1] = "P:PHASE_CONTEXT:571:4438:4:4395" end
        state.reply(rows, "PHASES,HEARTBEAT")
        equal(state.server:GetPhaseContext(), nil, "malformed regional catalog rejected: " .. modification)
    end
    local state = setup()
    state.reply({"P:PHASE_CONTEXT:571:0:4:67"}, "PHASES,HEARTBEAT")
    equal(state.server:GetPhaseRegion(state.server:GetPhaseContext()), nil, "unknown area never filtered")
    tests = tests + 1
end

print("Server bridge: " .. tests .. " regression groups passed")
