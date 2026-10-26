-- Load generated bases through the production loader; run from the addon root.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"):gsub("^\239\187\191", "")
    f:close()
    return source
end
local function equal(actual, expected, name)
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
env.QuestieLoader = {
    ImportModule = function(_, name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end,
    StampLoadBoundary = function() end,
}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
local function compile(source, label)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end
local function load(path) compile(read(path), "@" .. path)() end
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
env.QuestieCompat = {}
env.Questie = {
    db = {profile = {isleOfQuelDanasPhase = 1}, global = {}},
    Debug = function() end,
    Error = function(message) error(message, 2) end,
}
env.QuestieDB = env.QuestieLoader:ImportModule("QuestieDB")
env.UnitFactionGroup = function() return "Alliance" end
env.QuestieProfessions = env.QuestieLoader:ImportModule("QuestieProfessions")
env.QuestieCorrections = env.QuestieLoader:ImportModule("QuestieCorrections")
local registry = assert(read("Compat/Compat.lua"):match(
    "(local correctionsRegistry = {}.-)\nfunction QuestieCompat:ADDON_LOADED"))
compile(registry, "@Compat/Compat.lua")()
load("Compat/Corrections.lua")
local manifest = read("Database/AzerothCore/AzerothCore.xml")
local count = 0
for name in manifest:gmatch('<Script file="([^"]+)"') do
    load("Database/AzerothCore/" .. name)
    count = count + 1
end
equal(count, 2, "only server runtime metadata in early XML")
equal(env.QuestieCompat.AzerothCoreReputationRates[1090][1], 1.3, "reputation rates")
equal(env.QuestieCompat.AzerothCoreQuestAvailabilityConditions[308][1][1][2], 310, "availability")
for _, kind in ipairs({"item", "npc", "object", "quest"}) do
    load("Database/AzerothCore/acore" .. kind:sub(1,1):upper() .. kind:sub(2) .. "DB.lua")
end
for _, kind in ipairs({"quest", "npc", "item", "object"}) do
    load("Database/" .. kind .. "DB.lua")
end
local function enum(declaration)
    local pattern = declaration:gsub("(%W)", "%%%1") .. " = %b{}"
    compile(assert(read("Database/QuestieDB.lua"):match(pattern), declaration), "@QuestieDB enum")()
end
for _, name in ipairs({"raceKeys", "classKeys", "specialFlags"}) do
    enum("QuestieDB." .. name)
end
local prof = read("Modules/QuestieProfessions.lua")
compile(assert(prof:match("QuestieProfessions%.professionKeys = %b{}")), "@prof enum")()
load("Database/Zones/zoneTables.lua")
modules.ZoneDB.zoneIDs = modules.ZoneDB.private.zoneIDs
local db = env.QuestieDB
for _, kind in ipairs({"quest", "npc", "object", "item"}) do
    local raw = assert(db[kind .. "Data"], kind .. " raw source missing")
    assert(type(raw) == "table" and raw.__questieSourceChunks, kind .. " base should contain independent source chunks")
    db[kind .. "DataOverrides"] = {}
end
-- Use the production loader so source-chunk handling matches the client.
env.QuestieInit = env.QuestieLoader:ImportModule("QuestieInit")
env.coYield = coroutine.yield
env.loadstring = function(source, label) return compile(source, label) end
local baseLoader = assert(read("Modules/QuestieInit.lua"):match(
    "(function QuestieInit:LoadDatabase%(key%).-)\nfunction _QuestieInit.StartStageCoroutine"))
compile(baseLoader, "@QuestieInit base loader")()
local function run(fn)
    local thread = coroutine.create(fn)
    repeat
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
    until coroutine.status(thread) == "dead"
end
local function noStatic() error("legacy static correction was applied", 2) end
local function empty() return {} end
for _, name in ipairs({"ItemRuntimeCorrections", "NPCRuntimeCorrections",
    "ObjectRuntimeCorrections", "QuestRuntimeCorrections"}) do
    local mod = env.QuestieLoader:ImportModule(name)
    mod.ApplyFactionFixes = empty
end
-- Runtime helper behavior is covered by test_runtime_corrections.lua.
modules.QuestRuntimeCorrections.LoadEventTooltipTargets = empty
for _, name in ipairs({"QuestieQuestBlacklist", "QuestieNPCBlacklist", "QuestieItemBlacklist"}) do
    local mod = env.QuestieLoader:ImportModule(name)
    for _, method in ipairs({"Load", "LoadAutomatics", "LoadReverseLinkFixes",
        "LoadReverseStartQuestFixes"}) do
        mod[method] = noStatic
    end

    -- Blacklist Load() methods are runtime initialization,
    -- not obsolete static database corrections.
    if name == "QuestieQuestBlacklist"
        or name == "QuestieNPCBlacklist"
        or name == "QuestieItemBlacklist" then
        mod.Load = empty
    end

    mod.LoadAutoBlacklistWotlk = empty
end
-- MinimalInit receives blank static blacklist modules and the real Compat
-- callback still contributes intentional true/false Questie blacklist entries.
modules.IsleOfQuelDanas = {MAX_ISLE_OF_QUEL_DANAS_PHASES = 9}
env.QuestieCompat.LoadCorrections = noStatic
load("Database/Corrections/QuestieCorrections.lua")
-- Exercise the real pre-compilation startup path. Locale/UI work and waypoint
-- optimization have separate tests; source loading and corrections remain real.
modules.Townsfolk = {Initialize = function() end}
modules.l10n = setmetatable({Initialize = function() end}, {
    __call = function(_, text) return text end,
})
env.QuestieCorrections.PreCompile = function() end
local fullLoader = assert(read("Modules/QuestieInit.lua"):match(
    "(local function loadFullDatabase%(%)%s.-)\nlocal function runValidator"))
local initialize = compile('local QuestieInit, QuestieCorrections = QuestieLoader:ImportModule("QuestieInit"), QuestieLoader:ImportModule("QuestieCorrections")\n'
    .. 'local Townsfolk, l10n = QuestieLoader:ImportModule("Townsfolk"), QuestieLoader:ImportModule("l10n")\n'
    .. 'local coYield = coroutine.yield\n' .. fullLoader .. '\nreturn loadFullDatabase',
    "@QuestieInit full database loader")()
run(initialize)
equal(db.questData[12541][db.questKeys.parentQuest], 0, "quest zero correction baked into base")
equal(db.npcData[1][db.npcKeys.maxLevel], 80, "NPC max-level correction baked into base")
equal(db.itemData[25][db.itemKeys.npcDrops][1], 19994, "item drop baked into base")
equal(db.objectData[31][db.objectKeys.factionID], 84, "object faction baked into base")
for quest, reward in pairs({[2]=250,[6]=150,[7]=250}) do
    equal(db.questData[quest][db.questKeys.reputationReward][1][2], reward, "quest reputation " .. quest)
end
equal(env.QuestieCorrections.hiddenQuests[13240], false, "cached/fresh blacklist registration")

-- Resource coordinates must survive startup, binary compilation and a cached
-- handle reload. Source-only snapshots stop too early to catch destructive pruning.
local resourceIds = {
    1617, 1618, 1619, 1620, 1621, 1622, 1623, 1624, 1628,
    1731, 1732, 1733, 1734, 1735, 123848, 150082, 175404,
    176643, 177388, 324, 150079, 176645, 2040, 123310,
}
local objects, expected = {}, {}
for _, id in ipairs(resourceIds) do
    local row = assert(db.objectData[id], "resource object missing: " .. id)
    local spawns = assert(row[db.objectKeys.spawns], "startup removed resource coordinates: " .. id)
    assert(next(spawns), "resource coordinates empty: " .. id)
    objects[id], expected[id] = row, spawns
end
local rootSources = {[3724] = true, [3725] = true, [3726] = true,
    [3727] = true, [3729] = true, [3730] = true}
for _, id in pairs(db.itemData[5056][db.itemKeys.objectDrops]) do
    assert(rootSources[id], "Root Samples gained an unrelated herb source: " .. id)
    rootSources[id] = nil
end
assert(next(rootSources) == nil, "Root Samples lost a Barrens herb source")
equal(db.questData[866][db.questKeys.objectives][3][1][1], 5056, "Root Samples item objective")

env.unpack = unpack or table.unpack
env.tremove = table.remove
env.GetCVar = function() return "" end
env.InCombatLockdown = function() return false end
load("Modules/QuestieStream.lua")
load("Database/compiler.lua")
local compiler = modules.DBCompiler
run(function()
    compiler:CompileTableCoroutine(objects, db.objectCompilerTypes, db.objectCompilerOrder,
        db.objectKeys, "obj", "Object")
end)
local binary, pointers = assert(env.Questie.db.global.objBin), assert(env.Questie.db.global.objPtrs)
local function pointKey(point, source)
    -- Source coordinates are quantized down; decoded coordinates must recover
    -- that integer pair. Normalize omitted metadata to the compiler's zeros.
    local rounding = source and 0 or 0.5
    local fields = {math.floor(point[1] * 40.90 + rounding), math.floor(point[2] * 40.90 + rounding)}
    for index = 3, 8 do fields[index] = point[index] or 0 end
    return table.concat(fields, ":")
end
local function verifyHandle()
    local handle
    run(function()
        handle = compiler:GetDBHandle(binary, pointers,
            compiler:BuildSkipMap(db.objectCompilerTypes, db.objectCompilerOrder),
            db.objectKeys, db.objectDataOverrides)
    end)
    for id, zones in pairs(expected) do
        local spawns = assert(handle.QuerySingle(id, "spawns"), "compiled resource coordinates missing: " .. id)
        for zone in pairs(spawns) do
            assert(zones[zone], "compiled resource gained an unexpected zone: " .. id .. "/" .. zone)
        end
        for zone, points in pairs(zones) do
            equal(#assert(spawns[zone]), #points, "compiled resource coordinate count: " .. id)
            -- The production writer traverses points with pairs(), so their
            -- serialized order is unspecified. Compare a duplicate-aware set.
            local remaining = {}
            for _, point in ipairs(points) do
                local key = pointKey(point, true)
                remaining[key] = (remaining[key] or 0) + 1
            end
            for _, point in ipairs(spawns[zone]) do
                local key = pointKey(point, false)
                local count = remaining[key]
                assert(count and count > 0,
                    "compiled resource coordinate/metadata changed: " .. id .. "/" .. zone .. " " .. key)
                remaining[key] = count > 1 and count - 1 or nil
            end
            assert(next(remaining) == nil, "compiled resource lost a coordinate: " .. id .. "/" .. zone)
        end
    end
    handle.stream:finished()
end
verifyHandle()
db.objectData = nil -- Cached startup must work without the raw object table.
env.QuestieCorrections:MinimalInit()
verifyHandle()
print("Gathering coordinates survive startup, compilation and cached reload; Root Samples sources preserved")
print("AzerothCore complete-base smoke test passed")
