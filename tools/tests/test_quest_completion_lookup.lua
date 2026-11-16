-- Run with Lua 5.2+. Exercise the real completion lookup and source-item fallback.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({bit = bit32}, {__index = _G})
local modules, bagItem, bagReads, sourceChecks, countReads = {}, nil, 0, 0, 0
env.UnitFactionGroup = function() return "Alliance" end
env.Questie = {db = {profile = {}}, Debug = function() end}
env.LibStub = function() return {} end
env.GetItemCount = function(itemId, includeBank)
    equal(includeBank, false, "source-item ownership excludes the bank")
    countReads = countReads + 1
    return itemId == bagItem and 1 or 0
end
env.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
env.QuestieCompat = {C_QuestLog = {}, C_Timer = {},
    GetContainerItemInfo = function(_, slot)
        bagReads = bagReads + 1
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, slot == 1 and bagItem or nil
    end}
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
}
modules.ZoneDB = {zoneIDs = {ICECROWN = 210}}
modules.QuestLogCache = {questLog_DO_NOT_MODIFY = {}}
modules.QuestLogCache.TryGetQuest = function(id) return modules.QuestLogCache.questLog_DO_NOT_MODIFY[id] end
env.QuestieCompat.GetQuestLogIndexByID = function(id)
    if modules.QuestLogCache.TryGetQuest(id) then return 1 end
end
modules.QuestieLib = {ColorWheel = function() return {} end}
assert(loadfile("Database/QuestieDB.lua", "t", env))()
assert(loadfile("Modules/Quest/QuestieQuest.lua", "t", env))()
local db, questModule, log = modules.QuestieDB, modules.QuestieQuest, modules.QuestLogCache.questLog_DO_NOT_MODIFY
local quests = {
    [1] = {Id = 1, sourceItemId = 100, ObjectiveData = {}},
    [2] = {Id = 2, sourceItemId = 0, ObjectiveData = {}},
    [3] = {Id = 3, sourceItemId = 101, ObjectiveData = {}},
}
db.GetQuest = function(id) return quests[id] end
db.QueryItemSingle = function(id, field)
    if field == "startQuest" and id == 101 then return 3 end
    if field == "name" then return "Source item " .. id end
end
questModule.GetAllLeaderBoardDetails = function() return {} end
local checkSourceItem = questModule.CheckQuestSourceItem
questModule.CheckQuestSourceItem = function(self, ...)
    sourceChecks = sourceChecks + 1
    return checkSourceItem(self, ...)
end

-- Missing log entries and known states never need an inventory scan, regardless
-- of objective presence or whether a source item is in the bags.
equal(db.IsComplete(999), 0, "missing log entry")
for _, present in ipairs({false, true}) do
    bagItem = present and 100 or nil
    for _, status in ipairs({-1, 0, 1}) do
        for _, objectives in ipairs({{}, {{finished = false}}}) do
            log[1] = {isComplete = status, objectives = objectives}
            for _ = 1, 100 do equal(db.IsComplete(1), status, "cached status " .. status) end
        end
    end
end
equal(sourceChecks, 0, "1,200 known-status lookups skip the source-item helper")
equal(bagReads, 0, "known-status lookups perform no bag reads")
equal(countReads, 0, "known-status lookups perform no inventory counts")

-- An unknown status with a client objective remains incomplete without scanning.
log[1] = {objectives = {{finished = false}}}
equal(db.IsComplete(1), 0, "objective fallback remains incomplete")
equal(sourceChecks, 0, "objective fallback skips the source-item helper")

-- Empty-objective fallback remains live: acquiring/removing the source item must
-- immediately change the result, without caching the inventory decision.
log[1] = {objectives = {}}
bagItem = nil
equal(db.IsComplete(1), 0, "missing required source item")
bagItem = 100
equal(db.IsComplete(1), 1, "acquired source item")
bagItem = nil
equal(db.IsComplete(1), 0, "removed source item")
equal(sourceChecks, 3, "each empty-objective fallback checks the live source item")
equal(countReads, 3, "each required fallback performs one inventory count")
equal(bagReads, 0, "required fallback never scans bag slots")
log[2] = {objectives = {}}
equal(db.IsComplete(2), 1, "empty-objective quest without a source item")

-- Consumed quest-start items and explicit missing-item objectives retain their
-- production behavior; the completion lookup does not alter these callers.
log[3] = {objectives = {}}
local before = countReads
equal(db.IsComplete(3), 1, "consumed starting item is not required")
equal(countReads, before, "consumed starting item skips inventory count")
quests[3].ObjectiveData = {{Type = "item", Id = 101}}
equal(db.IsComplete(3), 0, "starting item also used as an objective is required")
equal(questModule:CheckQuestSourceItem(1, true), false, "explicit missing-item check remains available")
equal(quests[1].Objectives[1].Id, 100, "explicit caller still creates the missing-item objective")
bagItem = 100
equal(questModule:CheckQuestSourceItem(1, true), true, "explicit caller sees acquired source item")

bagItem, quests[1].Objectives = nil, nil
log[1] = nil
equal(questModule:CheckQuestSourceItem(1, true), false, "removed quest still reports missing source item")
equal(quests[1].Objectives, nil, "removed cache entry cannot recreate an objective")
log[1] = {objectives = {}}
local getQuestIndex = env.QuestieCompat.GetQuestLogIndexByID
env.QuestieCompat.GetQuestLogIndexByID = function() end
equal(questModule:CheckQuestSourceItem(1, true), false, "removed live quest still reports missing source item")
equal(quests[1].Objectives, nil, "stale cache entry cannot recreate an objective")
env.QuestieCompat.GetQuestLogIndexByID = getQuestIndex
bagItem = 100

-- Preserve the old expression's results even for a false status/first objective.
log[1] = {isComplete = false, objectives = {}}
equal(db.IsComplete(1), 1, "false status uses live fallback")
log[1] = {objectives = {false}}
equal(db.IsComplete(1), 1, "nonempty false objective preserves legacy fallback")
print("Quest completion lookup: cached states, zero unnecessary bag reads, live source items, consumed starters and explicit missing-item objectives passed")
