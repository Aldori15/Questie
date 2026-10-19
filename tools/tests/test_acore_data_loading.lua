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
env.bit = {band = function() return 0 end}
env.QuestieCompat = {}
env.Questie = {db = {profile = {isleOfQuelDanasPhase = 1}}}
env.QuestieDB = env.QuestieLoader:ImportModule("QuestieDB")
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
local thread = coroutine.create(function() env.QuestieInit:LoadBaseDB() end)
repeat
    local ok, err = coroutine.resume(thread)
    assert(ok, err)
until coroutine.status(thread) == "dead"
local function noStatic() error("legacy static correction was applied", 2) end
local function empty() return {} end
for _, name in ipairs({"ItemRuntimeCorrections", "NPCRuntimeCorrections",
    "ObjectRuntimeCorrections", "QuestRuntimeCorrections"}) do
    local mod = env.QuestieLoader:ImportModule(name)
    mod.ApplyFactionFixes = empty
end
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
env.QuestieCorrections:Initialize()
equal(db.questData[12541][db.questKeys.parentQuest], 0, "quest zero correction baked into base")
equal(db.npcData[1][db.npcKeys.maxLevel], 80, "NPC max-level correction baked into base")
equal(db.itemData[25][db.itemKeys.npcDrops][1], 19994, "item drop baked into base")
equal(db.objectData[31][db.objectKeys.factionID], 84, "object faction baked into base")
for quest, reward in pairs({[2]=250,[6]=150,[7]=250}) do
    equal(db.questData[quest][db.questKeys.reputationReward][1][2], reward, "quest reputation " .. quest)
end
equal(env.QuestieCorrections.hiddenQuests[13240], false, "cached/fresh blacklist registration")
print("AzerothCore complete-base smoke test passed")
