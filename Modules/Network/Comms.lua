---@class Comms
local Comms = QuestieLoader:CreateModule("Comms")

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

local playerName
local realmName
local requestedUnavailableQuestSnapshot
local unavailableQuestSnapshotRequestTicker
local commsAudienceFrame

---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")

local function _SendSerializedEventToAvailableChannels(serializedEvent)
    if IsInGuild() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "GUILD")
    end

    if IsInRaid() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "RAID")
    elseif IsInGroup() then
        Questie:SendCommMessage(COMM_PREFIX, serializedEvent, "PARTY")
    end
end

local function _HasUnavailableQuestSyncAudience()
    return IsInGuild() or IsInRaid() or IsInGroup()
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
        if Comms.RequestUnavailableQuestState() or attempts >= UNAVAILABLE_QUEST_SYNC_REQUEST_ATTEMPTS then
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

function Comms.Initialize()
    Questie:RegisterComm(COMM_PREFIX, Comms.OnCommReceived)

    playerName = UnitName("player")
    realmName = GetRealmName()
    requestedUnavailableQuestSnapshot = false

    if not commsAudienceFrame then
        commsAudienceFrame = CreateFrame("Frame")
        commsAudienceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        commsAudienceFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        commsAudienceFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
        commsAudienceFrame:SetScript("OnEvent", _RefreshUnavailableQuestSyncRequest)
    end

    _RefreshUnavailableQuestSyncRequest()
end

---@param prefix string
---@param message string
---@param distribution string
---@param sender string
function Comms.OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then
        return
    end

    if sender == playerName or sender == (playerName .. "-" .. realmName) then
        return
    end

    local success, event = AceSerializer:Deserialize(message)
    if (not success) or (type(event) ~= "table") then
        return
    end

    if event.eventName == "HideDailyQuests" and event.data and type(event.data) == "table" then
        local npcId = event.data.npcId
        if (not npcId) then
            return
        end

        local questIds = event.data.questIds
        if (not questIds) or type(questIds) ~= "table" then
            return
        end

        AvailableQuests.RemoveQuestsForToday(npcId, questIds)
        return
    end

    if event.eventName == "RequestUnavailableQuestState" then
        Comms.SendUnavailableQuestState(sender)
        return
    end

    if event.eventName == "SyncUnavailableQuestState" and event.data and type(event.data) == "table" then
        AvailableQuests.MergeUnavailableQuestSnapshot(event.data)
    end
end

---@param npcId NpcId
---@param questIds QuestId[]
function Comms.BroadcastUnavailableDailyQuests(npcId, questIds)
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

function Comms.RequestUnavailableQuestState()
    if requestedUnavailableQuestSnapshot or (not _HasUnavailableQuestSyncAudience()) then
        return false
    end

    requestedUnavailableQuestSnapshot = true
    _StopInitialUnavailableQuestSyncRequest()

    ---@type CommEvent
    local event = {
        eventName = "RequestUnavailableQuestState",
    }

    local serializedEvent = AceSerializer:Serialize(event)
    _SendSerializedEventToAvailableChannels(serializedEvent)
    return true
end

---@param target string
function Comms.SendUnavailableQuestState(target)
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

return Comms
