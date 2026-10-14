-- Run from the addon root with Lua 5.1 or 5.2+.
-- Deterministic client/server clocks; completion state uses the real quest-log code.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function timestamp(day, hour, month, year)
    return os.time({year = year or 2026, month = month or 10, day = day, hour = hour, min = 0, sec = 0})
end
local function setup(options)
    options = options or {}
    local now, uptime, native = options.now or timestamp(6, 7), 0, 3600
    local timers, draws, warnings, rewarded = {}, 0, 0, {}
    local char = options.char or {complete = {}, daily = {}, weekly = {}, monthly = {}}
    local profile = options.profile or {resetDailyQuests = true, weeklyResetHour = 6, weeklyResetDay = 4}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.time, env.date, env.bit = os.time, os.date, {band = function() return 0 end}
    env.ERR_QUEST_COMPLETE_S, env.DAILY_QUESTS_REMAINING = "%s completed.", "%d dailies remaining"
    env.GetTime = function() return uptime end
    env.UnitName = function() return "Tester" end
    env.GetQuestResetTime = function() return native end
    env.GetMaxDailyQuests = function() return 25 end
    env.QueryQuestsCompleted = noop
    env.GetQuestsCompleted = function(target)
        for id in pairs(target) do target[id] = nil end
        for id in pairs(rewarded) do target[id] = true end
    end
    env.Questie = {started = true, db = {char = char, profile = profile}, Debug = function(_, message)
        if message:find("Invalid native value", 1, true) then warnings = warnings + 1 end
    end}
    local server = {GetQuestResetTimes = function() return options.resets end,
        HasCapability = function() return options.heartbeat or false end}
    if options.noBridge then server.GetQuestResetTimes = nil end
    local modules = {
        QuestieDB = {IsDailyQuest = function(id) return id == 30 or id == 31 or id == 32 end,
            IsWeeklyQuest = function(id) return id == 10 end,
            IsMonthlyQuest = function(id) return id == 20 end,
            IsRepeatable = function(id) return id ~= 40 end},
        AvailableQuests = {CalculateAndDrawAll = function() draws = draws + 1 end},
        QuestieServer = server, QuestiePlayer = {GetPlayerLevel = function() return 80 end},
    }
    env.QuestieLoader = {ImportModule = function(_, name)
        modules[name] = modules[name] or {}; return modules[name]
    end, StampLoadBoundary = noop}
    local compat = {GetServerTime = function()
        local currentDate = os.date("*t", now); currentDate.weekday = currentDate.wday
        return now, currentDate
    end, Merge = function(target, source) for id, value in pairs(source) do target[id] = value end end}
    env.QuestieCompat = compat
    compat.C_Timer = {After = function(delay, callback)
        assert(delay > 0 and delay <= 1800, "bounded positive timer delay")
        local timer = {delay = delay, due = uptime + delay, callback = callback}
        timer.Cancel = function() timer.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end}
    local function loadModule(path)
        local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close()
        if setfenv then setfenv(assert(loadstring(source, "@" .. path)), env)()
        else assert(load(source, "@" .. path, "t", env))() end
    end
    loadModule("Compat/QuestLog.lua")
    loadModule("Compat/QuestResets.lua")
    loadModule("Compat/QuestRewardCompletion.lua")
    return {env = env, compat = compat, char = char, profile = profile, timers = timers, rewarded = rewarded,
        now = function() return now end, warnings = function() return warnings end, draws = function() return draws end,
        native = function(value) native = value end,
        advance = function(seconds) now, uptime = now + seconds, uptime + seconds end,
        runTimers = function()
            local due = {}
            for _, timer in ipairs(timers) do
                if not timer.cancelled and timer.due <= uptime then
                    timer.cancelled = true; due[#due + 1] = timer.callback
                end
            end
            for _, callback in ipairs(due) do callback() end
        end}
end

-- Preserve native values, small negative rollover, and fallback warning throttling.
do
    local s = setup()
    for _, seconds in ipairs({0, 1, 3600, 172800, "7200"}) do
        s.native(seconds); equal(s.compat.GetQuestResetTime(), tonumber(seconds), "valid native reset interval")
    end
    s.native(-5); equal(s.compat.GetQuestResetTime(), 86395, "small negative daily rollover")
    for _, seconds in ipairs({-11, -s.now(), 172801, math.huge, 0 / 0, "invalid"}) do
        s.native(seconds)
        equal(s.compat.GetQuestResetTime(), timestamp(7, 6) - s.now(), "invalid value uses next fallback reset")
    end
    s.native(nil); equal(s.compat.GetQuestResetTime(), timestamp(7, 6) - s.now(), "absent reset uses fallback")
    equal(s.warnings(), 1, "invalid native reset warning emitted once")
    local early = setup({now = timestamp(6, 5)})
    early.native(nil)
    equal(early.compat.GetQuestResetTime(), 3600, "fallback before today's reset hour")
end

-- Zero means retry, never erase completions or save the current time as a deadline.
do
    local s = setup()
    s.char.daily[30], s.char.complete[30] = true, true
    s.native(0)
    s.compat.CalculateNextResetTime(); s.compat.CalculateNextResetTime()
    equal(#s.timers, 1, "only one daily retry scheduled")
    equal(s.timers[1].delay, 3, "daily retry delay")
    equal(s.char.dailyResetTime, nil, "zero interval never stored")
    s.advance(3); s.native(3600); s.runTimers()
    equal(s.char.dailyResetTime, s.now() + 3600, "retry adopts valid daily deadline")
    equal(s.char.complete[30], true, "retry preserves current daily completion")
    equal(s.draws(), 0, "retry without rollover does not redraw")
end
do
    local s = setup()
    s.native(0); s.compat.CalculateNextResetTime()
    s.native(3600); s.compat.CalculateNextResetTime()
    equal(s.timers[1].cancelled, true, "valid response cancels pending retry")
    local deadline = s.char.dailyResetTime
    s.advance(3); s.runTimers()
    equal(s.char.dailyResetTime, deadline, "cancelled retry cannot change deadline")
end

-- Legacy profile deadlines only belong to characters with matching saved history.
do
    local s = setup()
    s.profile.dailyResetTime = s.now() - 1
    s.char.daily[30], s.char.complete[30] = true, true
    s.compat.CalculateNextResetTime()
    equal(s.char.dailyResetTime, s.now() - 1, "expired legacy deadline migrated without advancing")
    equal(s.compat.ResetDailyQuests(), true, "expired migrated daily history cleared")
    equal(s.char.complete[30], nil, "expired legacy completion removed")
    equal(s.char.dailyResetTime, s.now() + 3600, "next cycle recorded after migration")
    local other = setup({profile = s.profile})
    other.native(7200); other.compat.CalculateNextResetTime()
    equal(other.char.dailyResetTime, other.now() + 7200, "empty character ignores another character's deadline")
    s.compat.CalculateNextResetTime()
    equal(s.char.dailyResetTime, s.now() + 3600, "shared profile cannot advance saved character deadline")
end
do
    local s = setup()
    s.char.acoreDailyQuestCompletions = {[32] = true}
    s.profile.dailyResetTime = s.now() + 7200
    s.native(nil)
    equal(s.compat.GetQuestResetTime(), 7200, "bridge daily history preserves legacy fallback")
    s.compat.CalculateNextResetTime()
    equal(s.char.dailyResetTime, s.profile.dailyResetTime, "bridge-only legacy deadline migrated")
end

-- Both local and raw server-only dailies expire; other completion periods survive.
do
    local s = setup()
    s.compat.CalculateNextResetTime()
    s.profile.resetDailyQuests = false
    for _, id in ipairs({10, 20, 31, 40}) do s.rewarded[id] = true end
    s.compat:QUEST_QUERY_COMPLETE()
    equal(s.compat.IsQuestCompletedOnServer(31), true, "raw daily retained after repeatable filtering")
    s.profile.resetDailyQuests = true
    s.char.daily[30], s.char.complete[30] = true, true
    s.char.acoreDailyQuestCompletions = {[32] = true}
    s.char.complete[32] = true
    s.char.weekly[10], s.char.monthly[20], s.char.complete[10], s.char.complete[20] = true, true, true, true
    equal(s.compat.ResetDailyQuests(), false, "future deadline does not clear current completions")
    s.advance(3600)
    equal(s.compat.ResetDailyQuests(), true, "deadline expires daily cycle")
    for _, id in ipairs({30, 31, 32}) do
        equal(s.char.complete[id], nil, "daily completion cleared")
        equal(s.compat.IsQuestCompletedOnServer(id), false, "daily raw completion cleared")
    end
    equal(next(s.char.daily), nil, "daily history emptied")
    equal(next(s.char.acoreDailyQuestCompletions), nil, "bridge daily history emptied")
    for _, id in ipairs({10, 20, 40}) do
        equal(s.char.complete[id], true, "other completion history preserved")
        equal(s.compat.IsQuestCompletedOnServer(id), true, "other raw history preserved")
    end
    equal(s.draws(), 2, "one query redraw and one daily reset redraw")
    equal(s.compat.ResetDailyQuests(), false, "same reset does not clear twice")
    s.compat.SetQuestComplete(30)
    equal(s.char.daily[30], true, "new cycle completion recorded")
    equal(s.char.complete[30], true, "new cycle completion survives")
    -- Query replaces the private raw table. Cleanup must operate on its current version.
    s.profile.resetDailyQuests = false
    s.compat:QUEST_QUERY_COMPLETE()
    equal(s.compat.IsQuestCompletedOnServer(31), true, "replacement server query cached")
    s.profile.resetDailyQuests = true
    s.compat.ResetDailyQuests(true)
    equal(s.compat.IsQuestCompletedOnServer(31), false, "forced reset clears replacement raw cache")
end

-- Completion recording expires yesterday's state before recording today's result.
do
    local s = setup()
    s.char.dailyResetTime = s.now() - 1
    s.char.daily[30], s.char.complete[30] = true, true
    s.compat.SetQuestComplete(30)
    equal(s.char.daily[30], true, "daily record added after expiry")
    equal(s.char.complete[30], true, "current completion preserved after expiry")
    equal(s.char.dailyResetTime, s.now() + 3600, "deadline refreshed before new completion")
    s.compat.SetAzerothCoreDailyQuestComplete(32)
    equal(s.compat.IsAzerothCoreDailyQuestComplete(32), true, "bridge daily completion tracked")
    s.advance(3600)
    equal(s.compat.IsAzerothCoreDailyQuestComplete(32), false, "bridge daily check expires old cycle")
end

-- A server reset message schedules cleanup only when automatic resets are enabled.
do
    local s = setup()
    s.compat.CalculateNextResetTime()
    s.char.daily[30], s.char.complete[30] = true, true
    s.compat:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "24 dailies remaining")
    equal(#s.timers, 0, "ordinary daily count does not schedule a reset")
    s.compat:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "25 dailies remaining")
    equal(s.timers[1].delay, 1, "server reset message waits for client status update")
    s.advance(1); s.runTimers()
    equal(s.char.complete[30], nil, "server reset message clears current daily history")
    local disabled = setup()
    disabled.profile.resetDailyQuests = false
    disabled.compat:CHAT_MSG_SYSTEM("CHAT_MSG_SYSTEM", "25 dailies remaining")
    equal(#disabled.timers, 0, "disabled automatic resets ignore reset messages")
end

-- A missing bridge uses calendar schedules; long waits stay within animation timer limits.
do
    local s = setup({noBridge = true, now = timestamp(31, 7, 12)})
    s.compat.ResetMonthlyQuests()
    equal(s.char.monthlyResetTime, timestamp(1, 6, 1, 2027), "monthly fallback crosses year boundary")
    equal(s.timers[1].delay, 1800, "long monthly delay capped")
    local early = setup({noBridge = true, now = timestamp(1, 5, 1, 2027)})
    early.compat.ResetMonthlyQuests()
    equal(early.char.monthlyResetTime, timestamp(1, 6, 1, 2027), "monthly reset later on first day")
    local weekly = setup({noBridge = true, now = timestamp(7, 6)})
    weekly.compat.ResetWeeklyQuests()
    equal(weekly.char.weeklyResetTime, timestamp(14, 6), "weekly fallback advances at exact reset boundary")
end
do
    local s = setup({noBridge = true})
    s.char.weeklyResetTime, s.char.monthlyResetTime = s.now() - 1, s.now() + 1000
    s.char.weekly[10], s.char.complete[10], s.char.monthly[20], s.char.complete[20] = true, true, true, true
    equal(s.compat.ResetWeeklyQuests(), true, "expired weekly fallback clears weekly completion")
    equal(s.char.complete[10], nil, "weekly history expired")
    equal(s.char.complete[20], true, "monthly history preserved")
    s.compat.SetQuestComplete(10)
    s.profile.resetDailyQuests = false
    s.advance(1800); s.runTimers()
    equal(s.char.complete[10], true, "disabled reset prevents scheduled cleanup")
end
print("Quest reset compatibility regressions passed")
