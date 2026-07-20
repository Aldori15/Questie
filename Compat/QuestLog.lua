---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieEventHandler
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@class AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type MinimapIcon
local MinimapIcon = QuestieLoader:ImportModule("MinimapIcon")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestXP
local QuestXP = QuestieLoader:ImportModule("QuestXP")

local math_max = math.max
local bitband = bit.band
local strfind = string.find
local questLogCompatibilityInitialized = false
local questObjectivesCache = {}
local uiInfoChangedQuestIds = {}
local QUEST_OBJECTIVE_CACHE_TTL_SECONDS = 3
local QUEST_FLAGS_NO_MONEY_FROM_XP = 0x100

-- Forward declarations for the 3.3.5 reward-completion fallback near the end
-- of this file. The raw cache is kept before repeatable quests are filtered
-- from Questie.db.char.complete.
local ProcessPendingRewardCompletions
local serverCompletedQuests = {}

local function parseQuestObjective(text)
    return string.match(string.gsub(text, "\239\188\154", ":"), "(.*):%s*([%d]+)%s*/%s*([%d]+)")
end

local function normalizeObjectiveName(objectiveName)
    if type(objectiveName) ~= "string" then
        return objectiveName
    end

    -- Remove coloring codes and trim whitespace to keep lookup keys stable.
    objectiveName = objectiveName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return objectiveName:match("^%s*(.-)%s*$")
end

local function setObjectiveProgressCache(objectiveName, numFulfilled)
    numFulfilled = tonumber(numFulfilled)
    if (not objectiveName) or (not numFulfilled) then
        return
    end

    questObjectivesCache[objectiveName] = {
        fulfilled = numFulfilled,
        expiresAt = GetTime() + QUEST_OBJECTIVE_CACHE_TTL_SECONDS
    }
end

local function getObjectiveProgressCache(objectiveName)
    local cached = questObjectivesCache[objectiveName]
    if not cached then
        return nil
    end

    if (type(cached) ~= "table") or (type(cached.fulfilled) ~= "number") then
        questObjectivesCache[objectiveName] = nil
        return nil
    end

    if cached.expiresAt and (GetTime() > cached.expiresAt) then
        questObjectivesCache[objectiveName] = nil
        return nil
    end

    return cached.fulfilled
end

local function applyObjectiveProgressToQuestieCache(objectiveName, numFulfilled)
    numFulfilled = tonumber(numFulfilled)
    if (not objectiveName) or (not numFulfilled) then
        return false
    end

    local hasChanges = false
    for questId, questData in pairs(QuestLogCache.questLog_DO_NOT_MODIFY or {}) do
        local objectives = questData and questData.objectives
        if objectives and #objectives > 0 then
            for _, objective in ipairs(objectives) do
                if objective and objective.type == "item" and normalizeObjectiveName(objective.text) == objectiveName then
                    local oldFulfilled = tonumber(objective.numFulfilled) or 0
                    if numFulfilled > oldFulfilled then
                        objective.numFulfilled = numFulfilled
                        objective.raw_numFulfilled = math_max(tonumber(objective.raw_numFulfilled) or 0, numFulfilled)
                        if objective.numRequired then
                            local isFinished = numFulfilled >= objective.numRequired
                            objective.finished = isFinished
                            objective.raw_finished = objective.raw_finished or isFinished
                        end
                        uiInfoChangedQuestIds[questId] = true
                        hasChanges = true
                    end
                end
            end
        end
    end

    return hasChanges
end

QuestieCompat.C_QuestLog = {
	-- Returns info for the objectives of a quest. (https://wowpedia.fandom.com/wiki/API_C_QuestLog.GetQuestObjectives)
	GetQuestObjectives = function(questID, questLogIndex)
		local questObjectives, objectiveIndex = {}, 1
        if questLogIndex then
		    local numObjectives = GetNumQuestLeaderBoards(questLogIndex);
		    for i = 1, numObjectives do
		    	-- https://wowpedia.fandom.com/wiki/API_GetQuestLogLeaderBoard
		    	local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i, questLogIndex);
                if objectiveType ~= "log" then
		    	    local objectiveName, numFulfilled, numRequired = parseQuestObjective(description)
                    objectiveName = normalizeObjectiveName(objectiveName)
                    -- GetQuestLogLeaderBoard randomly returns incorrect objective information.
                    -- Parsing the UI_INFO_MESSAGE event for the correct numFulfilled value seems like the solution.
                    local fulfilled = getObjectiveProgressCache(objectiveName)
                    if fulfilled then
                        if not isCompleted then
                            -- GetQuestLogLeaderBoard can lag behind UI_INFO_MESSAGE.
                            -- Never let cached fallback reduce an already newer value.
                            local questLogFulfilled = tonumber(numFulfilled)
                            if questLogFulfilled then
                                numFulfilled = math_max(questLogFulfilled, fulfilled)
                                if questLogFulfilled >= fulfilled then
                                    questObjectivesCache[objectiveName] = nil
                                end
                            else
                                numFulfilled = fulfilled
                            end
                        else
                            questObjectivesCache[objectiveName] = nil
                        end
                    end

		    	    table.insert(questObjectives, objectiveIndex, {
		    	    	text = description,
		    	    	type = objectiveType,
		    	    	finished = isCompleted and true or false,
		    	    	numFulfilled = tonumber(numFulfilled) or (isCompleted and 1 or 0),
		    	    	numRequired = tonumber(numRequired) or 1,
		    	    })
					-- "event" should always be last?
					objectiveIndex = objectiveIndex + (objectiveType ~= "event" and 1 or 0)
                end
		    end
        end
		return questObjectives -- can be empty for quests without objectives
	end,
    GetMaxNumQuestsCanAccept = function()
        return MAX_QUESTLOG_QUESTS
    end,
    IsOnQuest = function(questId)
        return QuestieCompat.GetQuestLogIndexByID(questId) and true or false
    end,
}

-- Can't find anything about this function.
-- Apparently, it returns true when quest data is ready to be queried.
function QuestieCompat.HaveQuestData(questID)
	return true
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogTitle?oldid=2214753
-- Returns information about a quest in your quest log.
-- Patch 6.0.2 (2014-10-14): Removed returns 'questTag'.
function QuestieCompat.GetQuestLogTitle(questLogIndex)
    local questTitle, level, _, suggestedGroup, isHeader, isCollapsed,
        isComplete, isDaily, questID = GetQuestLogTitle(questLogIndex);
    local questTag = select(2, QuestieCompat.GetQuestTagInfo(questID))

    if (isComplete == nil) then
        local numObjectives = GetNumQuestLeaderBoards(questLogIndex);
        local requiredMoney = GetQuestLogRequiredMoney(questLogIndex);
        isComplete = (numObjectives == 0 and requiredMoney > 0 and GetMoney() >= requiredMoney) and 1 or nil
    end
    return questTitle, level, questTag, isHeader, isCollapsed, isComplete, isDaily and 2 or 1, questID
end

local MAX_QUEST_LOG_INDEX = 75
-- Returns the current quest log index of a quest by its ID.
-- https://wowpedia.fandom.com/wiki/API_GetQuestLogIndexByID
function QuestieCompat.GetQuestLogIndexByID(questId)
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if (not title) then
            break -- We exceeded the valid quest log entries
        end
        if (not isHeader) then
            if (questId == id) then
                return questLogIndex
            end
        end
    end
end

function QuestieCompat.GetQuestIDFromLogIndex(questLogIndex)
    return select(9, GetQuestLogTitle(questLogIndex))
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLink
-- Returns a QuestLink for a quest.
-- Between patches 6.2 and 7.3.2 argument was changed to take a QuestID instead of a quest log index.
function QuestieCompat.GetQuestLink(questId)
    local questLogIndex = QuestieCompat.GetQuestLogIndexByID(questId)
    return questLogIndex and GetQuestLink(questLogIndex)
end

function QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
	local questLink = QuestieCompat.GetQuestLink(questId)
	if questLink then
		return questLink
	end

	local numericQuestId = tonumber(questId)
	if numericQuestId and questName then
		local numericQuestLevel = tonumber(questLevel) or -1
		return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", numericQuestId, numericQuestLevel, questName)
	end

	return "[["..tostring(questLevel).."] "..tostring(questName).." ("..tostring(questId)..")]"
end

function QuestieCompat:GetQuestLinkStringById(questId)
    local questName = QuestieDB.QueryQuestSingle(questId, "name");
    local questLevel, _ = QuestieLib.GetTbcLevel(questId);
    return QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogRewardMoney
-- Returns the amount of money rewarded for a quest.
function QuestieCompat.GetQuestLogRewardMoney(questID)
    local rewardMoney = QuestieCompat.RewardMoney[questID] or 0
    local rewardMoneyDifficulty = QuestieCompat.RewardMoneyDifficulty[questID] or 0

    local playerLevel = QuestiePlayer.GetPlayerLevel()
    if rewardMoney >= 0 and playerLevel > 0 and rewardMoneyDifficulty > 0 then
        local levelRewards = QuestieCompat.QuestMoneyReward[playerLevel]
        local scaledRewardMoney = levelRewards and levelRewards[rewardMoneyDifficulty]
        if scaledRewardMoney and scaledRewardMoney > 0 then
            rewardMoney = scaledRewardMoney
        end
    end

    -- https://wowpedia.fandom.com/wiki/Quest?oldid=1035002 Formula is XP gained * 6c
    if QuestiePlayer.IsMaxLevel() then
        local questFlags = QuestieDB.QueryQuestSingle(questID, "questFlags") or 0
        if bitband(questFlags, QUEST_FLAGS_NO_MONEY_FROM_XP) == 0 then
            -- AzerothCore's max-level XP-to-money conversion does not apply
            -- player quest XP aura modifiers such as heirloom bonuses.
            local xpReward = QuestXP:GetQuestLogRewardXP(questID, true, true)
            if xpReward > 0 then
                rewardMoney = rewardMoney + xpReward * 6
            end
        end
    end

    return rewardMoney
end

local MAX_DAILY_RESET_SECONDS = 48 * 60 * 60
local FALLBACK_DAILY_RESET_HOUR = 6
local warnedInvalidQuestResetTime = false

local function _CalculateFallbackQuestResetTime(currentTime, currentDate)
    local resetHour = Questie.db.profile.weeklyResetHour
    if type(resetHour) ~= "number" then
        resetHour = FALLBACK_DAILY_RESET_HOUR
    end

    local nextResetTime = time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day,
        hour = resetHour,
        min = 0,
        sec = 0,
    })

    if (not nextResetTime) or nextResetTime <= currentTime then
        nextResetTime = time({
            year = currentDate.year,
            month = currentDate.month,
            day = currentDate.day + 1,
            hour = resetHour,
            min = 0,
            sec = 0,
        })
    end

    return (nextResetTime or currentTime) - currentTime
end

function QuestieCompat.GetQuestResetTime()
    local timeUntilReset = tonumber(GetQuestResetTime())
    local currentTime, currentDate = QuestieCompat.GetServerTime()

    if timeUntilReset and timeUntilReset >= -10 and timeUntilReset <= MAX_DAILY_RESET_SECONDS then
        return math.max(0, timeUntilReset)
    end

    -- Some private servers return an invalid value close to -GetServerTime(), which means their reset timestamp is zero.
    if (not warnedInvalidQuestResetTime) then
        warnedInvalidQuestResetTime = true
        Questie:Debug(Questie.DEBUG_DEVELOP, "[GetQuestResetTime] Invalid native value, using fallback: ", timeUntilReset)
    end

    local storedResetTime = Questie.db.profile.dailyResetTime
    if type(storedResetTime) == "number" and storedResetTime > currentTime then
        return storedResetTime - currentTime
    end

    return _CalculateFallbackQuestResetTime(currentTime, currentDate)
end

function QuestieCompat.CalculateNextResetTime()
    local currentTime, currentDate = QuestieCompat.GetServerTime()
    local timeUntilReset = QuestieCompat.GetQuestResetTime()

    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] GetQuestResetTime: ", timeUntilReset)

    Questie.db.profile.dailyResetTime = Questie.db.profile.dailyResetTime or (currentTime + timeUntilReset)
    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] Next daily rest time: ", date("%m/%d/%y %H:%M:%S", Questie.db.profile.dailyResetTime))

    Questie.db.profile.weeklyResetHour = Questie.db.profile.weeklyResetHour or tonumber(date("%H", Questie.db.profile.dailyResetTime+300))
    local dayOffset = (Questie.db.profile.weeklyResetDay - currentDate.weekday + 7) % 7
    if dayOffset == 0 and currentDate.hour >= Questie.db.profile.weeklyResetHour then
        dayOffset = 7
    end

    Questie.db.profile.weeklyResetTime = Questie.db.profile.weeklyResetTime or time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day + dayOffset,
        hour = Questie.db.profile.weeklyResetHour,
    })
    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] Next weekly rest time: ", date("%m/%d/%y %H:%M:%S", Questie.db.profile.weeklyResetTime))
end

function QuestieCompat.ResetDailyQuests(reset)
    local currentTime = QuestieCompat.GetServerTime()

    if reset or (currentTime > Questie.db.profile.dailyResetTime) then
        for questId in pairs(Questie.db.char.daily) do
            Questie.db.char.daily[questId] = nil
            Questie.db.char.complete[questId] = nil
            serverCompletedQuests[questId] = nil
        end
        Questie.db.char.acoreDailyQuestCompletions = {}
        Questie.db.profile.dailyResetTime = nil
        QuestieCompat.CalculateNextResetTime()
        if Questie.started then
            AvailableQuests.CalculateAndDrawAll()
        end
    end
end

local weeklyResetTimer
function QuestieCompat.ResetWeeklyQuests()
    local currentTime = QuestieCompat.GetServerTime()
    local timeUntilReset = Questie.db.profile.weeklyResetTime - currentTime

    if timeUntilReset < 1800 then
        if weeklyResetTimer then
            weeklyResetTimer = weeklyResetTimer:Cancel()
        end

        weeklyResetTimer = weeklyResetTimer or QuestieCompat.C_Timer.After(timeUntilReset, function()
            for questId in pairs(Questie.db.char.weekly) do
                Questie.db.char.weekly[questId] = nil
                Questie.db.char.complete[questId] = nil
            end
            Questie.db.profile.weeklyResetTime = nil
            QuestieCompat.CalculateNextResetTime()
            if Questie.started then
                AvailableQuests.CalculateAndDrawAll()
            end
        end)

        return true
    end
end

function QuestieCompat.SetQuestComplete(questId)
    if (not QuestieDB.IsRepeatable(questId)) then
        Questie.db.char.complete[questId] = true
    end

    if Questie.db.profile.resetDailyQuests then
        if QuestieDB.IsDailyQuest(questId) then
            Questie.db.char.daily[questId] = true
            Questie.db.char.complete[questId] = true
        elseif QuestieDB.IsWeeklyQuest(questId) then
            Questie.db.char.weekly[questId] = true
            Questie.db.char.complete[questId] = true
        end
    end
end

-- Returns a list of quests the character has completed in its lifetime.
-- https://wowpedia.fandom.com/wiki/API_GetQuestsCompleted
function QuestieCompat.GetQuestsCompleted()
    if not Questie.db.char.complete then
        Questie.db.char.complete = {}
    end

    QueryQuestsCompleted()
    return Questie.db.char.complete
end

---Returns the unfiltered completion state sent by the 3.3.5 server.
---Unlike Questie.db.char.complete, this retains daily/repeatable entries long
---enough for AzerothCore availability conditions to inspect them.
---@param questId number
---@return boolean
function QuestieCompat.IsQuestCompletedOnServer(questId)
    return serverCompletedQuests[questId] == true
        or (Questie.db.char.complete and Questie.db.char.complete[questId] == true)
end

local function EnsureAzerothCoreDailyCompletionReset()
    Questie.db.char.acoreDailyQuestCompletions = Questie.db.char.acoreDailyQuestCompletions or {}

    local currentTime = QuestieCompat.GetServerTime()
    local resetTime = Questie.db.profile.dailyResetTime
    if type(resetTime) ~= "number" or resetTime <= currentTime then
        Questie.db.char.acoreDailyQuestCompletions = {}
        Questie.db.profile.dailyResetTime = nil
        QuestieCompat.CalculateNextResetTime()
    end
end

---@param questId number
function QuestieCompat.SetAzerothCoreDailyQuestComplete(questId)
    EnsureAzerothCoreDailyCompletionReset()
    Questie.db.char.acoreDailyQuestCompletions[questId] = true
end

---@param questId number
---@return boolean
function QuestieCompat.IsAzerothCoreDailyQuestComplete(questId)
    EnsureAzerothCoreDailyCompletionReset()
    return Questie.db.char.acoreDailyQuestCompletions[questId] == true
end

-- Fires when the data requested by QueryQuestsCompleted() is available.
-- https://wowpedia.fandom.com/wiki/QUEST_QUERY_COMPLETE
function QuestieCompat:QUEST_QUERY_COMPLETE(event)
    GetQuestsCompleted(Questie.db.char.complete)

    serverCompletedQuests = {}
    for questId in pairs(Questie.db.char.complete) do
        serverCompletedQuests[questId] = true
    end

    -- Process reward turn-ins before repeatable quests are filtered from the
    -- raw server completion table.
    if ProcessPendingRewardCompletions then
        ProcessPendingRewardCompletions()
    end

    for questId in pairs(Questie.db.char.complete) do
        if QuestieDB.IsRepeatable(questId) then
            Questie.db.char.complete[questId] = nil
        end
    end

    if Questie.db.profile.resetDailyQuests then
        QuestieCompat.CalculateNextResetTime()
        QuestieCompat.ResetDailyQuests()
        QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.daily)

        if Questie.IsWotlk and QuestiePlayer.GetPlayerLevel() >= 78 then
            if (not QuestieCompat.ResetWeeklyQuests()) and (Questie.db.profile.weeklyResetDay == CalendarGetDate()) then
                weeklyResetTimer = weeklyResetTimer or QuestieCompat.C_Timer.NewTicker(1800, QuestieCompat.ResetWeeklyQuests)
            end
            QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.weekly)
        end
    end

    -- The completed-quest response is authoritative for AzerothCore quest
    -- status conditions. It can arrive after Questie's initial map draw.
    if Questie.started then
        AvailableQuests.CalculateAndDrawAll()
    end
end

-- https://wowpedia.fandom.com/wiki/API_IsQuestFlaggedCompleted
-- Determine if a quest has been completed.
function QuestieCompat.IsQuestFlaggedCompleted(questID)
	return Questie.db.char.complete[questID] or false
end

---Returns the available quests at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetGossipAvailableQuests
function QuestieCompat.GetAvailableQuests()
	local availableQuests = {GetGossipAvailableQuests()}
	local numAvailable = GetNumGossipAvailableQuests()
	for i = 1, numAvailable do
		local index = (i - 1) * 5
		availableQuests[index + 3] = availableQuests[index + 3] and true or false
		availableQuests[index + 4] = availableQuests[index + 4] and 2 or 1
		availableQuests[index + 5] = availableQuests[index + 5] and true or false
	end
    for i = 1, numAvailable do
		local index = (i - 1) * 7
		table.insert(availableQuests, index + 6, false)
		table.insert(availableQuests, index + 7, false)
	end
	return unpack(availableQuests)
end

-- Returns the quests which can be turned in at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetGossipActiveQuests
function QuestieCompat.GetActiveQuests()
	local activeQuests = {GetGossipActiveQuests()}
	local numActive = GetNumGossipActiveQuests()
	for i = 1, numActive do
		local index = (i - 1) * 4
		activeQuests[index + 3] = activeQuests[index + 3] and true or false
		activeQuests[index + 4] = activeQuests[index + 4] and true or false
	end
    for i = 1, numActive do
		local index = (i - 1) * 6
		table.insert(activeQuests, index + 5, false)
		table.insert(activeQuests, index + 6, false)
	end
	return unpack(activeQuests)
end

local questTagToName = {
	[1] = "Group",
	[21] = "Class",
	[41] = "PvP",
	[62] = "Raid",
	[81] = "Dungeon",
	[82] = "World Event",
	[83] = "Legendary",
	[84] = "Escort",
	[85] = "Heroic",
	[88] = "Raid (10)",
	[89] = "Raid (25)",
}

-- Retrieves tag information about the quest.
-- https://wowpedia.fandom.com/wiki/API_GetQuestTagInfo
function QuestieCompat.GetQuestTagInfo(questId)
    if not questId then return nil, nil end

    local tagId = QuestieCompat.QuestTag[questId]
	if tagId then
		return tagId, questTagToName[tagId]
	end
end

-- Returns the ID of the displayed quest at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetQuestID
function QuestieCompat.GetQuestID(questStarter, title)
    local title = title or GetTitleText()
    local guid = QuestieCompat.UnitGUID("npc")

	return QuestieDB.GetQuestIDFromName(title, guid, questStarter)
end

function QuestieCompat.GetQuestIDFromName(questTitle)
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if (not title) then
            break -- We exceeded the valid quest log entries
        end
        if (not isHeader) then
            if (questTitle == title) then
                return id
            end
        end
    end
end

local _EventHandler = QuestieEventHandler.private
local chatMessagePattern = {
    questInfo = {
        ERR_QUEST_OBJECTIVE_COMPLETE_S,
	    ERR_QUEST_UNKNOWN_COMPLETE,
	    ERR_QUEST_ADD_KILL_SII,
	    ERR_QUEST_ADD_FOUND_SII,
	    ERR_QUEST_ADD_ITEM_SII,
	    ERR_QUEST_ADD_PLAYER_KILL_SII,
	    ERR_QUEST_FAILED_S,
    },
    playerLoot = {
        LOOT_ITEM_CREATED_SELF,
        LOOT_ITEM_CREATED_SELF_MULTIPLE,
        LOOT_ITEM_PUSHED_SELF,
        LOOT_ITEM_PUSHED_SELF_MULTIPLE,
        LOOT_ITEM_SELF,
        LOOT_ITEM_SELF_MULTIPLE,
    }
}
local uiInfoObjectiveProgressPending = false
local uiInfoObjectiveSyncQueued = false
local uiInfoObjectiveLateSyncQueued = false

local function syncObjectiveProgressFromUiInfoMessage(allowFullFallback)
    local hasTargetedChanges = false
    for questId in pairs(uiInfoChangedQuestIds) do
        uiInfoChangedQuestIds[questId] = nil
        hasTargetedChanges = true
        QuestieQuest:SetObjectivesDirty(questId)
        QuestieQuest:UpdateQuest(questId)
    end

    local didSync = hasTargetedChanges
    if (not hasTargetedChanges) and allowFullFallback then
        local questEventHandlerPrivate = QuestEventHandler.private
        if questEventHandlerPrivate and questEventHandlerPrivate.UpdateAllQuests then
            questEventHandlerPrivate:UpdateAllQuests()
            didSync = true
        end
    end

    if didSync and QuestieTracker and QuestieTracker.Update then
        QuestieTracker:Update()
    end
end

local function queueObjectiveProgressSync(delay)
    if uiInfoObjectiveSyncQueued then
        return
    end

    uiInfoObjectiveSyncQueued = true
    QuestieCompat.C_Timer.After(delay or 0, function()
        uiInfoObjectiveSyncQueued = false
        if not uiInfoObjectiveProgressPending then
            return
        end

        uiInfoObjectiveProgressPending = false
        syncObjectiveProgressFromUiInfoMessage(true)
    end)
end

local function queueLateObjectiveProgressSync()
    if uiInfoObjectiveLateSyncQueued then
        return
    end

    uiInfoObjectiveLateSyncQueued = true
    QuestieCompat.C_Timer.After(0.35, function()
        uiInfoObjectiveLateSyncQueued = false
        syncObjectiveProgressFromUiInfoMessage(false)
    end)
end

function QuestieCompat.LOOT_SLOT_CLEARED(event)
    if uiInfoObjectiveProgressPending then
        queueObjectiveProgressSync(0.10)
        queueLateObjectiveProgressSync()
    end
end

function QuestieCompat.LOOT_CLOSED(event)
    if uiInfoObjectiveProgressPending then
        queueObjectiveProgressSync(0.20)
        queueLateObjectiveProgressSync()
    end
end

-- parse chat message for quest related info
function QuestieCompat.UiInfoMessage(event, ...)
    local arg1, arg2 = ...
    local message
    if type(arg1) == "string" then
        message = arg1
    elseif type(arg2) == "string" then
        message = arg2
    else
        return
    end

    local hasObjectiveProgressUpdate = false
    local objectiveName, numFulfilled = parseQuestObjective(message)
    objectiveName = normalizeObjectiveName(objectiveName)

    -- Parse and cache objective progress from the message itself, independent of pattern matching.
    if objectiveName and numFulfilled then
        setObjectiveProgressCache(objectiveName, numFulfilled)
        hasObjectiveProgressUpdate = true
        uiInfoObjectiveProgressPending = true
        applyObjectiveProgressToQuestieCache(objectiveName, numFulfilled)
        MinimapIcon:UpdateText(message)
    else
        for _, pattern in pairs(chatMessagePattern.questInfo) do
            if strfind(message, pattern) then
                MinimapIcon:UpdateText(message)
                break
            end
        end
    end

    if hasObjectiveProgressUpdate then
        -- Keep a generic delayed sync for non-loot objective progress updates.
        queueObjectiveProgressSync(0.05)
        queueLateObjectiveProgressSync()
    end
end

-- parse chat message for player looting an item
local playerName = UnitName("player")
local emptyName = ""
function QuestieCompat.ChatMessageLoot(message)
    for _, pattern in pairs(chatMessagePattern.playerLoot) do
        if strfind(message, pattern) then
            return playerName
        end
    end
    return emptyName
end

-- handle remote questlog of the party/raid
function QuestieCompat.GroupRosterUpdate(event)
    local currentMembers = QuestieCompat.GetNumGroupMembers()
    local previousMembers = QuestiePlayer.numberOfGroupMembers

    if _EventHandler.GroupRosterUpdate then
        _EventHandler.GroupRosterUpdate()
    else
        QuestiePlayer.numberOfGroupMembers = currentMembers
    end

    -- Only want to do logic when number increases, not decreases.
    if previousMembers < currentMembers then
        if previousMembers == 0 then
            _EventHandler:GroupJoined()
        end
        -- Tell comms to send information to members.
        --Questie:SendMessage("QC_ID_BROADCAST_FULL_QUESTLIST")
    else
        if currentMembers == 0 then
            _EventHandler:GroupLeft()
        end
    end
end

local _QuestEventHandler = QuestEventHandler.private
local QUEST_COMPLETE_MSG = string.gsub(ERR_QUEST_COMPLETE_S, "(%%s)", "(.+)")

-- QUEST_TURNED_IN is unavailable on the 3.3.5 client. Most quests are
-- reconstructed from ERR_QUEST_COMPLETE_S, but some immediate-turn-in quests
-- do not produce a usable message. Keep reward claims until the server confirms
-- the exact quest ID obtained from the current quest ender.
local pendingRewardCompletions = {}
local rewardCompletionQueryScheduled = false
local rewardCompletionQueryInFlight = false
local rewardCompletionQuerySerial = 0
local REWARD_COMPLETION_QUERY_DELAY = 0.5
local REWARD_COMPLETION_QUERY_TIMEOUT = 5

local function ResolveQuestEnderQuestId(questTitle)
    local guid = QuestieCompat.UnitGUID("npc")
    if not guid then
        return nil
    end

    local questgiverId = tonumber(guid:match("-(%d+)-%x+$"), 10)
    local unitType = strsplit("-", guid)
    local questsEnded

    if unitType == "Creature" then
        questsEnded = QuestieDB.QueryNPCSingle(questgiverId, "questEnds")
    elseif unitType == "GameObject" then
        questsEnded = QuestieDB.QueryObjectSingle(questgiverId, "questEnds")
    else
        return nil
    end

    if not questsEnded then
        return nil
    end

    local uniqueMatch
    local uniqueDoableMatch
    local multipleMatches = false
    local multipleDoableMatches = false

    for _, questId in pairs(questsEnded) do
        if QuestieDB.QueryQuestSingle(questId, "name") == questTitle then
            if uniqueMatch and uniqueMatch ~= questId then
                multipleMatches = true
            else
                uniqueMatch = questId
            end

            if QuestieDB.IsDoable(questId) then
                if uniqueDoableMatch and uniqueDoableMatch ~= questId then
                    multipleDoableMatches = true
                else
                    uniqueDoableMatch = questId
                end
            end
        end
    end

    if uniqueDoableMatch and not multipleDoableMatches then
        return uniqueDoableMatch
    end
    if uniqueMatch and not multipleMatches then
        return uniqueMatch
    end
end

local function ResolveRewardQuestId(questTitle)
    -- Immediate-turn-in quests can disappear from (or never enter) the quest
    -- log, so resolve against the current quest ender first.
    local questId = ResolveQuestEnderQuestId(questTitle)
    if questId then
        return questId
    end

    -- Database mismatches can prevent quest-ender resolution. Fall back to the
    -- quest log only when the title identifies one unique quest ID.
    local uniqueQuestId
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if not title then
            break
        end

        if (not isHeader) and title == questTitle then
            if uniqueQuestId and uniqueQuestId ~= id then
                return nil
            end
            uniqueQuestId = id
        end
    end

    return uniqueQuestId
end

local function CompleteRewardQuest(questId)
    -- Keep the raw cache in sync even when the normal chat path handled the
    -- turn-in before another completed-quest query was needed.
    serverCompletedQuests[questId] = true
    if QuestieDB.IsDailyQuest(questId) then
        QuestieCompat.SetAzerothCoreDailyQuestComplete(questId)
    end
    _QuestEventHandler:QuestTurnedIn(questId)
    _QuestEventHandler:QuestRemoved(questId)
end

local ScheduleRewardCompletionQuery

local function ExpireRewardCompletionQuery(querySerial)
    if (not rewardCompletionQueryInFlight) or rewardCompletionQuerySerial ~= querySerial then
        return
    end

    rewardCompletionQueryInFlight = false

    -- Only discard entries which were included in the timed-out request.
    -- Entries queued while it was in flight still need their own query.
    for index = #pendingRewardCompletions, 1, -1 do
        if pendingRewardCompletions[index].minimumQuerySerial <= querySerial then
            table.remove(pendingRewardCompletions, index)
        end
    end

    ScheduleRewardCompletionQuery()
end

ScheduleRewardCompletionQuery = function()
    if rewardCompletionQueryScheduled or rewardCompletionQueryInFlight or #pendingRewardCompletions == 0 then
        return
    end

    rewardCompletionQueryScheduled = true
    QuestieCompat.C_Timer.After(REWARD_COMPLETION_QUERY_DELAY, function()
        rewardCompletionQueryScheduled = false
        if rewardCompletionQueryInFlight or #pendingRewardCompletions == 0 then
            return
        end

        rewardCompletionQuerySerial = rewardCompletionQuerySerial + 1
        local querySerial = rewardCompletionQuerySerial
        rewardCompletionQueryInFlight = true

        QueryQuestsCompleted()
        QuestieCompat.C_Timer.After(REWARD_COMPLETION_QUERY_TIMEOUT, function()
            ExpireRewardCompletionQuery(querySerial)
        end)
    end)
end

ProcessPendingRewardCompletions = function()
    if not rewardCompletionQueryInFlight then
        -- An unrelated completion query may finish between GetQuestReward and
        -- our delayed request. Fold its result into each pending baseline so it
        -- cannot be mistaken for the reward we are about to verify.
        for _, pending in ipairs(pendingRewardCompletions) do
            if pending.questId and serverCompletedQuests[pending.questId] then
                pending.completedBefore = true
            end
        end
        return
    end

    local completedQuerySerial = rewardCompletionQuerySerial
    rewardCompletionQueryInFlight = false

    for index = #pendingRewardCompletions, 1, -1 do
        local pending = pendingRewardCompletions[index]
        if pending.minimumQuerySerial <= completedQuerySerial then
            table.remove(pendingRewardCompletions, index)

            -- Require a false -> true transition for this exact quest ID. This
            -- prevents failed reward attempts and previously completed
            -- repeatable quests from being marked complete locally.
            if pending.questId and (not pending.completedBefore)
                and serverCompletedQuests[pending.questId] then
                CompleteRewardQuest(pending.questId)
            end
        end
    end

    -- A reward can be claimed while another completion query is in flight.
    -- Those newer entries require one additional batched query.
    ScheduleRewardCompletionQuery()
end

local DAILY_QUESTS_MSG = DAILY_QUESTS_REMAINING:gsub("%%d", "(%%d+)"):gsub("|4(.-)$", "")

function QuestieCompat:CHAT_MSG_SYSTEM(event, message)
    local questName = message:match(QUEST_COMPLETE_MSG)
    if questName then
        -- Preserve the existing fast path for ordinary quests. Only consume a
        -- title when it identifies one pending reward; same-title batches are
        -- left to exact-ID server confirmation instead of relying on order.
        local matchingIndex
        local matchingCount = 0
        for index, pending in ipairs(pendingRewardCompletions) do
            if pending.title == questName and pending.questId then
                matchingIndex = index
                matchingCount = matchingCount + 1
            end
        end

        if matchingCount == 1 then
            local questId = pendingRewardCompletions[matchingIndex].questId
            table.remove(pendingRewardCompletions, matchingIndex)
            CompleteRewardQuest(questId)
        end
    end

    if Questie.db.profile.resetDailyQuests then
        local dailyQuestCount = tonumber(message:match(DAILY_QUESTS_MSG))
        if dailyQuestCount and (dailyQuestCount == GetMaxDailyQuests()) then
            QuestieCompat.C_Timer.After(1, function()
                QuestieCompat.ResetDailyQuests(true)
            end)
        end
    end
end

function QuestieCompat.QuestEventHandler_RegisterEvents()
    QuestieCompat.frame:RegisterEvent("QUEST_QUERY_COMPLETE")
    QuestieCompat.frame:RegisterEvent("CHAT_MSG_SYSTEM")

    -- https://wowpedia.fandom.com/wiki/PLAYER_INTERACTION_MANAGER_FRAME_HIDE
    QuestieQuestEventFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    for _, event in pairs({
        "TRADE_CLOSED",
        "MERCHANT_CLOSED",
        "BANKFRAME_CLOSED",
        "GUILDBANKFRAME_CLOSED",
        "VENDOR_CLOSED",
        "MAIL_CLOSED",
        "AUCTION_HOUSE_CLOSED",
    }) do
        QuestieCompat.frame:RegisterEvent(event)
        QuestieCompat[event] = _QuestEventHandler.QuestRelatedFrameClosed
    end

    -- https://wowpedia.fandom.com/wiki/QUEST_TURNED_IN
    QuestieQuestEventFrame:UnregisterEvent("QUEST_TURNED_IN")
    hooksecurefunc("GetQuestReward", function(itemChoice)
        local questTitle = GetTitleText()
        if not questTitle or questTitle == "" then
            return
        end

        local questId = ResolveRewardQuestId(questTitle)
        pendingRewardCompletions[#pendingRewardCompletions + 1] = {
            title = questTitle,
            questId = questId,
            completedBefore = questId and (serverCompletedQuests[questId] or false) or false,
            -- The next query issued after this hook is the first one which can
            -- legitimately contain this completion.
            minimumQuerySerial = rewardCompletionQuerySerial + 1,
        }

        ScheduleRewardCompletionQuery()
    end)

    hooksecurefunc("SetAbandonQuest", function()
        QuestieCompat.abandonQuestID = select(9, GetQuestLogTitle(GetQuestLogSelection()))
    end)

    --https://wowpedia.fandom.com/wiki/QUEST_REMOVED
    QuestieQuestEventFrame:UnregisterEvent("QUEST_REMOVED")
    hooksecurefunc("AbandonQuest", function()
        local questId = QuestieCompat.abandonQuestID or select(9, GetQuestLogTitle(GetQuestLogSelection()))
        if questId and questId > 0 then
            _QuestEventHandler:QuestRemoved(questId, true)
        end
        QuestieCompat.abandonQuestID = nil
    end)
end

function QuestieCompat.InitializeQuestLogCompatibility()
    if questLogCompatibilityInitialized then return end
    questLogCompatibilityInitialized = true

    for k, patterns in pairs(chatMessagePattern) do
        for i, str in pairs(patterns) do
            chatMessagePattern[k][i] = QuestieLib:SanitizePattern(str)
        end
    end
end
