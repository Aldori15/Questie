---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local mapIdToUiMapId = {}
local zoneNameToUiMapId = {}
local zoneNameToAreaId = {}
local areaIdToZoneName = {}
local mapIdToCZ = {}
local mapCompatibilityInitialized = false
local UnitPosition = UnitPosition
local GetUnitSpeed = GetUnitSpeed
local lastKnownUiMapID = nil
local lastKnownZoneLikeUiMapID = nil
local lastStablePlayerWorldX = nil
local lastStablePlayerWorldY = nil
local lastStablePlayerInstanceID = nil
local lastStablePlayerUiMapID = nil
local lastMinimapPlayerWorldX = nil
local lastMinimapPlayerWorldY = nil
local lastMinimapPlayerInstanceID = nil
local lastMinimapPlayerUiMapID = nil
local anchoredDisplayedUiMapID = nil
local anchoredDisplayedWorldX = nil
local anchoredDisplayedWorldY = nil
local anchoredStableWorldX = nil
local anchoredStableWorldY = nil
local anchoredStableInstanceID = nil
local anchoredStableUiMapID = nil
local anchoredMinimapDisplayedUiMapID = nil
local anchoredMinimapDisplayedWorldX = nil
local anchoredMinimapDisplayedWorldY = nil
local anchoredMinimapWorldX = nil
local anchoredMinimapWorldY = nil
local anchoredMinimapInstanceID = nil
local anchoredMinimapUiMapID = nil
local internalMapReadDepth = 0
local internalMapReadSelection = nil
local worldMapInteractionSuppressUntil = 0
local playerPositionCache = {}
local stablePlayerWorldPositionCache = {}
local minimapPlayerWorldPositionCache = {}
local PLAYER_POSITION_CACHE_TTL = 0.075
local MIN_ZONE_COORD = -0.25
local MAX_ZONE_COORD = 1.25

local function IsValidZoneCoords(x, y)
    if not x or not y then return false end
    return x >= MIN_ZONE_COORD and x <= MAX_ZONE_COORD and y >= MIN_ZONE_COORD and y <= MAX_ZONE_COORD
end

local GetDisplayedWorldMapName
local minimapChildToParentRebaseUiMapId = {
    [467] = true,
    [468] = true,
}
local starterAreaIdToUiMapId = {
    [9] = 425,
    [132] = 427,
    [154] = 465,
    [188] = 460,
    [220] = 462,
    [221] = 462,
    [358] = 462,
    [363] = 461,
    [3431] = 467,
    [3526] = 468,
    [6170] = 425,
    [6176] = 427,
    [6450] = 460,
    [6451] = 461,
    [6452] = 462,
    [6454] = 465,
    [6455] = 467,
    [6456] = 468,
}
local zoneNameToUiMapIdOverrides = {
    -- Wrath's legacy zone texts can stay on surface Dalaran while the hidden map context
    -- correctly resolves to the Underbelly child map. Keep sewer-related aliases on 126.
    ["The Underbelly"] = 126,
    ["Circle of Wills"] = 126,
    ["Sewer Exit Pipe"] = 126,
    ["Dalaran Arena"] = 126,
    ["Deeprun Tram"] = 2257,
    ["The Deeprun Tram"] = 2257,
}

local function NormalizeMapKey(mapID, mapLevel)
    return math.floor((mapID + (mapLevel or 0) / 10) * 10 + 0.5) / 10
end

local function GetRawMapContext()
    if internalMapReadDepth > 0 and internalMapReadSelection and WorldMapFrame and WorldMapFrame:IsVisible() then
        return internalMapReadSelection.rawMapID, internalMapReadSelection.rawMapLevel
    end

    local mapID = GetCurrentMapAreaID()
    if mapID == 0 then -- both the "Cosmic" and "Azeroth" maps return a mapID of 0
        mapID = GetCurrentMapContinent()
    end
    local mapLevel = GetCurrentMapDungeonLevel() or 0
    return mapID, mapLevel
end

local function GetPlayerPositionCacheContextKey()
    local worldMapVisible = WorldMapFrame and WorldMapFrame:IsVisible() or false
    local rawMapID, rawMapLevel = GetRawMapContext()
    local zoneText = GetRealZoneText and GetRealZoneText() or ""
    local subZoneText = GetSubZoneText and GetSubZoneText() or ""
    local displayedMapName = ""

    if worldMapVisible then
        displayedMapName = GetDisplayedWorldMapName() or ""
    end

    return (worldMapVisible and "1" or "0")
        .. "|" .. tostring(rawMapID or 0)
        .. "|" .. tostring(rawMapLevel or 0)
        .. "|" .. zoneText
        .. "|" .. subZoneText
        .. "|" .. displayedMapName
end

local function TryGetCachedPlayerPosition(cache, maxAge, contextKey)
    if internalMapReadDepth > 0 then
        return nil
    end

    local cachedAt = cache.cachedAt
    if not cachedAt or (GetTime() - cachedAt) > maxAge then
        return nil
    end

    if cache.contextKey ~= contextKey then
        return nil
    end

    return cache.r1, cache.r2, cache.r3, cache.r4
end

local function StoreCachedPlayerPosition(cache, contextKey, r1, r2, r3, r4)
    cache.cachedAt = GetTime()
    cache.contextKey = contextKey
    cache.r1 = r1
    cache.r2 = r2
    cache.r3 = r3
    cache.r4 = r4
end

local function ClearCachedPlayerPositions()
    playerPositionCache.cachedAt = nil
    playerPositionCache.contextKey = nil
    stablePlayerWorldPositionCache.cachedAt = nil
    stablePlayerWorldPositionCache.contextKey = nil
    minimapPlayerWorldPositionCache.cachedAt = nil
    minimapPlayerWorldPositionCache.contextKey = nil
end

QuestieCompat.ClearCachedPlayerPositions = ClearCachedPlayerPositions

local function ResolveDirectUiMapID(mapID, mapLevel)
    return mapIdToUiMapId[NormalizeMapKey(mapID, mapLevel)] or mapIdToUiMapId[mapID]
end

local uiMapInfoCache = {}

local function BuildUiMapInfo(uiMapID)
    local uiMapData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    if not uiMapData then
        return nil
    end

    local mapInfo = uiMapInfoCache[uiMapID]
    if mapInfo then
        return mapInfo
    end

    mapInfo = {
        mapID = uiMapID,
        name = uiMapData.name,
        mapType = uiMapData.mapType,
        parentMapID = uiMapData.parentMapID or 0,
    }

    if uiMapData.instance ~= nil then
        mapInfo.instance = uiMapData.instance
    end
    if uiMapData.worldMapOnly ~= nil then
        mapInfo.worldMapOnly = uiMapData.worldMapOnly
    end

    uiMapInfoCache[uiMapID] = mapInfo
    return mapInfo
end

local function GetAreaName(areaID)
    if areaIdToZoneName[areaID] then
        return areaIdToZoneName[areaID]
    end

    local uiMapData = areaID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[areaID]
    if uiMapData then
        return uiMapData.name
    end

    return nil
end

local function CollectMapChildrenInfo(parentUiMapID, mapType, allDescendants, results, seen)
    results = results or {}
    seen = seen or {}

    for uiMapID, uiMapData in pairs(QuestieCompat.UiMapData or {}) do
        if uiMapData.parentMapID == parentUiMapID and not seen[uiMapID] then
            seen[uiMapID] = true

            if (mapType == nil) or (uiMapData.mapType == mapType) then
                results[#results + 1] = BuildUiMapInfo(uiMapID)
            end

            if allDescendants then
                CollectMapChildrenInfo(uiMapID, mapType, true, results, seen)
            end
        end
    end

    return results
end

local function IsContinentalOrCosmicUiMap(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    return uiData and uiData.mapType and uiData.mapType < 3
end

local function IsZoneLikeUiMap(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    return uiData and uiData.mapType and uiData.mapType >= 3
end

local function IsWorldMapOnlyUiMap(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    return uiData and uiData.worldMapOnly
end

local function IsDescendantUiMap(childUiMapID, ancestorUiMapID)
    local parentUiMapID = childUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[childUiMapID] and QuestieCompat.UiMapData[childUiMapID].parentMapID
    while parentUiMapID and QuestieCompat.UiMapData[parentUiMapID] do
        if parentUiMapID == ancestorUiMapID then
            return true
        end
        parentUiMapID = QuestieCompat.UiMapData[parentUiMapID].parentMapID
    end
    return false
end

local function TranslateZoneCoordinatesBetweenUiMaps(x, y, fromUiMapID, toUiMapID)
    local fromUiData = fromUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[fromUiMapID]
    local toUiData = toUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[toUiMapID]
    if not fromUiData or not toUiData then
        return nil, nil
    end

    local fromWidth, fromHeight, fromLeft, fromTop = fromUiData[1], fromUiData[2], fromUiData[3], fromUiData[4]
    local toWidth, toHeight, toLeft, toTop = toUiData[1], toUiData[2], toUiData[3], toUiData[4]
    if not fromWidth or fromWidth == 0 or not fromHeight or fromHeight == 0 or not toWidth or toWidth == 0 or not toHeight or toHeight == 0 then
        return nil, nil
    end

    local worldX = fromLeft - fromWidth * x
    local worldY = fromTop - fromHeight * y
    return (toLeft - worldX) / toWidth, (toTop - worldY) / toHeight
end

local function GetWorldCoordinatesFromUiMapPosition(x, y, uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    if not uiData or not x or not y then
        return nil, nil, nil
    end

    local width, height, left, top = uiData[1], uiData[2], uiData[3], uiData[4]
    if not width or width == 0 or not height or height == 0 then
        return nil, nil, nil
    end

    return left - width * x, top - height * y, uiData.instance
end

local function CacheStablePlayerWorldPosition(worldX, worldY, instanceID, uiMapID)
    lastStablePlayerWorldX = worldX
    lastStablePlayerWorldY = worldY
    lastStablePlayerInstanceID = instanceID
    lastStablePlayerUiMapID = uiMapID
end

local function CacheMinimapPlayerWorldPosition(worldX, worldY, instanceID, uiMapID)
    lastMinimapPlayerWorldX = worldX
    lastMinimapPlayerWorldY = worldY
    lastMinimapPlayerInstanceID = instanceID
    lastMinimapPlayerUiMapID = uiMapID
end

local function NormalizeActualZoneUiMapID(uiMapID)
    if uiMapID and IsWorldMapOnlyUiMap(uiMapID) and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID] then
        return QuestieCompat.UiMapData[uiMapID].parentMapID or uiMapID
    end
    return uiMapID
end

local function GetPlayerWorldPositionFromUnitPosition(actualUiMapID)
    if type(UnitPosition) ~= "function" then
        return nil, nil, nil, nil
    end

    local rawY, rawX, _z, rawInstanceID = UnitPosition("player")

    if not rawX or not rawY then
        return nil, nil, rawInstanceID, nil
    end

    local validationUiMapID = NormalizeActualZoneUiMapID(actualUiMapID) or NormalizeActualZoneUiMapID(lastKnownZoneLikeUiMapID)

    if validationUiMapID and QuestieCompat.HBD and QuestieCompat.HBD.GetZoneCoordinatesFromWorld then
        local zoneX, zoneY = QuestieCompat.HBD:GetZoneCoordinatesFromWorld(rawX, rawY, validationUiMapID, true)

        if IsValidZoneCoords(zoneX, zoneY) then
            return rawX, rawY, rawInstanceID, validationUiMapID
        end
    end

    if lastStablePlayerWorldX and lastStablePlayerWorldY and rawInstanceID and rawInstanceID == lastStablePlayerInstanceID then
        local delta = math.abs(rawX - lastStablePlayerWorldX) + math.abs(rawY - lastStablePlayerWorldY)
        if delta < 4000 then
            return rawX, rawY, rawInstanceID, validationUiMapID
        end
    end

    return nil, nil, rawInstanceID, validationUiMapID
end

local function BeginInternalMapRead(savedSelection)
    internalMapReadDepth = internalMapReadDepth + 1
    if internalMapReadDepth == 1 then
        internalMapReadSelection = savedSelection
    end
end

local function EndInternalMapRead()
    if internalMapReadDepth <= 0 then
        return
    end

    internalMapReadDepth = internalMapReadDepth - 1
    if internalMapReadDepth == 0 then
        internalMapReadSelection = nil
    end
end

function QuestieCompat.IsInternalMapReadActive()
    return internalMapReadDepth > 0
end

GetDisplayedWorldMapName = function()
    if internalMapReadDepth > 0 and internalMapReadSelection then
        return internalMapReadSelection.displayedMapName
    end

    if UIDropDownMenu_GetText then
        if WorldMapZoneDropDown then
            local zoneDropdownText = UIDropDownMenu_GetText(WorldMapZoneDropDown)
            if zoneDropdownText and zoneDropdownText ~= "" then
                return zoneDropdownText
            end
        end

        if WorldMapContinentDropDown then
            local continentDropdownText = UIDropDownMenu_GetText(WorldMapContinentDropDown)
            if continentDropdownText and continentDropdownText ~= "" then
                return continentDropdownText
            end
        end
    end

    if GetMapInfo then
        local mapName = GetMapInfo()
        if mapName and mapName ~= "" then
            return mapName
        end
    end

    local areaName = WorldMapFrame and WorldMapFrame.areaName
    if areaName and areaName ~= "" then
        return areaName
    end

    if WorldMapFrameAreaLabel and WorldMapFrameAreaLabel.GetText then
        local label = WorldMapFrameAreaLabel:GetText()
        if label and label ~= "" then
            return label:gsub(" |cff.+$", "")
        end
    end

    return nil
end

local function SuppressWorldMapInteraction(duration)
    if type(GetTime) ~= "function" then
        return
    end

    local suppressUntil = GetTime() + (duration or 0.5)
    if suppressUntil > worldMapInteractionSuppressUntil then
        worldMapInteractionSuppressUntil = suppressUntil
    end
end

local function IsWorldMapInteractionSuppressed()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return false
    end

    return type(GetTime) == "function" and GetTime() < worldMapInteractionSuppressUntil
end

local function IsWorldMapDropdownMenuOpen()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return false
    end

    local openMenu = UIDROPDOWNMENU_OPEN_MENU
    local menuMatches = openMenu == WorldMapContinentDropDown
        or openMenu == WorldMapZoneDropDown
        or openMenu == WorldMapZoneMinimapDropDown
        or openMenu == WorldMapLevelDropDown

    if not menuMatches then
        return false
    end

    local dropDownList1 = _G.DropDownList1
    local dropDownList2 = _G.DropDownList2
    return (dropDownList1 and dropDownList1:IsShown())
        or (dropDownList2 and dropDownList2:IsShown())
end

local function HookWorldMapInteractionSuppression(frame)
    if not frame or frame.questieWorldMapInteractionHooked then
        return
    end

    frame.questieWorldMapInteractionHooked = true
    frame:HookScript("OnMouseDown", function()
        SuppressWorldMapInteraction(0.9)
    end)
end

local function EnsureWorldMapInteractionHooks()
    if WorldMapFrame and not WorldMapFrame.questieEnsureInteractionHooksHooked then
        WorldMapFrame.questieEnsureInteractionHooksHooked = true
        WorldMapFrame:HookScript("OnShow", function()
            EnsureWorldMapInteractionHooks()
        end)
    end

    HookWorldMapInteractionSuppression(WorldMapButton)
    HookWorldMapInteractionSuppression(WorldMapFrame)
    HookWorldMapInteractionSuppression(WorldMapDetailFrame)
    HookWorldMapInteractionSuppression(WorldMapFrameAreaFrame)
    HookWorldMapInteractionSuppression(WorldMapContinentDropDownButton)
    HookWorldMapInteractionSuppression(WorldMapContinentDropDown)
    HookWorldMapInteractionSuppression(WorldMapZoneDropDownButton)
    HookWorldMapInteractionSuppression(WorldMapZoneDropDown)
    HookWorldMapInteractionSuppression(WorldMapZoneMinimapDropDownButton)
    HookWorldMapInteractionSuppression(WorldMapZoneMinimapDropDown)
    HookWorldMapInteractionSuppression(WorldMapLevelDropDownButton)
    HookWorldMapInteractionSuppression(WorldMapLevelDropDown)
    HookWorldMapInteractionSuppression(WorldMapZoomOutButton)
end

local function ResetAnchoredDisplayedWorldPosition()
    anchoredDisplayedUiMapID = nil
    anchoredDisplayedWorldX = nil
    anchoredDisplayedWorldY = nil
    anchoredStableWorldX = nil
    anchoredStableWorldY = nil
    anchoredStableInstanceID = nil
    anchoredStableUiMapID = nil
end

local function GetAnchoredDisplayedWorldPosition(displayedUiMapID, displayedX, displayedY)
    if not displayedUiMapID or not displayedX or not displayedY then
        return nil, nil, nil, nil, false
    end

    local displayedWorldX, displayedWorldY = GetWorldCoordinatesFromUiMapPosition(displayedX, displayedY, displayedUiMapID)
    if not displayedWorldX or not displayedWorldY or not lastStablePlayerWorldX or not lastStablePlayerWorldY then
        return nil, nil, nil, nil, false
    end

    if anchoredDisplayedUiMapID ~= displayedUiMapID or not anchoredDisplayedWorldX or not anchoredDisplayedWorldY or not anchoredStableWorldX or not anchoredStableWorldY then
        anchoredDisplayedUiMapID = displayedUiMapID
        anchoredDisplayedWorldX = displayedWorldX
        anchoredDisplayedWorldY = displayedWorldY
        anchoredStableWorldX = lastStablePlayerWorldX
        anchoredStableWorldY = lastStablePlayerWorldY
        anchoredStableInstanceID = lastStablePlayerInstanceID
        anchoredStableUiMapID = lastStablePlayerUiMapID

        return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID, true
    end

    return anchoredStableWorldX + (displayedWorldX - anchoredDisplayedWorldX),
        anchoredStableWorldY + (displayedWorldY - anchoredDisplayedWorldY),
        anchoredStableInstanceID or lastStablePlayerInstanceID,
        anchoredStableUiMapID or lastStablePlayerUiMapID,
        false
end

local function ResetAnchoredMinimapWorldPosition()
    anchoredMinimapDisplayedUiMapID = nil
    anchoredMinimapDisplayedWorldX = nil
    anchoredMinimapDisplayedWorldY = nil
    anchoredMinimapWorldX = nil
    anchoredMinimapWorldY = nil
    anchoredMinimapInstanceID = nil
    anchoredMinimapUiMapID = nil
end

local function GetAnchoredMinimapWorldPosition(displayedUiMapID, displayedX, displayedY)
    if not displayedUiMapID or not displayedX or not displayedY then
        return nil, nil, nil, nil, false
    end

    local displayedWorldX, displayedWorldY = GetWorldCoordinatesFromUiMapPosition(displayedX, displayedY, displayedUiMapID)
    local baseWorldX = lastMinimapPlayerWorldX or lastStablePlayerWorldX
    local baseWorldY = lastMinimapPlayerWorldY or lastStablePlayerWorldY
    local baseInstanceID = lastMinimapPlayerInstanceID or lastStablePlayerInstanceID
    local baseUiMapID = lastMinimapPlayerUiMapID or lastStablePlayerUiMapID
    if not displayedWorldX or not displayedWorldY or not baseWorldX or not baseWorldY then
        return nil, nil, nil, nil, false
    end

    if anchoredMinimapDisplayedUiMapID ~= displayedUiMapID
        or not anchoredMinimapDisplayedWorldX or not anchoredMinimapDisplayedWorldY
        or not anchoredMinimapWorldX or not anchoredMinimapWorldY then
        anchoredMinimapDisplayedUiMapID = displayedUiMapID
        anchoredMinimapDisplayedWorldX = displayedWorldX
        anchoredMinimapDisplayedWorldY = displayedWorldY
        anchoredMinimapWorldX = baseWorldX
        anchoredMinimapWorldY = baseWorldY
        anchoredMinimapInstanceID = baseInstanceID
        anchoredMinimapUiMapID = baseUiMapID

        return baseWorldX, baseWorldY, baseInstanceID, baseUiMapID, true
    end

    return anchoredMinimapWorldX + (displayedWorldX - anchoredMinimapDisplayedWorldX),
        anchoredMinimapWorldY + (displayedWorldY - anchoredMinimapDisplayedWorldY),
        anchoredMinimapInstanceID or baseInstanceID,
        anchoredMinimapUiMapID or baseUiMapID,
        false
end

local genericWaterSubzones = {
    ["The North Sea"] = true,
    ["The Great Sea"] = true,
    ["The Forbidding Sea"] = true,
    ["The Veiled Sea"] = true,
    ["The Frozen Sea"] = true,
    ["South Seas"] = true,
}

local function GetUiMapIdForAreaId(areaId)
    if not areaId then
        return nil
    end

    local areaIdToUiMapId = ZoneDB.private and ZoneDB.private.areaIdToUiMapId
    local specialZoneIdToUiMapId = ZoneDB.private and ZoneDB.private.specialZoneIdToUiMapId
    local uiMapID = starterAreaIdToUiMapId[areaId]
        or (areaIdToUiMapId and areaIdToUiMapId[areaId])
        or (specialZoneIdToUiMapId and specialZoneIdToUiMapId[areaId])

    if uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID] then
        return uiMapID
    end

    return nil
end

local function GetParentUiMapIdForAreaId(areaId)
    if not areaId then
        return nil
    end

    local dungeonData = ZoneDB.private and ZoneDB.private.dungeons and ZoneDB.private.dungeons[areaId]
    local parentAreaId = dungeonData and dungeonData[3]
    if not parentAreaId and ZoneDB.GetParentZoneId then
        parentAreaId = ZoneDB:GetParentZoneId(areaId)
    end

    return GetUiMapIdForAreaId(parentAreaId)
end

local function IsAzerothOutlandChooserVisible(rawMapID)
    if rawMapID ~= -1 or not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return false
    end

    local zoomOutDisabled = WorldMapZoomOutButton and (not WorldMapZoomOutButton:IsEnabled())
    local continentDropdownText = (UIDropDownMenu_GetText and WorldMapContinentDropDown) and UIDropDownMenu_GetText(WorldMapContinentDropDown) or nil
    local zoneDropdownText = (UIDropDownMenu_GetText and WorldMapZoneDropDown) and UIDropDownMenu_GetText(WorldMapZoneDropDown) or nil
    local blankDropdowns = (not continentDropdownText or continentDropdownText == "") and (not zoneDropdownText or zoneDropdownText == "")

    return zoomOutDisabled or blankDropdowns
end

local function ResolveUiMapIDByZoneTexts()
    local zoneCandidates = {
        {name = GetSubZoneText and GetSubZoneText(), source = "sub"},
        {name = GetMinimapZoneText and GetMinimapZoneText(), source = "minimap"},
        {name = GetZoneText and GetZoneText(), source = "zone"},
        {name = GetRealZoneText and GetRealZoneText(), source = "real"},
    }
    local fallbackUiMapID, fallbackZoneName = nil, nil
    for _, candidate in ipairs(zoneCandidates) do
        local zoneName = candidate.name
        if zoneName and zoneName ~= "" then
            local zoneUiMapID = zoneNameToUiMapIdOverrides[zoneName] or zoneNameToUiMapId[zoneName]
            if not zoneUiMapID then
                local areaId = zoneNameToAreaId[zoneName]
                if areaId then
                    zoneUiMapID = GetUiMapIdForAreaId(areaId) or GetParentUiMapIdForAreaId(areaId)
                end
            end
            if zoneUiMapID then
                local uiData = QuestieCompat.UiMapData and QuestieCompat.UiMapData[zoneUiMapID]
                local mapType = uiData and uiData.mapType
                local isZoneLikeMap = mapType and mapType >= 3
                local isGenericWaterSubzone = genericWaterSubzones[zoneName] and (candidate.source == "sub" or candidate.source == "minimap")
                if isZoneLikeMap and (not isGenericWaterSubzone) then
                    return zoneUiMapID, zoneName
                end
                if not fallbackUiMapID then
                    fallbackUiMapID = zoneUiMapID
                    fallbackZoneName = zoneName
                end
            end
        end
    end
    return fallbackUiMapID, fallbackZoneName
end

local function ResolveUiMapIDByMapName(mapName)
    if not mapName or mapName == "" then
        return nil, nil
    end

    local uiMapID = zoneNameToUiMapIdOverrides[mapName] or zoneNameToUiMapId[mapName]
    if not uiMapID then
        local areaId = zoneNameToAreaId[mapName]
        if areaId then
            uiMapID = GetUiMapIdForAreaId(areaId) or GetParentUiMapIdForAreaId(areaId)
        end
    end

    return uiMapID, mapName
end

local function ResolveSelectedUiMapIDByMapName()
    if not GetMapInfo then
        return nil, nil
    end

    local mapName = GetMapInfo()
    return ResolveUiMapIDByMapName(mapName)
end

local function ResolveWorldMapZoneDropdownUiMapID()
    if not UIDropDownMenu_GetText or not WorldMapZoneDropDown then
        return nil
    end

    local zoneDropdownText = UIDropDownMenu_GetText(WorldMapZoneDropDown)
    if not zoneDropdownText or zoneDropdownText == "" then
        return nil
    end

    return ResolveUiMapIDByMapName(zoneDropdownText)
end

local function ResolveWorldMapContinentDropdownUiMapID()
    if not UIDropDownMenu_GetText or not WorldMapContinentDropDown then
        return nil
    end

    local continentDropdownText = UIDropDownMenu_GetText(WorldMapContinentDropDown)
    if not continentDropdownText or continentDropdownText == "" then
        return nil
    end

    return ResolveUiMapIDByMapName(continentDropdownText)
end

local function AreUiMapsRelated(leftUiMapID, rightUiMapID)
    if not leftUiMapID or not rightUiMapID then
        return false
    end

    return leftUiMapID == rightUiMapID or IsDescendantUiMap(leftUiMapID, rightUiMapID) or IsDescendantUiMap(rightUiMapID, leftUiMapID)
end

local function IsCachedWorldPositionUsableForUiMap(cachedUiMapID, actualUiMapID)
    local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
    if not normalizedActualUiMapID or not cachedUiMapID then
        return true
    end

    return AreUiMapsRelated(cachedUiMapID, normalizedActualUiMapID)
end

local function ResolveDisplayedWorldMapUiMapID(rawMapID, mapLevel, displayedMapName)
    local displayedUiMapID = ResolveDirectUiMapID(rawMapID, mapLevel)
    local displayedNameUiMapID = ResolveUiMapIDByMapName(displayedMapName)
    local zoneDropdownUiMapID = ResolveWorldMapZoneDropdownUiMapID()
    local continentDropdownUiMapID = ResolveWorldMapContinentDropdownUiMapID()
    if rawMapID == -1 then
        if IsAzerothOutlandChooserVisible(rawMapID) then
            return 946
        end
        if displayedMapName == "Outland" then
            return 1945
        end
        return 946
    end

    if continentDropdownUiMapID and IsContinentalOrCosmicUiMap(continentDropdownUiMapID) then
        local zoneDropdownMatchesContinent = zoneDropdownUiMapID and AreUiMapsRelated(zoneDropdownUiMapID, continentDropdownUiMapID)
        local displayedNameMatchesContinent = displayedNameUiMapID and AreUiMapsRelated(displayedNameUiMapID, continentDropdownUiMapID)

        if zoneDropdownUiMapID and not zoneDropdownMatchesContinent then
            return continentDropdownUiMapID
        end

        if displayedNameUiMapID and not displayedNameMatchesContinent and (not displayedUiMapID) then
            return continentDropdownUiMapID
        end
    end

    local zoneDropdownParentUiMapID = displayedUiMapID or displayedNameUiMapID
    if zoneDropdownUiMapID and zoneDropdownParentUiMapID
        and IsZoneLikeUiMap(zoneDropdownParentUiMapID)
        and IsWorldMapOnlyUiMap(zoneDropdownUiMapID)
        and IsDescendantUiMap(zoneDropdownUiMapID, zoneDropdownParentUiMapID) then
        return zoneDropdownUiMapID
    end

    if displayedNameUiMapID and displayedUiMapID and displayedNameUiMapID ~= displayedUiMapID then
        local displayedNameIsRelated = displayedNameUiMapID == displayedUiMapID
            or IsDescendantUiMap(displayedNameUiMapID, displayedUiMapID)
            or IsDescendantUiMap(displayedUiMapID, displayedNameUiMapID)
        if displayedNameIsRelated and IsWorldMapOnlyUiMap(displayedNameUiMapID) and IsZoneLikeUiMap(displayedUiMapID) then
            return displayedNameUiMapID
        end
    end

    if displayedUiMapID then
        return displayedUiMapID
    end

    if displayedMapName == "Azeroth" then
        return 947
    end

    if displayedNameUiMapID then
        return displayedNameUiMapID
    end

    local selectedUiMapID = ResolveSelectedUiMapIDByMapName()
    return selectedUiMapID
end

local function ResolveChooserPlayerUiMapID(actualUiMapID)
    local normalizedUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
    local currentUiMapID = normalizedUiMapID
    local resolvedWorldUiMapID = nil

    while currentUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[currentUiMapID] do
        local uiData = QuestieCompat.UiMapData[currentUiMapID]
        if uiData.mapType == 1 and currentUiMapID ~= 946 then
            resolvedWorldUiMapID = currentUiMapID
        end

        local parentUiMapID = uiData.parentMapID
        if not parentUiMapID or parentUiMapID == currentUiMapID then
            break
        end
        currentUiMapID = parentUiMapID
    end

    if resolvedWorldUiMapID then
        return resolvedWorldUiMapID
    end

    local instanceID = normalizedUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[normalizedUiMapID] and QuestieCompat.UiMapData[normalizedUiMapID].instance
    if instanceID == 530 then
        return 1945
    end

    return 947
end

local function SetLegacyMapToUiMap(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[uiMapID]
    if not uiData or not uiData.mapID then
        return false
    end

    local cz = mapIdToCZ[uiData.mapID]
    if cz then
        SetMapZoom(QuestieCompat.Round(cz % 1 * 10), math.floor(cz))
        return true
    end

    SetMapByID(math.floor(uiData.mapID) - 1)
    local mapLevel = QuestieCompat.Round((uiData.mapID % 1) * 10)
    if mapLevel > 0 then
        SetDungeonMapLevel(mapLevel)
    end
    return true
end

local function CaptureLegacyMapSelection()
    local mapID, mapLevel = GetRawMapContext()
    local displayedMapName = GetDisplayedWorldMapName()
    return {
        rawMapID = mapID,
        rawMapLevel = mapLevel,
        rawUiMapID = ResolveDirectUiMapID(mapID, mapLevel),
        displayedMapName = displayedMapName,
        displayedUiMapID = ResolveDisplayedWorldMapUiMapID(mapID, mapLevel, displayedMapName),
        continent = GetCurrentMapContinent(),
        zone = GetCurrentMapZone(),
        mapLevel = GetCurrentMapDungeonLevel() or 0,
        continentDropdownText = (UIDropDownMenu_GetText and WorldMapContinentDropDown) and UIDropDownMenu_GetText(WorldMapContinentDropDown) or nil,
        zoneDropdownText = (UIDropDownMenu_GetText and WorldMapZoneDropDown) and UIDropDownMenu_GetText(WorldMapZoneDropDown) or nil,
        continentDropdownSelectedID = (UIDropDownMenu_GetSelectedID and WorldMapContinentDropDown) and UIDropDownMenu_GetSelectedID(WorldMapContinentDropDown) or nil,
        zoneDropdownSelectedID = (UIDropDownMenu_GetSelectedID and WorldMapZoneDropDown) and UIDropDownMenu_GetSelectedID(WorldMapZoneDropDown) or nil,
    }
end

local function RestoreLegacyMapDropdownSelection(savedSelection)
    if not savedSelection or not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return
    end

    if IsWorldMapInteractionSuppressed() or IsWorldMapDropdownMenuOpen() then
        return
    end

    if savedSelection.rawMapID == -1 then
        return
    end

    local currentContinentSelectedID = (UIDropDownMenu_GetSelectedID and WorldMapContinentDropDown) and UIDropDownMenu_GetSelectedID(WorldMapContinentDropDown) or nil
    local currentZoneSelectedID = (UIDropDownMenu_GetSelectedID and WorldMapZoneDropDown) and UIDropDownMenu_GetSelectedID(WorldMapZoneDropDown) or nil
    local currentContinentText = (UIDropDownMenu_GetText and WorldMapContinentDropDown) and UIDropDownMenu_GetText(WorldMapContinentDropDown) or nil
    local currentZoneText = (UIDropDownMenu_GetText and WorldMapZoneDropDown) and UIDropDownMenu_GetText(WorldMapZoneDropDown) or nil

    if UIDropDownMenu_SetSelectedID then
        if WorldMapContinentDropDown
            and type(savedSelection.continentDropdownSelectedID) == "number"
            and currentContinentSelectedID ~= savedSelection.continentDropdownSelectedID then
            UIDropDownMenu_SetSelectedID(WorldMapContinentDropDown, savedSelection.continentDropdownSelectedID)
        end
        if WorldMapZoneDropDown
            and type(savedSelection.zoneDropdownSelectedID) == "number"
            and currentZoneSelectedID ~= savedSelection.zoneDropdownSelectedID then
            UIDropDownMenu_SetSelectedID(WorldMapZoneDropDown, savedSelection.zoneDropdownSelectedID)
        end
    end

    if UIDropDownMenu_SetText then
        if WorldMapContinentDropDown
            and savedSelection.continentDropdownText ~= nil
            and currentContinentText ~= savedSelection.continentDropdownText then
            UIDropDownMenu_SetText(WorldMapContinentDropDown, savedSelection.continentDropdownText)
        end
        if WorldMapZoneDropDown
            and savedSelection.zoneDropdownText ~= nil
            and currentZoneText ~= savedSelection.zoneDropdownText then
            UIDropDownMenu_SetText(WorldMapZoneDropDown, savedSelection.zoneDropdownText)
        end
    end
end

local function RestoreLegacyMapSelection(savedSelection)
    if not savedSelection then
        return
    end

    if savedSelection.rawMapID == -1 then
        if savedSelection.displayedUiMapID == 1945 then
            SetLegacyMapToUiMap(1945)
        else
            SetMapZoom(-1)
        end
        RestoreLegacyMapDropdownSelection(savedSelection)
        return
    end

    local continent = savedSelection.continent
    local zone = savedSelection.zone
    local mapLevel = savedSelection.mapLevel
    if continent and continent > 0 then
        if zone and zone > 0 then
            SetMapZoom(continent, zone)
        else
            SetMapZoom(continent)
        end
    else
        local rawUiMapID = savedSelection.rawUiMapID
        local rawUiData = rawUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[rawUiMapID]
        if rawUiData and rawUiData.mapID and rawUiData.mapID > 0 then
            SetLegacyMapToUiMap(rawUiMapID)
        else
            SetMapZoom(WORLDMAP_WORLD_ID)
        end
    end

    if mapLevel and mapLevel > 0 then
        SetDungeonMapLevel(mapLevel)
    end

    RestoreLegacyMapDropdownSelection(savedSelection)
end

local function GetPlayerWorldPositionFromActualZoneUiMap(actualUiMapID)
    if not actualUiMapID then
        return nil, nil, nil, nil
    end

    local targetUiMapID = actualUiMapID
    if IsWorldMapOnlyUiMap(targetUiMapID) and QuestieCompat.UiMapData[targetUiMapID] and QuestieCompat.UiMapData[targetUiMapID].parentMapID then
        targetUiMapID = QuestieCompat.UiMapData[targetUiMapID].parentMapID
    end

    if not targetUiMapID then
        return nil, nil, nil, nil
    end

    local shouldSuppressVisibleMapSelection = WorldMapFrame and WorldMapFrame:IsVisible()
    if shouldSuppressVisibleMapSelection then
        local rawMapID, rawMapLevel = GetRawMapContext()
        local displayedMapName = GetDisplayedWorldMapName()
        local displayedUiMapID = ResolveDisplayedWorldMapUiMapID(rawMapID, rawMapLevel, displayedMapName)

        if displayedUiMapID and IsZoneLikeUiMap(displayedUiMapID) and AreUiMapsRelated(displayedUiMapID, targetUiMapID) then
            local x, y = GetPlayerMapPosition("player")
            if not x or not y or (x <= 0 and y <= 0) then
                -- Avoid forcing a legacy map reselection while the world map is visible.
                -- Related parent/child maps can hit this path repeatedly and generate
                -- WORLD_MAP_UPDATE churn without ever producing a better position read.
                return nil, nil, nil, nil
            end

            if x and y and (x > 0 or y > 0) then
                if displayedUiMapID ~= targetUiMapID then
                    x, y = TranslateZoneCoordinatesBetweenUiMaps(x, y, displayedUiMapID, targetUiMapID)
                end

                if x and y then
                    local worldX, worldY, instanceID = GetWorldCoordinatesFromUiMapPosition(x, y, targetUiMapID)
                    if worldX and worldY then
                        return worldX, worldY, instanceID, targetUiMapID
                    end
                end
            end
        end
    end

    local savedSelection = shouldSuppressVisibleMapSelection and CaptureLegacyMapSelection() or nil
    if shouldSuppressVisibleMapSelection then
        BeginInternalMapRead(savedSelection)
    end

    if not SetLegacyMapToUiMap(targetUiMapID) then
        if shouldSuppressVisibleMapSelection then
            EndInternalMapRead()
        end
        return nil, nil, nil, nil
    end

    local x, y = GetPlayerMapPosition("player")
    if shouldSuppressVisibleMapSelection then
        RestoreLegacyMapSelection(savedSelection)
        EndInternalMapRead()
    end

    if not x or not y or (x <= 0 and y <= 0) then
        return nil, nil, nil, nil
    end

    local worldX, worldY, instanceID = GetWorldCoordinatesFromUiMapPosition(x, y, targetUiMapID)
    if not worldX or not worldY then
        return nil, nil, nil, nil
    end

    return worldX, worldY, instanceID, targetUiMapID
end

local function ShouldCacheZoneLikeUiMap(uiMapID)
    if not uiMapID or not IsZoneLikeUiMap(uiMapID) or IsWorldMapOnlyUiMap(uiMapID) then
        return false
    end

    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return true
    end

    local actualUiMapID = NormalizeActualZoneUiMapID(ResolveUiMapIDByZoneTexts())
    if not actualUiMapID or not IsZoneLikeUiMap(actualUiMapID) or IsWorldMapOnlyUiMap(actualUiMapID) then
        return false
    end

    return AreUiMapsRelated(uiMapID, actualUiMapID)
end

local function CanUseResolvedMinimapPosition(resolvedUiMapID, x, y, actualUiMapID)
    if not resolvedUiMapID or not x or not y or (x <= 0 and y <= 0) then
        return false
    end

    if not IsZoneLikeUiMap(resolvedUiMapID) or IsWorldMapOnlyUiMap(resolvedUiMapID) then
        return false
    end

    if not actualUiMapID then
        return true
    end

    return AreUiMapsRelated(resolvedUiMapID, actualUiMapID)
end

local function GetValidatedResolvedMinimapWorldPosition(resolvedUiMapID, x, y, actualUiMapID)
    if not CanUseResolvedMinimapPosition(resolvedUiMapID, x, y, actualUiMapID) then
        return nil, nil, nil
    end

    local worldX, worldY, instanceID = GetWorldCoordinatesFromUiMapPosition(x, y, resolvedUiMapID)
    if not worldX or not worldY then
        return nil, nil, nil
    end

    if actualUiMapID and QuestieCompat.HBD and QuestieCompat.HBD.GetZoneCoordinatesFromWorld then
        local zoneX, zoneY = QuestieCompat.HBD:GetZoneCoordinatesFromWorld(worldX, worldY, actualUiMapID, true)
        if not IsValidZoneCoords(zoneX, zoneY) then
            return nil, nil, nil
        end
    end

    return worldX, worldY, instanceID
end

local function ShouldFreezeVisibleWorldMapPlayerRead(rawMapID, displayedUiMapID, actualUiMapID)
    -- The Azeroth/Outland chooser and non-zone maps should never trigger an exact
    -- player read because doing so mutates the displayed map selection.
    if rawMapID == -1 then
        return true
    end

    if not displayedUiMapID then
        return true
    end

    if not IsZoneLikeUiMap(displayedUiMapID) then
        return true
    end

    if not actualUiMapID then
        return true
    end

    return not AreUiMapsRelated(displayedUiMapID, actualUiMapID)
end

local function ShouldUseExactPlayerWorldRead(rawMapID, displayedUiMapID, actualUiMapID)
    if ShouldFreezeVisibleWorldMapPlayerRead(rawMapID, displayedUiMapID, actualUiMapID) then
        return false
    end

    return AreUiMapsRelated(displayedUiMapID, actualUiMapID)
end

-- convert current mapAreaID and mapLevel to UiMapId
-- https://wowpedia.fandom.com/wiki/API_GetCurrentMapAreaID
-- https://wowwiki-archive.fandom.com/wiki/API_GetCurrentMapDungeonLevel
-- https://wowpedia.fandom.com/wiki/UiMapID#Classic
function QuestieCompat.GetCurrentUiMapID()
    local mapID, mapLevel = GetRawMapContext()
    local worldMapVisible = WorldMapFrame and WorldMapFrame:IsVisible()
    local uiMapID
    if worldMapVisible then
        local displayedMapName = GetDisplayedWorldMapName()
        uiMapID = ResolveDisplayedWorldMapUiMapID(mapID, mapLevel, displayedMapName)
    else
        uiMapID = ResolveDirectUiMapID(mapID, mapLevel)
    end
    if uiMapID and IsWorldMapOnlyUiMap(uiMapID) and not worldMapVisible then
        uiMapID = nil
    end
    if uiMapID then
        if (not worldMapVisible) and IsContinentalOrCosmicUiMap(uiMapID) then
            local zoneUiMapID = ResolveUiMapIDByZoneTexts()
            if zoneUiMapID and IsZoneLikeUiMap(zoneUiMapID) and not IsWorldMapOnlyUiMap(zoneUiMapID) then
                uiMapID = zoneUiMapID
            elseif lastKnownZoneLikeUiMapID then
                uiMapID = lastKnownZoneLikeUiMapID
            end
        end
        if ShouldCacheZoneLikeUiMap(uiMapID) then
            lastKnownZoneLikeUiMapID = uiMapID
        end
        if (not worldMapVisible) and (not IsWorldMapOnlyUiMap(uiMapID)) then
            lastKnownUiMapID = uiMapID
        end
        return uiMapID
    end
    local zoneUiMapID = ResolveUiMapIDByZoneTexts()
    if (not WorldMapFrame) or (not WorldMapFrame:IsVisible()) then
        if zoneUiMapID and not IsWorldMapOnlyUiMap(zoneUiMapID) then
            if IsContinentalOrCosmicUiMap(zoneUiMapID) and lastKnownZoneLikeUiMapID then
                zoneUiMapID = lastKnownZoneLikeUiMapID
            end
            if IsZoneLikeUiMap(zoneUiMapID) then
                lastKnownZoneLikeUiMapID = zoneUiMapID
            end
            lastKnownUiMapID = zoneUiMapID
            return zoneUiMapID
        end
    elseif zoneUiMapID and IsWorldMapOnlyUiMap(zoneUiMapID) then
        return zoneUiMapID
    end
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        -- Avoid drawing parent/continent pins on unresolved subzone maps.
        return 946
    end
    if lastKnownUiMapID then
        return lastKnownUiMapID
    end
    if lastKnownZoneLikeUiMapID then
        return lastKnownZoneLikeUiMapID
    end
    return 946
end

-- maps mapAreaID to Zone and Continent index
-- https://wowpedia.fandom.com/wiki/API_GetMapContinents
-- https://wowpedia.fandom.com/wiki/API_GetMapZones
local function BuildMapIdToCZ()
    if next(mapIdToCZ) then return end

    local savedMapSelection = CaptureLegacyMapSelection()
    for C in ipairs({GetMapContinents()}) do
        local zones = {GetMapZones(C)}
        for Z in ipairs(zones) do
            SetMapZoom(C, Z)
            local mapId = GetCurrentMapAreaID()
            mapIdToCZ[mapId] = Z + C / 10
        end
    end
    RestoreLegacyMapSelection(savedMapSelection)
end

local function GetTomTomCZForUiMapID(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData[uiMapID]
    if not uiData then
        return nil
    end

    if uiMapID == 947 then
        return 0
    elseif uiMapID == 1414 then
        return 0.1
    elseif uiMapID == 1415 then
        return 0.2
    elseif uiMapID == 1945 then
        return 0.3
    end

    return mapIdToCZ[uiData.mapID]
end

local function GetTomTomDungeonEntranceWaypoint(uiMapID)
    local areaID
    if ZoneDB.GetAreaIdByUiMapId then
        local success, resolvedAreaID = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, uiMapID)
        if success then
            areaID = resolvedAreaID
        end
    end

    local dungeonLocations = ZoneDB.private and ZoneDB.private.dungeonLocations
    local subZoneToParentZone = ZoneDB.private and ZoneDB.private.subZoneToParentZone
    if areaID and dungeonLocations and not dungeonLocations[areaID] and subZoneToParentZone and subZoneToParentZone[areaID] then
        areaID = subZoneToParentZone[areaID]
    end

    local entrance = areaID and dungeonLocations and dungeonLocations[areaID] and dungeonLocations[areaID][1]
    if not entrance then
        return nil, nil, nil
    end

    local entranceUiMapID = ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(entrance[1])
    local entranceCZ = GetTomTomCZForUiMapID(entranceUiMapID)
    if not entranceCZ then
        return nil, nil, nil
    end

    return entranceCZ, entrance[2], entrance[3]
end

function QuestieCompat.TomTom_AddWaypoint(title, zone, x, y)
    local CZ = GetTomTomCZForUiMapID(zone)
    if (zone == 125) or (zone == 126) then CZ = 3.4 end
    if not CZ then
        local entranceCZ, entranceX, entranceY = GetTomTomDungeonEntranceWaypoint(zone)
        if entranceCZ then
            CZ = entranceCZ
            x = entranceX
            y = entranceY
        end
    end
    if not CZ then return nil end
    -- Force the crazy arrow on 3.3.5 so Questie behaves like newer TomTom integrations.
    return TomTom:AddZWaypoint(QuestieCompat.Round(CZ%1 * 10), math.floor(CZ), x, y, title, nil, nil, nil, nil, nil, true)
end

-- This function will do its utmost to retrieve some sort of valid position
-- for the player, including changing the current map zoom (if needed)
-- https://wowpedia.fandom.com/wiki/API_C_Map.GetPlayerMapPosition?oldid=2167175
function QuestieCompat.GetCurrentPlayerPosition()
    local contextKey = GetPlayerPositionCacheContextKey()
    local cachedUiMapID, cachedX, cachedY = TryGetCachedPlayerPosition(playerPositionCache, PLAYER_POSITION_CACHE_TTL, contextKey)
    if cachedUiMapID ~= nil then
        return cachedUiMapID, cachedX, cachedY
    end

    -- Try using UnitPosition + HBD to derive player's zone-relative coordinates
    -- This avoids changing the current map zoom/selection which can cause UI churn.
    local actualUiMapID = ResolveUiMapIDByZoneTexts()
    if actualUiMapID and (type(UnitPosition) == "function") and QuestieCompat.HBD and QuestieCompat.HBD.GetZoneCoordinatesFromWorld then
        local worldX, worldY, instanceID, unitUiMapID = GetPlayerWorldPositionFromUnitPosition(actualUiMapID)
        if worldX and worldY and unitUiMapID then
            local zoneX, zoneY = QuestieCompat.HBD:GetZoneCoordinatesFromWorld(worldX, worldY, unitUiMapID, true)
            if IsValidZoneCoords(zoneX, zoneY) then
                StoreCachedPlayerPosition(playerPositionCache, contextKey, unitUiMapID, zoneX, zoneY)
                return unitUiMapID, zoneX, zoneY
            end
        end
    end

    local x, y = GetPlayerMapPosition("player");
    local function NormalizeResolvedPlayerUiMapID(resolvedUiMapID)
        if resolvedUiMapID and IsWorldMapOnlyUiMap(resolvedUiMapID) and not WorldMapFrame:IsVisible() then
            return nil
        end
        return resolvedUiMapID
    end
	if ( x <= 0 and y <= 0 ) then
		if ( WorldMapFrame:IsVisible() ) then
			-- we know there is a visible world map, so don't cause
			-- WORLD_MAP_UPDATE events by changing map zoom
            local fallbackUiMapID = QuestieCompat.GetCurrentUiMapID()
            StoreCachedPlayerPosition(playerPositionCache, contextKey, fallbackUiMapID, x, y)
			return fallbackUiMapID, x, y;
		end
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition("player");
		if ( x <= 0 and y <= 0 ) then
			-- attempt to zoom out once - logic copied from WorldMapZoomOutButton_OnClick()
				if ( ZoomOut() ) then
					-- do nothing
				elseif ( GetCurrentMapZone() ~= WORLDMAP_WORLD_ID ) then
					SetMapZoom(GetCurrentMapContinent());
				else
					SetMapZoom(WORLDMAP_WORLD_ID);
				end
			x, y = GetPlayerMapPosition("player");
			if ( x <= 0 and y <= 0 ) then
				-- we are in an instance without a map or otherwise off map
                local fallbackUiMapID = QuestieCompat.GetCurrentUiMapID()
                StoreCachedPlayerPosition(playerPositionCache, contextKey, fallbackUiMapID, x, y)
				return fallbackUiMapID, x, y;
			end
		end
	end
    local mapID, mapLevel = GetRawMapContext();
    local rawUiMapID = ResolveDirectUiMapID(mapID, mapLevel)
    local zoneUiMapID = ResolveUiMapIDByZoneTexts()
    if (not WorldMapFrame:IsVisible()) and zoneUiMapID and minimapChildToParentRebaseUiMapId[zoneUiMapID] and (x > 0 or y > 0) then
        local parentUiMapID = QuestieCompat.UiMapData[zoneUiMapID] and QuestieCompat.UiMapData[zoneUiMapID].parentMapID
        if parentUiMapID then
            if rawUiMapID == parentUiMapID then
                StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, x, y)
                return parentUiMapID, x, y
            end

            if rawUiMapID == zoneUiMapID then
                local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(x, y, zoneUiMapID, parentUiMapID)
                if translatedX and translatedY then
                    StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, translatedX, translatedY)
                    return parentUiMapID, translatedX, translatedY
                end
            end

            if SetLegacyMapToUiMap(parentUiMapID) then
                local parentX, parentY = GetPlayerMapPosition("player")
                if (parentX > 0 or parentY > 0) then
                    StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, parentX, parentY)
                    return parentUiMapID, parentX, parentY
                end
            end

            local coordinateUiMapID = rawUiMapID or zoneUiMapID
            local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(x, y, coordinateUiMapID, parentUiMapID)
            if translatedX and translatedY then
                StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, translatedX, translatedY)
                return parentUiMapID, translatedX, translatedY
            end
        end
    end
    if (not WorldMapFrame:IsVisible()) and (x > 0 or y > 0) then
        local selectedUiMapID = ResolveSelectedUiMapIDByMapName()
        if selectedUiMapID and minimapChildToParentRebaseUiMapId[selectedUiMapID] then
            local parentUiMapID = QuestieCompat.UiMapData[selectedUiMapID] and QuestieCompat.UiMapData[selectedUiMapID].parentMapID
            if parentUiMapID then
                local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(x, y, selectedUiMapID, parentUiMapID)
                if translatedX and translatedY then
                    StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, translatedX, translatedY)
                    return parentUiMapID, translatedX, translatedY
                end
            end
        end
    end
    if (not WorldMapFrame:IsVisible()) and rawUiMapID and minimapChildToParentRebaseUiMapId[rawUiMapID] and (x > 0 or y > 0) then
        local parentUiMapID = QuestieCompat.UiMapData[rawUiMapID] and QuestieCompat.UiMapData[rawUiMapID].parentMapID
        if parentUiMapID then
            local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(x, y, rawUiMapID, parentUiMapID)
            if translatedX and translatedY then
                StoreCachedPlayerPosition(playerPositionCache, contextKey, parentUiMapID, translatedX, translatedY)
                return parentUiMapID, translatedX, translatedY
            end
        end
    end
	local uiMapID = NormalizeResolvedPlayerUiMapID(rawUiMapID);
    if uiMapID and (not WorldMapFrame:IsVisible()) and IsContinentalOrCosmicUiMap(uiMapID) then
        -- Continental/cosmic map contexts can produce distorted local coordinates for minimap math.
        -- Re-anchor to the player's actual zone map first.
        SetMapToCurrentZone()
        local zx, zy = GetPlayerMapPosition("player")
        if (zx > 0 or zy > 0) then
            x, y = zx, zy
        end
        mapID, mapLevel = GetRawMapContext()
        uiMapID = NormalizeResolvedPlayerUiMapID(ResolveDirectUiMapID(mapID, mapLevel)) or uiMapID
    end
	if not uiMapID and not WorldMapFrame:IsVisible() then
		-- Some starter subzones expose a mapAreaID that does not exist in UiMapData.
		-- Force map context to the parent zone map first (not continent), so coordinates stay in local zone space.
		local continent = GetCurrentMapContinent();
		local zone = GetCurrentMapZone();
		if continent and continent > 0 and zone and zone > 0 then
			SetMapZoom(continent, zone);
		else
			SetMapToCurrentZone();
		end

		local zx, zy = GetPlayerMapPosition("player");
		if ( zx > 0 or zy > 0 ) then
			x, y = zx, zy;
		end

		mapID, mapLevel = GetRawMapContext();
		uiMapID = NormalizeResolvedPlayerUiMapID(ResolveDirectUiMapID(mapID, mapLevel));

		if not uiMapID then
			if ( ZoomOut() ) then
				local ox, oy = GetPlayerMapPosition("player");
				if ( ox > 0 or oy > 0 ) then
					x, y = ox, oy;
				end
			elseif ( GetCurrentMapZone() ~= WORLDMAP_WORLD_ID ) then
				SetMapZoom(GetCurrentMapContinent());
				local ox, oy = GetPlayerMapPosition("player");
				if ( ox > 0 or oy > 0 ) then
					x, y = ox, oy;
				end
			end

			mapID, mapLevel = GetRawMapContext();
			uiMapID = NormalizeResolvedPlayerUiMapID(ResolveDirectUiMapID(mapID, mapLevel));
		end
	end

	if not uiMapID then
		uiMapID = QuestieCompat.GetCurrentUiMapID();
	end

    local worldMapVisible = WorldMapFrame and WorldMapFrame:IsVisible()
    if zoneUiMapID and IsZoneLikeUiMap(zoneUiMapID) and not IsWorldMapOnlyUiMap(zoneUiMapID) then
        if worldMapVisible then
            if not uiMapID then
                uiMapID = zoneUiMapID
            end
        elseif (not uiMapID) or IsContinentalOrCosmicUiMap(uiMapID) or uiMapID == zoneUiMapID or IsDescendantUiMap(zoneUiMapID, uiMapID) then
            uiMapID = zoneUiMapID
        end
    elseif uiMapID and IsContinentalOrCosmicUiMap(uiMapID) and lastKnownZoneLikeUiMapID and not worldMapVisible then
        uiMapID = lastKnownZoneLikeUiMapID
    end

    if worldMapVisible and zoneUiMapID and minimapChildToParentRebaseUiMapId[zoneUiMapID] and uiMapID and (x > 0 or y > 0) then
        local parentUiMapID = QuestieCompat.UiMapData[zoneUiMapID] and QuestieCompat.UiMapData[zoneUiMapID].parentMapID
        local sourceUiMapID = nil
        if rawUiMapID == zoneUiMapID then
            sourceUiMapID = zoneUiMapID
        elseif rawUiMapID and rawUiMapID ~= parentUiMapID then
            local rawUiData = QuestieCompat.UiMapData and QuestieCompat.UiMapData[rawUiMapID]
            local parentUiData = parentUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[parentUiMapID]
            if rawUiData and parentUiData and rawUiData.instance == parentUiData.instance then
                sourceUiMapID = rawUiMapID
            end
        end

        if parentUiMapID and sourceUiMapID then
            local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(x, y, sourceUiMapID, parentUiMapID)
            if translatedX and translatedY then
                uiMapID = parentUiMapID
                x, y = translatedX, translatedY
            end
        elseif parentUiMapID then
            uiMapID = parentUiMapID
        end
    end

    if ShouldCacheZoneLikeUiMap(uiMapID) then
        lastKnownZoneLikeUiMapID = uiMapID
    end

	if uiMapID and uiMapID ~= 946 and not WorldMapFrame:IsVisible() then
		local uiData = QuestieCompat.UiMapData[uiMapID];
		if uiData and uiData.mapID and uiData.mapID >= 0 then
			local currentMapID, currentMapLevel = GetRawMapContext();
			local targetMapID = uiData.mapID;
			local targetMapLevel = QuestieCompat.Round((targetMapID % 1) * 10);
			if NormalizeMapKey(currentMapID, currentMapLevel) ~= NormalizeMapKey(targetMapID, targetMapLevel) then
				SetMapByID(math.floor(targetMapID) - 1);
				if targetMapLevel > 0 then
					SetDungeonMapLevel(targetMapLevel);
				end
				local ax, ay = GetPlayerMapPosition("player");
				if (ax > 0 or ay > 0) then
					x, y = ax, ay;
				end
			end
		end
	end

    StoreCachedPlayerPosition(playerPositionCache, contextKey, uiMapID, x, y)
	return uiMapID, x, y;
end

function QuestieCompat.GetCurrentPlayerRawPosition()
    local x, y = GetPlayerMapPosition("player")

    if (x <= 0 and y <= 0) then
        if WorldMapFrame:IsVisible() then
            return QuestieCompat.GetCurrentPlayerPosition()
        end

        SetMapToCurrentZone()
        x, y = GetPlayerMapPosition("player")
        if (x <= 0 and y <= 0) then
            if (ZoomOut()) then
                -- do nothing
            elseif (GetCurrentMapZone() ~= WORLDMAP_WORLD_ID) then
                SetMapZoom(GetCurrentMapContinent())
            else
                SetMapZoom(WORLDMAP_WORLD_ID)
            end
            x, y = GetPlayerMapPosition("player")
        end
    end

    local mapID, mapLevel = GetRawMapContext()
    local rawUiMapID = ResolveDirectUiMapID(mapID, mapLevel)
    if rawUiMapID and (x > 0 or y > 0) then
        return rawUiMapID, x, y
    end

    return QuestieCompat.GetCurrentPlayerPosition()
end

function QuestieCompat.GetCurrentPlayerStableWorldPosition()
    local contextKey = GetPlayerPositionCacheContextKey()
    local cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID = TryGetCachedPlayerPosition(stablePlayerWorldPositionCache, PLAYER_POSITION_CACHE_TTL, contextKey)
    if cachedWorldX ~= nil then
        return cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID
    end

    if not WorldMapFrame:IsVisible() then
        ResetAnchoredDisplayedWorldPosition()
        local uiMapID, x, y = QuestieCompat.GetCurrentPlayerPosition()
        if uiMapID and x and y then
            local worldX, worldY, instanceID = GetWorldCoordinatesFromUiMapPosition(x, y, uiMapID)
            if worldX and worldY then
                CacheStablePlayerWorldPosition(worldX, worldY, instanceID, uiMapID)
                StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, worldX, worldY, instanceID, uiMapID)
                return worldX, worldY, instanceID, uiMapID
            end
        end
    else
        local x, y = GetPlayerMapPosition("player")
        local mapID, mapLevel = GetRawMapContext()
        local displayedMapName = GetDisplayedWorldMapName()
        local displayedUiMapID = ResolveDisplayedWorldMapUiMapID(mapID, mapLevel, displayedMapName)
        local actualUiMapID = ResolveUiMapIDByZoneTexts()

        if actualUiMapID and not IsZoneLikeUiMap(actualUiMapID) then
            actualUiMapID = nil
        end
        if not actualUiMapID then
            actualUiMapID = lastKnownZoneLikeUiMapID
        end

        local shouldFreezeVisibleRead = ShouldFreezeVisibleWorldMapPlayerRead(mapID, displayedUiMapID, actualUiMapID)
        if shouldFreezeVisibleRead then
            if displayedUiMapID and not IsZoneLikeUiMap(displayedUiMapID) then
                local anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID = GetAnchoredDisplayedWorldPosition(displayedUiMapID, x, y)
                if anchoredWorldX and anchoredWorldY then
                    StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID)
                    return anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID
                end
            else
                ResetAnchoredDisplayedWorldPosition()
            end

            if lastStablePlayerWorldX and lastStablePlayerWorldY then
                StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
                return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
            end

            return nil, nil, nil, nil
        end

        ResetAnchoredDisplayedWorldPosition()

        if actualUiMapID and (x > 0 or y > 0) then
            local zoneX, zoneY = x, y
            local sourceUiMapID = displayedUiMapID or actualUiMapID
            if sourceUiMapID ~= actualUiMapID then
                zoneX, zoneY = TranslateZoneCoordinatesBetweenUiMaps(x, y, sourceUiMapID, actualUiMapID)
            end

            if zoneX and zoneY then
                local worldX, worldY, instanceID = GetWorldCoordinatesFromUiMapPosition(zoneX, zoneY, actualUiMapID)
                if worldX and worldY then
                    CacheStablePlayerWorldPosition(worldX, worldY, instanceID, actualUiMapID)
                    StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, worldX, worldY, instanceID, actualUiMapID)
                    return worldX, worldY, instanceID, actualUiMapID
                end
            end
        end

        if ShouldUseExactPlayerWorldRead(mapID, displayedUiMapID, actualUiMapID) then
            local exactWorldX, exactWorldY, exactInstanceID, exactUiMapID = GetPlayerWorldPositionFromActualZoneUiMap(actualUiMapID)
            if exactWorldX and exactWorldY then
                CacheStablePlayerWorldPosition(exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
                StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
                return exactWorldX, exactWorldY, exactInstanceID, exactUiMapID
            end
        end
    end

    if lastStablePlayerWorldX and lastStablePlayerWorldY then
        StoreCachedPlayerPosition(stablePlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
        return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
    end

    return nil, nil, nil, nil
end

function QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
    local contextKey = GetPlayerPositionCacheContextKey()
    local cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID = TryGetCachedPlayerPosition(minimapPlayerWorldPositionCache, PLAYER_POSITION_CACHE_TTL, contextKey)
    if cachedWorldX ~= nil then
        return cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID
    end

    local worldMapVisible = WorldMapFrame and WorldMapFrame:IsVisible()
    if worldMapVisible then
        EnsureWorldMapInteractionHooks()
    else
        ResetAnchoredMinimapWorldPosition()
    end

    local actualUiMapID = ResolveUiMapIDByZoneTexts()
    if actualUiMapID and not IsZoneLikeUiMap(actualUiMapID) then
        actualUiMapID = nil
    end
    if not actualUiMapID then
        actualUiMapID = lastKnownZoneLikeUiMapID
    end

    local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
    local displayedUiMapID = nil
    local isAzerothOutlandChooser = false
    local chooserPlayerUiMapID = nil
    local rawMapID = nil
    local rawMapLevel = nil
    if worldMapVisible then
        rawMapID, rawMapLevel = GetRawMapContext()
        local displayedMapName = GetDisplayedWorldMapName()
        displayedUiMapID = ResolveDisplayedWorldMapUiMapID(rawMapID, rawMapLevel, displayedMapName)
        isAzerothOutlandChooser = IsAzerothOutlandChooserVisible(rawMapID) or displayedUiMapID == 946
        if isAzerothOutlandChooser then
            chooserPlayerUiMapID = ResolveChooserPlayerUiMapID(actualUiMapID)
        end
    end

    local dropdownMenuOpen = IsWorldMapDropdownMenuOpen()
    local shouldFreezeVisibleRead = worldMapVisible and ShouldFreezeVisibleWorldMapPlayerRead(rawMapID, displayedUiMapID, normalizedActualUiMapID)
    local shouldSuppressExactRead = dropdownMenuOpen or isAzerothOutlandChooser or shouldFreezeVisibleRead
    local visibleMapIsUnrelated = worldMapVisible
        and displayedUiMapID
        and normalizedActualUiMapID
        and (not AreUiMapsRelated(displayedUiMapID, normalizedActualUiMapID))
    local starterChildUiMapID = actualUiMapID
    if not (starterChildUiMapID and minimapChildToParentRebaseUiMapId[starterChildUiMapID]) then
        local subZoneUiMapID = ResolveUiMapIDByMapName(GetSubZoneText and GetSubZoneText() or nil)
        if subZoneUiMapID and minimapChildToParentRebaseUiMapId[subZoneUiMapID] then
            starterChildUiMapID = subZoneUiMapID
        end
    end

    if worldMapVisible
        and starterChildUiMapID
        and displayedUiMapID
        and (not shouldSuppressExactRead)
        and AreUiMapsRelated(displayedUiMapID, NormalizeActualZoneUiMapID(starterChildUiMapID) or starterChildUiMapID) then
        local exactWorldX, exactWorldY, exactInstanceID, exactUiMapID = GetPlayerWorldPositionFromActualZoneUiMap(starterChildUiMapID)
        if exactWorldX and exactWorldY then
            ResetAnchoredMinimapWorldPosition()
            CacheMinimapPlayerWorldPosition(exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
            return exactWorldX, exactWorldY, exactInstanceID, exactUiMapID
        end
    end

    local unitWorldX, unitWorldY, unitInstanceID, unitUiMapID = GetPlayerWorldPositionFromUnitPosition(actualUiMapID)
    if unitWorldX and unitWorldY then
        ResetAnchoredMinimapWorldPosition()
        unitUiMapID = unitUiMapID or NormalizeActualZoneUiMapID(actualUiMapID)
        CacheMinimapPlayerWorldPosition(unitWorldX, unitWorldY, unitInstanceID, unitUiMapID)
        StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, unitWorldX, unitWorldY, unitInstanceID, unitUiMapID)
        return unitWorldX, unitWorldY, unitInstanceID, unitUiMapID
    end

    local isPlayerMoving = true
    if type(GetUnitSpeed) == "function" then
        local playerSpeed = GetUnitSpeed("player")
        isPlayerMoving = playerSpeed and playerSpeed > 0 or false
    end
    local shouldUseIdleVisibleMapCache = worldMapVisible
        and displayedUiMapID
        and normalizedActualUiMapID
        and (not shouldSuppressExactRead)
        and (not isPlayerMoving)
        and displayedUiMapID ~= normalizedActualUiMapID
        and (visibleMapIsUnrelated or (not IsZoneLikeUiMap(displayedUiMapID)))

    if shouldUseIdleVisibleMapCache then
        ResetAnchoredMinimapWorldPosition()

        if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastMinimapPlayerUiMapID, actualUiMapID) then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
            return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
        end

        if lastStablePlayerWorldX and lastStablePlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastStablePlayerUiMapID, actualUiMapID) then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
            return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
        end
    end

    local uiMapID, x, y = nil, nil, nil
    if (not visibleMapIsUnrelated) or shouldSuppressExactRead or (not worldMapVisible) then
        uiMapID, x, y = QuestieCompat.GetCurrentPlayerPosition()
        if (not worldMapVisible) and uiMapID and IsZoneLikeUiMap(uiMapID) and (not IsWorldMapOnlyUiMap(uiMapID)) then
            -- Hidden map reads are more reliable for dedicated underground/sub-zone maps
            -- than the legacy zone text APIs, which can stay on the parent surface zone.
            actualUiMapID = uiMapID
            normalizedActualUiMapID = NormalizeActualZoneUiMapID(uiMapID)
        end
        do
            local worldX, worldY, instanceID = GetValidatedResolvedMinimapWorldPosition(uiMapID, x, y, actualUiMapID)
            if worldX and worldY then
                ResetAnchoredMinimapWorldPosition()
                CacheMinimapPlayerWorldPosition(worldX, worldY, instanceID, uiMapID)
                StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, worldX, worldY, instanceID, uiMapID)
                return worldX, worldY, instanceID, uiMapID
            end
        end
        displayedUiMapID = displayedUiMapID or uiMapID
    end

    if shouldSuppressExactRead and worldMapVisible then
        if isAzerothOutlandChooser then
            local anchorUiMapID = chooserPlayerUiMapID
            if anchorUiMapID and x and y and (x > 0 or y > 0) then
                local anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID = GetAnchoredMinimapWorldPosition(anchorUiMapID, x, y)
                if anchoredWorldX and anchoredWorldY then
                    StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID)
                    return anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID
                end
            end

            ResetAnchoredMinimapWorldPosition()
            if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastMinimapPlayerUiMapID, actualUiMapID) then
                StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
                return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
            end
            if lastStablePlayerWorldX and lastStablePlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastStablePlayerUiMapID, actualUiMapID) then
                StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
                return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
            end
        else
            if not displayedUiMapID then
                displayedUiMapID = uiMapID
            end

            local anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID = GetAnchoredMinimapWorldPosition(displayedUiMapID, x, y)
            if anchoredWorldX and anchoredWorldY then
                StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID)
                return anchoredWorldX, anchoredWorldY, anchoredInstanceID, anchoredUiMapID
            end
        end
    end

    ResetAnchoredMinimapWorldPosition()

    if worldMapVisible and visibleMapIsUnrelated and not shouldSuppressExactRead and not isPlayerMoving then
        if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastMinimapPlayerUiMapID, actualUiMapID) then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
            return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
        end

        if lastStablePlayerWorldX and lastStablePlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastStablePlayerUiMapID, actualUiMapID) then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
            return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
        end
    end

    if actualUiMapID and not shouldSuppressExactRead then
        local exactWorldX, exactWorldY, exactInstanceID, exactUiMapID = GetPlayerWorldPositionFromActualZoneUiMap(actualUiMapID)
        if exactWorldX and exactWorldY then
            CacheMinimapPlayerWorldPosition(exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, exactWorldX, exactWorldY, exactInstanceID, exactUiMapID)
            return exactWorldX, exactWorldY, exactInstanceID, exactUiMapID
        end
    end

    if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastMinimapPlayerUiMapID, actualUiMapID) then
        StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
        return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
    end

    if lastStablePlayerWorldX and lastStablePlayerWorldY and IsCachedWorldPositionUsableForUiMap(lastStablePlayerUiMapID, actualUiMapID) then
        StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
        return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
    end

    local stableWorldX, stableWorldY, stableInstanceID, stableUiMapID = QuestieCompat.GetCurrentPlayerStableWorldPosition()
    if IsCachedWorldPositionUsableForUiMap(stableUiMapID, actualUiMapID) then
        return stableWorldX, stableWorldY, stableInstanceID, stableUiMapID
    end

    return nil, nil, nil, nil
end

local function ResolveActualUiMapIDForMapContext(actualUiMapID, displayedUiMapID, allowDisplayedUiMapWithoutActual)
    if actualUiMapID and not IsZoneLikeUiMap(actualUiMapID) then
        actualUiMapID = nil
    end

    local subZoneUiMapID = ResolveUiMapIDByMapName(GetSubZoneText and GetSubZoneText() or nil)
    if subZoneUiMapID and IsZoneLikeUiMap(subZoneUiMapID) and IsWorldMapOnlyUiMap(subZoneUiMapID) then
        if not actualUiMapID or AreUiMapsRelated(subZoneUiMapID, actualUiMapID) then
            actualUiMapID = subZoneUiMapID
        end
    end

    if displayedUiMapID and IsWorldMapOnlyUiMap(displayedUiMapID) then
        local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
        local displayedParentUiMapID = displayedUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[displayedUiMapID] and QuestieCompat.UiMapData[displayedUiMapID].parentMapID

        if (allowDisplayedUiMapWithoutActual and not actualUiMapID)
            or displayedUiMapID == actualUiMapID
            or (displayedParentUiMapID and displayedParentUiMapID == actualUiMapID)
            or (displayedParentUiMapID and displayedParentUiMapID == normalizedActualUiMapID)
            or (actualUiMapID and AreUiMapsRelated(displayedUiMapID, actualUiMapID)) then
            actualUiMapID = displayedUiMapID
        end
    end

    return actualUiMapID, NormalizeActualZoneUiMapID(actualUiMapID)
end

local function ResolveActualPlayerUiMapID()
    local displayedUiMapID = nil
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        local rawMapID, rawMapLevel = GetRawMapContext()
        local displayedMapName = GetDisplayedWorldMapName()
        displayedUiMapID = ResolveDisplayedWorldMapUiMapID(rawMapID, rawMapLevel, displayedMapName)
    end

    local actualUiMapID, normalizedActualUiMapID = ResolveActualUiMapIDForMapContext(ResolveUiMapIDByZoneTexts(), displayedUiMapID, false)
    if not actualUiMapID then
        actualUiMapID = lastKnownZoneLikeUiMapID
        normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
    end

    return actualUiMapID, normalizedActualUiMapID
end

local function GetCurrentActualPlayerZonePosition()
    local actualUiMapID, normalizedActualUiMapID = ResolveActualPlayerUiMapID()
    if not actualUiMapID and not normalizedActualUiMapID then
        return nil, nil, nil
    end

    local worldX = lastMinimapPlayerWorldX or lastStablePlayerWorldX
    local worldY = lastMinimapPlayerWorldY or lastStablePlayerWorldY
    if not worldX or not worldY then
        worldX, worldY = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
    end

    local resolvedUiMapID, resolvedX, resolvedY = QuestieCompat.GetCurrentPlayerPosition()
    local targetUiMapIDs = {actualUiMapID}
    if normalizedActualUiMapID and normalizedActualUiMapID ~= actualUiMapID then
        targetUiMapIDs[#targetUiMapIDs + 1] = normalizedActualUiMapID
    end

    for _, targetUiMapID in ipairs(targetUiMapIDs) do
        if targetUiMapID and worldX and worldY and QuestieCompat.HBD and QuestieCompat.HBD.GetZoneCoordinatesFromWorld then
            local zoneX, zoneY = QuestieCompat.HBD:GetZoneCoordinatesFromWorld(worldX, worldY, targetUiMapID, true)
            if IsValidZoneCoords(zoneX, zoneY) then
                return targetUiMapID, zoneX, zoneY
            end
        end

        if resolvedUiMapID and resolvedX and resolvedY and (resolvedX > 0 or resolvedY > 0) then
            if resolvedUiMapID == targetUiMapID then
                return targetUiMapID, resolvedX, resolvedY
            end

            local translatedX, translatedY = TranslateZoneCoordinatesBetweenUiMaps(resolvedX, resolvedY, resolvedUiMapID, targetUiMapID)
            if translatedX and translatedY then
                return targetUiMapID, translatedX, translatedY
            end
        end
    end

    return nil, nil, nil
end

local function SetTomTomTextIfChanged(fontString, text)
    if fontString and text and fontString:GetText() ~= text then
        fontString:SetText(text)
    end
end

local function GetTomTomWorldMapCursorPosition()
    if not WorldMapDetailFrame or not WorldMapDetailFrame:IsVisible() then
        return nil, nil
    end

    local cursorX, cursorY = GetCursorPosition()
    local left = WorldMapDetailFrame:GetLeft()
    local top = WorldMapDetailFrame:GetTop()
    local width = WorldMapDetailFrame:GetWidth()
    local height = WorldMapDetailFrame:GetHeight()
    local scale = WorldMapDetailFrame:GetEffectiveScale()

    if not cursorX or not cursorY or not left or not top or not width or width == 0 or not height or height == 0 or not scale or scale == 0 then
        return nil, nil
    end

    local mapX = (cursorX / scale - left) / width
    local mapY = (top - cursorY / scale) / height
    if mapX < 0 or mapX > 1 or mapY < 0 or mapY > 1 then
        return nil, nil
    end

    return mapX, mapY
end

local function FormatTomTomCoordinatePair(x, y, precision)
    precision = precision or 2
    return string.format("%." .. precision .. "f, %." .. precision .. "f", x * 100, y * 100)
end

local function ShouldUseCompatTomTomWorldCoords()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        return false
    end

    local rawMapID, rawMapLevel = GetRawMapContext()
    local displayedMapName = GetDisplayedWorldMapName()
    local displayedUiMapID = ResolveDisplayedWorldMapUiMapID(rawMapID, rawMapLevel, displayedMapName)
    local _, normalizedActualUiMapID = ResolveActualUiMapIDForMapContext(ResolveUiMapIDByZoneTexts(), displayedUiMapID, true)
    normalizedActualUiMapID = normalizedActualUiMapID or NormalizeActualZoneUiMapID(lastKnownZoneLikeUiMapID)

    if not displayedUiMapID or not normalizedActualUiMapID then
        return false
    end

    return displayedUiMapID ~= normalizedActualUiMapID
end

function QuestieCompat.UpdateTomTomWorldCoords(frame, elapsed)
    if not frame or not frame:IsVisible() then
        return
    end

    if frame.questieOriginalOnUpdate and not ShouldUseCompatTomTomWorldCoords() then
        frame.questieOriginalCoordElapsed = (frame.questieOriginalCoordElapsed or 0) + (elapsed or 0)
        if frame.questieOriginalCoordElapsed < 0.1 then
            return
        end

        local originalElapsed = frame.questieOriginalCoordElapsed
        frame.questieOriginalCoordElapsed = 0
        return frame.questieOriginalOnUpdate(frame, originalElapsed)
    end

    frame.questieCoordElapsed = (frame.questieCoordElapsed or 0) + (elapsed or 0)
    if frame.questieCoordElapsed < 0.05 then
        return
    end
    frame.questieCoordElapsed = 0

    local TomTom = _G.TomTom
    local profile = TomTom and TomTom.db and TomTom.db.profile
    local mapCoordsProfile = profile and profile.mapcoords
    if not mapCoordsProfile then
        return
    end
    local _, playerX, playerY = GetCurrentActualPlayerZonePosition()

    if frame.Player then
        if playerX and playerY then
            SetTomTomTextIfChanged(frame.Player, "Player: " .. FormatTomTomCoordinatePair(playerX, playerY, mapCoordsProfile.playeraccuracy))
        else
            SetTomTomTextIfChanged(frame.Player, "Player: ---")
        end
    end

    if frame.Cursor then
        local cursorX, cursorY = GetTomTomWorldMapCursorPosition()
        if cursorX and cursorY then
            SetTomTomTextIfChanged(frame.Cursor, "Cursor: " .. FormatTomTomCoordinatePair(cursorX, cursorY, mapCoordsProfile.cursoraccuracy))
        else
            SetTomTomTextIfChanged(frame.Cursor, "Cursor: ---")
        end
    end
end

function QuestieCompat.PatchTomTomWorldCoords()
    local TomTom = _G.TomTom
    if not TomTom or not TomTom.ShowHideWorldCoords then
        return
    end

    if not TomTom.questieWorldCoordsHooked then
        TomTom.questieWorldCoordsHooked = true
        hooksecurefunc(TomTom, "ShowHideWorldCoords", QuestieCompat.PatchTomTomWorldCoords)
    end

    local tomTomWorldFrame = _G.TomTomWorldFrame
    if tomTomWorldFrame then
        if not tomTomWorldFrame.questieOriginalOnUpdate then
            tomTomWorldFrame.questieOriginalOnUpdate = tomTomWorldFrame:GetScript("OnUpdate")
        end
        tomTomWorldFrame:SetScript("OnUpdate", QuestieCompat.UpdateTomTomWorldCoords)
    end
end

-- wrapper used by QuestieCoords
local playerPos = {}
function QuestieCompat.GetPlayerMapPosition()
    playerPos.uiMapID, playerPos.x, playerPos.y = QuestieCompat.GetCurrentPlayerPosition()
    return playerPos, playerPos.uiMapID
end

QuestieCompat.C_Map = {
    -- Returns map information.
	-- https://wowpedia.fandom.com/wiki/API_C_Map.GetMapInfo
	GetMapInfo = function(uiMapID)
        return BuildUiMapInfo(uiMapID)
	end,
    -- Returns a map subzone name.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetAreaInfo
	GetAreaInfo = function(areaID)
        return GetAreaName(areaID)
	end,
    -- Returns the current UI map for the given unit.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetBestMapForUnit
	GetBestMapForUnit = function(unit)
        if unit == "player" then
            local actualUiMapID, normalizedActualUiMapID = ResolveActualPlayerUiMapID()
            return actualUiMapID or normalizedActualUiMapID or QuestieCompat.GetCurrentPlayerPosition()
        end
	end,
    -- Returns the player's position on a map.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetPlayerMapPosition
    GetPlayerMapPosition = function(uiMapID, unit)
        if unit == "player" or uiMapID == "player" then
            return QuestieCompat.GetPlayerMapPosition()
        end
    end,
    -- Returns child maps of a map.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetMapChildrenInfo
    GetMapChildrenInfo = function(uiMapID, mapType, allDescendants)
        local results = CollectMapChildrenInfo(uiMapID, mapType, allDescendants == true)
        return #results > 0 and results or nil
    end,
    -- Translates a map position to a world map position.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetWorldPosFromMapPos
	GetWorldPosFromMapPos = function(uiMapID, mapPos)
        local x, y, instanceID = QuestieCompat.HBD:GetWorldCoordinatesFromZone(mapPos.x, mapPos.y, uiMapID)
        return instanceID or 0, {x = x or 0, y = y or 0}
	end,
}

if not C_Map then
    C_Map = QuestieCompat.C_Map
end

-- https://www.townlong-yak.com/framexml/classic/Blizzard_MapCanvas/Blizzard_MapCanvas.lua
QuestieCompat.WorldMapFrame = {
    IsVisible = function(self)
        return WorldMapFrame:IsVisible()
    end,
    IsShown = function(self)
        return WorldMapFrame:IsShown()
    end,
    Show = function(self)
        ShowUIPanel(WorldMapFrame)
    end,
    GetCanvas = function(self)
        return WorldMapButton
    end,
    GetMapID = QuestieCompat.GetCurrentUiMapID,
    SetMapID = function(self, UiMapID)
        local uiData = QuestieCompat.UiMapData[UiMapID]
        if not uiData then
            return
        end

        local mapID = uiData.mapID
        if uiData.worldMapOnly and uiData.parentMapID and QuestieCompat.UiMapData[uiData.parentMapID] then
            mapID = QuestieCompat.UiMapData[uiData.parentMapID].mapID
        end
        if not mapID then
            return
        end

        local mapLevel = QuestieCompat.Round(mapID%1 * 10)

        SetMapByID(math.floor(mapID) - 1)
        if mapLevel > 0 then
            SetDungeonMapLevel(mapLevel)
        end
    end,
    EnumeratePinsByTemplate = function(self, template)
        return pairs(QuestieCompat.HBDPins.worldmapPins)
    end,
}

function QuestieCompat.InitializeMapCompatibility()
    if mapCompatibilityInitialized then return end
    mapCompatibilityInitialized = true

    for uiMapId, data in pairs(QuestieCompat.UiMapData) do
        mapIdToUiMapId[data.mapID] = uiMapId
        mapIdToUiMapId[NormalizeMapKey(data.mapID, 0)] = uiMapId

        -- Map outdoor/city zone names to uiMap so player position can stay in the correct map space
        -- even when the hidden map context drifts after browsing other maps.
        if data.name and (data.mapType == 3 or data.mapType == 5) then
            zoneNameToUiMapId[data.name] = uiMapId
        end
    end

    BuildMapIdToCZ()

    local areaIdToUiMapId = ZoneDB.private and ZoneDB.private.areaIdToUiMapId

    -- Build zone-name -> areaId and zone-name -> uiMap using all lookup categories.
    if l10n and l10n.zoneLookup then
        for _, lookupTable in pairs(l10n.zoneLookup) do
            if type(lookupTable) == "table" then
                for areaId, zoneName in pairs(lookupTable) do
                    if zoneName and zoneName ~= "" then
                        areaIdToZoneName[areaId] = areaIdToZoneName[areaId] or zoneName
                        zoneNameToAreaId[zoneName] = zoneNameToAreaId[zoneName] or areaId
                        local uiMapID = GetUiMapIdForAreaId(areaId) or GetParentUiMapIdForAreaId(areaId)
                        if uiMapID then
                            zoneNameToUiMapId[zoneName] = zoneNameToUiMapId[zoneName] or uiMapID
                        end
                    end
                end
            end
        end
    end

    -- Map remaining subzone names to their parent zone uiMap when they do not have a dedicated child uiMap.
    local subZoneToParentZone = ZoneDB.private and ZoneDB.private.subZoneToParentZone
    if subZoneToParentZone and areaIdToUiMapId then
        for subZoneId, parentZoneId in pairs(subZoneToParentZone) do
            local parentUiMapId = areaIdToUiMapId[parentZoneId]
            local subZoneName = nil
            if l10n and l10n.zoneLookup then
                for _, lookupTable in pairs(l10n.zoneLookup) do
                    if type(lookupTable) == "table" and lookupTable[subZoneId] then
                        subZoneName = lookupTable[subZoneId]
                        break
                    end
                end
            end
            if subZoneName and parentUiMapId then
                zoneNameToUiMapId[subZoneName] = zoneNameToUiMapId[subZoneName] or parentUiMapId
            end
        end
    end

    EnsureWorldMapInteractionHooks()
end
