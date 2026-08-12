---@class QuestieCoords
local QuestieCoords = QuestieLoader:CreateModule("QuestieCoords");

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local C_Map = QuestieCompat.C_Map
local WorldMapFrame = QuestieCompat.WorldMapFrame

local posX = 0;
local posY = 0;

QuestieCoords.updateInterval = QuestieCompat.Is335 and 0.1 or 0.5;
-- Placing the functions locally to save time when spamming the updateInterval
local GetBestMapForUnit = C_Map.GetBestMapForUnit;
local GetPlayerMapPosition = C_Map.GetPlayerMapPosition;
local GetCursorPosition = GetCursorPosition;

local GetMinimapZoneText = GetMinimapZoneText;
local IsInInstance = IsInInstance;
local GetTime = GetTime;
local format = format;


local function SetTextIfChanged(fontString, text)
    if fontString and text and fontString:GetText() ~= text then
        fontString:SetText(text)
    end
end

local function GetMapTitleText()
    if QuestieCompat.Is335 then return WorldMapFrameTitle end
    local regions = {WorldMapFrame.BorderFrame:GetRegions()}
    for i = 1, #regions do
        if (regions[i].SetText) then
            return regions[i]
        end
    end
end

local function GetMiniWorldMapTitleText()
    if QuestieCompat.Is335 then return end
    local regions = {WorldMapFrame.MiniBorderFrame:GetRegions()}
    for i = 1, #regions do
        if regions[i].SetText then
            return regions[i]
        end
    end
end

local function GetWorldMapCoordsText()
    if not QuestieCompat.Is335 then
        return GetMapTitleText()
    end

    if QuestieCoords._worldMapCoordsText then
        return QuestieCoords._worldMapCoordsText
    end

    local worldMapFrame = _G.WorldMapFrame
    local positioningGuide = _G.WorldMapPositioningGuide or _G.WorldMapDetailFrame
    if not worldMapFrame or not positioningGuide then
        return nil
    end

    local coordsText = worldMapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordsText:SetPoint("BOTTOM", positioningGuide, "BOTTOM", 0, 10)
    coordsText:SetJustifyH("CENTER")
    coordsText:Hide()

    QuestieCoords._worldMapCoordsText = coordsText
    return coordsText
end

local function UpdateWorldMapCoordsLayout(coordsText)
    if not QuestieCompat.Is335 or not coordsText then
        return
    end

    local positioningGuide = _G.WorldMapPositioningGuide or _G.WorldMapDetailFrame
    if not positioningGuide then
        return
    end

    local isWindowed = WORLDMAP_SETTINGS and WORLDMAP_WINDOWED_SIZE and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
    local yOffset = 10

    if isWindowed then
        local objectivesButton = _G.WorldMapQuestShowObjectives
        local guideBottom = positioningGuide:GetBottom()
        local _, objectivesCenterY = objectivesButton and objectivesButton:GetCenter()
        if guideBottom and objectivesCenterY then
            yOffset = objectivesCenterY - guideBottom
        else
            yOffset = 0
        end
    end

    if QuestieCoords._worldMapCoordsWindowed == isWindowed and QuestieCoords._worldMapCoordsYOffset == yOffset then
        return
    end

    QuestieCoords._worldMapCoordsWindowed = isWindowed
    QuestieCoords._worldMapCoordsYOffset = yOffset
    coordsText:ClearAllPoints()
    coordsText:SetPoint("CENTER", positioningGuide, "BOTTOM", 0, yOffset)
end

local function HideWorldMapCoordsText()
    QuestieCoords._nextWorldMapCoordsUpdateAt = nil

    if QuestieCoords._worldMapCoordsText then
        if QuestieCoords._worldMapCoordsText:IsShown() then
            QuestieCoords._worldMapCoordsText:Hide()
        end
        if QuestieCoords._worldMapCoordsText:GetText() ~= "" then
            QuestieCoords._worldMapCoordsText:SetText("")
        end
    end
end

function QuestieCoords:WriteCoords()
    local shouldShowWorldMapCoords = Questie.db.profile.mapCoordinatesEnabled and WorldMapFrame:IsVisible()
    local shouldShowMinimapCoords = Questie.db.profile.minimapCoordinatesEnabled and Minimap:IsVisible()

    if not shouldShowWorldMapCoords then
        HideWorldMapCoordsText()
    end

    if not (shouldShowWorldMapCoords or shouldShowMinimapCoords) then
        return -- no need to write coords
    end
    local isInInstance, instanceType = IsInInstance()

    if isInInstance and "pvp" ~= instanceType then
        HideWorldMapCoordsText()
        return -- dont write coords in raids
    end

    local position = QuestieCoords.GetPlayerMapPosition()
    if (not position) then
        HideWorldMapCoordsText()
        return
    end

    if position.x ~= 0 and position.y ~= 0 and (position.x ~= QuestieCoords._lastX or position.y ~= QuestieCoords._lastY) then
        QuestieCoords._lastX = position.x
        QuestieCoords._lastY = position.y

        posX = position.x * 100;
        posY = position.y * 100;

        -- if minimap
        if shouldShowMinimapCoords then
            SetTextIfChanged(MinimapZoneText, format("(%d, %d) ", posX, posY) .. GetMinimapZoneText());
        end
    end
    -- if main map
    local mapCoordsText = GetWorldMapCoordsText()
    if shouldShowWorldMapCoords and mapCoordsText then
        UpdateWorldMapCoordsLayout(mapCoordsText)

        if QuestieCompat.Is335 then
            local now = GetTime()
            if QuestieCoords._nextWorldMapCoordsUpdateAt and now < QuestieCoords._nextWorldMapCoordsUpdateAt then
                return
            end
            QuestieCoords._nextWorldMapCoordsUpdateAt = now + 0.2
        end

        -- get cursor position
        local curX, curY = GetCursorPosition();

        local canvas = WorldMapFrame:GetCanvas()

        local scale = canvas:GetEffectiveScale();
        curX = curX / scale;
        curY = curY / scale;

        local width = canvas:GetWidth();
        local height = canvas:GetHeight();
        local left = canvas:GetLeft();
        local top = canvas:GetTop();

        curX = (curX - left) / width * 100;
        curY = (top - curY) / height * 100;
        local precision = "%.".. Questie.db.profile.mapCoordinatePrecision .."f";

        if QuestieCompat.Is335 and ((not canvas:IsMouseOver()) or (position.uiMapID == 946)) then
            curX, curY = 0, 0
        end

        local worldmapCoordsText = "Cursor: "..format(precision..", "..precision, curX, curY)
        worldmapCoordsText = worldmapCoordsText.." | Player: "..format(precision..", "..precision, posX, posY)

        -- Add text to world map
        if QuestieCompat.Is335 and not mapCoordsText:IsShown() then
            mapCoordsText:Show()
        end
        SetTextIfChanged(mapCoordsText, worldmapCoordsText)

        -- Adding text to mini world map
        local miniWorldMapTitleText = GetMiniWorldMapTitleText()
        if miniWorldMapTitleText then
            SetTextIfChanged(miniWorldMapTitleText, worldmapCoordsText)
        end
    end
end

---@return table<{x: number, y: number}>, number | nil
function QuestieCoords.GetPlayerMapPosition()
    local mapID = GetBestMapForUnit("player")
    if (not mapID) then
        return nil, nil
    end

    return GetPlayerMapPosition(mapID, "player"), mapID
end

function QuestieCoords:Initialize()

    -- Do not fight with Coordinates addon
    if IsAddOnLoaded("Coordinates") and ((Questie.db.profile.minimapCoordinatesEnabled) or (Questie.db.profile.mapCoordinatesEnabled)) then
        Questie:Print("|cFFFF0000", l10n("WARNING!"), "|r", l10n("Coordinates addon is enabled and will cause buggy behavior. Disabling global map and mini map coordinates. These can be re-enabled in settings"))
        Questie.db.profile.minimapCoordinatesEnabled = false
        Questie.db.profile.mapCoordinatesEnabled = false
    end

    C_Timer.NewTicker(QuestieCoords.updateInterval, QuestieCoords.Update)
end

function QuestieCoords:Update()
    if (Questie.db.profile.minimapCoordinatesEnabled and Minimap:IsVisible()) or (Questie.db.profile.mapCoordinatesEnabled and WorldMapFrame:IsVisible()) then
        QuestieCoords:WriteCoords();
    end
end

function QuestieCoords:ResetMinimapText()
    MinimapZoneText:SetText(GetMinimapZoneText());
end

function QuestieCoords:ResetMapText()
    HideWorldMapCoordsText()
    if not QuestieCompat.Is335 then
        GetMapTitleText():SetText(WORLD_MAP);
    end
end

function QuestieCoords:ResetMiniWorldMapText()
    local currentMapId = WorldMapFrame:GetMapID();
    if currentMapId then
        local info = C_Map.GetMapInfo(currentMapId);
        if info then
            GetMiniWorldMapTitleText():SetText(info.name);
        end
    end
end
