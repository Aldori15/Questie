-- Run from the addon directory with Lua 5.2+. Uses the production 3.3.5
-- reward hooks and quest event handler; the client APIs and UI are simulated.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function setup(ids, completed)
    local env = setmetatable({}, {__index = _G})
    local modules, hooks, timers, log, rewarded, history = {}, {}, {}, {}, {}, {}
    local now, queries, title, ender = 0, 0, "Membership Benefits", {9884, 9885, 9886, 9887}
    for _, id in ipairs(ids or {}) do log[#log + 1] = id end
    for _, id in ipairs(completed or {}) do rewarded[id] = true end
    local function noop() end
    env.bit, env.time, env.date = bit32, os.time, os.date
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
        CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    }
    env.QuestieCompat = {Is335 = true, frame = env.CreateFrame(), UnitGUID = function() return "Creature-0-0-0-0-18265-00000001" end,
        C_Timer = {After = function(delay, callback)
            timers[#timers + 1] = {due = now + delay, callback = callback}
        end}}
    modules.QuestieDB = {
        IsDailyQuest = function(id) return id == 30 end,
        IsWeeklyQuest = function(id) return id == 10 end,
        IsMonthlyQuest = function(id) return id >= 9884 and id <= 9887 end,
        IsRepeatable = function() return true end,
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
    modules.QuestieJourney = {CompleteQuest = function(_, id) history[#history + 1] = id end, AbandonQuest = noop}
    modules.QuestieAnnounce = {CompletedQuest = noop, AbandonedQuest = noop}
    modules.QuestiePartyObjectives = {ScheduleUpdate = noop}
    modules.AvailableQuests = {CalculateAndDrawAll = noop, ResetLastNpcGuid = noop,
        RemoveQuest = function(id, callback) ui[id] = nil; callback() end}
    local tracker = {}
    for _, id in ipairs(log) do tracker[id] = true end
    modules.QuestieTracker = {RemoveQuest = function(_, id) tracker[id] = nil end, Update = noop}
    modules.QuestieCombatQueue = {Queue = function(_, callback) callback() end}
    modules.CommsVisibility = {ScheduleSnapshot = noop}
    assert(loadfile("Compat/QuestLog.lua", "t", env))()
    local compat = env.QuestieCompat
    -- Timing is covered by the bridge suite. Keep these tests focused on rewards.
    compat.ResetDailyQuests, compat.ResetWeeklyQuests, compat.ResetMonthlyQuests = noop, noop, noop
    compat.CalculateNextResetTime = noop
    compat.Merge = function(target, source) for id in pairs(source) do target[id] = true end end
    assert(loadfile("Modules/Quest/QuestEventHandler.lua", "t", env))()
    assert(loadfile("Modules/Quest/Lifecycle/QuestLifecycle.lua", "t", env))()
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
        chat = function() compat:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", title .. " completed.") end,
        ender = function(value) ender = value end,
    }
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

print("Quest reward completion regression tests passed (" .. tests .. " groups)")
