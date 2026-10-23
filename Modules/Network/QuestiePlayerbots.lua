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
local TOKEN_PREFIX = "qpb"

local eventFrame
local helloTimeoutAt
local rosterSyncAt
local nextHelloAt = 0
local nextRosterCheckAt = 0

local bridgeReady = false
local helloPending = false
local bridgeUnsupported = false
local helloRetries = 0

local bridgeCapabilities = {}
local progressSnapshots = {}
local pendingRequests = {}
local trackedBots = {}
local appliedQuestStates = {}
local requestsByBot = {}
local retryAfter = {}

local requestSequence = 0
local ROSTER_SYNC_DELAY = 0.5
local HELLO_TIMEOUT = 3.0
local REQUEST_TIMEOUT = 10
local HELLO_RETRY_INTERVAL = 30
local MAX_HELLO_RETRIES = 3
local WATCH_REFRESH_INTERVAL = 60
local MAX_QUESTS = 75
local MAX_OBJECTIVES = 32

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
    nextHelloAt = GetTime() + HELLO_RETRY_INTERVAL
    bridgeReady = false
    bridgeCapabilities = {}

    if not Send("HELLO", PROTOCOL_VERSION) then
        helloPending = false
        helloTimeoutAt = nil
    end
end

local function NextToken()
    requestSequence = requestSequence + 1
    return TOKEN_PREFIX .. tostring(math.floor(GetTime() * 1000)) .. "x" .. tostring(requestSequence)
end

local function NormalizeName(name)
    if not name then
        return nil
    end

    return name:gsub("%-.*$", "")
end

local function RequestBotQuestProgress(botName)
    if retryAfter[botName] and GetTime() < retryAfter[botName] then
        return
    end

    local token = requestsByBot[botName]
    local request = token and pendingRequests[token]
    if request and GetTime() < request.refreshAt then
        return
    end

    token = token or NextToken()
    local payload = "QUEST_PROGRESS~" .. botName .. "~" .. token

    if bridgeCapabilities.QUEST_PROGRESS_PUSH_V1 then
        payload = payload .. "~WATCH"
    end

    requestsByBot[botName] = token
    pendingRequests[token] = {
        botName = botName,
        watch = bridgeCapabilities.QUEST_PROGRESS_PUSH_V1,
        expiresAt = GetTime() + REQUEST_TIMEOUT,
        refreshAt = GetTime() + WATCH_REFRESH_INTERVAL,
    }

    if not Send("GET", payload) then
        pendingRequests[token] = nil
        requestsByBot[botName] = nil
    end
end

local function RequestGroupQuests()
    if not bridgeReady then
        return
    end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name = UnitName("raid" .. i)

            if name and name ~= UnitName("player") and UnitIsConnected("raid" .. i) then
                RequestBotQuestProgress(name)
            end
        end
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. i)

            if name and UnitIsConnected("party" .. i) then
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
            if name and UnitIsConnected("raid" .. i) then
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
                if name and UnitIsConnected("party" .. i) then
                    members[name] = true
                end
            end
        end
    end

    return members
end

local function RemoveBotQuest(questId, botName)
    local players = QuestieComms.remoteQuestLogs[questId]
    players[botName] = nil
    QuestieComms.data:RemoveQuestFromPlayer(questId, botName)
    if not next(players) then
        QuestieComms.remoteQuestLogs[questId] = nil
    end
    QuestiePartyObjectives:ScheduleUpdate(questId)
end

local function RemoveTrackedBot(botName)
    local token = requestsByBot[botName]
    if token then
        local request = pendingRequests[token]
        if request and request.watch then
            Send("GET", "QUEST_PROGRESS~" .. botName .. "~" .. token .. "~UNWATCH")
        end
        pendingRequests[token] = nil
        progressSnapshots[token] = nil
        requestsByBot[botName] = nil
    end

    -- Only data this addon applied is removed; a real client's native data stays.
    for questId, state in pairs(appliedQuestStates[botName] or {}) do
        local players = QuestieComms.remoteQuestLogs[questId]
        if players and players[botName] == state.objectives then
            RemoveBotQuest(questId, botName)
        end
    end

    trackedBots[botName] = nil
    appliedQuestStates[botName] = nil
    retryAfter[botName] = nil
end

local function SyncGroupRoster()
    rosterSyncAt = nil

    if not bridgeReady then
        return
    end

    local members = GetCurrentGroupMembers()
    local departedBots = {}
    for botName in pairs(retryAfter) do
        if not members[botName] then retryAfter[botName] = nil end
    end

    local knownBots = {}
    for botName in pairs(requestsByBot) do knownBots[botName] = true end
    for botName in pairs(trackedBots) do knownBots[botName] = true end
    for botName in pairs(knownBots) do
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
    e = "event",
    r = "reputation",
    s = "spell",
    p = "player",
    g = "money",
}

local function FindQuestieObjectiveIndex(objectiveData, rawObjective, usedIndices)
    local fullType = objectiveTypeMap[rawObjective.type]
    for objectiveIndex, objective in ipairs(objectiveData) do
        local matches = objective.Type == fullType and (objective.Id or 0) == rawObjective.id
        if objective.Type == "killcredit" and rawObjective.type == "m" then
            matches = objective.RootId == rawObjective.id
            for _, id in pairs(objective.IdList or {}) do
                matches = matches or id == rawObjective.id
            end
        end

        if not usedIndices[objectiveIndex] and matches then

            usedIndices[objectiveIndex] = true
            return objectiveIndex
        end
    end

    return nil
end

local function FindSameTypeObjectiveIndex(objectiveData, objectiveType, usedIndices)
    for objectiveIndex, objective in ipairs(objectiveData) do
        if not usedIndices[objectiveIndex] and objective.Type == objectiveType then
            usedIndices[objectiveIndex] = true
            return objectiveIndex
        end
    end
end

local function BuildQuestieQuestPacket(questId, questState)
    local questPacket = {
        id = questId,
        status = questState.status,
        objectives = {},
    }

    local quest = QuestieDB.GetQuest(questId)
    local objectiveData = quest and quest.ObjectiveData or {}
    local usedIndices, indices, unmatched, remaining = {}, {}, {}, {}

    for position, rawObjective in ipairs(questState.objectives) do
        indices[position] = FindQuestieObjectiveIndex(objectiveData, rawObjective, usedIndices)
        local objectiveType = objectiveTypeMap[rawObjective.type]
        if not indices[position] then
            unmatched[objectiveType] = (unmatched[objectiveType] or 0) + 1
        end
    end
    for objectiveIndex, objective in ipairs(objectiveData) do
        if not usedIndices[objectiveIndex] then
            remaining[objective.Type] = (remaining[objective.Type] or 0) + 1
        end
    end

    for position, rawObjective in ipairs(questState.objectives) do
        -- Questie's database can name other items or targets than the server for
        -- the same objectives. Like a Questie client, pair the rest of a type in
        -- order when the database leaves exactly as many objectives of that type.
        local objectiveType = objectiveTypeMap[rawObjective.type]
        if not indices[position] and unmatched[objectiveType] == remaining[objectiveType] then
            indices[position] = FindSameTypeObjectiveIndex(objectiveData, objectiveType, usedIndices)
        end

        -- Native database and special objectives use positive indices. Keep unknown
        -- counters in a separate namespace so special map pins cannot inherit them.
        -- Bridges may number objectives per type, so the snapshot position keys them.
        local objectiveIndex = indices[position] or -position
        -- A Questie client reports its database objective, so tooltips and map
        -- pins follow the same sources as the local player's objective.
        local databaseObjective = objectiveData[objectiveIndex]
        questPacket.objectives[objectiveIndex] = {
            id = databaseObjective and databaseObjective.Id or (rawObjective.id ~= 0 and rawObjective.id or nil),
            typ = rawObjective.type,
            fin = rawObjective.finished,
            ful = rawObjective.current,
            req = rawObjective.required,
        }
    end

    return questPacket
end

local function BuildQuestStateSignature(questState)
    local parts = {
        tostring(questState.status or ""),
    }

    for _, objective in ipairs(questState.objectives) do
        parts[#parts + 1] = table.concat({
            tostring(objective.index),
            tostring(objective.type or ""),
            tostring(objective.id or 0),
            tostring(objective.current or 0),
            tostring(objective.required or 0),
            tostring(objective.finished),
        }, ":")
    end

    return table.concat(parts, "|")
end

local function IsUnsigned(value, maximum)
    return value and value >= 0 and value <= (maximum or 4294967295) and value % 1 == 0
end

local function IsProgressValue(value, objectiveType)
    -- Reputation standings can be negative; copper and counters must stay exact
    -- in the client's double-precision Lua number representation.
    return value and value % 1 == 0 and value <= 9007199254740991
        and value >= (objectiveType == "r" and -2147483648 or 0)
end

local function GetProgressRequest(botName, token)
    local current = requestsByBot[botName]
    local request = current and pendingRequests[current]
    -- Tokens issued by NextToken expire once replaced. A bridge may push WATCH
    -- updates under its own tokens; those are valid only for a current WATCH.
    local owned = token == current
        or (request and request.watch and token and token:sub(1, #TOKEN_PREFIX) ~= TOKEN_PREFIX)
    if bridgeReady and request and owned
        and (not request.expiresAt or GetTime() < request.expiresAt) and GetCurrentGroupMembers()[botName] then
        return request
    end
end

local function ApplyProgressSnapshot(snapshot)
    local botName = snapshot.botName
    local seenQuests = {}
    local previousStates = appliedQuestStates[botName] or {}
    local nextStates = {}

    for questId in pairs(snapshot.quests) do
        local players = QuestieComms.remoteQuestLogs[questId]
        local previous = previousStates[questId]
        if players and players[botName] and (not previous or players[botName] ~= previous.objectives) then
            -- A real client's native comms took ownership while a WATCH reply was
            -- in flight. Stop observing before an old snapshot can replace it.
            RemoveTrackedBot(botName)
            retryAfter[botName] = GetTime() + WATCH_REFRESH_INTERVAL
            return false
        end
    end

    for questId, questState in pairs(snapshot.quests) do
        seenQuests[questId] = true

        local signature = BuildQuestStateSignature(questState)
        local players = QuestieComms.remoteQuestLogs[questId]
        local previousState = previousStates[questId]
        local alreadyApplied = previousState and previousState.signature == signature
            and players and players[botName] == previousState.objectives

        if not alreadyApplied then
            -- Remove the previous tooltip registration before replacing
            -- this bot's data for the quest.
            QuestieComms.data:RemoveQuestFromPlayer(questId, botName)

            local questPacket = BuildQuestieQuestPacket(questId, questState)
            QuestieComms:InsertQuestDataPacket(questPacket, botName)
        end

        nextStates[questId] = {
            signature = signature,
            objectives = QuestieComms.remoteQuestLogs[questId] and QuestieComms.remoteQuestLogs[questId][botName],
        }
    end

    -- A snapshot is authoritative. If the bot previously had a quest
    -- but it isn't in this snapshot anymore, remove it.
    for questId, state in pairs(previousStates) do
        local players = QuestieComms.remoteQuestLogs[questId]
        if not seenQuests[questId] and players and players[botName] == state.objectives then
            RemoveBotQuest(questId, botName)
        end
    end

    appliedQuestStates[botName] = nextStates
    return true
end

local function HandleBridgeMessage(message, sender)
    -- The bridge sends responses as the player's own addon message sender.
    if type(message) ~= "string" or #message > 255 then
        return
    end

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
            if not bridgeUnsupported then
                bridgeUnsupported = true
                Print("|cFFFFAA00Bridge does not support QUEST_PROGRESS_V1.|r")
            end
            return
        end

        bridgeReady = true

        RequestGroupQuests()
        return
    end

    if opcode == "QUEST_PROGRESS_BEGIN" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]

        if not GetProgressRequest(botName, token) then
            return
        end

        progressSnapshots[token] = {
            botName = botName,
            quests = {},
            questCount = 0,
            expiresAt = GetTime() + REQUEST_TIMEOUT,
        }

        return
    end

    if opcode == "QUEST_PROGRESS_QUEST" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]
        local questId = tonumber(fields[4])
        local status = fields[5]

        local snapshot = progressSnapshots[token]

        if snapshot and snapshot.botName == botName
            and IsUnsigned(questId) and questId > 0 and (status == "I" or status == "C" or status == "F")
            and not snapshot.quests[questId] and snapshot.questCount < MAX_QUESTS then
            snapshot.questCount = snapshot.questCount + 1
            snapshot.quests[questId] = {
                status = status,
                objectives = {},
            }
        elseif snapshot then
            progressSnapshots[token] = nil
        end

        return
    end

    if opcode == "QUEST_PROGRESS_OBJECTIVE" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]
        local questId = tonumber(fields[4])
        local objectiveType = fields[5]
        local objectiveIndex = tonumber(fields[6])
        local objectiveId = tonumber(fields[7])
        local current = tonumber(fields[8])
        local required = tonumber(fields[9])

        local snapshot = progressSnapshots[token]
        local questState = snapshot and snapshot.botName == botName and questId and snapshot.quests[questId]

        if questState
            and objectiveTypeMap[objectiveType] and IsUnsigned(objectiveIndex, MAX_OBJECTIVES) and objectiveIndex > 0
            and IsUnsigned(objectiveId) and IsProgressValue(current, objectiveType) and IsProgressValue(required, objectiveType)
            and #questState.objectives < MAX_OBJECTIVES
            and (not fields[10] or fields[10] == "0" or fields[10] == "1") then
            for _, objective in ipairs(questState.objectives) do
                if objective.index == objectiveIndex and objective.type == objectiveType then
                    progressSnapshots[token] = nil
                    return
                end
            end
            questState.objectives[#questState.objectives + 1] = {
                type = objectiveType,
                index = objectiveIndex,
                id = objectiveId,
                current = current,
                required = required,
                finished = fields[10] == "1" or (not fields[10] and required > 0 and current >= required),
            }
        elseif snapshot then
            progressSnapshots[token] = nil
        end

        return
    end

    if opcode == "QUEST_PROGRESS_END" then
        local botName = UrlDecode(fields[2])
        local token = fields[3]

        local snapshot = progressSnapshots[token]

        local request = GetProgressRequest(botName, token)
        if request and fields[4] == "NO_BOT" then
            -- Bridges without an error reply report unobservable members this way.
            -- No WATCH was registered, so back off like a bridge error.
            request.watch = nil
            RemoveTrackedBot(botName)
            retryAfter[botName] = GetTime() + WATCH_REFRESH_INTERVAL
            return
        end
        if snapshot and request and snapshot.botName == botName and GetTime() < snapshot.expiresAt then
            if not ApplyProgressSnapshot(snapshot) then
                return
            end
            progressSnapshots[token] = nil
            trackedBots[botName] = true
            request.expiresAt = nil
            if not request.watch then
                requestsByBot[botName] = nil
                pendingRequests[token] = nil
                retryAfter[botName] = GetTime() + WATCH_REFRESH_INTERVAL
            end
        end

        return
    end

    if opcode == "ERR" then
        local requestType = UrlDecode(fields[3])
        local token = fields[4]
        local reason = UrlDecode(fields[5])

        if token and pendingRequests[token] and requestType == "QUEST_PROGRESS" then
            local botName = pendingRequests[token].botName
            RemoveTrackedBot(botName)
            retryAfter[botName] = GetTime() + WATCH_REFRESH_INTERVAL
        elseif token and pendingRequests[token] then
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
            elseif not helloPending then
                ProbeBridge()
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

        if now >= nextRosterCheckAt then
            nextRosterCheckAt = now + 2
            if bridgeReady then
                SyncGroupRoster()
            elseif not helloPending and not bridgeUnsupported and helloRetries < MAX_HELLO_RETRIES
                and now >= nextHelloAt then
                -- Retry a lost HELLO a few times. Realms without a bridge stay quiet
                -- until the group changes; a bridge without quest progress stays unsupported.
                helloRetries = helloRetries + 1
                ProbeBridge()
            end

            for token, snapshot in pairs(progressSnapshots) do
                if now >= snapshot.expiresAt then
                    progressSnapshots[token] = nil
                end
            end
            for token, request in pairs(pendingRequests) do
                if request.expiresAt and now >= request.expiresAt then
                    RemoveTrackedBot(request.botName)
                    retryAfter[request.botName] = now + 2
                end
            end
        end
    end)

    -- Probe automatically once Questie initializes
    ProbeBridge()
end
