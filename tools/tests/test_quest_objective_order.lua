-- Run from the addon root with Lua 5.1 or 5.2+.
-- Issue #181: preserve quest-log objective indices through compilation and adaptation.
local env = setmetatable({}, {__index = _G})
env._G, env.unpack, env.tremove = env, unpack or table.unpack, table.remove
env.bit = bit or bit32 or {
    band = function(a, b)
        local result, place = 0, 1
        for _ = 1, 32 do
            if a % 2 == 1 and b % 2 == 1 then result = result + place end
            a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        return result
    end,
    lshift = function(a, n) return (a * 2 ^ n) % 4294967296 end,
    rshift = function(a, n) return math.floor(a / 2 ^ n) end,
}
local function noop() end
env.UnitFactionGroup = function() return "Horde" end
env.GetCVar = function() return "" end
env.InCombatLockdown = function() return false end
env.QuestieCompat = {C_Timer = {}, C_QuestLog = {}, HBD = {}, GetQuestLogIndexByID = function() return 1 end}
env.Questie = {db = {profile = {objectiveFilterDistance = 0}, char = {}, global = {}}, Debug = noop}
env.Questie.Error = function(...) error(table.concat({...}, " "), 2) end
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local function compile(source, label)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end
local function loadModule(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("^\239\187\191", "")
    file:close()
    return compile(source, "@" .. path)()
end
local function run(fn)
    local thread = coroutine.create(fn)
    repeat
        local ok, message = coroutine.resume(thread)
        assert(ok, message)
    until coroutine.status(thread) == "dead"
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
setmetatable(module("l10n"), {__call = function(_, key) return key end})
loadModule("Database/Zones/zoneTables.lua")
module("ZoneDB").zoneIDs = module("ZoneDB").private.zoneIDs
loadModule("Database/QuestieDB.lua")
loadModule("Database/questDB.lua")
loadModule("Database/AzerothCore/acoreQuestDB.lua")
local db, rows = modules.QuestieDB, {}
for _, chunk in ipairs(db.questData) do
    for id, row in pairs(compile(chunk, "@quest source chunk")()) do rows[id] = row end
end
db.questData = rows
loadModule("Modules/QuestieStream.lua")
loadModule("Database/compiler.lua")
loadModule("Modules/Quest/QuestieQuest.lua")
loadModule("Modules/Quest/QuestieQuestPrivates.lua")
local compiler, questModule = modules.DBCompiler, modules.QuestieQuest

-- Valid Lua traversal can visit array indices in any order. Force reverse order
-- for objective lists so the regression does not depend on the host Lua version.
local orderedLists = setmetatable({}, {__mode = "k"})
env.pairs = function(value)
    if orderedLists[value] then
        local index = #value + 1
        return function()
            index = index - 1
            if index > 0 then return index, value[index] end
        end
    end
    return pairs(value)
end
local kinds = {1, 2, 3, 5, 6}
local function mark(objectives)
    for _, kind in ipairs(kinds) do
        local list = objectives[kind]
        if list then
            for index in pairs(list) do
                assert(type(index) == "number" and index >= 1 and index <= #list, "sparse objective list")
            end
            orderedLists[list] = true
        end
    end
end
local function roundTrip(objectives, label)
    mark(objectives)
    local stream = modules.QuestieStreamLib:GetStream("raw")
    compiler.writers.objectives(stream, objectives)
    local binary = stream:Save()
    stream:finished()
    stream = modules.QuestieStreamLib:GetStream("raw")
    stream:Load(binary)
    local restored = compiler.readers.objectives(stream)
    equal(stream._pointer, #binary + 1, label .. " stream boundary")
    stream:finished()
    for _, kind in ipairs(kinds) do
        local source, decoded = objectives[kind] or {}, restored[kind] or {}
        equal(#decoded, #source, label .. " objective count")
        for index, objective in ipairs(source) do
            local field = kind == 5 and 2 or 1
            equal(decoded[index][field], objective[field], label .. " type " .. kind .. " index " .. index)
            if kind ~= 5 then
                equal(decoded[index][2], objective[2], label .. " objective text")
            end
        end
    end
    return restored
end
local checked = 0
for id, row in pairs(rows) do
    local objectives = row[db.questKeys.objectives]
    if objectives then roundTrip(objectives, "quest " .. id); checked = checked + 1 end
end

-- Exercise every ordered category, including spell/kill-credit lists which may
-- currently contain only one entry in the generated database.
local mixed = {}
for _, kind in ipairs(kinds) do
    mixed[kind] = {}
    for index = 1, 3 do
        local id = kind * 100 + index
        mixed[kind][index] = kind == 5 and {{id + 1000}, id} or {id}
    end
end
roundTrip(mixed, "mixed synthetic quest")
local corrections = modules.QuestieCorrections
corrections.hiddenQuests, corrections.itemObjectiveFirst, corrections.killCreditObjectiveFirst = {}, {}, {}
corrections.triggerEndTooltipTargets, corrections.questNPCBlacklist = {}, {}
modules.QuestieLib.GetEffectiveQuestLevel = function() return 36, 32 end
modules.QuestieLib.GetFullObjectiveText = function(value) return value end
modules.QuestieLib.ColorWheel = function() return {} end
modules.QuestieLib.Euclid = function() return 0 end
modules.QuestieAnnounce.ObjectiveChanged = noop
modules.AutoRoute.ScheduleUpdate = noop
modules.TrackerUtils.ClearTomTomTargetForQuest = noop
db.QueryItemSingle = function(id) return "item " .. id end
db.QueryNPCSingle = function(id, key)
    if key == "name" then return "NPC " .. id end
    if key == "spawns" then return {[405] = {{50, 50}}} end
    if key == "rank" then return 0 end
    return {}
end
db.QueryObjectSingle = function(id, key)
    if key == "name" then return "object " .. id end
    if key == "spawns" then return {[405] = {{50, 50}}} end
end
db.GetItem = function() return nil end
db.QueryQuest = function(id) return rows[id] end
db.QueryQuestSingle = function(id, key) return rows[id] and rows[id][db.questKeys[key]] end
db.QuestPointers = rows
local fixture = {name = "Ordered objectives", startedBy = {}, finishedBy = {}, sourceItemId = 0,
    specialFlags = 0, objectives = mixed}
rows[999999] = {}
for key, value in pairs(fixture) do rows[999999][db.questKeys[key]] = value end
local adapted = db.GetQuest(999999)
local index = 0
for _, kind in ipairs(kinds) do
    for _, objective in ipairs(mixed[kind]) do
        index = index + 1
        equal(adapted.ObjectiveData[index][kind == 5 and "RootId" or "Id"],
            objective[kind == 5 and 2 or 1], "adapter objective " .. index)
    end
end

-- Follow the reported quest through the real compiled handle, quest adapter,
-- quest-log updates, tooltip registration, and map-icon population.
local source6143 = rows[6143]
run(function()
    compiler:CompileTableCoroutine({[6143] = source6143}, db.questCompilerTypes,
        db.questCompilerOrder, db.questKeys, "quest", "Quest")
end)
local binary, pointers = env.Questie.db.global.questBin, env.Questie.db.global.questPtrs
local native = {
    {type = "monster", text = "Slitherblade Myrmidon", numFulfilled = 0, numRequired = 7},
    {type = "monster", text = "Slitherblade Naga", numFulfilled = 0, numRequired = 7},
    {type = "monster", text = "Slitherblade Sorceress", numFulfilled = 0, numRequired = 5},
}
modules.QuestLogCache.GetQuest = function() return {isComplete = 0} end
modules.QuestLogCache.GetQuestObjectives = function() return native end
local frames, tooltips = {}, {}
modules.QuestiePlayer.currentQuestlog = {}
modules.QuestieTooltips.RegisterObjectiveTooltip = function(_, _, key, objective) tooltips[key] = objective end
modules.ZoneDB.GetUiMapIdByAreaId = function(_, zone) return zone end
modules.ZoneDB.GetDungeonLocation = noop
modules.Phasing.IsSpawnDataVisible = function() return true end
modules.QuestieIconVisibility.IsEnabledAnywhere = function() return true end
env.QuestieCompat.HBD.GetWorldCoordinatesFromZone = function(_, x, y) return x, y end
modules.QuestieMap.FindClosestStarter = function() return {} end
modules.QuestieMap.IsLootedObjectSpawn = function() return false end
modules.QuestieMap.DrawWorldIcon = function(_, data)
    local frame = {}
    frames[frame] = data
    return frame, {}
end
modules.QuestieFramePool.UnloadFrame = function(_, frame) frames[frame] = nil end
for _, startup in ipairs({"fresh", "cached"}) do
    local handle
    run(function()
        handle = compiler:GetDBHandle(binary, pointers,
            compiler:BuildSkipMap(db.questCompilerTypes, db.questCompilerOrder), db.questKeys, {})
    end)
    db.QueryQuest, db.QueryQuestSingle, db.QuestPointers = handle.Query, handle.QuerySingle, handle.pointers
    db.private.questCache = {}
    local quest = db.GetQuest(6143)
    quest.IsComplete = function() return 0 end
    modules.QuestiePlayer.currentQuestlog[6143] = quest
    questModule:PopulateQuestLogInfo(quest)
    for objectiveIndex, id in ipairs({4714, 4711, 4712}) do
        local objective = quest.Objectives[objectiveIndex]
        equal(objective.Id, id, startup .. " objective target")
        equal(objective.Description, native[objectiveIndex].text, startup .. " objective label")
        run(function() questModule:PopulateObjective(quest, objectiveIndex, objective) end)
        equal(tooltips["m_" .. id], objective, startup .. " tooltip target")
        local found = false
        for _, data in pairs(frames) do
            if data.ObjectiveIndex == objectiveIndex then
                equal(data.ObjectiveTargetId, id, startup .. " map target")
                found = true
            end
        end
        assert(found, startup .. " missing map icon")
    end
    native[2].numFulfilled = 7
    for _, objective in pairs(quest.Objectives) do objective.isUpdated = false end
    questModule:PopulateQuestLogInfo(quest)
    run(function() questModule:PopulateObjective(quest, 2, quest.Objectives[2]) end)
    assert(quest.Objectives[2].Completed, "Naga completion lost")
    assert(not quest.Objectives[1].Completed, "Myrmidon completed by Naga kills")
    for _, data in pairs(frames) do assert(data.ObjectiveTargetId ~= 4711, "completed Naga icon remains") end
    handle.stream:finished()
    native[2].numFulfilled = 0
    frames, tooltips = {}, {}
    db.questData = nil -- The cached pass must not need the raw database.
end
print("PASS: " .. checked .. " quest objective packets retain order; all objective types adapt in order")
print("PASS: quest 6143 tooltips, map targets and completion agree on fresh and cached startup")
