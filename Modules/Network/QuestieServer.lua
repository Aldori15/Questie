---@class QuestieServer
local QuestieServer = QuestieLoader:CreateModule("QuestieServer")
local Integrations = QuestieLoader:ImportModule("QuestieServerIntegrations")

local PREFIX, PROTOCOL_VERSION = "QSTSVR", "10"

-- Shared with the correction generators. Decisions apply to the current area,
-- never to every location in these zones. Keep the module's profiles in sync.
local phaseZones = {
    [0] = {[85] = "Tirisfal Glades", [1497] = "Undercity"},
    [1] = {[1637] = "Orgrimmar"},
    [571] = {[65] = "Dragonblight", [66] = "Zul'Drak", [67] = "Storm Peaks",
        [210] = "Icecrown", [394] = "Grizzly Hills", [3537] = "Borean Tundra"},
    [609] = {[4298] = "Death knight starting area"},
}
local phaseAreas = {
    [0] = {[4281] = "Acherus"},
    [571] = {[4477] = "Shadow Vault"},
}
-- Includes composite masks from audited creature and gameobject spawn data.
local phaseMasks = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 19, 32, 35, 51, 64, 65, 66, 71,
    128, 129, 131, 175, 192, 193, 194, 195, 196, 197, 198, 204, 231, 243, 255, 256, 257,
    384, 448, 449, 510, 511, 65535, 2147483647, 4294967295}
local phaseMaskSet = {}
for _, mask in ipairs(phaseMasks) do phaseMaskSet[mask] = true end

local function PhaseRegion(map, area, zone)
    if area == 0 then return nil end
    return (phaseAreas[map] and phaseAreas[map][area]) or (phaseZones[map] and phaseZones[map][zone])
end
local frame, snapshot, assembly, watchToken, pendingUntil, lastReplyAt
local serverInfo, infoReceived
local snapshotToken, snapshotSequence, pendingRenewal
local forceSnapshot, subscriptionsDirty = false, false
local iccContextPending = false
local phaseContextPending = false
local lastRequestAt = -2
local snapshotCount, heartbeatCount = 0, 0
local requestSequence, lastSequence, nextRequestAt = 0, 0, 0
local nextPreferenceCheck, previousPreferences = 0, nil
local subscriptions = {}
local CAPABILITIES = {EVENTS = true, VALUES = true, SCOURGE = true, QUELDANAS = true,
    KALUAK = true, HEARTBEAT = true, QUESTPOOLS = true, WINTERGRASP = true, ICC = true, RESETS = true, PHASES = true}

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

---@return table|nil Reset deadlines and an advancing server clock, in Unix seconds.
function QuestieServer:GetQuestResetTimes()
    if not self:HasCapability("RESETS") then return nil end
    return {weekly = snapshot.resets.weekly, monthly = snapshot.resets.monthly,
        serverTime = snapshot.serverTime + GetTime() - snapshot.receivedAt}
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
    subscriptionsDirty = true
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

---@return boolean|nil nil means unsupported or Clearwater's AI has not been observed.
function QuestieServer:IsKaluakDerbyFinished()
    if self:HasCapability("KALUAK") then return snapshot.kaluakFinished end
    return nil
end

---@return boolean|nil nil means no authoritative pool membership is known.
function QuestieServer:IsPooledQuestActive(questId)
    if self:HasCapability("QUESTPOOLS") then
        local quest = snapshot.poolQuests[questId]
        if quest then return quest.active end
    end
    return nil
end

function QuestieServer:GetQuestPoolId(questId)
    if self:HasCapability("QUESTPOOLS") then
        local quest = snapshot.poolQuests[questId]
        if quest then return quest.pool end
    end
    return nil
end

---@return number[]|nil All reported members, optionally restricted to one pool.
function QuestieServer:GetPooledQuests(poolId)
    if not self:HasCapability("QUESTPOOLS") then return nil end
    local ids = {}
    for id, quest in pairs(snapshot.poolQuests) do
        if not poolId or quest.pool == poolId then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

---@return table|nil A copy of public battlefield state; nil means unsupported/expired.
function QuestieServer:GetWintergraspState()
    if not self:HasCapability("WINTERGRASP") then return nil end
    local state = snapshot.wintergrasp
    return {loaded = state.loaded, enabled = state.enabled, battle = state.battle, defender = state.defender}
end

---@return table|nil Current local phase context; never reused across area transitions.
function QuestieServer:GetPhaseContext()
    if phaseContextPending or not self:HasCapability("PHASES") then return nil end
    local state = snapshot.phaseContext
    return {map = state.map, area = state.area, mask = state.mask, zone = state.zone}
end

function QuestieServer:GetPhaseRegion(context)
    if not context then return nil end
    return PhaseRegion(context.map, context.area, context.zone)
end

function QuestieServer:GetPhaseVisibilityKey()
    local context = self:GetPhaseContext()
    if not self:GetPhaseRegion(context) then return "unknown" end
    local parts = {tostring(context.map), tostring(context.area), tostring(context.zone), tostring(context.mask)}
    for _, mask in ipairs(phaseMasks) do
        parts[#parts + 1] = tostring(self:GetSpawnPhaseVisibility(context.map, context.area, mask))
    end
    return table.concat(parts, ":")
end

---@return boolean|nil Server visibility decision, or nil outside the supported region.
function QuestieServer:GetSpawnPhaseVisibility(map, region, mask)
    local context = self:GetPhaseContext()
    if not context or context.map ~= map or context.area ~= region then return nil end
    return snapshot.phaseVisibility[region] and snapshot.phaseVisibility[region][mask]
end

---@return boolean|nil Scripted faction/pool gate only, not character eligibility.
function QuestieServer:IsWintergraspQuestActive(questId)
    if self:HasCapability("WINTERGRASP") then return snapshot.wintergraspQuests[questId] end
    return nil
end

function QuestieServer:GetWintergraspQuests()
    if not self:HasCapability("WINTERGRASP") or not snapshot.wintergrasp.loaded then return nil end
    local ids = {}
    for id in pairs(snapshot.wintergraspQuests) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

---@return table|nil Current raid context only; never reused after an instance transition.
function QuestieServer:GetICCState()
    if iccContextPending or not self:HasCapability("ICC") then return nil end
    local state = snapshot.icc
    return {loaded = state.loaded, inside = state.inside, instance = state.instance,
        difficulty = state.difficulty, family = state.family, respiteReady = state.respiteReady, team = state.team}
end

---@return boolean|nil Scripted family, difficulty and unlock gate; not character eligibility.
function QuestieServer:IsICCQuestActive(questId)
    if not iccContextPending and self:HasCapability("ICC") and snapshot.icc.loaded and snapshot.icc.inside then
        return snapshot.iccQuests[questId]
    end
    return nil
end

function QuestieServer:GetICCQuests()
    local state = self:GetICCState()
    if not state or not state.loaded or not state.inside then return nil end
    local ids = {}
    for id in pairs(snapshot.iccQuests) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- Combine independent live gates. A selected quest cannot bypass a faction gate,
-- raid-instance gate or inactive direct pool membership.
function QuestieServer:GetQuestAvailabilityState(questId)
    local pool = self:IsPooledQuestActive(questId)
    local wintergrasp = self:IsWintergraspQuestActive(questId)
    local icc = self:IsICCQuestActive(questId)
    if pool == false or wintergrasp == false or icc == false then return false end
    if pool == true or wintergrasp == true or icc == true then return true end
    return nil
end

function QuestieServer:GetStateControlledQuests()
    local pool, wintergrasp, icc = self:GetPooledQuests(), self:GetWintergraspQuests(), self:GetICCQuests()
    if not pool and not wintergrasp and not icc then return nil end
    local ids, seen = {}, {}
    for _, members in ipairs({pool or {}, wintergrasp or {}, icc or {}}) do
        for _, id in ipairs(members) do
            if not seen[id] then ids[#ids + 1], seen[id] = id, true end
        end
    end
    table.sort(ids)
    return ids
end

local function Request()
    local now = GetTime()
    if pendingUntil or now < nextRequestAt or now - lastRequestAt < 2 then return end
    local name = UnitName("player")
    if not name then return end
    lastRequestAt = now
    if QuestieServer:HasCapability("HEARTBEAT")
        and snapshotToken == watchToken and not forceSnapshot and not subscriptionsDirty then
        -- Keep the token and acknowledged snapshot stable; renewing must not force
        -- another copy of the event catalog. The server's subscription lease is 45s.
        pendingUntil, pendingRenewal = now + 5, true
        nextRequestAt = now + 20
        SendAddonMessage(PREFIX, "ACK~" .. PROTOCOL_VERSION .. "~" .. watchToken .. "~" .. tostring(snapshotSequence), "WHISPER", name)
        return
    end
    requestSequence = requestSequence + 1
    watchToken = "qs" .. tostring(math.floor(now * 1000)) .. tostring(requestSequence)
    lastSequence, assembly = 0, nil
    infoReceived = false
    pendingUntil = now + 5
    pendingRenewal, forceSnapshot, subscriptionsDirty = false, false, false
    nextRequestAt = now + (Fresh() and 20 or 60)
    local ids = {}
    for id in pairs(subscriptions) do ids[#ids + 1] = id end
    table.sort(ids)
    SendAddonMessage(PREFIX, "WATCH~" .. PROTOCOL_VERSION .. "~" .. watchToken .. "~" .. table.concat(ids, ","), "WHISPER", name)
end

local function ParseRows(batch)
    local result = {caps = batch.caps, events = {}, values = {}, ui = {}, poolQuests = {},
        wintergraspQuests = {}, iccQuests = {}, phaseVisibility = {}}
    local count = 0
    for index = 1, batch.partCount do
        if not batch.parts[index] then return nil end
        for _, row in ipairs(Split(batch.parts[index], ";")) do
            count = count + 1
            local fields = Split(row, ":")
            local kind, id = fields[1], Integer(fields[2], 4294967295)
            if kind == "P" and result.caps.PHASES and fields[2] == "PHASE_CONTEXT"
                and #fields == 6 and not result.phaseContext then
                local map, area, mask = Integer(fields[3], 65535), Integer(fields[4], 65535), Integer(fields[5], 4294967295)
                local zone = Integer(fields[6], 65535)
                if not map or not area or not mask or not zone then return nil end
                result.phaseContext = {map = map, area = area, mask = mask, zone = zone}
            elseif kind == "F" and result.caps.PHASES and #fields == 4 and id and id <= 65535 then
                local mask = Integer(fields[3], 4294967295)
                if not phaseMaskSet[mask]
                    or not string.match(fields[4], "^[01]$") then return nil end
                result.phaseVisibility[id] = result.phaseVisibility[id] or {}
                if result.phaseVisibility[id][mask] ~= nil then return nil end
                result.phaseVisibility[id][mask] = fields[4] == "1"
            elseif kind == "P" and result.caps.RESETS and fields[2] == "QUEST_RESETS"
                and #fields == 4 and not result.resets then
                local weekly, monthly = Integer(fields[3], 4294967295), Integer(fields[4], 4294967295)
                if not weekly or weekly == 0 or not monthly or monthly == 0 then return nil end
                result.resets = {weekly = weekly, monthly = monthly}
            elseif kind == "P" and result.caps.RESETS and fields[2] == "SERVER_TIME"
                and #fields == 3 and not result.serverTime then
                local serverTime = Integer(fields[3], 4294967295)
                if not serverTime or serverTime == 0 then return nil end
                result.serverTime = serverTime
            elseif kind == "E" and result.caps.EVENTS and #fields == 5 and id and id > 0 and id <= 65535 then
                local holiday = Integer(fields[3], 4294967295)
                if not holiday or not string.match(fields[4], "^[01]$") or not string.match(fields[5], "^[01]$")
                    or result.events[id] then return nil end
                result.events[id] = {holiday = holiday, main = fields[4] == "1", active = fields[5] == "1"}
            elseif kind == "Q" and result.caps.QUESTPOOLS and #fields == 4 and id and id > 0 then
                local pool = Integer(fields[3], 4294967295)
                if not pool or pool < 1 or not string.match(fields[4], "^[01]$") or result.poolQuests[id] then return nil end
                result.poolQuests[id] = {pool = pool, active = fields[4] == "1"}
            elseif kind == "R" and result.caps.WINTERGRASP and #fields == 3 and id and id > 0 then
                if not string.match(fields[3], "^[01]$") or result.wintergraspQuests[id] ~= nil then return nil end
                result.wintergraspQuests[id] = fields[3] == "1"
            elseif kind == "I" and result.caps.ICC and #fields == 3 and id and id > 0 then
                if not string.match(fields[3], "^[01]$") or result.iccQuests[id] ~= nil then return nil end
                result.iccQuests[id] = fields[3] == "1"
            elseif kind == "P" and result.caps.ICC and #fields == 7
                and fields[2] == "ICC_STATE" and not result.icc then
                if fields[3] == "?" and fields[4] == "?" and fields[5] == "?"
                    and fields[6] == "?" and fields[7] == "?" then
                    result.icc = {loaded = false}
                else
                    local instance, difficulty, family, team = Integer(fields[3], 4294967295),
                        Integer(fields[4], 3), Integer(fields[5], 4294967295), Integer(fields[7], 1)
                    if not instance or not difficulty or not family or not team
                        or not string.match(fields[6], "^[01]$") then return nil end
                    if instance == 0 and (difficulty ~= 0 or family ~= 0 or fields[6] ~= "0" or team ~= 0) then return nil end
                    result.icc = {loaded = true, inside = instance > 0, instance = instance,
                        difficulty = difficulty, family = family, respiteReady = fields[6] == "1", team = team}
                end
            elseif kind == "P" and result.caps.WINTERGRASP and #fields == 5
                and fields[2] == "WG_STATE" and not result.wintergrasp then
                if fields[3] == "?" and fields[4] == "?" and fields[5] == "?" then
                    result.wintergrasp = {loaded = false}
                elseif string.match(fields[3], "^[01]$") and string.match(fields[4], "^[01]$")
                    and string.match(fields[5], "^[01]$") then
                    result.wintergrasp = {loaded = true, enabled = fields[3] == "1",
                        battle = fields[4] == "1", defender = tonumber(fields[5])}
                else
                    return nil
                end
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
            elseif kind == "P" and result.caps.KALUAK and #fields == 3 and fields[2] == "KA_FINISHED"
                and (fields[3] == "0" or fields[3] == "1" or fields[3] == "?") and not result.kaluakReported then
                result.kaluakReported = true
                if fields[3] ~= "?" then result.kaluakFinished = fields[3] == "1" end
            else
                return nil
            end
        end
    end
    if count ~= batch.rowCount then return nil end
    if result.caps.PHASES then
        local context = result.phaseContext
        if not context then return nil end
        if PhaseRegion(context.map, context.area, context.zone) then
            local visibility = result.phaseVisibility[context.area]
            if not visibility then return nil end
            for _, mask in ipairs(phaseMasks) do
                if visibility[mask] == nil then return nil end
            end
            for area in pairs(result.phaseVisibility) do
                if area ~= context.area then return nil end
            end
        elseif next(result.phaseVisibility) then
            return nil
        end
    end
    if result.caps.RESETS and (not result.resets or not result.serverTime) then return nil end
    if result.caps.SCOURGE and result.scourge == nil then return nil end
    if result.caps.KALUAK and not result.kaluakReported then return nil end
    if result.caps.WINTERGRASP and (not result.wintergrasp
        or (not result.wintergrasp.loaded and next(result.wintergraspQuests))) then return nil end
    if result.caps.ICC then
        local state = result.icc
        if not state then return nil end
        if not state.loaded or not state.inside then
            if next(result.iccQuests) then return nil end
        elseif not next(result.iccQuests) or (state.family ~= 0 and result.iccQuests[state.family] == nil) then
            return nil
        end
    end
    if result.caps.QUELDANAS and (not result.ui[3426] or result.ui[3426] < 0 or result.ui[3426] > 3) then return nil end
    if result.caps.VALUES then
        for id in pairs(subscriptions) do if not result.values[id] then return nil end end
    end
    return result
end

local function HandleInfo(fields)
    -- The diagnostic envelope is independent of the quest-state protocol. Only
    -- accept one reply to a current full WATCH; it cannot keep state alive.
    local now = GetTime()
    if #fields ~= 7 or fields[2] ~= "1" or fields[3] ~= watchToken or not pendingUntil
        or now > pendingUntil or pendingRenewal or infoReceived then return end
    local protocol = Integer(fields[4], 65535)
    if not protocol or protocol < 1 or tostring(protocol) ~= fields[4] then return end
    for index = 5, 6 do
        if #fields[index] < 1 or #fields[index] > 64 or not string.match(fields[index], "^[%w._%+%-]+$") then return end
    end
    local status = fields[7]
    local compatible = fields[4] == PROTOCOL_VERSION
    if status == "MISMATCH" then
        if compatible then return end
    elseif status == "READY" or status == "DISABLED" then
        if not compatible then return end
    else
        return
    end
    infoReceived = true
    serverInfo = {protocol = fields[4], version = fields[5], revision = fields[6], status = status, receivedAt = now}
    if status ~= "READY" then
        local hadSnapshot = snapshot ~= nil
        snapshot, lastReplyAt, snapshotToken, snapshotSequence = nil, nil, nil, nil
        pendingUntil, pendingRenewal, assembly, watchToken = nil, false, nil, nil
        forceSnapshot, nextRequestAt = true, now + 60
        if hadSnapshot then Integrations:Refresh() end
    end
end

local function HandleMessage(message, distribution, sender)
    if distribution ~= "WHISPER" or sender ~= UnitName("player") or not watchToken
        or type(message) ~= "string" or #message > 240 then return end
    local fields = Split(message, "~")
    if fields[1] == "INFO" then HandleInfo(fields); return end
    if fields[2] ~= PROTOCOL_VERSION or fields[3] ~= watchToken then return end
    local sequence = Integer(fields[4], 9007199254740991)
    if not sequence or sequence <= lastSequence then return end
    local now = GetTime()
    if fields[1] == "ALIVE" and #fields == 5 then
        -- A heartbeat only confirms an already complete, fresh snapshot. It cannot
        -- create state, finish a partial batch, or revive expired information.
        if assembly or forceSnapshot or not Fresh() or snapshotToken ~= watchToken
            or not QuestieServer:HasCapability("HEARTBEAT") then return end
        local confirmed = Integer(fields[5], 9007199254740991)
        if not confirmed or confirmed < 1 then return end
        if confirmed ~= snapshotSequence then
            -- We missed a changed snapshot. Ask for a complete replacement instead
            -- of extending the lifetime of stale quest availability.
            forceSnapshot, pendingUntil, pendingRenewal, nextRequestAt = true, nil, false, 0
            return
        end
        lastSequence, lastReplyAt = sequence, now
        heartbeatCount = heartbeatCount + 1
        if pendingRenewal then pendingUntil, pendingRenewal = nil, false end
    elseif fields[1] == "BEGIN" and #fields == 7 then
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
            snapshot.receivedAt = now
            iccContextPending = false
            phaseContextPending = false
            snapshotToken, snapshotSequence = watchToken, sequence
            snapshotCount = snapshotCount + 1
            pendingUntil, pendingRenewal, forceSnapshot = nil, false, false
            nextRequestAt = math.min(nextRequestAt, now + 20)
            Integrations:Refresh()
        end
    end
end

function QuestieServer:PrintStatus(poolId)
    local addonVersion = GetAddOnMetadata(QuestieCompat.addonName or "Questie-335", "Version") or "unknown"
    Questie:Print("[Server bridge] Client: Questie " .. addonVersion .. "; protocol " .. PROTOCOL_VERSION)
    if serverInfo then
        Questie:Print("[Server bridge] Server: mod-questie-bridge " .. serverInfo.version .. "; protocol "
            .. serverInfo.protocol .. "; AC revision " .. serverInfo.revision .. " (last handshake "
            .. math.floor(GetTime() - serverInfo.receivedAt) .. "s ago)")
    else
        Questie:Print("[Server bridge] Server version information unavailable.")
    end
    if not Fresh() then
        if serverInfo and serverInfo.status == "MISMATCH" then
            Questie:Print("[Server bridge] Last handshake: protocol mismatch; client requires " .. PROTOCOL_VERSION
                .. ", server provides " .. serverInfo.protocol .. ". Install matching Questie and module builds.")
        elseif serverInfo and serverInfo.status == "DISABLED" then
            Questie:Print("[Server bridge] Last handshake: bridge disabled or no state capabilities enabled.")
        elseif pendingUntil then
            Questie:Print("[Server bridge] Waiting for a complete server snapshot.")
        elseif not serverInfo then
            Questie:Print("[Server bridge] No bridge response; module may be absent or communication unavailable.")
        end
        Questie:Print("[Server bridge] No fresh server state; using existing calendar and manual settings.")
        return
    end
    local caps = {}
    for cap in pairs(snapshot.caps) do caps[#caps + 1] = cap end
    table.sort(caps)
    Questie:Print("[Server bridge] Live state (" .. math.floor(GetTime() - lastReplyAt) .. "s): " .. table.concat(caps, ", "))
    Questie:Print("[Server bridge] Updates this session: " .. snapshotCount .. " snapshots, " .. heartbeatCount .. " heartbeats")
    local poolQuests = self:GetPooledQuests(poolId)
    if not poolQuests then
        Questie:Print("[Server bridge] Quest pool selection unavailable.")
    else
        local db = QuestieLoader:ImportModule("QuestieDB")
        local pools, selected, unknown = {}, 0, 0
        for _, id in ipairs(poolQuests) do
            pools[self:GetQuestPoolId(id)] = true
            local active = self:IsPooledQuestActive(id)
            if active then selected = selected + 1 end
            local name = db.QueryQuestSingle(id, "name")
            if not name then unknown = unknown + 1 end
            if poolId then
                Questie:Print("[Server bridge] Pool " .. poolId .. ": " .. id .. " "
                    .. (active and "selected" or "inactive") .. " - " .. (name or "unknown to Questie"))
            end
        end
        local poolCount = 0
        for _ in pairs(pools) do poolCount = poolCount + 1 end
        Questie:Print("[Server bridge] Quest pools: " .. poolCount .. " pools, " .. #poolQuests
            .. " quests, " .. selected .. " selected, " .. unknown .. " unknown to Questie")
        if poolId then
            if #poolQuests == 0 then Questie:Print("[Server bridge] No reported quest members for pool " .. poolId) end
            return
        end
    end
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
    Questie:Print("[Server bridge] Kalu'ak turn-ins 63: " .. tostring(self:IsEventActive(63))
        .. "; derby finished: " .. tostring(self:IsKaluakDerbyFinished()))
    self:PrintWintergraspStatus(false)
    if self:HasCapability("ICC") then self:PrintICCStatus(false) end
    if self:HasCapability("RESETS") then self:PrintResetStatus() end
    if self:HasCapability("PHASES") then self:PrintPhaseStatus() end
end

function QuestieServer:PrintResetStatus()
    local resets = self:GetQuestResetTimes()
    if not resets then
        Questie:Print("[Server bridge] Server quest reset timing unavailable; using Questie's fallback schedule.")
        return
    end
    for _, period in ipairs({"weekly", "monthly"}) do
        local remaining = math.max(0, math.ceil(resets[period] - resets.serverTime))
        Questie:Print("[Server bridge] " .. period:gsub("^%l", string.upper)
            .. " quest reset: " .. resets[period] .. " (Unix seconds); in " .. remaining .. "s")
    end
end

function QuestieServer:PrintPhaseStatus()
    local context = self:GetPhaseContext()
    if not context then
        Questie:Print("[Server bridge] Phase visibility unavailable; using Questie's usual locations.")
        return
    end
    Questie:Print("[Server bridge] Phase context: map " .. context.map .. "; zone " .. context.zone
        .. "; area " .. context.area .. "; mask " .. context.mask)
    local region = self:GetPhaseRegion(context)
    if not region then
        Questie:Print("[Server bridge] Outside supported story regions; using Questie's usual locations.")
        return
    end
    Questie:Print("[Server bridge] Story-phase locations: " .. region .. "; current subarea only.")
    local visible, hidden = {}, {}
    for _, mask in ipairs(phaseMasks) do
        local list = self:GetSpawnPhaseVisibility(context.map, context.area, mask) and visible or hidden
        list[#list + 1] = tostring(mask)
    end
    Questie:Print("[Server bridge] Visible spawn masks: " .. table.concat(visible, ", "))
    Questie:Print("[Server bridge] Hidden spawn masks: " .. table.concat(hidden, ", "))
end

function QuestieServer:PrintICCStatus(detailed)
    local state = self:GetICCState()
    if not state or not state.loaded then
        Questie:Print("[Server bridge] ICC weekly selection unavailable" .. (iccContextPending and "; updating raid context." or "."))
        return
    end
    if not state.inside then
        Questie:Print("[Server bridge] ICC: outside the raid; using existing quest availability.")
        return
    end
    local difficulties = {[0] = "10-player Normal", [1] = "25-player Normal",
        [2] = "10-player Heroic", [3] = "25-player Heroic"}
    local db = QuestieLoader:ImportModule("QuestieDB")
    local family = state.family == 0 and "not selected (defeat Lord Marrowgar)"
        or (db.QueryQuestSingle(state.family, "name") or ("unknown family " .. state.family))
    Questie:Print("[Server bridge] ICC: instance " .. state.instance .. "; " .. difficulties[state.difficulty]
        .. "; weekly family: " .. family)
    if state.family == 24872 and not state.respiteReady then
        Questie:Print("[Server bridge] ICC: Respite unlock pending; rescue Valithria Dreamwalker.")
    end
    if detailed then
        for _, id in ipairs(self:GetICCQuests()) do
            Questie:Print("[Server bridge] ICC quest " .. id .. " "
                .. (self:GetQuestAvailabilityState(id) and "permitted" or "inactive")
                .. " - " .. (db.QueryQuestSingle(id, "name") or "unknown to Questie"))
        end
    end
end

function QuestieServer:PrintWintergraspStatus(detailed)
    local state = self:GetWintergraspState()
    if not state then
        Questie:Print("[Server bridge] Wintergrasp state unavailable.")
        return
    end
    if not state.loaded then
        Questie:Print("[Server bridge] Wintergrasp: battlefield not initialized; quest gates unknown.")
        return
    end
    local teams = {[0] = "Alliance", [1] = "Horde"}
    Questie:Print("[Server bridge] Wintergrasp: enabled " .. tostring(state.enabled)
        .. "; battle " .. tostring(state.battle) .. "; defender " .. teams[state.defender]
        .. "; attacker " .. teams[1 - state.defender])
    if detailed then
        local db = QuestieLoader:ImportModule("QuestieDB")
        for _, id in ipairs(self:GetWintergraspQuests()) do
            Questie:Print("[Server bridge] Wintergrasp quest " .. id .. " "
                .. (self:GetQuestAvailabilityState(id) and "permitted" or "inactive")
                .. " - " .. (db.QueryQuestSingle(id, "name") or "unknown to Questie"))
        end
    end
end

function QuestieServer:Initialize()
    if frame or not QuestieCompat.Is335 then return end
    Integrations:Initialize()
    frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:SetScript("OnEvent", function(_, event, prefix, message, distribution, sender)
        if event == "CHAT_MSG_ADDON" and prefix == PREFIX then
            HandleMessage(message, distribution, sender)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
            or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
            local _, instanceType = IsInInstance()
            local refreshICC = (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA")
                and snapshot and snapshot.caps.ICC and (snapshot.icc.inside or instanceType == "raid")
            local refreshPhases = snapshot and snapshot.caps.PHASES
            if refreshICC or refreshPhases then
                -- Clear old local context immediately. A new WATCH/token prevents
                -- an in-flight reply or heartbeat from restoring the previous area/raid.
                iccContextPending = refreshICC or iccContextPending
                phaseContextPending = refreshPhases or phaseContextPending
                pendingUntil, pendingRenewal, assembly, watchToken = nil, false, nil, nil
                forceSnapshot, nextRequestAt = true, 0
                Integrations:Refresh()
            end
        end
    end)
    frame:SetScript("OnUpdate", function()
        local now = GetTime()
        if pendingUntil and now >= pendingUntil then
            pendingUntil, assembly, watchToken = nil, nil, nil
            if pendingRenewal or subscriptionsDirty then
                -- A server restart/config change can remove the subscription.
                -- A failed renewal recovers through a new full WATCH request.
                forceSnapshot, nextRequestAt = true, 0
            end
            pendingRenewal = false
        end
        if assembly and now > assembly.untilTime then assembly = nil end
        if snapshot and not Fresh() then
            snapshot, lastReplyAt, snapshotToken, snapshotSequence = nil, nil, nil, nil
            pendingUntil, pendingRenewal, assembly = nil, false, nil
            forceSnapshot, nextRequestAt = true, 0
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
    SlashCmdList.QUESTIESERVER = function(command)
        command = command or ""
        if command:match("^%s*$") then self:PrintStatus(); return end
        if command:match("^%s*wintergrasp%s*$") then self:PrintWintergraspStatus(true); return end
        if command:match("^%s*icc%s*$") then self:PrintICCStatus(true); return end
        if command:match("^%s*resets%s*$") then self:PrintResetStatus(); return end
        if command:match("^%s*phases%s*$") then self:PrintPhaseStatus(); return end
        local id = Integer(command:match("^%s*pool%s+(%d+)%s*$"), 4294967295)
        if id and id > 0 then self:PrintStatus(id); return end
        Questie:Print("[Server bridge] Usage: /qserver, /qserver pool <pool ID>, /qserver wintergrasp, /qserver icc, /qserver resets, or /qserver phases")
    end
    Request()
end
