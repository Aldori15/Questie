---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieStream
local QuestieStream = QuestieLoader:ImportModule("QuestieStreamLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieEventHandler
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@class AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type MinimapIcon
local MinimapIcon = QuestieLoader:ImportModule("MinimapIcon")
---@type TrackerLinePool
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestXP
local QuestXP = QuestieLoader:ImportModule("QuestXP")
---@class QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords")
---@class Sounds
local Sounds = QuestieLoader:ImportModule("Sounds")
---@class QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@class QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@class QuestieNameplate
local QuestieNameplate = QuestieLoader:ImportModule("QuestieNameplate")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@class QuestieLink
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")

-- addon/folder name
QuestieCompat.addonName = ...

QuestieCompat.NOOP = function() end
QuestieCompat.NOOP_MT = {__index = function() return QuestieCompat.NOOP end}

-- events handler
QuestieCompat.frame = CreateFrame("Frame")
QuestieCompat.frame:RegisterEvent("ADDON_LOADED")
QuestieCompat.frame:RegisterEvent("PLAYER_LOGIN")
QuestieCompat.frame:RegisterEvent("PLAYER_LOGOUT")
QuestieCompat.frame:SetScript("OnEvent", function(self, event, ...)
    QuestieCompat[event](self, event, ...)
end)

-- current expansion level (https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID)
QuestieCompat.WOW_PROJECT_CLASSIC = 2
QuestieCompat.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
QuestieCompat.WOW_PROJECT_WRATH_CLASSIC = 11
QuestieCompat.WOW_PROJECT_ID = tonumber(GetAddOnMetadata(QuestieCompat.addonName, "X-WOW_PROJECT_ID"))

-- check for a specific type of group
QuestieCompat.LE_PARTY_CATEGORY_HOME = 1 -- home-realm parties
QuestieCompat.LE_PARTY_CATEGORY_INSTANCE = 2 -- instance-specific groups

-- Date stuff
QuestieCompat.CALENDAR_WEEKDAY_NAMES = {
	WEEKDAY_SUNDAY,
	WEEKDAY_MONDAY,
	WEEKDAY_TUESDAY,
	WEEKDAY_WEDNESDAY,
	WEEKDAY_THURSDAY,
	WEEKDAY_FRIDAY,
	WEEKDAY_SATURDAY,
};

-- month names show up differently for full date displays in some languages
QuestieCompat.CALENDAR_FULLDATE_MONTH_NAMES = {
	FULLDATE_MONTH_JANUARY,
	FULLDATE_MONTH_FEBRUARY,
	FULLDATE_MONTH_MARCH,
	FULLDATE_MONTH_APRIL,
	FULLDATE_MONTH_MAY,
	FULLDATE_MONTH_JUNE,
	FULLDATE_MONTH_JULY,
	FULLDATE_MONTH_AUGUST,
	FULLDATE_MONTH_SEPTEMBER,
	FULLDATE_MONTH_OCTOBER,
	FULLDATE_MONTH_NOVEMBER,
	FULLDATE_MONTH_DECEMBER,
};

-- https://wago.tools/db2/ChrRaces?build=3.4.3.52237
QuestieCompat.ChrRaces = {
	Human = 1,
	Orc = 2,
	Dwarf = 3,
	NightElf = 4,
	Scourge = 5,
	Tauren = 6,
	Gnome = 7,
	Troll = 8,
	Goblin = 9,
	BloodElf = 10,
	Draenei = 11,
	FelOrc = 12,
	Naga_ = 13,
	Broken = 14,
	Skeleton = 15,
	Vrykul = 16,
	Tuskarr = 17,
	ForestTroll = 18,
	Taunka = 19,
	NorthrendSkeleton = 20,
	IceTroll = 21,
}

-- https://wago.tools/db2/ChrClasses?build=3.4.3.52237
QuestieCompat.ChrClasses = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 3,
	ROGUE = 4,
	PRIEST = 5,
	DEATHKNIGHT = 6,
	SHAMAN = 7,
	MAGE = 8,
	WARLOCK = 9,
	DRUID = 11,
}

local activeTimers = {}
local inactiveTimers = {}

local function timerCancel(id)
    local timer = activeTimers[id]
    if not timer then return end

    timer:GetParent():Stop()

    timer.id = nil
    activeTimers[id] = nil
	inactiveTimers[timer] = true
end

local function timerOnFinished(self)
    local id = self.id
    self.callback(id)

    -- Make sure timer wasn't cancelled during the callback and used again
    if id == self.id then
        if self.iterations > 0 then
            self.iterations = self.iterations - 1
            if self.iterations == 0 then
                timerCancel(id)
            end
        end
    end
end

QuestieCompat.C_Timer = {
    -- Schedules a (repeating) timer that can be canceled. (https://wowpedia.fandom.com/wiki/API_C_Timer.NewTimer)
    NewTicker = function(duration, callback, iterations)
        local timer = next(inactiveTimers)
        if timer then
        	inactiveTimers[timer] = nil
        else
        	local anim = QuestieCompat.frame:CreateAnimationGroup()
        	timer = anim:CreateAnimation()
        	timer:SetScript("OnFinished", timerOnFinished)
        end

        if duration < 0.01 then duration = 0.01 end
        timer:SetDuration(duration)

        timer.callback = callback
        timer.iterations = iterations or -1
        timer.id = {Cancel = timerCancel}
        activeTimers[timer.id] = timer

        local anim = timer:GetParent()
        anim:SetLooping("REPEAT")
        anim:Play()

        return timer.id
    end,
    -- Schedules a timer. (https://wowpedia.fandom.com/wiki/API_C_Timer.After)
    After = function(duration, callback)
        return QuestieCompat.C_Timer.NewTicker(duration, callback, 1)
    end
}

local mapIdToUiMapId = {}
local zoneNameToUiMapId = {}
local zoneNameToAreaId = {}
local areaIdToZoneName = {}
local mapIdToCZ = {}
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

    return table.concat({
        worldMapVisible and "1" or "0",
        tostring(rawMapID or 0),
        tostring(rawMapLevel or 0),
        tostring(zoneText or ""),
        tostring(subZoneText or ""),
        tostring(displayedMapName or ""),
    }, "|")
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

        if zoneX and zoneY and zoneX >= -0.25 and zoneX <= 1.25 and zoneY >= -0.25 and zoneY <= 1.25 then
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
}

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
                    zoneUiMapID = (starterAreaIdToUiMapId[areaId])
                        or (ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(areaId))
                    if not zoneUiMapID then
                        local parentAreaId = ZoneDB.GetParentZoneId and ZoneDB:GetParentZoneId(areaId) or nil
                        zoneUiMapID = parentAreaId and ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(parentAreaId)
                    end
                end
            end
            if zoneUiMapID then
                local uiData = QuestieCompat.UiMapData and QuestieCompat.UiMapData[zoneUiMapID]
                local mapType = uiData and uiData.mapType
                local isZoneLikeMap = mapType and mapType >= 3
                local isGenericWaterSubzone = (candidate.source == "sub") and genericWaterSubzones[zoneName]
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
            uiMapID = starterAreaIdToUiMapId[areaId]
            if not uiMapID then
                uiMapID = ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(areaId)
            end
            if not uiMapID then
                local parentAreaId = ZoneDB.GetParentZoneId and ZoneDB:GetParentZoneId(areaId) or nil
                uiMapID = parentAreaId and ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(parentAreaId)
            end
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

    return leftUiMapID == rightUiMapID
        or IsDescendantUiMap(leftUiMapID, rightUiMapID)
        or IsDescendantUiMap(rightUiMapID, leftUiMapID)
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

local function HasDirectUiMapRelationship(displayedUiMapID, actualUiMapID)
    if not displayedUiMapID or not actualUiMapID then
        return false
    end

    return displayedUiMapID == actualUiMapID
        or IsDescendantUiMap(displayedUiMapID, actualUiMapID)
        or IsDescendantUiMap(actualUiMapID, displayedUiMapID)
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

    return HasDirectUiMapRelationship(uiMapID, actualUiMapID)
        or HasDirectUiMapRelationship(actualUiMapID, uiMapID)
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

    return HasDirectUiMapRelationship(resolvedUiMapID, actualUiMapID)
        or HasDirectUiMapRelationship(actualUiMapID, resolvedUiMapID)
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
        if not zoneX or not zoneY or zoneX < -0.25 or zoneX > 1.25 or zoneY < -0.25 or zoneY > 1.25 then
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

    return not HasDirectUiMapRelationship(displayedUiMapID, actualUiMapID)
end

local function ShouldUseExactPlayerWorldRead(rawMapID, displayedUiMapID, actualUiMapID)
    if ShouldFreezeVisibleWorldMapPlayerRead(rawMapID, displayedUiMapID, actualUiMapID) then
        return false
    end

    return HasDirectUiMapRelationship(displayedUiMapID, actualUiMapID)
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
for C in ipairs({GetMapContinents()}) do
    local zones = {GetMapZones(C)}
    for Z in ipairs(zones) do
        SetMapZoom(C, Z)
        local mapId = GetCurrentMapAreaID()
        mapIdToCZ[mapId] = Z + C/10
    end
end

function QuestieCompat.TomTom_AddWaypoint(title, zone, x, y)
    local CZ = mapIdToCZ[QuestieCompat.UiMapData[zone].mapID]
    if (zone == 125) or (zone == 126) then CZ = 3.4 end
    -- Force the crazy arrow on 3.3.5 so Questie behaves like newer TomTom integrations.
    return TomTom:AddZWaypoint(QuestieCompat.Round(CZ%1 * 10), math.floor(CZ), x, y, title, nil, nil, nil, nil, nil, true)
end

-- This function will do its utmost to retrieve some sort of valid position
-- for the player, including changing the current map zoom (if needed)
-- https://wowpedia.fandom.com/wiki/API_C_Map.GetPlayerMapPosition?oldid=2167175
function QuestieCompat.GetCurrentPlayerPosition()
    local contextKey = GetPlayerPositionCacheContextKey()
    local cachedUiMapID, cachedX, cachedY = TryGetCachedPlayerPosition(playerPositionCache, 0.01, contextKey)
    if cachedUiMapID ~= nil then
        return cachedUiMapID, cachedX, cachedY
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
    local cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID = TryGetCachedPlayerPosition(stablePlayerWorldPositionCache, 0.01, contextKey)
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
    local cachedWorldX, cachedWorldY, cachedInstanceID, cachedUiMapID = TryGetCachedPlayerPosition(minimapPlayerWorldPositionCache, 0.01, contextKey)
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
        and (not HasDirectUiMapRelationship(displayedUiMapID, normalizedActualUiMapID))
        and (not HasDirectUiMapRelationship(normalizedActualUiMapID, displayedUiMapID))
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
        and HasDirectUiMapRelationship(displayedUiMapID, NormalizeActualZoneUiMapID(starterChildUiMapID) or starterChildUiMapID) then
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

        if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
            return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
        end

        if lastStablePlayerWorldX and lastStablePlayerWorldY then
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
            if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY then
                StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
                return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
            end
            if lastStablePlayerWorldX and lastStablePlayerWorldY then
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
        if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY then
            StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
            return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
        end

        if lastStablePlayerWorldX and lastStablePlayerWorldY then
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

    if lastMinimapPlayerWorldX and lastMinimapPlayerWorldY then
        StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID)
        return lastMinimapPlayerWorldX, lastMinimapPlayerWorldY, lastMinimapPlayerInstanceID, lastMinimapPlayerUiMapID
    end

    if lastStablePlayerWorldX and lastStablePlayerWorldY then
        StoreCachedPlayerPosition(minimapPlayerWorldPositionCache, contextKey, lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID)
        return lastStablePlayerWorldX, lastStablePlayerWorldY, lastStablePlayerInstanceID, lastStablePlayerUiMapID
    end

    return QuestieCompat.GetCurrentPlayerStableWorldPosition()
end

    local function ResolveActualPlayerUiMapID()
        local actualUiMapID = ResolveUiMapIDByZoneTexts()
        if actualUiMapID and not IsZoneLikeUiMap(actualUiMapID) then
            actualUiMapID = nil
        end

        local subZoneUiMapID = ResolveUiMapIDByMapName(GetSubZoneText and GetSubZoneText() or nil)
        if subZoneUiMapID and IsZoneLikeUiMap(subZoneUiMapID) and IsWorldMapOnlyUiMap(subZoneUiMapID) then
            if not actualUiMapID or HasDirectUiMapRelationship(subZoneUiMapID, actualUiMapID) then
                actualUiMapID = subZoneUiMapID
            end
        end

        if WorldMapFrame and WorldMapFrame:IsVisible() then
            local rawMapID, rawMapLevel = GetRawMapContext()
            local displayedMapName = GetDisplayedWorldMapName()
            local displayedUiMapID = ResolveDisplayedWorldMapUiMapID(rawMapID, rawMapLevel, displayedMapName)
            local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
            local displayedParentUiMapID = displayedUiMapID and QuestieCompat.UiMapData and QuestieCompat.UiMapData[displayedUiMapID] and QuestieCompat.UiMapData[displayedUiMapID].parentMapID

            if displayedUiMapID and IsWorldMapOnlyUiMap(displayedUiMapID) then
                if displayedUiMapID == actualUiMapID
                    or (displayedParentUiMapID and displayedParentUiMapID == actualUiMapID)
                    or (displayedParentUiMapID and displayedParentUiMapID == normalizedActualUiMapID)
                    or (actualUiMapID and HasDirectUiMapRelationship(displayedUiMapID, actualUiMapID)) then
                    actualUiMapID = displayedUiMapID
                end
            end
        end

        if not actualUiMapID then
            actualUiMapID = lastKnownZoneLikeUiMapID
        end

        return actualUiMapID, NormalizeActualZoneUiMapID(actualUiMapID)
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
            if zoneX and zoneY and zoneX >= -0.25 and zoneX <= 1.25 and zoneY >= -0.25 and zoneY <= 1.25 then
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
    local actualUiMapID = ResolveUiMapIDByZoneTexts()
    if actualUiMapID and not IsZoneLikeUiMap(actualUiMapID) then
        actualUiMapID = nil
    end

    local subZoneUiMapID = ResolveUiMapIDByMapName(GetSubZoneText and GetSubZoneText() or nil)
    if subZoneUiMapID and IsZoneLikeUiMap(subZoneUiMapID) and IsWorldMapOnlyUiMap(subZoneUiMapID) then
        if not actualUiMapID or HasDirectUiMapRelationship(subZoneUiMapID, actualUiMapID) then
            actualUiMapID = subZoneUiMapID
        end
    end

    if displayedUiMapID and IsWorldMapOnlyUiMap(displayedUiMapID) then
        local displayedParentUiMapID = QuestieCompat.UiMapData and QuestieCompat.UiMapData[displayedUiMapID] and QuestieCompat.UiMapData[displayedUiMapID].parentMapID
        local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID)
        if not actualUiMapID
            or displayedUiMapID == actualUiMapID
            or (displayedParentUiMapID and displayedParentUiMapID == actualUiMapID)
            or (displayedParentUiMapID and displayedParentUiMapID == normalizedActualUiMapID)
            or (actualUiMapID and HasDirectUiMapRelationship(displayedUiMapID, actualUiMapID)) then
            actualUiMapID = displayedUiMapID
        end
    end

    local normalizedActualUiMapID = NormalizeActualZoneUiMapID(actualUiMapID or lastKnownZoneLikeUiMapID)

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

QuestieCompat.C_Calendar = {
    -- Returns information about the calendar month by offset.
	-- https://wowpedia.fandom.com/wiki/API_C_Calendar.GetMonthInfo
	GetMonthInfo = function(offsetMonths)
        local month, year, numdays, firstday = CalendarGetMonth(offsetMonths or 0);
		return {
			month = month,
			year = year,
			numDays = numdays,
			firstWeekday = firstday,
		}
	end,
    OpenCalendar = function()
        if OpenCalendar then
            OpenCalendar()
        end
    end,
    SetMonth = function(offsetMonths)
        if CalendarSetMonth then
            CalendarSetMonth(offsetMonths or 0)
        end
    end,
    GetNumDayEvents = function(offsetMonths, dayOfMonth)
        if CalendarGetNumDayEvents then
            return CalendarGetNumDayEvents(offsetMonths or 0, dayOfMonth)
        end

        return 0
    end,
    GetHolidayInfo = function(offsetMonths, dayOfMonth, index)
        if not CalendarGetHolidayInfo then
            return nil
        end

        local name, description, texture = CalendarGetHolidayInfo(
            offsetMonths or 0,
            dayOfMonth,
            index
        )

        if not name then
            return nil
        end

        return {
            name = name,
            description = description,
            texture = texture,
        }
    end,
}

QuestieCompat.C_DateAndTime = {
    -- Returns the realm's current date and time.
	-- https://wowpedia.fandom.com/wiki/API_C_DateAndTime.GetCurrentCalendarTime
	GetCurrentCalendarTime = function()
		local weekday, month, day, year = CalendarGetDate();
		local hours, minutes = GetGameTime()
		return {
			year = year,
			month = month,
			monthDay = day,
			weekday = weekday,
			hour = hours,
			minute = minutes
		}
	end
}

-- Returns the server's Unix time.
-- https://wowpedia.fandom.com/wiki/API_GetServerTime
function QuestieCompat.GetServerTime()
    local weekday, month, day, year = CalendarGetDate()
	local hours, minutes = GetGameTime()

    local currentDate = {
        year = year,
        month = month,
        day = day,
        weekday = weekday,
        hour = hours,
        min = minutes,
    }

    return time(currentDate), currentDate
end

local questObjectivesCache = {}
local QUEST_OBJECTIVE_CACHE_TTL_SECONDS = 3

local function parseQuestObjective(text)
    return string.match(string.gsub(text, "\239\188\154", ":"), "(.*):%s*([%d]+)%s*/%s*([%d]+)")
end

local function normalizeObjectiveName(objectiveName)
    if type(objectiveName) ~= "string" then
        return objectiveName
    end

    -- Remove coloring codes and trim whitespace to keep lookup keys stable.
    objectiveName = objectiveName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return objectiveName:match("^%s*(.-)%s*$")
end

local function setObjectiveProgressCache(objectiveName, numFulfilled)
    numFulfilled = tonumber(numFulfilled)
    if (not objectiveName) or (not numFulfilled) then
        return
    end

    questObjectivesCache[objectiveName] = {
        fulfilled = numFulfilled,
        expiresAt = GetTime() + QUEST_OBJECTIVE_CACHE_TTL_SECONDS
    }
end

local function getObjectiveProgressCache(objectiveName)
    local cached = questObjectivesCache[objectiveName]
    if not cached then
        return nil
    end

    if (type(cached) ~= "table") or (type(cached.fulfilled) ~= "number") then
        questObjectivesCache[objectiveName] = nil
        return nil
    end

    if cached.expiresAt and (GetTime() > cached.expiresAt) then
        questObjectivesCache[objectiveName] = nil
        return nil
    end

    return cached.fulfilled
end

local function applyObjectiveProgressToQuestieCache(objectiveName, numFulfilled)
    numFulfilled = tonumber(numFulfilled)
    if (not objectiveName) or (not numFulfilled) then
        return false
    end

    local changedQuestIds = {}
    for questId, questData in pairs(QuestLogCache.questLog_DO_NOT_MODIFY or {}) do
        local objectives = questData and questData.objectives
        if objectives and #objectives > 0 then
            for _, objective in ipairs(objectives) do
                if objective and objective.type == "item" and normalizeObjectiveName(objective.text) == objectiveName then
                    local oldFulfilled = tonumber(objective.numFulfilled) or 0
                    if numFulfilled > oldFulfilled then
                        objective.numFulfilled = numFulfilled
                        objective.raw_numFulfilled = math.max(tonumber(objective.raw_numFulfilled) or 0, numFulfilled)
                        if objective.numRequired then
                            local isFinished = numFulfilled >= objective.numRequired
                            objective.finished = isFinished
                            objective.raw_finished = objective.raw_finished or isFinished
                        end
                        changedQuestIds[questId] = true
                    end
                end
            end
        end
    end

    local hasChanges = false
    for questId in pairs(changedQuestIds) do
        hasChanges = true
        QuestieQuest:SetObjectivesDirty(questId)
        QuestieQuest:UpdateQuest(questId)
    end

    return hasChanges
end

QuestieCompat.C_QuestLog = {
	-- Returns info for the objectives of a quest. (https://wowpedia.fandom.com/wiki/API_C_QuestLog.GetQuestObjectives)
	GetQuestObjectives = function(questID, questLogIndex)
		local questObjectives, objectiveIndex = {}, 1
        if questLogIndex then
		    local numObjectives = GetNumQuestLeaderBoards(questLogIndex);
		    for i = 1, numObjectives do
		    	-- https://wowpedia.fandom.com/wiki/API_GetQuestLogLeaderBoard
		    	local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i, questLogIndex);
                if objectiveType ~= "log" then
		    	    local objectiveName, numFulfilled, numRequired = parseQuestObjective(description)
                    objectiveName = normalizeObjectiveName(objectiveName)
                    -- GetQuestLogLeaderBoard randomly returns incorrect objective information.
                    -- Parsing the UI_INFO_MESSAGE event for the correct numFulfilled value seems like the solution.
                    local fulfilled = getObjectiveProgressCache(objectiveName)
                    if fulfilled then
                        if not isCompleted then
                            -- GetQuestLogLeaderBoard can lag behind UI_INFO_MESSAGE.
                            -- Never let cached fallback reduce an already newer value.
                            local questLogFulfilled = tonumber(numFulfilled)
                            if questLogFulfilled then
                                numFulfilled = math.max(questLogFulfilled, fulfilled)
                                if questLogFulfilled >= fulfilled then
                                    questObjectivesCache[objectiveName] = nil
                                end
                            else
                                numFulfilled = fulfilled
                            end
                        else
                            questObjectivesCache[objectiveName] = nil
                        end
                    end

		    	    table.insert(questObjectives, objectiveIndex, {
		    	    	text = description,
		    	    	type = objectiveType,
		    	    	finished = isCompleted and true or false,
		    	    	numFulfilled = tonumber(numFulfilled) or (isCompleted and 1 or 0),
		    	    	numRequired = tonumber(numRequired) or 1,
		    	    })
					-- "event" should always be last?
					objectiveIndex = objectiveIndex + (objectiveType ~= "event" and 1 or 0)
                end
		    end
        end
		return questObjectives -- can be empty for quests without objectives
	end,
    GetMaxNumQuestsCanAccept = function()
        return MAX_QUESTLOG_QUESTS
    end,
    IsOnQuest = function(questId)
        return QuestieCompat.GetQuestLogIndexByID(questId) and true or false
    end,
}

-- Can't find anything about this function.
-- Apparently, it returns true when quest data is ready to be queried.
function QuestieCompat.HaveQuestData(questID)
	return true
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogTitle?oldid=2214753
-- Returns information about a quest in your quest log.
-- Patch 6.0.2 (2014-10-14): Removed returns 'questTag'.
function QuestieCompat.GetQuestLogTitle(questLogIndex)
    local questTitle, level, _, suggestedGroup, isHeader, isCollapsed,
        isComplete, isDaily, questID = GetQuestLogTitle(questLogIndex);
    local questTag = select(2, QuestieCompat.GetQuestTagInfo(questID))

    if (isComplete == nil) then
        local numObjectives = GetNumQuestLeaderBoards(questLogIndex);
        local requiredMoney = GetQuestLogRequiredMoney(questLogIndex);
        isComplete = (numObjectives == 0 and GetMoney() >= requiredMoney) and 1 or nil
    end
    return questTitle, level, questTag, isHeader, isCollapsed, isComplete, isDaily and 2 or 1, questID
end

local MAX_QUEST_LOG_INDEX = 75
-- Returns the current quest log index of a quest by its ID.
-- https://wowpedia.fandom.com/wiki/API_GetQuestLogIndexByID
function QuestieCompat.GetQuestLogIndexByID(questId)
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if (not title) then
            break -- We exceeded the valid quest log entries
        end
        if (not isHeader) then
            if (questId == id) then
                return questLogIndex
            end
        end
    end
end

function QuestieCompat.GetQuestIDFromLogIndex(questLogIndex)
    return select(9, GetQuestLogTitle(questLogIndex))
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLink
-- Returns a QuestLink for a quest.
-- Between patches 6.2 and 7.3.2 argument was changed to take a QuestID instead of a quest log index.
function QuestieCompat.GetQuestLink(questId)
    local questLogIndex = QuestieCompat.GetQuestLogIndexByID(questId)
    return questLogIndex and GetQuestLink(questLogIndex)
end

function QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
	local questLink = QuestieCompat.GetQuestLink(questId)
	if questLink then
		return questLink
	end

	local numericQuestId = tonumber(questId)
	if numericQuestId and questName then
		local numericQuestLevel = tonumber(questLevel) or -1
		return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", numericQuestId, numericQuestLevel, questName)
	end

	return "[["..tostring(questLevel).."] "..tostring(questName).." ("..tostring(questId)..")]"
end

function QuestieCompat:GetQuestLinkStringById(questId)
    local questName = QuestieDB.QueryQuestSingle(questId, "name");
    local questLevel, _ = QuestieLib.GetTbcLevel(questId);
    return QuestieCompat:GetQuestLinkString(questLevel, questName, questId)
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogRewardMoney
-- Returns the amount of money rewarded for a quest.
function QuestieCompat.GetQuestLogRewardMoney(questID)
    local rewardMoney = QuestieCompat.RewardMoney[questID] or 0
	local rewardMoneyDifficulty = QuestieCompat.RewardMoneyDifficulty[questID] or 0

    if rewardMoney < 0 then -- required money
        return rewardMoney
    end

    local playerLevel = QuestiePlayer.GetPlayerLevel()
    if playerLevel > 0 and rewardMoneyDifficulty > 0 then
        rewardMoney = QuestieCompat.QuestMoneyReward[playerLevel][rewardMoneyDifficulty]
    end

    -- https://wowpedia.fandom.com/wiki/Quest?oldid=1035002 Formula is XP gained * 6c
    if QuestiePlayer.IsMaxLevel() then
        local xpReward = QuestXP:GetQuestLogRewardXP(questID, true)
        if xpReward > 0 then
            rewardMoney = rewardMoney + xpReward*6
        end
    end

    return rewardMoney
end

function QuestieCompat.CalculateNextResetTime()
    local currentTime, currentDate = QuestieCompat.GetServerTime()
    local timeUntilReset = GetQuestResetTime()

    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] GetQuestResetTime: ", timeUntilReset)
    -- -10 because reset isn't instant, avoids error unless genuine
    if timeUntilReset <= -10 then
        Questie:Error("GetQuestResetTime() returns an invalid value: "..timeUntilReset..". Please report on Github!")
        return
    end
    Questie.db.profile.dailyResetTime = Questie.db.profile.dailyResetTime or (currentTime + timeUntilReset)
    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] Next daily rest time: ", date("%m/%d/%y %H:%M:%S", Questie.db.profile.dailyResetTime))

    Questie.db.profile.weeklyResetHour = Questie.db.profile.weeklyResetHour or tonumber(date("%H", Questie.db.profile.dailyResetTime+300))
    local dayOffset = (Questie.db.profile.weeklyResetDay - currentDate.weekday + 7) % 7
    if dayOffset == 0 and currentDate.hour >= Questie.db.profile.weeklyResetHour then
        dayOffset = 7
    end

    Questie.db.profile.weeklyResetTime = Questie.db.profile.weeklyResetTime or time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day + dayOffset,
        hour = Questie.db.profile.weeklyResetHour,
    })
    Questie:Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] Next weekly rest time: ", date("%m/%d/%y %H:%M:%S", Questie.db.profile.weeklyResetTime))
end

function QuestieCompat.ResetDailyQuests(reset)
    local currentTime = QuestieCompat.GetServerTime()

    if reset or (currentTime > Questie.db.profile.dailyResetTime) then
        for questId in pairs(Questie.db.char.daily) do
            Questie.db.char.daily[questId] = nil
            Questie.db.char.complete[questId] = nil
        end
        Questie.db.profile.dailyResetTime = nil
        QuestieCompat.CalculateNextResetTime()
        if Questie.started then
            AvailableQuests.CalculateAndDrawAll()
        end
    end
end

local weeklyResetTimer
function QuestieCompat.ResetWeeklyQuests()
    local currentTime = QuestieCompat.GetServerTime()
    local timeUntilReset = Questie.db.profile.weeklyResetTime - currentTime

    if timeUntilReset < 1800 then
        if weeklyResetTimer then
            weeklyResetTimer = weeklyResetTimer:Cancel()
        end

        weeklyResetTimer = weeklyResetTimer or QuestieCompat.C_Timer.After(timeUntilReset, function()
            for questId in pairs(Questie.db.char.weekly) do
                Questie.db.char.weekly[questId] = nil
                Questie.db.char.complete[questId] = nil
            end
            Questie.db.profile.weeklyResetTime = nil
            QuestieCompat.CalculateNextResetTime()
            if Questie.started then
                AvailableQuests.CalculateAndDrawAll()
            end
        end)

        return true
    end
end

function QuestieCompat.SetQuestComplete(questId)
    if (not QuestieDB.IsRepeatable(questId)) then
        Questie.db.char.complete[questId] = true
    end

    if Questie.db.profile.resetDailyQuests then
        if QuestieDB.IsDailyQuest(questId) then
            Questie.db.char.daily[questId] = true
            Questie.db.char.complete[questId] = true
        elseif QuestieDB.IsWeeklyQuest(questId) then
            Questie.db.char.weekly[questId] = true
            Questie.db.char.complete[questId] = true
        end
    end
end

-- Returns a list of quests the character has completed in its lifetime.
-- https://wowpedia.fandom.com/wiki/API_GetQuestsCompleted
function QuestieCompat.GetQuestsCompleted()
    if not Questie.db.char.complete then
        Questie.db.char.complete = {}
    end

    QueryQuestsCompleted()
    return Questie.db.char.complete
end

-- Fires when the data requested by QueryQuestsCompleted() is available.
-- https://wowpedia.fandom.com/wiki/QUEST_QUERY_COMPLETE
function QuestieCompat:QUEST_QUERY_COMPLETE(event)
    GetQuestsCompleted(Questie.db.char.complete)

    for questId in pairs(Questie.db.char.complete) do
        if QuestieDB.IsRepeatable(questId) then
            Questie.db.char.complete[questId] = nil
        end
    end

    if Questie.db.profile.resetDailyQuests then
        QuestieCompat.CalculateNextResetTime()
        QuestieCompat.ResetDailyQuests()
        QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.daily)

        if Questie.IsWotlk and QuestiePlayer.GetPlayerLevel() >= 78 then
            if (not QuestieCompat.ResetWeeklyQuests()) and (Questie.db.profile.weeklyResetDay == CalendarGetDate()) then
                weeklyResetTimer = weeklyResetTimer or QuestieCompat.C_Timer.NewTicker(1800, QuestieCompat.ResetWeeklyQuests)
            end
            QuestieCompat.Merge(Questie.db.char.complete, Questie.db.char.weekly)
        end
    end
end

-- https://wowpedia.fandom.com/wiki/API_IsQuestFlaggedCompleted
-- Determine if a quest has been completed.
function QuestieCompat.IsQuestFlaggedCompleted(questID)
	return Questie.db.char.complete[questID] or false
end

---Returns the available quests at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetGossipAvailableQuests
function QuestieCompat.GetAvailableQuests()
	local availableQuests = {GetGossipAvailableQuests()}
	local numAvailable = GetNumGossipAvailableQuests()
	for i = 1, numAvailable do
		local index = (i - 1) * 5
		availableQuests[index + 3] = availableQuests[index + 3] and true or false
		availableQuests[index + 4] = availableQuests[index + 4] and 2 or 1
		availableQuests[index + 5] = availableQuests[index + 5] and true or false
	end
    for i = 1, numAvailable do
		local index = (i - 1) * 7
		table.insert(availableQuests, index + 6, false)
		table.insert(availableQuests, index + 7, false)
	end
	return unpack(availableQuests)
end

-- Returns the quests which can be turned in at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetGossipActiveQuests
function QuestieCompat.GetActiveQuests()
	local activeQuests = {GetGossipActiveQuests()}
	local numActive = GetNumGossipActiveQuests()
	for i = 1, numActive do
		local index = (i - 1) * 4
		activeQuests[index + 3] = activeQuests[index + 3] and true or false
		activeQuests[index + 4] = activeQuests[index + 4] and true or false
	end
    for i = 1, numActive do
		local index = (i - 1) * 6
		table.insert(activeQuests, index + 5, false)
		table.insert(activeQuests, index + 6, false)
	end
	return unpack(activeQuests)
end

local questTagToName = {
	[1] = "Group",
	[41] = "PvP",
	[62] = "Raid",
	[81] = "Dungeon",
	[82] = "World Event",
	[83] = "Legendary",
	[84] = "Escort",
	[85] = "Heroic",
}

-- Retrieves tag information about the quest.
-- https://wowpedia.fandom.com/wiki/API_GetQuestTagInfo
function QuestieCompat.GetQuestTagInfo(questId)
    if not questId then return nil, nil end

    local tagId = QuestieCompat.QuestTag[questId]
	if tagId then
		return tagId, questTagToName[tagId]
	end
end

-- Returns the ID of the displayed quest at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetQuestID
function QuestieCompat.GetQuestID(questStarter, title)
    local title = title or GetTitleText()
    local guid = QuestieCompat.UnitGUID("npc")

	return QuestieDB.GetQuestIDFromName(title, guid, questStarter)
end

function QuestieCompat.GetQuestIDFromName(questTitle)
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if (not title) then
            break -- We exceeded the valid quest log entries
        end
        if (not isHeader) then
            if (questTitle == title) then
                return id
            end
        end
    end
end

-- https://wowwiki-archive.fandom.com/wiki/API_UnitGUID?oldid=2368080
local GUIDType = {
    [0]="Player",
    [1]="GameObject",
    [3]="Creature",
    [4]="Pet",
    [5]="Vehicle"
}

-- Returns the GUID of the unit.
-- https://wowpedia.fandom.com/wiki/GUID
-- Patch 6.0.2 (2014-10-14): Changed to a new format
function QuestieCompat.UnitGUID(unit)
    local guid = UnitGUID(unit)
    if guid then
        local type = tonumber(guid:sub(5,5), 16) % 8
        if type and (type == 1 or type == 3 or type == 5) then
            local id = tonumber(guid:sub(6, 12), 16)
            -- Creature-0-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
            return string.format("%s-0-4170-0-41-%d-00000F4B37", GUIDType[type], id)
        end
    end
end

function QuestieCompat.GetMaxPlayerLevel()
    return (Questie.IsWotlk and 80) or (Questie.IsTBC and 70) or (Questie.IsClassic and 60)
end

-- https://wowpedia.fandom.com/wiki/API_UnitAura?oldid=2681338
-- Returns the buffs/debuffs for the unit.
-- an alias for UnitAura(unit, index, "HELPFUL"), returning only buffs.
-- Patch 8.0.1 (2018-07-17): Removed 'rank' return value.
function QuestieCompat.UnitBuff(unit, index)
    local name, rank, icon, count, debuffType, duration, expirationTime,
        unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff(unit, index)
    return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
end

-- Returns the race of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitRace
function QuestieCompat.UnitRace(unit)
    local raceName, raceFile = UnitRace(unit)
    return raceName, raceFile, QuestieCompat.ChrRaces[raceFile]
end

-- Returns the class of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitClass
-- Patch 5.0.4 (2012-08-28): Added classId return value.
function QuestieCompat.UnitClass(unit)
    local className, classFile = UnitClass(unit)
    return className, classFile, QuestieCompat.ChrClasses[classFile]
end

-- Returns info for a faction.
-- https://wowpedia.fandom.com/wiki/API_GetFactionInfo
-- Patch 5.0.4 (2012-08-28): Added new return value: factionID
-- TODO: localize factions name(https://www.curseforge.com/wow/addons/libbabble-faction-3-0)
function QuestieCompat.GetFactionInfo(factionIndex)
    local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

    return name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, QuestieCompat.FactionId[name:trim()]
end

-- Returns true if the unit is a member of your party
-- https://wowpedia.fandom.com/wiki/API_UnitInParty
-- As of 2.0.3, UnitInParty("player") always returns 1, even when you are not in a party.
function QuestieCompat.UnitInParty(unit)
    if unit == "player" then
        return QuestieCompat.IsInGroup()
    end
    return UnitInParty(unit)
end

-- Returns true if the player is in a group.
-- https://wowpedia.fandom.com/wiki/API_IsInGroup
function QuestieCompat.IsInGroup(groupType)
    if groupType then return false end
    return UnitInParty("player") and GetNumPartyMembers() > 0
end

-- Returns true if the player is in a raid.
-- https://wowpedia.fandom.com/wiki/API_IsInRaid
function QuestieCompat.IsInRaid(groupType)
    if groupType then return false end
    return UnitInRaid("player") and GetNumRaidMembers() > 0
end

-- Returns names of characters in your home (non-instance) party.
-- https://wowpedia.fandom.com/wiki/API_GetHomePartyInfo
function QuestieCompat.GetHomePartyInfo(homePlayers)
	if QuestieCompat.UnitInParty("player") then
		homePlayers = homePlayers or {}
		for i=1, MAX_PARTY_MEMBERS do
			if GetPartyMember(i) then
				table.insert(homePlayers, UnitName("party"..i))
			end
		end
		return homePlayers
	end
end

-- Gets a list of the auction house item classes.
-- https://wowpedia.fandom.com/wiki/API_GetAuctionItemClasses?oldid=1835520
local itemClass = {GetAuctionItemClasses()}
for classId, className in ipairs(itemClass) do
    itemClass[className] = classId
    itemClass[classId] = nil
end

-- Returns info for an item.
-- https://wowpedia.fandom.com/wiki/API_GetItemInfo?oldid=2376031
-- Patch 7.0.3 (2016-07-19): Added classID, subclassID returns.
function QuestieCompat.GetItemInfo(item)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(item)

    return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice, itemClass[itemType]
end

-- Returns info for an item in a container slot.
-- https://wowpedia.fandom.com/wiki/API_GetContainerItemInfo
function QuestieCompat.GetContainerItemInfo(bagID, slot)
	local iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink = GetContainerItemInfo(bagID, slot)
    if hyperlink then
	    local itemID = string.match(hyperlink, "(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	    -- GetContainerItemInfo does not return a quality value for all items.  If it does not, it returns -1
	    if quality and quality < 0 then
	    	quality = (select(3, GetItemInfo(hyperlink)))
	    end

	    return iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, false, false, tonumber(itemID), false
    end
end

-- https://wowpedia.fandom.com/wiki/API_IsSpellKnown
QuestieCompat.IsSpellKnownOrOverridesKnown = IsSpellKnown
QuestieCompat.IsPlayerSpell = IsSpellKnown

local LARGE_NUMBER_SEPERATOR = ",";
function QuestieCompat.FormatLargeNumber(amount)
	amount = tostring(amount);
	local newDisplay = "";
	local strlen = amount:len();
	--Add each thing behind a comma
	for i=4, strlen, 3 do
		newDisplay = LARGE_NUMBER_SEPERATOR..amount:sub(-(i - 1), -(i - 3))..newDisplay;
	end
	--Add everything before the first comma
	newDisplay = amount:sub(1, (strlen % 3 == 0) and 3 or (strlen % 3))..newDisplay;
	return newDisplay;
end

local function Round(value)
	if value < 0.0 then
		return math.ceil(value - .5);
	end
	return math.floor(value + .5);
end
QuestieCompat.Round = Round

local function GenerateHexColor(r, g, b, a)
	return ("ff%.2x%.2x%.2x"):format(Round(r * 255), Round(g * 255), Round(b * 255), Round((a or 1) * 255));
end

-- Returns the color value associated with a given class.
function QuestieCompat.GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename];
	if color then
		return color.r, color.g, color.b, GenerateHexColor(color.r, color.g, color.b)
	end
	return 1, 1, 1, "ffffffff";
end

local function IsWorldMapFrameDescendant(frame)
    local current = frame

    while current do
        if current == WorldMapButton or current == WorldMapFrame then
            return true
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

-- handle tooltip based on the parent frame
function QuestieCompat.SetupTooltip(frame, OnHide)
    if IsWorldMapFrameDescendant(frame) then
        WorldMapPOIFrame.allowBlobTooltip = OnHide and true or false
        QuestieCompat.Tooltip = WorldMapTooltip
    else
        QuestieCompat.Tooltip = GameTooltip
    end
    return QuestieCompat.Tooltip
end

local wrappedLines = {}
-- tooltip word wrapping looks fine the way it is, leave it for now
function QuestieCompat.TextWrap(self, line, prefix, combineTrailing, desiredWidth)
    QuestieCompat.Tooltip:AddLine(line, 0.86, 0.86, 0.86, 1);
    return wrappedLines
end

local unboundedFS = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
unboundedFS:SetPoint("TOPLEFT", 0, 0)
unboundedFS:Hide()

-- The minimum width necessary to contain the entire text without truncation
-- https://wowpedia.fandom.com/wiki/API_FontString_GetStringWidth
function QuestieCompat.GetUnboundedStringWidth(self)
    unboundedFS:SetWidth(0)
    unboundedFS:SetFont(self:GetFont())
    unboundedFS:SetText(self:GetText())

    return unboundedFS:GetStringWidth()
end

-- Number of lines of wrapped text
-- https://wowpedia.fandom.com/wiki/API_FontString_GetNumLines
function QuestieCompat.GetNumLines(self)
    local fontName, fontHeight, fontFlags = self:GetFont()
    unboundedFS:SetWidth(self:GetWidth())
    unboundedFS:SetFont(fontName, fontHeight, fontFlags)
    unboundedFS:SetText(self:GetText())

	return math.ceil(unboundedFS:GetHeight()/fontHeight)
end

-- texture			- Texture
-- canvasFrame      - Canvas Frame (for anchoring)
-- startX,startY    - Coordinate of start of line
-- endX,endY		- Coordinate of end of line
-- lineWidth        - Width of line
-- relPoint			- Relative point on canvas to interpret coords (Default BOTTOMLEFT)
local function DrawLine(texture, canvasFrame, startX, startY, endX, endY, lineWidth, lineFactor, relPoint)
	if (not relPoint) then relPoint = "BOTTOMLEFT"; end
	lineFactor = lineFactor * .5;

	-- Determine dimensions and center point of line
	local dx,dy = endX - startX, endY - startY;
	local cx,cy = (startX + endX) / 2, (startY + endY) / 2;

	-- Normalize direction if necessary
	if (dx < 0) then
		dx,dy = -dx,-dy;
	end

	-- Calculate actual length of line
	local lineLength = sqrt((dx * dx) + (dy * dy));

	-- Quick escape if it'sin zero length
	if (lineLength == 0) then
        texture:ClearAllPoints();
		texture:SetTexCoord(0,0,0,0,0,0,0,0);
		texture:SetPoint("BOTTOMLEFT", canvasFrame, relPoint, cx,cy);
		texture:SetPoint("TOPRIGHT",   canvasFrame, relPoint, cx,cy);
		return;
	end

	-- Sin and Cosine of rotation, and combination (for later)
	local sin, cos = -dy / lineLength, dx / lineLength;
	local sinCos = sin * cos;

	-- Calculate bounding box size and texture coordinates
	local boundingWidth, boundingHeight, bottomLeftX, bottomLeftY, topLeftX, topLeftY, topRightX, topRightY, bottomRightX, bottomRightY;
	if (dy >= 0) then
		boundingWidth = ((lineLength * cos) - (lineWidth * sin)) * lineFactor;
		boundingHeight = ((lineWidth * cos) - (lineLength * sin)) * lineFactor;

		bottomLeftX = (lineWidth / lineLength) * sinCos;
		bottomLeftY = sin * sin;
		bottomRightY = (lineLength / lineWidth) * sinCos;
		bottomRightX = 1 - bottomLeftY;

		topLeftX = bottomLeftY;
		topLeftY = 1 - bottomRightY;
		topRightX = 1 - bottomLeftX;
		topRightY = bottomRightX;
	else
		boundingWidth = ((lineLength * cos) + (lineWidth * sin)) * lineFactor;
		boundingHeight = ((lineWidth * cos) + (lineLength * sin)) * lineFactor;

		bottomLeftX = sin * sin;
		bottomLeftY = -(lineLength / lineWidth) * sinCos;
		bottomRightX = 1 + (lineWidth / lineLength) * sinCos;
		bottomRightY = bottomLeftX;

		topLeftX = 1 - bottomRightX;
		topLeftY = 1 - bottomLeftX;
		topRightY = 1 - bottomLeftY;
		topRightX = topLeftY;
	end

	-- Set texture coordinates and anchors
	texture:ClearAllPoints();
	texture:SetTexCoord(topLeftX, topLeftY, bottomLeftX, bottomLeftY, topRightX, topRightY, bottomRightX, bottomRightY);
	texture:SetPoint("BOTTOMLEFT", canvasFrame, relPoint, cx - boundingWidth, cy - boundingHeight);
	texture:SetPoint("TOPRIGHT",   canvasFrame, relPoint, cx + boundingWidth, cy + boundingHeight);
end

-- Mix this into a Texture to be able to treat it like a line
local LineMixin = {};

function LineMixin:SetStartPoint(relPoint, x, y)
	self.startX, self.startY = x, y;
end

function LineMixin:SetEndPoint(relPoint, x, y)
	self.endX, self.endY = x, y;
end

function LineMixin:SetThickness(thickness)
	self.thickness = thickness;
end

function LineMixin:Draw()
	local parent = self:GetParent();
	local x, y = parent:GetLeft(), parent:GetBottom();

	self:ClearAllPoints();
	DrawLine(self, parent, self.startX - x, self.startY - y, self.endX - x, self.endY - y, self.thickness or 32, 1);
end

local function drawLineOnShow(self)
    local line = self.line
    DrawLine(line, self, line.startX, line.startY, line.endX, line.endY, line.thickness*15, 1.2, "TOPLEFT");
end

local stub_line = setmetatable({}, QuestieCompat.NOOP_MT)
-- https://wowpedia.fandom.com/wiki/API_Frame_CreateLine
function QuestieCompat.CreateLine(self)
    if self.line then return stub_line end -- stub lineBorder, as our line texture already has border

    local line = self:CreateTexture(nil, "OVERLAY")
    line:SetTexture(QuestieLib.AddonPath.."Compat\\Icons\\Waypoint-Line.blp")
    line.SetColorTexture = line.SetVertexColor

    for k,v in pairs(LineMixin) do
        line[k] = v
    end

    self:SetScript("OnShow", drawLineOnShow)

    return line
end

QuestieCompat.LibUIDropDownMenu = {
	Create_UIDropDownMenu = function(self, name, parent)
		return CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	end,
	EasyMenu = function(self, menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
	end,
	CloseDropDownMenus = function(self, level)
        CloseDropDownMenus(level)
    end,
}

QuestieCompat.KButtons = {
    Add = function(self, templateName, templateType)
        local button = CreateFrame("Button", "Questie_WorldMapButton", WorldMapFrame)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        button:SetPoint("TOPRIGHT", WorldMapButton, "TOPRIGHT", -4, -2);
        button:SetFrameLevel(99)
        button:SetSize(32, 32)
        button:RegisterForClicks("anyUp")
        button:SetScript("OnMouseDown", QuestieWorldMapButtonMixin.OnMouseDown)
        button:SetScript("OnEnter", QuestieWorldMapButtonMixin.OnEnter)
        button:SetScript("OnLeave", function(self)
            GameTooltip_Hide()
            local tooltip = QuestieCompat.SetupTooltip(self, true)
            if tooltip and tooltip ~= GameTooltip then
                tooltip:Hide()
            end
        end)

        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetSize(25, 25)
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        background:SetPoint("TOPLEFT", 2, -4)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetTexture(QuestieLib.AddonPath.."Icons\\complete.blp")
        icon:SetPoint("TOPLEFT", 6, -5)

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT")

        return button
    end,
}

--[[
    xpcall wrapper implementation
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, eh, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh or errorhandler)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", table.concat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

Dispatchers[0] = function(func, eh)
	return xpcall(func, eh or errorhandler)
end

function QuestieCompat.xpcall(func, eh, ...)
    if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, eh, ...)
	end
end

--[[
    It seems that the table size is capped in 3.3.5, with a maximum of 524,288 entries.
    For instance, this code triggers an error message: 'memory allocation error: block too big.

    local t = {}
	for i=1, 524289 do
		t[i] = true
	end

    Spliting the table into multiple subtables should do the trick.
]]

local stringchar = string.char
local MAX_TABLE_SIZE = 524288

function QuestieCompat._writeByte(self, val)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

	self._bin[subIndex] = self._bin[subIndex] or {}
	self._bin[subIndex][index] = stringchar(val)

    self._pointer = self._pointer + 1
end

function QuestieCompat._readByte(self)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

    self._pointer = self._pointer + 1

	return self._bin[subIndex][index]
end

function QuestieCompat.Save(self)
	local result = ""
	for i=1, #self._bin do
		result = result .. table.concat(self._bin[i])
	end
	return result
end

local _QuestieNameplate = QuestieNameplate.private
local npFrames = {}
local npActiveQuestNPCs = {}
local npBorderTexture = "Interface\\Tooltips\\Nameplate-Border"

local function isNamePlate(frame)
    if frame.UnitFrame  -- ElvUI
    or frame.extended   -- TidyPlates
    or frame.aloftData  -- Aloft
    or frame.kui  -- Kui_Nameplate
    then return true end

    local _, borderRegion = frame:GetRegions()
    if borderRegion and borderRegion:GetObjectType() == "Texture" then
        return borderRegion:GetTexture() == npBorderTexture
    end

    return false
end

local function scanWorldFrameChildren(frame, ...)
	if not frame then return end

	if not npFrames[frame] and isNamePlate(frame) then
        npFrames[frame] = select(7, frame:GetRegions())

        frame:HookScript("OnShow", QuestieCompat.NameplateCreated)
        frame:HookScript("OnHide", _QuestieNameplate.RemoveFrame)

        if frame:IsShown() then
		    QuestieCompat.NameplateCreated(frame)
        end
	end
	return scanWorldFrameChildren(...)
end

function QuestieCompat.NameplateCreated(frame)
    local name = npFrames[frame]:GetText()
    local key = npActiveQuestNPCs[name]
    if key then
        local icon = _QuestieNameplate.GetValidIcon(QuestieTooltips.lookupByKey[key])

        if icon then
            local f = _QuestieNameplate.GetFrame(frame)
            f.Icon:SetTexture(icon)
            f.lastIcon = icon -- this is used to prevent updating the texture when it's already what it needs to be
            f:Show()
        end
    end
end

function QuestieCompat.UpdateNameplate()
    for frame in pairs(npFrames) do
        local name = npFrames[frame]:GetText()
        local key = npActiveQuestNPCs[name]

        local icon = _QuestieNameplate.GetValidIcon(QuestieTooltips.lookupByKey[key])

        if icon then
            local f = _QuestieNameplate.GetFrame(frame)
            -- check if the texture needs to be changed
            if f.lastIcon ~= icon then
                f.lastIcon = icon
                f.Icon:SetTexture(icon)
            end
        else
            -- tooltip removed but we still have the frame active, remove it
            _QuestieNameplate.RemoveFrame(frame)
        end
    end
end

function QuestieCompat:QuestieTooltips_RegisterObjectiveTooltip(questId, key, objective)
    if key:find("m_") then
        local name = QuestieDB.QueryNPCSingle(tonumber(key:sub(3)), "name")
        npActiveQuestNPCs[name] = key
    end
end

local _EventHandler = QuestieEventHandler.private
local chatMessagePattern = {
    questInfo = {
        ERR_QUEST_OBJECTIVE_COMPLETE_S,
	    ERR_QUEST_UNKNOWN_COMPLETE,
	    ERR_QUEST_ADD_KILL_SII,
	    ERR_QUEST_ADD_FOUND_SII,
	    ERR_QUEST_ADD_ITEM_SII,
	    ERR_QUEST_ADD_PLAYER_KILL_SII,
	    ERR_QUEST_FAILED_S,
    },
    playerLoot = {
        LOOT_ITEM_CREATED_SELF,
        LOOT_ITEM_CREATED_SELF_MULTIPLE,
        LOOT_ITEM_PUSHED_SELF,
        LOOT_ITEM_PUSHED_SELF_MULTIPLE,
        LOOT_ITEM_SELF,
        LOOT_ITEM_SELF_MULTIPLE,
    }
}
local uiInfoObjectiveProgressPending = false
local uiInfoObjectiveSyncQueued = false
local uiInfoObjectiveLateSyncQueued = false

local function syncObjectiveProgressFromUiInfoMessage()
    local questEventHandlerPrivate = QuestEventHandler.private
    if questEventHandlerPrivate and questEventHandlerPrivate.UpdateAllQuests then
        questEventHandlerPrivate:UpdateAllQuests()
    end

    if QuestieTracker and QuestieTracker.Update then
        QuestieTracker:Update()
    end
end

local function queueObjectiveProgressSync(delay)
    if uiInfoObjectiveSyncQueued then
        return
    end

    uiInfoObjectiveSyncQueued = true
    QuestieCompat.C_Timer.After(delay or 0, function()
        uiInfoObjectiveSyncQueued = false
        if not uiInfoObjectiveProgressPending then
            return
        end

        uiInfoObjectiveProgressPending = false
        syncObjectiveProgressFromUiInfoMessage()
    end)
end

local function queueLateObjectiveProgressSync()
    if uiInfoObjectiveLateSyncQueued then
        return
    end

    uiInfoObjectiveLateSyncQueued = true
    QuestieCompat.C_Timer.After(0.35, function()
        uiInfoObjectiveLateSyncQueued = false
        syncObjectiveProgressFromUiInfoMessage()
    end)
end

function QuestieCompat.LOOT_SLOT_CLEARED(event)
    if uiInfoObjectiveProgressPending then
        queueObjectiveProgressSync(0.10)
        queueLateObjectiveProgressSync()
    end
end

function QuestieCompat.LOOT_CLOSED(event)
    if uiInfoObjectiveProgressPending then
        queueObjectiveProgressSync(0.20)
        queueLateObjectiveProgressSync()
    end
end

-- parse chat message for quest related info
function QuestieCompat.UiInfoMessage(event, ...)
    local arg1, arg2 = ...
    local message
    if type(arg1) == "string" then
        message = arg1
    elseif type(arg2) == "string" then
        message = arg2
    else
        return
    end

    local hasObjectiveProgressUpdate = false
    local objectiveName, numFulfilled = parseQuestObjective(message)
    objectiveName = normalizeObjectiveName(objectiveName)

    -- Parse and cache objective progress from the message itself, independent of pattern matching.
    if objectiveName and numFulfilled then
        setObjectiveProgressCache(objectiveName, numFulfilled)
        hasObjectiveProgressUpdate = true
        uiInfoObjectiveProgressPending = true
        applyObjectiveProgressToQuestieCache(objectiveName, numFulfilled)
        MinimapIcon:UpdateText(message)
    else
        for _, pattern in pairs(chatMessagePattern.questInfo) do
            if string.find(message, pattern) then
                MinimapIcon:UpdateText(message)
                break
            end
        end
    end

    if hasObjectiveProgressUpdate then
        -- Keep a generic delayed sync for non-loot objective progress updates.
        queueObjectiveProgressSync(0.05)
        queueLateObjectiveProgressSync()
    end
end

-- parse chat message for player looting an item
local playerName = UnitName("player")
local emptyName = ""
function QuestieCompat.ChatMessageLoot(message)
    for _, pattern in pairs(chatMessagePattern.playerLoot) do
        if string.find(message, pattern) then
            return playerName
        end
    end
    return emptyName
end

-- handle remote questlog of the party/raid
function QuestieCompat.GroupRosterUpdate(event)
    local currentMembers = QuestieCompat.IsInRaid() and GetNumRaidMembers() or GetNumPartyMembers()
    -- Only want to do logic when number increases, not decreases.
    if QuestiePlayer.numberOfGroupMembers < currentMembers then
        if QuestiePlayer.numberOfGroupMembers == 0 then
            _EventHandler:GroupJoined()
        end
        -- Tell comms to send information to members.
        --Questie:SendMessage("QC_ID_BROADCAST_FULL_QUESTLIST")
        QuestiePlayer.numberOfGroupMembers = currentMembers
    else
        if currentMembers == 0 then
            _EventHandler:GroupLeft()
        end
        -- We do however always want the local to be the current number to allow up and down.
        QuestiePlayer.numberOfGroupMembers = currentMembers
    end
end

function QuestieCompat.QuestieEventHandler_RegisterLateEvents()
    -- In fullscreen mode, WorldMap intercepts keyboard input,
    -- preventing the MODIFIER_STATE_CHANGED event
    if WorldMapFrame:GetScript("OnKeyDown") then
        local modifierStateChanged
        WorldMapFrame:HookScript("OnKeyDown", function(self, key)
            if IsModifierKeyDown() then
                _EventHandler:ModifierStateChanged(key, 1)
                modifierStateChanged = true
            end
        end)
        WorldMapFrame:HookScript("OnKeyUp", function(self, key)
            if modifierStateChanged then
                _EventHandler:ModifierStateChanged(key, 0)
                modifierStateChanged = nil
            end
        end)
    end

    Questie:UnregisterEvent("MAP_EXPLORATION_UPDATED") -- https://wowpedia.fandom.com/wiki/MAP_EXPLORATION_UPDATED
    Questie:UnregisterEvent("NEW_RECIPE_LEARNED")

    -- Party join event for QuestieComms, Use bucket to hinder this from spamming (Ex someone using a raid invite addon etc)
    Questie:UnregisterEvent("GROUP_ROSTER_UPDATE") -- https://wowpedia.fandom.com/wiki/GROUP_ROSTER_UPDATE
    Questie:UnregisterEvent("GROUP_JOINED") -- https://wowpedia.fandom.com/wiki/GROUP_JOINED
    Questie:UnregisterEvent("GROUP_LEFT") -- https://wowpedia.fandom.com/wiki/GROUP_LEFT
    Questie:RegisterEvent("PARTY_MEMBERS_CHANGED", QuestieCompat.GroupRosterUpdate)
    Questie:RegisterBucketEvent("RAID_ROSTER_UPDATE", 1, QuestieCompat.GroupRosterUpdate)

    -- Nameplate / Target Frame Objective Events
    Questie:UnregisterEvent("NAME_PLATE_UNIT_ADDED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_ADDED
    Questie:UnregisterEvent("NAME_PLATE_UNIT_REMOVED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_REMOVED

    -- Use loot events as additional sync points for tracker refreshes.
    Questie:RegisterEvent("LOOT_SLOT_CLEARED", QuestieCompat.LOOT_SLOT_CLEARED)
    Questie:RegisterEvent("LOOT_CLOSED", QuestieCompat.LOOT_CLOSED)

    if Questie.db.profile.nameplateEnabled then
        QuestieNameplate.UpdateNameplate = QuestieCompat.UpdateNameplate
        hooksecurefunc(QuestieQuest, "GetAllQuestIds", QuestieCompat.UpdateNameplate)
        hooksecurefunc(QuestieTooltips, "RegisterObjectiveTooltip", QuestieCompat.QuestieTooltips_RegisterObjectiveTooltip)

        local lastNumChildren
        QuestieCompat.C_Timer.NewTicker(0.1, function()
            local numChildren = WorldFrame:GetNumChildren()
            if numChildren ~= lastNumChildren then
                lastNumChildren = numChildren
                scanWorldFrameChildren(WorldFrame:GetChildren())
            end
        end)
    end
end

local _QuestEventHandler = QuestEventHandler.private
local QUEST_COMPLETE_MSG = string.gsub(ERR_QUEST_COMPLETE_S, "(%%s)", "(.+)")
local completeQuestCache = {}

local DAILY_QUESTS_MSG = DAILY_QUESTS_REMAINING:gsub("%%d", "(%%d+)"):gsub("|4(.-)$", "")

function QuestieCompat:CHAT_MSG_SYSTEM(event, message)
    local questName = message:match(QUEST_COMPLETE_MSG)
    local questId = completeQuestCache[questName]
    if questId then
        _QuestEventHandler:QuestTurnedIn(questId)
        _QuestEventHandler:QuestRemoved(questId)
        completeQuestCache[questName] = nil
    end

    if Questie.db.profile.resetDailyQuests then
        local dailyQuestCount = tonumber(message:match(DAILY_QUESTS_MSG))
        if dailyQuestCount and (dailyQuestCount == GetMaxDailyQuests()) then
            QuestieCompat.C_Timer.After(1, function()
                QuestieCompat.ResetDailyQuests(true)
            end)
        end
    end
end

function QuestieCompat.QuestEventHandler_RegisterEvents()
    QuestieCompat.frame:RegisterEvent("QUEST_QUERY_COMPLETE")
    QuestieCompat.frame:RegisterEvent("CHAT_MSG_SYSTEM")

    -- https://wowpedia.fandom.com/wiki/PLAYER_INTERACTION_MANAGER_FRAME_HIDE
    QuestieQuestEventFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    for _, event in pairs({
        "TRADE_CLOSED",
        "MERCHANT_CLOSED",
        "BANKFRAME_CLOSED",
        "GUILDBANKFRAME_CLOSED",
        "VENDOR_CLOSED",
        "MAIL_CLOSED",
        "AUCTION_HOUSE_CLOSED",
    }) do
        QuestieCompat.frame:RegisterEvent(event)
        QuestieCompat[event] = _QuestEventHandler.QuestRelatedFrameClosed
    end

    -- https://wowpedia.fandom.com/wiki/QUEST_TURNED_IN
    QuestieQuestEventFrame:UnregisterEvent("QUEST_TURNED_IN")
    hooksecurefunc("GetQuestReward", function(itemChoice)
        local questTitle = GetTitleText()
        local questId = QuestieCompat.GetQuestIDFromName(questTitle)
        if questId and questId > 0 then
            completeQuestCache[questTitle] = questId
        end
    end)

    hooksecurefunc("SetAbandonQuest", function()
        QuestieCompat.abandonQuestID = select(9, GetQuestLogTitle(GetQuestLogSelection()))
    end)

    --https://wowpedia.fandom.com/wiki/QUEST_REMOVED
    QuestieQuestEventFrame:UnregisterEvent("QUEST_REMOVED")
    hooksecurefunc("AbandonQuest", function()
        local questId = QuestieCompat.abandonQuestID or select(9, GetQuestLogTitle(GetQuestLogSelection()))
        if questId and questId > 0 then
            _QuestEventHandler:QuestRemoved(questId, true)
        end
        QuestieCompat.abandonQuestID = nil
    end)
end

function QuestieCompat.QuestieTracker_Initialize(trackerQuestFrame)
    -- TrackerHeaderFrame.Initialize
    Questie_HeaderFrame.trackedQuests.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
    -- TrackerQuestFrame.Initialize
    trackerQuestFrame.ScrollFrame.scrollBarHideable = true
    trackerQuestFrame.ScrollBar:ClearAllPoints()
    trackerQuestFrame.ScrollBar:SetPoint("TOPRIGHT", trackerQuestFrame.ScrollUpButton, "BOTTOMRIGHT", -1, 4)
    trackerQuestFrame.ScrollBar:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollDownButton, "TOPRIGHT", -1, -4)
    trackerQuestFrame.ScrollDownButton:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollFrame, "BOTTOMRIGHT", -4, 12)
    trackerQuestFrame.ScrollBg:SetTexture(0, 0, 0, 0.35)
    trackerQuestFrame.ScrollBg:Show()
    trackerQuestFrame.ScrollBar.Show = function() end
    -- TrackerLinePool.Initialize
    for i = 1, 250 do
        local line = _G["linePool" .. i]
        line.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
        line.label.GetWrappedWidth = line.label.GetWidth
        line.label.GetNumLines = QuestieCompat.GetNumLines
    end
end

-- prevents the override of existing global variables with the same name(e.g., WorldMapButton)
function QuestieCompat.PopulateGlobals(self)
    for name, module in pairs(QuestieLoader._modules) do
        if not _G[name] then
            _G[name] = module
        end
    end
end

-- change sound files extension from .ogg to .wav
function QuestieCompat.GetSelectedSoundFile(typeSelected)
    return QuestieCompat.orig_GetSelectedSoundFile(typeSelected):gsub("[^.]+$", "wav")
end

QuestieCompat.isReloadingUi = false
function QuestieCompat.OnReloadUi(command)
	command = command or "reloadui"
	if (command == "reloadui") then
		Questie.db.profile.isInitialLogin = false
		QuestieCompat.isReloadingUi = true
	end
end

-- disable builtin quest progress tooltips, re-enable on logout
function QuestieCompat:ToggleQuestTrackingTooltips(event)
    local value = tostring(event:find("LOGOUT") and 1 or 0)
    SetCVar("showQuestTrackingTooltips", value)
end
QuestieCompat.PLAYER_LOGIN = QuestieCompat.ToggleQuestTrackingTooltips

function QuestieCompat:PLAYER_LOGOUT(event)
	if not QuestieCompat.isReloadingUi then
		QuestieCompat:ToggleQuestTrackingTooltips(event)
		
		Questie.db.profile.isInitialLogin = true
	end
end

local townsfolk_texturemap = {
    ["Ammo"] = "Interface\\Icons\\inv_ammo_arrow_02",
    ["Bags"] = "Interface\\Icons\\inv_misc_bag_09",
    ["Potions"] = "Interface\\Icons\\inv_potion_51",
    ["Trade Goods"] ="Interface\\Icons\\inv_fabric_wool_02",
    ["Drink"] = "Interface\\Icons\\inv_potion_01",
    ["Food"] = "Interface\\Icons\\inv_misc_food_11",
    ["Pet Food"] = "Interface\\Icons\\ability_hunter_beasttraining",
    ["Spirit Healer"] = "Interface\\Addons\\"..QuestieCompat.addonName.."\\Compat\\Icons\\Raid-Icon-Rez.blp",
    ["Portal Trainer"] = "Interface\\Addons\\"..QuestieCompat.addonName.."\\Compat\\Icons\\Vehicle-AllianceMagePortal.blp",
}

StaticPopupDialogs["QUESTIE_RELOAD"] = {
    text = "Changes you have made require a UI reload",
    button1 = 'Reload UI',
    button2 = CANCEL,
    OnAccept = function()
        ReloadUI()
    end,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function QuestieCompat.QuestieOptions_Initialize()
    QuestieCompat.orig_QuestieOptions_Initialize()

    local optionsTable = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("Questie", "dialog", "MyLib-1.0")

    -- revert instant quest text to old cvar
    optionsTable.args.general_tab.args.interface_options_group.args.instantQuest.get = function()
        return GetCVar("questFadingDisable") == '1' and true or false
    end
    optionsTable.args.general_tab.args.interface_options_group.args.instantQuest.set = function(info, value)
        QUEST_FADING_DISABLE = tostring(value and 1 or 0)
        SetCVar("questFadingDisable", tostring(value and 1 or 0))
    end

    optionsTable.args.nameplate_tab.args.nameplate_options_group.args.nameplateEnabled.set = function (info, value)
        QuestieOptions:SetProfileValue(info, value)
        StaticPopup_Show("QUESTIE_RELOAD")
    end

    -- disable settings for not implemented functionality
    Questie.db.profile.hideUnexploredMapIcons = false
    optionsTable.args.icons_tab.args.map_settings_group.args.hideUnexploredMapIconsToggle.disabled = true

    -- 3.3.5 section
    optionsTable.args.advanced_tab.args.compat_header = {
        type = "header",
        order = 6,
        name = "3.3.5 Compatibility Settings",
    }
	
	optionsTable.args.advanced_tab.args.initDelay = {
        type = "range",
        order = 6.1,
        name = "Init rate delay",
        desc = "Init rate delay",
        width = "full",
        min = 0.1,
        max = 1,
        step = 0.01,
        hidden = function() return not Questie.db.profile.debugEnabled; end,
        get = function(info) return QuestieOptions:GetProfileValue(info)*10; end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value/10)
        end,
    }

    optionsTable.args.advanced_tab.args.useWotlkMapData = {
        type = "toggle",
        order = 6.2,
        name = "Use WotLK map data",
        desc = "Use WotLK map data",
        width = 1.65,
        disabled = function() return QuestieCompat.WOW_PROJECT_ID == QuestieCompat.WOW_PROJECT_WRATH_CLASSIC end,
        get = function (info) return QuestieOptions:GetProfileValue(info); end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }
	
	optionsTable.args.advanced_tab.args.useQuestieLinks = {
        type = "toggle",
        order = 6.3,
        name = "Use Questie Links",
        desc = "Use Questie Links",
        width = 1.65,
        get = function (info) return QuestieOptions:GetProfileValue(info); end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }

    optionsTable.args.advanced_tab.args.resetDailyQuests = {
        type = "toggle",
        order = 6.4,
        name = "Reset Daily Quests",
        desc = "Reset Daily Quests",
        width = 1.65,
        get = function (info) return QuestieOptions:GetProfileValue(info); end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            Questie.db.profile.dailyResetTime = nil
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }

    optionsTable.args.advanced_tab.args.weeklyResetDay = {
        type = "select",
        order = 6.5,
        values = QuestieCompat.CALENDAR_WEEKDAY_NAMES,
        style = 'dropdown',
        disabled = function() return not Questie.db.profile.resetDailyQuests end,
        name = "Weekly Reset Day",
        desc = "Weekly Reset Day",
        width = 1.6,
        get = function (info) return QuestieOptions:GetProfileValue(info) end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            Questie.db.profile.weeklyResetTime = nil
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }
end

local correctionsRegistry = {}

function QuestieCompat.RegisterCorrection(dbName, corrections)
    correctionsRegistry[dbName] = correctionsRegistry[dbName] or {}
    table.insert(correctionsRegistry[dbName], corrections)
end

function QuestieCompat.LoadCorrections(_LoadCorrections, validationTables)
    for dbName in pairs(correctionsRegistry) do
        local dbKeysReversed = QuestieDB[dbName:sub(1, -5).."KeysReversed"]
        for i, corrections in ipairs(correctionsRegistry[dbName]) do
            _LoadCorrections(dbName, corrections(), dbKeysReversed, validationTables)
        end
    end
end

local blacklistRegistry = {}

function QuestieCompat.RegisterBlacklist(blName, blacklist)
    blacklistRegistry[blName] = blacklistRegistry[blName] or {}
    table.insert(blacklistRegistry[blName], blacklist)
end

function QuestieCompat.LoadBlacklists()
    for blName in pairs(blacklistRegistry) do
        for _, blacklist in ipairs(blacklistRegistry[blName]) do
            QuestieCompat.Merge(QuestieCorrections[blName], blacklist(), true)
        end
    end
end

function QuestieCompat.Merge(target, source, override)
	if type(target) ~= "table" then target = {} end
	for k,v in pairs(source) do
		if type(v) == "table" then
			target[k] = QuestieCompat.Merge(target[k], v, override)
		elseif target[k] == nil or override then
			target[k] = v
		end
	end
	return target
end

function QuestieCompat:ADDON_LOADED(event, addon)
    if addon ~= QuestieCompat.addonName then return end

    QuestieCompat.Merge(Questie.db, {
        profile = {
			isInitialLogin = true,
            initDelay = 0.01,
            useWotlkMapData = false,
            resetDailyQuests = true,
            weeklyResetDay = 4,
			useQuestieLinks = false,
        },
        char = {
            daily = {},
            weekly = {},
        }
    })

    QuestieCompat.LoadUiMapData(Questie.db.profile.useWotlkMapData and QuestieCompat.WOW_PROJECT_WRATH_CLASSIC)

    for uiMapId, data in pairs(QuestieCompat.UiMapData) do
        mapIdToUiMapId[data.mapID] = uiMapId
        mapIdToUiMapId[NormalizeMapKey(data.mapID, 0)] = uiMapId

        -- Map outdoor/city zone names to uiMap so player position can stay in the correct map space
        -- even when the hidden map context drifts after browsing other maps.
        if data.name and (data.mapType == 3 or data.mapType == 5) then
            zoneNameToUiMapId[data.name] = uiMapId
        end
    end

    local areaIdToUiMapId = ZoneDB.private and ZoneDB.private.areaIdToUiMapId

    -- Build zone-name -> areaId and zone-name -> uiMap using all lookup categories.
    if l10n and l10n.zoneLookup then
        for _, lookupTable in pairs(l10n.zoneLookup) do
            if type(lookupTable) == "table" then
                for areaId, zoneName in pairs(lookupTable) do
                    if zoneName and zoneName ~= "" then
                        areaIdToZoneName[areaId] = areaIdToZoneName[areaId] or zoneName
                        zoneNameToAreaId[zoneName] = zoneNameToAreaId[zoneName] or areaId
                        if starterAreaIdToUiMapId[areaId] then
                            zoneNameToUiMapId[zoneName] = starterAreaIdToUiMapId[areaId]
                        elseif areaIdToUiMapId and areaIdToUiMapId[areaId] then
                            zoneNameToUiMapId[zoneName] = areaIdToUiMapId[areaId]
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

    for k, patterns in pairs(chatMessagePattern) do
        for i, str in pairs(patterns) do
            chatMessagePattern[k][i] = QuestieLib:SanitizePattern(str)
        end
    end

    for name, path in pairs(townsfolk_texturemap) do
        QuestieMenu.private.townsfolk_texturemap[name] = path
    end
	
	local DISABLED_MODULES = {
        "HBDHooks",
        "QuestieDebugOffer",
        "SeasonOfDiscovery",
        "QuestieDBMIntegration"
    }
	
	if not Questie.db.profile.useQuestieLinks then
		table.insert(DISABLED_MODULES, "ChatFilter")
		table.insert(DISABLED_MODULES, "Hooks")
		table.insert(DISABLED_MODULES, "QuestieLink")
	end

    for _, moduleName in pairs(DISABLED_MODULES) do
        local module = QuestieLoader:ImportModule(moduleName)
        setmetatable(wipe(module), QuestieCompat.NOOP_MT)
    end

	QuestieLoader.PopulateGlobals = QuestieCompat.PopulateGlobals
    QuestieStream._writeByte = QuestieCompat._writeByte
    QuestieStream._readByte = QuestieCompat._readByte
    QuestieStream.Save = QuestieCompat.Save
    ZoneDB.private.RunTests = QuestieCompat.NOOP
    QuestieLib.TextWrap = QuestieCompat.TextWrap
    QuestieCoords.GetPlayerMapPosition = QuestieCompat.GetPlayerMapPosition
    QuestieCoords.ResetMiniWorldMapText = QuestieCompat.NOOP
    _EventHandler.UiInfoMessage = QuestieCompat.UiInfoMessage
    QuestieCompat.orig_QuestieOptions_Initialize = QuestieOptions.Initialize
    QuestieOptions.Initialize = QuestieCompat.QuestieOptions_Initialize
    QuestieCompat.orig_GetSelectedSoundFile = Sounds.GetSelectedSoundFile
    Sounds.GetSelectedSoundFile = QuestieCompat.GetSelectedSoundFile
	QuestieLink.GetQuestLinkString = rawget(QuestieLink, "GetQuestLinkString") or QuestieCompat.GetQuestLinkString
	QuestieLink.GetQuestLinkStringById = rawget(QuestieLink, "GetQuestLinkStringById") or QuestieCompat.GetQuestLinkStringById
	QuestieLink.GetQuestHyperLink = rawget(QuestieLink, "GetQuestHyperLink") or QuestieCompat.GetQuestLinkStringById

    hooksecurefunc(QuestieEventHandler, "RegisterLateEvents", QuestieCompat.QuestieEventHandler_RegisterLateEvents)
    hooksecurefunc(QuestEventHandler, "RegisterEvents", QuestieCompat.QuestEventHandler_RegisterEvents)
    hooksecurefunc(TrackerLinePool, "Initialize", QuestieCompat.QuestieTracker_Initialize)
    hooksecurefunc(QuestieQuest, "ToggleNotes", QuestieCompat.HBDPins.UpdateWorldMap)
	hooksecurefunc("ReloadUI", QuestieCompat.OnReloadUi)
	hooksecurefunc("ConsoleExec", QuestieCompat.OnReloadUi)


    local Mapster = LibStub("AceAddon-3.0"):GetAddon("Mapster", true)
    if Mapster and Mapster.RefreshQuestObjectivesDisplay then
        hooksecurefunc(Mapster, "RefreshQuestObjectivesDisplay", QuestieCompat.HBDPins.UpdateWorldMap)
    end

    QuestieCompat.PatchTomTomWorldCoords()

    EnsureWorldMapInteractionHooks()

    local MBF = LibStub("AceAddon-3.0"):GetAddon("Minimap Button Frame", true)
    if MBF and MBF.db.profile.MinimapIcons then
        table.insert(MBF.db.profile.MinimapIcons, "QuestieFrame")
        MBF:fillDropdowns()
    end
end