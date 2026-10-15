---@class TrackerQuestOrder
local TrackerQuestOrder = QuestieLoader:CreateModule("TrackerQuestOrder")

---@type Sorter
local Sorter = QuestieLoader:ImportModule("Sorter")
---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
local TrackerData = QuestieLoader:ImportModule("TrackerData")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local C_Timer = QuestieCompat.C_Timer
local C_Map = QuestieCompat.C_Map
local tinsert = table.insert

-- Quest ordering and its refresh timers share one lifecycle. Sorter contains
-- the static comparison strategies; TrackerUtils supplies localized zone names.
local proximityTimer

---@return table|nil position Returns Players current X/Y coordinates or nil if a Players postion can't be determined
local function _GetWorldPlayerPosition()
    -- Turns coords into 'world' coords so it can be compared with any coords in another zone
    local mapPosition, mapID = QuestieCoords.GetPlayerMapPosition()
    if not mapID or not mapPosition or type(mapPosition.x) ~= "number" or type(mapPosition.y) ~= "number" then
        return nil
    end

    local worldInstance, worldPosition = C_Map.GetWorldPosFromMapPos(mapID, mapPosition)
    if not worldPosition or type(worldPosition.x) ~= "number" or type(worldPosition.y) ~= "number" then
        return nil
    end
    local position = {
        x = worldPosition.x,
        y = worldPosition.y,
        worldInstance = worldInstance,
        mapID = mapID
    }

    return position
end

---@param x1 number Current Position X
---@param y1 number Current Position Y
---@param x2 number Previous Position X
---@param y2 number Previous Position Y
---@return number Distance @Distance between Current and Previous X/Y coordinates
local function _GetDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

---@param uiMapId number Continent ID number
---@return string Continent Returns Continent Name or "UNKNOWN"
local function _GetContinent(uiMapId)
    if (not uiMapId) then
        return "UNKNOWN"
    end

    local useUiMapId = uiMapId
    local mapInfo = C_Map.GetMapInfo(useUiMapId)
    while mapInfo and mapInfo.mapType ~= 2 and mapInfo.parentMapID ~= useUiMapId do
        useUiMapId = mapInfo.parentMapID
        mapInfo = C_Map.GetMapInfo(useUiMapId)
    end

    if mapInfo ~= nil then
        return mapInfo.name
    else
        return "UNKNOWN"
    end
end

---@param quest Quest
---@return number|nil distance
---@return AreaId|nil zone
---@return string|nil continent
local function _GetNearestQuestSortData(quest)
    if not quest or quest.NativeOnly then
        return nil, nil, nil
    end

    local _, zone, _, _, _, distance = QuestieMap:GetNearestQuestSpawn(quest)
    if not zone then
        return distance, nil, nil
    end

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
    return distance, zone, uiMapId and _GetContinent(uiMapId) or nil
end

---@param sortedQuestIds QuestId[]
---@param orderCopy QuestId[]
---@return boolean
local function _DidQuestOrderChange(sortedQuestIds, orderCopy)
    if #sortedQuestIds ~= #orderCopy then
        return true
    end
    for index = 1, #sortedQuestIds do
        if orderCopy[index] ~= sortedQuestIds[index] then
            return true
        end
    end

    return false
end

---@param zoneOrSort ZoneOrSort
---@param questId QuestId
---@return string zoneName Returns the zone name for a quest based on the quests zoneOrSort value and the current tracker sorting method. If the quest has no explicit zone or category, it will return "Unknown Zone".
--- If the sorting method is not byZone, it will return a custom zone name based on the sorting type.
local function _GetZoneName(zoneOrSort, questId)
    if not zoneOrSort then
        return "Unknown Zone"
    end

    local zoneName
    local sortObj = Questie.db.profile.trackerSortObjectives
    if sortObj == "byZone" or sortObj == "byZonePlayerProximity" or sortObj == "byZonePlayerProximityReversed" then
        if (zoneOrSort) > 0 then
            -- Valid ZoneID
            zoneName = TrackerUtils:GetZoneNameByID(zoneOrSort)
        elseif (zoneOrSort) < 0 then
            -- Valid CategoryID
            zoneName = TrackerUtils:GetCategoryNameByID(zoneOrSort)
        else
            -- The quest has no explicit zone or category. Fallback to "Unknown Zone"
            zoneName = "Unknown Zone"
            Questie.Debug(Questie.DEBUG_CRITICAL, "[TrackerQuestOrder:_GetZoneName] zoneOrSort", zoneOrSort, "of quest", questId, "is not in the Database!")
        end
    else
        -- Let's create custom Zones based on Sorting type.
        if sortObj == "byComplete" then
            zoneName = "Quests (By %% Complete)"
        elseif sortObj == "byCompleteReversed" then
            zoneName = "Quests (By %% Complete Reversed)"
        elseif sortObj == "byLevel" then
            zoneName = "Quests (By Level)"
        elseif sortObj == "byLevelReversed" then
            zoneName = "Quests (By Level Reversed)"
        elseif sortObj == "byProximity" then
            zoneName = "Quests (By Proximity)"
        elseif sortObj == "byProximityReversed" then
            zoneName = "Quests (By Proximity Reversed)"
        end
    end
    return zoneName or "Unknown Zone"
end

function TrackerQuestOrder.GetQuestGroupName(quest)
    local mode = Questie.db.profile.trackerSortObjectives
    if quest.NativeOnly and (mode == "byZone" or mode == "byZonePlayerProximity" or mode == "byZonePlayerProximityReversed") then
        return quest.zoneName
    end
    return _GetZoneName(quest.zoneOrSort or 0, quest.Id)
end

local function _CollectQuestDetails(quests)
    ---@type QuestId[]
    local sortedQuestIds = {}
    ---@type table<QuestId, QuestSortDetails>
    local questDetails = {}

    -- Update quest objectives
    for questId, quest in pairs(quests or TrackerData.Refresh()) do
        if quest then
            tinsert(sortedQuestIds, questId)

            local percent = 0
            if quest:IsComplete() == 1 or ((not quest.NativeOnly) and (not next(quest.Objectives))) then
                percent = 1
            else
                local count = 0
                for _, Objective in pairs(quest.Objectives) do
                    local needed = Objective.Needed or 0
                    if quest.NativeOnly then
                        percent = percent + (Objective.Completed and 1 or (needed > 0 and math.min((Objective.Collected or 0) / needed, 1) or 0))
                    else
                        percent = percent + (needed > 0 and (Objective.Collected or 0) / needed or (Objective.Completed and 1 or 0))
                    end
                    count = count + 1
                end
                percent = count > 0 and percent / count or 0
            end

            questDetails[questId] = {
                quest = quest,
                zoneName = TrackerQuestOrder.GetQuestGroupName(quest),
                questCompletePercent = percent,
            }
        end
    end

    return sortedQuestIds, questDetails
end

local function _IsProximitySort(sortObj)
    return sortObj == "byProximity" or sortObj == "byProximityReversed"
        or sortObj == "byZonePlayerProximity" or sortObj == "byZonePlayerProximityReversed"
end

local function _SortByProximity(sortedQuestIds, questDetails, sortObj)
    local byZone = sortObj == "byZonePlayerProximity" or sortObj == "byZonePlayerProximityReversed"
    local reversed = sortObj == "byProximityReversed" or sortObj == "byZonePlayerProximityReversed"
    local continent = _GetContinent(C_Map.GetBestMapForUnit("player"))
    local proximity = {}
    for _, questId in ipairs(sortedQuestIds) do
        local distance, _, questContinent = _GetNearestQuestSortData(questDetails[questId].quest)
        proximity[questId] = {distance = distance, continent = questContinent}
    end

    table.sort(sortedQuestIds, function(a, b)
        if byZone and questDetails[a].zoneName ~= questDetails[b].zoneName then
            -- Reversing proximity never reverses the zone headings.
            return questDetails[a].zoneName < questDetails[b].zoneName
        end
        local aHere, bHere = proximity[a].continent == continent, proximity[b].continent == continent
        if aHere ~= bHere then
            if reversed then return bHere end
            return aHere
        end
        local aDistance, bDistance = proximity[a].distance, proximity[b].distance
        if aDistance ~= bDistance then
            if aDistance == nil then return reversed end
            if bDistance == nil then return not reversed end
            if reversed then return aDistance > bDistance end
            return aDistance < bDistance
        end
        local aLevel, bLevel = questDetails[a].quest.level, questDetails[b].quest.level
        if aLevel ~= bLevel then
            if reversed then return aLevel > bLevel end
            return aLevel < bLevel
        end
        -- Stable ties avoid needless renders when distances and levels are equal.
        return Sorter.CompareBySuffix(a, b)
    end)
end

local function _StopProximityTimer()
    if proximityTimer then
        proximityTimer.ticker:Cancel()
        proximityTimer = nil
    end
    TrackerQuestOrder.FilterProximityTimer = nil
end

local function _RefreshProximityOrder(state)
    -- A cancelled callback must never affect a replacement timer.
    if proximityTimer ~= state then return end
    if Questie.db.profile.trackerSortObjectives ~= state.sortObj
        or not Questie.db.profile.trackerEnabled or IsInInstance() then
        _StopProximityTimer()
        return
    end
    if state.updatePending then return end

    local position = _GetWorldPlayerPosition()
    if not position then return end
    local previous = state.playerPosition
    if previous and previous.worldInstance == position.worldInstance and previous.mapID == position.mapID
        and _GetDistance(position.x, position.y, previous.x, previous.y) <= 0.01 then
        return
    end
    state.playerPosition = position

    -- Read the live log and distances, rather than the first render's captured data.
    -- Sort a separate list so movement cannot mutate an in-progress render.
    local sortedQuestIds, questDetails = _CollectQuestDetails()
    _SortByProximity(sortedQuestIds, questDetails, state.sortObj)
    if not _DidQuestOrderChange(sortedQuestIds, state.sortedQuestIds) then return end

    state.updatePending = true
    local version = state.version
    QuestieCombatQueue:Queue(function()
        state.updatePending = false
        if proximityTimer ~= state or state.version ~= version
            or Questie.db.profile.trackerSortObjectives ~= state.sortObj
            or not Questie.db.profile.trackerEnabled or IsInInstance() then
            return
        end
        TrackerQuestOrder.FilterProximityTimer = true
        QuestieTracker:Update()
    end)
end

local function _UpdateProximityTimer(sortObj, sortedQuestIds)
    if not _IsProximitySort(sortObj) or not Questie.db.profile.trackerEnabled or IsInInstance() then
        _StopProximityTimer()
        return
    end
    if proximityTimer and proximityTimer.sortObj ~= sortObj then
        _StopProximityTimer()
    end
    if not proximityTimer then
        local state = {sortObj = sortObj, version = 0}
        proximityTimer = state
        state.ticker = C_Timer.NewTicker(5.0, function() _RefreshProximityOrder(state) end)
    end
    -- Keep the running timer tied to the latest renderer snapshot. A normal event
    -- render also makes any previously queued proximity render redundant.
    proximityTimer.version = proximityTimer.version + 1
    proximityTimer.sortedQuestIds = sortedQuestIds
    proximityTimer.playerPosition = _GetWorldPlayerPosition()
end

---@return QuestId[] sortedQuestIds
---@return table<QuestId, QuestSortDetails> questDetails
function TrackerQuestOrder:GetSortedQuestIds(quests)
    local sortedQuestIds, questDetails = _CollectQuestDetails(quests)
    local sortObj = Questie.db.profile.trackerSortObjectives

    if sortObj == "byZone" then
        Sorter.byZone(sortedQuestIds, questDetails)
    elseif sortObj == "byComplete" then
        Sorter.byComplete(sortedQuestIds, questDetails)
    elseif sortObj == "byCompleteReversed" then
        Sorter.byCompleteReverse(sortedQuestIds, questDetails)
    elseif sortObj == "byLevel" then
        Sorter.byLevel(sortedQuestIds, questDetails)
    elseif sortObj == "byLevelReversed" then
        Sorter.byLevelReverse(sortedQuestIds, questDetails)
    elseif _IsProximitySort(sortObj) then
        _SortByProximity(sortedQuestIds, questDetails, sortObj)
    end

    _UpdateProximityTimer(sortObj, sortedQuestIds)
    return sortedQuestIds, questDetails
end
