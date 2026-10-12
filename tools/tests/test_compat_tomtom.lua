-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the complete map compatibility file and its TomTom adapter.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {
    ZoneDB = {private = {dungeonLocations = {[900] = {{101, 32, 45}}},
        subZoneToParentZone = {[901] = 900}, areaIdToUiMapId = {[101] = 1001}}},
    l10n = {SetUILocale = noop},
    QuestieMap = {utils = {MapExplorationUpdate = noop}},
}
local areaIds = {[9000] = 900, [9001] = 901}
function modules.ZoneDB:GetAreaIdByUiMapId(id)
    if id == 9999 then error("unknown map") end
    return areaIds[id]
end
function modules.ZoneDB:GetUiMapIdByAreaId(id) return self.private.areaIdToUiMapId[id] end
env.QuestieLoader = {
    ImportModule = function(_, name) return assert(modules[name], name) end,
    StampLoadBoundary = noop,
}
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"); file:close()
    if setfenv then
        setfenv(assert(loadstring(source, "@" .. path)), env)()
    else
        assert(load(source, "@" .. path, "t", env))()
    end
end
local function frame()
    return {
        visible = true, scripts = {},
        IsVisible = function(self) return self.visible end,
        GetScript = function(self, event) return self.scripts[event] end,
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        HookScript = noop,
    }
end
env.WorldMapFrame = frame()
env.WorldMapFrame.visible = false
local detail = frame()
env.WorldMapDetailFrame = detail
local left, top, width, height, scale = 100, 300, 400, 200, 2
detail.GetLeft = function() return left end
detail.GetTop = function() return top end
detail.GetWidth = function() return width end
detail.GetHeight = function() return height end
detail.GetEffectiveScale = function() return scale end
local cursorX, cursorY = 400, 400
env.GetCursorPosition = function() return cursorX, cursorY end
local continent, zone, mapLevel = 1, 1, 0
local nativeMaps = {{11}, {21}, {31}, {41}}
local mapNames = {[11] = "Zone One", [21] = "Zone Two", [31] = "Zone Three", [41] = "Zone Four"}
local zoomWrites = 0
env.GetMapContinents = function() return "One", "Two", "Three", "Four" end
env.GetMapZones = function() return "Zone" end
env.GetCurrentMapContinent = function() return continent end
env.GetCurrentMapZone = function() return zone end
env.GetCurrentMapDungeonLevel = function() return mapLevel end
env.GetCurrentMapAreaID = function() return nativeMaps[continent][zone] end
env.GetMapInfo = function() return mapNames[env.GetCurrentMapAreaID()] end
env.SetMapZoom = function(c, z) continent, zone = c, z or 1; zoomWrites = zoomWrites + 1 end
env.SetDungeonMapLevel = function(level) mapLevel = level end
env.IsInInstance = function() return false end
env.GetTime = function() return 100 end
local actualZone = "Zone One"
env.GetRealZoneText = function() return actualZone end
env.GetZoneText = env.GetRealZoneText
env.GetSubZoneText = function() return "" end
env.GetMinimapZoneText = function() return "" end
local hooks = {}
env.hooksecurefunc = function(object, method, callback)
    hooks[#hooks + 1] = {object, method, callback}
end
local uiData = {
    [1001] = {1000, 1000, 1000, 1000, mapID = 11, mapType = 3, name = "Zone One", instance = 0},
    [1002] = {1000, 1000, 1000, 1000, mapID = 21, mapType = 3, name = "Zone Two", instance = 1},
    [1003] = {1000, 1000, 1000, 1000, mapID = 31, mapType = 3, name = "Zone Three", instance = 530},
    [1004] = {1000, 1000, 1000, 1000, mapID = 41, mapType = 3, name = "Zone Four", instance = 571},
    [125] = {mapID = 504, mapType = 3, name = "Dalaran", instance = 571},
    [126] = {mapID = 504.1, mapType = 3, name = "The Underbelly", instance = 571},
    [947] = {mapID = 0.9}, [1414] = {mapID = 1}, [1415] = {mapID = 2}, [1945] = {mapID = 3},
}
env.QuestieCompat = {UiMapData = uiData, Round = function(value) return math.floor(value + 0.5) end}
loadModule("Compat/Map.lua")
loadModule("Compat/TomTom.lua")
local compat = env.QuestieCompat
compat.InitializeMapCompatibility()
equal(continent, 1, "cache initialization restores continent selection")
equal(zone, 1, "cache initialization restores zone selection")
local oldZoomWrites = zoomWrites
compat.InitializeMapCompatibility()
equal(zoomWrites, oldZoomWrites, "repeated map initialization does not rebuild cache")

local waypoints = {}
local uid = {}
env.TomTom = {db = {profile = {mapcoords = {playeraccuracy = 1, cursoraccuracy = 2}}},
    ShowHideWorldCoords = noop,
    AddZWaypoint = function(_, ...)
        waypoints[#waypoints + 1] = {n = select("#", ...), ...}
        return uid
    end,
}
local function waypoint(uiMapId, expectedContinent, expectedZone, x, y)
    local result = compat.TomTom_AddWaypoint("Test quest", uiMapId, 12, 34, false)
    equal(result, uid, "native waypoint identity returned")
    local args = waypoints[#waypoints]
    equal(args[1], expectedContinent, "waypoint continent")
    equal(args[2], expectedZone, "waypoint zone")
    equal(args[3], x or 12, "waypoint x")
    equal(args[4], y or 34, "waypoint y")
    equal(args[5], "Test quest", "waypoint title")
    equal(args[6], false, "nonpersistent route preserved")
    equal(args.n, 11, "native argument count including nil options")
    for index = 7, 10 do equal(args[index], nil, "optional native arguments") end
    equal(args[11], true, "navigation arrow forced on")
end
for index = 1, 4 do waypoint(1000 + index, index, 1) end
waypoint(947, 0, 0)
waypoint(1414, 1, 0)
waypoint(1415, 2, 0)
waypoint(1945, 3, 0)
waypoint(125, 4, 3)
waypoint(126, 4, 3)
waypoint(9000, 1, 1, 32, 45)
waypoint(9001, 1, 1, 32, 45)
local oldWaypointCount = #waypoints
equal(compat.TomTom_AddWaypoint("Unknown", 8888, 12, 34), nil, "unmapped waypoint skipped")
equal(compat.TomTom_AddWaypoint("Invalid", 9999, 12, 34), nil, "area lookup failure handled")
equal(#waypoints, oldWaypointCount, "invalid maps never reach TomTom")
equal(zoomWrites, oldZoomWrites, "waypoint queries never change map selection")
compat.TomTom_AddWaypoint("Persistent", 1001, 12, 34, true)
equal(waypoints[#waypoints][6], true, "persistent waypoint preserved")
compat.TomTom_AddWaypoint("Default", 1001, 12, 34)
equal(waypoints[#waypoints][6], nil, "default persistence preserved")

-- The adapter must use the actual player's zone while another map is displayed.
local playerMap, playerX, playerY = 1001, 0.125, 0.375
local worldX, worldY
compat.GetCurrentPlayerPosition = function() return playerMap, playerX, playerY end
compat.GetCurrentPlayerMinimapWorldPosition = function() return worldX, worldY end
local function text()
    return {writes = 0, GetText = function(self) return self.value end,
        SetText = function(self, value) self.value = value; self.writes = self.writes + 1 end}
end
local coords = frame()
coords.Player, coords.Cursor = text(), text()
local originalCalls, originalElapsed = 0, 0
local original = function(_, elapsed) originalCalls = originalCalls + 1; originalElapsed = elapsed end
coords:SetScript("OnUpdate", original)
env.TomTomWorldFrame = coords
compat.PatchTomTomWorldCoords()
compat.PatchTomTomWorldCoords()
equal(coords.questieOriginalOnUpdate, original, "repeated patch preserves original handler")
local tomtomHooks = 0
for _, hook in ipairs(hooks) do
    if hook[1] == env.TomTom then tomtomHooks = tomtomHooks + 1 end
end
equal(tomtomHooks, 1, "TomTom visibility method hooked once")
local update = coords:GetScript("OnUpdate")
equal(update, compat.UpdateTomTomWorldCoords, "coordinate adapter installed")
env.WorldMapFrame.visible = true
update(coords, 0.04)
equal(originalCalls, 0, "original coordinate updates throttled")
update(coords, 0.07)
equal(originalCalls, 1, "current zone delegates to original handler")
assert(math.abs(originalElapsed - 0.11) < 0.00001, "original receives accumulated elapsed time")
continent = 2
update(coords, 0.02)
equal(coords.Player.writes, 0, "compat coordinate updates throttled")
update(coords, 0.03)
equal(originalCalls, 1, "browsing another zone uses compatibility coordinates")
equal(coords.Player.value, "Player: 12.5, 37.5", "player coordinates stay in actual zone")
equal(coords.Cursor.value, "Cursor: 25.00, 50.00", "cursor respects map position and UI scale")
update(coords, 0.05)
equal(coords.Player.writes, 1, "unchanged player text is not rewritten")
equal(coords.Cursor.writes, 1, "unchanged cursor text is not rewritten")
cursorX = 10000
update(coords, 0.05)
equal(coords.Cursor.value, "Cursor: ---", "cursor outside map has no coordinates")
cursorX, width = 400, 0
update(coords, 0.05)
equal(coords.Cursor.value, "Cursor: ---", "zero-sized map is handled")
width, scale = 400, 0
update(coords, 0.05)
equal(coords.Cursor.value, "Cursor: ---", "zero UI scale is handled")
scale, playerMap, playerX, playerY = 2, nil, nil, nil
update(coords, 0.05)
equal(coords.Player.value, "Player: ---", "missing player position is handled")
playerMap, playerX, playerY = 1001, 0.125, 0.375
worldX, worldY = 500, 750
compat.HBD = {GetZoneCoordinatesFromWorld = function(_, x, y, mapId, allowOutside)
    equal(x, 500, "world position x")
    equal(y, 750, "world position y")
    equal(mapId, 1001, "world position translated into actual player zone")
    equal(allowOutside, true, "world-to-zone conversion preserves outside allowance")
    return 0.5, 0.25
end}
update(coords, 0.05)
equal(coords.Player.value, "Player: 50.0, 25.0", "world-position conversion retained")
coords.visible = false
local oldPlayerWrites = coords.Player.writes
update(coords, 1)
equal(coords.Player.writes, oldPlayerWrites, "hidden coordinate frame does no work")
coords.visible, env.WorldMapFrame.visible = true, false
update(coords, 0.1)
equal(originalCalls, 2, "hidden world map delegates to original handler")
-- A frame created later may not have an original handler at all.
env.TomTomWorldFrame = nil
compat.PatchTomTomWorldCoords()
local replacement = frame()
replacement.Player, replacement.Cursor = text(), text()
env.TomTomWorldFrame = replacement
compat.PatchTomTomWorldCoords()
compat.PatchTomTomWorldCoords()
equal(replacement.questieOriginalOnUpdate, nil, "repeated patch preserves absent original handler")
env.WorldMapFrame.visible = true
continent = 1
replacement:GetScript("OnUpdate")(replacement, 0.1)
equal(replacement.Player.value, "Player: 50.0, 25.0", "replacement frame updates without original handler")
env.TomTom = nil
compat.PatchTomTomWorldCoords()
equal(coords:GetScript("OnUpdate"), update, "missing TomTom is harmless")
print("TomTom compatibility regressions passed")
