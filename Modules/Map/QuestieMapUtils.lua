---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap");
---@class QuestieMapUtils
QuestieMap.utils = QuestieMap.utils or {}

-- All the speed we can get is worth it.
local pairs = pairs

-- Frame-level offset for every icon type defined by Questie 335.
local DRAW_ORDER_BY_ICON_TYPE_LOOKUP = {
    [Questie.ICON_TYPE_SLAY] = 0,
    [Questie.ICON_TYPE_LOOT] = 0,
    [Questie.ICON_TYPE_EVENT] = 0,
    [Questie.ICON_TYPE_OBJECT] = 0,
    [Questie.ICON_TYPE_TALK] = 0,
    [Questie.ICON_TYPE_AVAILABLE] = 1,
    [Questie.ICON_TYPE_AVAILABLE_GRAY] = 0,
    [Questie.ICON_TYPE_COMPLETE] = 3,
    [Questie.ICON_TYPE_GLOW] = 0,
    [Questie.ICON_TYPE_REPEATABLE] = 2,
    [Questie.ICON_TYPE_REPEATABLE_COMPLETE] = 3,
    [Questie.ICON_TYPE_INCOMPLETE] = 0,
    [Questie.ICON_TYPE_EVENTQUEST] = 2,
    [Questie.ICON_TYPE_EVENTQUEST_COMPLETE] = 3,
    [Questie.ICON_TYPE_PVPQUEST] = 2,
    [Questie.ICON_TYPE_PVPQUEST_COMPLETE] = 3,
    [Questie.ICON_TYPE_INTERACT] = 0,
    [Questie.ICON_TYPE_MOUNT_UP] = 0,
    [Questie.ICON_TYPE_NODE_FISH] = 0,
    [Questie.ICON_TYPE_NODE_HERB] = 0,
    [Questie.ICON_TYPE_NODE_ORE] = 0,
    [Questie.ICON_TYPE_CHEST] = 0,
}

local MAX_DRAW_ORDER_BY_ICON_TYPE = 0
for _, drawOrder in pairs(DRAW_ORDER_BY_ICON_TYPE_LOOKUP) do
    if drawOrder > MAX_DRAW_ORDER_BY_ICON_TYPE then
        MAX_DRAW_ORDER_BY_ICON_TYPE = drawOrder
    end
end
-- Leave one complete priority range between manual and regular quest icons.
MAX_DRAW_ORDER_BY_ICON_TYPE = MAX_DRAW_ORDER_BY_ICON_TYPE + 1

-- Quest finishers render above every manual and regular icon priority.
local DRAW_ORDER_QUEST_COMPLETE = 2 * MAX_DRAW_ORDER_BY_ICON_TYPE

function QuestieMap.utils.SetDrawOrder(frame)
    -- Keep icons above the map canvas and waypoint lines while preserving
    -- the explicit parent and strata handling required by the 3.3.5 client.
    local frameLevel
    if frame.miniMapIcon then
        frame:SetParent(Minimap)
        frame:SetFrameStrata(Minimap:GetFrameStrata())
        frameLevel = Minimap:GetFrameLevel() + 2016
    else
        frame:SetParent(WorldMapButton)
        frame:SetFrameStrata(WorldMapFrame:GetFrameStrata())
        frameLevel = WorldMapFrame:GetFrameLevel() + 2016
    end

    if frame.data and frame.data.Type == "complete" then
        frameLevel = frameLevel + DRAW_ORDER_QUEST_COMPLETE
    else
        frameLevel = frameLevel
            + ((frame.data and DRAW_ORDER_BY_ICON_TYPE_LOOKUP[frame.data.Icon]) or 0)
            + (frame.isManualIcon and 0 or MAX_DRAW_ORDER_BY_ICON_TYPE)
    end

    frame:SetFrameLevel(frameLevel)
end

function QuestieMap.utils.IsExplored(uiMapId, x, y)
    local IsExplored = false
    if uiMapId then
        local exploredAreaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapId, CreateVector2D(x / 100, y / 100))
        if exploredAreaIDs then
            IsExplored = true -- Explored
        elseif (uiMapId == 1453) then
            IsExplored = true -- Stormwind
        elseif (uiMapId == 1455) then
            IsExplored = true -- Ironforge
        elseif (uiMapId == 1457) then
            IsExplored = true -- Darnassus
        elseif (uiMapId == 1458) then
            IsExplored = true -- Undercity
        elseif (uiMapId == 1454) then
            IsExplored = true -- Orgrimmar
        elseif (uiMapId == 1456) then
            IsExplored = true -- Thunder Bluff
        end
    end
    return IsExplored
end

function QuestieMap.utils.MapExplorationUpdate()
    for _, frameList in pairs(QuestieMap.questIdFrames) do
        for _, frameName in pairs(frameList) do
            local frame = _G[frameName]
            if (frame and frame.x and frame.y and frame.UiMapID and frame.hidden) then
                if QuestieMap.utils.IsExplored(frame.UiMapID, frame.x, frame.y) then
                    frame:FakeShow()
                end
            end
        end
    end
end

local function _GetManualScaleProfile(frame, isMinimap)
    if not frame.isManualIcon then
        return isMinimap and Questie.db.profile.globalMiniMapScale or Questie.db.profile.globalScale
    end

    if frame.data and frame.data.ManualScaleType == "instance" then
        return isMinimap and Questie.db.profile.globalMiniMapInstanceScale or Questie.db.profile.globalInstanceScale
    end

    return isMinimap and Questie.db.profile.globalMiniMapTownsfolkScale or Questie.db.profile.globalTownsfolkScale
end

--- Rescale a single icon
---@param frameRef string|IconFrame @The global name/iconRef of the icon frame, e.g. "QuestieFrame1"
---@param mapScale number? @Scale value for the final size of the Icon
function QuestieMap.utils.RescaleIcon(frameRef, mapScale)
    local frame = frameRef;
    local iconScale = mapScale or 1
    if type(frameRef) == "string" then
        frame = _G[frameRef];
    end
    if frame and frame.data then
        if frame.data.GetIconScale then
            frame.data.IconScale = frame.data:GetIconScale();
            local scale
            if frame.miniMapIcon then
                local scaleProfile = _GetManualScaleProfile(frame, true)
                scale = 16 * (frame.data.IconScale or 1) * (scaleProfile or 0.7);
            else
                --? If you ever chanage this logic, make sure you change the logic in QuestieMap:ProcessQueue() too!
                local scaleProfile = _GetManualScaleProfile(frame, false)
                scale = (16 * (frame.data.IconScale or 1) * (scaleProfile or 0.7)) * iconScale;
            end

            if scale > 1 then
                frame:SetSize(scale, scale)
                frame:GlowUpdate()
            end
        else
            Questie.Error("A frame is lacking the GetIconScale function for resizing!", frame.data.Id);
        end
    end
end
