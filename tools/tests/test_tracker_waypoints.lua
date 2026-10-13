-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise public tracker calls with the production 3.3.5 TomTom adapter.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
local function noop() end
local names = {"ForgetTomTomTarget", "GetTomTomTarget", "ClearTomTomTarget",
    "ClearTomTomTargetForQuest", "SetTomTomTarget", "SetTomTomTargetToDungeonEntrance"}

local function setup()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local s = {env = env, added = {}, removed = {}, invalid = {}, quests = {}, spawns = {}, uid = 100}
    env.Questie = {started = true, db = {profile = {autoRouteEnabled = true, trackerEnabled = true}, char = {}}, Debug = noop}
    env.debugstack = noop
    env.GetTime = function() return 0 end
    env.QuestLogListScrollFrame = {ScrollBar = {}}
    env.IsInInstance = function() return false end
    env.QuestieCompat = {C_Timer = {}, UiMapData = {[1001] = {mapID = 11}}}
    env.QuestieCompat.GetLegacyMapContinentAndZone = function(uiMapId)
        if uiMapId == 1001 and not s.rejectMap then return 3, 4 end
    end
    loadModule("Modules/Libs/QuestieLoader.lua", env)
    local loader = env.QuestieLoader
    local zone = loader:CreateModule("ZoneDB")
    zone.private = {dungeonLocations = {[900] = {{101, 32, 45}}}}
    zone.GetUiMapIdByAreaId = function(_, areaId) return areaId == 101 and 1001 end
    zone.GetAreaIdByUiMapId = function(_, uiMapId) return uiMapId == 1001 and 101 end
    zone.GetDungeonLocation = function(_, areaId) return zone.private.dungeonLocations[areaId] end
    zone.GetLocalizedDungeonName = function() return s.dungeonName end
    s.dungeonName = "Dungeon"
    loadModule("Compat/TomTom.lua", env)
    env.TomTom = {waypoints = {}, AddWaypoint = noop}
    function env.TomTom:AddZWaypoint(...)
        local args = {n = select("#", ...), ...}
        s.added[#s.added + 1] = args
        s.uid = s.uid + 1
        self.waypoints[s.uid] = {zone = args[2], coord = tostring(args[3]) .. "," .. tostring(args[4]), title = args[5]}
        return s.uid
    end
    function env.TomTom:RemoveWaypoint(uid)
        s.removed[#s.removed + 1] = uid
        self.waypoints[uid] = nil
    end
    function env.TomTom:IsValidWaypoint(uid) return not s.invalid[uid] end
    loadModule("Modules/Tracker/TrackerWaypoints.lua", env)
    loadModule("Modules/Tracker/TrackerUtils.lua", env)
    s.utils = loader:ImportModule("TrackerUtils")
    s.char = env.Questie.db.char
    loader:ImportModule("QuestiePlayer").currentQuestlog = s.quests
    loader:ImportModule("QuestiePlayer").GetPlayerLevel = function() return 80 end
    loader:ImportModule("QuestieQuest").IsQuestTracked = function(_, id) return s.quests[id] ~= nil end
    loader:ImportModule("QuestieLib").GetEffectiveQuestLevel = function() return 80 end
    loader:ImportModule("QuestieMap").GetNearestQuestSpawn = function(_, quest)
        local point = s.spawns[quest.Id]
        if point then return {point.x, point.y}, 101, quest.name, nil, nil, point.distance end
    end
    loadModule("Modules/Tracker/AutoRoute.lua", env)
    s.route = loader:ImportModule("AutoRoute")
    function s.target(id, objective, source)
        s.utils:SetTomTomTarget("Target", 101, 12, 34, id, objective, source)
        return s.char._tom_waypoint
    end
    function s.quest(id, distance)
        s.quests[id] = {Id = id, name = "Quest " .. id, IsComplete = function() return 0 end}
        s.spawns[id] = {x = id, y = 20, distance = distance}
    end
    return s
end

local groups = 0
do
    local s = setup()
    local uid = s.target(10055, 1)
    equal(s.utils:GetTomTomTarget(), uid, "created target resolves through public getter")
    equal(s.char._tom_waypoint_quest.questId, 10055, "quest owner saved")
    equal(s.char._tom_waypoint_quest.objectiveIndex, 1, "objective owner saved")
    equal(s.char._tom_waypoint_source, "manual", "manual source saved")
    equal(s.char._tom_waypoint_identity.title, "Target", "identity saved")
    local call = s.added[1]
    equal(call[1], 3, "area ID mapped to legacy continent")
    equal(call[2], 4, "area ID mapped to legacy zone")
    equal(call[3], 12, "x coordinate preserved")
    equal(call[4], 34, "y coordinate preserved")
    equal(call[6], nil, "manual target keeps default persistence")
    equal(call[11], true, "adapter forces crazy arrow")
    groups = groups + 1
end
do
    local s = setup()
    s.target(10055, nil, "autoRoute")
    equal(s.added[1][6], false, "automatic target is not persisted")
    equal(s.char._tom_waypoint_source, "autoRoute", "automatic source saved")
    groups = groups + 1
end
do
    local s = setup()
    local first = s.target(10055, 1)
    local second = s.target(11515, 2)
    equal(s.removed[1], first, "replacing target removes old owned waypoint")
    equal(s.utils:GetTomTomTarget(), second, "replacement becomes current target")
    equal(s.char._tom_waypoint_quest.questId, 11515, "replacement updates ownership")
    s.utils:ClearTomTomTarget()
    equal(s.removed[2], second, "explicit clear removes current owned waypoint")
    for _, key in ipairs({"_tom_waypoint", "_tom_waypoint_quest", "_tom_waypoint_source", "_tom_waypoint_identity"}) do
        equal(s.char[key], nil, "clear releases saved field: " .. key)
    end
    groups = groups + 1
end
do
    local s = setup()
    local uid = s.target(10055)
    s.utils:ForgetTomTomTarget()
    equal(#s.removed, 0, "forget does not remove a TomTom waypoint")
    assert(s.env.TomTom.waypoints[uid], "forgotten native waypoint remains")
    equal(s.utils:GetTomTomTarget(), nil, "forgotten target no longer resolves")
    groups = groups + 1
end
do
    local s = setup()
    local uid = s.target(10055)
    local ownData = s.env.TomTom.waypoints[uid]
    s.env.TomTom.waypoints[uid] = {zone = 4, coord = ownData.coord, title = "Another player's waypoint"}
    s.env.TomTom.waypoints[200] = ownData
    equal(s.utils:GetTomTomTarget(), 200, "restored waypoint resolves reassigned numeric ID")
    equal(s.char._tom_waypoint, 200, "resolved ID saved")
    s.utils:ClearTomTomTarget()
    equal(s.removed[1], 200, "clear removes restored owned waypoint")
    assert(s.env.TomTom.waypoints[uid], "reused foreign ID survives clear")
    groups = groups + 1
end
for _, field in ipairs({"zone", "coord", "title"}) do
    local s = setup()
    local uid = s.target(10055)
    s.env.TomTom.waypoints[uid][field] = "changed"
    equal(s.utils:GetTomTomTarget(), nil, "identity mismatch: " .. field)
    s.utils:ClearTomTomTarget()
    equal(#s.removed, 0, "identity mismatch never deletes another target")
    groups = groups + 1
end
do
    local s = setup()
    local uid = s.target(10055)
    s.env.TomTom.waypoints.other = s.env.TomTom.waypoints[uid]
    s.invalid[uid] = true
    equal(s.utils:GetTomTomTarget(), nil, "invalid native waypoint rejected; nonnumeric replacements ignored")
    s.env.TomTom.IsValidWaypoint = nil
    equal(s.utils:GetTomTomTarget(), uid, "older TomTom without validity API still supported")
    groups = groups + 1
end
for _, missing in ipairs({"identity", "TomTom", "waypoints"}) do
    local s = setup()
    s.target(10055)
    if missing == "identity" then s.char._tom_waypoint_identity = nil
    elseif missing == "TomTom" then s.env.TomTom = nil
    else s.env.TomTom.waypoints = nil end
    equal(s.utils:GetTomTomTarget(), nil, "missing target metadata/provider: " .. missing)
    s.utils:ClearTomTomTarget()
    equal(#s.removed, 0, "missing provider does not receive removal")
    equal(s.char._tom_waypoint, nil, "missing provider still clears ownership")
    groups = groups + 1
end
for _, owner in ipairs({"quest", "objective", "wholeQuest", "noOwner"}) do
    local s = setup()
    local questId, objectiveIndex = 10055, 1
    if owner == "noOwner" then questId = nil end
    if owner == "wholeQuest" then objectiveIndex = nil end
    local uid = s.target(questId, objectiveIndex)
    if owner == "quest" then s.utils:ClearTomTomTargetForQuest(11515)
    elseif owner == "objective" then s.utils:ClearTomTomTargetForQuest(10055, 2)
    else s.utils:ClearTomTomTargetForQuest(10055, 2) end
    local shouldClear = owner == "wholeQuest"
    if shouldClear then equal(s.char._tom_waypoint, nil, "whole-quest ownership cleared")
    else equal(s.char._tom_waypoint, uid, "different/no ownership retained: " .. owner) end
    equal(#s.removed, shouldClear and 1 or 0, "conditional removal count: " .. owner)
    groups = groups + 1
end
do
    local s = setup()
    s.target(10055, 1)
    s.utils:ClearTomTomTargetForQuest(10055, 1)
    equal(s.char._tom_waypoint, nil, "matching objective clears target")
    s.target(10055, 2)
    s.utils:ClearTomTomTargetForQuest(10055)
    equal(s.char._tom_waypoint, nil, "quest abandonment/turn-in clears any owned objective")
    groups = groups + 1
end
do
    local s = setup()
    s.target(10055)
    s.rejectMap = true
    s.target(11515)
    equal(#s.added, 1, "unmapped zone never reaches native TomTom")
    equal(s.char._tom_waypoint, nil, "failed add does not retain old target")
    equal(s.char._tom_waypoint_quest, nil, "failed add clears quest ownership")
    equal(s.char._tom_waypoint_source, nil, "failed add clears source")
    groups = groups + 1
end
for _, missing in ipairs({"TomTom", "AddWaypoint"}) do
    local s = setup()
    local uid = s.target(10055)
    if missing == "TomTom" then s.env.TomTom = nil else s.env.TomTom.AddWaypoint = nil end
    s.target(11515)
    equal(s.char._tom_waypoint, uid, "unsupported provider leaves existing target untouched")
    equal(#s.removed, 0, "unsupported provider does not replace target")
    groups = groups + 1
end
do
    local s = setup()
    equal(s.utils:SetTomTomTargetToDungeonEntrance(nil), false, "missing dungeon quest rejected")
    equal(s.utils:SetTomTomTargetToDungeonEntrance({zoneOrSort = 999}), false, "unknown dungeon rejected")
    local quest = {Id = 10055, zoneOrSort = 900, name = "Quest"}
    equal(s.utils:SetTomTomTargetToDungeonEntrance(quest), true, "dungeon entrance selected")
    equal(s.added[1][3], 32, "dungeon entrance x")
    equal(s.added[1][4], 45, "dungeon entrance y")
    equal(s.added[1][5], "Dungeon", "localized dungeon title")
    equal(s.char._tom_waypoint_quest.questId, 10055, "dungeon waypoint retains quest owner")
    s.dungeonName = nil
    s.utils:SetTomTomTargetToDungeonEntrance(quest)
    equal(s.added[2][5], "Quest", "missing dungeon title falls back to quest name")
    groups = groups + 1
end

-- AutoRoute continues to use the public TrackerUtils API after extraction.
do
    local s = setup()
    s.quest(10055, 10); s.quest(11515, 20)
    s.route.Update()
    equal(s.char._tom_waypoint_quest.questId, 10055, "AutoRoute selects nearest quest through facade")
    equal(s.char._tom_waypoint_source, "autoRoute", "AutoRoute owns automatic target")
    equal(s.added[1][6], false, "AutoRoute target remains transient")
    s.route.Update()
    equal(#s.added, 1, "unchanged automatic target does not recreate waypoint")
    s.target(11515, 1)
    s.route.Update()
    equal(#s.added, 2, "manual waypoint takes priority over AutoRoute")
    s.route.SetEnabled(false)
    equal(s.char._tom_waypoint_quest.questId, 11515, "disabling AutoRoute preserves manual target")
    groups = groups + 1
end
do
    local s = setup()
    s.quest(10055, 10)
    s.route.Update()
    s.env.Questie.db.profile.trackerEnabled = false
    s.route.Update()
    equal(s.char._tom_waypoint, nil, "disabled tracker releases automatic target")
    groups = groups + 1
end
do
    local s = setup()
    local uid = s.target(10055)
    s.env.TomTom.waypoints[200] = s.env.TomTom.waypoints[uid]
    s.env.TomTom.waypoints[uid] = nil
    s.route.RestoreSavedWaypoint()
    equal(s.char._tom_waypoint, 200, "AutoRoute reload restoration retains reassigned manual waypoint")
    s.target(10055, nil, "autoRoute")
    local removed = #s.removed
    s.route.RestoreSavedWaypoint()
    equal(s.char._tom_waypoint, nil, "reload forgets transient automatic ownership")
    equal(#s.removed, removed, "reload forget does not remove foreign/restored waypoints")
    groups = groups + 1
end

-- The nearest-item keybind must follow the real resolved waypoint owner.
do
    local s = setup()
    local env, loader = s.env, s.env.QuestieLoader
    s.quest(11515, 100); s.quest(11516, 1)
    s.quests[11515].sourceItemId, s.quests[11516].sourceItemId = 34257, 34253
    loader:ImportModule("QuestieDB").QueryItemSingle = function() return 12 end
    env.GetItemCount = function() return 1 end
    env.GetItemSpell = function() return "Use item" end
    env.InCombatLockdown = function() return false end
    env.UIParent = {}
    env.CreateFrame = function()
        local button = {attributes = {}, RegisterForClicks = noop, Hide = noop}
        function button:SetAttribute(key, value) self.attributes[key] = value end
        s.itemButton = button
        return button
    end
    env.QuestieCompat.C_Timer.NewTicker = function(_, callback) s.itemTick = callback end
    loadModule("Modules/Tracker/TrackerNearestQuestItem.lua", env)
    s.target(11515)
    loader:ImportModule("TrackerNearestQuestItem").Initialize()
    equal(s.itemButton.attributes.item, "item:34257", "waypoint owner takes priority over nearer usable item")
    s.utils:ClearTomTomTargetForQuest(11515)
    s.itemTick()
    equal(s.itemButton.attributes.item, "item:34253", "clearing target restores nearest-item selection")
    groups = groups + 1
end

do
    local s = setup()
    local controller = s.env.QuestieLoader:ImportModule("TrackerWaypoints")
    for _, name in ipairs(names) do equal(s.utils[name], controller[name], "existing entry point: " .. name) end
    local count, seen = 0, false
    for line in io.lines("Questie-335.toc") do
        if line == "Modules\\Tracker\\TrackerWaypoints.lua" then count, seen = count + 1, true
        elseif line == "Modules\\Tracker\\TrackerUtils.lua" then equal(seen, true, "waypoint module loads before utility facade") end
    end
    equal(count, 1, "waypoint module registered exactly once")
    groups = groups + 1
end
print("Tracker waypoint regressions passed (" .. groups .. " groups)")
