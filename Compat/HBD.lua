---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap");
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB");
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n");
local C_Timer = QuestieCompat.C_Timer

local mapData = QuestieCompat.UiMapData -- table { width, height, left, top, .instance, .name, .mapType }
local worldMapData = QuestieCompat.worldMapData -- table { width, height, left, top }
local zoneNameToAreaId

local HBD = {mapData = mapData}
QuestieCompat.HBD = HBD

--- Convert local/point coordinates to world coordinates in yards
-- @param x X position in 0-1 point coordinates
-- @param y Y position in 0-1 point coordinates
-- @param zone uiMapID of the zone
function HBD:GetWorldCoordinatesFromZone(x, y, zone)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil, nil end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, data.instance
end

--- Convert world coordinates to local/point zone coordinates
-- @param x Global X position
-- @param y Global Y position
-- @param zone uiMapID of the zone
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetZoneCoordinatesFromWorld(x, y, zone, allowOutOfBounds)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Convert world coordinates to local/point zone coordinates on the azeroth world map
-- @param x Global X position
-- @param y Global Y position
-- @param instance Instance to translate coordinates from
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetAzerothWorldMapCoordinatesFromWorld(x, y, instance, allowOutOfBounds)
    local data = worldMapData[instance]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Return the distance from an origin position to a destination position in the same instance/continent.
-- @param instanceID instance ID
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return distance, deltaX, deltaY
function HBD:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

--- Return the distance between two points on the same continent
-- @param oZone origin zone uiMapID
-- @param oX origin X, in local zone/point coordinates
-- @param oY origin Y, in local zone/point coordinates
-- @param dZone destination zone uiMapID
-- @param dX destination X, in local zone/point coordinates
-- @param dY destination Y, in local zone/point coordinates
-- @return distance, deltaX, deltaY in yards
function HBD:GetZoneDistance(oZone, oX, oY, dZone, dX, dY)
    local oInstance, dInstance
    oX, oY, oInstance = self:GetWorldCoordinatesFromZone(oX, oY, oZone)
    if not oX then return nil, nil, nil end

    -- translate dX, dY to the origin zone
    dX, dY, dInstance = self:GetWorldCoordinatesFromZone(dX, dY, dZone)
    if not dX then return nil, nil, nil end

    if oInstance ~= dInstance then return nil, nil, nil end

    return self:GetWorldDistance(oInstance, oX, oY, dX, dY)
end

--- Get the current world position of the player
-- The position is transformed to the current continent, if applicable
-- @return x, y, instanceID
function HBD:GetPlayerWorldPosition()
    local x, y, instanceID = QuestieCompat.GetCurrentPlayerStableWorldPosition()
    if x and y then
        return x, y, instanceID
    end
    return nil, nil, nil
end

--- Get the current zone and level of the player
-- The returned mapFile can represent a micro dungeon, if the player currently is inside one.
-- @return uiMapID, mapType
function HBD:GetPlayerZone()
    return QuestieCompat.GetCurrentPlayerPosition()
end

--- Get the current position of the player on a zone level
-- The returned values are local point coordinates, 0-1. The mapFile can represent a micro dungeon.
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
-- @return x, y, uiMapID, mapType
function HBD:GetPlayerZonePosition(allowOutOfBounds)
    -- get the current position
    local uiMapID, x, y = QuestieCompat.GetCurrentPlayerPosition()

    if uiMapID and x and y then
        return x, y, uiMapID
    end
    return nil, nil, nil, nil
end

-- Data Constants
local WORLD_MAP_ID = 947

-- upvalue lua api
local cos, sin, max = math.cos, math.sin, math.max
local type, pairs = type, pairs

-- upvalue wow api
local GetPlayerFacing = GetPlayerFacing

-- storage for minimap pins
local minimapPins = {}
local activeMinimapPins = {}
local minimapPinRegistry = {}

-- and worldmap pins
local worldmapPins = {}
local worldmapPinRegistry = {}

local pins = {
    Minimap = Minimap,
    updateFrame = CreateFrame("Frame"),
    activeMinimapPins = activeMinimapPins,
    worldmapPins = worldmapPins,
    worldmapProvider = {
        GetMap = function(self) return QuestieCompat.WorldMapFrame end,
    },
}
QuestieCompat.HBDPins = pins

local minimap_size = {
    indoor = {
        [0] = 300, -- scale
        [1] = 240, -- 1.25
        [2] = 180, -- 5/3
        [3] = 120, -- 2.5
        [4] = 80,  -- 3.75
        [5] = 50,  -- 6
    },
    outdoor = {
        [0] = 466 + 2/3, -- scale
        [1] = 400,       -- 7/6
        [2] = 333 + 1/3, -- 1.4
        [3] = 266 + 2/6, -- 1.75
        [4] = 200,       -- 7/3
        [5] = 133 + 1/3, -- 3.5
    },
}

---@class MinimapShapes
local minimap_shapes = {
    -- { upper-left, lower-left, upper-right, lower-right }
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
    ["SIDE-LEFT"]             = { true,  true,  false, false },
    ["SIDE-RIGHT"]            = { false, false, true,  true },
    ["SIDE-TOP"]              = { true,  false, true,  false },
    ["SIDE-BOTTOM"]           = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

local tableCache = setmetatable({}, {__mode='k'})

local function newCachedTable()
    local t = next(tableCache)
    if t then
        tableCache[t] = nil
    else
        t = {}
    end
    return t
end

local function recycle(t)
    tableCache[t] = true
end

-------------------------------------------------------------------------------------------
-- Minimap pin position logic

-- minimap rotation
local rotateMinimap = GetCVar("rotateMinimap") == "1"

-- is the minimap indoors or outdoors
local indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"

local minimapPinCount, queueFullUpdate = 0, false
---@type unknown, MinimapShapes?
local minimapScale, minimapShape, mapRadius, minimapWidth, minimapHeight, mapSin, mapCos
local lastZoom, lastFacing, lastXY, lastYY
local worldMapLayoutDirty = true
local worldMapRefreshPending = false
local minimapZoomProbeReady = false
local minimapZoomProbeScheduled = false
local lastWorldMapUiMapID, lastWorldMapWidth, lastWorldMapHeight, lastWorldMapScale

local function _HasTrackedMinimapPins()
    return next(minimapPins) ~= nil or next(activeMinimapPins) ~= nil
end

local function drawMinimapPin(pin, data)
    local xDist, yDist = lastXY - data.x, lastYY - data.y

    -- handle rotation
    if rotateMinimap then
        local dx, dy = xDist, yDist
        xDist = dx*mapCos - dy*mapSin
        yDist = dx*mapSin + dy*mapCos
    end

    -- adapt delta position to the map radius
    local diffX = xDist / mapRadius
    local diffY = yDist / mapRadius

    -- different minimap shapes
    ---@type boolean|number
    local isRound = true
    if minimapShape and not (xDist == 0 or yDist == 0) then
        isRound = (xDist < 0) and 1 or 3
        if yDist < 0 then
            isRound = minimapShape[isRound]
        else
            isRound = minimapShape[isRound + 1]
        end
    end

    -- calculate distance from the center of the map
    local dist
    if isRound then
        dist = (diffX*diffX + diffY*diffY) / 0.9^2
    else
        dist = max(diffX*diffX, diffY*diffY) / 0.9^2
    end

    -- if distance > 1, then adapt node position to slide on the border
    if dist > 1 and data.floatOnEdge then
        dist = dist^0.5
        diffX = diffX/dist
        diffY = diffY/dist
    end

    -- Questie Modification.
    -- data.floatOnEdge is replaced by (data.floatOnEdge and ((pin.texture and pin.texture.a and pin.texture.a ~= 0) or pin.texture == nil))
    -- icons will now only float on edge if they have an opacity which is not 0 or if no texture exist.
    data.distanceFromMinimapCenter = dist
    if dist <= 1 or (data.floatOnEdge and ((pin.texture and pin.texture.a and pin.texture.a ~= 0) or pin.texture == nil)) then
        pin:Show()
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", pins.Minimap, "CENTER", diffX * minimapWidth, -diffY * minimapHeight)
        data.onEdge = (dist > 1)
    else
        pin:Hide()
        data.onEdge = nil
        pin.keep = nil
    end
end

local function IsWorldPositionInsideUiMap(worldX, worldY, uiMapID)
    if not worldX or not worldY or not uiMapID then
        return false
    end

    local zoneX, zoneY = HBD:GetZoneCoordinatesFromWorld(worldX, worldY, uiMapID, true)
    return zoneX and zoneY and zoneX >= -0.05 and zoneX <= 1.05 and zoneY >= -0.05 and zoneY <= 1.05
end

local function GetZoneNameToAreaId()
    if zoneNameToAreaId then
        return zoneNameToAreaId
    end

    zoneNameToAreaId = {}
    if not l10n or not l10n.zoneLookup then
        return zoneNameToAreaId
    end

    for _, lookupTable in pairs(l10n.zoneLookup) do
        if type(lookupTable) == "table" then
            for areaId, zoneName in pairs(lookupTable) do
                if zoneName and zoneName ~= "" and not zoneNameToAreaId[zoneName] then
                    zoneNameToAreaId[zoneName] = areaId
                end
            end
        end
    end

    return zoneNameToAreaId
end

local function GetBestAreaIdForUiMap(uiMapID)
    if not uiMapID then
        return nil
    end

    local uiMapData = mapData[uiMapID]
    local zoneName = uiMapData and uiMapData.name
    local namedAreaId = zoneName and GetZoneNameToAreaId()[zoneName]
    if namedAreaId then
        return namedAreaId
    end

    if ZoneDB and ZoneDB.GetAreaIdByUiMapId then
        local success, areaId = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, uiMapID)
        if success then
            return areaId
        end
    end

    return nil
end

local function IsParentZoneUiMapForNamedSubZone(pinUiMapID, currentUiMapID)
    if not pinUiMapID or not currentUiMapID or pinUiMapID == currentUiMapID then
        return false
    end

    local pinMapData = mapData[pinUiMapID]
    local currentMapData = mapData[currentUiMapID]
    if not pinMapData or not currentMapData or pinMapData.instance ~= currentMapData.instance then
        return false
    end

    if not ZoneDB or not ZoneDB.GetParentZoneId then
        return false
    end

    local currentAreaId = GetBestAreaIdForUiMap(currentUiMapID)
    local parentAreaId = currentAreaId and ZoneDB:GetParentZoneId(currentAreaId)
    if not parentAreaId then
        return false
    end

    return GetBestAreaIdForUiMap(pinUiMapID) == parentAreaId
end

local function IsEquivalentZoneSiblingUiMap(leftUiMapID, rightUiMapID)
    if not leftUiMapID or not rightUiMapID or leftUiMapID == rightUiMapID then
        return false
    end

    local leftMapData = HBD.mapData[leftUiMapID]
    local rightMapData = HBD.mapData[rightUiMapID]
    if not leftMapData or not rightMapData then
        return false
    end

    return leftMapData.name
        and rightMapData.name
        and leftMapData.name == rightMapData.name
        and leftMapData.parentMapID
        and leftMapData.parentMapID == rightMapData.parentMapID
        and leftMapData.instance
        and leftMapData.instance == rightMapData.instance
end

local function ShouldShowMinimapPinForUiMap(data, currentUiMapID)
    local pinUiMapID = data and data.uiMapID
    local showInParentZone = data and data.showInParentZone
    if not pinUiMapID or not currentUiMapID then
        return true
    end

    if pinUiMapID == currentUiMapID then
        return true
    end

    if IsEquivalentZoneSiblingUiMap(pinUiMapID, currentUiMapID)
        and IsWorldPositionInsideUiMap(data and data.x, data and data.y, currentUiMapID) then
        return true
    end

    if showInParentZone
        and IsParentZoneUiMapForNamedSubZone(pinUiMapID, currentUiMapID)
        and IsWorldPositionInsideUiMap(data and data.x, data and data.y, currentUiMapID) then
        return true
    end

    if not showInParentZone then
        return false
    end

    local parentMapID = HBD.mapData[pinUiMapID] and HBD.mapData[pinUiMapID].parentMapID
    while parentMapID and HBD.mapData[parentMapID] do
        if parentMapID == currentUiMapID then
            return true
        end

        parentMapID = HBD.mapData[parentMapID].parentMapID
    end

    return false
end

local function UpdateMinimapPins(force)
    if not _HasTrackedMinimapPins() then
        minimapPinCount = 0
        lastXY, lastYY = nil, nil
        return
    end

    -- get the current player position
    local x, y, instanceID, currentUiMapID = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()

    -- get data from the API for calculations
    local zoom = pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom

    -- for rotating minimap support
    local facing
    if rotateMinimap then
        facing = GetPlayerFacing()
    else
        facing = lastFacing
    end

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y or (rotateMinimap and not facing) then
        minimapPinCount = 0
        for pin in pairs(activeMinimapPins) do
            pin:Hide()
            activeMinimapPins[pin] = nil
        end
        lastXY, lastYY = nil, nil
        return
    end

    local newScale = pins.Minimap:GetScale()
    if minimapScale ~= newScale then
        minimapScale = newScale
        force = true
    end

    if minimapPinCount == 0 or x ~= lastXY or y ~= lastYY or diffZoom or facing ~= lastFacing or force then
        -- minimap information
        minimapShape = GetMinimapShape and minimap_shapes[GetMinimapShape() or "ROUND"]
        minimapWidth = pins.Minimap:GetWidth() / 2
        minimapHeight = pins.Minimap:GetHeight() / 2
        if MinimapRadiusAPI then
            mapRadius = C_Minimap.GetViewRadius()
        else
            mapRadius = minimap_size[indoors][zoom] / 2
        end

        -- update upvalues for icon placement
        lastZoom = zoom
        lastFacing = facing
        lastXY, lastYY = x, y

        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end

        for pin, data in pairs(minimapPins) do
            if instanceID == data.instanceID
                and ShouldShowMinimapPinForUiMap(data, currentUiMapID)
                and math.abs(x-data.x) + math.abs(y-data.y) < 500 then -- questie specific fix
                activeMinimapPins[pin] = data
                data.keep = true
                -- draw the pin (this may reset data.keep if outside of the map)
                drawMinimapPin(pin, data)
            end
        end

        minimapPinCount = 0
        for pin, data in pairs(activeMinimapPins) do
            if not data.keep then
                pin:Hide()
                activeMinimapPins[pin] = nil
            else
                minimapPinCount = minimapPinCount + 1
                data.keep = nil
            end
        end
    end
end

local function UpdateMinimapIconPosition()
    if next(activeMinimapPins) == nil then
        minimapPinCount = 0
        return
    end

    -- get the current map  zoom
    local zoom = pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom
    -- if the map zoom changed, run a full update sweep
    if diffZoom then
        UpdateMinimapPins()
        return
    end

    -- we have no active minimap pins, just return early
    if minimapPinCount == 0 then return end

    local x, y = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()

    -- for rotating minimap support
    local facing
    if rotateMinimap then
        facing = GetPlayerFacing()
    else
        facing = lastFacing
    end

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y or (rotateMinimap and not facing) then
        UpdateMinimapPins()
        return
    end

    local refresh
    local newScale = pins.Minimap:GetScale()
    if minimapScale ~= newScale then
        minimapScale = newScale
        refresh = true
    end

    if x ~= lastXY or y ~= lastYY or facing ~= lastFacing or refresh then
        -- update radius of the map
        if MinimapRadiusAPI then
            mapRadius = C_Minimap.GetViewRadius()
        else
            mapRadius = minimap_size[indoors][zoom] / 2
        end
        -- update upvalues for icon placement
        lastXY, lastYY = x, y
        lastFacing = facing

        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end

        -- iterate all nodes and check if they are still in range of our minimap display
        for pin, data in pairs(activeMinimapPins) do
            -- update the position of the node
            drawMinimapPin(pin, data)
        end
    end
end

local function UpdateMinimapZoom()
    if not MinimapRadiusAPI then
        if not minimapZoomProbeReady then
            return
        end
        local zoom = pins.Minimap:GetZoom()
        if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
            pins.Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        end
        indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"
        pins.Minimap:SetZoom(zoom)
    end
end

-------------------------------------------------------------------------------------------
-- WorldMap data provider

local Enum = {
    -- https://wowpedia.fandom.com/wiki/Enum.UIMapType
	UIMapType = {
		Cosmic = 0,
		World = 1,
		Continent = 2,
		Zone = 3,
		Dungeon = 4,
		Micro = 5,
		Orphan = 6
	}
}

local worldmapWidth, worldmapHeight

local function HandleWorldMapPin(icon, data, uiMapID)
    if not WorldMapFrame:IsVisible() then return end

    -- check for a valid map
    if not uiMapID then return end

    --Questie Modification
    if (Questie.db.profile.hideIconsOnContinents == true) and (HBD.mapData[uiMapID].mapType == Enum.UIMapType.Continent or uiMapID == 947) or (uiMapID ~= data.uiMapID and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT) then
        icon:Hide();
        return;
    elseif(uiMapID == data.uiMapID and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT) then
        icon:Show();
    end

    if icon.type == "line" then return end

    local x, y
    if uiMapID == WORLD_MAP_ID then
        -- should this pin show on the world map?
        if uiMapID ~= data.uiMapID and data.worldMapShowFlag ~= HBD_PINS_WORLDMAP_SHOW_WORLD then return end

        -- translate to the world map
        x, y = HBD:GetAzerothWorldMapCoordinatesFromWorld(data.x, data.y, data.instanceID)
    else
        -- check that it matches the instance
        if not HBD.mapData[uiMapID] or HBD.mapData[uiMapID].instance ~= data.instanceID then return end

        if uiMapID ~= data.uiMapID then
            local mapType = HBD.mapData[uiMapID].mapType
            if not data.uiMapID then
                if mapType == Enum.UIMapType.Continent and data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT then
                    --pass
                elseif mapType ~= Enum.UIMapType.Zone and mapType ~= Enum.UIMapType.Dungeon and mapType ~= Enum.UIMapType.Micro then
                    -- fail
                    return
                end
            else
                local currentMapData = HBD.mapData[uiMapID]
                local iconMapData = HBD.mapData[data.uiMapID]
                if not iconMapData then
                    return
                end

                local show = currentMapData.mapType == Enum.UIMapType.Zone and
                    iconMapData.mapType == Enum.UIMapType.Zone and
                    currentMapData.parentMapID == iconMapData.parentMapID
                -- World-map-only starter zones still need ancestor-zone pins projected into
                -- the child rectangle when the world coordinates fall inside it.
                local currentParentMapID = currentMapData.parentMapID
                while (not show) and currentParentMapID and HBD.mapData[currentParentMapID] do
                    if currentParentMapID == data.uiMapID then
                        local parentMapType = HBD.mapData[currentParentMapID].mapType
                        if data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_PARENT and
                            (parentMapType == Enum.UIMapType.Zone or parentMapType == Enum.UIMapType.Dungeon or parentMapType == Enum.UIMapType.Micro) then
                            show = true
                        elseif data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT and
                            parentMapType == Enum.UIMapType.Continent then
                            show = true
                        end
                        break
                    end
                    currentParentMapID = HBD.mapData[currentParentMapID].parentMapID
                end
                local parentMapID = iconMapData.parentMapID
                while parentMapID and HBD.mapData[parentMapID] do
                    if parentMapID == uiMapID then
                        local parentMapType = HBD.mapData[parentMapID].mapType
                        -- show on any parent zones if they are normal zones
                        if data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_PARENT and
                            (parentMapType == Enum.UIMapType.Zone or parentMapType == Enum.UIMapType.Dungeon or parentMapType == Enum.UIMapType.Micro) then
                            show = true
                        -- show on the continent
                        elseif data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT and
                            parentMapType == Enum.UIMapType.Continent then
                            show = true
                        elseif data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT then
                            -- Questie modifications!
                            show = false
                        end
                        break
                        -- worldmap is handled above already
                    else
                        parentMapID = HBD.mapData[parentMapID].parentMapID
                    end
                end

                if not show then return end
            end
        end

        -- translate coordinates
        x, y = HBD:GetZoneCoordinatesFromWorld(data.x, data.y, uiMapID)
    end

    if x and y then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * worldmapWidth, -y * worldmapHeight)
        icon:Show()
    else
        icon:Hide()
    end
end

-- map event handling
local function UpdateMinimap()
    UpdateMinimapZoom()
    UpdateMinimapPins()
end

local function ScheduleInitialMinimapZoomProbe()
    if minimapZoomProbeReady or minimapZoomProbeScheduled then
        return
    end

    minimapZoomProbeScheduled = true

    if not C_Timer or not C_Timer.After then
        minimapZoomProbeReady = true
        minimapZoomProbeScheduled = false
        UpdateMinimap()
        return
    end

    -- Delay the zoom probe until the client has finished restoring its saved minimap zoom.
    C_Timer.After(1, function()
        minimapZoomProbeReady = true
        minimapZoomProbeScheduled = false
        UpdateMinimap()
    end)
end

local function HideWorldMapPins()
    for icon in pairs(worldmapPins) do
        icon:Hide()
        icon:ClearAllPoints()
    end
    worldMapLayoutDirty = true
    lastWorldMapUiMapID, lastWorldMapWidth, lastWorldMapHeight, lastWorldMapScale = nil, nil, nil, nil
end

local function UpdateWorldMap(force)
    if QuestieCompat.IsInternalMapReadActive and QuestieCompat.IsInternalMapReadActive() then
        return
    end

    if not WorldMapFrame:IsVisible() then return end

    local uiMapID = QuestieCompat.GetCurrentUiMapID()
    if not uiMapID then return end

    worldmapWidth  = WorldMapButton:GetWidth()
    worldmapHeight = WorldMapButton:GetHeight()

    local mapScale = QuestieMap.GetScaleValue()
    local shouldRescale = force or worldMapLayoutDirty or mapScale ~= lastWorldMapScale
    if (not force)
        and (not worldMapLayoutDirty)
        and uiMapID == lastWorldMapUiMapID
        and worldmapWidth == lastWorldMapWidth
        and worldmapHeight == lastWorldMapHeight
        and mapScale == lastWorldMapScale then
        return
    end

    for icon, data in pairs(worldmapPins) do
        icon:Hide()
        --icon:ClearAllPoints()

        if shouldRescale then
            QuestieMap.utils:RescaleIcon(icon, mapScale)
        end
        HandleWorldMapPin(icon, data, uiMapID)
    end

    worldMapLayoutDirty = false
    lastWorldMapUiMapID = uiMapID
    lastWorldMapWidth = worldmapWidth
    lastWorldMapHeight = worldmapHeight
    lastWorldMapScale = mapScale
end
pins.UpdateWorldMap = UpdateWorldMap

local function QueueWorldMapRefresh()
    if worldMapRefreshPending then
        return
    end

    if not C_Timer or not C_Timer.After then
        UpdateWorldMap()
        return
    end

    worldMapRefreshPending = true
    C_Timer.After(0.01, function()
        worldMapRefreshPending = false
        if WorldMapFrame and WorldMapFrame:IsVisible() then
            UpdateWorldMap()
        end
    end)
end

local function EnsureWorldMapLifecycleHooks()
    if not WorldMapFrame or WorldMapFrame.questieWorldMapPinsLifecycleHooked then
        return
    end

    WorldMapFrame.questieWorldMapPinsLifecycleHooked = true
    WorldMapFrame:HookScript("OnShow", function()
        UpdateWorldMap()
        QueueWorldMapRefresh()
    end)
    WorldMapFrame:HookScript("OnHide", HideWorldMapPins)
end

local lastFullUpdate = 0
local lastIconUpdate = 0
local function OnUpdateHandler(frame, elapsed)
    if not queueFullUpdate and not _HasTrackedMinimapPins() then
        lastFullUpdate = 0
        lastIconUpdate = 0
        return
    end

    lastFullUpdate = lastFullUpdate + elapsed
    lastIconUpdate = lastIconUpdate + elapsed

    if lastFullUpdate > 1 or queueFullUpdate then
        UpdateMinimapPins(queueFullUpdate)
        lastFullUpdate = 0
        lastIconUpdate = 0
        queueFullUpdate = false
    elseif lastIconUpdate > 0.05 then
        UpdateMinimapIconPosition()
        lastIconUpdate = 0
    end
end
pins.updateFrame:SetScript("OnUpdate", OnUpdateHandler)

local function OnEventHandler(frame, event, ...)
    if QuestieCompat.ClearCachedPlayerPositions then
        QuestieCompat.ClearCachedPlayerPositions()
    end

    if event == "CVAR_UPDATE" then
        local cvar, value = ...
        if cvar == "ROTATE_MINIMAP" then
            rotateMinimap = (value == "1")
            queueFullUpdate = true
        end
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        minimapZoomProbeReady = true
        minimapZoomProbeScheduled = false
        UpdateMinimap()
    elseif event == "PLAYER_LOGIN" then
        -- recheck cvars after login
        rotateMinimap = GetCVar("rotateMinimap") == "1"
        EnsureWorldMapLifecycleHooks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        EnsureWorldMapLifecycleHooks()
        UpdateMinimapPins()
        ScheduleInitialMinimapZoomProbe()
        UpdateWorldMap()
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMap()
    elseif string.find(event, "ZONE_CHANGED") then
        UpdateMinimap()
        UpdateWorldMap()
    end
end

pins.updateFrame:SetScript("OnEvent", OnEventHandler)
pins.updateFrame:RegisterEvent("CVAR_UPDATE")
pins.updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
pins.updateFrame:RegisterEvent("WORLD_MAP_UPDATE")
pins.updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pins.updateFrame:RegisterEvent("ZONE_CHANGED")
pins.updateFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
pins.updateFrame:RegisterEvent("PLAYER_LOGIN")
pins.updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Showing quest objectives does not trigger WORLD_MAP_UPDATE event
hooksecurefunc("WorldMapFrame_DisplayQuests", UpdateWorldMap)
EnsureWorldMapLifecycleHooks()

--- Add a icon to the minimap (x/y world coordinate version)
-- Note: This API does not let you specify a map to limit the pin to, it'll be shown on all maps these coordinates are valid for.
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param instanceID Instance ID of the map to add the icon to
-- @param x X position in world coordinates
-- @param y Y position in world coordinates
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconWorld(ref, icon, instanceID, x, y, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconWorld: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconWorld: 'icon' must be a frame", 2)
    end
    if type(instanceID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconWorld: 'instanceID', 'x' and 'y' must be numbers", 2)
    end

    if not minimapPinRegistry[ref] then
        minimapPinRegistry[ref] = {}
    end

    minimapPinRegistry[ref][icon] = true

    local t = minimapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = x
    t.y = y
    t.floatOnEdge = floatOnEdge
    t.uiMapID = nil
    t.showInParentZone = nil

    minimapPins[icon] = t
    queueFullUpdate = true

    icon:SetParent(pins.MinimapGroup or pins.Minimap)
end

--- Add a icon to the minimap (UiMapID zone coordinate version)
-- The pin will only be shown on the map specified, or optionally its parent map if specified
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param uiMapID uiMapID of the map to place the icon on
-- @param x X position in local/point coordinates (0-1), relative to the zone
-- @param y Y position in local/point coordinates (0-1), relative to the zone
-- @param showInParentZone flag if the icon should be shown in its parent zone - ie. an icon in a microdungeon in the outdoor zone itself (default false)
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconMap(ref, icon, uiMapID, x, y, showInParentZone, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconMap: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconMap: 'icon' must be a frame", 2)
    end
    if type(uiMapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconMap: 'uiMapID', 'x' and 'y' must be numbers", 2)
    end

    -- convert to world coordinates and use our known adding function
    local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if not xCoord then return end

    self:AddMinimapIconWorld(ref, icon, instanceID, xCoord, yCoord, floatOnEdge)

    -- store extra information
    minimapPins[icon].uiMapID = uiMapID
    minimapPins[icon].showInParentZone = showInParentZone
end

--- Check if a floating minimap icon is on the edge of the map
-- @param icon the minimap icon
function pins:IsMinimapIconOnEdge(icon)
    if not icon then return false end
    local data = minimapPins[icon]
    if not data then return nil end

    return data.onEdge
end

--- Remove a minimap icon
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
function pins:RemoveMinimapIcon(ref, icon)
    if not ref or not icon or not minimapPinRegistry[ref] then return end
    minimapPinRegistry[ref][icon] = nil
    if minimapPins[icon] then
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
    end
    icon:Hide()
end

--- Remove all minimap icons belonging to your addon (as tracked by "ref")
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllMinimapIcons(ref)
    if not ref or not minimapPinRegistry[ref] then return end
    for icon in pairs(minimapPinRegistry[ref]) do
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
        icon:Hide()
    end
    wipe(minimapPinRegistry[ref])
end

--- Set the minimap object to position the pins on. Needs to support the usual functions a Minimap-type object exposes.
-- @param minimapObject The new minimap object, or nil to restore the default
function pins:SetMinimapObject(minimapObject)
    pins.Minimap = minimapObject or Minimap
    for pin in pairs(minimapPins) do
        pin:SetParent(pins.Minimap)
    end
    UpdateMinimapPins(true)
end

-- world map constants
-- show worldmap pin only on zone map (Questie modification)
HBD_PINS_WORLDMAP_SHOW_CURRENT   = -1
-- show worldmap pin on its parent zone map (if any)
HBD_PINS_WORLDMAP_SHOW_PARENT    = 1
-- show worldmap pin on the continent map
HBD_PINS_WORLDMAP_SHOW_CONTINENT = 2
-- show worldmap pin on the continent and world map
HBD_PINS_WORLDMAP_SHOW_WORLD     = 3

--- Add a icon to the world map (x/y world coordinate version)
-- Note: This API does not let you specify a map to limit the pin to, it'll be shown on all maps these coordinates are valid for.
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param instanceID Instance ID of the map to add the icon to
-- @param x X position in world coordinates
-- @param y Y position in world coordinates
-- @param showFlag Flag to control on which maps this pin will be shown
-- @param frameLevel Optional Frame Level type registered with the WorldMapFrame, defaults to PIN_FRAME_LEVEL_AREA_POI
function pins:AddWorldMapIconWorld(ref, icon, instanceID, x, y, showFlag, frameLevel)
    if not ref then
        error(MAJOR..": AddWorldMapIconWorld: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddWorldMapIconWorld: 'icon' must be a frame", 2)
    end
    if type(instanceID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddWorldMapIconWorld: 'instanceID', 'x' and 'y' must be numbers", 2)
    end
    if showFlag ~= nil and type(showFlag) ~= "number" then
        error(MAJOR..": AddWorldMapIconWorld: 'showFlag' must be a number (or nil)", 2)
    end

    if not worldmapPinRegistry[ref] then
        worldmapPinRegistry[ref] = {}
    end

    worldmapPinRegistry[ref][icon] = true

    local t = worldmapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = x
    t.y = y
    t.uiMapID = nil
    t.worldMapShowFlag = showFlag or 0
    t.frameLevelType = frameLevel

    worldmapPins[icon] = t
    worldMapLayoutDirty = true

    icon.icon = icon --LOL!
    icon:SetParent(WorldMapButton)
    local currentUiMapID = WorldMapFrame and WorldMapFrame:IsVisible() and QuestieCompat.GetCurrentUiMapID() or nil
    HandleWorldMapPin(icon, t, currentUiMapID)
end

--- Add a icon to the world map (uiMapID zone coordinate version)
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param uiMapID uiMapID of the map to place the icon on
-- @param x X position in local/point coordinates (0-1), relative to the zone
-- @param y Y position in local/point coordinates (0-1), relative to the zone
-- @param showFlag Flag to control on which maps this pin will be shown
-- @param frameLevel Optional Frame Level type registered with the WorldMapFrame, defaults to PIN_FRAME_LEVEL_AREA_POI
function pins:AddWorldMapIconMap(ref, icon, uiMapID, x, y, showFlag, frameLevel)
    if not ref then
        error(MAJOR..": AddWorldMapIconMap: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddWorldMapIconMap: 'icon' must be a frame", 2)
    end
    if type(uiMapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddWorldMapIconMap: 'uiMapID', 'x' and 'y' must be numbers", 2)
    end
    if showFlag ~= nil and type(showFlag) ~= "number" then
        error(MAJOR..": AddWorldMapIconMap: 'showFlag' must be a number (or nil)", 2)
    end

    -- convert to world coordinates
    local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if not xCoord then return end

    if not worldmapPinRegistry[ref] then
        worldmapPinRegistry[ref] = {}
    end

    worldmapPinRegistry[ref][icon] = true

    local t = worldmapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = xCoord
    t.y = yCoord
    t.uiMapID = uiMapID
    t.worldMapShowFlag = showFlag or 0
    t.frameLevelType = frameLevel

    worldmapPins[icon] = t
    worldMapLayoutDirty = true

    icon.icon = icon --LOL!
    icon:SetParent(WorldMapButton)
    local currentUiMapID = WorldMapFrame and WorldMapFrame:IsVisible() and QuestieCompat.GetCurrentUiMapID() or nil
    HandleWorldMapPin(icon, t, currentUiMapID)
end

--- Remove a worldmap icon
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
function pins:RemoveWorldMapIcon(ref, icon)
    if not ref or not icon or not worldmapPinRegistry[ref] then return end
    worldmapPinRegistry[ref][icon] = nil
    if worldmapPins[icon] then
        recycle(worldmapPins[icon])
        worldmapPins[icon] = nil
        worldMapLayoutDirty = true
    end
    icon:Hide()
    icon:ClearAllPoints()
    icon:SetParent(UiParent)
end

--- Remove all worldmap icons belonging to your addon (as tracked by "ref")
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllWorldMapIcons(ref)
    if not ref or not worldmapPinRegistry[ref] then return end
    for icon in pairs(worldmapPinRegistry[ref]) do
        if worldmapPins[icon] then
            recycle(worldmapPins[icon])
            worldmapPins[icon] = nil
            worldMapLayoutDirty = true
        end
        icon:Hide()
        icon:ClearAllPoints()
        icon:SetParent(UiParent)
    end
    wipe(worldmapPinRegistry[ref])
end