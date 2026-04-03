---@class Phasing
local Phasing = QuestieLoader:CreateModule("Phasing")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")

local _Phasing = {}

-- Minimal Wrath-era phasing support for 3.3.5a.
local phases = {
    UNKNOWN = 169,
    CUSTOM_EVENT_3 = 177,
    SCARLET_ENCLAVE_ENTRACE = 1029,
    SCARLET_ENCLAVE = 1030,
    HAR_KOA_AT_ALTAR = 1034,
    HAR_KOA_AT_ZIM_TORGA = 1035,
}
Phasing.phases = phases

---@param phase number|nil
---@return boolean
function Phasing.IsSpawnVisible(phase)
    if (not phase) or phase == phases.UNKNOWN then
        return true
    end

    if (not Questie) or (not Questie.db) or (not Questie.db.char) or (not Questie.db.char.complete) then
        return true
    end

    local complete = Questie.db.char.complete
    local questLog = QuestLogCache.questLog_DO_NOT_MODIFY or {}

    if phase == phases.CUSTOM_EVENT_3 then
        return _Phasing.CheckQuestLog(questLog)
    end

    if phase == phases.SCARLET_ENCLAVE_ENTRACE then
        return not complete[27460]
    end

    if phase == phases.SCARLET_ENCLAVE then
        return complete[27460] or false
    end

    if phase == phases.HAR_KOA_AT_ALTAR then
        return not complete[12684]
    end

    if phase == phases.HAR_KOA_AT_ZIM_TORGA then
        return complete[12684] or false
    end

    return false
end

_Phasing.CheckQuestLog = function(questLog)
    return (
        questLog[13847] or
        questLog[13851] or
        questLog[13852] or
        questLog[13854] or
        questLog[13855] or
        questLog[13856] or
        questLog[13857] or
        questLog[13858] or
        questLog[13859] or
        questLog[13860] or
        questLog[13861] or
        questLog[13862] or
        questLog[13863] or
        questLog[13864] or
        questLog[25560]
    ) and true or false
end

return Phasing
