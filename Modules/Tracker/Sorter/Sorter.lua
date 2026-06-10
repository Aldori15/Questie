---@class Sorter
local Sorter = QuestieLoader:CreateModule("Sorter")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

---@class QuestSortDetails
---@field questCompletePercent number
---@field quest Quest
---@field zoneName string

---@param questIdA QuestId
---@param questIdB QuestId
---@return boolean
function Sorter.CompareBySuffix(questIdA, questIdB)
    local suffixPrioA = QuestieLib.GetQuestTypeSuffixPriority(questIdA)
    local suffixPrioB = QuestieLib.GetQuestTypeSuffixPriority(questIdB)
    if suffixPrioA == suffixPrioB then
        return questIdA < questIdB
    end
    return suffixPrioA < suffixPrioB
end

---@param questIdA QuestId
---@param questLevelA number
---@param questIdB QuestId
---@param questLevelB number
---@return boolean
function Sorter.CompareByQuestLevelAndType(questIdA, questLevelA, questIdB, questLevelB)
    if questLevelA == questLevelB then
        return Sorter.CompareBySuffix(questIdA, questIdB)
    end
    return questLevelA < questLevelB
end
