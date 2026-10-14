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
---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type MinimapIcon
local MinimapIcon = QuestieLoader:ImportModule("MinimapIcon")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestXP
local QuestXP = QuestieLoader:ImportModule("QuestXP")
local QuestieServer = QuestieLoader:ImportModule("QuestieServer")

local math_max = math.max
local bitband = bit.band
local strfind = string.find
local questLogCompatibilityInitialized = false
local questObjectivesCache = {}
local uiInfoChangedQuestIds = {}
local QUEST_OBJECTIVE_CACHE_TTL_SECONDS = 3
local QUEST_FLAGS_NO_MONEY_FROM_XP = 0x100

-- Keep the raw server snapshot before repeatable quests are filtered from
-- Questie.db.char.complete. Reward confirmation accesses it through the
-- helpers below, so replacing this table cannot leave a stale shared reference.
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
            for objectiveIndex, objective in ipairs(objectives) do
                if objective and objective.type == "item" and normalizeObjectiveName(objective.text) == objectiveName then
                    if QuestLogCache.ApplyObjectiveProgress(questId, objectiveIndex, numFulfilled) then
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
-- A batch can reuse membership without repeatedly searching the client log.
-- Discard this snapshot before yielding so the next batch sees log changes.
---@return table<QuestId, boolean>
function QuestieCompat.GetQuestLogQuestIds()
    local questIds = {}
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if not title then
            break
        end
        if not isHeader and id then
            questIds[id] = true
        end
    end
    return questIds
end

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
    local questLevel, _ = QuestieLib.GetEffectiveQuestLevel(questId);
    return QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
end

local function shouldInsertQuestIdForChatCommand()
    local activeWindow = ChatEdit_GetActiveWindow()
    if not activeWindow then
        return false
    end

    local text = activeWindow:GetText()
    return type(text) == "string" and string.match(text, "^%s*[./!]") ~= nil
end

function QuestieCompat:GetQuestInsertString(questLevel, questName, questId)
    if shouldInsertQuestIdForChatCommand() then
        return QuestieCompat.GetQuestLink(questId) or tostring(questId)
    end

    return QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
end

function QuestieCompat:GetQuestInsertStringById(questId)
    if shouldInsertQuestIdForChatCommand() then
        return QuestieCompat.GetQuestLink(questId) or tostring(questId)
    end

    return QuestieCompat:GetQuestLinkStringById(questId)
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

    local live = QuestieServer.GetQuestMoneyRates and QuestieServer:GetQuestMoneyRates()
    if live then
        -- Costs remain unscaled. Ordinary rewards and the capped-level bonus
        -- have independent rates and are each truncated before being added.
        local normal = rewardMoney < 0 and rewardMoney or QuestXP:ScaleRewardMoney(rewardMoney, live.normal)
        local bonus = 0
        if playerLevel >= live.maxLevel then
            local questFlags = QuestieDB.QueryQuestSingle(questID, "questFlags") or 0
            if bitband(questFlags, QUEST_FLAGS_NO_MONEY_FROM_XP) == 0 then
                local baseXP = QuestXP:GetQuestLogRewardXP(questID, true, true, live.maxLevel)
                bonus = QuestXP:ScaleRewardMoney(baseXP * 6, live.bonus)
            end
        end
        if normal and bonus then
            local total = normal + bonus
            if total >= -2147483648 and total <= 2147483647 then return total end
        end
        -- Unsupported conversions retain the complete generated fallback.
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

---@param questId number
function QuestieCompat.ClearQuestCompletion(questId)
    Questie.db.char.complete[questId] = nil
    serverCompletedQuests[questId] = nil
end

function QuestieCompat.ClearServerDailyQuestCompletions()
    for questId in pairs(serverCompletedQuests) do
        if QuestieDB.IsDailyQuest(questId) then
            QuestieCompat.ClearQuestCompletion(questId)
        end
    end
end

function QuestieCompat.SetQuestComplete(questId)
    local isDailyQuest = QuestieDB.IsDailyQuest(questId)
    if isDailyQuest then
        -- Expire yesterday's records before adding today's completion.
        QuestieCompat.ResetDailyQuests()
    end

    if (not QuestieDB.IsRepeatable(questId)) then
        Questie.db.char.complete[questId] = true
    end

    if Questie.db.profile.resetDailyQuests then
        if isDailyQuest then
            Questie.db.char.daily[questId] = true
            Questie.db.char.complete[questId] = true
        elseif QuestieDB.IsWeeklyQuest(questId) then
            QuestieCompat.ResetWeeklyQuests()
            Questie.db.char.weekly[questId] = true
            Questie.db.char.complete[questId] = true
        elseif QuestieDB.IsMonthlyQuest(questId) then
            QuestieCompat.ResetMonthlyQuests()
            Questie.db.char.monthly[questId] = true
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

---Raw completion evidence for reward confirmation; excludes saved completion flags.
---@param questId number
---@return boolean
function QuestieCompat.HasRawServerQuestCompletion(questId)
    return serverCompletedQuests[questId] == true
end

---Record an exact-ID reward after confirmation.
---@param questId number
function QuestieCompat.RecordServerQuestCompletion(questId)
    serverCompletedQuests[questId] = true
end

local function EnsureAzerothCoreDailyCompletionReset()
    Questie.db.char.acoreDailyQuestCompletions = Questie.db.char.acoreDailyQuestCompletions or {}
    QuestieCompat.ResetDailyQuests()
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
    -- Expire old caches before applying the authoritative server response.
    QuestieCompat.ResetDailyQuests()
    GetQuestsCompleted(Questie.db.char.complete)

    serverCompletedQuests = {}
    for questId in pairs(Questie.db.char.complete) do
        serverCompletedQuests[questId] = true
    end

    -- Process reward turn-ins before repeatable quests are filtered from the
    -- raw server completion table.
    QuestieCompat.ProcessPendingRewardCompletions()

    for questId in pairs(Questie.db.char.complete) do
        if QuestieDB.IsRepeatable(questId) then
            Questie.db.char.complete[questId] = nil
        end
    end

    if Questie.db.profile.resetDailyQuests then
        QuestieCompat.CalculateNextResetTime()
        QuestieCompat.ResetDailyQuests()
        QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.daily)

        if QuestiePlayer.GetPlayerLevel() >= 78 then
            QuestieCompat.ResetWeeklyQuests()
            QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.weekly)
        end

        QuestieCompat.ResetMonthlyQuests()
        QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.monthly)
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

local function syncObjectiveProgressFromUiInfoMessage(allowFullFallback, forceFullFallback)
    local hasTargetedChanges = false
    for questId in pairs(uiInfoChangedQuestIds) do
        uiInfoChangedQuestIds[questId] = nil
        hasTargetedChanges = true
        QuestieQuest:SetObjectivesDirty(questId)
        QuestieQuest:UpdateQuest(questId)
    end

    local didSync = hasTargetedChanges
    if forceFullFallback or ((not hasTargetedChanges) and allowFullFallback) then
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
        -- The 3.3.5 quest log can still be stale during the early refresh. Run a
        -- second full scan for objective types that cannot use the item-specific
        -- targeted update, such as hidden monster credits for scripted objectives.
        syncObjectiveProgressFromUiInfoMessage(true, true)
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
function QuestieCompat:CHAT_MSG_SYSTEM(event, message)
    QuestieCompat.HandleQuestRewardMessage(message)
    QuestieCompat.HandleDailyQuestResetMessage(message)
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
    QuestieCompat.RegisterQuestRewardCompletionHook()

    hooksecurefunc("SetAbandonQuest", function()
        QuestieCompat.abandonQuestID = select(9, GetQuestLogTitle(GetQuestLogSelection()))
    end)

    --https://wowpedia.fandom.com/wiki/QUEST_REMOVED
    QuestieQuestEventFrame:UnregisterEvent("QUEST_REMOVED")
    hooksecurefunc("AbandonQuest", function()
        local questId = QuestieCompat.abandonQuestID or select(9, GetQuestLogTitle(GetQuestLogSelection()))
        if questId and questId > 0 then
            QuestieCompat.MarkPendingQuestRewardAbandoned(questId)
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
