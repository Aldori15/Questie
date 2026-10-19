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
    assert(calls == (kind == "Quest" and 2 or 3), kind .. " expansion precedence changed")
    assert(next(result), kind .. " faction overrides missing")
    return result
end
for _, current in ipairs({"Alliance", "Horde"}) do
    faction = current
    local items = apply("Item")
    apply("NPC")
    apply("Object")
    local quests = apply("Quest")
    assert(items[49698].npcDrops[1] == (current == "Horde" and 36669 or 36670))
    local starters = quests[1947].startedBy[1]
    assert(starters[#starters] == (current == "Horde" and 16652 or 17513), "TBC must override Classic starters")
    assert(quests[7562].requiredRaces == 0, "explicit zero race override lost")
    if current == "Horde" then assert(next(quests[3741].reputationReward) == nil) end
    starters[1] = -1
    assert(apply("Quest")[1947].startedBy[1][1] ~= -1, "runtime tables leaked between initializations")
end
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
