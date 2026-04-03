---@class QuestieReputation
local QuestieReputation = QuestieLoader:CreateModule("QuestieReputation")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

--- COMPATIBILITY ---
local GetFactionInfo = QuestieCompat.GetFactionInfo

local playerReputations = {}
local factionNameCache = {}

local _ReachedNewStanding, _WinterSaberChanged, _FilterShaTarRewards, _GetRewardMultiplier

-- Fast local references
local ExpandFactionHeader, GetNumFactions = ExpandFactionHeader, GetNumFactions
local tinsert, floor = table.insert, math.floor

--- Updates all factions a player already discovered and checks if any of these
--- reached a new reputation level
---@param isInit boolean? @
function QuestieReputation:Update(isInit)
    Questie:Debug(Questie.DEBUG_DEVELOP, "QuestieReputation: Update")
    ExpandFactionHeader(0) -- Expand all header

    local factionChanged = false
    local newFaction = false

    for i=1, GetNumFactions() do
        local name, _, standingId, _, _, barValue, _, _, isHeader, _, _, _, _, factionID, _, _ = GetFactionInfo(i)
        if not isHeader and factionID then
            local previousValues = playerReputations[factionID]
            if (not previousValues) then
                --? Reset all autoBlacklisted quests if a faction gets discovered
                QuestieQuest.ResetAutoblacklistCategory("rep")
                newFaction = true
            end

            playerReputations[factionID] = {standingId, barValue}

            if (not isInit) and (
                    _ReachedNewStanding(previousValues, standingId)
                    or _WinterSaberChanged(factionID, previousValues, barValue)) then
                Questie:Debug(Questie.DEBUG_DEVELOP, "QuestieReputation: Update - faction \"" .. name .. "\" (" .. factionID .. ") changed")
                factionChanged = true
            end
        end
    end

    return factionChanged, newFaction
end

---@return boolean
_ReachedNewStanding = function(previousValues, standingId)
    return (not previousValues) -- New faction
        or (previousValues[1] ~= standingId) -- Standing changed
end

---@return boolean
_WinterSaberChanged = function(factionID, previousValues, barValue)
    return factionID == QuestieDB.factionIDs.WINTERSABER_TRAINERS
        and previousValues and ((previousValues[2] < 4500 and barValue >= 4500)
            or (previousValues[2] < 13000 and barValue >= 13000))
end

---@param requiredMinRep { [1]: number, [2]: number }? [1] = factionId, [2] = repValue
---@param requiredMaxRep { [1]: number, [2]: number }? [1] = factionId, [2] = repValue
---@return boolean AboveMinRep
---@return boolean HasMinFaction
---@return boolean BelowMaxRep
---@return boolean HasMaxFaction
function QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)
    local aboveMinRep = false -- the player has reached the min required reputation value
    local belowMaxRep = false
    local hasMinFaction = false
    local hasMaxFaction = false

    if requiredMinRep then
        local minFactionID = requiredMinRep[1]
        local reqMinValue = requiredMinRep[2]

        if playerReputations[minFactionID] then
            hasMinFaction = true
            aboveMinRep = playerReputations[minFactionID][2] >= reqMinValue
        end
    else
        -- If requiredMinRep is nil, we don't care about the reputation aka it fullfils it
        aboveMinRep = true
        hasMinFaction = true
    end
    if requiredMaxRep then
        local maxFactionID = requiredMaxRep[1]
        local reqMaxValue = requiredMaxRep[2]

        if playerReputations[maxFactionID] then
            hasMaxFaction = true
            belowMaxRep = playerReputations[maxFactionID][2] < reqMaxValue
        elseif maxFactionID == QuestieDB.factionIDs.DARKMOON_FAIRE then
            hasMaxFaction = true
            belowMaxRep = true
        end
    else
        -- If requiredMaxRep is nil, we don't care about the reputation aka it fullfils it
        belowMaxRep = true
        hasMaxFaction = true
    end
    return aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction
end

--- Checkout https://github.com/Questie/Questie/wiki/Corrections#reputation-levels for more information
---@return boolean HasReputation Is the player within the required reputation ranges specified by the parameters
function QuestieReputation:HasReputation(requiredMinRep, requiredMaxRep)
    local aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction = QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)

    return ((aboveMinRep and hasMinFaction) and (belowMaxRep and hasMaxFaction))
end

---@param factionId FactionId
---@return string|nil name @Name of the faction
function QuestieReputation.GetFactionName(factionId)
    if not factionId then
        return nil
    end

    local cachedName = factionNameCache[factionId]
    if cachedName then
        return cachedName
    end

    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local friendReputation = C_GossipInfo.GetFriendshipReputation(factionId)
        if friendReputation and friendReputation.name and friendReputation.name ~= "" then
            factionNameCache[factionId] = friendReputation.name
            return friendReputation.name
        end
    end

    if GetFactionInfoByID then
        local factionName = select(1, GetFactionInfoByID(factionId))
        if factionName and factionName ~= "" then
            factionNameCache[factionId] = factionName
            return factionName
        end
    end

    ExpandFactionHeader(0) -- Expand all header
    for i = 1, GetNumFactions() do
        local factionName, _, _, _, _, _, _, _, isHeader, _, _, _, _, lFactionId = GetFactionInfo(i)
        if not isHeader and lFactionId == factionId and factionName and factionName ~= "" then
            factionNameCache[factionId] = factionName
            return factionName
        end
    end

    return nil
end

---@param questId QuestId
---@return ReputationPair[]|nil
function QuestieReputation.GetReputationReward(questId)
    if not questId then
        return nil
    end

    local baseRewards = QuestieDB.QueryQuestSingle(questId, "reputationReward")
    if not baseRewards or not next(baseRewards) then
        return nil
    end

    local rewards = {}
    for _, rewardPair in pairs(baseRewards) do
        rewards[#rewards + 1] = {rewardPair[1], rewardPair[2]}
    end

    local factionIDs = QuestieDB.factionIDs
    rewards = _FilterShaTarRewards(rewards, factionIDs)

    local reputationMultiplier = _GetRewardMultiplier()
    local aldorPenalty, scryersPenalty

    for _, rewardPair in pairs(rewards) do
        local factionId = rewardPair[1]
        local rewardValue = rewardPair[2]

        if rewardValue > 0 and reputationMultiplier ~= 1 then
            rewardValue = floor(rewardValue * reputationMultiplier)
            rewardPair[2] = rewardValue
        end

        if factionId == factionIDs.THE_ALDOR then
            scryersPenalty = {factionIDs.THE_SCRYERS, 0 - floor(rewardValue * 1.1)}
        elseif factionId == factionIDs.THE_SCRYERS then
            aldorPenalty = {factionIDs.THE_ALDOR, 0 - floor(rewardValue * 1.1)}
        end
    end

    if aldorPenalty then
        tinsert(rewards, aldorPenalty)
    elseif scryersPenalty then
        tinsert(rewards, scryersPenalty)
    end

    return rewards
end

---@return number
_GetRewardMultiplier = function()
    if QuestiePlayer.HasRequiredRace(QuestieDB.raceKeys.HUMAN) then
        return 1.1 -- 10% bonus reputation from Human racial
    end

    return 1
end

---@param reputationReward ReputationPair[]
---@param factionIDs table
---@return ReputationPair[]
_FilterShaTarRewards = function(reputationReward, factionIDs)
    local playerIsHonoredWithShaTar = QuestieReputation:HasReputation({ factionIDs.THE_SHA_TAR, 9000 }, nil)
    if not playerIsHonoredWithShaTar then
        return reputationReward
    end

    local hasAldorOrScryer = false
    for _, rewardPair in pairs(reputationReward) do
        local factionId = rewardPair[1]
        if factionId == factionIDs.THE_ALDOR or factionId == factionIDs.THE_SCRYERS then
            hasAldorOrScryer = true
            break
        end
    end

    if not hasAldorOrScryer then
        return reputationReward
    end

    local filteredRewards = {}
    for _, rewardPair in pairs(reputationReward) do
        if rewardPair[1] ~= factionIDs.THE_SHA_TAR then
            filteredRewards[#filteredRewards + 1] = rewardPair
        end
    end

    return filteredRewards
end

---@param reputationReward ReputationPair[]
---@return string @Formatted reputation reward string
function QuestieReputation.GetReputationRewardString(reputationReward)
    local rewardTable = {}

    for _, rewardPair in pairs(reputationReward) do
        local factionId = rewardPair[1]
        local rewardValue = rewardPair[2]
        local factionName = QuestieReputation.GetFactionName(factionId)
        if factionName then
            rewardTable[#rewardTable + 1] = (rewardValue > 0 and "+" or "") .. rewardValue .. " " .. factionName
        end
    end

    return table.concat(rewardTable, " / ")
end

return QuestieReputation
