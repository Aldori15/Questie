--Contains functions to fetch the Quest Experiance for quests.
---@class QuestXP
local QuestXP = QuestieLoader:CreateModule("QuestXP")

---@type table<QuestId,table<Level,number>> -- {questId = {QuestLevel, RewardXPDifficulty}}
QuestXP.db = {}

---@type table<Level,table<number,XP>> -- QuestXP.dbc rows by level and difficulty
QuestXP.xpByLevel = {}

--- COMPATIBILITY ---
local GetMaxPlayerLevel = QuestieCompat.GetMaxPlayerLevel
local GetQuestLogRewardMoney = QuestieCompat.GetQuestLogRewardMoney

local floor = floor
local UnitLevel = UnitLevel

---@param xp XP
---@param qLevel Level
---@param ignorePlayerLevel boolean
---@return XP experience
local function getAdjustedXP(xp, qLevel, ignorePlayerLevel)
    local charLevel = UnitLevel("player")
    if charLevel == GetMaxPlayerLevel() and (not ignorePlayerLevel) then
        return 0
    end

    --? These calculations are fetched from cmangos
    local xpMultiplier = 2 * (qLevel - charLevel) + 20
    if (xpMultiplier < 1) then
        xpMultiplier = 1
    elseif (xpMultiplier > 10) then
        xpMultiplier = 10
    end

    xp = xp * xpMultiplier / 10
    --? I am unsure if the first xp <= 100 is actually correct... because some 85 xp quests should actually give 90
    if (xp <= 100) then
        xp = 5 * floor((xp + 2) / 5)
    elseif (xp <= 500) then
        xp = 10 * floor((xp + 5) / 10)
    elseif (xp <= 1000) then
        xp = 25 * floor((xp + 12) / 25)
    else
        xp = 50 * floor((xp + 25) / 50)
    end

    return floor(xp)
end


---Get the adjusted XP for a quest.
---@param questId QuestId
---@param ignorePlayerLevel boolean
---@return XP experience
function QuestXP:GetQuestLogRewardXP(questId, ignorePlayerLevel)
    local questData = QuestXP.db[questId]
    if questData then
        local level = questData[1]
        local rewardDifficulty = questData[2]

        -- AzerothCore uses the player's current level for quests with QuestLevel -1.
        if level == -1 then
            level = UnitLevel("player")
        end

        local levelRewards = QuestXP.xpByLevel[level]
        local xp = levelRewards and levelRewards[rewardDifficulty + 1]
        if level > 0 and xp and xp > 0 then
            return getAdjustedXP(xp, level, ignorePlayerLevel)
        end
    end

    -- Return 0 if questId or xp data is not found for some reason
    return 0
end

function QuestXP.GetQuestRewardMoney(questId)
    return floor(GetQuestLogRewardMoney(questId))
end
