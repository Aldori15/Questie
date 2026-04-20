---@class QuestieMap
local QuestieMap = QuestieLoader:CreateModule("QuestieMap");
---@type QuestieMapUtils
QuestieMap.utils = QuestieMap.utils or {}

-------------------------
--Import modules.
-------------------------
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool");
---@type QuestieDBMIntegration
local QuestieDBMIntegration = QuestieLoader:ImportModule("QuestieDBMIntegration");
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib");
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer");
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type WeaponMasterSkills
local WeaponMasterSkills = QuestieLoader:ImportModule("WeaponMasterSkills")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local C_Map = QuestieCompat.C_Map

QuestieMap.ICON_MAP_TYPE = "MAP";
QuestieMap.ICON_MINIMAP_TYPE = "MINIMAP";

--Useful links.
-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/SharedXML/Pools.lua
-- https://www.townlong-yak.com/framexml/27101/Blizzard_MapCanvas/Blizzard_MapCanvas.lua
-- https://www.townlong-yak.com/framexml/27101/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua
-- https://www.townlong-yak.com/framexml/27101/Blizzard_MapCanvas/MapCanvas_PinFrameLevelsManager.lua

-- List of frames sorted by quest ID (automatic notes)
-- E.g. {[questId] = {[frameName] = frame, ...}, ...}
-- For details about frame.data see calls to QuestieMap.DrawWorldIcon
QuestieMap.questIdFrames = {}
-- List of frames sorted by NPC/object ID (manual notes)
-- id > 0: NPC
-- id < 0: object
-- E.g. {[-objectId] = {[frameName] = frame, ...}, ...}
-- For details about frame.data see QuestieMap.ShowNPC and QuestieMap.ShowObject
QuestieMap.manualFrames = {}


--Used in my fadelogic.
local fadeOverDistance = 10;
local normalizedValue = 1 / fadeOverDistance; --Opacity / Distance to fade over

local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")
local HBDPins = QuestieCompat.HBDPins or LibStub("HereBeDragonsQuestie-Pins-2.0")
local _MinimapIconSetFade
local _MinimapIconFadeLogic

--We should really try and squeeze out all the performance we can, especially in this.
local tostring = tostring;
local tinsert = table.insert;
local pairs = pairs;
local ipairs = ipairs;
local tremove = table.remove;
local tunpack = unpack;

local function _IsSpawnVisible(spawn)
    return Phasing.IsSpawnVisible(spawn and spawn[3])
end

local alreadyErroredDungeonZones = {}

local function _GetDistanceToNearestResolvedSpawn(zone, spawn, playerX, playerY, playerI)
    local bestDistance, bestSpawn, bestSpawnZone
    local resolvedSpawns

    if spawn[1] == -1 or spawn[2] == -1 then
        local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
        if not dungeonLocation then
            local parentZoneId = ZoneDB:GetParentZoneId(zone)
            if parentZoneId then
                dungeonLocation = ZoneDB:GetDungeonLocation(parentZoneId)
            end
        end
        if (not dungeonLocation) and (not alreadyErroredDungeonZones[zone]) then
            alreadyErroredDungeonZones[zone] = true
            Questie:Error("No dungeon location found for zoneId:", zone, "Please report this on Github or Discord!")
        end

        resolvedSpawns = {}
        for _, location in pairs(dungeonLocation or {}) do
            tinsert(resolvedSpawns, {zone = location[1], x = location[2], y = location[3]})
        end
    else
        resolvedSpawns = {{zone = zone, x = spawn[1], y = spawn[2]}}
    end

    for _, resolvedSpawn in pairs(resolvedSpawns) do
        local uiMapId = ZoneDB:GetUiMapIdByAreaId(resolvedSpawn.zone)
        if uiMapId then
            local dX, dY, dInstance = HBD:GetWorldCoordinatesFromZone(resolvedSpawn.x / 100.0, resolvedSpawn.y / 100.0, uiMapId)
            if dX and dY and dInstance then
                local dist = HBD:GetWorldDistance(dInstance, playerX, playerY, dX, dY)
                if dist then
                    if dInstance ~= playerI then
                        dist = 500000 + dist * 100 -- hack
                    end
                    if (not bestDistance) or dist < bestDistance then
                        bestDistance = dist
                        bestSpawn = {resolvedSpawn.x, resolvedSpawn.y}
                        bestSpawnZone = resolvedSpawn.zone
                    end
                end
            end
        end
    end

    return bestDistance, bestSpawn, bestSpawnZone
end


local drawTimer
local drawQueueTickRate
local fadeLogicTimerShown
local fadeLogicCoroutine


--* TODO: How the frames are handled needs to be reworked, why are we getting them from _G
--Get the frames for a quest, this returns all of the frames
function QuestieMap:GetFramesForQuest(questId)
    local frames = {}
    --If no frames exists or if the quest does not exist we just return an empty list
    if QuestieMap.questIdFrames[questId] then
        for _, name in pairs(QuestieMap.questIdFrames[questId]) do
            if _G[name] then
                frames[name] = _G[name]
            end
        end
    end
    return frames
end

function QuestieMap:UnloadQuestFrames(questId, iconType, noteType)
    if QuestieMap.questIdFrames[questId] then
        if (not iconType) and (not noteType) then
            for _, frame in pairs(QuestieMap:GetFramesForQuest(questId)) do
                frame:Unload();
            end
            QuestieMap.questIdFrames[questId] = nil;
        else
            for name, frame in pairs(QuestieMap:GetFramesForQuest(questId)) do
                if frame and frame.data
                    and ((not iconType) or frame.data.Icon == iconType)
                    and ((not noteType) or frame.data.Type == noteType) then
                    frame:Unload();
                    QuestieMap.questIdFrames[questId][name] = nil
                    _G[name] = nil
                end
            end
        end
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap] Unloading quest frames for questid:", questId)
    end
end

--Get the frames for manual note, this returns all of the frames/spawns
---@param id number @The ID of the NPC (>0) or object (<0)
function QuestieMap:GetManualFrames(id, typ)
    typ = typ or "any"
    local frames = {}
    --If no frames exists or if the quest does not exist we just return an empty list
    if QuestieMap.manualFrames[typ] and (QuestieMap.manualFrames[typ][id]) then
        for _, name in pairs(QuestieMap.manualFrames[typ][id]) do
            tinsert(frames, _G[name])
        end
    end
    return frames
end

---@param id number @The ID of the NPC (>0) or object (<0)
function QuestieMap:UnloadManualFrames(id, typ)
    typ = typ or "any"
    if QuestieMap.manualFrames[typ] and (QuestieMap.manualFrames[typ][id]) then
        for _, frame in ipairs(QuestieMap:GetManualFrames(id, typ)) do
            frame:Unload();
        end
        QuestieMap.manualFrames[typ][id] = nil;
    end
end

function QuestieMap:ResetManualFrames(typ)
    typ = typ or "any"
    if not QuestieMap.manualFrames[typ] then return end
    for id, _ in pairs(QuestieMap.manualFrames[typ]) do
        QuestieMap:UnloadManualFrames(id, typ)
    end
end

-- Rescale all the icons
function QuestieMap:RescaleIcons()
    local mapScale = QuestieMap.GetScaleValue()
    for _, framelist in pairs(QuestieMap.questIdFrames) do
        for _, frameName in pairs(framelist) do
            QuestieMap.utils:RescaleIcon(frameName, mapScale)
        end
    end
    for _, frameTypeList in pairs(QuestieMap.manualFrames) do
        for _, framelist in pairs(frameTypeList) do
            for _, frameName in ipairs(framelist) do
                QuestieMap.utils:RescaleIcon(frameName, mapScale)
            end
        end
    end
end

function QuestieMap:RescaleManualIcons()
    local mapScale = QuestieMap.GetScaleValue()
    for _, frameTypeList in pairs(QuestieMap.manualFrames) do
        for _, framelist in pairs(frameTypeList) do
            for _, frameName in ipairs(framelist) do
                QuestieMap.utils:RescaleIcon(frameName, mapScale)
            end
        end
    end
end

-- Rescale all Townsfolk icons
function QuestieMap:RescaleTownsfolkIcons()
    QuestieMap:RescaleManualIcons()
end

local mapDrawQueue = {};
local minimapDrawQueue = {};

QuestieMap._mapDrawQueue = mapDrawQueue
QuestieMap._minimapDrawQueue = minimapDrawQueue

local function _GetManualScaleProfile(frame)
    if not frame.isManualIcon then
        return Questie.db.profile.globalScale
    end

    if frame.data and frame.data.ManualScaleType == "instance" then
        return Questie.db.profile.globalInstanceScale
    end

    return Questie.db.profile.globalTownsfolkScale
end

function QuestieMap:InitializeQueue() -- now called on every loading screen
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap] Starting draw queue timer!")
    local isInInstance, instanceType = IsInInstance()

    local desiredTickRate
    if isInInstance and instanceType == "raid" then
        desiredTickRate = 0.4 -- slower update rate in raids instead of disabling updates entirely
    else
        desiredTickRate = 0.2
    end

    if drawTimer and drawQueueTickRate ~= desiredTickRate then
        drawTimer:Cancel()
        drawTimer = nil
    end

    drawQueueTickRate = desiredTickRate

    if not drawTimer then
        drawTimer = C_Timer.NewTicker(drawQueueTickRate, QuestieMap.ProcessQueue)
    end

    if not fadeLogicTimerShown then
        -- ! Remember to update the distance variable in ProcessShownMinimapIcons if you change the timer
        fadeLogicTimerShown = C_Timer.NewTicker(0.1, function()
            if fadeLogicCoroutine and coroutine.status(fadeLogicCoroutine) == "suspended" then
                local success, errorMsg = coroutine.resume(fadeLogicCoroutine)
                if (not success) then
                    Questie:Error("Please report on Github or Discord. Minimap pins fade logic coroutine stopped:", errorMsg)
                    fadeLogicCoroutine = nil
                end
            end
        end)
    end

    if not fadeLogicCoroutine then
        fadeLogicCoroutine = coroutine.create(QuestieMap.ProcessShownMinimapIcons)
    end
end

---@return number @A scale value that is based of the map currently open, smaller icons for World and Continent
function QuestieMap.GetScaleValue()
    local map = HBDPins.worldmapProvider and HBDPins.worldmapProvider:GetMap()
    local mapId = map and map:GetMapID()
    local scaling = 1;
    if C_Map and C_Map.GetMapInfo and mapId then
        local mapInfo = C_Map.GetMapInfo(mapId)
        if not mapInfo then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap:GetScaleValue] No map info for uiMapID:", tostring(mapId))
        elseif (mapInfo.mapType == 0) then     --? Cosmic, This is probably not needed but for the sake of completion...
            scaling = 0.85
        elseif (mapInfo.mapType == 1) then -- World
            scaling = 0.85
        elseif (mapInfo.mapType == 2) then -- Continent
            scaling = 0.9
        end
    end
    return scaling
end

function QuestieMap:ProcessShownMinimapIcons()
    --Upvalue the most used functions in here
    local getTime, cYield, getWorldPos = GetTime, coroutine.yield, HBD.GetPlayerWorldPosition

    --Max icons per tick
    local maxCount = 50

    --Local variables defined here instead of in loop
    --saves time because it doesn't need to remake the variables
    local doEdgeUpdate = true
    local playerX, playerY
    local count
    local lastUpdate = getTime()

    local xd, yd
    local totalDistance = 0

    --This coroutine never dies, we want it to keep looping forever
    --yield stops it from being "infinite" and crashing the game
    while true do
        count = 0

        playerX, playerY = getWorldPos()

        --Calculate squared distance
        -- No need for absolute values as these are used only as squared
        xd = (playerX or 0) - (QuestieMap.playerX or 0)
        yd = (playerY or 0) - (QuestieMap.playerY or 0)
        --Instead of math.sqrt we just used the square distance for speed
        totalDistance = totalDistance + (xd * xd + yd * yd)


        --These variables are used inside the fadelogic
        QuestieMap.playerX = playerX
        QuestieMap.playerY = playerY

        -- Only update icons on the edge every 1 seconds
        -- totalDistance is used because sometimes we move so fast that we need to update it more often.
        -- ! Remember to update the distance variable if you change the timer
        if totalDistance > 3 or getTime() - lastUpdate >= 1 then
            doEdgeUpdate = true
            lastUpdate = getTime()
            --print("Dist:", totalDistance)
            totalDistance = 0
        end

        ---@param minimapFrame IconFrame
        for minimapFrame, data in pairs(HBDPins.activeMinimapPins) do
            if minimapFrame.miniMapIcon and ((data.distanceFromMinimapCenter < 1.1) or doEdgeUpdate) then
                if minimapFrame.FadeLogic then
                    minimapFrame:FadeLogic()
                end
                if minimapFrame.GlowUpdate then
                    minimapFrame:GlowUpdate()
                end
            end

            --Never run more than maxCount in a single run
            if count > maxCount then
                cYield()
                if (not HBDPins.activeMinimapPins[minimapFrame]) then
                    -- table has been edited during traversal at critical key. we can't continue iterating over it. stop iteration and start again.
                    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap:ProcessShownMinimapIcons] FadeLogic loop coroutine: HBDPins.activeMinimapPins doesn't have the key anymore.")
                    -- force reupdate imeadiately
                    totalDistance = 9000
                    break
                end
                count = 0
            else
                count = count + 1
            end
        end
        cYield()
        doEdgeUpdate = false
    end
end

function QuestieMap:QueueDraw(drawType, ...)
    if (drawType == QuestieMap.ICON_MAP_TYPE) then
        tinsert(mapDrawQueue, { ... });
    elseif (drawType == QuestieMap.ICON_MINIMAP_TYPE) then
        tinsert(minimapDrawQueue, { ... });
    end
end

function QuestieMap.ProcessQueue()
    if (not next(mapDrawQueue) and (not next(minimapDrawQueue))) then
        -- Nothing to process
        return
    end

    local scaleValue = QuestieMap.GetScaleValue()
    local queueSize = math.max(#mapDrawQueue, #minimapDrawQueue)
    local maxPerTick = 24

    if queueSize > 600 then
        maxPerTick = 96
    elseif queueSize > 250 then
        maxPerTick = 64
    elseif queueSize > 100 then
        maxPerTick = 48
    end

    for _ = 1, math.min(maxPerTick, queueSize) do
        local mapDrawCall = tremove(mapDrawQueue, 1);
        if mapDrawCall then
            local frame = mapDrawCall[2];
            HBDPins:AddWorldMapIconMap(tunpack(mapDrawCall));

            --? If you ever chanage this logic, make sure you change the logic in QuestieMap.utils:RescaleIcon function too!
            local scaleProfile = _GetManualScaleProfile(frame)
            local size = (16 * (frame.data.IconScale or 1) * (scaleProfile or 0.7)) * scaleValue;
            frame:SetSize(size, size)

            QuestieMap.utils:SetDrawOrder(frame);

            mapDrawCall[2]._loaded = true
            if mapDrawCall[2]._needsUnload then
                mapDrawCall[2]:Unload()
            end
        end

        local minimapDrawCall = tremove(minimapDrawQueue, 1);
        if minimapDrawCall then
            local frame = minimapDrawCall[2];
            HBDPins:AddMinimapIconMap(tunpack(minimapDrawCall));

            QuestieMap.utils:SetDrawOrder(frame);

            minimapDrawCall[2]._loaded = true
            if minimapDrawCall[2]._needsUnload then
                minimapDrawCall[2]:Unload()
            end
        end
    end
end

-- Show NPC on map
-- This function does the same for manualFrames as similar functions in
-- QuestieQuest do for questIdFrames
---@param npcID number @The ID of the NPC
function QuestieMap:ShowNPC(npcID, icon, scale, title, body, disableShiftToRemove, typ, excludeDungeon)
    if type(npcID) ~= "number" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:ShowNPC] Got <" .. type(npcID) .. "> instead of <number>")
        return
    end
    -- get the NPC data
    local npc = QuestieDB:GetNPC(npcID)
    if (not npc) or (not npc.spawns) then return end

    -- create the icon data
    local data = {}
    data.id = npc.id
    data.Icon = icon or "Interface\\WorldMap\\WorldMapPartyIcon"

    data.GetIconScale = function() return scale or Questie.db.profile.manualScale or 0.7 end
    data.IconScale = data:GetIconScale()
    data.Type = "manual"
    data.spawnType = "monster"
    data.npcData = npc
    data.Name = npc.name
    data.IsObjectiveNote = false
    data.ManualTooltipData = {}
    local baseTitle = title or (npc.name .. " (" .. l10n("NPC") .. ")")
    data.ManualTooltipData.Title = WeaponMasterSkills.AppendSkillsToTitle(baseTitle, data.id)
    local level = tostring(npc.minLevel)
    local health = tostring(npc.minLevelHealth)
    if npc.minLevel ~= npc.maxLevel then
        level = level .. '-' .. tostring(npc.maxLevel)
        health = health .. '-' .. tostring(npc.maxLevelHealth)
    end
    data.ManualTooltipData.Body = body or {
        { 'ID:',     tostring(npc.id) },
        { 'Level:',  level },
        { 'Health:', health },
    }
    data.ManualTooltipData.disableShiftToRemove = disableShiftToRemove

    local manualIcons = {}
    local visibleSpawnZones = {}
    -- draw the notes
    for zone, spawns in pairs(npc.spawns) do
        if (zone ~= nil and spawns ~= nil) and ((not excludeDungeon) or (not ZoneDB.IsDungeonZone(zone))) then
            for _, coords in ipairs(spawns) do
                if _IsSpawnVisible(coords) then
                    visibleSpawnZones[zone] = true

                    -- instance spawn, draw entrance on map
                    local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
                    if dungeonLocation ~= nil then
                        for _, value in ipairs(dungeonLocation) do
                            QuestieMap:DrawManualIcon(data, value[1], value[2], value[3], typ)
                        end
                    -- world spawn
                    else
                        manualIcons[zone] = QuestieMap:DrawManualIcon(data, zone, coords[1], coords[2], typ)
                    end
                end
            end
        end
    end
    -- draw waypoints
    if npc.waypoints then
        for zone, waypoints in pairs(npc.waypoints) do
            if (visibleSpawnZones[zone] or (not npc.spawns) or (not npc.spawns[zone])) and
                (not ZoneDB:GetDungeonLocation(zone)) and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                if not manualIcons[zone] then
                    manualIcons[zone] = QuestieMap:DrawManualIcon(data, zone, waypoints[1][1][1], waypoints[1][1][2])
                end
                QuestieMap:DrawWaypoints(manualIcons[zone], waypoints, zone)
            end
        end
    end
end

-- Show object on map
-- This function does the same for manualFrames as similar functions in
-- QuestieQuest do for questIdFrames
---@param objectID number
function QuestieMap:ShowObject(objectID, icon, scale, title, body, disableShiftToRemove, typ)
    if type(objectID) ~= "number" then return end
    -- get the gameobject data
    local object = QuestieDB:GetObject(objectID)
    if not object or not object.spawns then return end

    -- create the icon data
    local data = {}
    -- hack: clean up this code, we shouldnt be using negative indexes
    if typ then
        data.id = object.id
    else
        data.id = -object.id
    end
    data.Icon = icon or "Interface\\WorldMap\\WorldMapPartyIcon"
    data.GetIconScale = function() return scale or Questie.db.profile.manualScale or 0.7 end
    data.IconScale = data:GetIconScale()
    data.Type = "manual"
    data.spawnType = "object"
    data.objectData = object
    data.Name = object.name
    data.IsObjectiveNote = false
    data.ManualTooltipData = {}
    data.ManualTooltipData.Title = title or (object.name .. " (object)")
    data.ManualTooltipData.Body = body or {
        { 'ID:', tostring(object.id) },
    }
    data.ManualTooltipData.disableShiftToRemove = disableShiftToRemove

    -- draw the notes
    for zone, spawns in pairs(object.spawns) do
        if (zone ~= nil and spawns ~= nil) then
            for _, coords in ipairs(spawns) do
                if _IsSpawnVisible(coords) then
                    -- instance spawn, draw entrance on map
                    local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
                    if dungeonLocation ~= nil then
                        for _, value in ipairs(dungeonLocation) do
                            QuestieMap:DrawManualIcon(data, value[1], value[2], value[3], typ)
                        end
                        -- world spawn
                    else
                        QuestieMap:DrawManualIcon(data, zone, coords[1], coords[2], typ)
                    end
                end
            end
        end
    end
end

function QuestieMap:DrawLineIcon(lineFrame, areaID, x, y)
    if type(areaID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error("Questie" .. ": AddWorldMapIconMap: 'AreaID', 'x' and 'y' must be numbers " .. areaID .. " " .. x .. " " .. y)
    end

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)

    HBDPins:AddWorldMapIconMap(Questie, lineFrame, uiMapId, x, y, HBD_PINS_WORLDMAP_SHOW_CURRENT)
end

-- Draw manually added NPC/object notes
-- TODO: item and custom notes
--@param data table<...> @A table created by the calling function, must contain `id`, `Name`, `GetIconScale()`, and `Type`
--@param AreaID number @The zone ID from the raw data
--@param x float @The X coordinate in 0-100 format
--@param y float @The Y coordinate in 0-100 format
function QuestieMap:DrawManualIcon(data, areaID, x, y, typ)
    if type(data) ~= "table" then
        error("Questie" .. ": AddWorldMapIconMap: must have some data")
    end
    if type(areaID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error("Questie" .. ": AddWorldMapIconMap: 'AreaID', 'x' and 'y' must be numbers " .. areaID .. " " .. x .. " " .. y)
    end
    if type(data.id) ~= "number" or type(data.id) ~= "number" then
        error("Questie" .. "Data.id must be set to the NPC or object ID!")
    end

    -- this needs to be refactored. Fix the capitalization. Who made this id instead of Id?
    data.Id = data.id

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    if (not uiMapId) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawManualIcon] No UiMapID for areaId:", areaID, tostring(data.Name))
        return nil, nil
    end
    -- set the icon
    local texture = data.Icon or "Interface\\WorldMap\\WorldMapPartyIcon"
    -- Save new zone ID format, used in QuestieFramePool
    -- create a list for all frames belonging to a NPC (id > 0) or an object (id < 0)
    typ = typ or "any"
    if not QuestieMap.manualFrames[typ] then
        QuestieMap.manualFrames[typ] = {}
    end
    if not QuestieMap.manualFrames[typ][data.id] then
        QuestieMap.manualFrames[typ][data.id] = {}
    end

    -- create the map icon
    local icon = QuestieFramePool:GetFrame()
    icon.isManualIcon = true
    icon.data = data
    icon.x = x
    icon.y = y
    icon.AreaID = areaID -- used by QuestieFramePool
    icon.UiMapID = uiMapId
    icon.miniMapIcon = false;
    icon.texture:SetTexture(texture)
    if data.TexCoords then
        icon.texture:SetTexCoord(unpack(data.TexCoords))
    else
        icon.texture:SetTexCoord(0, 1, 0, 1)
    end
    if not QuestieCompat.Is335 then
        icon.texture:SetSnapToPixelGrid(false)
        icon.texture:SetTexelSnappingBias(0)
    end
    icon:SetWidth(16 * (data:GetIconScale() or 0.7))
    icon:SetHeight(16 * (data:GetIconScale() or 0.7))

    -- add the map icon
    QuestieMap:QueueDraw(QuestieMap.ICON_MAP_TYPE, Questie, icon, icon.UiMapID, x / 100, y / 100, 3) -- showFlag)
    tinsert(QuestieMap.manualFrames[typ][data.id], icon:GetName())

    -- create the minimap icon
    local iconMinimap = QuestieFramePool:GetFrame()
    iconMinimap.isManualIcon = true
    local colorsMinimap = { 1, 1, 1 }
    if data.IconColor ~= nil and Questie.db.profile.questMinimapObjectiveColors then
        colorsMinimap = data.IconColor
    end
    iconMinimap:SetWidth(16 * ((data:GetIconScale() or 0.7) * (Questie.db.profile.globalMiniMapTownsfolkScale or 0.7)))
    iconMinimap:SetHeight(16 * ((data:GetIconScale() or 0.7) * (Questie.db.profile.globalMiniMapTownsfolkScale or 0.7)))
    iconMinimap.data = data
    iconMinimap.x = x
    iconMinimap.y = y
    iconMinimap.AreaID = areaID -- used by QuestieFramePool
    iconMinimap.UiMapID = uiMapId
    iconMinimap.texture:SetTexture(texture)
    if data.TexCoords then
        iconMinimap.texture:SetTexCoord(unpack(data.TexCoords))
    else
        iconMinimap.texture:SetTexCoord(0, 1, 0, 1)
    end
    if not QuestieCompat.Is335 then
        icon.texture:SetSnapToPixelGrid(false)
        icon.texture:SetTexelSnappingBias(0)
    end
    iconMinimap.texture:SetVertexColor(colorsMinimap[1], colorsMinimap[2], colorsMinimap[3], 1);
    iconMinimap.texture.r = colorsMinimap[1]
    iconMinimap.texture.g = colorsMinimap[2]
    iconMinimap.texture.b = colorsMinimap[3]
    iconMinimap.texture.a = 1
    iconMinimap.miniMapIcon = true;

    if (not iconMinimap.FadeLogic) then
        iconMinimap.SetFade = _MinimapIconSetFade
        iconMinimap.FadeLogic = _MinimapIconFadeLogic
    end

    -- add the minimap icon
    QuestieMap:QueueDraw(QuestieMap.ICON_MINIMAP_TYPE, Questie, iconMinimap, iconMinimap.UiMapID, x / 100, y / 100, true, true);
    tinsert(QuestieMap.manualFrames[typ][data.id], iconMinimap:GetName())

    -- make sure notes are only shown when they are supposed to
    if (not Questie.db.profile.enabled) then -- TODO: or (not Questie.db.profile.manualNotes)
        icon:FakeHide()
        iconMinimap:FakeHide()
    else
        if (not Questie.db.profile.enableMapIcons) then
            icon:FakeHide()
        end
        if (not Questie.db.profile.enableMiniMapIcons) then
            iconMinimap:FakeHide()
        end
    end

    QuestieMap.utils:RescaleIcon(icon)

    -- return the frames in case they need to be stored seperately from QuestieMap.manualFrames
    return icon, iconMinimap;
end

--A layer to keep the area convertion away from the other parts of the code
--coordinates need to be 0-1 instead of 0-100
--showFlag isn't required but may want to be Modified
---@return IconFrame, IconFrame
_MinimapIconSetFade = function(self, value)
    if self.lastGlowFade ~= value then
        self.lastGlowFade = value
        if self.glowTexture then
            local r, g, b = self.glowTexture:GetVertexColor()
            self.glowTexture:SetVertexColor(r, g, b, value)
        end

        local r = self.texture.r
        local g = self.texture.g
        local b = self.texture.b
        if r == nil or g == nil or b == nil then
            r, g, b = self.texture:GetVertexColor()
            r = r or 1
            g = g or 1
            b = b or 1
            self.texture.r = r
            self.texture.g = g
            self.texture.b = b
        end

        self.texture.a = value
        self.texture:SetVertexColor(r, g, b, value)
    end
end

_MinimapIconFadeLogic = function(self)
    local profile = Questie.db.profile
    if self.miniMapIcon and self.x and self.y and self.texture and self.UiMapID and self.texture.SetVertexColor and HBD and HBD.GetPlayerZonePosition and QuestieLib and QuestieLib.Euclid then
        if (QuestieMap.playerX and QuestieMap.playerY) then
            local x, y
            if not self.worldX then
                x, y = HBD:GetWorldCoordinatesFromZone(self.x / 100, self.y / 100, self.UiMapID)
                self.worldX = x
                self.worldY = y
            else
                x = self.worldX
                y = self.worldY
            end
            if (x and y) then
                --Very small value before, hard to work with.
                local distance = QuestieLib:Euclid(QuestieMap.playerX, QuestieMap.playerY, x, y) / 10;

                if (distance > profile.fadeLevel) then
                    local fade = 1 - (math.min(10, (distance - profile.fadeLevel)) * normalizedValue);
                    self:SetFade(fade)
                elseif (distance < profile.fadeOverPlayerDistance) and profile.fadeOverPlayer then
                    local fadeAmount = profile.fadeOverPlayerLevel + distance * (1 - profile.fadeOverPlayerLevel) / profile.fadeOverPlayerDistance
                    -- local fadeAmount = math.max(fadeAmount, 0.5);
                    if self.faded and fadeAmount > profile.iconFadeLevel then
                        fadeAmount = profile.iconFadeLevel
                    end
                    self:SetFade(fadeAmount)
                else
                    if self.faded then
                        self:SetFade(profile.iconFadeLevel)
                    else
                        self:SetFade(1)
                    end
                end
            end
        else
            if self.faded then
                self:SetFade(profile.iconFadeLevel)
            else
                self:SetFade(1)
            end
        end
    end
end

function QuestieMap:DrawWorldIcon(data, areaID, x, y, phase, showFlag)
    if type(data) ~= "table" then
        error("Questie" .. ": AddWorldMapIconMap: must have some data")
    end

    if not Phasing.IsSpawnVisible(phase) then
        Questie:Debug(Questie.DEBUG_SPAM, "Skipping invisible phase", phase)
        return nil, nil
    end

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    if (not uiMapId) then
        local parentMapId
        local mapInfo = C_Map.GetMapInfo(areaID)
        if mapInfo then
            parentMapId = mapInfo.parentMapID
        else
            parentMapId = ZoneDB:GetParentZoneId(areaID)
        end

        if (not parentMapId) then
            error("No UiMapID or fitting parentAreaId for areaId : " .. areaID .. " - " .. tostring(data.Name))
            return nil, nil
        else
            areaID = parentMapId
            uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
        end
    end

    if (not showFlag) then
        showFlag = HBD_PINS_WORLDMAP_SHOW_WORLD
    end

    --print("UIMAPID: " .. tostring(uiMapId))
    if not uiMapId then
        --ZoneDB:GetUiMapIdByAreaId
        error("No UiMapID or fitting uiMapId for areaId : " .. areaID .. " - " .. tostring(data.Name))
        return nil, nil
    end

    local floatOnEdge = true

    ---@type IconFrame
    local iconMap = QuestieFramePool:GetFrame()
    iconMap.data = data
    iconMap.x = x
    iconMap.y = y
    iconMap.AreaID = areaID
    iconMap.UiMapID = uiMapId
    iconMap.miniMapIcon = false;
    iconMap:UpdateTexture(Questie.usedIcons[data.Icon]);

    ---@type IconFrame
    local iconMinimap = QuestieFramePool:GetFrame()
    iconMinimap.data = data
    iconMinimap.x = x
    iconMinimap.y = y
    iconMinimap.AreaID = areaID
    iconMinimap.UiMapID = uiMapId
    --data.refMiniMap = iconMinimap -- used for removing
    --Are we a minimap note?
    iconMinimap.miniMapIcon = true;
    iconMinimap:UpdateTexture(Questie.usedIcons[data.Icon]);

    if (not iconMinimap.FadeLogic) then
        iconMinimap.SetFade = _MinimapIconSetFade
        iconMinimap.FadeLogic = _MinimapIconFadeLogic

        -- We do not want to hook the OnUpdate again!
        -- iconMinimap:SetScript("OnUpdate", )
    end

    QuestieMap:QueueDraw(QuestieMap.ICON_MINIMAP_TYPE, Questie, iconMinimap, uiMapId, x / 100, y / 100, true, floatOnEdge)
    QuestieMap:QueueDraw(QuestieMap.ICON_MAP_TYPE, Questie, iconMap, uiMapId, x / 100, y / 100, showFlag)
    local r, g, b = iconMinimap.texture:GetVertexColor()
    QuestieDBMIntegration:RegisterHudQuestIcon(tostring(iconMap), data.Icon, uiMapId, x, y, r, g, b)

    if not QuestieMap.questIdFrames[data.Id] then
        QuestieMap.questIdFrames[data.Id] = {}
    end

    -- tinsert(QuestieMap.questIdFrames[data.Id], iconMap:GetName())
    -- tinsert(QuestieMap.questIdFrames[data.Id], iconMinimap:GetName())
    QuestieMap.questIdFrames[data.Id][iconMap:GetName()] = iconMap:GetName()
    QuestieMap.questIdFrames[data.Id][iconMinimap:GetName()] = iconMinimap:GetName()

    if iconMap:ShouldBeHidden() then
        iconMap:FakeHide()
    end

    if iconMinimap:ShouldBeHidden() then
        iconMinimap:FakeHide()
    end

    return iconMap, iconMinimap;
end

--- The return type also contains, distance, zone and type but we never really use it.
---@type table<QuestId, {x:X, y:Y}>
local closestStarter = {}
function QuestieMap:FindClosestStarter()
    local playerX, playerY, _ = HBD:GetPlayerWorldPosition();
    local playerZone = HBD:GetPlayerWorldPosition();
    for questId in pairs(QuestiePlayer.currentQuestlog) do
        if (not closestStarter[questId]) then
            local quest = QuestieDB.GetQuest(questId);
            if quest then
                closestStarter[questId] = {
                    distance = 999999,
                    x = -1,
                    y = -1,
                    zone = -1,
                    type = "",
                }
                for starterType, starters in pairs(quest.Starts) do
                    if (starterType == "GameObject") then
                        for _, ObjectID in ipairs(starters or {}) do
                            local obj = QuestieDB:GetObject(ObjectID)
                            if (obj ~= nil and obj.spawns ~= nil) then
                                for Zone, Spawns in pairs(obj.spawns) do
                                    if (Zone ~= nil and Spawns ~= nil) then
                                        for _, coords in ipairs(Spawns) do
                                            if _IsSpawnVisible(coords) then
                                                if (coords[1] == -1 or coords[2] == -1) then -- instace locations
                                                    local dungeonLocation = ZoneDB:GetDungeonLocation(Zone)
                                                    if dungeonLocation ~= nil then
                                                        for _, value in ipairs(dungeonLocation) do
                                                            if (value[1] and value[2]) then
                                                                local x, y, _ = HBD:GetWorldCoordinatesFromZone(value[1] / 100, value[2] / 100, ZoneDB:GetUiMapIdByAreaId(value[3]))
                                                                if (x and y) then
                                                                    local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                                    if (closestStarter[questId].distance > distance) then
                                                                        closestStarter[questId].distance = distance;
                                                                        closestStarter[questId].x = x;
                                                                        closestStarter[questId].y = y;
                                                                        closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                                        closestStarter[questId].type = "GameObject - " .. obj.name;
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                else
                                                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(Zone)
                                                    local x, y, _ = HBD:GetWorldCoordinatesFromZone(coords[1] / 100, coords[2] / 100, uiMapId)
                                                    if (x and y) then
                                                        local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                        if (closestStarter[questId].distance > distance) then
                                                            closestStarter[questId].distance = distance;
                                                            closestStarter[questId].x = x;
                                                            closestStarter[questId].y = y;
                                                            closestStarter[questId].zone = uiMapId
                                                            closestStarter[questId].type = "GameObject - " .. obj.name;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif (starterType == "NPC") then
                        for _, NPCID in ipairs(starters or {}) do
                            local NPC = QuestieDB:GetNPC(NPCID)
                            if (NPC ~= nil and NPC.spawns ~= nil and NPC.friendly) then
                                for Zone, Spawns in pairs(NPC.spawns) do
                                    if (Zone ~= nil and Spawns ~= nil) then
                                        for _, coords in ipairs(Spawns) do
                                            if _IsSpawnVisible(coords) then
                                                if (coords[1] == -1 or coords[2] == -1) then
                                                    local dungeonLocation = ZoneDB:GetDungeonLocation(Zone)
                                                    if dungeonLocation ~= nil then
                                                        for _, value in ipairs(dungeonLocation) do
                                                            if (value[1] and value[2]) then
                                                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(value[3])
                                                                local x, y, _ = HBD:GetWorldCoordinatesFromZone(value[1] / 100, value[2] / 100, uiMapId)
                                                                if (x and y) then
                                                                    local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                                    if (closestStarter[questId].distance > distance) then
                                                                        closestStarter[questId].distance = distance;
                                                                        closestStarter[questId].x = x;
                                                                        closestStarter[questId].y = y;
                                                                        closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                                        closestStarter[questId].type = "NPC - " .. NPC.name;
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                elseif (coords[1] and coords[2]) then
                                                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(Zone)
                                                    local x, y, _ = HBD:GetWorldCoordinatesFromZone(coords[1] / 100, coords[2] / 100, uiMapId)
                                                    if (x and y) then
                                                        local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                        if (closestStarter[questId].distance > distance) then
                                                            closestStarter[questId].distance = distance;
                                                            closestStarter[questId].x = x;
                                                            closestStarter[questId].y = y;
                                                            closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                            closestStarter[questId].type = "NPC - " .. NPC.name;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if (closestStarter[questId].x == -1) then
                    closestStarter[questId].distance = 0;
                    closestStarter[questId].x = playerX;
                    closestStarter[questId].y = playerY;
                    closestStarter[questId].zone = playerZone;
                    closestStarter[questId].type = "player";
                end
            end
        end
    end
    return closestStarter;
end

function QuestieMap:GetNearestSpawn(objective)
    if not objective then
        return nil
    end
    local playerX, playerY, playerI = HBD:GetPlayerWorldPosition()
    if (not playerX) or (not playerY) then
        playerX, playerY = 0, 0
    end
    local bestDistance = 999999999
    local bestSpawn, bestSpawnZone, bestSpawnId, bestSpawnType, bestSpawnName
    -- TODO: This is just a temporary workaround - We have to find out why "objective.spawnList" can be nil
    if objective and objective.spawnList and next(objective.spawnList) then
        for id, spawnData in pairs(objective.spawnList) do
            for zone, spawns in pairs(spawnData.Spawns) do
                for _, spawn in pairs(spawns) do
                    if _IsSpawnVisible(spawn) then
                        local dist, resolvedSpawn, resolvedZone = _GetDistanceToNearestResolvedSpawn(zone, spawn, playerX, playerY, playerI)
                        if dist and dist < bestDistance then
                            bestDistance = dist
                            bestSpawn = resolvedSpawn
                            bestSpawnZone = resolvedZone
                            bestSpawnId = id
                            bestSpawnType = spawnData.Type
                            bestSpawnName = spawnData.Name
                        end
                    end
                end
            end
        end
    end
    return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnId, bestSpawnType, bestDistance
end

---@param quest Quest
function QuestieMap:GetNearestQuestSpawn(quest)
    if not quest then
        return nil
    end
    if quest:IsComplete() == 1 then
        local finisherSpawns
        local finisherName
        if quest.Finisher ~= nil then
            if quest.Finisher.Type == "monster" then
                --finisher = QuestieDB:GetNPC(quest.Finisher.Id)
                finisherSpawns, finisherName = QuestieDB.QueryNPCSingle(quest.Finisher.Id, "spawns"), QuestieDB.QueryNPCSingle(quest.Finisher.Id, "name")
            elseif quest.Finisher.Type == "object" then
                --finisher = QuestieDB:GetObject(quest.Finisher.Id)
                finisherSpawns, finisherName = QuestieDB.QueryObjectSingle(quest.Finisher.Id, "spawns"), QuestieDB.QueryObjectSingle(quest.Finisher.Id, "name")
            end
        end
        if finisherSpawns then -- redundant code
            local bestDistance = 999999999
            local playerX, playerY, playerI = HBD:GetPlayerWorldPosition()
            if (not playerX) or (not playerY) then
                playerX, playerY = 0, 0
            end
            local bestSpawn, bestSpawnZone, bestSpawnType, bestSpawnName
            for zone, spawns in pairs(finisherSpawns) do
                for _, spawn in pairs(spawns) do
                    if _IsSpawnVisible(spawn) then
                        local dist, resolvedSpawn, resolvedZone = _GetDistanceToNearestResolvedSpawn(zone, spawn, playerX, playerY, playerI)
                        if dist and dist < bestDistance then
                            bestDistance = dist
                            bestSpawn = resolvedSpawn
                            bestSpawnZone = resolvedZone
                            bestSpawnType = quest.Finisher.Type
                            bestSpawnName = finisherName
                        end
                    end
                end
            end
            return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnType, bestDistance
        end
        return nil
    end

    local bestDistance = 999999999
    local bestSpawn, bestSpawnZone, bestSpawnId, bestSpawnType, bestSpawnName

    for _, objective in pairs(quest.Objectives) do
        local spawn, zone, Name, id, Type, dist = QuestieMap:GetNearestSpawn(objective)
        if spawn and dist < bestDistance and ((not objective.Needed) or objective.Needed ~= objective.Collected) then
            bestDistance = dist
            bestSpawn = spawn
            bestSpawnZone = zone
            bestSpawnId = id
            bestSpawnType = Type
            bestSpawnName = Name
        end
    end

    for _, objective in pairs(quest.SpecialObjectives) do
        local spawn, zone, Name, id, Type, dist = QuestieMap:GetNearestSpawn(objective)
        if spawn and dist < bestDistance and ((not objective.Needed) or objective.Needed ~= objective.Collected) then
            bestDistance = dist
            bestSpawn = spawn
            bestSpawnZone = zone
            bestSpawnId = id
            bestSpawnType = Type
            bestSpawnName = Name
        end
    end
    return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnId, bestSpawnType, bestDistance
end

QuestieMap.zoneWaypointColorOverrides = { -- this is used when the default orange color doesn't work well in specific zones. Not needed after 769ea832ff772b10c57351eb199348393625a99b
    --    [14] = {0,0.1,0.9,0.7}, -- durotar
    --    [38] = {0,0.1,0.9,0.7} -- loch modan
}

QuestieMap.zoneWaypointHoverColorOverrides = {
    --    [14] = {0,0.6,1,1}, -- durotar
    --    [38] = {0,0.6,1,1} -- loch modan
}

function QuestieMap:DrawWaypoints(icon, waypoints, zone, color)
    if waypoints and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then -- check that waypoint data actually exists
        local shouldBeHidden = icon:ShouldBeHidden()
        local lineFrames = QuestieFramePool:CreateWaypoints(icon, waypoints, nil, color or QuestieMap.zoneWaypointColorOverrides[zone], zone)
        for _, lineFrame in ipairs(lineFrames) do
            QuestieMap:DrawLineIcon(lineFrame, zone, waypoints[1][1][1], waypoints[1][1][2])
            if shouldBeHidden then
                lineFrame:FakeHide()
            end
        end
    end
end
