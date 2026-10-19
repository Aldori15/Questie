-- Exercise consolidated faction overrides and helper registrations without UI state.
local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text:gsub("\r\n", "\n")
end
local env = setmetatable({}, {__index = _G})
local modules = {}
local faction = "Alliance"
env.QuestieLoader = {
    ImportModule = function(_, name)
        modules[name] = modules[name] or {}
        return modules[name]
    end,
}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
env.UnitFactionGroup = function() return faction end
local function keys()
    return setmetatable({}, {__index = function(_, key) return key end})
end
modules.QuestieDB = {itemKeys = keys(), npcKeys = keys(), objectKeys = keys(), questKeys = keys(), raceKeys = {NONE = 0}}
modules.QuestieDB.scriptedSpawnSources = {
    [6492] = {STORMWIND_CITY = {{51.32,92.34,0,1,0,2,1519}}, UNDERCITY = {{53.29,74.56,0,1,0,2,1497}}},
    [32823] = {[12] = {{9,8,0,1,0,7,12}}},
}
modules.ZoneDB = {zoneIDs = setmetatable({ELWYNN_FOREST = 12, MULGORE = 215, TEROKKAR_FOREST = 3519},
    {__index = function(_, key) return key end})}
modules.QuestieCorrections = {itemObjectiveFirst = {}, killCreditObjectiveFirst = {},
    questTooltipHints = {}, objectiveTooltipHints = {}, triggerEndTooltipTargets = {}}
local function loadFile(path)
    local source = read(path)
    local func
    if setfenv then
        func = setfenv(assert(loadstring(source, "@" .. path)), env)
    else
        func = assert(load(source, "@" .. path, "t", env))
    end
    func()
end
for _, kind in ipairs({"Item", "NPC", "Object", "Quest"}) do
    loadFile("Database/Corrections/" .. kind .. "RuntimeCorrections.lua")
end
local function apply(kind)
    local result, calls = {}, 0
    modules[kind .. "RuntimeCorrections"]:ApplyFactionFixes(result, function(target, incoming)
        calls = calls + 1
        for id, fields in pairs(incoming) do
            target[id] = target[id] or {}
            for key, value in pairs(fields) do target[id][key] = value end
        end
    end)
    assert(calls == (kind == "Quest" and 1 or 2), kind .. " faction application should be consolidated")
    assert(next(result), kind .. " faction overrides missing")
    return result
end
for _, current in ipairs({"Alliance", "Horde"}) do
    faction = current
    -- Simulate the selected view emitted by the base generator. Deliberately
    -- use an ID absent from the historical lists to catch stale-list fallback.
    modules.QuestieDB.questFactionSelections = {[1947] = {startedBy = {{900001}}}}
    modules.QuestieDB.itemFactionSelections = {[25911] = {objectDrops = {current == "Horde" and 182936 or 182799}}}
    if current == "Horde" then modules.QuestieDB.questFactionSelections[3741] = {reputationReward = {}} end
    local items = apply("Item")
    local npcs = apply("NPC")
    local objects = apply("Object")
    local quests = apply("Quest")
    assert(items[49698].npcDrops[1] == (current == "Horde" and 36669 or 36670))
    local cofferZone = current == "Horde" and "UNDERCITY" or "STORMWIND_CITY"
    assert(objects[103574].zoneID == cofferZone, "consolidation lost a coffer field")
    assert(objects[103574].spawns[cofferZone][1][1] == (current == "Horde" and 53.29 or 51.32),
        "coffer guide did not use the generated Rift Spawn source")
    assert(objects[103574].spawns.STORMWIND_CITY and objects[103574].spawns.UNDERCITY,
        "coffer guide lost a valid source location")
    assert(objects[103574].spawns[cofferZone][1][6] == 2, "coffer phase metadata was lost")
    assert(npcs[34806].spawns[12][1][6] == 7 and npcs[34806].name == "Spirit of Sharing",
        "Spirit of Sharing guide lost source placements or visibility metadata")
    assert(npcs[5676].zoneID == (current == "Horde" and "ORGRIMMAR" or "STORMWIND_CITY"))
    local starters = quests[1947].startedBy[1]
    assert(#starters == 1 and starters[1] == 900001, "generated source selection was replaced by an inherited list")
    assert(quests[687] == nil and quests[737] == nil and quests[1718] == nil
        and quests[1953] == nil and quests[2861] == nil and quests[5050] == nil,
        "retired handwritten starters were reapplied")
    assert(quests[7562] == nil and quests[8254] == nil, "handwritten starter/race overrides returned")
    assert(quests[4738] == nil, "Alliance-only quest received a manual starter")
    assert(quests[9388] == nil and quests[9389] == nil, "disabled quest starters returned")
    assert(items[3713] == nil, "obsolete Soothing Spices relations returned")
    assert(npcs[34907] == nil and npcs[34947] == nil, "source-backed Kvaldir geometry was overwritten")
    assert(npcs[35060] == nil and npcs[35061] == nil and npcs[35071] == nil,
        "player-summoned sharks received unsupported faction placement restrictions")
    assert(npcs[29579] == nil, "Brann's player-relative summon received an unsupported faction location")
    if current == "Horde" then
        assert(npcs[5676].spawns.GHOSTLANDS[1][1] == 27.0, "source Ghostlands Voidwalker summon was omitted")
        assert(npcs[5676].spawns.UNDERCITY[1][1] == 86.65, "Voidwalker guide disagrees with its summon event")
    end
    assert(npcs[6492].spawns == nil, "source Rift Spawn coordinates were replaced")
    assert(npcs[23537] == nil and npcs[26221] == nil and npcs[38340] == nil,
        "source holiday positions/visibility were replaced")
    assert(npcs[16788] == nil, "obsolete Flamekeeper placements returned")
    assert(objects[105174] == nil and objects[186189] == nil and objects[187236] == nil,
        "source object positions were replaced")
    if current == "Horde" then assert(objects[177525] == nil)
    else assert(objects[177525].spawns == nil and objects[177525].zoneID == "DARKSHORE") end
    assert(items[15882] == nil and items[15883] == nil and items[30712] == nil and items[30713] == nil,
        "neutral loot sources were restricted by inherited lists")
    assert(items[25911].objectDrops[1] == (current == "Horde" and 182936 or 182799),
        "source-backed salvage faction access filter was lost")
    assert(objects[201873] == nil and objects[202178] == nil,
        "unverified fixed Gunship chest coordinates returned")
    if current == "Horde" then assert(next(quests[3741].reputationReward) == nil) end
    assert(quests[6681] == nil, "handwritten letter distributors returned")
    npcs[5676].zoneID = -1
    assert(apply("NPC")[5676].zoneID ~= -1, "runtime tables leaked between initializations")
end
modules.QuestieDB.questFactionSelections = nil
local ok, failure = pcall(apply, "Quest")
assert(not ok and tostring(failure):find("regenerate acoreQuestDB.lua", 1, true), "missing generated selections went unnoticed")
modules.QuestieDB.scriptedSpawnSources = nil
ok, failure = pcall(apply, "NPC")
assert(not ok and tostring(failure):find("regenerate acoreNpcDB.lua", 1, true), "missing scripted spawn sources went unnoticed")
local helpers = modules.QuestieCorrections
assert(helpers.itemObjectiveFirst[503] and helpers.itemObjectiveFirst[5088])
assert(helpers.killCreditObjectiveFirst[10503] and helpers.killCreditObjectiveFirst[24507])
for questId, npcId in pairs({[155] = 467, [9212] = 16295, [11241] = 23784}) do
    local target = helpers.triggerEndTooltipTargets[questId][1]
    assert(target[1] == "monster" and target[2] == npcId, "triggerEnd tooltip target lost")
end
assert(helpers.questTooltipHints[12020]:find("Dark Iron", 1, true))
assert(helpers.objectiveTooltipHints[8306][15215]:find("Hive", 1, true))
for _, location in ipairs({1, 2, 3}) do
    local overrides = modules.NPCRuntimeCorrections:LoadDarkmoonFixes(location)
    local zone = ({215, 12, 3519})[location]
    local npc = overrides[10445]
    assert(npc.zoneID == zone and next(npc.waypoints) == nil)
    local point = npc.spawns[zone][1]
    local expected = ({36.9, 41.72, 34.57})[location]
    assert(point[1] == expected, "Darkmoon location changed")
end
print("Runtime correction consolidation tests passed")
