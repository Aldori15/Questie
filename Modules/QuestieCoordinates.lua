---@class QuestieCoords
local QuestieCoords = QuestieLoader:CreateModule("QuestieCoords");

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

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

local function GetWorldMapCoordsTitleText()
    if not QuestieCompat.Is335 then
        return GetMapTitleText()
    end

    if QuestieCoords._worldMapCoordsTitleText then
        return QuestieCoords._worldMapCoordsTitleText
    end

    if not WorldMapFrameTitle then
        return nil
    end

    local worldMapFrameParent = WorldMapFrameTitle.GetParent and WorldMapFrameTitle:GetParent() or _G.WorldMapFrame or UIParent
    if not worldMapFrameParent or not worldMapFrameParent.CreateFontString then
        return nil
    end

    local coordsTitleText = worldMapFrameParent:CreateFontString(nil, "OVERLAY")
    coordsTitleText:SetPoint("CENTER", WorldMapFrameTitle, "CENTER", 0, 0)

    local font, size, flags = WorldMapFrameTitle:GetFont()
    if font then
        coordsTitleText:SetFont(font, size, flags)
    end

    local r, g, b, a = WorldMapFrameTitle:GetTextColor()
    coordsTitleText:SetTextColor(r, g, b, a)

    local shadowR, shadowG, shadowB, shadowA = WorldMapFrameTitle:GetShadowColor()
    if shadowR then
        coordsTitleText:SetShadowColor(shadowR, shadowG, shadowB, shadowA)
    end

    local shadowX, shadowY = WorldMapFrameTitle:GetShadowOffset()
    if shadowX and shadowY then
        coordsTitleText:SetShadowOffset(shadowX, shadowY)
    end

    coordsTitleText:Hide()
    QuestieCoords._worldMapCoordsTitleText = coordsTitleText
    return coordsTitleText
end

local function HideWorldMapCoordsTitleText()
    if QuestieCompat.Is335 and WorldMapFrameTitle and not WorldMapFrameTitle:IsShown() then
        WorldMapFrameTitle:Show()
    end

    QuestieCoords._nextWorldMapCoordsUpdateAt = nil

    if QuestieCoords._worldMapCoordsTitleText then
        if QuestieCoords._worldMapCoordsTitleText:IsShown() then
            QuestieCoords._worldMapCoordsTitleText:Hide()
        end
        if QuestieCoords._worldMapCoordsTitleText:GetText() ~= "" then
            QuestieCoords._worldMapCoordsTitleText:SetText("")
        end
    end
end

function QuestieCoords:WriteCoords()
    local shouldShowWorldMapCoords = Questie.db.profile.mapCoordinatesEnabled and WorldMapFrame:IsVisible()
    local shouldShowMinimapCoords = Questie.db.profile.minimapCoordinatesEnabled and Minimap:IsVisible()

    if not shouldShowWorldMapCoords then
        HideWorldMapCoordsTitleText()
    end

    if not (shouldShowWorldMapCoords or shouldShowMinimapCoords) then
        return -- no need to write coords
    end
    local isInInstance, instanceType = IsInInstance()

    if isInInstance and "pvp" ~= instanceType then
        HideWorldMapCoordsTitleText()
        return -- dont write coords in raids
    end

    local position = QuestieCoords.GetPlayerMapPosition()
    if (not position) then
        HideWorldMapCoordsTitleText()
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
    local mapTitleText = GetWorldMapCoordsTitleText()
    if shouldShowWorldMapCoords and mapTitleText then
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

        if QuestieCompat.Is335 and (not canvas:IsMouseOver()) or (position.uiMapID == 946)then
            curX, curY = 0, 0
        end

        local worldmapCoordsText = "Cursor: "..format(precision.. " X, ".. precision .." Y  ", curX, curY);

        worldmapCoordsText = worldmapCoordsText.."|  Player: "..format(precision.. " X , ".. precision .." Y", posX, posY);
        -- Add text to world map
        if QuestieCompat.Is335 and WorldMapFrameTitle then
            if WorldMapFrameTitle:IsShown() then
                WorldMapFrameTitle:Hide()
            end
            if not mapTitleText:IsShown() then
                mapTitleText:Show()
            end
        end
        SetTextIfChanged(mapTitleText, worldmapCoordsText)

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
    if (Questie.db.profile.minimapCoordinatesEnabled) or (Questie.db.profile.mapCoordinatesEnabled) then
        QuestieCoords:WriteCoords();
    end
end

function QuestieCoords:ResetMinimapText()
    MinimapZoneText:SetText(GetMinimapZoneText());
end

function QuestieCoords:ResetMapText()
    HideWorldMapCoordsTitleText()
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
