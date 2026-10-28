-- Run from the addon root with Lua 5.2+.
-- Exercise real compiled handles, quest/NPC caches, the Darkmoon override path,
-- and the objective draw guard. Fixture coordinates stand in for server locations.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local modules = {}
local env = setmetatable({bit = bit32, unpack = table.unpack, tremove = table.remove}, {__index = _G})
env.QuestieLoader = {
    ImportModule = function(_, name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end,
}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
env.UnitFactionGroup = function() return "Alliance" end
env.GetCVar = function() return "" end
env.StaticPopupDialogs = {}
env.Questie = {started = true, Debug = noop, Error = error,
    db = {global = {}, profile = {}, char = {complete = {}, hidden = {}}}}
env.QuestieCompat = {C_QuestLog = {}, C_Timer = {}, C_DateAndTime = {},
    GetQuestTagInfo = function() return 0, "" end}
modules.ZoneDB = {zoneIDs = {ICECROWN = 210}}
modules.l10n = setmetatable({}, {__call = function(_, text) return text end})
modules.QuestieCorrections = {hiddenQuests = {}, itemObjectiveFirst = {}}
modules.AvailableQuests = {RemoveAvailableQuest = noop}
modules.QuestiePlayer = {currentQuestlog = {}, faction = "Alliance",
    HasRequiredRace = function() return true end, HasRequiredClass = function() return true end}
modules.QuestLogCache = {questLog_DO_NOT_MODIFY = {[1] = {isComplete = 0}, [3] = {isComplete = 1}}}
modules.QuestieLib = {GetEffectiveQuestLevel = function() return 10, 1 end,
    TableMemoizeFunction = function(_, fn)
        return setmetatable({}, {__index = function(tbl, key)
            local value = fn(key); tbl[key] = value; return value
        end})
    end}
local function loadModule(path) assert(loadfile(path, "t", env))() end
loadModule("Database/QuestieDB.lua")
for _, name in ipairs({"quest", "npc", "object", "item"}) do loadModule("Database/" .. name .. "DB.lua") end
loadModule("Modules/QuestieStream.lua")
loadModule("Database/compiler.lua")
local db, compiler, player = modules.QuestieDB, modules.DBCompiler, modules.QuestiePlayer
local q, n = db.questKeys, db.npcKeys
local npcId = 14823
local quests = {}
for id = 1, 6 do
    quests[id] = {[q.name] = "Fixture quest " .. id, [q.requiredLevel] = 1, [q.questLevel] = 10,
        [q.startedBy] = {{npcId}}, [q.finishedBy] = {{npcId}}}
end
quests[4][q.startedBy], quests[4][q.finishedBy] = {{99}}, {{99}}
quests[7] = {[q.preQuestSingle] = {1}} -- Correction-only record: pointer, but no base name.
quests[2][q.extraObjectives] = {{nil, 1, "Find the event NPC", 0, {{"monster", npcId}}}}
quests[2][q.objectivesText] = {"Find the fair"}
quests[2][q.specialFlags] = db.specialFlags.REPEATABLE
quests[2][q.startedBy] = {{npcId}, {npcId}, {100}}
local npcs = {
    [npcId] = {[n.name] = "Silas Darkmoon", [n.spawns] = {[12] = {{10, 20}}}},
    [99] = {[n.name] = "Unrelated NPC", [n.spawns] = {[12] = {{30, 40}}}},
}
local objects = {[npcId] = {[db.objectKeys.name] = "Unrelated object sharing the NPC ID",
    [db.objectKeys.spawns] = {[12] = {{70, 80}}}}}
local items = {[100] = {[db.itemKeys.name] = "Darkmoon item", [db.itemKeys.npcDrops] = {npcId, 99}}}
local global = env.Questie.db.global
for _, spec in ipairs({{"quest", "quest", quests}, {"npc", "npc", npcs},
    {"object", "obj", objects}, {"item", "item", items}}) do
    local kind, prefix = spec[1], spec[2]
    global[prefix .. "Bin"], global[prefix .. "Ptrs"] = compiler:CompileTable(
        spec[3], db[kind .. "CompilerTypes"], db[kind .. "CompilerOrder"], db[kind .. "Keys"])
end
local thread = coroutine.create(function() db:Initialize() end)
while coroutine.status(thread) ~= "dead" do
    local ok, message = coroutine.resume(thread); assert(ok, message)
end
assert(db.QuestPointers[7], "correction-only fixture has a real compiled pointer")
equal(db.HasQuestData(7), false, "correction-only fixture is not usable database data")
equal(db.GetQuest(7), nil, "map/lifecycle paths cannot construct correction-only quest objects")
db.private.questCache[7] = {Id = 7, ObjectiveData = {}}
equal(db.GetQuest(7), nil, "cached correction-only objects cannot bypass validity checks")
db.private.questCache[7] = nil
equal(db.GetQuestStartInfo(nil), nil, "starter lookup rejects a missing ID")
equal(db.GetQuestStartInfo(999), nil, "starter lookup rejects unknown quests")
db.private.questStartCache[7] = {Id = 7}
equal(db.GetQuestStartInfo(7), nil, "cached starter cannot bypass nameless-record validation")
db.private.questStartCache[7] = nil
modules.QuestieQuest.private.objectiveSpawnListCallTable = {monster = function(id)
    local npc = db:GetNPC(id)
    return {{Id = id, Name = npc.name, Spawns = npc.spawns}}
end}
-- A calendar override is the fallback restored when the bridge loses its live state.
local calendarSpawns = {[12] = {{15, 25}}}
db.npcDataOverrides[npcId] = {[n.spawns] = calendarSpawns}
modules.NPCRuntimeCorrections = {LoadDarkmoonFixes = function(_, location)
    return {[npcId] = {[n.spawns] = {[location == 0 and 215 or 12] = {{50 + location, 60}}}},
        [99] = {[n.spawns] = {[12] = {{30, 40}}}}}
end}
loadModule("Database/Corrections/QuestieEvent.lua")
local event = modules.QuestieEvent

-- Load the unmodified guard used by asynchronous objective drawing.
local file = assert(io.open("Modules/Quest/QuestieQuest.lua", "r"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
env.QuestiePlayer = player
local guardSource = assert(source:match("(local function _IsCurrentObjectiveDraw.-\nend)"))
local canDraw = assert(load(guardSource .. "\nreturn _IsCurrentObjectiveDraw", "@QuestieQuest.lua", "t", env))()
local starter = db.GetQuestStartInfo(2)
equal(starter.Id, 2, "starter quest ID")
equal(starter.name, "Fixture quest 2", "starter name")
equal(starter.Starts.NPC[1], npcId, "NPC starter")
equal(starter.Starts.GameObject[1], npcId, "object starter")
equal(starter.Starts.Item[1], 100, "item starter")
equal(starter.Description[1], "Find the fair", "starter tooltip description")
equal(starter.level, 10, "starter effective level")
equal(starter.requiredLevel, 1, "starter required level")
equal(starter.IsRepeatable, true, "starter repeatable icon flag")
equal(db.GetQuestStartInfo(2), starter, "starter data is reused")
equal(starter.SpecialObjectives, nil, "starter data does not build special objectives")
equal(starter.Objectives, nil, "starter data does not build objectives")
equal(db.private.questCache[2], nil, "starter lookup does not create a full quest")
equal(next(db.private.npcCache), nil, "starter lookup does not read objective NPC spawns")
equal(db.GetQuestStartInfo(4).IsRepeatable, db.GetQuest(4).IsRepeatable,
    "non-repeatable starter matches full quest behavior")
local active, ready = db.GetQuest(1), db.GetQuest(3)
player.currentQuestlog[1], player.currentQuestlog[3] = active, ready
local spawnCache = {existingFrame = true}
local objective = {Index = 1, AlreadySpawned = spawnCache, Completed = false}
active.Objectives[1] = objective
active.SpecialObjectives[1] = {Description = "Live special objective", AlreadySpawned = {}}
active.WasComplete = false
local objectives, special = active.Objectives, active.SpecialObjectives
local preview = db.GetQuest(2)
equal(preview.Description[1], starter.Description[1], "full and starter descriptions match")
equal(preview.IsRepeatable, starter.IsRepeatable, "full and starter icon flags match")
equal(db.private.questStartCache[2], nil, "full quest replaces its starter cache entry")
equal(db.GetQuestStartInfo(2), preview, "starter lookup reuses a cached full quest")
assert(preview.SpecialObjectives[1].spawnList, "full quest still builds objective spawns")
equal(preview.SpecialObjectives[1].Optional, nil, "unmarked helper remains required")
db.questOptionalExtraObjectives = {[2] = {[1] = true}}
db.private.questCache[2] = nil
preview = db.GetQuest(2)
equal(preview.SpecialObjectives[1].Optional, true, "generated metadata marks compiled helper optional")
db.questOptionalExtraObjectives[2][1] = false
db.private.questCache[2] = nil
equal(db.GetQuest(2).SpecialObjectives[1].Optional, nil, "false metadata cannot mark a helper optional")
db.questOptionalExtraObjectives[2][1] = true
db.questDataOverrides[2] = {[q.extraObjectives] = {{nil, 1, "Required objective", 1, {{"monster", npcId}}}}}
db.private.questCache[2] = nil
equal(db.GetQuest(2).SpecialObjectives[1].Optional, nil, "linked real objective cannot become optional")
db.questOptionalExtraObjectives, db.questDataOverrides[2] = nil, nil
db.private.questCache[2] = nil
preview = db.GetQuest(2)
local beforeStarter = db.GetQuestStartInfo(5)
local beforeNPC, unrelatedNPC = db:GetNPC(npcId), db:GetNPC(99)
equal(canDraw(active, objective, spawnCache), true, "objective drawable before refresh")

equal(event.SetServerDarkmoonLocations({0}), true, "live Darkmoon location received")
assert(db.GetQuestStartInfo(5) ~= beforeStarter, "NPC invalidation clears lightweight previews too")
equal(db.GetQuest(1), active, "refresh preserves accepted quest identity")
equal(db.GetQuestStartInfo(1), active, "starter lookup preserves accepted quest identity")
equal(db.GetQuest(3), ready, "refresh preserves ready-to-turn-in quest identity")
equal(db.GetQuest(1).Objectives, objectives, "refresh preserves objective collection")
equal(db.GetQuest(1).SpecialObjectives, special, "refresh preserves special objective collection")
equal(db.GetQuest(1).WasComplete, false, "refresh preserves completion transition state")
equal(canDraw(db.GetQuest(1), objective, spawnCache), true, "queued objective draw remains valid")
local movedNPC = db:GetNPC(npcId)
assert(movedNPC ~= beforeNPC, "event NPC cache must refresh")
equal(movedNPC.spawns[215][1][1], 50, "NPC uses live coordinates")
equal(db:GetNPC(99), unrelatedNPC, "unrelated NPC cache remains warm")
local livePreview = db.GetQuest(2)
assert(livePreview ~= preview, "inactive quest preview must rebuild")
equal(livePreview.SpecialObjectives[1].spawnList[1].Spawns[215][1][1], 50, "rebuilt preview uses live NPC spawns")
equal(event.SetServerDarkmoonLocations({0}), false, "unchanged locations do not invalidate again")
equal(db.GetQuest(2), livePreview, "unchanged locations preserve cached preview")

equal(event.SetServerDarkmoonLocations({1}), true, "live location changes")
equal(db.GetQuest(1), active, "repeated invalidation preserves active identity")
equal(db:GetNPC(npcId).spawns[12][1][1], 51, "second location updates coordinates")
equal(event.SetServerDarkmoonLocations(nil), true, "bridge fallback restores calendar")
equal(db:GetNPC(npcId).spawns, calendarSpawns, "calendar NPC override restored")
equal(db.GetQuest(1), active, "fallback preserves active identity")
equal(canDraw(db.GetQuest(1), objective, spawnCache), true, "fallback keeps queued draw valid")

player.currentQuestlog[1] = nil
db.InvalidateNPC(npcId)
equal(canDraw(active, objective, spawnCache), false, "abandoned quest cannot draw")
local reaccepted = db.GetQuest(1)
assert(reaccepted ~= active, "quest outside the log is no longer pinned")
equal(next(reaccepted.Objectives), nil, "reaccepted quest starts with fresh objective state")
player.currentQuestlog[1] = reaccepted
db.InvalidateNPC(npcId)
equal(db.GetQuest(1), reaccepted, "new acceptance preserves its new identity")
equal(canDraw(active, objective, spawnCache), false, "old acceptance cannot revive after reaccepting")
player.currentQuestlog = nil
db.InvalidateNPC(npcId)
assert(db.GetQuest(1) ~= reaccepted, "invalidation before player-log initialization clears previews")

-- Exercise the real spawn-list builders, targeted refresh and marker drawing.
-- No phase metadata is present on these ordinary Darkmoon coordinates.
local jobs, frames, unloads = {}, {}, {}
local showObjectives = true
env.coroutine = setmetatable({running = function()
    local running, main = coroutine.running()
    if not main then return running end
end}, {__index = coroutine})
env.QuestieCompat.HBD = {GetWorldCoordinatesFromZone = function(_, x, y) return x, y end}
env.QuestieCompat.GetQuestLogIndexByID = function(id)
    return player.currentQuestlog[id] and id
end
env.Questie.db.profile.objectiveFilterDistance = 0
env.Questie.db.profile.hideUntrackedQuestsMapIcons = true
modules.QuestieCorrections.questNPCBlacklist = {}
modules.QuestieCorrections.questItemBlacklist = {}
modules.QuestieLib.ColorWheel = function() return {} end
modules.QuestieLib.Euclid = function(_, _, _, x, y) return x + y end
modules.ZoneDB.GetUiMapIdByAreaId = function(_, zone) return zone end
modules.ZoneDB.GetDungeonLocation = noop
modules.TrackerUtils = {ClearTomTomTargetForQuest = noop}
modules.AutoRoute = {ScheduleUpdate = noop}
modules.QuestieTracker = {Update = noop}
modules.QuestieCombatQueue = {Queue = function(_, fn) fn() end}
modules.QuestieIconVisibility = {IsEnabledAnywhere = function() return showObjectives end}
modules.Phasing = {IsSpawnDataVisible = function() return true end,
    HasDynamicSpawns = function() error("NPC refresh must not depend on phase metadata") end}
modules.ThreadLib = {ThreadCallbackInstant = function(fn, callback)
    jobs[#jobs + 1] = {thread = coroutine.create(fn), callback = callback}
end}
modules.QuestieTooltips = {lookupByKey = {}, RegisterObjectiveTooltip = noop, RegisterQuestStartTooltip = noop}
modules.QuestieFramePool = {UnloadFrame = function(_, frame)
    for index = #frames, 1, -1 do
        if frames[index] == frame then table.remove(frames, index) end
    end
end}
modules.QuestieMap = {FindClosestStarter = function() return {} end,
    IsLootedObjectSpawn = function() return false end,
    DrawWorldIcon = function(_, data, zone, x, y)
        local frame = {data = data, zone = zone, x = x, y = y}
        frames[#frames + 1] = frame
        return frame, frame
    end,
    UnloadQuestFrames = function(_, id)
        unloads[id] = (unloads[id] or 0) + 1
        for index = #frames, 1, -1 do
            if frames[index].data.Id == id then table.remove(frames, index) end
        end
    end}
loadModule("Modules/Quest/QuestieQuest.lua")
loadModule("Modules/Quest/QuestieQuestPrivates.lua")
local questModule = modules.QuestieQuest
questModule.IsQuestTracked = function(_, id) return id ~= 6 end
local builders = questModule.private.objectiveSpawnListCallTable
db.questDataOverrides[1] = {[q.extraObjectives] = {
    {nil, 123, "Find several sources", 0, {{"monster", npcId}, {"monster", 99}}}}}
player.currentQuestlog = {}
db.InvalidateNPC(npcId)
active, ready = db.GetQuest(1), db.GetQuest(3)
local unaffected, hidden, untracked = db.GetQuest(4), db.GetQuest(5), db.GetQuest(6)
player.currentQuestlog = {[1] = active, [3] = ready, [4] = unaffected, [5] = hidden, [6] = untracked}
env.Questie.db.char.hidden[5] = true
local function makeObjective(quest, id, kind, index)
    local obj = {Id = id, Type = kind, Index = index, Description = "Accepted objective",
        AlreadySpawned = {}, Collected = 2, Needed = 5, Completed = false,
        isUpdated = true, Update = noop, _lastPopulatedCompleted = false}
    obj.spawnList = builders[kind](id, obj)
    quest.Objectives[index] = obj
    return obj
end
objective = makeObjective(active, npcId, "monster", 1)
local objectObjective = makeObjective(active, npcId, "object", 2)
local completedObjective = makeObjective(active, npcId, "monster", 3)
completedObjective.Completed, completedObjective._lastPopulatedCompleted = true, true
local itemObjective = makeObjective(active, 100, "item", 4)
local itemSource, otherItemSource = itemObjective.spawnList[npcId], itemObjective.spawnList[99]
local itemIcon = itemSource.Icon
makeObjective(unaffected, 99, "monster", 1)
makeObjective(hidden, npcId, "monster", 1)
makeObjective(untracked, npcId, "monster", 1)
local extra = active.SpecialObjectives[1]
extra.Index, extra.Update, extra.Completed, extra.AlreadySpawned = 65, noop, false, {}
active.WasComplete, ready.WasComplete, ready.isComplete = false, true, true
local originalObjectives, originalSpecial, originalList = active.Objectives, active.SpecialObjectives, extra.spawnList
local unrelatedSource, objectSource = extra.spawnList[99], objectObjective.spawnList[npcId]
local unrelatedSpawns = unrelatedSource.Spawns
local function drain()
    while #jobs > 0 do
        local job = table.remove(jobs, 1)
        local ok, message = coroutine.resume(job.thread); assert(ok, message)
        if coroutine.status(job.thread) == "dead" then job.callback(true)
        else jobs[#jobs + 1] = job end
    end
end
local function markerX(id, obj, sourceId)
    for _, frame in ipairs(frames) do
        if frame.data.Id == id and frame.data.ObjectiveData == obj
            and (not sourceId or frame.data.ObjectiveTargetId == sourceId) then return frame.x end
    end
end
local function verifyCoordinates(zone, x)
    equal(objective.spawnList[npcId].Spawns[zone][1][1], x, "accepted objective spawn coordinates")
    equal(extra.spawnList[npcId].Spawns[zone][1][1], x, "accepted multi-source extra spawn coordinates")
    equal(completedObjective.spawnList[npcId].Spawns[zone][1][1], x, "completed objective spawn coordinates")
    equal(itemSource.Spawns[zone][1][1], x, "item NPC source spawn coordinates")
    equal(markerX(1, objective), showObjectives and x or nil, "production objective marker coordinates")
    equal(markerX(1, extra, npcId), showObjectives and x or nil, "production special marker coordinates")
    equal(markerX(1, extra, 99), showObjectives and 30 or nil, "unrelated special marker coordinates")
    equal(markerX(1, itemObjective, npcId), showObjectives and x or nil, "production item marker coordinates")
    equal(markerX(3, nil), x, "production finisher marker coordinates")
    equal(markerX(1, completedObjective), nil, "completed objective remains undrawn")
    equal(markerX(5, hidden.Objectives[1]), nil, "manually hidden quest remains undrawn")
    equal(markerX(6, untracked.Objectives[1]), nil, "untracked quest remains undrawn")
    equal(db.GetQuest(1), active, "accepted quest identity across targeted refresh")
    equal(db.GetQuest(3), ready, "ready quest identity across targeted refresh")
    equal(active.Objectives, originalObjectives, "objective collection identity")
    equal(active.SpecialObjectives, originalSpecial, "special collection identity")
    equal(extra.spawnList, originalList, "multi-source collection preserved")
    equal(extra.spawnList[99], unrelatedSource, "unrelated extra source preserved")
    equal(unrelatedSource.Spawns, unrelatedSpawns, "unrelated extra coordinates preserved")
    equal(objectSource.Spawns[12][1][1], 70, "object sharing NPC ID is unaffected")
    equal(extra.spawnList[npcId].Icon, 123, "special objective icon preserved")
    equal(itemObjective.spawnList[99], otherItemSource, "unrelated item source preserved")
    equal(itemSource.ItemId, 100, "item source association preserved")
    equal(itemSource.Icon, itemIcon, "item source icon preserved")
    equal(objective.Collected, 2, "objective progress preserved")
    equal(objective.Needed, 5, "objective goal preserved")
    equal(objective.isUpdated, true, "objective update state preserved")
    equal(objective.Completed, false, "incomplete objective state preserved")
    equal(completedObjective.Completed, true, "completed objective state preserved")
    equal(active.WasComplete, false, "incomplete quest transition state preserved")
    equal(ready.WasComplete, true, "complete quest transition state preserved")
    equal(ready.isComplete, true, "quest completion state preserved")
    equal(env.Questie.db.char.hidden[5], true, "manual hiding preserved")
    equal(unloads[4], nil, "unrelated accepted quest never redrawn")
end
questModule:UpdateObjectiveNotes(active)
questModule:AddFinisher(ready)
drain()
verifyCoordinates(12, 15)
local function move(locations)
    local changed, ids = event.SetServerDarkmoonLocations(locations)
    equal(changed, true, "actual NPC locations changed")
    equal(ids[npcId], true, "changed NPC ID reported")
    equal(ids[99], nil, "unrelated NPC not reported")
    local oldCache = objective.AlreadySpawned
    questModule:RefreshNPCSpawns(ids)
    equal(canDraw(active, objective, oldCache), false, "old queued drawing guard invalidated")
    drain()
end
move({0})
verifyCoordinates(215, 50)
local unchangedCache, redrawCount = objective.AlreadySpawned, unloads[1]
equal(event.SetServerDarkmoonLocations({0}), false, "identical live location is unchanged")
equal(objective.AlreadySpawned, unchangedCache, "unchanged location keeps drawing cache")
equal(unloads[1], redrawCount, "unchanged location does not redraw")
move({1})
verifyCoordinates(12, 51)
move(nil)
verifyCoordinates(12, 15)
-- Even a different bridge location key must not redraw identical coordinates.
move({1})
verifyCoordinates(12, 51)
local loadFixes = modules.NPCRuntimeCorrections.LoadDarkmoonFixes
modules.NPCRuntimeCorrections.LoadDarkmoonFixes = function() return loadFixes(nil, 1) end
unchangedCache, redrawCount = objective.AlreadySpawned, unloads[1]
local changed, ids = event.SetServerDarkmoonLocations({2})
equal(changed, false, "different location key with identical spawns is unchanged")
equal(next(ids), nil, "identical coordinates report no changed NPCs")
equal(objective.AlreadySpawned, unchangedCache, "identical coordinates preserve queued draw cache")
equal(unloads[1], redrawCount, "identical coordinates do not redraw")
-- Zone metadata is cached on the NPC even when its spawn coordinates stay put.
local oldNPC = db:GetNPC(npcId)
local metadataOnlyFixes = loadFixes(nil, 1)
local newZoneID = (db.QueryNPCSingle(npcId, "zoneID") or 12) + 1
metadataOnlyFixes[npcId][n.zoneID] = newZoneID
modules.NPCRuntimeCorrections.LoadDarkmoonFixes = function() return metadataOnlyFixes end
changed, ids = event.SetServerDarkmoonLocations({3})
equal(changed, true, "zone metadata alone reports a change")
equal(ids[npcId], true, "zone metadata change reports affected NPC")
equal(ids[99], nil, "zone metadata change excludes unchanged NPC")
local updatedNPC = db:GetNPC(npcId)
assert(updatedNPC ~= oldNPC, "zone metadata change invalidates cached NPC")
equal(updatedNPC.zoneID, newZoneID, "rebuilt NPC uses updated zone metadata")
questModule:RefreshNPCSpawns(ids)
drain()
verifyCoordinates(12, 51)
unchangedCache, redrawCount = objective.AlreadySpawned, unloads[1]
equal(event.SetServerDarkmoonLocations({3}), false, "repeated zone metadata is unchanged")
changed, ids = event.SetServerDarkmoonLocations({4})
equal(changed, false, "different location key with identical zone metadata is unchanged")
equal(next(ids), nil, "identical zone metadata reports no changed NPCs")
equal(db:GetNPC(npcId), updatedNPC, "identical zone metadata preserves NPC cache")
equal(objective.AlreadySpawned, unchangedCache, "identical zone metadata preserves drawing cache")
equal(unloads[1], redrawCount, "identical zone metadata does not redraw")
modules.NPCRuntimeCorrections.LoadDarkmoonFixes = loadFixes
showObjectives = false
move({0})
verifyCoordinates(215, 50)
showObjectives = true
move(nil)
verifyCoordinates(12, 15)
-- A real objective draw suspended while preparing coordinates must stop after
-- the NPC refresh replaces its drawing cache, before drawing obsolete icons.
local manySpawns = {}
for index = 1, 61 do manySpawns[index] = {15 + index / 100, 25} end
objective.spawnList[npcId].Spawns = {[12] = manySpawns}
objective.AlreadySpawned = {}
local pausedDraw = coroutine.create(function() questModule:PopulateObjective(active, 1, objective) end)
local ok, message = coroutine.resume(pausedDraw); assert(ok, message)
equal(coroutine.status(pausedDraw), "suspended", "production objective preparation yields")
changed, ids = event.SetServerDarkmoonLocations({0})
questModule:RefreshNPCSpawns(ids)
local frameCount = #frames
ok, message = coroutine.resume(pausedDraw); assert(ok, message)
equal(coroutine.status(pausedDraw), "dead", "superseded objective draw stops")
equal(#frames, frameCount, "superseded objective draw adds no obsolete markers")
drain()
verifyCoordinates(215, 50)
-- Removing an acceptance before asynchronous cleanup completes cannot revive it.
changed, ids = event.SetServerDarkmoonLocations({1})
questModule:RefreshNPCSpawns(ids)
player.currentQuestlog[1] = nil
drain()
equal(markerX(1, objective), nil, "asynchronous refresh cannot redraw abandoned acceptance")
print("Quest cache invalidation: active identities, real NPC/objective/special/finisher coordinates, visibility, unchanged locations and stale-draw guards passed")
