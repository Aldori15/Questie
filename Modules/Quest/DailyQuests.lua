---@class DailyQuests
---@field hubs table<HubId, Hub>
local DailyQuests = QuestieLoader:CreateModule("DailyQuests");

local GetDailyQuestsCompleted = GetDailyQuestsCompleted
local GetMaxDailyQuests = GetMaxDailyQuests

---@return boolean
function DailyQuests:IsAtDailyQuestLimit()
    local maxDailyQuests = GetMaxDailyQuests and GetMaxDailyQuests() or 0
    if maxDailyQuests <= 0 then
        return false
    end

    if GetDailyQuestsCompleted then
        local dailyQuestsCompleted = GetDailyQuestsCompleted()
        if dailyQuestsCompleted and dailyQuestsCompleted >= maxDailyQuests then
            return true
        end
    end

    if not Questie.db.profile.resetDailyQuests then
        return false
    end

    local dailyQuestsCompleted = 0
    for _ in pairs(Questie.db.char.daily or {}) do
        dailyQuestsCompleted = dailyQuestsCompleted + 1
    end

    return dailyQuestsCompleted >= maxDailyQuests
end

---@type table<QuestId, Hub[]>
local hubQuestLookup = {}

function DailyQuests.Initialize()
    hubQuestLookup = {}

    for _, hub in pairs(DailyQuests.hubs or {}) do
        hub.exclusiveHubs = hub.exclusiveHubs or {}
        hub.preQuestHubsSingle = hub.preQuestHubsSingle or {}
        hub.preQuestHubsGroup = hub.preQuestHubsGroup or {}

        for _, hubQuestId in pairs(hub.quests or {}) do
            if not hubQuestLookup[hubQuestId] then
                hubQuestLookup[hubQuestId] = {}
            end

            table.insert(hubQuestLookup[hubQuestId], hub)
        end
    end
end

---@param hub Hub
---@param completedQuests table<QuestId, boolean>
---@param questLog table<QuestId, Quest>
---@return boolean
local function _ShouldBeHidden(hub, completedQuests, questLog)
    if hub.IsActive and (not hub.IsActive(completedQuests, questLog)) then
        return true
    end

    local completedCount = 0
    for _, hubQuestId in pairs(hub.quests or {}) do
        if completedQuests[hubQuestId] or questLog[hubQuestId] then
            completedCount = completedCount + 1
        end
    end

    for hubId in pairs(hub.exclusiveHubs) do
        local exclusiveHub = DailyQuests.hubs and DailyQuests.hubs[hubId]
        if exclusiveHub then
            for _, exclusiveHubQuestId in pairs(exclusiveHub.quests or {}) do
                if completedQuests[exclusiveHubQuestId] or questLog[exclusiveHubQuestId] then
                    return true
                end
            end
        end
    end

    if completedCount >= (hub.limit or 0) then
        return true
    end

    local singlePreQuestHubComplete = not next(hub.preQuestHubsSingle)
    for hubId in pairs(hub.preQuestHubsSingle) do
        local preHub = DailyQuests.hubs and DailyQuests.hubs[hubId]
        if preHub then
            local preHubCompletedCount = 0
            for _, preHubQuestId in pairs(preHub.quests or {}) do
                if completedQuests[preHubQuestId] then
                    preHubCompletedCount = preHubCompletedCount + 1
                end
            end

            if preHubCompletedCount >= (preHub.limit or 0) then
                singlePreQuestHubComplete = true
            end
        end
    end

    if not singlePreQuestHubComplete then
        return true
    end

    local groupPreQuestHubComplete = true
    for hubId in pairs(hub.preQuestHubsGroup) do
        local preHub = DailyQuests.hubs and DailyQuests.hubs[hubId]
        if preHub then
            local preHubCompletedCount = 0
            for _, preHubQuestId in pairs(preHub.quests or {}) do
                if completedQuests[preHubQuestId] then
                    preHubCompletedCount = preHubCompletedCount + 1
                end
            end

            if preHubCompletedCount < (preHub.limit or 0) then
                groupPreQuestHubComplete = false
                break
            end
        end
    end

    if not groupPreQuestHubComplete then
        return true
    end

    return false
end

---@param questId QuestId
---@param completedQuests table<QuestId, boolean>
---@param questLog table<QuestId, Quest>
---@return boolean
function DailyQuests.ShouldBeHidden(questId, completedQuests, questLog)
    if not hubQuestLookup[questId] then
        return false
    end

    for _, hub in pairs(hubQuestLookup[questId]) do
        if not _ShouldBeHidden(hub, completedQuests, questLog) then
            return false
        end
    end

    return true
end
