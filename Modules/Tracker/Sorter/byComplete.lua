---@class Sorter
local Sorter = QuestieLoader:ImportModule("Sorter")

--- Sorts the given questIds in place by their completion status, with completed quests first.
---@param questIds QuestId[]
---@param questDetails table<QuestId, QuestSortDetails>
function Sorter.byComplete(questIds, questDetails)
    table.sort(questIds, function(questIdA, questIdB)
        local percentageA = questDetails[questIdA].questCompletePercent
        local percentageB = questDetails[questIdB].questCompletePercent

        if percentageA == percentageB then
            local questA = questDetails[questIdA].quest
            local questB = questDetails[questIdB].quest
            return Sorter.CompareByQuestLevelAndType(questIdA, questA.level, questIdB, questB.level)
        end

        return percentageB < percentageA
    end)
end

--- Sorts the given questIds in place by their completion status, with incomplete quests first.
---@param questIds QuestId[]
---@param questDetails table<QuestId, QuestSortDetails>
function Sorter.byCompleteReverse(questIds, questDetails)
    table.sort(questIds, function(questIdA, questIdB)
        local percentageA = questDetails[questIdA].questCompletePercent
        local percentageB = questDetails[questIdB].questCompletePercent

        if percentageA == percentageB then
            local questA = questDetails[questIdA].quest
            local questB = questDetails[questIdB].quest
            return Sorter.CompareByQuestLevelAndType(questIdA, questA.level, questIdB, questB.level)
        end

        return percentageB > percentageA
    end)
end
