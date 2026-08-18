---@class DailyQuestComms
local DailyQuestComms = QuestieLoader:CreateModule("DailyQuestComms")

---@class CommEvent
---@field eventName "HideDailyQuests"|"RequestUnavailableQuestState"|"SyncUnavailableQuestState"
---@field data? { npcId: NpcId, questIds: QuestId[] }|UnavailableQuestSnapshot

local AceSerializer = LibStub("AceSerializer-3.0")
local IsInGuild = IsInGuild
local IsInGroup = QuestieCompat.IsInGroup
local IsInRaid = QuestieCompat.IsInRaid
local C_Timer = QuestieCompat.C_Timer

local COMM_PREFIX = "Questie"
local UNAVAILABLE_QUEST_SYNC_REQUEST_ATTEMPTS = 60
local UNAVAILABLE_QUEST_SYNC_REQUEST_INTERVAL = 0.5
local UNAVAILABLE_QUEST_RESPONSE_WINDOW = 8
local MAX_UNAVAILABLE_QUEST_MESSAGE_BYTES = 64 * 1024
local MAX_UNAVAILABLE_QUEST_NPCS = 256
local MAX_UNAVAILABLE_QUESTS_PER_NPC = 128
local MAX_UNAVAILABLE_QUESTS_TOTAL = 2048

local playerName
local realmName
local requestedUnavailableQuestSnapshot
local unavailableQuestSnapshotRequestTicker
local commsAudienceFrame
local pendingUnavailableQuestResponses = {}

---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local function _IsPositiveInteger(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
end

local function _IsExpectedUnavailableQuest(questId, bucketName)
    if bucketName == "daily" then
        return QuestieDB.IsDailyQuest(questId)
    elseif bucketName == "weekly" then
        return QuestieDB.IsWeeklyQuest(questId)
    end

    return QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId)
end

local function _ValidateUnavailableQuestIds(questIds, bucketName)
    if type(questIds) ~= "table" then
        return nil, "quest IDs are not a table"
    end

    local validatedQuestIds = {}
    local seenQuestIds = {}
    local entryCount = 0
    for _, questId in pairs(questIds) do
        entryCount = entryCount + 1
        if entryCount > MAX_UNAVAILABLE_QUESTS_PER_NPC then
            return nil, "too many quest IDs for one NPC"
        end
        if (not _IsPositiveInteger(questId)) or (not _IsExpectedUnavailableQuest(questId, bucketName)) then
            return nil, "invalid daily or weekly quest ID"
        end
        if not seenQuestIds[questId] then
            seenQuestIds[questId] = true
            validatedQuestIds[#validatedQuestIds + 1] = questId
        end
    end

    if #validatedQuestIds == 0 then
        return nil, "quest ID list is empty"
    end

    return validatedQuestIds
end

local function _ValidateUnavailableQuestSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil, "snapshot is not a table"
    end

    local validatedSnapshot = {daily = {}, weekly = {}}
    local npcCount = 0
    local questCount = 0
    for _, bucketName in pairs({"daily", "weekly"}) do
        local bucketEntries = snapshot[bucketName]
        if bucketEntries ~= nil and type(bucketEntries) ~= "table" then
            return nil, bucketName .. " snapshot is not a table"
        end

        for _, entry in pairs(bucketEntries or {}) do
            npcCount = npcCount + 1
            if npcCount > MAX_UNAVAILABLE_QUEST_NPCS then
                return nil, "too many NPC entries"
            end
            if type(entry) ~= "table" or not _IsPositiveInteger(entry.npcId) then
                return nil, "invalid NPC entry"
            end

            local questIds, validationError = _ValidateUnavailableQuestIds(entry.questIds, bucketName)
            if not questIds then
                return nil, validationError
            end

            questCount = questCount + #questIds
            if questCount > MAX_UNAVAILABLE_QUESTS_TOTAL then
                return nil, "too many quest IDs"
            end

            validatedSnapshot[bucketName][#validatedSnapshot[bucketName] + 1] = {
                npcId = entry.npcId,
                questIds = questIds,
            }
        end
    end

    return validatedSnapshot
end

local function _LogRejectedUnavailableQuestPayload(sender, reason)
    Questie.Debug(Questie.DEBUG_DEVELOP,
        "[DailyQuestComms.OnCommReceived] Rejected unavailable quest payload from", sender or "unknown", reason)
end

local function _CreateEmptyUnavailableQuestSnapshot()
    return {daily = {}, weekly = {}}
end

local function _GetOrCreateSnapshotEntry(snapshot, bucketName, npcId)
    for _, entry in pairs(snapshot[bucketName]) do
        if entry.npcId == npcId then
            return entry
        end
    end

    local entry = {npcId = npcId, questIds = {}}
    snapshot[bucketName][#snapshot[bucketName] + 1] = entry
    return entry
end

local function _AddUnavailableQuestsToSnapshot(snapshot, npcId, questIds)
    for _, questId in pairs(questIds) do
        local bucketName = QuestieDB.IsDailyQuest(questId) and "daily" or "weekly"
        local entry = _GetOrCreateSnapshotEntry(snapshot, bucketName, npcId)
        local alreadyKnown = false
        for _, knownQuestId in pairs(entry.questIds) do
            if knownQuestId == questId then
                alreadyKnown = true
                break
            end
        end
        if not alreadyKnown then
            entry.questIds[#entry.questIds + 1] = questId
        end
    end
end

local function _CanSendToDistribution(distribution)
    if distribution == "GUILD" then
        return IsInGuild()
    elseif distribution == "RAID" then
        return IsInRaid()
    elseif distribution == "PARTY" then
        return IsInGroup() and not IsInRaid()
    end
    return false
end

local function _CancelPendingUnavailableQuestResponse(distribution)
    local pendingResponse = pendingUnavailableQuestResponses[distribution]
    if pendingResponse then
        if pendingResponse.timer then
            pendingResponse.timer:Cancel()
        end
        pendingUnavailableQuestResponses[distribution] = nil
    end
end

local function _SendUnavailableQuestSnapshot(snapshot, distribution)
    for _, bucketName in pairs({"daily", "weekly"}) do
        for _, entry in pairs(snapshot[bucketName] or {}) do
            local event = {
                eventName = "HideDailyQuests",
                data = {
                    npcId = entry.npcId,
                    questIds = entry.questIds,
                },
            }
            local serializedEvent = AceSerializer:Serialize(event)
            Questie:SendCommMessage(COMM_PREFIX, serializedEvent, distribution)
        end
    end
end

local function _ScheduleUnavailableQuestResponse(distribution, requesterSnapshot)
    _CancelPendingUnavailableQuestResponse(distribution)

    if not AvailableQuests.GetUnavailableQuestSnapshotDelta(requesterSnapshot) then
        return
    end

    local pendingResponse = {knownSnapshot = requesterSnapshot}
    pendingUnavailableQuestResponses[distribution] = pendingResponse
    pendingResponse.timer = C_Timer.NewTimer(math.random() * UNAVAILABLE_QUEST_RESPONSE_WINDOW, function()
        if pendingUnavailableQuestResponses[distribution] ~= pendingResponse then
            return
        end
        pendingUnavailableQuestResponses[distribution] = nil

        if not _CanSendToDistribution(distribution) then
            return
        end

        local delta = AvailableQuests.GetUnavailableQuestSnapshotDelta(pendingResponse.knownSnapshot)
        if delta then
            Questie.Debug(Questie.DEBUG_DEVELOP, "[DailyQuestComms] Answering unavailable quest request on", distribution)
            _SendUnavailableQuestSnapshot(delta, distribution)
        end
    end)
end

local function _RecordPendingUnavailableQuestBroadcast(distribution, npcId, questIds)
    local pendingResponse = pendingUnavailableQuestResponses[distribution]
    if not pendingResponse then
        return
    end

    _AddUnavailableQuestsToSnapshot(pendingResponse.knownSnapshot, npcId, questIds)
    if not AvailableQuests.GetUnavailableQuestSnapshotDelta(pendingResponse.knownSnapshot) then
        Questie.Debug(Questie.DEBUG_DEVELOP, "[DailyQuestComms] Cancelling covered unavailable quest response on", distribution)
        _CancelPendingUnavailableQuestResponse(distribution)
    end
end

local function _SendSerializedEventToAvailableChannels(serializedEvent, askGuild)
    local sent = false
    if askGuild ~= false and IsInGuild() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "GUILD")
        sent = true
    end

    if IsInRaid() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "RAID")
        sent = true
    elseif IsInGroup() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "PARTY")
        sent = true
    end

    return sent
end

local function _HasUnavailableQuestSyncAudience()
    return IsInGuild() or IsInRaid() or IsInGroup()
end

local function _IsUnavailableQuestBroadcastDistribution(distribution)
    return distribution == "GUILD" or distribution == "RAID" or distribution == "PARTY"
end

local function _StartInitialUnavailableQuestSyncRequest()
    if unavailableQuestSnapshotRequestTicker then
        unavailableQuestSnapshotRequestTicker:Cancel()
        unavailableQuestSnapshotRequestTicker = nil
    end

    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(UNAVAILABLE_QUEST_SYNC_REQUEST_INTERVAL, function()
        attempts = attempts + 1
        if DailyQuestComms.RequestUnavailableQuestState() or attempts >= UNAVAILABLE_QUEST_SYNC_REQUEST_ATTEMPTS then
            local finishedTicker = ticker
            if ticker then
                ticker:Cancel()
                ticker = nil
            end
            if unavailableQuestSnapshotRequestTicker == finishedTicker then
                unavailableQuestSnapshotRequestTicker = nil
            end
        end
    end)
    unavailableQuestSnapshotRequestTicker = ticker
end

local function _StopInitialUnavailableQuestSyncRequest()
    if unavailableQuestSnapshotRequestTicker then
        unavailableQuestSnapshotRequestTicker:Cancel()
        unavailableQuestSnapshotRequestTicker = nil
    end
end

local function _RefreshUnavailableQuestSyncRequest()
    if requestedUnavailableQuestSnapshot then
        _StopInitialUnavailableQuestSyncRequest()
        return
    end

    if _HasUnavailableQuestSyncAudience() then
        if not unavailableQuestSnapshotRequestTicker then
            _StartInitialUnavailableQuestSyncRequest()
        end
    else
        _StopInitialUnavailableQuestSyncRequest()
    end
end

function DailyQuestComms.Initialize()
    Questie:RegisterComm(COMM_PREFIX, DailyQuestComms.OnCommReceived)

    playerName = UnitName("player")
    realmName = GetRealmName()
    requestedUnavailableQuestSnapshot = false

    if not commsAudienceFrame then
        commsAudienceFrame = CreateFrame("Frame")
        commsAudienceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if QuestieCompat.Is335 then
            commsAudienceFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
            commsAudienceFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        else
            commsAudienceFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        end
        commsAudienceFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
        commsAudienceFrame:SetScript("OnEvent", _RefreshUnavailableQuestSyncRequest)
    end

    _RefreshUnavailableQuestSyncRequest()
end

function DailyQuestComms.CancelPendingUnavailableQuestGroupResponses()
    _CancelPendingUnavailableQuestResponse("PARTY")
    _CancelPendingUnavailableQuestResponse("RAID")
end

---@param prefix string
---@param message string
---@param distribution string
---@param sender string
function DailyQuestComms.OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then
        return
    end

    if type(message) ~= "string" or #message > MAX_UNAVAILABLE_QUEST_MESSAGE_BYTES then
        _LogRejectedUnavailableQuestPayload(sender, "invalid message size")
        return
    end

    local isBroadcastDistribution = _IsUnavailableQuestBroadcastDistribution(distribution)
    if (not isBroadcastDistribution) and distribution ~= "WHISPER" then
        return
    end

    if sender == playerName or sender == (playerName .. "-" .. realmName) then
        return
    end

    local success, event = AceSerializer:Deserialize(message)
    if (not success) or (type(event) ~= "table") then
        return
    end

    Questie.Debug(Questie.DEBUG_DEVELOP, "[DailyQuestComms.OnCommReceived] Received", event.eventName, "from", sender, "on", distribution)

    if event.eventName == "SyncUnavailableQuestState" then
        if distribution ~= "WHISPER" then
            return
        end
    elseif not isBroadcastDistribution then
        return
    end

    if event.eventName == "HideDailyQuests" then
        if type(event.data) ~= "table" then
            _LogRejectedUnavailableQuestPayload(sender, "daily quest data is not a table")
            return
        end

        local npcId = event.data.npcId
        if not _IsPositiveInteger(npcId) then
            _LogRejectedUnavailableQuestPayload(sender, "invalid NPC ID")
            return
        end

        local questIds, validationError = _ValidateUnavailableQuestIds(event.data.questIds)
        if not questIds then
            _LogRejectedUnavailableQuestPayload(sender, validationError)
            return
        end

        _RecordPendingUnavailableQuestBroadcast(distribution, npcId, questIds)
        AvailableQuests.RemoveQuestsForToday(npcId, questIds)
        return
    end

    if event.eventName == "RequestUnavailableQuestState" then
        local requesterSnapshot = _CreateEmptyUnavailableQuestSnapshot()
        if event.data ~= nil then
            local validationError
            requesterSnapshot, validationError = _ValidateUnavailableQuestSnapshot(event.data)
            if not requesterSnapshot then
                _LogRejectedUnavailableQuestPayload(sender, validationError)
                return
            end
        end

        AvailableQuests.MergeUnavailableQuestSnapshot(requesterSnapshot)
        _ScheduleUnavailableQuestResponse(distribution, requesterSnapshot)
        return
    end

    if event.eventName == "SyncUnavailableQuestState" then
        local snapshot, validationError = _ValidateUnavailableQuestSnapshot(event.data)
        if not snapshot then
            _LogRejectedUnavailableQuestPayload(sender, validationError)
            return
        end

        AvailableQuests.MergeUnavailableQuestSnapshot(snapshot)
    end
end

---@param npcId NpcId
---@param questIds QuestId[]
function DailyQuestComms.BroadcastUnavailableDailyQuests(npcId, questIds)
    ---@type CommEvent
    local event = {
        eventName = "HideDailyQuests",
        data = {
            npcId = npcId,
            questIds = questIds
        }
    }

    local serializedEvent = AceSerializer:Serialize(event)
    _SendSerializedEventToAvailableChannels(serializedEvent)
end

---@param askGuild boolean|nil Include the guild channel; defaults to true.
---@param force boolean|nil Send even if the initial login request already succeeded.
function DailyQuestComms.RequestUnavailableQuestState(askGuild, force)
    if requestedUnavailableQuestSnapshot and not force then
        return false
    end

    ---@type CommEvent
    local event = {
        eventName = "RequestUnavailableQuestState",
        data = AvailableQuests.GetUnavailableQuestSnapshot() or _CreateEmptyUnavailableQuestSnapshot(),
    }

    local serializedEvent = AceSerializer:Serialize(event)
    if not _SendSerializedEventToAvailableChannels(serializedEvent, askGuild) then
        return false
    end

    Questie.Debug(Questie.DEBUG_DEVELOP, "[DailyQuestComms.RequestUnavailableQuestState] Requested unavailable quests; askGuild:", askGuild ~= false)
    requestedUnavailableQuestSnapshot = true
    _StopInitialUnavailableQuestSyncRequest()
    return true
end

---@param target string
function DailyQuestComms.SendUnavailableQuestState(target)
    local snapshot = AvailableQuests.GetUnavailableQuestSnapshot()
    if (not snapshot) then
        return
    end

    ---@type CommEvent
    local event = {
        eventName = "SyncUnavailableQuestState",
        data = snapshot,
    }

    local serializedEvent = AceSerializer:Serialize(event)
    Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "WHISPER", target)
end
