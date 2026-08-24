---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap");
---@class QuestieMapUtils
QuestieMap.utils = QuestieMap.utils or {}

-- All the speed we can get is worth it.
local pairs = pairs

local DRAW_ORDER_BY_ICON_TYPE_LOOKUP

local DRAW_LAYER_KEYS = {
    "line",
    "manual",
    "objective",
    "available",
    "repeatable",
    "complete",
}

local worldMapDrawLayers
local minimapDrawLayers

local function CreateDrawLayers(root, strata)
    local drawLayers = {
        root = root,
        frames = {},
    }

    -- On the 3.3.5 client, reparenting sibling frames can affect their render
    -- order even when explicit frame levels differ. These persistent category
    -- parents are created once from lowest to highest priority, so recreating
    -- an icon cannot move it above an icon from a higher priority category.
    for index, key in ipairs(DRAW_LAYER_KEYS) do
        local layer = CreateFrame("Frame", nil, root)
        layer:SetAllPoints(root)
        layer:SetFrameStrata(strata)
        layer:SetFrameLevel(root:GetFrameLevel() + index)
        layer:EnableMouse(false)
        drawLayers.frames[index] = layer
        drawLayers[key] = layer
    end

    return drawLayers
end

local function GetDrawLayers(isMinimap)
    local root = isMinimap and Minimap or WorldMapButton
    local strata = isMinimap and Minimap:GetFrameStrata() or WorldMapFrame:GetFrameStrata()
    local drawLayers = isMinimap and minimapDrawLayers or worldMapDrawLayers

    if (not drawLayers) or drawLayers.root ~= root then
        drawLayers = CreateDrawLayers(root, strata)
        if isMinimap then
            minimapDrawLayers = drawLayers
        else
            worldMapDrawLayers = drawLayers
        end
    end

    -- Map replacements can adjust the root frame after Questie initializes.
    -- Refresh the compact levels without changing the containers' order.
    for index, layer in ipairs(drawLayers.frames) do
        if layer:GetFrameStrata() ~= strata then
            layer:SetFrameStrata(strata)
        end
        local frameLevel = root:GetFrameLevel() + index
        if layer:GetFrameLevel() ~= frameLevel then
            layer:SetFrameLevel(frameLevel)
        end
    end

    return drawLayers, strata
end

local function EnsureDrawOrderLookup()
    if DRAW_ORDER_BY_ICON_TYPE_LOOKUP then return end

    -- Questie.lua is loaded last in the 3.3.5 TOC, so its icon constants are
    -- not available while QuestieMapUtils.lua itself is being loaded.
    DRAW_ORDER_BY_ICON_TYPE_LOOKUP = {
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
end

function QuestieMap.utils.SetDrawOrder(frame)
    EnsureDrawOrderLookup()

    local drawLayers, strata = GetDrawLayers(frame.miniMapIcon)
    local layer
    if frame.isManualIcon then
        layer = drawLayers.manual
    else
        local priority
        if frame.data and frame.data.Type == "complete" then
            priority = 3
        else
            priority = (frame.data and DRAW_ORDER_BY_ICON_TYPE_LOOKUP[frame.data.Icon]) or 0
        end

        if priority == 3 then
            layer = drawLayers.complete
        elseif priority == 2 then
            layer = drawLayers.repeatable
        elseif priority == 1 then
            layer = drawLayers.available
        else
            layer = drawLayers.objective
        end
    end

    frame:SetParent(layer)
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(layer:GetFrameLevel() + 1)

    -- These sublayers only control the regions within this individual icon.
    frame.glowTexture:SetDrawLayer("ARTWORK", -1)
    frame.texture:SetDrawLayer("OVERLAY", 0)
    frame.overlayTexture:SetDrawLayer("OVERLAY", 1)
end

function QuestieMap.utils.SetLineDrawOrder(frame)
    local drawLayers, strata = GetDrawLayers(false)
    frame.questieDrawLayerParent = drawLayers.line
    frame:SetParent(drawLayers.line)
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(drawLayers.line:GetFrameLevel() + 1)
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
