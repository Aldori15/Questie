---@class QuestiePlayerbots
local QuestiePlayerbots = QuestieLoader:CreateModule("QuestiePlayerbots")
---@type QuestieComms
local QuestieComms = QuestieLoader:ImportModule("QuestieComms")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestiePartyObjectives
local QuestiePartyObjectives = QuestieLoader:ImportModule("QuestiePartyObjectives")

local PREFIX = "MBOT"
local PROTOCOL_VERSION = "1"

local eventFrame
local helloTimeoutAt
local rosterSyncAt

local bridgeReady = false
local helloPending = false

local bridgeCapabilities = {}
local progressSnapshots = {}
local pendingRequests = {}
local trackedBots = {}
local appliedQuestStates = {}

local requestSequence = 0
local ROSTER_SYNC_DELAY = 0.5
local HELLO_TIMEOUT = 3.0

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF4DDBFF[Questie Playerbots]|r " .. tostring(message))
end

local function SplitFields(value)
    local fields = {}
    local startIndex = 1

    value = value or ""

    while true do
        local separatorIndex = string.find(value, "~", startIndex, true)

        if not separatorIndex then
            fields[#fields + 1] = string.sub(value, startIndex)
            break
        end

        fields[#fields + 1] = string.sub(value, startIndex, separatorIndex - 1)
        startIndex = separatorIndex + 1
    end

    return fields
end

local function UrlDecode(value)
    if not value or value == "" then
        return ""
    end

    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16) or 0)
    end))
end

local function GetChannel()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return "RAID"
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        return "PARTY"
    end

    return "WHISPER"
end

local function Send(opcode, payload)
    local playerName = UnitName("player")
    if not playerName then
        return false
    end

    local message = opcode
    if payload and payload ~= "" then
        message = message .. "~" .. payload
    end

    local channel = GetChannel()

    if channel == "WHISPER" then
        SendAddonMessage(PREFIX, message, channel, playerName)
    else
        SendAddonMessage(PREFIX, message, channel)
    end

    return true
end

local function ProbeBridge()
    if helloPending then
        return
    end

    helloPending = true
    helloTimeoutAt = GetTime() + HELLO_TIMEOUT
    bridgeReady = false
    bridgeCapabilities = {}

    if not Send("HELLO", PROTOCOL_VERSION) then
        helloPending = false
        helloTimeoutAt = nil
    end
end

local function NextToken()
    requestSequence = requestSequence + 1
    return "qpb" .. tostring(requestSequence)
end

local function NormalizeName(name)
    if not name then
        return nil
    end

    return name:gsub("%-.*$", "")
end

local function RequestBotQuestProgress(botName)
    local token = NextToken()
    local payload = "QUEST_PROGRESS~" .. botName .. "~" .. token

    if bridgeCapabilities.QUEST_PROGRESS_PUSH_V1 then
        payload = payload .. "~WATCH"
    end

    pendingRequests[token] = true

    if not Send("GET", payload) then
        pendingRequests[token] = nil
    end
end

local function RequestGroupQuests()
    if not bridgeReady then
        return
    end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)

            if name and name ~= UnitName("player") then
                RequestBotQuestProgress(name)
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)

            if name then
                RequestBotQuestProgress(name)
            end
        end
    end
end

local function GetCurrentGroupMembers()
    local members = {}

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = NormalizeName(UnitName("raid" .. i))
            if name then
                members[name] = true
            end
        end
    else
        local playerName = NormalizeName(UnitName("player"))
        if playerName then
            members[playerName] = true
        end

        if GetNumPartyMembers then
            for i = 1, GetNumPartyMembers() do
                local name = NormalizeName(UnitName("party" .. i))
                if name then
                    members[name] = true
                end
            end
        end
    end

    return members
end

local function RemoveTrackedBot(botName)
    local affectedQuests = {}

    for questId, players in pairs(QuestieComms.remoteQuestLogs) do
        if players[botName] then
            affectedQuests[#affectedQuests + 1] = questId
        end
    end

    for _, questId in ipairs(affectedQuests) do
        local players = QuestieComms.remoteQuestLogs[questId]

        if players then
            players[botName] = nil
            QuestieComms.data:RemoveQuestFromPlayer(questId, botName)

            if not next(players) then
                QuestieComms.remoteQuestLogs[questId] = nil
            end

            QuestiePartyObjectives:ScheduleUpdate(questId)
        end
    end

    trackedBots[botName] = nil
    appliedQuestStates[botName] = nil
end

local function SyncGroupRoster()
    rosterSyncAt = nil

    if not bridgeReady then
        return
    end

    local members = GetCurrentGroupMembers()
    local departedBots = {}

    for botName in pairs(trackedBots) do
        if not members[botName] then
            departedBots[#departedBots + 1] = botName
        end
    end

    for _, botName in ipairs(departedBots) do
        RemoveTrackedBot(botName)
    end

    RequestGroupQuests()
end

local function ScheduleRosterSync()
    rosterSyncAt = GetTime() + ROSTER_SYNC_DELAY
end

local objectiveTypeMap = {
    m = "monster",
    o = "object",
    i = "item",
}

local function FindQuestieObjectiveIndex(questId, rawObjective, usedIndices)
    local quest = QuestieDB.GetQuest(questId)
    if not quest or not quest.ObjectiveData then
        return nil
    end

    local fullType = objectiveTypeMap[rawObjective.type]
    if not fullType then
        return nil
    end

    for objectiveIndex, objective in ipairs(quest.ObjectiveData) do
        if not usedIndices[objectiveIndex]
            and objective.Type == fullType
            and objective.Id == rawObjective.id then

            usedIndices[objectiveIndex] = true
            return objectiveIndex
        end
    end

    return nil
end

local function BuildQuestieQuestPacket(questId, questState)
    local questPacket = {
        id = questId,
        objectives = {},
    }

    local usedIndices = {}

    for _, rawObjective in ipairs(questState.objectives) do
        local objectiveIndex = FindQuestieObjectiveIndex(questId, rawObjective, usedIndices)

        if objectiveIndex then
            questPacket.objectives[objectiveIndex] = {
                id = rawObjective.id ~= 0 and rawObjective.id or nil,
                typ = rawObjective.type,
                fin = rawObjective.current >= rawObjective.required,
                ful = rawObjective.current,
                req = rawObjective.required,
            }
        end
    end

    return questPacket
end

local function BuildQuestStateSignature(questState)
    local parts = {
        tostring(questState.status or ""),
    }

    for _, objective in ipairs(questState.objectives) do
        parts[#parts + 1] = table.concat({
            tostring(objective.type or ""),
            tostring(objective.id or 0),
            tostring(objective.current or 0),
            tostring(objective.required or 0),
        }, ":")
    end

    return table.concat(parts, "|")
end

local function ApplyProgressSnapshot(snapshot)
    local botName = snapshot.botName
    local seenQuests = {}
    local previousStates = appliedQuestStates[botName] or {}
    local nextStates = {}

    for questId, questState in pairs(snapshot.quests) do
        seenQuests[questId] = true

        local signature = BuildQuestStateSignature(questState)
        nextStates[questId] = signature

        local players = QuestieComms.remoteQuestLogs[questId]
        local alreadyApplied = previousStates[questId] == signature and players and players[botName]

        if not alreadyApplied then
            -- Remove the previous tooltip registration before replacing
            -- this bot's data for the quest.
            QuestieComms.data:RemoveQuestFromPlayer(questId, botName)

            local questPacket = BuildQuestieQuestPacket(questId, questState)
            QuestieComms:InsertQuestDataPacket(questPacket, botName)
        end
    end

    -- A snapshot is authoritative. If the bot previously had a quest
    -- but it isn't in this snapshot anymore, remove it.
    for questId, players in pairs(QuestieComms.remoteQuestLogs) do
        if players[botName] and not seenQuests[questId] then
            players[botName] = nil
            QuestieComms.data:RemoveQuestFromPlayer(questId, botName)
            QuestiePartyObjectives:ScheduleUpdate(questId)
        end
    end

    appliedQuestStates[botName] = nextStates
end

local function HandleBridgeMessage(message, sender)
    -- The bridge sends responses as the player's own addon message sender.
    local playerName = UnitName("player")
    local senderName = sender and sender:gsub("%-.*$", "")

    if not playerName or not senderName or string.lower(senderName) ~= string.lower(playerName) then
        return
    end

    local fields = SplitFields(message)
    local opcode = fields[1]

    if opcode == "HELLO_ACK" then
        if not helloPending then
            return
        end

        return
    end

    if opcode == "CAPS_BEGIN" then
        if not helloPending then
            return
        end

        bridgeCapabilities = {}
        return
    end

    if opcode == "CAPS" then
        if not helloPending then
            return
        end

        local capabilities = fields[2] or ""

        for capability in string.gmatch(capabilities, "[^,]+") do
            bridgeCapabilities[capability] = true
        end

        return
    end

    if opcode == "CAPS_END" then
        if not helloPending then
            return
        end

        helloPending = false
        helloTimeoutAt = nil

        if not bridgeCapabilities.QUEST_PROGRESS_V1 then
            bridgeReady = false
            Print("|cFFFFAA00Bridge does not support QUEST_PROGRESS_V1.|r")
            return
        end

        bridgeReady = true

        RequestGroupQuests()
        return
    end

    if opcode == "QUEST_PROGRESS_BEGIN" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]

        progressSnapshots[token] = {
            botName = botName,
            quests = {},
        }

        return
    end

    if opcode == "QUEST_PROGRESS_QUEST" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]
        local questId = tonumber(fields[4])
        local status = fields[5]

        local snapshot = progressSnapshots[token]

        if snapshot and snapshot.botName == botName and questId then
            snapshot.quests[questId] = {
                status = status,
                objectives = {},
            }
        end

        return
    end

    if opcode == "QUEST_PROGRESS_OBJECTIVE" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]
        local questId = tonumber(fields[4])
        local objectiveType = fields[5]
        local objectiveId = tonumber(fields[7])
        local current = tonumber(fields[8])
        local required = tonumber(fields[9])

        local snapshot = progressSnapshots[token]
        local questState = snapshot and snapshot.botName == botName and snapshot.quests[questId]

        if questState then
            questState.objectives[#questState.objectives + 1] = {
                type = objectiveType,
                id = objectiveId,
                current = current,
                required = required,
            }
        end

        return
    end

    if opcode == "QUEST_PROGRESS_END" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]

        local snapshot = progressSnapshots[token]

        if snapshot and snapshot.botName == botName then
            ApplyProgressSnapshot(snapshot)
            progressSnapshots[token] = nil
            trackedBots[botName] = true
        end

        pendingRequests[token] = nil
        return
    end

    if opcode == "ERR" then
        local requestType = UrlDecode(fields[3])
        local token = fields[4]
        local reason = UrlDecode(fields[5])

        if token and pendingRequests[token] then
            pendingRequests[token] = nil
            Print("|cFFFF4444Bridge error for " .. tostring(requestType) .. ":|r " .. tostring(reason))
        end

        return
    end
end

function QuestiePlayerbots:Initialize()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, distribution, sender = ...

            if prefix ~= PREFIX then
                return
            end

            HandleBridgeMessage(message, sender)
            return
        end

        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            if bridgeReady then
                ScheduleRosterSync()
            end
        end
    end)

    eventFrame:SetScript("OnUpdate", function()
        local now = GetTime()

        if helloPending and helloTimeoutAt and now >= helloTimeoutAt then
            helloPending = false
            helloTimeoutAt = nil
        end

        if rosterSyncAt and now >= rosterSyncAt then
            SyncGroupRoster()
        end
    end)

    -- Probe automatically once Questie initializes
    ProbeBridge()
end
