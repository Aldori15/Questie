---@class Sorter
local Sorter = QuestieLoader:ImportModule("Sorter")

--- Sorts the given questIds in place by their level, with lower level quests first.
---@param questIds QuestId[]
---@param questDetails table<QuestId, QuestSortDetails>
function Sorter.byLevel(questIds, questDetails)
    table.sort(questIds, function(questIdA, questIdB)
        local questA = questDetails[questIdA].quest
        local questB = questDetails[questIdB].quest

        if questA.level == questB.level then
            return Sorter.CompareBySuffix(questIdA, questIdB)
        end

        return questA.level < questB.level
    end)
end

--- Sorts the given questIds in place by their level, with higher level quests first.
---@param questIds QuestId[]
---@param questDetails table<QuestId, QuestSortDetails>
function Sorter.byLevelReverse(questIds, questDetails)
    table.sort(questIds, function(questIdA, questIdB)
        local questA = questDetails[questIdA].quest
        local questB = questDetails[questIdB].quest

        if questA.level == questB.level then
            return Sorter.CompareBySuffix(questIdA, questIdB)
        end

        return questA.level > questB.level
    end)
end
