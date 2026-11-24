-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise exploration through the real map-selection and cache logic.
local unpackValues = unpack or table.unpack
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
local updates = 0
local refreshProbe
local modules = {
    ZoneDB = {private = {}}, l10n = {SetUILocale = noop},
    QuestieMap = {utils = {MapExplorationUpdate = function()
        updates = updates + 1
        if refreshProbe then refreshProbe() end
    end}},
}
env.QuestieLoader = {ImportModule = function(_, name) return assert(modules[name], name) end,
    StampLoadBoundary = noop}
local visible, events, hooks, timers = false, {}, {}, {}
env.WorldMapFrame = {IsVisible = function() return visible end, HookScript = function(_, name, hook) hooks[name] = hook end}
env.Questie = {db = {profile = {hideUnexploredMapIcons = true}},
    RegisterEvent = function(_, name, callback) events[name] = callback end}
local function runRefresh()
    local callback = table.remove(timers, 1)
    assert(callback, "deferred exploration refresh queued")
    callback()
end
env.hooksecurefunc = noop
env.GetTime = function() return 100 end
env.IsInInstance = function() return false end
env.wipe = function(values) for key in pairs(values) do values[key] = nil end end
local continent, zone, level, rawMap = 2, 1, 2, 21
local names = {[11] = "One", [21] = "Two"}
local zoomWrites, overlayReads = 0, 0
local onSelect, rejectSelection
env.GetMapContinents = function() return "First", "Second" end
env.GetMapZones = function() return "Zone" end
env.GetCurrentMapContinent = function() return continent end
env.GetCurrentMapZone = function() return zone end
env.GetCurrentMapDungeonLevel = function() return level end
env.GetCurrentMapAreaID = function() return rawMap end
env.GetMapInfo = function() return names[rawMap] end
env.SetMapZoom = function(c, z)
    zoomWrites = zoomWrites + 1
    if rejectSelection and c == 1 then return end
    continent, zone, level, rawMap = c, z or 0, 0, c == -1 and -1 or c * 10 + 1
    if onSelect then onSelect() end
end
env.SetMapByID = function(id) rawMap = id + 1 end
env.SetDungeonMapLevel = function(value) level = value end
env.GetRealZoneText = function() return "Two" end
env.GetZoneText = env.GetRealZoneText
env.GetSubZoneText = function() return "" end
env.GetMinimapZoneText = function() return "" end
local function outdoor(mapID, instance) return {mapID = mapID, mapType = 3, instance = instance} end
local data = {[1001] = outdoor(11, 0), [1002] = outdoor(21, 1), [1003] = outdoor(31, 530),
    [1004] = outdoor(41, 571), [9000] = outdoor(51, 389), [9001] = outdoor(0, 0),
    [9002] = {mapID = 61, mapType = 2, instance = 0}, [9003] = {mapID = 71, mapType = 3}}
for _, id in ipairs({1453, 1454, 1455, 1456, 1457, 1458, 1947, 1954, 1955, 125, 126, 123}) do
    data[id] = outdoor(id, 0)
end
local maskRow = string.char(33, 43) -- Opaque columns 0 through 10; remaining pixels transparent.
env.QuestieCompat = {UiMapData = data, C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}, ExplorationMasks = {
    ["one\\area1"] = string.rep(maskRow .. "~", 64),
    ["one\\area2"] = string.rep(maskRow .. "~", 64),
}, Round = function(value) return math.floor(value + 0.5) end}
local overlays = {{"Interface\\WorldMap\\One\\Area", 512, 256, 100, 100},
    {"Interface\\WorldMap\\One\\PixelFix", 512, 256, 0, 0}, {"", 512, 256, 0, 0},
    {"Bad", 0, 256, 0, 0}, {false, 512, 256, 0, 0}}
local nativeCount = function() overlayReads = overlayReads + 1; return #overlays end
env.GetNumMapOverlays = nativeCount
env.GetMapOverlayInfo = function(index) return unpackValues(overlays[index]) end
local fogClear
env.LibStub = function(name)
    equal(name, "AceAddon-3.0", "Mapster lookup library")
    return {GetAddon = function(_, addonName, silent)
        equal(addonName, "Mapster", "optional addon lookup")
        equal(silent, true, "absent Mapster allowed")
        if fogClear then return {GetModule = function(_, moduleName, optional)
            equal(moduleName, "FogClear", "fog module lookup")
            equal(optional, true, "missing fog module allowed")
            return fogClear
        end} end
    end}
end
local function loadModule(path)
    local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close()
    if setfenv then setfenv(assert(loadstring(source, "@" .. path)), env)()
    else assert(load(source, "@" .. path, "t", env))() end
end
loadModule("Compat/Map.lua")
loadModule("Compat/MapExploration.lua")
local compat = env.QuestieCompat
compat.InitializeMapExplorationCompatibility()
compat.InitializeMapCompatibility()
local isExplored = modules.QuestieMap.utils.IsExplored
local function atPixel(id, x, y) return isExplored(id, x / 10.02, y / 6.68) end
local function selectionRestored(label)
    equal(continent, 2, label .. " continent")
    equal(zone, 1, label .. " zone")
    equal(level, 2, label .. " dungeon level")
    equal(rawMap, 21, label .. " native map ID")
    equal(compat.IsInternalMapReadActive(), false, label .. " read guard cleared")
end
selectionRestored("initialization")
local initializedZoomWrites = zoomWrites
for _, id in ipairs({1453, 1454, 1455, 1456, 1457, 1458, 1947, 1954, 1955, 125, 126, 123,
    9000, 9001, 9002, 9003, 9999}) do
    equal(isExplored(id, 50, 50), true, "cities and maps without outdoor exploration retain icons")
end
equal(isExplored(1001, nil, 20), true, "missing coordinates retain icons")
equal(zoomWrites, initializedZoomWrites, "exceptions never change map selection")
equal(atPixel(1001, 110, 110), true, "opaque mask pixel explored")
equal(atPixel(1001, 160, 110), false, "transparent mask pixel unexplored")
equal(atPixel(1001, 366, 110), true, "second overlay tile uses its own mask")
equal(atPixel(1001, 70, 70), false, "pixelfix and invalid overlays ignored")
equal(atPixel(1001, 700, 500), false, "outside overlays unexplored")
equal(overlayReads, 1, "overlay cache reused")
selectionRestored("exploration query")
equal(type(compat.ExplorationMasks["one\\area1"]), "table", "packed masks decoded")

compat.ClearExplorationCache()
overlays = {{"Interface\\WorldMap\\Custom\\Unknown", 200, 200, 100, 100}}
equal(atPixel(1001, 110, 110), true, "unknown artwork preserves icons inside overlay")
equal(atPixel(1001, 310, 110), false, "unknown artwork does not reveal outside overlay")
equal(overlayReads, 2, "cache invalidation reloads overlays")
-- Discovery refresh invalidates the player's zone before refreshing its pins.
compat.GetWorldMapUiMapContext = function() return 1002, 1001 end
overlays = {}
refreshProbe = function()
    equal(atPixel(1001, 110, 110), false, "player overlay invalidated before visibility refresh")
end
modules.QuestieMap.utils.MapExplorationUpdate()
refreshProbe = nil
equal(updates, 1, "existing exploration refresh invoked once")
equal(atPixel(1001, 110, 110), false, "discovery refresh invalidates cached rectangles")
local refresh = modules.QuestieMap.utils.MapExplorationUpdate
compat.InitializeMapExplorationCompatibility()
compat.InitializeMapCompatibility()
equal(modules.QuestieMap.utils.MapExplorationUpdate, refresh, "initialization does not wrap refresh twice")

overlays = {{"Unknown", 200, 200, 100, 100}}
fogClear = {hooks = {GetNumMapOverlays = nativeCount}}
env.GetNumMapOverlays = function() return 0 end
compat.ClearExplorationCache()
equal(atPixel(1001, 110, 110), true, "Mapster original overlay API used")
equal(atPixel(1001, 700, 500), false, "Mapster fog removal does not count as exploration")
fogClear = {}
compat.ClearExplorationCache()
equal(atPixel(1001, 110, 110), false, "missing Mapster hook uses native API")
fogClear = nil
env.GetNumMapOverlays = nativeCount

for _, id in ipairs({1003, 1004}) do
    equal(atPixel(id, 110, 110), true, "Outland and Northrend overlays read")
    equal(atPixel(id, 700, 500), false, "Outland and Northrend unexplored locations hidden")
    selectionRestored("outdoor instance query")
end

-- Map changes may synchronously reenter visibility checks during a read.
compat.ClearExplorationCache()
local reentries = 0
onSelect = function()
    if rawMap == 11 then
        reentries = reentries + 1
        equal(compat.IsInternalMapReadActive(), true, "internal map read guarded")
        equal(atPixel(1001, 110, 110), false, "reentrant query uses pending cache")
        equal(compat.GetCurrentUiMapID(), 1001, "closed map reports the native selection during the read")
    end
end
equal(atPixel(1001, 110, 110), true, "outer query completes after reentry")
equal(reentries, 1, "reentry does not select map recursively")
onSelect = nil
selectionRestored("reentrant exploration query")
rejectSelection = true
compat.ClearExplorationCache()
equal(atPixel(1001, 110, 110), true, "failed map selection preserves icons")
selectionRestored("failed map selection")
rejectSelection = false
overlays = {}
equal(atPixel(1001, 110, 110), false, "failed map selection was not cached")

local success, message = pcall(function()
    compat.WithLegacyMapRead(1001, function()
        equal(rawMap, 11, "reader executes with requested map selected")
        error("simulated overlay failure", 0)
    end)
end)
equal(success, false, "reader errors propagate")
equal(message, "simulated overlay failure", "reader error preserved")
selectionRestored("reader error")

-- The Azeroth/Outland chooser must also survive temporary exploration reads.
continent, zone, level, rawMap = -1, 0, 0, -1
compat.ClearExplorationCache()
atPixel(1001, 110, 110)
equal(continent, -1, "chooser restored")
equal(rawMap, -1, "chooser native map restored")
equal(compat.IsInternalMapReadActive(), false, "chooser read guard cleared")

-- With the world map open, both fresh reads and discovery must avoid selecting
-- another map, even when the player is in a different zone from the one shown.
compat.ClearExplorationCache()
continent, zone, level, rawMap, visible = 2, 1, 0, 21, true
overlays = {{"Unknown", 200, 200, 100, 100}}
local beforeVisibleReads, beforeVisibleZoom = overlayReads, zoomWrites
equal(atPixel(1002, 110, 110), true, "displayed zone can be read directly")
equal(atPixel(1001, 110, 110), false, "uncached offscreen zone is deferred")
equal(overlayReads, beforeVisibleReads + 1, "only the displayed map's overlays were read")
equal(zoomWrites, beforeVisibleZoom, "open-map reads do not select another map")

rawMap = 11
refreshProbe = function() equal(atPixel(1001, 110, 110), true, "browsing to the deferred zone reveals its pins") end
events.WORLD_MAP_UPDATE()
events.WORLD_MAP_UPDATE()
equal(#timers, 1, "map updates coalesce")
runRefresh()
equal(zoomWrites, beforeVisibleZoom, "browsing refresh makes no map selection")
rawMap = 21
overlays = {}
refreshProbe = function()
    equal(atPixel(1002, 110, 110), true, "unrelated overlay cache survives player-zone invalidation")
    equal(atPixel(1001, 110, 110), true, "offscreen stale zone keeps its last known overlays")
end
modules.QuestieMap.utils.MapExplorationUpdate()
equal(overlayReads, beforeVisibleReads + 2, "transition with another zone displayed reads no overlays")

visible = false
refreshProbe = function()
    equal(atPixel(1001, 110, 110), false, "closing the map refreshes stale offscreen overlays")
    equal(atPixel(1002, 110, 110), true, "closing the map retains unrelated cached zones")
end
hooks.OnHide()
runRefresh()
equal(overlayReads, beforeVisibleReads + 3, "only the stale zone was refreshed after close")

-- Keep cached data fresh even if the player discovers an area with the filter off.
env.WorldMapFrame.GetScript = noop
env.Questie.UnregisterEvent, env.Questie.RegisterBucketEvent = noop, noop
modules.QuestieEventHandler = {private = {
    MapExplorationUpdated = function() error("disabled filter should not refresh pins") end,
}}
modules.QuestEventHandler = {}
loadModule("Compat/Events.lua")
compat.QuestieEventHandler_RegisterLateEvents()
env.Questie.db.profile.hideUnexploredMapIcons = false
overlays = {{"Unknown", 200, 200, 100, 100}}
events.ZONE_CHANGED()
events.ZONE_CHANGED_INDOORS()
equal(#timers, 1, "zone events coalesce with the filter off")
runRefresh()
equal(overlayReads, beforeVisibleReads + 3, "cache invalidation alone reads no overlays")
equal(atPixel(1001, 110, 110), true, "next visibility check reads the latest discovery")
equal(overlayReads, beforeVisibleReads + 4, "only the player's map needed a fresh read")
print("Map exploration compatibility regressions passed")
