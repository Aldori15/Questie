-- Run with Lua 5.2+. Exercise production availability and frame removal with a controlled clock.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function setup(count, clockAvailable)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.time, env.date = os.time, os.date
    local modules = {}
    local state = {now = 0, checkCost = 0, drawCost = 0, removeCost = 0, setupCost = 0,
        nativeId = 10000, checked = 0, drawn = 0, removed = 0, snapshots = 0, jobs = {}, slices = {}, callbacks = 0}
    local function spend(milliseconds) state.now = state.now + milliseconds end
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    }
    if clockAvailable ~= false then env.QuestieLoader.GetProfilerTime = function() return state.now / 1000 end end
    env.GetQuestGreenRange = function() return 100 end
    env.GetRealmName = function() return "Test realm" end
    env.Questie = {db = {profile = {lowLevelStyle = "default", showAQWarEffortQuests = true,
        showScourgeInvasionQuests = true, showSunsReachQuests = true}, global = {}, char = {complete = {}, hidden = {}}},
        Debug = noop, Error = error}
    env.QuestieCompat = {HBD = {}, HBDPins = {}, C_Timer = {}, C_Map = {},
        GetQuestResetTime = function() return 3600 end,
        GetServerTime = function() return 1791302400, {year = 2026, month = 10, day = 6, hour = 12, weekday = 3} end,
        GetQuestLogQuestIds = function() state.snapshots = state.snapshots + 1; return {[state.nativeId] = true} end}
    modules.ZoneDB = {GetDungeons = function() return {} end}
    modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return 80 end}
    modules.QuestieServer = {GetStateControlledQuests = function() spend(state.setupCost) end}
    modules.QuestieCorrections = {hiddenQuests = {}}
    modules.IsleOfQuelDanas = {GetHiddenQuests = function() return {} end}
    modules.QuestieQuestBlacklist = {AQWarEffortQuests = {}, ScourgeInvasionQuests = {}, SunsReachQuests = {}}
    modules.QuestieIconVisibility = {IsEnabledAnywhere = function() return true end}
    modules.QuestieTooltips = {RemoveAvailableQuest = noop}
    modules.QuestieDB = {questData = {}, autoBlacklist = {}, activeChildQuests = {}, SetUnavailableQuestChecker = noop,
        IsRepeatable = function() return false end, IsLevelRequirementsFulfilled = function() return true end,
        IsDoable = function(_, _, _, ids)
            assert(ids[state.nativeId], "snapshot must see client-log changes after every timed yield")
            state.checked = state.checked + 1
            spend(state.checkCost)
            return true
        end,
        IsDailyQuest = function() return false end, IsWeeklyQuest = function() return false end, IsMonthlyQuest = function() return false end,
        GetQuest = function(id) return {Id = id, Starts = {}, tagInfoWasCached = true} end,
        QueryQuestSingle = function() end}
    modules.QuestieDB.GetQuestStartInfo = function(id) return modules.QuestieDB.GetQuest(id) end
    for id = 1, count do modules.QuestieDB.questData[id] = true end
    modules.ThreadLib = {Thread = function(fn, _, _, callback)
        state.jobs[#state.jobs + 1] = {thread = coroutine.create(fn), callback = callback}
        return {}
    end}
    modules.QuestieFramePool = {UnloadFrame = function(_, frame)
        spend(state.removeCost)
        state.removed = state.removed + 1
        modules.QuestieMap.questIdFrames[frame.questId][frame.name] = nil
        env[frame.name] = nil
    end}
    assert(loadfile("Modules/Map/QuestieMap.lua", "t", env))()
    assert(loadfile("Modules/Quest/AvailableQuests.lua", "t", env))()
    local serial = 0
    function state.addFrame(id)
        serial = serial + 1
        local name = "budgetFrame" .. serial
        env[name] = {name = name, questId = id, data = {Type = "available"}}
        local frames = modules.QuestieMap.questIdFrames
        frames[id] = frames[id] or {}
        frames[id][name] = name
    end
    modules.AvailableQuests.DrawAvailableQuest = function(quest)
        spend(state.drawCost)
        state.drawn = state.drawn + 1
        state.addFrame(quest.Id)
    end
    function state.start(fast)
        modules.AvailableQuests.CalculateAndDrawAll(function(success)
            assert(success, "refresh succeeded")
            state.callbacks = state.callbacks + 1
        end, fast ~= false)
    end
    function state.resume(job)
        local before = state.now
        local ok, message = coroutine.resume(job.thread)
        assert(ok, message)
        state.slices[#state.slices + 1] = state.now - before
        if coroutine.status(job.thread) == "dead" then job.callback(true); return true end
        return false
    end
    function state.finish(job)
        while not state.resume(job) do spend(1000) end
    end
    function state.drain()
        while #state.jobs > 0 do state.finish(table.remove(state.jobs, 1)) end
    end
    function state.assertSlices(maximum)
        for _, elapsed in ipairs(state.slices) do assert(elapsed <= maximum + 0.000001, "oversized active slice: " .. elapsed) end
    end
    state.env, state.modules = env, modules
    return state
end

-- Timed yields happen well before the count cap, in fast and normal refreshes.
for _, fast in ipairs({true, false}) do
    local s = setup(40)
    s.checkCost, s.drawCost = 0.5, 0.5
    s.start(fast)
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "scan suspended on time budget")
    assert(s.checked >= 6 and s.checked <= 7, "time budget limits scan batch")
    equal(s.snapshots, 1, "one client snapshot per timed scan batch")
    s.nativeId = 10001 -- Change the client log while suspended.
    s.now = s.now + 1000
    s.finish(job)
    equal(s.checked, 40, "all candidates checked")
    equal(s.drawn, 40, "all available icons drawn")
    equal(s.callbacks, 1, "completion callback once")
    s.assertSlices(3.5)
end

-- The draw pass uses the scan's remaining budget, rather than starting a new slice.
do
    local s = setup(4)
    s.checkCost, s.drawCost = 0.5, 1
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "combined scan/draw work yielded")
    equal(s.checked, 4, "scan finished before drawing")
    equal(s.drawn, 1, "drawing consumes remaining 1 ms of first slice")
    s.finish(job)
    equal(s.drawn, 4, "drawing completes after yields")
    s.assertSlices(4)
end

-- Setup work is charged to the first slice too.
do
    local s = setup(4)
    s.setupCost = 3
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "expensive setup yields before checking")
    equal(s.checked, 0, "no candidates processed after setup exhausted budget")
    s.finish(job)
    equal(s.drawn, 4, "setup yield still completes refresh")
end

-- Nested frame removal shares the deadline and excludes scheduler waits.
do
    local s = setup(1)
    s.start(); s.drain()
    for _ = 1, 47 do s.addFrame(1) end
    s.env.Questie.db.char.complete[1] = true
    s.removeCost, s.slices = 0.5, {}
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "frame removal yielded on time")
    assert(s.removed >= 6 and s.removed <= 7, "removal yields before 30-frame count cap")
    local removed = s.removed
    s.now = s.now + 1000
    equal(s.resume(job), false, "removal continues after wait")
    assert(s.removed - removed >= 6, "scheduler wait does not exhaust resumed removal budget")
    s.finish(job)
    equal(s.removed, 48, "all obsolete frames removed")
    equal(next(s.modules.QuestieMap.questIdFrames[1]), nil, "no stale available frames")
    equal(s.callbacks, 2, "callback completes after removal")
    s.assertSlices(3.5)
end

-- Reused frames must survive the extra yield opportunities during removal.
do
    local s = setup(1)
    s.start(); s.drain()
    for _ = 1, 9 do s.addFrame(1) end
    s.env.Questie.db.char.complete[1] = true
    s.removeCost = 0.5
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "removal suspended before reuse")
    local frames = s.modules.QuestieMap.questIdFrames[1]
    local name = next(frames)
    local replacement = {Type = "objective"}
    s.env[name].data = replacement -- Accepted-quest data replaces an old available frame.
    s.finish(job)
    equal(s.removed, 9, "only original available frames removed")
    equal(s.env[name].data, replacement, "replacement frame preserved")
    equal(frames[name], name, "replacement remains registered")
end

-- Changed quests queue a follow-up refresh, even while the first scan is suspended.
do
    local s = setup(20)
    s.checkCost = 0.5
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "first refresh running")
    s.env.Questie.db.char.complete[1] = true
    s.start() -- Coalesced follow-up runs after this job's callback.
    s.finish(job); s.drain()
    equal(s.callbacks, 2, "both queued callers completed")
    assert(not next(s.modules.QuestieMap.questIdFrames[1] or {}), "queued refresh removes changed quest's icons")
end

-- A missing or non-advancing clock retains the existing count safeguards.
local fallbackBatch
for _, clockAvailable in ipairs({false, true}) do
    local s = setup(1030, clockAvailable)
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "count fallback yields")
    assert(s.checked > 1 and s.checked < 1030, "count safeguard splits a fast scan")
    if fallbackBatch then equal(s.checked, fallbackBatch, "stalled clock uses the same count safeguard") end
    fallbackBatch = s.checked
    s.finish(job)
    equal(s.drawn, 1030, "count fallback completes every quest")
end
-- Discovering active children shares the same budget as the scan/draw passes.
do
    local s = setup(45)
    local db, parents = s.modules.QuestieDB, s.modules.QuestiePlayer.currentQuestlog
    local parentReads = 0
    for id = 1, 40 do parents[id] = {} end
    db.IsComplete = function() return 0 end
    db.QueryQuestSingle = function(_, field)
        if field == "childQuests" then
            parentReads = parentReads + 1
            s.now = s.now + 0.5
            return {}
        end
    end
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "parent discovery yields on time budget")
    assert(parentReads >= 6 and parentReads <= 7, "discovery is bounded before all parents are read")
    equal(s.checked, 0, "availability checks wait until discovery is complete")
    s.finish(job)
    equal(parentReads, 40, "each parent is discovered once")
    equal(s.checked, 5, "only candidates outside the log need eligibility checks")
    equal(s.drawn, 5, "ordinary candidates still render")
    s.assertSlices(3.5)
end
-- A compiled pointer can describe a correction-only record that GetQuest rejects.
do
    local s = setup(3)
    local db = s.modules.QuestieDB
    local getQuest = db.GetQuest
    db.GetQuest = function(id) if id ~= 2 then return getQuest(id) end end
    s.start(); s.drain()
    equal(s.drawn, 2, "An unusable database quest does not abort drawing valid candidates")
    assert(not next(s.modules.QuestieMap.questIdFrames[2] or {}), "No icons for a rejected database record")
    s.start(); s.drain()
    equal(s.drawn, 2, "Repeated scans leave invalid candidates excluded and valid frames reusable")

    -- Data can become unavailable after a previous refresh created real frames.
    db.GetQuest = getQuest; s.start(); s.drain()
    equal(s.drawn, 3, "A restored quest becomes available normally")
    db.GetQuest = function(id) if id ~= 2 then return getQuest(id) end end
    s.start(); s.drain()
    assert(not next(s.modules.QuestieMap.questIdFrames[2] or {}), "Stale frames are removed if their quest becomes invalid")
    equal(s.drawn, 3, "Removing a stale candidate does not redraw unrelated quests")
end

-- A yielded scan must revalidate the quest object before starting its draw pass.
do
    local s = setup(40)
    s.checkCost = 0.5
    s.start()
    local job = table.remove(s.jobs, 1)
    equal(s.resume(job), false, "Scan yields before drawing")
    local getQuest = s.modules.QuestieDB.GetQuest
    s.modules.QuestieDB.GetQuest = function(id) if id ~= 1 then return getQuest(id) end end
    s.finish(job)
    equal(s.drawn, 39, "A missing quest after a yield cannot abort the remaining draw pass")
end
print("Available quest budget and invalid-record recovery tests passed")
