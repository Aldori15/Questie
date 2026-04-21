---@class AvailableQuests
local AvailableQuests = QuestieLoader:CreateModule("AvailableQuests")

---@type ThreadLib
local ThreadLib = QuestieLoader:ImportModule("ThreadLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieQuestBlacklist
local QuestieQuestBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
---@type IsleOfQuelDanas
local IsleOfQuelDanas = QuestieLoader:ImportModule("IsleOfQuelDanas")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type Comms
local Comms = QuestieLoader:ImportModule("Comms")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

local GetQuestGreenRange = GetQuestGreenRange
local GetQuestID = QuestieCompat.GetQuestID
local UnitGUID = QuestieCompat.UnitGUID
local yield = coroutine.yield
local tinsert = table.insert
local next = next
local time = time
local date = date
local tonumber = tonumber
local NewThread = ThreadLib.ThreadSimple

local QUESTS_PER_YIELD = 24
local QUESTS_PER_YIELD_FAST = 512
local questsPerYield = QUESTS_PER_YIELD
local isFastRefreshActive = false

--- Used to keep track of the active timer for CalculateAndDrawAll
---@type Ticker|nil
local timer
local timerStarted = false
local currentCallbacks = {}
local pendingRefreshRequested = false
local pendingFastRefresh = false
local pendingCallbacks = {}
local availableQuestStartTooltipsDirty = true

-- Keep track of all available quests to unload undoable when abandoning a quest
local availableQuests = {}
local nextAvailableQuests = {}
local availableQuestsByNpc = {}
local levelRequirementCache = {}
local unavailableQuestsDeterminedByTalking -- quests that were hidden after talking to an NPC
local unavailableQuestSyncState -- reset-aware unavailable daily/weekly quest snapshot by NPC
local unavailableQuestLookupDirty = true

AvailableQuests.levelRequirementCache = levelRequirementCache

local function _ClearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function _ShouldTrackNpcAvailability(questId)
    return QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId)
end

local function _ApplyRefreshSpeed(useFastRefresh)
    if useFastRefresh then
        questsPerYield = QUESTS_PER_YIELD_FAST
        isFastRefreshActive = true
    else
        questsPerYield = QUESTS_PER_YIELD
        isFastRefreshActive = false
    end
end

local function _RunCallbacks(callbacks)
    for i = 1, #callbacks do
        callbacks[i]()
        callbacks[i] = nil
    end
end

local function _QueueRefreshRequest(callback, fastRefresh)
    pendingRefreshRequested = true
    pendingFastRefresh = pendingFastRefresh or (fastRefresh == true)
    if callback then
        tinsert(pendingCallbacks, callback)
    end
end

local _StartQueuedRefresh

local function _HasVisibleSpawnInZone(spawns)
    if not spawns then
        return true
    end

    for _, spawn in pairs(spawns) do
        if Phasing.IsSpawnVisible(spawn[3]) then
            return true
        end
    end

    return false
end

local dungeons = ZoneDB:GetDungeons()
local function _CreateUnavailableQuestSyncBucket()
    return {
        nextReset = 0,
        byNpc = {},
        byQuest = {},
    }
end

local function _EnsureUnavailableQuestSyncBucket(syncState, bucketName)
    if type(syncState[bucketName]) ~= "table" then
        syncState[bucketName] = _CreateUnavailableQuestSyncBucket()
    end

    local bucket = syncState[bucketName]
    if type(bucket.byNpc) ~= "table" then
        bucket.byNpc = {}
    end
    if type(bucket.byQuest) ~= "table" then
        bucket.byQuest = {}
    end
    bucket.nextReset = tonumber(bucket.nextReset) or 0
    return bucket
end

local function _GetCurrentServerTimestamp()
    return QuestieCompat.GetServerTime()
end

local function _CalculateNextDailyResetTimestamp()
    local currentTimestamp = _GetCurrentServerTimestamp()
    local timeUntilReset = tonumber(GetQuestResetTime()) or 0
    if timeUntilReset < 0 then
        timeUntilReset = 0
    end
    return currentTimestamp + timeUntilReset
end

local function _CalculateNextWeeklyResetTimestamp()
    local currentTimestamp, currentDate = QuestieCompat.GetServerTime()
    local nextDailyReset = _CalculateNextDailyResetTimestamp()
    local dailyResetHour = tonumber(date("%H", nextDailyReset + 300)) or 0
    local weeklyResetDay = (Questie.db and Questie.db.profile and Questie.db.profile.weeklyResetDay) or 4
    local dayOffset = (weeklyResetDay - currentDate.weekday + 7) % 7
    if dayOffset == 0 and currentDate.hour >= dailyResetHour then
        dayOffset = 7
    end

    local nextWeeklyReset = time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day + dayOffset,
        hour = dailyResetHour,
    })

    return nextWeeklyReset or (currentTimestamp + 7 * 24 * 60 * 60)
end

local function _ResetUnavailableQuestBucketIfNeeded(bucket, nextResetCalculator, currentTimestamp)
    if bucket.nextReset == 0 then
        bucket.nextReset = nextResetCalculator()
        return false
    end

    if currentTimestamp >= bucket.nextReset then
        bucket.byNpc = {}
        bucket.byQuest = {}
        bucket.nextReset = nextResetCalculator()
        return true
    end

    return false
end

local function _RebuildUnavailableQuestLookup(syncState)
    unavailableQuestsDeterminedByTalking = {}

    local dailyBucket = _EnsureUnavailableQuestSyncBucket(syncState, "daily")
    local weeklyBucket = _EnsureUnavailableQuestSyncBucket(syncState, "weekly")

    for questId in pairs(dailyBucket.byQuest) do
        unavailableQuestsDeterminedByTalking[questId] = true
    end

    for questId in pairs(weeklyBucket.byQuest) do
        unavailableQuestsDeterminedByTalking[questId] = true
    end
end

local function _GetUnavailableQuestSyncState()
    local syncState
    if (not Questie.db) or (not Questie.db.global) then
        unavailableQuestSyncState = unavailableQuestSyncState or {}
        syncState = unavailableQuestSyncState
    else
        Questie.db.global.unavailableQuestSyncState = Questie.db.global.unavailableQuestSyncState or {}

        local realmName = GetRealmName()
        if type(Questie.db.global.unavailableQuestSyncState[realmName]) ~= "table" then
            Questie.db.global.unavailableQuestSyncState[realmName] = {}
        end

        syncState = Questie.db.global.unavailableQuestSyncState[realmName]
        unavailableQuestSyncState = syncState
    end

    local currentTimestamp = _GetCurrentServerTimestamp()
    local dailyReset = _ResetUnavailableQuestBucketIfNeeded(_EnsureUnavailableQuestSyncBucket(syncState, "daily"), _CalculateNextDailyResetTimestamp, currentTimestamp)
    local weeklyReset = _ResetUnavailableQuestBucketIfNeeded(_EnsureUnavailableQuestSyncBucket(syncState, "weekly"), _CalculateNextWeeklyResetTimestamp, currentTimestamp)
    if unavailableQuestLookupDirty or dailyReset or weeklyReset then
        _RebuildUnavailableQuestLookup(syncState)
        unavailableQuestLookupDirty = false
    end

    return syncState
end

---@return table<number, boolean>
local function _GetUnavailableQuestsDeterminedByTalking()
    _GetUnavailableQuestSyncState()
    unavailableQuestsDeterminedByTalking = unavailableQuestsDeterminedByTalking or {}
    return unavailableQuestsDeterminedByTalking
end

local function _GetUnavailableQuestBucketForQuest(syncState, questId)
    if QuestieDB.IsDailyQuest(questId) then
        return _EnsureUnavailableQuestSyncBucket(syncState, "daily")
    end

    if QuestieDB.IsWeeklyQuest(questId) then
        return _EnsureUnavailableQuestSyncBucket(syncState, "weekly")
    end
end

local function _IsQuestStillTrackedAsUnavailable(bucket, questId)
    for _, questIdsByNpc in pairs(bucket.byNpc) do
        if questIdsByNpc[questId] then
            return true
        end
    end
    return false
end

local function _StoreUnavailableQuestForToday(npcId, questId)
    local syncState = _GetUnavailableQuestSyncState()
    local bucket = _GetUnavailableQuestBucketForQuest(syncState, questId)
    if not bucket then
        return false
    end

    bucket.byNpc[npcId] = bucket.byNpc[npcId] or {}
    local wasNew = not bucket.byNpc[npcId][questId]
    bucket.byNpc[npcId][questId] = true
    bucket.byQuest[questId] = true
    unavailableQuestsDeterminedByTalking[questId] = true
    unavailableQuestLookupDirty = false

    return wasNew
end

local function _ClearUnavailableQuestForToday(npcId, questId)
    local syncState = _GetUnavailableQuestSyncState()
    local bucket = _GetUnavailableQuestBucketForQuest(syncState, questId)

    unavailableQuestsDeterminedByTalking[questId] = nil
    if not bucket then
        return false
    end

    local removed = false
    local questsByNpc = bucket.byNpc[npcId]
    if questsByNpc and questsByNpc[questId] then
        questsByNpc[questId] = nil
        removed = true
        if not next(questsByNpc) then
            bucket.byNpc[npcId] = nil
        end
    end

    if bucket.byQuest[questId] and (not _IsQuestStillTrackedAsUnavailable(bucket, questId)) then
        bucket.byQuest[questId] = nil
        removed = true
    end

    if removed then
        unavailableQuestLookupDirty = false
    end

    return removed
end

local _CalculateAvailableQuests, _DrawChildQuests, _AddStarter, _DrawAvailableQuest, _GetQuestIcon, _GetIconScaleForAvailable, _HasProperDistanceToAlreadyAddedSpawns, _RegisterQuestStartTooltips, _GetStructuredAvailableQuestsInGossip, _GetStructuredActiveQuestsInGossip, _RemoveQuestFromNpcAvailability, _SyncAvailableQuestDisplay, _HasLiveAvailableQuestFrames

---@param questId QuestId
---@param minLevel Level
---@param maxLevel Level
---@param playerLevel Level?
---@return boolean
function AvailableQuests.IsLevelRequirementsFulfilled(questId, minLevel, maxLevel, playerLevel)
    local cacheKey = questId .. ":" .. minLevel .. ":" .. maxLevel .. ":" .. (playerLevel or 0)
    if levelRequirementCache[cacheKey] ~= nil then
        return levelRequirementCache[cacheKey]
    end

    local isFulfilled = QuestieDB.IsLevelRequirementsFulfilled(questId, minLevel, maxLevel, playerLevel)
    levelRequirementCache[cacheKey] = isFulfilled
    return isFulfilled
end

function AvailableQuests.ResetLevelRequirementCache()
    levelRequirementCache = {}
    AvailableQuests.levelRequirementCache = levelRequirementCache
end

function AvailableQuests.MarkQuestStartTooltipsDirty()
    availableQuestStartTooltipsDirty = true
end

-- Repeatable quests should be controlled by showRepeatableQuests
local function _IsLevelRequirementsFulfilledForAvailable(questId, minLevel, maxLevel, playerLevel, isRepeatableQuest)
    if AvailableQuests.IsLevelRequirementsFulfilled(questId, minLevel, maxLevel, playerLevel) then
        return true
    end

    if isRepeatableQuest and Questie.db.profile.lowLevelStyle ~= Questie.LOWLEVEL_RANGE then
        return AvailableQuests.IsLevelRequirementsFulfilled(questId, 1, maxLevel, playerLevel)
    end

    return false
end

local function _IsHiddenByTrivialRepeatableSetting(questId, isRepeatableQuest, showTrivialRepeatableQuests)
    if (not isRepeatableQuest) or showTrivialRepeatableQuests then
        return false
    end

    local questLevel = QuestieDB.QueryQuestSingle(questId, "questLevel")
    return questLevel and QuestieDB.IsTrivial(questLevel)
end

_GetStructuredAvailableQuestsInGossip = function(npcGuid)
    local rawAvailableQuests = { QuestieCompat.GetAvailableQuests() }
    local availableQuestsInGossip = {}

    if type(rawAvailableQuests[1]) == "table" then
        for _, gossipQuest in pairs(rawAvailableQuests) do
            local questId = gossipQuest.questID
            if (not questId) or questId == 0 then
                questId = QuestieDB.GetQuestIDFromName(gossipQuest.title, npcGuid, true)
            end
            tinsert(availableQuestsInGossip, {
                questID = questId,
                title = gossipQuest.title,
            })
        end
    else
        for i = 1, #rawAvailableQuests, 7 do
            local title = rawAvailableQuests[i]
            if title then
                tinsert(availableQuestsInGossip, {
                    questID = QuestieDB.GetQuestIDFromName(title, npcGuid, true),
                    title = title,
                })
            end
        end
    end

    return availableQuestsInGossip
end

_GetStructuredActiveQuestsInGossip = function(npcGuid)
    local rawActiveQuests = { QuestieCompat.GetActiveQuests() }
    local activeQuests = {}

    if type(rawActiveQuests[1]) == "table" then
        for _, gossipQuest in pairs(rawActiveQuests) do
            local questId = gossipQuest.questID
            if (not questId) or questId == 0 then
                questId = QuestieDB.GetQuestIDFromName(gossipQuest.title, npcGuid, false)
            end
            tinsert(activeQuests, {
                questID = questId,
                title = gossipQuest.title,
            })
        end
    else
        for i = 1, #rawActiveQuests, 6 do
            local title = rawActiveQuests[i]
            if title then
                tinsert(activeQuests, {
                    questID = QuestieDB.GetQuestIDFromName(title, npcGuid, false),
                    title = title,
                })
            end
        end
    end

    return activeQuests
end

_StartQueuedRefresh = function()
    if timer or (not pendingRefreshRequested) then
        return
    end

    local useFastRefresh = pendingFastRefresh
    currentCallbacks = pendingCallbacks
    pendingCallbacks = {}
    pendingRefreshRequested = false
    pendingFastRefresh = false
    timerStarted = false

    _ApplyRefreshSpeed(useFastRefresh)

    timer = ThreadLib.Thread(function()
        timerStarted = true
        _CalculateAvailableQuests()
    end, 0, "Error in AvailableQuests.CalculateAndDrawAll", function()
        local callbacks = currentCallbacks
        currentCallbacks = {}
        timer = nil
        timerStarted = false
        _ApplyRefreshSpeed(false)
        _RunCallbacks(callbacks)
        _StartQueuedRefresh()
    end)
end

---@param callback function | nil
---@param fastRefresh boolean|nil
function AvailableQuests.CalculateAndDrawAll(callback, fastRefresh)
    Questie:Debug(Questie.DEBUG_INFO, "[AvailableQuests.CalculateAndDrawAll]")

    if timer then
        if not timerStarted then
            if fastRefresh and not isFastRefreshActive then
                _ApplyRefreshSpeed(true)
            end
            if callback then
                tinsert(currentCallbacks, callback)
            end
        else
            _QueueRefreshRequest(callback, fastRefresh)
        end
        return
    end

    _QueueRefreshRequest(callback, fastRefresh)
    _StartQueuedRefresh()
end

function AvailableQuests.RebuildAll(callback, fastRefresh)
    local questIds = {}

    for questId in pairs(availableQuests) do
        tinsert(questIds, questId)
    end

    for i = 1, #questIds do
        AvailableQuests.RemoveAvailableQuest(questIds[i])
    end

    AvailableQuests.CalculateAndDrawAll(callback, fastRefresh)
end

-- Recolor already drawn available-quest icons immediately on level changes
function AvailableQuests.RefreshVisibleAvailableIcons()
    for questId in pairs(QuestieMap.questIdFrames) do
        local questFrames = QuestieMap:GetFramesForQuest(questId)
        local oldIcon, newIcon

        for _, frame in pairs(questFrames) do
            if frame and frame.data and frame.data.Type == "available" and frame.data.QuestData then
                oldIcon = frame.data.Icon
                newIcon = _GetQuestIcon(frame.data.QuestData)
                break
            end
        end

        if newIcon and oldIcon and newIcon ~= oldIcon then
            for _, frame in pairs(questFrames) do
                if frame and frame.data and frame.data.Type == "available" and frame.data.QuestData then
                    frame:UpdateTexture(Questie.usedIcons[newIcon])
                    frame.data.Icon = newIcon
                end
            end
        end
    end
end

-- Remove currently shown available quests that no longer match the active level filter.
function AvailableQuests.PruneByCurrentLevelFilter()
    local playerLevel = QuestiePlayer.GetPlayerLevel()
    local minLevel = playerLevel - GetQuestGreenRange("player")
    local maxLevel = playerLevel
    local showTrivialRepeatableQuests = Questie.db.profile.showTrivialRepeatableQuests ~= false

    if Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_RANGE then
        minLevel = Questie.db.profile.minLevelFilter
        maxLevel = Questie.db.profile.maxLevelFilter
    elseif Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_OFFSET then
        minLevel = playerLevel - Questie.db.profile.manualLevelOffset
    end

    for questId in pairs(availableQuests) do
        local isRepeatableQuest = QuestieDB.IsRepeatable(questId)
        if _IsHiddenByTrivialRepeatableSetting(questId, isRepeatableQuest, showTrivialRepeatableQuests) or
            (not _IsLevelRequirementsFulfilledForAvailable(questId, minLevel, maxLevel, playerLevel, isRepeatableQuest)) then
            AvailableQuests.RemoveAvailableQuest(questId)
        end
    end
end

--Draw a single available quest, it is used by the CalculateAndDrawAll function.
---@param quest Quest
function AvailableQuests.DrawAvailableQuest(quest) -- prevent recursion
    --? Some quests can be started by an item, NPC, and/or a GameObject

    if Questie.db.profile.showItemStartQuests and quest.Starts["Item"] then
        local items = quest.Starts["Item"]
        for i = 1, #items do
            local item = QuestieDB:GetItem(items[i])
            if item then
                if item.npcDrops then
                    for _, npcId in pairs(item.npcDrops) do
                        local npc = QuestieDB:GetNPC(npcId)
                        if npc then
                            _AddStarter(npc, quest, "im_" .. npcId)
                        end
                    end
                end

                if item.objectDrops then
                    for _, objectId in pairs(item.objectDrops) do
                        local object = QuestieDB:GetObject(objectId)
                        if object then
                            _AddStarter(object, quest, "io_" .. objectId)
                        end
                    end
                end
            end
        end
    end

    if quest.Starts["GameObject"] then
        local gameObjects = quest.Starts["GameObject"]
        for i = 1, #gameObjects do
            local obj = QuestieDB:GetObject(gameObjects[i])
            if obj then
                _AddStarter(obj, quest, "o_" .. obj.id)
            end
        end
    end
    if (quest.Starts["NPC"]) then
        local npcs = quest.Starts["NPC"]
        local trackNpcAvailability = _ShouldTrackNpcAvailability(quest.Id)
        for i = 1, #npcs do
            local npc = QuestieDB:GetNPC(npcs[i])

            if npc then
                if trackNpcAvailability then
                    if (not availableQuestsByNpc[npc.id]) then
                        availableQuestsByNpc[npc.id] = {}
                    end
                    availableQuestsByNpc[npc.id][quest.Id] = true
                end

                _AddStarter(npc, quest, "m_" .. npc.id)
            end
        end
    end
end

_RemoveQuestFromNpcAvailability = function(questId, quest)
    if (not quest) or (not quest.Starts) or (not quest.Starts["NPC"]) or (not _ShouldTrackNpcAvailability(questId)) then
        return
    end

    local npcs = quest.Starts["NPC"]
    for i = 1, #npcs do
        local npcId = npcs[i]
        if availableQuestsByNpc[npcId] then
            availableQuestsByNpc[npcId][questId] = nil
            if not next(availableQuestsByNpc[npcId]) then
                availableQuestsByNpc[npcId] = nil
            end
        end
    end
end

---@param questId QuestId
function AvailableQuests.RemoveAvailableQuest(questId)
    availableQuests[questId] = nil
    _RemoveQuestFromNpcAvailability(questId, QuestieDB.GetQuest(questId))
    QuestieMap:UnloadQuestFrames(questId, nil, "available")
    QuestieTooltips:RemoveAvailableQuest(questId)
end

---@param questId QuestId
function AvailableQuests.RemoveQuest(questId)
    availableQuests[questId] = nil
    _RemoveQuestFromNpcAvailability(questId, QuestieDB.GetQuest(questId))
    QuestieMap:UnloadQuestFrames(questId)
    QuestieTooltips:RemoveQuest(questId)
end

---@param npcId NpcId
---@param questIds QuestId[]
function AvailableQuests.RemoveQuestsForToday(npcId, questIds)
    _GetUnavailableQuestsDeterminedByTalking()

    local removedAnyQuest = false
    for _, questId in pairs(questIds) do
        if availableQuests[questId] or QuestieMap.questIdFrames[questId] or QuestieTooltips.lookupKeysByQuestId[questId] then
            AvailableQuests.RemoveAvailableQuest(questId)
            removedAnyQuest = true
        end
        if availableQuestsByNpc[npcId] then
            availableQuestsByNpc[npcId][questId] = nil
        end
        _StoreUnavailableQuestForToday(npcId, questId)
    end

    if removedAnyQuest then
        AvailableQuests.CalculateAndDrawAll(nil, true)
    end
end

local function _BuildUnavailableQuestSnapshotEntries(bucket)
    local snapshotEntries = {}
    for npcId, questIdsByNpc in pairs(bucket.byNpc) do
        local questIds = {}
        for questId in pairs(questIdsByNpc) do
            tinsert(questIds, questId)
        end

        if next(questIds) then
            tinsert(snapshotEntries, {
                npcId = npcId,
                questIds = questIds,
            })
        end
    end

    return snapshotEntries
end

function AvailableQuests.GetUnavailableQuestSnapshot()
    local syncState = _GetUnavailableQuestSyncState()
    local snapshot = {
        daily = _BuildUnavailableQuestSnapshotEntries(syncState.daily),
        weekly = _BuildUnavailableQuestSnapshotEntries(syncState.weekly),
    }

    if (not next(snapshot.daily)) and (not next(snapshot.weekly)) then
        return nil
    end

    return snapshot
end

function AvailableQuests.MergeUnavailableQuestSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    local mergedAnyQuest = false
    for _, bucketName in pairs({ "daily", "weekly" }) do
        local bucketEntries = snapshot[bucketName]
        if type(bucketEntries) == "table" then
            for _, entry in pairs(bucketEntries) do
                local npcId = entry.npcId
                local questIds = entry.questIds
                if npcId and type(questIds) == "table" then
                    local newQuestIds = {}
                    for _, questId in pairs(questIds) do
                        local syncState = _GetUnavailableQuestSyncState()
                        local bucket = _GetUnavailableQuestBucketForQuest(syncState, questId)
                        local alreadyKnown = bucket and bucket.byNpc[npcId] and bucket.byNpc[npcId][questId]
                        if not alreadyKnown then
                            tinsert(newQuestIds, questId)
                        end
                    end

                    if next(newQuestIds) then
                        AvailableQuests.RemoveQuestsForToday(npcId, newQuestIds)
                        mergedAnyQuest = true
                    end
                end
            end
        end
    end

    return mergedAnyQuest
end

---@type string|nil
local lastNpcGuid

--- Called on GOSSIP_SHOW to hide all quests that are not available from the NPC.
function AvailableQuests.ValidateAvailableQuestsFromGossipShow()
    _GetUnavailableQuestsDeterminedByTalking()

    local npcGuid = UnitGUID("target")
    if (not npcGuid) then
        return
    end

    local _, _, _, _, _, npcIDStr = strsplit("-", npcGuid)
    if (not npcIDStr) then
        return
    end

    local npcId = tonumber(npcIDStr)
    if lastNpcGuid == npcGuid then
        return
    end

    lastNpcGuid = npcGuid

    local availableQuestsInGossip = _GetStructuredAvailableQuestsInGossip(npcGuid)

    -- validate no quest is incorrectly hidden
    for _, gossipQuest in pairs(availableQuestsInGossip) do
        local questId = gossipQuest.questID
        if unavailableQuestsDeterminedByTalking[questId] then
            _ClearUnavailableQuestForToday(npcId, questId)
            local quest = QuestieDB.GetQuest(questId)
            if quest then
                availableQuests[questId] = true
                AvailableQuests.DrawAvailableQuest(quest)
            end
        end
    end

    -- Active quests are relevant, because the API can fire GOSSIP_SHOW before QUEST_ACCEPTED.
    -- So we need to check active quests to not hide them incorrectly for the day.
    local activeQuests = _GetStructuredActiveQuestsInGossip(npcGuid)
    local unavailableQuestsToBroadcast = {}
    for questId in pairs(availableQuestsByNpc[npcId] or {}) do
        local isAvailableInGossip = false
        for _, gossipQuest in pairs(availableQuestsInGossip) do
            if gossipQuest.questID == questId then
                isAvailableInGossip = true
                break
            end
        end
        for _, gossipQuest in pairs(activeQuests) do
            if gossipQuest.questID == questId then
                isAvailableInGossip = true
                break
            end
        end

        if (not isAvailableInGossip) and (QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId)) then
            tinsert(unavailableQuestsToBroadcast, questId)
        end
    end

    if next(unavailableQuestsToBroadcast) then
        AvailableQuests.RemoveQuestsForToday(npcId, unavailableQuestsToBroadcast)
        Comms.BroadcastUnavailableDailyQuests(npcId, unavailableQuestsToBroadcast)
    end
end

--- Called on QUEST_DETAIL to hide all quests that are not available from the NPC.
--- This is relevant on NPCs which offer random quests each day and especially a different number of quests.
function AvailableQuests.ValidateAvailableQuestsFromQuestDetail()
    _GetUnavailableQuestsDeterminedByTalking()

    local npcGuid = UnitGUID("target")
    if (not npcGuid) then
        return
    end

    local _, _, _, _, _, npcIDStr = strsplit("-", npcGuid)
    if (not npcIDStr) then
        return
    end

    local npcId = tonumber(npcIDStr)
    if lastNpcGuid == npcGuid then
        return
    end

    lastNpcGuid = npcGuid

    -- Hide all quests but the current one
    local availableQuestId = GetQuestID(true)
    if availableQuestId == 0 then
        -- GetQuestID returns 0 when the dialog is closed. Nothing left to do for us
        return
    end

    -- validate quest is not incorrectly hidden
    if unavailableQuestsDeterminedByTalking[availableQuestId] then
        _ClearUnavailableQuestForToday(npcId, availableQuestId)
        local quest = QuestieDB.GetQuest(availableQuestId)
        if quest then
            availableQuests[availableQuestId] = true
            AvailableQuests.DrawAvailableQuest(quest)
        end
    end

    local unavailableQuestsToBroadcast = {}
    for questId in pairs(availableQuestsByNpc[npcId] or {}) do
        if questId ~= availableQuestId and (QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId)) then
            tinsert(unavailableQuestsToBroadcast, questId)
        end
    end

    if next(unavailableQuestsToBroadcast) then
        AvailableQuests.RemoveQuestsForToday(npcId, unavailableQuestsToBroadcast)
        Comms.BroadcastUnavailableDailyQuests(npcId, unavailableQuestsToBroadcast)
    end
end

--- Called on QUEST_GREETING to hide all quests that are not available from the NPC.
--- This is relevant on NPCs which offer random quests each day and especially a different number of quests.
function AvailableQuests.ValidateAvailableQuestsFromQuestGreeting()
    _GetUnavailableQuestsDeterminedByTalking()

    local npcGuid = UnitGUID("target")
    if (not npcGuid) then
        return
    end

    local _, _, _, _, _, npcIDStr = strsplit("-", npcGuid)
    if (not npcIDStr) then
        return
    end

    local npcId = tonumber(npcIDStr)
    if lastNpcGuid == npcGuid then
        return
    end

    lastNpcGuid = npcGuid

    local availableQuestsInGreeting = {}
    for i = 1, MAX_NUM_QUESTS do
        local titleLine = _G["QuestTitleButton" .. i]
        if (not titleLine) then
            break
        elseif titleLine:IsVisible() then
            local title
            local isActive = titleLine.isActive == 1
            if isActive then
                -- Active quests are relevant, because the API can fire QUEST_GREETING before QUEST_ACCEPTED.
                -- So we need to check active quests to not hide them incorrectly for the day.
                title = GetActiveTitle(titleLine:GetID())
            else
                title = GetAvailableTitle(titleLine:GetID())
            end
            local questId = QuestieDB.GetQuestIDFromName(title, npcGuid, (not isActive))
            if questId and questId > 0 then
                availableQuestsInGreeting[questId] = true
            end
        end
    end

    -- validate no quest is incorrectly hidden
    for questId in pairs(availableQuestsInGreeting) do
        if unavailableQuestsDeterminedByTalking[questId] then
            _ClearUnavailableQuestForToday(npcId, questId)
            local quest = QuestieDB.GetQuest(questId)
            if quest then
                availableQuests[questId] = true
                AvailableQuests.DrawAvailableQuest(quest)
            end
        end
    end

    local unavailableQuestsToBroadcast = {}
    for questId in pairs(availableQuestsByNpc[npcId] or {}) do
        if (not availableQuestsInGreeting[questId]) and (QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId)) then
            tinsert(unavailableQuestsToBroadcast, questId)
        end
    end

    if next(unavailableQuestsToBroadcast) then
        AvailableQuests.RemoveQuestsForToday(npcId, unavailableQuestsToBroadcast)
        Comms.BroadcastUnavailableDailyQuests(npcId, unavailableQuestsToBroadcast)
    end
end

_CalculateAvailableQuests = function()
    local maxQuestsPerYield = questsPerYield
    local unavailableQuests = _GetUnavailableQuestsDeterminedByTalking()
    local previousAvailableQuests = availableQuests
    availableQuests = nextAvailableQuests
    nextAvailableQuests = previousAvailableQuests
    _ClearTable(availableQuests)
    local nextAvailableQuestSet = availableQuests

    -- Localize the variables for speeeeed
    local debugEnabled = Questie.db.profile.debugEnabled

    local questData = QuestieDB.QuestPointers or QuestieDB.questData

    local playerLevel = QuestiePlayer.GetPlayerLevel()
    local minLevel = playerLevel - GetQuestGreenRange("player")
    local maxLevel = playerLevel

    if Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_RANGE then
        minLevel = Questie.db.profile.minLevelFilter
        maxLevel = Questie.db.profile.maxLevelFilter
    elseif Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_OFFSET then
        minLevel = playerLevel - Questie.db.profile.manualLevelOffset
    end

    local completedQuests = Questie.db.char.complete
    local showRepeatableQuests = Questie.db.profile.showRepeatableQuests
    local showTrivialRepeatableQuests = Questie.db.profile.showTrivialRepeatableQuests ~= false
    local showDungeonQuests = Questie.db.profile.showDungeonQuests
    local showRaidQuests = Questie.db.profile.showRaidQuests
    local showPvPQuests = Questie.db.profile.showPvPQuests
    local showAQWarEffortQuests = Questie.db.profile.showAQWarEffortQuests

    local autoBlacklist = QuestieDB.autoBlacklist
    local hiddenQuests = QuestieCorrections.hiddenQuests
    local hidden = Questie.db.char.hidden

    local currentQuestlog = QuestiePlayer.currentQuestlog
    local currentIsleOfQuelDanasQuests = IsleOfQuelDanas.quests[Questie.db.profile.isleOfQuelDanasPhase] or {}
    local aqWarEffortQuests = QuestieQuestBlacklist.AQWarEffortQuests

    QuestieDB.activeChildQuests = {} -- Reset here so we don't need to keep track in the quest event system

    -- We create a local function here to improve readability but use the localized variables above.
    -- The order of checks is important here to bring the speed to a max
    local function _CheckAvailability(questId)
        local isRepeatableQuest = QuestieDB.IsRepeatable(questId)

        if (autoBlacklist[questId] or -- Don't show autoBlacklist quests marked as such by IsDoable
            completedQuests[questId] or -- Don't show completed quests
            hiddenQuests[questId] or -- Don't show blacklisted quests
            hidden[questId] or -- Don't show quests hidden by the player
            unavailableQuests[questId] -- Don't show quests hidden after talking to an NPC
        ) then
            nextAvailableQuestSet[questId] = nil
            return
        end

        if currentQuestlog[questId] then
            _DrawChildQuests(questId, currentQuestlog, completedQuests, hiddenQuests, hidden, unavailableQuests, nextAvailableQuestSet)

            if QuestieDB.IsComplete(questId) ~= -1 then -- The quest in the quest log is not failed, so we don't show it as available
                nextAvailableQuestSet[questId] = nil
                return
            end
        end

        if (
            ((not showRepeatableQuests) and isRepeatableQuest) or                   -- Don't show repeatable quests if option is disabled
            ((not showPvPQuests) and QuestieDB.IsPvPQuest(questId)) or              -- Don't show PvP quests if option is disabled
            ((not showDungeonQuests) and QuestieDB.IsDungeonQuest(questId)) or      -- Don't show dungeon quests if option is disabled
            ((not showRaidQuests) and QuestieDB.IsRaidQuest(questId)) or            -- Don't show raid quests if option is disabled
            ((not showAQWarEffortQuests) and aqWarEffortQuests[questId]) or         -- Don't show AQ War Effort quests if the option disabled
            (Questie.IsClassic and currentIsleOfQuelDanasQuests[questId]) or        -- Don't show Isle of Quel'Danas quests for Era/HC/SoX
            (Questie.IsSoD and QuestieDB.IsRuneAndShouldBeHidden(questId))          -- Don't show SoD Rune quests with the option disabled
        ) then
            nextAvailableQuestSet[questId] = nil
            return
        end

        if _IsHiddenByTrivialRepeatableSetting(questId, isRepeatableQuest, showTrivialRepeatableQuests) then
            nextAvailableQuestSet[questId] = nil
            return
        end

        if (
            (not _IsLevelRequirementsFulfilledForAvailable(questId, minLevel, maxLevel, playerLevel, isRepeatableQuest)) or
            (not QuestieDB.IsDoable(questId, debugEnabled))
        ) then
            --If the quests are not within level range we want to unload them
            --(This is for when people level up or change settings etc)
            nextAvailableQuestSet[questId] = nil
            return
        end

        nextAvailableQuestSet[questId] = true
    end

    local questCount = 0
    for questId in pairs(questData) do
        _CheckAvailability(questId)

        -- Reset the questCount
        questCount = questCount + 1
        if questCount > maxQuestsPerYield then
            questCount = 0
            yield()
        end
    end

    _SyncAvailableQuestDisplay(previousAvailableQuests, availableQuests, maxQuestsPerYield)
end

_SyncAvailableQuestDisplay = function(previousAvailableQuests, nextAvailableQuests, maxQuestsPerYield)
    local questCount = 0

    for questId in pairs(previousAvailableQuests) do
        if not nextAvailableQuests[questId] then
            AvailableQuests.RemoveAvailableQuest(questId)
        end

        questCount = questCount + 1
        if questCount > maxQuestsPerYield then
            questCount = 0
            yield()
        end
    end

    local shouldRestoreStartTooltips = availableQuestStartTooltipsDirty
    questCount = 0
    for questId in pairs(nextAvailableQuests) do
        local hasLiveFrames = _HasLiveAvailableQuestFrames(questId)
        if (not previousAvailableQuests[questId]) or (not hasLiveFrames) then
            _DrawAvailableQuest(questId)
        elseif shouldRestoreStartTooltips then
            _RegisterQuestStartTooltips(QuestieDB.GetQuest(questId))
        end

        questCount = questCount + 1
        if questCount > maxQuestsPerYield then
            questCount = 0
            yield()
        end
    end

    if shouldRestoreStartTooltips then
        availableQuestStartTooltipsDirty = false
    end
end

---@param questId QuestId
---@return boolean
_HasLiveAvailableQuestFrames = function(questId)
    for _, frame in pairs(QuestieMap:GetFramesForQuest(questId)) do
        if frame and frame.data and frame.data.Type == "available" then
            return true
        end
    end

    return false
end

---@param quest Quest|nil
_RegisterQuestStartTooltips = function(quest)
    if (not quest) or (not quest.Starts) then
        return
    end

    local items = Questie.db.profile.showItemStartQuests and quest.Starts["Item"]
    if items then
        for i = 1, #items do
            local item = QuestieDB:GetItem(items[i])
            if item then
                if item.npcDrops then
                    for _, npcId in pairs(item.npcDrops) do
                        local npc = QuestieDB:GetNPC(npcId)
                        if npc then
                            local tooltipKey = "m_" .. npc.id
                            local tooltipId = tostring(quest.Id) .. " " .. npc.name .. " " .. npc.id
                            if (not QuestieTooltips.lookupByKey[tooltipKey]) or (not QuestieTooltips.lookupByKey[tooltipKey][tooltipId]) then
                                QuestieTooltips:RegisterQuestStartTooltip(quest.Id, npc.name, npc.id, tooltipKey, "itemFromMonster")
                            end
                        end
                    end
                end

                if item.objectDrops then
                    for _, objectId in pairs(item.objectDrops) do
                        local object = QuestieDB:GetObject(objectId)
                        if object then
                            local tooltipKey = "o_" .. object.id
                            local tooltipId = tostring(quest.Id) .. " " .. object.name .. " " .. object.id
                            if (not QuestieTooltips.lookupByKey[tooltipKey]) or (not QuestieTooltips.lookupByKey[tooltipKey][tooltipId]) then
                                QuestieTooltips:RegisterQuestStartTooltip(quest.Id, object.name, object.id, tooltipKey, "itemFromObject")
                            end
                        end
                    end
                end
            end
        end
    end

    local gameObjects = quest.Starts["GameObject"]
    if gameObjects then
        for i = 1, #gameObjects do
            local obj = QuestieDB:GetObject(gameObjects[i])
            if obj then
                local tooltipKey = "o_" .. obj.id
                local tooltipId = tostring(quest.Id) .. " " .. obj.name .. " " .. obj.id
                if (not QuestieTooltips.lookupByKey[tooltipKey]) or (not QuestieTooltips.lookupByKey[tooltipKey][tooltipId]) then
                    QuestieTooltips:RegisterQuestStartTooltip(quest.Id, obj.name, obj.id, tooltipKey, "Object")
                end
            end
        end
    end

    local npcs = quest.Starts["NPC"]
    if npcs then
        for i = 1, #npcs do
            local npc = QuestieDB:GetNPC(npcs[i])
            if npc then
                local tooltipKey = "m_" .. npc.id
                local tooltipId = tostring(quest.Id) .. " " .. npc.name .. " " .. npc.id
                if (not QuestieTooltips.lookupByKey[tooltipKey]) or (not QuestieTooltips.lookupByKey[tooltipKey][tooltipId]) then
                    QuestieTooltips:RegisterQuestStartTooltip(quest.Id, npc.name, npc.id, tooltipKey, "NPC")
                end
            end
        end
    end
end

--- Mark all child quests as active when the parent quest is in the quest log
--- Reused this logic in QuestsByZone.lua/QuestsByFaction.lua -- TO DO: copy logic to QBF
--- if this is modified, also make sure the changes are reflected in the other file
---@param questId number
---@param currentQuestlog table<number, boolean>
---@param completedQuests table<number, boolean>
---@param hiddenQuests table<number, boolean>
---@param hidden table<number, boolean>
---@param unavailableQuests table<number, boolean>
---@param availableQuestSet table<number, boolean>
_DrawChildQuests = function(questId, currentQuestlog, completedQuests, hiddenQuests, hidden, unavailableQuests, availableQuestSet)
    local childQuests = QuestieDB.QueryQuestSingle(questId, "childQuests")
    if (not childQuests) then
        return
    end

    for _, childQuestId in pairs(childQuests) do
        local requiredRaces = QuestieDB.QueryQuestSingle(childQuestId, "requiredRaces")
        if (not completedQuests[childQuestId]) and
            (not currentQuestlog[childQuestId]) and
            (not hiddenQuests[childQuestId]) and
            (not hidden[childQuestId]) and
            (not unavailableQuests[childQuestId]) and
            (QuestiePlayer.HasRequiredRace(requiredRaces))
        then
            local childQuestExclusiveTo = QuestieDB.QueryQuestSingle(childQuestId, "exclusiveTo")
            local blockedByExclusiveTo = false
            for _, exclusiveToQuestId in pairs(childQuestExclusiveTo or {}) do
                if QuestiePlayer.currentQuestlog[exclusiveToQuestId] or completedQuests[exclusiveToQuestId] then
                    blockedByExclusiveTo = true
                    break
                end
            end
            if (not blockedByExclusiveTo) then
                local isPreQuestSingleFulfilled = true
                local isPreQuestGroupFulfilled = true

                local preQuestSingle = QuestieDB.QueryQuestSingle(childQuestId, "preQuestSingle")
                if preQuestSingle then
                    isPreQuestSingleFulfilled = QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
                else
                    local preQuestGroup = QuestieDB.QueryQuestSingle(childQuestId, "preQuestGroup")
                    if preQuestGroup then
                        isPreQuestGroupFulfilled = QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
                    end
                end

                if isPreQuestSingleFulfilled and isPreQuestGroupFulfilled then
                    QuestieDB.activeChildQuests[childQuestId] = true
                    availableQuestSet[childQuestId] = true
                    -- Mark them here so the draw pass can render them even if their
                    -- questId was processed earlier in the availability pass.
                end
            end
        end
    end
end

---@param questId number
_DrawAvailableQuest = function(questId)
    local function _DrawNow()
        local quest = QuestieDB.GetQuest(questId)
        if (not quest.tagInfoWasCached) then
            QuestieDB.GetQuestTagInfo(questId) -- cache to load in the tooltip

            quest.tagInfoWasCached = true
        end

        AvailableQuests.DrawAvailableQuest(quest)
    end

    if isFastRefreshActive then
        _DrawNow()
        return
    end

    NewThread(_DrawNow, 0)
end

---@param quest Quest
_GetQuestIcon = function(quest)
    if Questie.IsSoD == true and QuestieDB.IsSoDRuneQuest(quest.Id) then
        return Questie.ICON_TYPE_SODRUNE
    elseif QuestieDB.IsActiveEventQuest(quest.Id) then
        return Questie.ICON_TYPE_EVENTQUEST
    end
    if QuestieDB.IsPvPQuest(quest.Id) then
        return Questie.ICON_TYPE_PVPQUEST
    end
    if quest.requiredLevel > QuestiePlayer.GetPlayerLevel() then
        return Questie.ICON_TYPE_AVAILABLE_GRAY
    end
    if quest.IsRepeatable then
        return Questie.ICON_TYPE_REPEATABLE
    end
    if (QuestieDB.IsTrivial(quest.level)) then
        return Questie.ICON_TYPE_AVAILABLE_GRAY
    end
    return Questie.ICON_TYPE_AVAILABLE
end

---@param starter table Either an object or an NPC
---@param quest Quest
---@param tooltipKey string the tooltip key. For objects it's "o_<ID>", for NPCs it's "m_<ID>"
_AddStarter = function(starter, quest, tooltipKey)
    if (not starter) then
        return
    end

    -- Need to know when this quest starts from an item, so we save it later
    ---@type string|nil
    local starterType

    if tooltipKey == "m_" .. starter.id then
        -- filter hostile starters
        if playerFaction == "Alliance" and starter.friendlyToFaction == "H" then
            return 0
        elseif playerFaction == "Horde" and starter.friendlyToFaction == "A" then
            return 0
        end
    elseif tooltipKey == "im_" .. starter.id then
        -- We don't filter items by faction, because Questie can not differentiate neutral NPCs from friendly ones.
        -- overwrite tooltipKey, so stuff shows in monster tooltips
        tooltipKey = "m_" .. starter.id
        starterType = "itemFromMonster"
    elseif tooltipKey == "o_" .. starter.id then
        starterType = "Object"
    elseif tooltipKey == "io_" .. starter.id then
        -- overwrite tooltipKey, so stuff shows in object tooltips
        tooltipKey = "o_" .. starter.id
        starterType = "itemFromObject"
    end

    QuestieTooltips:RegisterQuestStartTooltip(quest.Id, starter.name, starter.id, tooltipKey, (starterType or "NPC"))

    local starterIcons = {}
    local starterLocs = {}
    local visibleStarterZones = {}
    for zone, spawns in pairs(starter.spawns or {}) do
        local alreadyAddedSpawns = {}
        if (zone and spawns) then
            local coords
            for spawnIndex = 1, #spawns do
                coords = spawns[spawnIndex]
                if Phasing.IsSpawnVisible(coords[3]) and (#spawns == 1 or _HasProperDistanceToAlreadyAddedSpawns(coords, alreadyAddedSpawns)) then
                    visibleStarterZones[zone] = true

                    local data = {
                        Id = quest.Id,
                        Icon = _GetQuestIcon(quest),
                        GetIconScale = _GetIconScaleForAvailable,
                        IconScale = _GetIconScaleForAvailable(),
                        Type = "available",
                        QuestData = quest,
                        Name = starter.name,
                        IsObjectiveNote = false,
                    }

                    if (coords[1] == -1 or coords[2] == -1) then
                        local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
                        if dungeonLocation then
                            for _, value in ipairs(dungeonLocation) do
                                QuestieMap:DrawWorldIcon(data, value[1], value[2], value[3])
                            end
                        end
                    else
                        local icon = QuestieMap:DrawWorldIcon(data, zone, coords[1], coords[2], coords[3])
                        if starter.waypoints and icon then
                            -- This is only relevant for waypoint drawing
                            starterIcons[zone] = icon
                            if not starterLocs[zone] then
                                starterLocs[zone] = { coords[1], coords[2] }
                            end
                        end
                        tinsert(alreadyAddedSpawns, coords)
                    end
                end
            end
        end
    end

    -- Only for NPCs since objects do not move
    if starter.waypoints then
        for zone, waypoints in pairs(starter.waypoints or {}) do
            if (visibleStarterZones[zone] or (not starter.spawns) or (not starter.spawns[zone]) or _HasVisibleSpawnInZone(starter.spawns[zone])) and
                (not dungeons[zone]) and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                if not starterIcons[zone] then
                    local data = {
                        Id = quest.Id,
                        Icon = _GetQuestIcon(quest),
                        GetIconScale = _GetIconScaleForAvailable,
                        IconScale = _GetIconScaleForAvailable(),
                        Type = "available",
                        QuestData = quest,
                        Name = starter.name,
                        IsObjectiveNote = false,
                    }
                    starterIcons[zone] = QuestieMap:DrawWorldIcon(data, zone, waypoints[1][1][1], waypoints[1][1][2])
                    starterLocs[zone] = { waypoints[1][1][1], waypoints[1][1][2] }
                end
                QuestieMap:DrawWaypoints(starterIcons[zone], waypoints, zone)
            end
        end
    end
end

_HasProperDistanceToAlreadyAddedSpawns = function(coords, alreadyAddedSpawns)
    for _, alreadyAdded in pairs(alreadyAddedSpawns) do
        local distance = QuestieLib.GetSpawnDistance(alreadyAdded, coords)
        -- 29 seems like a good distance. The "Undying Laborer" in Westfall shows both spawns for the "Horn of Lordaeron" rune
        if distance < 29 then
            return false
        end
    end
    return true
end

_GetIconScaleForAvailable = function()
    return Questie.db.profile.availableScale or 1.3
end

return AvailableQuests
