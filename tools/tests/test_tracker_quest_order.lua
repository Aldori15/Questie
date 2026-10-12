-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise production quest metadata, sorting strategies, and timer lifecycle.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function order(actual, expected, label)
    equal(table.concat(actual, ","), table.concat(expected, ","), label)
end
local function loadModule(path, env)
    if setfenv then
        setfenv(assert(loadfile(path)), env)()
    else
        assert(loadfile(path, "t", env))()
    end
end
local files = {}
for line in io.lines("Questie-335.toc") do
    local path = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
    if path:match("^Modules/Tracker/Sorter/.*%.lua$")
        or path == "Modules/Tracker/TrackerUtils.lua"
        or path == "Modules/Tracker/TrackerQuestOrder.lua" then
        files[#files + 1] = path
    end
end
local moduleEntries = 0
for _, path in ipairs(files) do
    if path == "Modules/Tracker/TrackerQuestOrder.lua" then moduleEntries = moduleEntries + 1 end
end
equal(moduleEntries, 1, "quest-order controller registered exactly once")

local function setup(mode)
    local env = setmetatable({}, {__index = _G})
    env._G, env.strmatch = env, string.match
    local s = {quests = {}, spawns = {}, priorities = {}, tickers = {}, queued = {}, updates = 0,
        x = 0, y = 0, positionAvailable = true, inInstance = false, nearestReads = 0}
    env.Questie = {db = {profile = {trackerSortObjectives = mode}, char = {}}, Debug = function() end}
    env.GetTime = function() return 0 end
    env.debugstack = function() end
    env.QuestLogListScrollFrame = {ScrollBar = {}}
    env.IsInInstance = function() return s.inInstance end
    local maps = {
        [1000] = {mapType = 3, parentMapID = 1}, [1] = {mapType = 2, name = "Continent A"},
        [2000] = {mapType = 3, parentMapID = 2}, [2] = {mapType = 2, name = "Continent B"},
        [3000] = {mapType = 3, parentMapID = 3000, name = "Detached map"},
    }
    env.QuestieCompat = {C_Map = {
        GetBestMapForUnit = function() return s.playerMap or 1000 end,
        GetMapInfo = function(id) return maps[id] end,
        GetAreaInfo = function(id) return ({[200] = "Beta"})[id] end,
        GetWorldPosFromMapPos = function(_, position) return 1, position end,
    }, C_Timer = {NewTicker = function(interval, callback)
        local ticker = {interval = interval, callback = callback}
        function ticker:Cancel() self.cancelled = true end
        s.tickers[#s.tickers + 1] = ticker
        return ticker
    end}}
    loadModule("Modules/Libs/QuestieLoader.lua", env)
    local loader = env.QuestieLoader
    local function module(name) return loader:CreateModule(name) end
    local localization = module("l10n")
    localization.zoneLookup = {{[100] = "Alpha"}}
    localization.questCategoryLookup = {[-373] = "Jewelcrafting"}
    setmetatable(localization, {__call = function(_, text) return "Localized " .. text end})
    module("ZoneDB").GetUiMapIdByAreaId = function(_, id)
        return ({[100] = 1000, [200] = 2000, [300] = 3000})[id]
    end
    module("ZoneDB").GetLocalizedDungeonName = function(_, id)
        return id == 400 and "Dungeon" or nil
    end
    module("QuestiePlayer").currentQuestlog = s.quests
    module("QuestieLib").GetQuestTypeSuffixPriority = function(id) return s.priorities[id] or 0 end
    module("QuestieMap").GetNearestQuestSpawn = function(_, quest)
        s.nearestReads = s.nearestReads + 1
        local spawn = s.spawns[quest.Id] or {}
        return nil, spawn.zone, nil, nil, nil, spawn.distance
    end
    module("QuestieCoords").GetPlayerMapPosition = function()
        if s.positionAvailable then return {x = s.x, y = s.y}, 1000 end
    end
    module("QuestieCombatQueue").Queue = function(_, callback) s.queued[#s.queued + 1] = callback end
    module("QuestieTracker").Update = function() s.updates = s.updates + 1 end
    for _, path in ipairs(files) do loadModule(path, env) end
    s.owner = loader:ImportModule("TrackerQuestOrder")
    equal(type(s.owner.GetSortedQuestIds), "function", "ordering available after manifest load")
    function s.sort(newMode)
        if newMode then env.Questie.db.profile.trackerSortObjectives = newMode end
        return s.owner:GetSortedQuestIds()
    end
    function s.quest(id, level, zone, objectives, complete, distance, spawnZone, priority)
        local quest = {Id = id, level = level, zoneOrSort = zone, Objectives = objectives or {}}
        function quest:IsComplete() return complete and 1 or 0 end
        s.quests[id], s.spawns[id], s.priorities[id] = quest,
            {distance = distance, zone = spawnZone}, priority
        return quest
    end
    s.env = env
    return s
end

local tests = 0
local function populated(mode)
    local s = setup(mode)
    s.quest(10, 20, 100, {{Collected = 1, Needed = 4}}, false, 30, 100, 2)
    s.quest(20, 10, 100, {{Collected = 1, Needed = 2}, {Collected = 2, Needed = 2}}, false, 10, 100, 1)
    s.quest(30, 30, 200, {{Collected = 0, Needed = 2}}, true, 1, 200, 1)
    s.quest(40, 10, 100, {{Collected = 3, Needed = 4}}, false, nil, 100, 0)
    s.quest(50, 40, 0, {}, false, 20, 100, 0)
    return s
end

-- All nine settings retain their ordering, completion/type tie-breaks, and headings.
local expected = {
    byZone = {30, 40, 20, 10, 50}, -- Native "Beta" sorts before translated "Localized Alpha".
    byComplete = {30, 50, 40, 20, 10}, byCompleteReversed = {10, 40, 20, 30, 50},
    byLevel = {40, 20, 10, 30, 50}, byLevelReversed = {50, 30, 10, 40, 20},
    byProximity = {20, 50, 10, 40, 30}, byProximityReversed = {30, 40, 10, 50, 20},
    byZonePlayerProximity = {30, 20, 10, 40, 50}, byZonePlayerProximityReversed = {30, 40, 10, 20, 50},
}
local headings = {byComplete = "Quests (By %% Complete)", byCompleteReversed = "Quests (By %% Complete Reversed)",
    byLevel = "Quests (By Level)", byLevelReversed = "Quests (By Level Reversed)",
    byProximity = "Quests (By Proximity)", byProximityReversed = "Quests (By Proximity Reversed)"}
for mode, wanted in pairs(expected) do
    local s = populated(mode)
    local ids, details = s.sort()
    order(ids, wanted, mode)
    equal(details[10].quest, s.quests[10], "original quest reference retained")
    equal(details[10].questCompletePercent, 0.25, "partial completion")
    equal(details[20].questCompletePercent, 0.75, "objective percentages averaged")
    equal(details[30].questCompletePercent, 1, "completed quest")
    equal(details[50].questCompletePercent, 1, "no-objective quest")
    equal(details[10].zoneName, headings[mode] or "Localized Alpha", "sort heading retained")
    tests = tests + 1
end

-- Zone/category names keep their native, localization, dungeon, and unknown fallbacks.
do
    local s = setup("byZone")
    s.quest(1, 1, -373); s.quest(2, 2, 400); s.quest(3, 3, nil); s.quest(4, 4, 0); s.quest(5, 5, 999)
    local _, details = s.sort()
    equal(details[1].zoneName, "Localized Jewelcrafting", "quest category localized")
    equal(details[2].zoneName, "Localized Dungeon", "dungeon name fallback")
    for _, id in ipairs({3, 4, 5}) do equal(details[id].zoneName, "Unknown Zone", "missing zone fallback") end
    tests = tests + 1
end

-- Missing distance/continent data and level ties do not break proximity sorting.
for _, mode in ipairs({"byProximity", "byProximityReversed", "byZonePlayerProximity", "byZonePlayerProximityReversed"}) do
    local s = setup(mode)
    s.quest(1, 5, 100, {}, false, 1, 100)
    s.quest(2, 10, 100, {}, false, 1, 100)
    s.quest(3, 20, 100, {}, false, nil, nil)
    local ids = s.sort()
    local reversed = mode:match("Reversed$")
    order(ids, reversed and {3, 2, 1} or {1, 2, 3}, "proximity ties and unknown continent")
    equal(#s.tickers, 1, "one proximity timer")
    equal(s.tickers[1].interval, 5, "five-second proximity interval")
    s.sort(); equal(#s.tickers, 1, "repeated sorting does not duplicate timer")
    tests = tests + 1
end

-- Switching modes cancels the previous timer and clears its diagnostic flag.
do
    local s = populated("byProximity")
    s.sort()
    s.owner.FilterProximityTimer = true
    s.sort("byZonePlayerProximity")
    equal(s.tickers[1].cancelled, true, "plain proximity timer cancelled")
    equal(s.owner.FilterProximityTimer, nil, "plain proximity flag cleared")
    equal(#s.tickers, 2, "zone proximity timer started")
    s.owner.FilterProximityTimer = true
    s.sort("byLevel")
    equal(s.tickers[2].cancelled, true, "zone proximity timer cancelled")
    equal(s.owner.FilterProximityTimer, nil, "zone proximity flag cleared")
    s.sort("byProximity")
    equal(#s.tickers, 3, "returning to proximity starts a fresh timer")
    tests = tests + 1
end

-- Instances prevent timer creation and stop an existing timer on its next tick.
for _, mode in ipairs({"byProximity", "byZonePlayerProximity"}) do
    local s = populated(mode)
    s.inInstance = true; s.sort()
    equal(#s.tickers, 0, "no proximity timer in instance")
    s.inInstance = false; s.sort()
    equal(#s.tickers, 1, "timer starts after leaving instance")
    s.inInstance = true; s.tickers[1].callback()
    equal(s.tickers[1].cancelled, true, "entering instance cancels timer")
    equal(#s.queued, 0, "instance cancellation does not render")
    tests = tests + 1
end

-- Timer updates remain movement-gated and use the combat queue before rendering.
for _, mode in ipairs({"byProximity", "byZonePlayerProximity"}) do
    local s = setup(mode)
    local first = s.quest(1, 5, 100, {}, false, 1, 100)
    s.quest(2, 10, 100, {}, false, 1, 100)
    s.sort()
    local tick = s.tickers[1].callback
    s.positionAvailable = false; tick()
    equal(#s.queued, 0, "unknown position does not update")
    s.positionAvailable = true; tick()
    equal(#s.queued, 0, "unchanged order does not update")
    first.level = 20; s.x = 0.005; tick()
    equal(#s.queued, 0, "movement below threshold does not update")
    s.x = 0.02; tick()
    equal(#s.queued, 1, "changed order queues one update")
    equal(s.updates, 0, "rendering deferred to combat queue")
    s.queued[1]()
    equal(s.updates, 1, "queued callback renders tracker")
    equal(s.owner.FilterProximityTimer, true, "proximity diagnostic flag set")
    tick(); equal(#s.queued, 1, "stationary tick does not queue again")
    tests = tests + 1
end

do
    local s = setup("byZone")
    local ids, details = s.sort()
    equal(#ids, 0, "empty log has no sorted quests")
    equal(next(details), nil, "empty log has no metadata")
    equal(#s.tickers, 0, "static sort has no timer")
    tests = tests + 1
end

print("Tracker quest-order regressions passed (" .. tests .. " groups)")
