-- Move existing questgiver notes from complete server samples. Static spawn
-- coordinates and patrol lines remain available as the fallback.
local Patrol = QuestieLoader:CreateModule("QuestieServerPatrol")
local Server = QuestieLoader:ImportModule("QuestieServer")
local DB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")
local Pins = QuestieCompat.HBDPins or LibStub("HereBeDragonsQuestie-Pins-2.0")
local entries, lastSample, dirty, nextCheck = {}, nil, false, 0
-- Native map-530 rectangles for the TBC starting zones displayed on client
-- continents. Keep aligned with the generators' ACORE_WORLD_RECT_OVERRIDES.
local nativeRects = {
    [3430] = {-4487.55, 11041.64}, [3433] = {-5283.35, 8266.65}, [3487] = {-6400.74, 10153.71},
    [3524] = {-10499.97, -2793.73}, [3525] = {-10075.01, -758.34}, [3557] = {-11066.36, -3609.69},
    [4080] = {-5301.99, 13568.71},
}

local function NpcEntry(data)
    if data.Type == "available" and not data.StarterType then return data.StarterEntryId end
    if data.Type == "complete" and not data.FinisherType then return data.FinisherEntryId end
    if data.Type == "manual" and data.spawnType == "monster" then return data.id end
end

local function InCurrentZone(areaID, zone)
    if areaID == zone then return true end
    -- Some client map floors have their own area ID. AC reports the parent
    -- zone (for example, Underbelly 4560 belongs to Dalaran 4395).
    local parent = areaID
    for _ = 1, 8 do
        parent = ZoneDB.GetParentZoneId and ZoneDB:GetParentZoneId(parent)
        if not parent then break end
        if parent == zone then return true end
    end
    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    return uiMapId ~= nil and uiMapId == ZoneDB:GetUiMapIdByAreaId(zone)
end

local function Select(data, areaID, spawn, state)
    local id = NpcEntry(data)
    if not id or not state then return end
    local spawnId = spawn and spawn[8]
    if spawnId and spawnId > 0 then
        local position = state.positions[spawnId]
        if position and position.entry == id then return position end
        return
    end
    -- Older data and waypoint-only markers are safe only when both the local
    -- static location and the live entry identify a single spawn.
    local npc = data.npcData or (DB.GetNPC and DB:GetNPC(id))
    local points = npc and npc.spawns and npc.spawns[areaID]
    local positions = state.byEntry[id]
    if (not npc) or (points and #points ~= 1) or (not positions) or #positions ~= 1 then return end
    if not InCurrentZone(areaID, state.zone) then return end
    return positions[1]
end

local function Convert(position, state, uiMapId, areaID)
    local map = HBD.mapData[uiMapId]
    if not map then return end
    local x, y
    local rect = state.map == 530 and nativeRects[areaID]
    if rect then
        x, y = (rect[1] - position.worldX) / map[1], (rect[2] - position.worldY) / map[2]
        if x < 0 or x > 1 or y < 0 or y > 1 then return end
    elseif state.map == map.instance then
        x, y = HBD:GetZoneCoordinatesFromWorld(position.worldX, position.worldY, uiMapId)
    end
    if not x or not y then return end
    local worldX, worldY, instance = HBD:GetWorldCoordinatesFromZone(x, y, uiMapId)
    return x * 100, y * 100, worldX, worldY, instance
end

function Patrol:GetDrawCoordinates(data, areaID, uiMapId, x, y, spawn)
    local state = Server:GetPatrolPositions()
    local position = Select(data, areaID, spawn, state)
    if position then
        local liveX, liveY = Convert(position, state, uiMapId, areaID)
        if liveX then return liveX, liveY end
    end
    return x, y
end

function Patrol:Register(icon, spawn, originalX, originalY)
    if not NpcEntry(icon.data) then return end
    local x, y = originalX or icon.x, originalY or icon.y
    local worldX, worldY, instance = HBD:GetWorldCoordinatesFromZone(x / 100, y / 100, icon.UiMapID)
    icon.serverPatrolTracked = true
    entries[icon] = {data = icon.data, spawn = spawn, x = x, y = y, worldX = worldX, worldY = worldY,
        instance = instance, live = icon.x ~= x or icon.y ~= y}
    dirty = true
end

function Patrol:Unregister(icon)
    icon.serverPatrolTracked = nil
    entries[icon] = nil
end

local function Apply(icon, x, y, worldX, worldY, instance)
    if not icon._loaded or icon._needsUnload then return false end
    if math.abs(icon.x - x) < 0.0001 and math.abs(icon.y - y) < 0.0001 then return true end
    if not Pins:MoveIconWorld(Questie, icon, instance, worldX, worldY) then return true end
    icon.x, icon.y, icon.worldX, icon.worldY = x, y, worldX, worldY
    if icon.ManualTooltipData and icon.ManualTooltipData.Body then
        for _, row in ipairs(icon.ManualTooltipData.Body) do
            if row[1] == "Coordinates:" then row[2] = string.format("%.2f, %.2f", x, y) end
        end
    end
    return true
end

function Patrol:Update(now)
    if now < nextCheck then return end
    nextCheck = now + 0.1 -- Check expiry/queued draws; movement happens only for new samples.
    if not next(entries) then lastSample = nil; return end
    local sample = Server:GetPatrolPositions()
    if sample == lastSample and not dirty then return end
    lastSample, dirty = sample, false
    local converted = {}
    for icon, entry in pairs(entries) do
        if icon.data ~= entry.data then
            entries[icon] = nil
        else
            local position = Select(entry.data, icon.AreaID, entry.spawn, sample)
            local coords
            if position then
                local key = position.spawn .. ":" .. icon.UiMapID
                if converted[key] == nil then converted[key] = {Convert(position, sample, icon.UiMapID, icon.AreaID)} end
                coords = converted[key]
            end
            if coords and coords[1] then
                if not Apply(icon, unpack(coords)) then dirty = true end
                entry.live = true
            elseif entry.live then
                if Apply(icon, entry.x, entry.y, entry.worldX, entry.worldY, entry.instance) then
                    entry.live = false
                else
                    dirty = true
                end
            elseif not icon._loaded and not icon._needsUnload then
                dirty = true
            end
        end
    end
end
