---@class CommsVisibility : QuestieModule
local CommsVisibility = QuestieLoader:CreateModule("CommsVisibility")

-------------------------
--Import modules.
-------------------------
---@type QuestieSerializer
local QuestieSerializer = QuestieLoader:ImportModule("QuestieSerializer")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local C_QuestLog = QuestieCompat.C_QuestLog
local GetGroupUnitByName = QuestieCompat.GetGroupUnitByName
local GetNumGroupMembers = QuestieCompat.GetNumGroupMembers

local VISIBILITY_PREFIX = "QuestieV1"
local MAX_GROUP_SIZE = 5
local DEFAULT_MAX_SNAPSHOT_ENTRIES = 75

local remoteVisibility = {}
local snapshotTimer
local maxSnapshotEntries = DEFAULT_MAX_SNAPSHOT_ENTRIES
local initialized = false

local function _CancelSnapshotTimer()
    if snapshotTimer then
        snapshotTimer:Cancel()
        snapshotTimer = nil
    end
end

local function _GetPartyObjectives()
    -- Avoid relying on file load order. QuestieLoader creates an import placeholder
    -- before QuestiePartyObjectives.lua is loaded, which is safe by the time this
    -- function is called after addon initialization.
    return QuestieLoader:ImportModule("QuestiePartyObjectives")
end

local function _GetDistribution()
    local groupType = QuestiePlayer:GetGroupType()
    if groupType == "party" then
        return "PARTY"
    elseif groupType == "raid" then
        return "RAID"
    end

    -- 3.3.5 has no instance-chat distribution. Do not send a visibility
    -- snapshot to an instance group through a modern-only API.
    return nil
end

local function _CanSend()
    local memberCount = GetNumGroupMembers()
    return memberCount > 0 and memberCount <= MAX_GROUP_SIZE and _GetDistribution() ~= nil
end

local function _BuildSnapshot()
    local snapshot = {}
    local hidden = Questie.db.char.hidden

    for questId in pairs(QuestLogCache.questLog_DO_NOT_MODIFY) do
        if type(questId) == "number" then
            if hidden and hidden[questId] then
                snapshot[questId] = false
            else
                snapshot[questId] = QuestieQuest:IsQuestTracked(questId) and true or false
            end
        end
    end

    return snapshot
end

local function _ValidateSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local entryCount = 0
    for questId, visible in pairs(snapshot) do
        entryCount = entryCount + 1
        if entryCount > maxSnapshotEntries
            or type(questId) ~= "number"
            or questId <= 0
            or questId % 1 ~= 0
            or type(visible) ~= "boolean" then
            return nil
        end
    end

    return snapshot
end

local function _IsGroupSender(sender, distribution)
    if not sender or sender == UnitName("player") then
        return false
    end

    if distribution ~= "PARTY" and distribution ~= "RAID" and distribution ~= "WHISPER" then
        return false
    end

    return GetGroupUnitByName(sender) ~= nil
end

local function _SendSnapshot()
    snapshotTimer = nil

    if not _CanSend() then
        return
    end

    local distribution = _GetDistribution()
    local serialized = QuestieSerializer:Serialize(_BuildSnapshot())
    if not serialized then
        return
    end

    Questie:SendCommMessage(VISIBILITY_PREFIX, serialized, distribution, nil, "NORMAL")
end

---@param reason string|nil
function CommsVisibility:ScheduleSnapshot(reason)
    if not initialized then
        return
    end

    _CancelSnapshotTimer()
    if not _CanSend() then
        return
    end

    -- Debounce rapid quest-log/tracker events into one snapshot. NewTicker is
    -- used because it is the timer API provided by the 3.3.5 compatibility shim.
    snapshotTimer = C_Timer.NewTicker(1.0, _SendSnapshot, 1)
end

function CommsVisibility:Initialize()
    if initialized then
        return
    end

    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        maxSnapshotEntries = C_QuestLog.GetMaxNumQuestsCanAccept() or DEFAULT_MAX_SNAPSHOT_ENTRIES
    end

    Questie:RegisterComm(VISIBILITY_PREFIX, CommsVisibility.OnCommReceived)
    initialized = true
end

---@param prefix string
---@param message string
---@param distribution string
---@param sender string
function CommsVisibility.OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= VISIBILITY_PREFIX or not message or not _IsGroupSender(sender, distribution) then
        return
    end

    local success, snapshot = pcall(QuestieSerializer.Deserialize, QuestieSerializer, message)
    if not success then
        return
    end

    snapshot = _ValidateSnapshot(snapshot)
    if not snapshot then
        return
    end

    -- Replace the complete snapshot atomically. A missing quest entry means
    -- nothing is known about that quest, so ShouldShowPartyObjective defaults
    -- to visible for compatibility with older Questie clients.
    remoteVisibility[sender] = snapshot
    _GetPartyObjectives():ScheduleUpdate()
end

---@param playerName string
---@param questId number
---@return boolean
function CommsVisibility:ShouldShowPartyObjective(playerName, questId)
    local snapshot = remoteVisibility[playerName]
    if not snapshot then
        return true
    end

    return snapshot[questId] == true
end

function CommsVisibility:PruneRemotePlayers()
    for playerName in pairs(remoteVisibility) do
        if not GetGroupUnitByName(playerName) then
            remoteVisibility[playerName] = nil
        end
    end
end

function CommsVisibility:ResetAll()
    _CancelSnapshotTimer()
    wipe(remoteVisibility)
end

CommsVisibility.remoteVisibility = remoteVisibility
