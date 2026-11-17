-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local env = setmetatable({}, {__index = _G})
env._G = env
env.Questie = {db = {profile = {}}}
env.QuestieCompat = {}
env.QUEST_MONSTERS_KILLED, env.QUEST_ITEMS_NEEDED, env.QUEST_OBJECTS_FOUND = "slain", "needed", "found"
local function loadModule(path)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
loadModule("Modules/Libs/QuestieLoader.lua")
local loader = env.QuestieLoader
local db = loader:CreateModule("QuestieDB")
db.questTagIds = {PVP = 1, CLASS = 2, ESCORT = 3, RAID = 4, RAID_10 = 5,
    RAID_25 = 6, DUNGEON = 7, HEROIC = 8, WORLD_EVENT = 9}
loadModule("Modules/Libs/QuestieLib.lua")
local lib = loader:ImportModule("QuestieLib")
local translations = {Quest = "Localized quest", Complete = "Localized complete", Failed = "Localized failed"}
setmetatable(loader:ImportModule("l10n"), {__call = function(_, key) return translations[key] or key end})
env.Questie.Colorize = function(_, text) return text end
local name, quest, state = nil, nil, 0
db.QueryQuestSingle = function(_, field)
    if field == "name" then return name end
    if field == "questLevel" or field == "requiredLevel" then return 10 end
    if field == "requiredMaxLevel" then return 0 end
end
db.GetQuest = function() return quest end
db.IsComplete = function() return state end
db.IsRepeatable, db.IsPvPQuest = function() return false end, function() return false end
loader:ImportModule("QuestieEvent").IsEventQuest = function() return false end
lib.PrintDifficultyColor = function(_, _, text) return text end
lib.GetLevelString = function() return "[10] " end

equal(lib:GetColoredQuestName(900001, false, true), "Localized quest 900001", "missing record with state enabled")
name = ""
equal(lib:GetColoredQuestName(900001, true, true), "[10] Localized quest 900001", "empty name retains level prefix")
name = "Known quest"
equal(lib:GetColoredQuestName(844, false, true), name, "named quest without cached record")
quest = {isComplete = false}
equal(lib:GetColoredQuestName(844, false, true), name, "ordinary incomplete quest")
quest.isComplete = true
equal(lib:GetColoredQuestName(844, false, true), name .. " (Localized complete)", "synthetic completion")
quest, state = nil, 1
equal(lib:GetColoredQuestName(844, false, true), name .. " (Localized complete)", "native completion")
state = -1
equal(lib:GetColoredQuestName(844, false, true), name .. " (Localized failed)", "native failure")
equal(lib:GetColoredQuestName(844, false, false), name, "state suffix disabled")
print("Colored quest names: missing records, localized fallbacks and completion states passed")
