---@class QuestieJourneyUtils
local QuestieJourneyUtils = QuestieLoader:CreateModule("QuestieJourneyUtils")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local AceGUI = LibStub("AceGUI-3.0");

function QuestieJourneyUtils:GetSortedZoneKeys(zones)
    local function compare(a, b)
        return zones[a] < zones[b]
    end

    local zoneNames = {}
    for k, _ in pairs(zones) do
        table.insert(zoneNames, k)
    end
    table.sort(zoneNames, compare)
    return zoneNames
end

function QuestieJourneyUtils:Spacer(container, size)
    local spacer = AceGUI:Create("Label");
    spacer:SetFullWidth(true);
    spacer:SetText(" ");
    if size and size == "large" then
        spacer:SetFontObject(GameFontHighlightLarge);
    elseif size and size == "small" then
        spacer:SetFontObject(GameFontHighlightSmall);
    else
        spacer:SetFontObject(GameFontHighlight);
    end
    container:AddChild(spacer);
end

function QuestieJourneyUtils:AddLine(frame, text)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true);
    label:SetText(text)
    label:SetFontObject(GameFontNormal)
    frame:AddChild(label)
end

function QuestieJourneyUtils:GetZoneName(id)
    local function FindLookupName(lookup, zoneId)
        for _, data in pairs(lookup or {}) do
            if data[zoneId] then
                return data[zoneId]
            end
        end
        return nil
    end

    local zoneId = id
    local name = FindLookupName(l10n.zoneLookup, zoneId) or FindLookupName(l10n.zoneCategoryLookup, zoneId)
    if name then
        return name
    end

    local dungeons = ZoneDB.private and ZoneDB.private.dungeons
    if dungeons and dungeons[zoneId] then
        return dungeons[zoneId][1]
    end

    if ZoneDB.GetAreaIdByUiMapId then
        local success, areaId = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, zoneId)
        if success and areaId then
            zoneId = areaId
            name = FindLookupName(l10n.zoneLookup, zoneId) or FindLookupName(l10n.zoneCategoryLookup, zoneId)
            if name then
                return name
            end

            if dungeons and dungeons[zoneId] then
                return dungeons[zoneId][1]
            end
        end
    end

    local areaName = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(zoneId)
    local uiMapID = ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(zoneId) or zoneId
    local mapInfo = uiMapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
    return areaName or (mapInfo and mapInfo.name) or l10n("Unknown Zone")
end
