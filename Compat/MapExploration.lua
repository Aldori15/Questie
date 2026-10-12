QuestieLoader:StampLoadBoundary("Compat/MapExploration.lua")

local exploredMapOverlays = {}
local mapsWithoutExploration = {
    [1453] = true, [1454] = true, [1455] = true, -- Stormwind, Orgrimmar, Ironforge
    [1456] = true, [1457] = true, [1458] = true, -- Thunder Bluff, Darnassus, Undercity
    [1947] = true, [1954] = true, [1955] = true, -- Exodar, Silvermoon, Shattrath
    [125] = true, [126] = true, -- Dalaran and the Underbelly
    [123] = true, -- Wintergrasp
}

function QuestieCompat.ClearExplorationCache()
    wipe(exploredMapOverlays)
end

local function IsOverlayPixelOpaque(overlay, x, y)
    local localX, localY = x - overlay[1], y - overlay[2]
    local tile = math.floor(localY / 256) * math.ceil(overlay.width / 256) + math.floor(localX / 256) + 1
    local key = overlay.texture .. tile
    local rows = QuestieCompat.ExplorationMasks[key]
    if not rows then
        -- Unknown/custom artwork: preserve icons instead of hiding an entire region.
        return true
    end
    if type(rows) == "string" then
        local mask = rows
        rows = {}
        for row in mask:gmatch("(.-)~") do rows[#rows + 1] = row end
        QuestieCompat.ExplorationMasks[key] = rows
    end
    local row = rows[math.floor((localY % 256) / 4) + 1]
    local column = math.floor((localX % 256) / 4)
    for i = 1, #row, 2 do
        if column >= row:byte(i) - 33 and column <= row:byte(i + 1) - 33 then
            return true
        end
    end
    return false
end

local function IsMapPositionExplored(uiMapID, x, y)
    local data = QuestieCompat.UiMapData[uiMapID]
    -- Cities, instances and maps without a usable outdoor map have no fog to check.
    if not data or mapsWithoutExploration[uiMapID] or data.mapType ~= 3
        or not QuestieCompat.IsOutdoorWorldInstance(data.instance) or not data.mapID or data.mapID <= 0 then
        return true
    end
    if not x or not y then return true end

    local overlays = exploredMapOverlays[uiMapID]
    if not overlays then
        overlays = {}
        -- Cache before selecting the map to guard against map-update hooks reentering.
        exploredMapOverlays[uiMapID] = overlays
        local selected = QuestieCompat.WithLegacyMapRead(uiMapID, function()
            -- UiMapData stores the native area ID. Map.lua handles legacy selection offsets.
            if GetCurrentMapAreaID() ~= math.floor(data.mapID) then return false end

            -- Mapster's fog removal replaces the overlay count with zero. Read its
            -- original API so revealing the map visually does not count as exploration.
            local getNumOverlays = GetNumMapOverlays
            local mapster = LibStub("AceAddon-3.0"):GetAddon("Mapster", true)
            local fogClear = mapster and mapster:GetModule("FogClear", true)
            if fogClear and fogClear.hooks and fogClear.hooks.GetNumMapOverlays then
                getNumOverlays = fogClear.hooks.GetNumMapOverlays
            end
            for i = 1, getNumOverlays() do
                local texture, width, height, left, top = GetMapOverlayInfo(i)
                if texture and texture ~= "" and width and height and left and top
                    and width > 0 and height > 0 and not texture:lower():find("pixelfix", 1, true) then
                    overlays[#overlays + 1] = {
                        left, top, left + width, top + height,
                        width = width,
                        texture = texture:lower():gsub("^interface\\worldmap\\", ""),
                    }
                end
            end
            return true
        end)
        if not selected then
            exploredMapOverlays[uiMapID] = nil
            return true
        end
    end

    -- Legacy world-map overlays use a fixed 1002 x 668 canvas, regardless of UI scale.
    x, y = x * 10.02, y * 6.68
    for _, rect in ipairs(overlays) do
        if x >= rect[1] and y >= rect[2] and x < rect[3] and y < rect[4]
            and IsOverlayPixelOpaque(rect, x, y) then
            return true
        end
    end
    return false
end

local mapExplorationCompatibilityInitialized = false
function QuestieCompat.InitializeMapExplorationCompatibility()
    if mapExplorationCompatibilityInitialized then return end
    mapExplorationCompatibilityInitialized = true

    local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
    QuestieMap.utils.IsExplored = IsMapPositionExplored
    local mapExplorationUpdate = QuestieMap.utils.MapExplorationUpdate
    QuestieMap.utils.MapExplorationUpdate = function()
        QuestieCompat.ClearExplorationCache()
        mapExplorationUpdate()
    end
end
