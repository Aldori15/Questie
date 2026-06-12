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
local strfind = string.find
local questLogCompatibilityInitialized = false
local questObjectivesCache = {}
local uiInfoChangedQuestIds = {}
local QUEST_OBJECTIVE_CACHE_TTL_SECONDS = 3

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

    if rewardMoney < 0 then -- required money
        return rewardMoney
    end

    local playerLevel = QuestiePlayer.GetPlayerLevel()
    if playerLevel > 0 and rewardMoneyDifficulty > 0 then
        rewardMoney = QuestieCompat.QuestMoneyReward[playerLevel][rewardMoneyDifficulty]
    end

    -- https://wowpedia.fandom.com/wiki/Quest?oldid=1035002 Formula is XP gained * 6c
    if QuestiePlayer.IsMaxLevel() then
        local xpReward = QuestXP:GetQuestLogRewardXP(questID, true)
        if xpReward > 0 then
            rewardMoney = rewardMoney + xpReward*6
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
        end
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

-- Fires when the data requested by QueryQuestsCompleted() is available.
-- https://wowpedia.fandom.com/wiki/QUEST_QUERY_COMPLETE
function QuestieCompat:QUEST_QUERY_COMPLETE(event)
    GetQuestsCompleted(Questie.db.char.complete)

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
    local currentMembers = QuestieCompat.IsInRaid() and GetNumRaidMembers() or GetNumPartyMembers()
    -- Only want to do logic when number increases, not decreases.
    if QuestiePlayer.numberOfGroupMembers < currentMembers then
        if QuestiePlayer.numberOfGroupMembers == 0 then
            _EventHandler:GroupJoined()
        end
        -- Tell comms to send information to members.
        --Questie:SendMessage("QC_ID_BROADCAST_FULL_QUESTLIST")
        QuestiePlayer.numberOfGroupMembers = currentMembers
    else
        if currentMembers == 0 then
            _EventHandler:GroupLeft()
        end
        -- We do however always want the local to be the current number to allow up and down.
        QuestiePlayer.numberOfGroupMembers = currentMembers
    end
end

local _QuestEventHandler = QuestEventHandler.private
local QUEST_COMPLETE_MSG = string.gsub(ERR_QUEST_COMPLETE_S, "(%%s)", "(.+)")
local completeQuestCache = {}

local DAILY_QUESTS_MSG = DAILY_QUESTS_REMAINING:gsub("%%d", "(%%d+)"):gsub("|4(.-)$", "")

function QuestieCompat:CHAT_MSG_SYSTEM(event, message)
    local questName = message:match(QUEST_COMPLETE_MSG)
    local questId = completeQuestCache[questName]
    if questId then
        _QuestEventHandler:QuestTurnedIn(questId)
        _QuestEventHandler:QuestRemoved(questId)
        completeQuestCache[questName] = nil
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
        local questId = QuestieCompat.GetQuestIDFromName(questTitle)
        if questId and questId > 0 then
            completeQuestCache[questTitle] = questId
        end
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
