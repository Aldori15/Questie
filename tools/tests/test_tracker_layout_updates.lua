-- Run from the addon root with Lua 5.1 or 5.2+.
-- Real display-data/item readers and tracker update body; UI rows are counted at layout entry.
local function noop() end
local function equal(a, b, label) assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local env = setmetatable({}, {__index = _G})
env._G, env.tinsert = env, table.insert
local function run(source)
    if setfenv then return setfenv(assert(loadstring(source)), env)() end
    return assert(load(source, "tracker layout regression", "t", env))()
end
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local clock, combat, layouts, failLayout = 100, false, 0, false
local timers, bags, completionTexts = {}, {}, {}
local specialItem, itemReady, playerLevel = nil, true, 80
local unpackValues = unpack or table.unpack
env.GetTime = function() return clock end
env.InCombatLockdown = function() return combat end
env.GetQuestTimers = function() return unpackValues(timers) end
env.GetItemCount = function(id) return bags[id] or 0 end
env.GetItemSpell = function() return itemReady and "Use item" or nil end
env.IsEquippableItem = function() return false end
env.QuestLogListScrollFrame = {ScrollBar = {}}
local rows = {{title = "Zone", header = true}, {title = "Mapped", id = 1, level = 10},
    {title = "Custom", id = 2, level = 10}}
env.GetNumQuestLogEntries = function() return #rows end
env.GetQuestSortIndex = function() return 1 end
env.GetQuestLogSpecialItemInfo = function(index) return index == 3 and specialItem or nil end
env.GetQuestLogCompletionText = function(index) return completionTexts[index] end
local function logIndex(id)
    for index, row in ipairs(rows) do if row.id == id then return index end end
end
env.QuestieCompat = {C_Timer = {}, C_Map = {}, GetQuestLogIndexByID = logIndex,
    GetQuestLogTitle = function(index)
        local row = rows[index]
        if row then return row.title, row.level, nil, row.header, nil, row.complete, 1, row.id end
    end}
env.C_Timer = env.QuestieCompat.C_Timer
env.Questie = {Debug = noop, db = {profile = {trackerEnabled = true,
    trackerFontSizeQuest = 12, trackerFontSizeZone = 12, trackerFontSizeObjective = 12}, char = {}}}
local profile = env.Questie.db.profile
local known = {Id = 1, name = "Mapped", level = 10, zoneOrSort = 12, requiredSourceItems = {},
    Objectives = {{Index = 1, Type = "item", Description = "Token", Collected = 0, Needed = 8, Completed = false}},
    IsComplete = function(self) return self.complete or 0 end}
module("QuestiePlayer").currentQuestlog = {[1] = known}
module("QuestiePlayer").GetPlayerLevel = function() return playerLevel end
module("QuestieDB").HasQuestData = function(id) return id == 1 end
module("QuestieDB").QueryQuestSingle = function() end
module("QuestieDB").QueryItemSingle = function(id)
    if id ~= 999 then return 12 end -- The native-only quest's item is absent from QuestieDB.
end
local cache = {[2] = {objectives = {{type = "item", text = "Crystal", raw_text = "Crystal: 0/8",
    numFulfilled = 0, numRequired = 8, raw_finished = false}}}}
module("QuestLogCache").questLog_DO_NOT_MODIFY = cache
module("QuestieLib").GetQuestTypeSuffix = function() return known.suffix or "" end
module("QuestieLib").GetFullObjectiveText = function(text) return text end
setmetatable(module("l10n"), {__call = function(_, text) return text end})
run(read("Modules/Tracker/TrackerData.lua"))
run(read("Modules/Tracker/TrackerUtils.lua"))
env.TrackerData, env.TrackerUtils = module("TrackerData"), module("TrackerUtils")
local tracker = module("QuestieTracker")
env.QuestieTracker = tracker
tracker.started = true
env.TrackerHeaderFrame, env.TrackerQuestFrame = {Update = noop}, {Update = noop}
env.TrackerBaseFrame = {Update = function()
    layouts = layouts + 1
    if failLayout then failLayout = false; error("interrupted layout") end
end}
env.TrackerLinePool = {ResetLinesForChange = noop, ResetButtonsForChange = noop,
    HideAllStatusIcons = noop, GetLastLine = function() end}
env.TrackerQuestOrder = {GetSortedQuestIds = function(_, quests)
    assert(quests[1] == known and quests[2], "layout must use refreshed mapped and native records")
    return {}, {}
end}
env.TrackerAchievements = {GetTrackedIds = function() return {} end}
env.trackerMarginLeft, env.trackerMarginRight = 2, 2
env.lastTrackerUpdate, env.isFirstRun = 0, false
env.trackerBaseFrame = {IsShown = function() return false end}
env.QuestieCombatQueue = {Queue = function(_, fn) fn() end}
local source = read("Modules/Tracker/QuestieTracker.lua")
run(assert(source:match("(local layoutRevision.-)\nfunction QuestieTracker:UpdateFormatting")))
local function check() clock = clock + 1; tracker:UpdateFromQuestLog() end
local function changes(fn, label)
    local before = layouts
    fn(); check()
    equal(layouts, before + 1, label)
    check()
    equal(layouts, before + 1, label .. " settles without a second layout")
end
check()
equal(layouts, 1, "first check lays out")
for _ = 1, 8 do check() end
equal(layouts, 1, "unchanged log events skip row layout")
changes(function() known.Objectives[1].Collected = 1 end, "mapped progress")
changes(function() cache[2].objectives[1].numFulfilled = 1 end, "native progress")
changes(function() cache[1] = {objectives = {{text = "Token", numFulfilled = 2, numRequired = 8}}} end,
    "live cache progresses before database objective object")
changes(function() rows[3].title = "Loaded native title" end, "loading native title")
changes(function() rows[3].complete = 1 end, "native completion")
changes(function() known.suffix = "+" end, "quest tag")
changes(function() completionTexts[2] = "Return to the quest giver" end, "completion text")
changes(function() known.sourceItemId = 300; bags[300] = 1 end, "new usable item without a loot-message event")
local before = layouts
bags[300] = 2; check()
equal(layouts, before, "item count alone does not recreate buttons")
changes(function() itemReady = false end, "item availability")
changes(function() itemReady = true end, "item cache becomes usable")
changes(function() specialItem = "item:999:0"; bags[999] = 1 end, "native item absent from database")
changes(function() timers = {60} end, "quest timer starts after acceptance")
before = layouts
timers = {59}; check()
equal(layouts, before, "timer countdown does not recreate timer rows")
changes(function() timers = {} end, "timer stops")
changes(function() playerLevel = 81 end, "difficulty colors follow player level")
known.complete, known.isComplete = 1, true
local items, usableWhenComplete = env.TrackerUtils:GetQuestItemButtonState(known, 1)
equal(items[1], 300, "completed quest retains usable source item")
equal(usableWhenComplete, true, "completion item-button policy preserved")
check()

-- Explicit UI/achievement updates always lay out, even with unchanged quest data.
clock = clock + 1; before = layouts; tracker:Update()
equal(layouts, before + 1, "explicit UI request")
check(); equal(layouts, before + 1, "completed explicit layout is current")
tracker:Update() -- Throttled, but must invalidate the previous layout.
check(); equal(layouts, before + 2, "quest-log check recovers throttled UI request")
before = layouts
check(); tracker:Update()
equal(layouts, before + 1, "skipped check never throttles an explicit update")
tracker:Update(true)
equal(layouts, before + 2, "true still bypasses the legacy throttle")
combat = true; tracker:Update(true); check()
equal(layouts, before + 2, "forced request still respects combat lockdown")
combat = false; check()
equal(layouts, before + 3, "combat-deferred invalidation is retained")
profile.trackerEnabled = false; tracker:Update(true)
profile.trackerEnabled = true; check()
equal(layouts, before + 4, "hidden tracker cannot mark a layout current")
failLayout = true; known.name = "Changed"
clock = clock + 1
local ok = pcall(tracker.UpdateFromQuestLog, tracker)
equal(ok, false, "interrupted layout exposed by fixture")
before = layouts; check()
equal(layouts, before + 1, "failed layout retries with unchanged data")

local data = env.TrackerData
local revision = data.GetLayoutRevision(data.Refresh())
rows[4] = {title = "New custom quest", id = 3, level = 1}
assert(data.GetLayoutRevision(data.Refresh()) ~= revision, "acceptance changes membership revision")
revision = data.GetLayoutRevision(data.Refresh())
rows[4] = nil
assert(data.GetLayoutRevision(data.Refresh()) ~= revision, "abandonment changes membership revision")

-- Real event coalescing must retain force priority and allow the next update to queue.
local queue, requests = {}, {}
env.QuestieCombatQueue.Queue = function(_, fn) queue[#queue + 1] = fn end
local oldUpdate, oldCheck = tracker.Update, tracker.UpdateFromQuestLog
tracker.Update = function(_, force) requests[#requests + 1] = force and "forced" or "explicit" end
tracker.UpdateFromQuestLog = function() requests[#requests + 1] = "check" end
local eventSource = read("Modules/Quest/QuestEventHandler.lua")
local queueUpdate = run(assert(eventSource:match("(local trackerUpdateQueued.-)\nlocal function CacheRequiredItemConditionStates"))
    .. "\nreturn QueueTrackerUpdate")
for _ = 1, 8 do queueUpdate(false) end
equal(#queue, 1, "ordinary log checks coalesce during combat")
queueUpdate(true)
equal(#queue, 1, "acceptance upgrades the pending slot")
table.remove(queue, 1)()
equal(requests[1], "forced", "forced update wins")
queueUpdate(false); table.remove(queue, 1)()
equal(requests[2], "check", "queue resets for later log checks")

-- Execute the production display/CVar registrations with original 3.3.5 event names.
local events, delayed = {}, {}
env.Questie.RegisterEvent = function(_, name, fn) events[name] = fn end
env.C_Timer.After = function(_, fn) delayed[#delayed + 1] = fn end
local handlerSource = read("Modules/QuestieEventHandler.lua")
local geometry = "local trackerGeometryUpdateQueued = false\n"
    .. assert(handlerSource:match("(local function RefreshTrackerGeometry%(%).-\nend)"))
    .. "\n" .. assert(handlerSource:match('(Questie:RegisterEvent%("DISPLAY_SIZE_CHANGED".-)\n    Questie:RegisterEvent%("PLAYER_LEVEL_UP"'))
run(geometry)
events.CVAR_UPDATE("CVAR_UPDATE", "unrelatedSetting")
equal(#delayed, 0, "unrelated CVars do not lay out")
events.CVAR_UPDATE("CVAR_UPDATE", "UISCALE")
events.CVAR_UPDATE("CVAR_UPDATE", "useUiScale")
events.DISPLAY_SIZE_CHANGED()
equal(#delayed, 1, "scale/resolution event burst coalesces")
table.remove(delayed, 1)()
equal(#queue, 1, "geometry refresh waits in combat queue")
table.remove(queue, 1)()
equal(requests[#requests], "forced", "geometry refresh bypasses unchanged-data check")
equal(events.UI_SCALE_CHANGED, nil, "no unsupported native event")
tracker.Update, tracker.UpdateFromQuestLog = oldUpdate, oldCheck
print("PASS: tracker revisions/layout skipping, native/mapped progress, items, timers, explicit/forced updates, combat, queue priority, and 3.3.5 geometry events")
