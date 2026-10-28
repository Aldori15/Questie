-- Lua 5.1-compatible: Journey groups fallback quests by endpoint zones and quest ID.
local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a"):gsub("\r\n", "\n"):gsub("^\239\187\191", "")
    file:close()
    return text
end

local function same(actual, expected, label)
    assert(type(actual) == type(expected), label .. ": type mismatch")
    if type(expected) ~= "table" then
        assert(actual == expected, label .. ": value mismatch")
        return
    end
    for key, value in pairs(expected) do same(actual[key], value, label .. "[" .. tostring(key) .. "]") end
    for key in pairs(actual) do assert(expected[key] ~= nil, label .. ": unexpected key " .. tostring(key)) end
end

local function snapshot(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = snapshot(key) .. "=" .. snapshot(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- The three affected quests use their verified current endpoint IDs/zones.
-- Other rows are fixtures for object endpoints, visibility and special sorts.
local quests = {
    [1782] = {zoneOrSort = 0, startedBy = {{5413}}, finishedBy = {{5413}}},
    [3382] = {zoneOrSort = 0, startedBy = {{8380}}},
    [7838] = {zoneOrSort = 0, finishedBy = {{14508}}},
    [13592] = {zoneOrSort = -241, startedBy = {{70001}}, finishedBy = {{70002}}},
    [19000] = {finishedBy = {{70002}}},
    [19001] = {zoneOrSort = -999, startedBy = {[2] = {80001}}, finishedBy = {[2] = {80002}}},
    [19002] = {zoneOrSort = 0, startedBy = {{5413}, {80001}}, finishedBy = {{14508}, {80002}}},
    [19003] = {zoneOrSort = 0, startedBy = {[3] = {99999}}, finishedBy = {{70002}}},
    [19004] = {zoneOrSort = 0, startedBy = {{99998}, {99998}}},
    [19005] = {zoneOrSort = 16, startedBy = {{5413}}},
    [19006] = {zoneOrSort = -81, startedBy = {{5413}}},
    [19007] = {zoneOrSort = 0, startedBy = {{5413}}},
    [19008] = {zoneOrSort = 0, requiredRaces = 99, startedBy = {{5413}}},
    [19009] = {zoneOrSort = 0, requiredClasses = 99, startedBy = {{5413}}},
    [19010] = {zoneOrSort = 1001},
    [19011] = {zoneOrSort = 0, startedBy = {{70003}}},
    [19012] = {zoneOrSort = 0, startedBy = {{[2] = 8380, [7] = 5413}}},
    [19013] = {zoneOrSort = 0, startedBy = {[2] = {80003}}},
}
local npcs = {
    [1] = {spawns = {[9999] = {{1, 1}}}}, -- Poison list indexes: never query these IDs.
    [2] = {spawns = {[9999] = {{2, 2}}}},
    [5413] = {spawns = {[1519] = {{64.62, 37.22}}}},
    [8380] = {spawns = {[16] = {{50, 50}}}},
    [14508] = {spawns = {[33] = {{50, 50}}}},
    [70001] = {spawns = {[1001] = {{50, 50}}}},
    [70002] = {spawns = {[1519] = {{50, 50}}}},
    [70003] = {spawns = {}},
}
local objects = {
    [1] = {spawns = {[9999] = {{1, 1}}}},
    [80001] = {spawns = {[16] = {{50, 50}}}},
    [80002] = {spawns = {[33] = {{50, 50}}}},
    [80003] = {spawns = {[1001] = {{50, 50}}}},
}
local pointers, npcQueries, objectQueries = {}, {}, {}
for id in pairs(quests) do pointers[id] = true end
local modules = {
    ZoneDB = {private = {dungeonParentZones = {[1001] = 1000}}},
    QuestieDB = {
        QuestPointers = pointers,
        sortKeys = {WARRIOR = -81, SPECIAL = -1, SEASONAL = -22},
        QueryQuestSingle = function(id, field) return assert(quests[id], "unknown quest")[field] end,
        QueryNPCSingle = function(id, field)
            assert(field == "spawns")
            npcQueries[id] = true
            return npcs[id] and npcs[id][field]
        end,
        QueryObjectSingle = function(id, field)
            assert(field == "spawns")
            objectQueries[id] = true
            return objects[id] and objects[id][field]
        end,
    },
    QuestiePlayer = {
        HasRequiredRace = function(mask) return mask ~= 99 end,
        HasRequiredClass = function(mask) return mask ~= 99 end,
    },
    QuestieCorrections = {hiddenQuests = {[19007] = true}},
    QuestieEvent = {IsEventQuestInCurrentExpansion = function() return false end},
    l10n = {},
}
local env = setmetatable({QuestieCompat = {C_Map = {}}}, {__index = _G})
env._G = env
env.QuestieLoader = {
    CreateModule = function(_, name) return assert(modules[name], name) end,
    ImportModule = function(_, name) return assert(modules[name], name) end,
}
local source = read("Database/Zones/zoneDB.lua")
if setfenv then
    setfenv(assert(loadstring(source, "@Database/Zones/zoneDB.lua")), env)()
else
    assert(load(source, "@Database/Zones/zoneDB.lua", "t", env))()
end
local zoneDB = modules.ZoneDB
local expected = {
    [1519] = {[1782] = true, [13592] = true, [19000] = true, [19002] = true, [19003] = true, [19012] = true},
    [16] = {[3382] = true, [19001] = true, [19002] = true, [19005] = true, [19012] = true},
    [33] = {[7838] = true, [19001] = true, [19002] = true},
    [1000] = {[13592] = true, [19010] = true, [19013] = true},
    [-81] = {[19006] = true},
}
local original = snapshot({quests, npcs, objects})
local first = zoneDB:RebuildZonesWithQuests()
same(first, expected, "Journey grouping")
assert(not npcQueries[1] and not npcQueries[2] and not objectQueries[1], "endpoint indexes were queried as IDs")
assert(snapshot({quests, npcs, objects}) == original, "grouping mutated database records")

-- Journey's coroutine path must return the same map as synchronous rebuilding.
local thread = coroutine.create(function() return zoneDB:RebuildZonesWithQuests(true) end)
local result, yields = nil, 0
repeat
    local ok, value = coroutine.resume(thread)
    assert(ok, value)
    if coroutine.status(thread) == "dead" then result = value else yields = yields + 1 end
until coroutine.status(thread) == "dead"
assert(yields > 0, "yielding rebuild did not yield")
same(result, expected, "yielding Journey grouping")

-- A rebuilt index drops stale quests, without changing a previously returned map.
pointers[1782] = nil
expected[1519][1782] = nil
same(zoneDB:RebuildZonesWithQuests(), expected, "rebuilt Journey grouping")
assert(first[1519][1782], "rebuilding mutated the previous map")
print("Journey zone fallback: NPC/object IDs, quest keys, parent zones, visibility, sorts and rebuilds passed")
