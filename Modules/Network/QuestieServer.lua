---@class QuestieServer
local QuestieServer = QuestieLoader:CreateModule("QuestieServer")
local Integrations = QuestieLoader:ImportModule("QuestieServerIntegrations")

local PREFIX, VERSION = "QSTSVR", "2"
local frame, snapshot, assembly, watchToken, pendingUntil, lastReplyAt
local requestSequence, lastSequence, nextRequestAt = 0, 0, 0
local nextPreferenceCheck, previousPreferences = 0, nil
local subscriptions = {}
local CAPABILITIES = {EVENTS = true, VALUES = true, SCOURGE = true, QUELDANAS = true}

local function Split(value, separator)
    local fields, first = {}, 1
    while true do
        local position = string.find(value, separator, first, true)
        if not position then
            fields[#fields + 1] = string.sub(value, first)
            return fields
        end
        fields[#fields + 1] = string.sub(value, first, position - 1)
        first = position + #separator
    end
end

local function Integer(value, maximum)
    if not value or not string.match(value, "^%d+$") or #value > 16 then return nil end
    local number = tonumber(value)
    if number > maximum then return nil end
    return number
end

local function Fresh()
    return snapshot and GetTime() - lastReplyAt < 30
end

function QuestieServer:HasCapability(capability)
    return Fresh() and snapshot.caps[capability] == true or false
end

---@return boolean|nil nil means unknown/unsupported, false means confirmed inactive.
function QuestieServer:IsEventActive(id)
    if not self:HasCapability("EVENTS") then return nil end
    local event = snapshot.events[id]
    if event then return event.active end
    return nil
end

---@return number[]|nil Sorted active event IDs, or nil when the catalog is unavailable.
function QuestieServer:GetActiveEvents()
    if not self:HasCapability("EVENTS") then return nil end
    local events = {}
    for id, event in pairs(snapshot.events) do
        if event.active then events[#events + 1] = id end
    end
    table.sort(events)
    return events
end

function QuestieServer:IsHolidayActive(id)
    if not self:HasCapability("EVENTS") then return nil end
    local result
    for _, event in pairs(snapshot.events) do
        if event.holiday == id and event.main then
            if event.active then return true end
            result = false
        end
    end
    return result
end

function QuestieServer:WatchWorldState(id)
    assert(type(id) == "number" and id >= 0 and id <= 4294967295 and id == math.floor(id), "uint32 required")
    if subscriptions[id] then return end
    local count = 0
    for _ in pairs(subscriptions) do count = count + 1 end
    assert(count < 16, "server bridge supports 16 worldstate subscriptions")
    subscriptions[id] = true
    nextRequestAt = 0
end

-- Raw persistent values are decimal strings: Lua numbers cannot represent every uint64.
function QuestieServer:GetWorldStateRaw(id)
    if self:HasCapability("VALUES") then return snapshot.values[id] end
    return nil
end

function QuestieServer:GetWorldState(id)
    local raw = self:GetWorldStateRaw(id)
    if raw and (#raw < 16 or (#raw == 16 and raw <= "9007199254740991")) then return tonumber(raw) end
    return nil
end

function QuestieServer:GetProgressValue(id, capability)
    if self:HasCapability(capability) then return snapshot.ui[id] end
    return nil
end

function QuestieServer:IsScourgeInvasionActive()
    if self:HasCapability("SCOURGE") then return snapshot.scourge end
    return nil
end

local function Request()
    local now = GetTime()
    if pendingUntil or now < nextRequestAt then return end
    local name = UnitName("player")
    if not name then return end
    requestSequence = requestSequence + 1
    watchToken = "qs" .. tostring(math.floor(now * 1000)) .. tostring(requestSequence)
    lastSequence, assembly = 0, nil
    pendingUntil = now + 5
    nextRequestAt = now + (Fresh() and 10 or 60)
    local ids = {}
    for id in pairs(subscriptions) do ids[#ids + 1] = id end
    table.sort(ids)
    SendAddonMessage(PREFIX, "WATCH~" .. VERSION .. "~" .. watchToken .. "~" .. table.concat(ids, ","), "WHISPER", name)
end

local function ParseRows(batch)
    local result = {caps = batch.caps, events = {}, values = {}, ui = {}}
    local count = 0
    for index = 1, batch.partCount do
        if not batch.parts[index] then return nil end
        for _, row in ipairs(Split(batch.parts[index], ";")) do
            count = count + 1
            local fields = Split(row, ":")
            local kind, id = fields[1], Integer(fields[2], 4294967295)
            if kind == "E" and result.caps.EVENTS and #fields == 5 and id and id > 0 and id <= 65535 then
                local holiday = Integer(fields[3], 4294967295)
                if not holiday or not string.match(fields[4], "^[01]$") or not string.match(fields[5], "^[01]$")
                    or result.events[id] then return nil end
                result.events[id] = {holiday = holiday, main = fields[4] == "1", active = fields[5] == "1"}
            elseif kind == "W" and result.caps.VALUES and #fields == 3 and id and subscriptions[id] then
                local raw = fields[3]
                if not string.match(raw, "^%d+$") or #raw > 20
                    or (#raw == 20 and raw > "18446744073709551615") or result.values[id] then return nil end
                result.values[id] = raw
            elseif kind == "U" and (result.caps.SCOURGE or result.caps.QUELDANAS) and #fields == 3 and id then
                if not string.match(fields[3], "^%-?%d+$") or #fields[3] > 11 or result.ui[id] ~= nil then return nil end
                local value = tonumber(fields[3])
                if value < -2147483648 or value > 2147483647 then return nil end
                result.ui[id] = value
            elseif kind == "P" and result.caps.SCOURGE and #fields == 3 and fields[2] == "SC_ACTIVE"
                and string.match(fields[3], "^[01]$") and result.scourge == nil then
                result.scourge = fields[3] == "1"
            else
                return nil
            end
        end
    end
    if count ~= batch.rowCount then return nil end
    if result.caps.SCOURGE and result.scourge == nil then return nil end
    if result.caps.QUELDANAS and (not result.ui[3426] or result.ui[3426] < 0 or result.ui[3426] > 3) then return nil end
    if result.caps.VALUES then
        for id in pairs(subscriptions) do if not result.values[id] then return nil end end
    end
    return result
end

local function HandleMessage(message, distribution, sender)
    if distribution ~= "WHISPER" or sender ~= UnitName("player") or not watchToken
        or type(message) ~= "string" or #message > 240 then return end
    local fields = Split(message, "~")
    if fields[2] ~= VERSION or fields[3] ~= watchToken then return end
    local sequence = Integer(fields[4], 9007199254740991)
    if not sequence or sequence <= lastSequence then return end
    local now = GetTime()
    if fields[1] == "BEGIN" and #fields == 7 then
        if assembly and sequence <= assembly.sequence then return end
        local rows, parts = Integer(fields[6], 4096), Integer(fields[7], 1024)
        if not rows or not parts or (rows == 0) ~= (parts == 0) or parts > rows then return end
        local caps = {}
        if fields[5] ~= "" then
            for _, cap in ipairs(Split(fields[5], ",")) do
                if not CAPABILITIES[cap] or caps[cap] then return end
                caps[cap] = true
            end
        end
        assembly = {sequence = sequence, caps = caps, rowCount = rows, partCount = parts, parts = {}, untilTime = now + 5}
    elseif assembly and sequence == assembly.sequence and now <= assembly.untilTime then
        if fields[1] == "PART" and #fields == 6 then
            local index = Integer(fields[5], assembly.partCount)
            if not index or index < 1 or assembly.parts[index] or #fields[6] > 150 or fields[6] == "" then
                assembly = nil
                return
            end
            assembly.parts[index] = fields[6]
        elseif fields[1] == "END" and #fields == 4 then
            local result = ParseRows(assembly)
            assembly = nil
            if not result then return end
            snapshot, lastSequence, lastReplyAt = result, sequence, now
            pendingUntil = nil
            nextRequestAt = math.min(nextRequestAt, now + 10)
            Integrations:Refresh()
        end
    end
end

function QuestieServer:PrintStatus()
    if not Fresh() then
        Questie:Print("[Server bridge] No fresh server state; using existing calendar and manual settings.")
        return
    end
    local caps = {}
    for cap in pairs(snapshot.caps) do caps[#caps + 1] = cap end
    table.sort(caps)
    Questie:Print("[Server bridge] Live state (" .. math.floor(GetTime() - lastReplyAt) .. "s): " .. table.concat(caps, ", "))
    local events = self:GetActiveEvents()
    if not events then
        Questie:Print("[Server bridge] Event activity unavailable.")
    elseif #events == 0 then
        Questie:Print("[Server bridge] Active event IDs: none")
    else
        for first = 1, #events, 20 do
            Questie:Print("[Server bridge] Active event IDs (" .. #events .. "): "
                .. table.concat(events, ", ", first, math.min(first + 19, #events)))
        end
    end
    Questie:Print("[Server bridge] Fishing 15/62/90: " .. tostring(self:IsEventActive(15)) .. "/"
        .. tostring(self:IsEventActive(62)) .. "/" .. tostring(self:IsEventActive(90))
        .. "; winner: " .. tostring(self:GetWorldState(198)) .. "; Scourge: " .. tostring(self:IsScourgeInvasionActive())
        .. "; Quel'Danas phase (0-3): " .. tostring(self:GetProgressValue(3426, "QUELDANAS")))
end

function QuestieServer:Initialize()
    if frame or not QuestieCompat.Is335 then return end
    Integrations:Initialize()
    frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, prefix, message, distribution, sender)
        if event == "CHAT_MSG_ADDON" and prefix == PREFIX then HandleMessage(message, distribution, sender) end
    end)
    frame:SetScript("OnUpdate", function()
        local now = GetTime()
        if pendingUntil and now >= pendingUntil then pendingUntil, assembly, watchToken = nil, nil, nil end
        if assembly and now > assembly.untilTime then assembly = nil end
        if snapshot and not Fresh() then
            snapshot, lastReplyAt = nil, nil
            Integrations:Refresh()
        end
        if now >= nextPreferenceCheck then
            nextPreferenceCheck = now + 1
            local profile = Questie.db.profile
            local preferences = tostring(profile.showEventQuests) .. ":" .. tostring(profile.showScourgeInvasionQuests)
                .. ":" .. tostring(profile.showSunsReachQuests) .. ":" .. tostring(profile.isleOfQuelDanasPhase)
            if previousPreferences and previousPreferences ~= preferences then Integrations:Refresh() end
            previousPreferences = preferences
        end
        Request()
    end)
    SLASH_QUESTIESERVER1 = "/qserver"
    SlashCmdList.QUESTIESERVER = function() self:PrintStatus() end
    Request()
end
