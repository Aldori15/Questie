--Contains functions to fetch the Quest Experiance for quests.
---@class QuestXP
local QuestXP = QuestieLoader:CreateModule("QuestXP")
local QuestieServer = QuestieLoader:ImportModule("QuestieServer")
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

---@type table<QuestId,table<Level,number>> -- {questId = {QuestLevel, RewardXPDifficulty}}
QuestXP.db = {}

---@type table<Level,table<number,XP>> -- QuestXP.dbc rows by level and difficulty
QuestXP.xpByLevel = {}

---@type table<ItemId,table<number>> -- Equipped item quest XP bonus percentages
QuestXP.itemQuestXPBonuses = {}

--- COMPATIBILITY ---
local GetMaxPlayerLevel = QuestieCompat.GetMaxPlayerLevel
local GetQuestLogRewardMoney = QuestieCompat.GetQuestLogRewardMoney

local floor = floor
local GetInventoryItemID = GetInventoryItemID
local UnitLevel = UnitLevel

local FIRST_EQUIPMENT_SLOT = 1
local LAST_EQUIPMENT_SLOT = 19

-- Core reward multiplications use float32, followed by uint32 truncation.
-- Lua's doubles otherwise differ near integer boundaries for fractional rates.
local function float32(value)
    if value == 0 then return 0 end
    local _, exponent = math.frexp(value)
    local shift = exponent < -125 and 149 or 24 - exponent
    local scaled = math.ldexp(value, shift)
    local rounded = floor(scaled)
    local fraction = scaled - rounded
    if fraction > 0.5 or (fraction == 0.5 and rounded % 2 ~= 0) then rounded = rounded + 1 end
    return math.ldexp(rounded, -shift)
end

local function applyLiveXP(xp, rate, aura)
    xp = float32(float32(xp) * rate)
    -- Out-of-range float-to-uint32 conversion is not a supported core reward.
    if xp > 4294967295 then return nil end
    xp = float32(float32(floor(xp)) * aura)
    if xp > 4294967295 then return nil end
    return floor(xp)
end

---@return number multiplier
local function getEquippedQuestXPMultiplier()
    local multiplier = 1

    for inventorySlot = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
        local itemId = GetInventoryItemID("player", inventorySlot)
        local bonuses = itemId and QuestXP.itemQuestXPBonuses[itemId]
        if bonuses then
            for _, bonusPercent in ipairs(bonuses) do
                -- AzerothCore's GetTotalAuraMultiplier applies each percentage
                -- to the accumulated multiplier.
                multiplier = multiplier * (1 + bonusPercent / 100)
            end
        end
    end

    return multiplier
end

---@param questId QuestId
---@param xp XP
---@param qLevel Level
---@param ignorePlayerLevel boolean
---@param ignoreQuestXPModifiers boolean
---@return XP experience
local function getAdjustedXP(questId, xp, qLevel, ignorePlayerLevel, ignoreQuestXPModifiers)
    local charLevel = UnitLevel("player")
    local live = not ignoreQuestXPModifiers and QuestieServer.GetQuestXPRates and QuestieServer:GetQuestXPRates()
    local maxLevel = live and live.maxLevel or GetMaxPlayerLevel()
    if charLevel >= maxLevel and (not ignorePlayerLevel) then
        return 0
    end

    -- Match AzerothCore's Quest::XPValue level factor and rounding buckets.
    local xpMultiplier = 2 * (qLevel - charLevel) + 20
    if (xpMultiplier < 1) then
        xpMultiplier = 1
    elseif (xpMultiplier > 10) then
        xpMultiplier = 10
    end

    xp = floor(xp * xpMultiplier / 10)
    if (xp <= 100) then
        xp = 5 * floor((xp + 2) / 5)
    elseif (xp <= 500) then
        xp = 10 * floor((xp + 5) / 10)
    elseif (xp <= 1000) then
        xp = 25 * floor((xp + 12) / 25)
    else
        xp = 50 * floor((xp + 25) / 50)
    end

    if not ignoreQuestXPModifiers then
        if live then
            -- SpecialFlags bit 8 identifies DF rewards, not ordinary dungeon quests.
            local flags = QuestieDB.QueryQuestSingle(questId, "specialFlags") or 0
            local rate = flags % 16 >= 8 and live.dungeonFinder or live.normal
            local adjusted = applyLiveXP(xp, rate, live.aura)
            if adjusted then return adjusted end
        end
        xp = xp * getEquippedQuestXPMultiplier()
    end

    return floor(xp)
end


---Get the adjusted XP for a quest.
---@param questId QuestId
---@param ignorePlayerLevel boolean
---@param ignoreQuestXPModifiers boolean?
---@return XP experience
function QuestXP:GetQuestLogRewardXP(questId, ignorePlayerLevel, ignoreQuestXPModifiers)
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
            return getAdjustedXP(questId, xp, level, ignorePlayerLevel, ignoreQuestXPModifiers)
        end
    end

    -- Return 0 if questId or xp data is not found for some reason
    return 0
end

function QuestXP.GetQuestRewardMoney(questId)
    return floor(GetQuestLogRewardMoney(questId))
end
