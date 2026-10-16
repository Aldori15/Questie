-- Run from the addon root with Lua 5.1 or 5.2+.
-- Load actual generated files before their schemas, then exercise the production
-- correction initializer and registry with conflicting expansion-fix fixtures.
local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n"):gsub("^\239\187\191", "")
    file:close()
    return source
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
env.QuestieLoader = {
    ImportModule = function(_, name)
        modules[name] = modules[name] or {}
        return modules[name]
    end,
    StampLoadBoundary = function() end,
}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
local function compile(source, label)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end
local function loadModule(path) compile(read(path), "@" .. path)() end
local function loadEnum(path, declaration)
    local pattern = declaration:gsub("(%W)", "%%%1") .. " = %b{}"
    compile(assert(read(path):match(pattern), "missing enum: " .. declaration), "@" .. path)()
end
env.QuestieCompat = {}
env.QuestieDB = env.QuestieLoader:ImportModule("QuestieDB")
env.QuestieProfessions = env.QuestieLoader:ImportModule("QuestieProfessions")
env.QuestieCorrections = env.QuestieLoader:ImportModule("QuestieCorrections")
env.Questie = {db = {profile = {isleOfQuelDanasPhase = 0}}}
local compatSource = read("Compat/Compat.lua")
local registry = assert(compatSource:match("(local correctionsRegistry = {}.-)\nfunction QuestieCompat:ADDON_LOADED"))
compile(registry, "@Compat/Compat.lua")()
loadModule("Compat/Corrections.lua")
local manifest = read("Database/AzerothCore/AzerothCore.xml")
local fileCount = 0
for name in manifest:gmatch('<Script file="([^"]+)"') do
    loadModule("Database/AzerothCore/" .. name)
    fileCount = fileCount + 1
end
equal(fileCount, 6, "all generated files loaded")
equal(env.QuestieDB.questKeys, nil, "correction callbacks defer schema access")
equal(env.QuestieCompat.AzerothCoreReputationRates[1090][1], 1.3, "reputation data available before consumers")
equal(env.QuestieCompat.AzerothCoreQuestAvailabilityConditions[308][1][1][2], 310, "availability data available before consumers")

for _, name in ipairs({"quest", "npc", "item", "object"}) do
    loadModule("Database/" .. name .. "DB.lua")
end
for _, name in ipairs({"raceKeys", "classKeys", "specialFlags"}) do
    loadEnum("Database/QuestieDB.lua", "QuestieDB." .. name)
end
loadEnum("Modules/QuestieProfessions.lua", "QuestieProfessions.professionKeys")
loadModule("Database/Zones/zoneTables.lua")
local zone = modules.ZoneDB
zone.zoneIDs = zone.private.zoneIDs
local db = env.QuestieDB
for _, name in ipairs({"quest", "npc", "item", "object"}) do
    db[name .. "Data"] = {}
    db[name .. "DataOverrides"] = {}
end

-- Real base rewards must survive without the retired Classic reputation layer.
local baseQuestSource = read("Database/Wotlk/wotlkQuestDB.lua")
for _, questId in ipairs({2, 6, 7}) do
    local row = assert(baseQuestSource:match("\n%[" .. questId .. "%] = (%b{})"), "missing base quest: " .. questId)
    db.questData[questId] = compile("return " .. row, "@base quest " .. questId)()
end

local function empty() return {} end
for _, name in ipairs({"QuestieQuestFixes", "QuestieNPCFixes",
    "QuestieItemFixes", "QuestieObjectFixes", "QuestieTBCQuestFixes", "QuestieTBCNpcFixes",
    "QuestieTBCItemFixes", "QuestieTBCObjectFixes", "QuestieWotlkQuestFixes", "QuestieWotlkNpcFixes",
    "QuestieWotlkItemFixes", "QuestieWotlkObjectFixes", "QuestieItemStartFixes", "QuestieQuestBlacklist",
    "QuestieNPCBlacklist", "QuestieItemBlacklist"}) do
    local module = env.QuestieLoader:ImportModule(name)
    for _, method in ipairs({"Load", "LoadFactionFixes", "LoadAutomatics", "LoadReverseLinkFixes",
        "LoadReverseStartQuestFixes", "LoadAutomaticQuestStarts", "LoadAutoBlacklistWotlk"}) do
        module[method] = empty
    end
end
modules.QuestieWotlkQuestFixes.Load = function() return {[12541] = {[db.questKeys.parentQuest] = 999}} end
modules.QuestieWotlkNpcFixes.Load = function() return {[1] = {[db.npcKeys.maxLevel] = 1}} end
modules.QuestieWotlkItemFixes.Load = function() return {[25] = {[db.itemKeys.npcDrops] = {1}}} end
modules.QuestieWotlkObjectFixes.Load = function() return {[31] = {[db.objectKeys.factionID] = 1}} end
modules.IsleOfQuelDanas = {MAX_ISLE_OF_QUEL_DANAS_PHASES = 4}
local applyRegistered = env.QuestieCompat.LoadCorrections
local applied = false
env.QuestieCompat.LoadCorrections = function(...)
    equal(db.questData[12541][db.questKeys.parentQuest], 999, "expansion quest correction applied first")
    equal(db.npcData[1][db.npcKeys.maxLevel], 1, "expansion NPC correction applied first")
    equal(db.itemData[25][db.itemKeys.npcDrops][1], 1, "expansion item correction applied first")
    equal(db.objectData[31][db.objectKeys.factionID], 1, "expansion object correction applied first")
    applied = true
    return applyRegistered(...)
end
loadModule("Database/Corrections/QuestieCorrections.lua")
env.QuestieCorrections:Initialize()
equal(applied, true, "production initializer applied registered data")
equal(db.questData[12541][db.questKeys.parentQuest], 0, "AzerothCore zero override wins")
equal(db.npcData[1][db.npcKeys.maxLevel], 80, "AzerothCore NPC override wins")
equal(db.itemData[25][db.itemKeys.npcDrops][1], 19994, "AzerothCore item override wins")
equal(db.objectData[31][db.objectKeys.factionID], 84, "AzerothCore object override wins")
equal(db.questData[2][db.questKeys.reputationReward][1][2], 250, "Sharptalon's Claw reputation stays correct")
equal(db.questData[6][db.questKeys.reputationReward][1][2], 150, "Bounty on Garrick Padfoot reputation stays correct")
equal(db.questData[7][db.questKeys.reputationReward][1][2], 250, "Kobold Camp Cleanup reputation stays correct")
equal(env.QuestieCorrections.hiddenQuests[13240], false, "compatibility blacklist survives registration")
print("AzerothCore data loading regression tests passed")
