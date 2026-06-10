---@class Sorter
local Sorter = QuestieLoader:ImportModule("Sorter")

--- Sorts the given questIds in place by zone, then by level, then by type suffix, then by ID.
---@param questIds QuestId[]
---@param questDetails table<QuestId, QuestSortDetails>
function Sorter.byZone(questIds, questDetails)
    table.sort(questIds, function(questIdA, questIdB)
        local questA = questDetails[questIdA].quest
        local questB = questDetails[questIdB].quest
        local zoneA = questDetails[questIdA].zoneName
        local zoneB = questDetails[questIdB].zoneName

        if zoneA == zoneB then
            return Sorter.CompareByQuestLevelAndType(questIdA, questA.level, questIdB, questB.level)
        else
            return zoneA < zoneB
        end
    end)
end
