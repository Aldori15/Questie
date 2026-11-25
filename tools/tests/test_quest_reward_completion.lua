-- Run from the addon directory with Lua 5.1 or 5.2+. Uses the production 3.3.5
-- reward hooks and quest event handler; the client APIs and UI are simulated.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function loadModule(path, env)
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(path, "t", env))
    end
    chunk()
end

local function setup(ids, completed, isRepeatable)
    local env = setmetatable({}, {__index = _G})
    local modules, hooks, timers, log, rewarded, history = {}, {}, {}, {}, {}, {}
    local now, queries, title, ender = 0, 0, "Membership Benefits", {9884, 9885, 9886, 9887}
    local mapRefreshes, journeyRefreshes = 0, 0
    for _, id in ipairs(ids or {}) do log[#log + 1] = id end
    for _, id in ipairs(completed or {}) do rewarded[id] = true end
    local function noop() end
    -- QuestLog declares a money-helper alias, but reward handling never uses it.
    env.bit = bit32 or {band = function() error("unexpected money helper in reward test") end}
    env.time, env.date = os.time, os.date
    env.ERR_QUEST_COMPLETE_S, env.DAILY_QUESTS_REMAINING = "%s completed.", "%d dailies remaining"
    env.Questie = {started = true, db = {profile = {resetDailyQuests = true},
        char = {complete = {}, daily = {}, weekly = {}, monthly = {}}}, Debug = noop, SendMessage = noop}
    env.GetTime = function() return now end
    env.UnitName = function() return "Tester" end
    env.GetQuestLogTitle = function(index)
        local id = log[index]
        if id then return title, 70, nil, 0, false, false, 1, false, id end
    end
    env.GetTitleText = function() return title end
    env.GetQuestLogSelection = function() return 1 end
    env.GetMaxDailyQuests = function() return 25 end
    env.strsplit = function(separator, value) return value:match("^[^" .. separator .. "]+") end
    env.hooksecurefunc = function(name, callback) hooks[name] = callback end
    env.CreateFrame = function() return {RegisterEvent = noop, UnregisterEvent = noop} end
    env.QuestieQuestEventFrame = env.CreateFrame()
    env.QueryQuestsCompleted = function() queries = queries + 1 end
    env.GetQuestsCompleted = function(target)
        for id in pairs(target) do target[id] = nil end
        for id in pairs(rewarded) do target[id] = true end
    end
    env.QuestieLoader = {
        StampLoadBoundary = noop,
        CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    }
    env.QuestieCompat = {frame = env.CreateFrame(), UnitGUID = function() return "Creature-0-0-0-0-18265-00000001" end,
        C_Timer = {After = function(delay, callback)
            timers[#timers + 1] = {due = now + delay, callback = callback}
        end}}
    modules.QuestieDB = {
        IsDailyQuest = function(id) return id == 30 end,
        IsWeeklyQuest = function(id) return id == 10 end,
        IsMonthlyQuest = function(id) return id >= 9884 and id <= 9887 end,
        IsRepeatable = isRepeatable or function() return true end,
        QueryQuestSingle = function(_, field) if field == "name" then return title end end,
        QueryNPCSingle = function() return ender end,
        IsDoable = function(id)
            for _, active in ipairs(log) do if id == active then return true end end
            return #log == 0 and id == 9886
        end,
    }
    modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return 80 end}
    local player = modules.QuestiePlayer.currentQuestlog
    for _, id in ipairs(log) do player[id] = {Id = id} end
    modules.QuestieDB.GetQuest = function(id) return player[id] end
    local ui = {}
    for _, id in ipairs(log) do ui[id] = true end
    modules.QuestLogCache = {RemoveQuest = noop}
    modules.QuestieQuest = {SetObjectivesDirty = noop, ClearLootedSpawns = noop}
    modules.TrackerUtils = {ClearTomTomTargetForQuest = noop}
    modules.AutoRoute = {RemoveFromRoute = noop}
    modules.QuestieJourney = {CompleteQuest = function(_, id) history[#history + 1] = id end, AbandonQuest = noop,
        RefreshCompletionView = function() journeyRefreshes = journeyRefreshes + 1 end}
    modules.QuestieAnnounce = {CompletedQuest = noop, AbandonedQuest = noop}
    modules.QuestiePartyObjectives = {ScheduleUpdate = noop}
    modules.AvailableQuests = {CalculateAndDrawAll = function() mapRefreshes = mapRefreshes + 1 end, ResetLastNpcGuid = noop,
        RemoveQuest = function(id, callback) ui[id] = nil; callback() end}
    local tracker = {}
    for _, id in ipairs(log) do tracker[id] = true end
    modules.QuestieTracker = {RemoveQuest = function(_, id) tracker[id] = nil end, Update = noop}
    modules.QuestieCombatQueue = {Queue = function(_, callback) callback() end}
    modules.CommsVisibility = {ScheduleSnapshot = noop}
    loadModule("Compat/QuestLog.lua", env)
    loadModule("Compat/QuestResets.lua", env)
    loadModule("Compat/QuestRewardCompletion.lua", env)
    local compat = env.QuestieCompat
    -- Timing is covered by the bridge suite. Keep these tests focused on rewards.
    compat.ResetDailyQuests, compat.ResetWeeklyQuests, compat.ResetMonthlyQuests = noop, noop, noop
    compat.CalculateNextResetTime = noop
    compat.Merge = function(target, source) for id in pairs(source) do target[id] = true end end
    loadModule("Modules/Quest/QuestEventHandler.lua", env)
    loadModule("Modules/Quest/Lifecycle/QuestLifecycle.lua", env)
    compat.QuestEventHandler_RegisterEvents()
    local function remove(id)
        for index, active in ipairs(log) do
            if id == active then table.remove(log, index); return end
        end
    end
    local function advance(seconds)
        now = now + seconds
        local due = {}
        for index = #timers, 1, -1 do
            if timers[index].due <= now then
                due[#due + 1] = table.remove(timers, index).callback
            end
        end
        for _, callback in ipairs(due) do callback() end
    end
    compat:QUEST_QUERY_COMPLETE()
    return {
        env = env, hooks = hooks, history = history, ui = ui, tracker = tracker, player = player, rewarded = rewarded,
        claim = function() hooks.GetQuestReward(1) end,
        reward = function(id) rewarded[id] = true; remove(id) end,
        remove = remove, advance = advance,
        query = function() compat:QUEST_QUERY_COMPLETE() end,
        queries = function() return queries end,
        mapRefreshes = function() return mapRefreshes end,
        journeyRefreshes = function() return journeyRefreshes end,
        chat = function() compat:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", title .. " completed.") end,
        ender = function(value) ender = value end,
    }
end

-- A normal chat-confirmed reward still refreshes the server list for silent completions.
do
    local s = setup({1001, 1003, 1004}, nil, function(id) return id == 1005 end)
    local complete = s.env.Questie.db.char.complete
    s.ender({1001})
    s.claim(); s.reward(1001); s.chat()
    equal(s.history[1], 1001, "chat path completes the exact turn-in immediately")
    s.player[1003] = nil -- Native log alone still protects this quest.
    s.remove(1004) -- Pending Questie log alone still protects this quest.
    for _, id in ipairs({1002, 1003, 1004, 1005, 1006, 13686, 13687}) do s.rewarded[id] = true end
    complete[1006] = false
    s.advance(0.5)
    equal(s.queries(), 1, "chat reward reuses the scheduled query")
    local mapRefreshes = s.mapRefreshes()
    s.query()
    equal(complete[1002], true, "silent completion imported")
    equal(#s.history, 1, "silent completion does not invent a Journey turn-in event")
    equal(s.journeyRefreshes(), 1, "completion views refresh after a new entry")
    equal(s.mapRefreshes(), mapRefreshes + 1, "server response rechecks map availability")
    for _, id in ipairs({1003, 1004, 1005, 13686, 13687}) do
        equal(complete[id], nil, "kept out of local completions " .. id)
        equal(s.env.QuestieCompat.HasRawServerQuestCompletion(id), true, "raw history retained " .. id)
    end
    equal(complete[1006], false, "explicit local reset remains incomplete")
    s.query()
    equal(s.journeyRefreshes(), 1, "unchanged response does not redraw Journey")
    for id in pairs(s.rewarded) do s.rewarded[id] = nil end
    s.query()
    equal(complete[1002], true, "an empty response preserves a learned completion")
    equal(s.env.QuestieCompat.HasRawServerQuestCompletion(1002), false, "raw response excludes saved state")
    s.advance(1)
    equal(s.queries(), 1, "a confirmed response does not schedule another query")
    tests = tests + 1
end

-- Opening a completion view can share an outstanding query. A newer turn-in
-- must still be able to collect completions that the old request did not see.
do
    local s = setup({1001}, nil, function() return false end)
    local compat = s.env.QuestieCompat
    compat.RequestCompletedQuestRefresh()
    compat.RequestCompletedQuestRefresh()
    s.advance(0.5)
    equal(s.queries(), 1, "refresh requests coalesce")
    compat.RequestCompletedQuestRefresh()
    s.ender({1001})
    s.claim(); s.reward(1001); s.chat()
    s.query()
    s.rewarded[1002] = true
    s.advance(0.5)
    equal(s.queries(), 2, "a later reward receives a fresh response")
    s.query()
    equal(s.env.Questie.db.char.complete[1002], true, "newer response learns silent completion")
    s.advance(1)
    equal(s.queries(), 2, "view request does not add another query")
    tests = tests + 1
end

-- Reproduces the reported four same-title monthly quests with normal lifecycle callbacks.
do
    local s = setup({9884, 9885, 9886, 9887})
    s.claim(); s.reward(9884); s.chat(); s.advance(0.5); s.query()
    equal(#s.history, 1, "ambiguous turn-in recorded")
    equal(s.history[1], 9884, "exact rewarded ID")
    equal(s.ui[9884], nil, "rewarded tracker/tooltip/map state removed")
    equal(s.tracker[9884], nil, "production lifecycle removes tracker entry")
    equal(s.player[9884], nil, "production lifecycle removes accepted quest")
    equal(s.env.Questie.db.char.monthly[9884], true, "monthly completion stored")
    for _, id in ipairs({9885, 9886, 9887}) do equal(s.ui[id], true, "other variants remain accepted") end
    s.claim(); s.reward(9885); s.advance(0.5); s.query()
    equal(#s.history, 2, "second ambiguous turn-in recorded")
    equal(s.history[2], 9885, "second exact rewarded ID")
    tests = tests + 1
end

-- Two claims arrive before either log update. Confirm the rewarded set once, without relying on order.
do
    local s = setup({9884, 9885, 9886, 9887})
    s.claim(); s.claim(); s.reward(9885); s.reward(9884)
    s.advance(0.5); equal(s.queries(), 1, "rapid claims batched"); s.query()
    equal(#s.history, 2, "two rewards recorded once")
    equal(s.env.Questie.db.char.monthly[9884], true, "first rapid reward")
    equal(s.env.Questie.db.char.monthly[9885], true, "second rapid reward")
    s.query(); equal(#s.history, 2, "later query cannot duplicate history")
    tests = tests + 1
end

-- Lifetime repeatable history is already true: removal from the live log confirms this reward.
do
    local s = setup({9884, 9885, 9886, 9887}, {9884, 9885, 9886, 9887})
    s.claim(); s.reward(9886); s.advance(0.5); s.query()
    equal(#s.history, 1, "previously rewarded repeatable recorded again")
    equal(s.history[1], 9886, "repeatable ID resolved by removal")
    tests = tests + 1
end

-- Failed attempts and explicit abandonment must not become completions.
do
    local s = setup({9884, 9885, 9886, 9887}, {9884, 9885, 9886, 9887})
    s.claim(); s.advance(0.5); s.query()
    equal(#s.history, 0, "failed reward preserves history")
    s.claim(); s.hooks.SetAbandonQuest(); s.remove(9884); s.hooks.AbandonQuest()
    s.advance(0.5); s.query()
    equal(#s.history, 0, "abandon is not a repeatable reward")
    tests = tests + 1
end

-- Immediate turn-ins never enter the log; existing exact-ID chat/query paths still work.
for _, chat in ipairs({false, true}) do
    local s = setup()
    s.claim(); s.reward(9886)
    if chat then s.chat() end
    s.advance(0.5); s.query()
    equal(#s.history, 1, "immediate turn-in recorded once")
    equal(s.history[1], 9886, "immediate turn-in ID")
    tests = tests + 1
end

-- Claims during a query require a later query; a timeout cannot strand subsequent claims.
do
    local s = setup({9884, 9885, 9886, 9887})
    s.claim(); s.reward(9884); s.advance(0.5)
    s.claim(); s.reward(9885); s.query()
    equal(s.env.Questie.db.char.monthly[9884], nil, "ambiguous overlapping response waits for newer claim")
    s.advance(0.5); s.query()
    equal(s.env.Questie.db.char.monthly[9884], true, "first in-flight reward")
    equal(s.env.Questie.db.char.monthly[9885], true, "new claim gets its query")
    equal(#s.history, 2, "in-flight rewards not duplicated")
    s.claim(); s.advance(0.5); s.advance(5)
    s.claim(); s.reward(9886); s.advance(0.5); s.query()
    equal(s.env.Questie.db.char.monthly[9886], true, "reward after timeout")
    tests = tests + 1
end

-- Unknown earlier completions cannot prove an immediate reward attempt succeeded.
do
    local s = setup()
    s.claim(); s.rewarded[9886] = true; s.query() -- unrelated response before our delayed request
    s.advance(0.5); s.query()
    equal(#s.history, 0, "unrelated query updates the immediate-quest baseline")
    tests = tests + 1
end

-- Saved repeatable completion flags must not replace the raw server baseline.
do
    local s = setup()
    s.env.Questie.db.char.complete[9886] = true
    s.claim(); s.reward(9886); s.advance(0.5); s.query()
    equal(#s.history, 1, "saved completion does not hide a new immediate reward")
    equal(s.history[1], 9886, "raw server baseline identifies immediate reward")
    tests = tests + 1
end

-- Game-object enders and missing NPC context retain their existing resolution paths.
do
    local s = setup({9884, 9885})
    s.env.QuestieCompat.UnitGUID = function() return "GameObject-0-0-0-0-12345-00000001" end
    s.env.QuestieLoader:ImportModule("QuestieDB").QueryObjectSingle = function(id, field)
        equal(id, 12345, "game-object ender ID")
        equal(field, "questEnds", "game-object ender lookup")
        return {9884, 9885}
    end
    s.claim(); s.reward(9885); s.advance(0.5); s.query()
    equal(#s.history, 1, "game-object reward recorded once")
    equal(s.history[1], 9885, "game-object rewarded ID")
    equal(s.tracker[9884], true, "other game-object variant retained")

    s = setup({9884})
    s.env.QuestieCompat.UnitGUID = function() return nil end
    s.claim(); s.reward(9884); s.chat(); s.advance(0.5); s.query()
    equal(#s.history, 1, "unique log fallback recorded once without NPC context")
    equal(s.history[1], 9884, "unique log fallback ID")
    tests = tests + 1
end

-- Empty reward dialogs must not create completion queries or history.
do
    local s = setup({9884})
    s.env.GetTitleText = function() return "" end
    s.claim(); s.advance(1); s.query()
    equal(s.queries(), 0, "empty reward title ignored")
    equal(#s.history, 0, "empty reward title preserves history")
    tests = tests + 1
end

-- Do not assign several newly rewarded IDs to one ambiguous claim; retries are bounded.
do
    local s = setup({9884, 9885, 9886, 9887})
    s.claim(); s.reward(9884); s.reward(9885)
    for _ = 1, 12 do s.advance(0.5); s.query() end
    equal(#s.history, 0, "insufficient claim evidence cannot guess")
    local count = s.queries()
    s.advance(1); equal(s.queries(), count, "unresolved claim expires")
    tests = tests + 1
end

-- Same-title claims from different NPCs require independent supporting evidence.
do
    local s = setup({9884, 9885, 9886, 9887})
    s.ender({9884, 9885}); s.claim()
    s.ender({9886, 9887}); s.claim()
    s.reward(9884); s.reward(9885); s.advance(0.5); s.query()
    equal(#s.history, 0, "different NPC's failed claim cannot support a second reward")
    tests = tests + 1
end

-- A unique log title from an unrelated NPC cannot override the current ender's candidates.
do
    local s = setup({9884})
    s.ender({9885, 9886}) -- neither is currently doable in this simulated context
    s.claim(); s.chat()
    equal(#s.history, 0, "unrelated accepted quest must not be rewarded from a title alone")
    tests = tests + 1
end

-- The same callbacks preserve weekly and daily completion tracking.
for _, id in ipairs({10, 30}) do
    local s = setup({id})
    s.ender({id}); s.claim(); s.reward(id); s.chat()
    equal(s.env.Questie.db.char[id == 10 and "weekly" or "daily"][id], true, "reset-period completion")
    equal(s.tracker[id], nil, "ordinary repeatable removed from tracker")
    tests = tests + 1
end

-- A dialog claim and a missing-log check can share the same response.
do
    local s = setup({9884})
    s.claim()
    s.reward(9884)
    s.env.QuestieCompat.CheckMissingQuestReward(9884, function() return s.player[9884] ~= nil end,
        function() error("unexpected missing-reward timeout") end)
    s.advance(0.5); s.query()
    equal(s.queries(), 1, "dialog and missing-log checks share the request")
    equal(#s.history, 1, "dialog completion invalidates the matching missing-log check")
    tests = tests + 1
end

-- A historical repeatable reward or a changed log entry cannot confirm a new reward.
do
    local s = setup({9884, 9885}, {9884})
    local compat = s.env.QuestieCompat
    local function unexpectedTimeout() error("unexpected missing-reward timeout") end
    s.remove(9884)
    compat.CheckMissingQuestReward(9884, function() return true end, unexpectedTimeout)
    s.reward(9885)
    compat.CheckMissingQuestReward(9885, function() return false end, unexpectedTimeout)
    s.advance(0.5); s.query()
    equal(#s.history, 0, "historical or superseded reward evidence is ignored")
    tests = tests + 1
end

print("Quest reward completion regression tests passed (" .. tests .. " groups)")
