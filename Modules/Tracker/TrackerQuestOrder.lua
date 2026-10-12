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
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
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
local questProximityTimer
local questZoneProximityTimer

---@return table|nil position Returns Players current X/Y coordinates or nil if a Players postion can't be determined
local function _GetWorldPlayerPosition()
    -- Turns coords into 'world' coords so it can be compared with any coords in another zone
    local mapPosition, mapID = QuestieCoords.GetPlayerMapPosition()
    if (not mapPosition) or (not mapPosition.x) then
        return nil
    end

    local worldPosition = select(2, C_Map.GetWorldPosFromMapPos(mapID, mapPosition))
    local position = {
        x = worldPosition.x,
        y = worldPosition.y
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
    if not quest then
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

---@return table sortedQuestIds Table with sorted Quest ID's by Sort Type
---@return table questDetails Table with raw quest table from QuestiePlayer.currentQuestLog, percentage completed value per quest, and a "translated" zoneName
function TrackerQuestOrder:GetSortedQuestIds()
    ---@type QuestId[]
    local sortedQuestIds = {}
    ---@type table<QuestId, QuestSortDetails>
    local questDetails = {}
    local sortObj = Questie.db.profile.trackerSortObjectives

    -- Update quest objectives
    for questId, quest in pairs(QuestiePlayer.currentQuestlog) do
        if quest then
            tinsert(sortedQuestIds, questId)

            local percent = 0
            if quest:IsComplete() == 1 or (not next(quest.Objectives)) then
                percent = 1
            else
                local count = 0
                for _, Objective in pairs(quest.Objectives) do
                    percent = percent + (Objective.Collected / Objective.Needed)
                    count = count + 1
                end
                percent = percent / count
            end

            questDetails[questId] = {
                quest = quest,
                zoneName = _GetZoneName(quest.zoneOrSort, questId),
                questCompletePercent = percent,
            }
        end
    end

    -- Quests and objectives sort
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
    elseif sortObj == "byZonePlayerProximity" or sortObj == "byZonePlayerProximityReversed" then
        local toSort = {}
        local continent = _GetContinent(C_Map.GetBestMapForUnit("player"))

        for _, questId in pairs(sortedQuestIds) do
            local sortData = {}
            sortData.questId = questId
            sortData.q = questDetails[questId].quest
            local distance, zone, questContinent = _GetNearestQuestSortData(sortData.q)
            sortData.distance = distance
            sortData.zone = zone
            sortData.continent = questContinent
            toSort[questId] = sortData
        end

        local sorter = function(a, b)
            local qAZone = questDetails[a].zoneName
            local qBZone = questDetails[b].zoneName

            -- If same Zone as Player then sort by Proximity
            if qAZone == qBZone then
                a = toSort[a]
                b = toSort[b]
                if ((continent == a.continent) and (continent == b.continent)) or ((continent ~= a.continent) and (continent ~= b.continent)) then
                    if a.distance == b.distance then
                        -- Same distance then sort by Level
                        return a.q and b.q and a.q.level < b.q.level
                    end

                    if not a.distance and b.distance then
                        return false
                    elseif a.distance and not b.distance then
                        return true
                    end

                    return a.distance < b.distance
                elseif (continent == a.continent) and (continent ~= b.continent) then
                    return true
                elseif (continent ~= a.continent) and (continent == b.continent) then
                    return false
                end
            else
                return qAZone < qBZone
            end
        end

        local sorterReversed = function(a, b)
            local qAZone = questDetails[a].zoneName
            local qBZone = questDetails[b].zoneName

            -- If same Zone as Player then sort by Proximity
            if qAZone == qBZone then
                a = toSort[a]
                b = toSort[b]
                if ((continent == a.continent) and (continent == b.continent)) or ((continent ~= a.continent) and (continent ~= b.continent)) then
                    if a.distance == b.distance then
                        -- Same distance then sort by Level
                        return a.q and b.q and a.q.level > b.q.level
                    end

                    if not a.distance and b.distance then
                        return true
                    elseif a.distance and not b.distance then
                        return false
                    end

                    return a.distance > b.distance
                elseif (continent == a.continent) and (continent ~= b.continent) then
                    return false
                elseif (continent ~= a.continent) and (continent == b.continent) then
                    return true
                end
            else
                return qAZone < qBZone
            end
        end

        if sortObj == "byZonePlayerProximity" then
            table.sort(sortedQuestIds, sorter)
        else
            table.sort(sortedQuestIds, sorterReversed)
        end

        if not questZoneProximityTimer and not IsInInstance() then
            -- Check location often and update if you've moved
            Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Zone Proximity Timer Started!")

            local playerPosition
            questZoneProximityTimer = C_Timer.NewTicker(5.0, function()
                if IsInInstance() and questZoneProximityTimer then
                    Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Zone Proximity Timer Stopped!")
                    questZoneProximityTimer:Cancel()
                    questZoneProximityTimer = nil
                else
                    local position = _GetWorldPlayerPosition()
                    if position then
                        local distance = playerPosition and _GetDistance(position.x, position.y, playerPosition.x, playerPosition.y)
                        if not distance or distance > 0.01 then -- Position has changed
                            Questie.Debug(Questie.DEBUG_SPAM, "[TrackerQuestOrder:GetSortedQuestIds] - Zone Proximity Timer Updated!")
                            playerPosition = position
                            local orderCopy = {}

                            for index, val in pairs(sortedQuestIds) do
                                orderCopy[index] = val
                            end

                            if sortObj == "byZonePlayerProximity" then
                                table.sort(sortedQuestIds, sorter)
                            else
                                table.sort(sortedQuestIds, sorterReversed)
                            end

                            if _DidQuestOrderChange(sortedQuestIds, orderCopy) then
                                QuestieCombatQueue:Queue(function()
                                    TrackerQuestOrder.FilterProximityTimer = true
                                    QuestieTracker:Update()
                                end)
                            end
                        end
                    end
                end
            end)
        end
    elseif sortObj == "byProximity" or sortObj == "byProximityReversed" then
        local toSort = {}
        local continent = _GetContinent(C_Map.GetBestMapForUnit("player"))

        for _, questId in pairs(sortedQuestIds) do
            local sortData = {}
            sortData.questId = questId
            sortData.q = questDetails[questId].quest
            local distance, zone, questContinent = _GetNearestQuestSortData(sortData.q)
            sortData.distance = distance
            sortData.zone = zone
            sortData.continent = questContinent
            toSort[questId] = sortData
        end

        local sorter = function(a, b)
            a = toSort[a]
            b = toSort[b]
            if ((continent == a.continent) and (continent == b.continent)) or ((continent ~= a.continent) and (continent ~= b.continent)) then
                if a.distance == b.distance then
                    return a.q and b.q and a.q.level < b.q.level
                end

                if not a.distance and b.distance then
                    return false
                elseif a.distance and not b.distance then
                    return true
                end

                return a.distance < b.distance
            elseif (continent == a.continent) and (continent ~= b.continent) then
                return true
            elseif (continent ~= a.continent) and (continent == b.continent) then
                return false
            end
        end

        local sorterReversed = function(a, b)
            a = toSort[a]
            b = toSort[b]
            if ((continent == a.continent) and (continent == b.continent)) or ((continent ~= a.continent) and (continent ~= b.continent)) then
                if a.distance == b.distance then
                    return a.q and b.q and a.q.level > b.q.level
                end

                if not a.distance and b.distance then
                    return true
                elseif a.distance and not b.distance then
                    return false
                end

                return a.distance > b.distance
            elseif (continent == a.continent) and (continent ~= b.continent) then
                return false
            elseif (continent ~= a.continent) and (continent == b.continent) then
                return true
            end
        end

        if sortObj == "byProximity" then
            table.sort(sortedQuestIds, sorter)
        else
            table.sort(sortedQuestIds, sorterReversed)
        end

        if not questProximityTimer and not IsInInstance() then
            -- Check location often and update if you've moved
            Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Proximity Timer Started!")

            local playerPosition
            questProximityTimer = C_Timer.NewTicker(5.0, function()
                if IsInInstance() and questProximityTimer then
                    Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Proximity Timer Stopped!")
                    questProximityTimer:Cancel()
                    questProximityTimer = nil
                else
                    local position = _GetWorldPlayerPosition()
                    if position then
                        local distance = playerPosition and _GetDistance(position.x, position.y, playerPosition.x, playerPosition.y)
                        if not distance or distance > 0.01 then -- Position has changed
                            Questie.Debug(Questie.DEBUG_SPAM, "[TrackerQuestOrder:GetSortedQuestIds] - Proximity Timer Updated!")
                            playerPosition = position
                            local orderCopy = {}

                            for index, val in pairs(sortedQuestIds) do
                                orderCopy[index] = val
                            end

                            if sortObj == "byProximity" then
                                table.sort(sortedQuestIds, sorter)
                            else
                                table.sort(sortedQuestIds, sorterReversed)
                            end

                            if _DidQuestOrderChange(sortedQuestIds, orderCopy) then
                                QuestieCombatQueue:Queue(function()
                                    TrackerQuestOrder.FilterProximityTimer = true
                                    QuestieTracker:Update()
                                end)
                            end
                        end
                    end
                end
            end)
        end
    end


    if (sortObj ~= strmatch(sortObj, "byProximity.*")) and questProximityTimer and questProximityTimer ~= nil then
        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Proximity Timer Stopped!")
        questProximityTimer:Cancel()
        TrackerQuestOrder.FilterProximityTimer = nil
        questProximityTimer = nil
    end

    if (sortObj ~= strmatch(sortObj, "byZonePlayerProximity.*")) and questZoneProximityTimer and questZoneProximityTimer ~= nil then
        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestOrder:GetSortedQuestIds] - Zone Proximity Timer Stopped!")
        questZoneProximityTimer:Cancel()
        TrackerQuestOrder.FilterProximityTimer = nil
        questZoneProximityTimer = nil
    end

    return sortedQuestIds, questDetails
end
