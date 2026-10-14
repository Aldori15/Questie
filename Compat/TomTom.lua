QuestieLoader:StampLoadBoundary("Compat/TomTom.lua")

---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local function GetTomTomMapIndices(uiMapID)
    local uiData = uiMapID and QuestieCompat.UiMapData[uiMapID]
    if not uiData then
        return nil
    end

    if uiMapID == 947 then
        return 0, 0
    elseif uiMapID == 1414 then
        return 1, 0
    elseif uiMapID == 1415 then
        return 2, 0
    elseif uiMapID == 1945 then
        return 3, 0
    end

    return QuestieCompat.GetLegacyMapContinentAndZone(uiMapID)
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
        return nil, nil, nil, nil
    end

    local entranceUiMapID = ZoneDB.GetUiMapIdByAreaId and ZoneDB:GetUiMapIdByAreaId(entrance[1])
    local entranceContinent, entranceZone = GetTomTomMapIndices(entranceUiMapID)
    if not entranceContinent then
        return nil, nil, nil, nil
    end

    return entranceContinent, entranceZone, entrance[2], entrance[3]
end

function QuestieCompat.TomTom_AddWaypoint(title, zone, x, y, persistent)
    local continent, zoneIndex = GetTomTomMapIndices(zone)
    if (zone == 125) or (zone == 126) then continent, zoneIndex = 4, 3 end
    if not continent then
        local entranceContinent, entranceZone, entranceX, entranceY = GetTomTomDungeonEntranceWaypoint(zone)
        if entranceContinent then
            continent, zoneIndex = entranceContinent, entranceZone
            x = entranceX
            y = entranceY
        end
    end
    if not continent then return nil end
    -- Force the crazy arrow on 3.3.5 so Questie behaves like newer TomTom integrations.
    return TomTom:AddZWaypoint(continent, zoneIndex, x, y, title, persistent, nil, nil, nil, nil, true)
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

    local displayedUiMapID, actualUiMapID = QuestieCompat.GetWorldMapUiMapContext()

    if not displayedUiMapID or not actualUiMapID then
        return false
    end

    return displayedUiMapID ~= actualUiMapID
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
    local _, playerX, playerY = QuestieCompat.GetActualPlayerZonePosition()

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
        if not tomTomWorldFrame.questieWorldCoordsPatched then
            -- A nil original handler still counts as captured; never capture our own callback.
            tomTomWorldFrame.questieOriginalOnUpdate = tomTomWorldFrame:GetScript("OnUpdate")
            tomTomWorldFrame.questieWorldCoordsPatched = true
        end
        tomTomWorldFrame:SetScript("OnUpdate", QuestieCompat.UpdateTomTomWorldCoords)
    end
end

