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
env.QuestieCompat = {C_QuestLog = {}, C_Timer = {}, C_DateAndTime = {}}
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
for id = 1, 3 do
    quests[id] = {[q.name] = "Fixture quest " .. id, [q.requiredLevel] = 1, [q.questLevel] = 10,
        [q.startedBy] = {{npcId}}, [q.finishedBy] = {{npcId}}}
end
quests[2][q.extraObjectives] = {{nil, 1, "Find the event NPC", 0, {{"monster", npcId}}}}
local npcs = {
    [npcId] = {[n.name] = "Silas Darkmoon", [n.spawns] = {[12] = {{10, 20}}}},
    [99] = {[n.name] = "Unrelated NPC", [n.spawns] = {[12] = {{30, 40}}}},
}
local global = env.Questie.db.global
for _, spec in ipairs({{"quest", "quest", quests}, {"npc", "npc", npcs},
    {"object", "obj", {}}, {"item", "item", {}}}) do
    local kind, prefix = spec[1], spec[2]
    global[prefix .. "Bin"], global[prefix .. "Ptrs"] = compiler:CompileTable(
        spec[3], db[kind .. "CompilerTypes"], db[kind .. "CompilerOrder"], db[kind .. "Keys"])
end
local thread = coroutine.create(function() db:Initialize() end)
while coroutine.status(thread) ~= "dead" do
    local ok, message = coroutine.resume(thread); assert(ok, message)
end
modules.QuestieQuest.private.objectiveSpawnListCallTable = {monster = function(id)
    local npc = db:GetNPC(id)
    return {{Id = id, Name = npc.name, Spawns = npc.spawns}}
end}
-- A calendar override is the fallback restored when the bridge loses its live state.
local calendarSpawns = {[12] = {{15, 25}}}
db.npcDataOverrides[npcId] = {[n.spawns] = calendarSpawns}
modules.QuestieWotlkNpcFixes = {LoadDarkmoonFixes = function(_, location)
    return {[npcId] = {[n.spawns] = {[location == 0 and 215 or 12] = {{50 + location, 60}}}}}
end}
loadModule("Database/Corrections/QuestieEvent.lua")
local event = modules.QuestieEvent

-- Load the unmodified guard used by asynchronous objective drawing.
local file = assert(io.open("Modules/Quest/QuestieQuest.lua", "r"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
env.QuestiePlayer = player
local guardSource = assert(source:match("(local function _IsCurrentObjectiveDraw.-\nend)"))
local canDraw = assert(load(guardSource .. "\nreturn _IsCurrentObjectiveDraw", "@QuestieQuest.lua", "t", env))()
local active, ready = db.GetQuest(1), db.GetQuest(3)
player.currentQuestlog[1], player.currentQuestlog[3] = active, ready
local spawnCache = {existingFrame = true}
local objective = {Index = 1, AlreadySpawned = spawnCache, Completed = false}
active.Objectives[1] = objective
active.SpecialObjectives[1] = {Description = "Live special objective", AlreadySpawned = {}}
active.WasComplete = false
local objectives, special = active.Objectives, active.SpecialObjectives
local preview = db.GetQuest(2)
local beforeNPC, unrelatedNPC = db:GetNPC(npcId), db:GetNPC(99)
equal(canDraw(active, objective, spawnCache), true, "objective drawable before refresh")

equal(event.SetServerDarkmoonLocations({0}), true, "live Darkmoon location received")
equal(db.GetQuest(1), active, "refresh preserves accepted quest identity")
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
print("Quest cache invalidation: active identities, live NPC/preview spawns, fallback and stale-draw guards passed")
