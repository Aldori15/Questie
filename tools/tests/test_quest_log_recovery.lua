-- Run from the addon root with Lua 5.1 or 5.2+. Exercise shared loading recovery and acceptance lifetimes.
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function harness()
    local env = setmetatable({}, {__index = _G})
    local modules, quests, queue, timers, accepted, scans = {}, {}, {}, {}, {}, {}
    local now, fullMiss = 0, false
    local function module(name)
        if not modules[name] then modules[name] = {private = {}} end
        return modules[name]
    end
    local function newTimer(delay, callback)
        local timer = {due = now + delay, delay = delay, callback = callback}
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end
    env.CreateFrame = function() return {} end
    env.GetTime = function() return now end
    env.GetCursorInfo = noop
    env.Questie = {Debug = noop, SendMessage = noop, db = {profile = {}}}
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.QuestieCompat = {C_Timer = {NewTimer = newTimer, After = newTimer, NewTicker = newTimer},
        GetQuestLogIndexByID = function(id) return quests[id] and quests[id].present and 1 or 0 end}
    module("QuestieCombatQueue").Queue = function(_, callback) queue[#queue + 1] = callback end
    module("QuestLogCache").CheckForChanges = function(ids, fullScan)
        local miss = fullScan and fullMiss or false
        for id in pairs(ids) do
            if not fullScan then scans[id] = (scans[id] or 0) + 1 end
            if quests[id] and quests[id].present and not quests[id].ready then miss = true end
        end
        return miss, {}
    end
    module("QuestLogCache").HasPendingItemRegression = function() return false end
    module("QuestLogCache").RemoveQuest = noop
    module("QuestieDB").HasQuestData = function() return false end
    module("TrackerUtils").ClearTomTomTargetForQuest = noop
    module("QuestieLib").CacheItemNames = noop
    module("BreadcrumbQuests").CheckQuestBreadcrumbs = noop
    module("QuestieJourney").AcceptQuest = function(_, id) accepted[id] = (accepted[id] or 0) + 1 end
    module("QuestieJourney").AbandonQuest = noop
    module("QuestieAnnounce").AcceptedQuest = noop
    module("QuestieAnnounce").AbandonedQuest = noop
    module("QuestLifecycle").AcceptQuest = noop
    module("QuestLifecycle").AbandonQuest = noop
    module("QuestiePartyObjectives").ScheduleUpdate = noop
    module("QuestieTracker").Update = noop
    module("QuestieTracker").UpdateFromQuestLog = noop
    module("QuestieQuest").SetObjectivesDirty = noop
    module("AutoRoute").RemoveFromRoute = noop
    module("AvailableQuests").ResetLastNpcGuid = noop
    module("IsleOfQuelDanas").CheckForActivePhase = function() return false end
    if setfenv then setfenv(assert(loadfile("Modules/Quest/QuestEventHandler.lua")), env)()
    else assert(loadfile("Modules/Quest/QuestEventHandler.lua", "t", env))() end
    local public = module("QuestEventHandler")
    local h = {events = public.private, accepted = accepted, scans = scans}
    function h:drain() while #queue > 0 do table.remove(queue, 1)() end end
    function h:activeTimer()
        local active
        for _, timer in ipairs(timers) do
            if not timer.cancelled and not timer.fired then
                assert(not active, "Only one recovery timer may be active")
                active = timer
            end
        end
        return active
    end
    function h:advance(seconds)
        now = now + seconds
        -- Tests advance to a single deadline; newly scheduled timers wait for another advance.
        local timer = self:activeTimer()
        if timer and timer.due <= now then timer.fired = true; timer.callback() end
        self:drain()
    end
    function h:quest(id, ready) quests[id] = {present = true, ready = ready} end
    function h:ready(id) quests[id].ready = true end
    function h:hide(id) quests[id].present = false end
    function h:remove(id) quests[id].present = false; self.events:QuestRemoved(id, true) end
    function h:fullMiss(value) fullMiss = value end
    function h:init(id) self:quest(id, true); public.InitQuestLogStates({[id] = true}) end
    return h
end

-- Missing acceptance data recovers without a subsequent QUEST_LOG_UPDATE event.
local h = harness()
h:quest(1, false); h.events:QuestAccepted(1, 1); h:drain()
local timer = assert(h:activeTimer())
equal(timer.delay, 20, "Initial recovery delay")
for _ = 1, 3 do h.events:HandleQuestAccepted(1) end
equal(h:activeTimer(), timer, "Repeated misses preserve the deadline")
h:quest(2, false); h.events:QuestAccepted(1, 2); h:drain()
h:ready(2)
local priorScans = h.scans[1]
h.events:QuestLogUpdate(); h:drain()
equal(h.scans[1], priorScans + 1, "A lifecycle owns only one queued retry")
equal(h.accepted[2], 1, "An unresolved quest does not block a ready quest")
h:ready(1); h:advance(20)
equal(h.accepted[1], 1, "Timer finishes acceptance without another event")
equal(h:activeTimer(), nil, "Successful loading cancels recovery")
h.events:HandleQuestAccepted(1); h.events:QuestLogUpdate(); h:drain()
equal(h.accepted[1], 1, "Acceptance side effects execute once")

-- Accepted-quest cache misses share the fallback and keep its deadline during event traffic.
h = harness(); h:init(1); h:fullMiss(true); h.events:UpdateAllQuests()
timer = assert(h:activeTimer())
h:advance(19); h.events:QuestLogUpdate(); h:drain()
equal(h:activeTimer(), timer, "Events do not postpone the fallback")
h:advance(1)
for _, delay in ipairs({40, 80, 160, 320, 320}) do
    equal(h:activeTimer().delay, delay, "Unresolved loading backs off to the cap")
    h:advance(delay)
end
timer = h:activeTimer()
h:fullMiss(false); h.events:UpdateAllQuests()
equal(h:activeTimer(), nil, "A successful ordinary scan cancels the timer")
timer.callback()
equal(h:activeTimer(), nil, "A cancelled callback cannot restart recovery")
h:fullMiss(true); h.events:UpdateAllQuests()
equal(h:activeTimer().delay, 20, "Successful recovery resets the delay")
h:advance(20); h:quest(2, false); h.events:QuestAccepted(1, 2); h:drain()
equal(h:activeTimer().delay, 20, "A new acceptance resets a backed-off timer")

-- Queued work from an abandoned acceptance cannot act on a reaccepted quest with the same ID.
h = harness(); h:quest(1, false); h.events:QuestAccepted(1, 1); h:drain()
h:remove(1); h:quest(1, true); h.events:QuestAccepted(1, 1)
h.events:QuestLogUpdate(); h:drain()
equal(h.accepted[1], 1, "Old retry cannot duplicate acceptance of the new lifecycle")
h.events:QuestLogUpdate(); h:drain()
equal(h:activeTimer(), nil, "Removed loading quests do not keep recovery alive")
h = harness(); h:quest(1, true); h.events:QuestAccepted(1, 1)
h:remove(1); h:quest(1, true); h.events:QuestAccepted(1, 1); h:drain()
equal(h.accepted[1], 1, "Old combat-queued acceptance cannot act on the new lifecycle")
h = harness(); h:quest(1, false); h.events:QuestAccepted(1, 1); h:drain()
h:remove(1); h:advance(20)
equal(h.accepted[1], nil, "Abandoned quests are never accepted by the timer")
equal(h:activeTimer(), nil, "Recovery stops after abandonment")
h = harness(); h:quest(1, true); h:hide(1); h.events:QuestAccepted(1, 1); h:drain()
equal(h.accepted[1], nil, "A zero log index cannot run acceptance side effects")
equal(h.events:HandleQuestAccepted(1), true, "A missing log index of zero is terminal")

print("Quest log recovery tests passed")
