---@class AutoRoute
local AutoRoute = QuestieLoader:CreateModule("AutoRoute")

---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local C_Timer = QuestieCompat.C_Timer
local tinsert, tremove = table.insert, table.remove

local LEVEL_ABOVE_CUTOFF = 5
local YARDS_PER_LEVEL_ABOVE = 900
local YARDS_PER_LEVEL_BELOW = 220
local UNREACHABLE = math.huge

local updateGeneration = 0
local lastAutoTarget

local function _GetRoute()
    if not Questie.db.char.autoRouteOrder then
        Questie.db.char.autoRouteOrder = {}
    end
    return Questie.db.char.autoRouteOrder
end

local function _GetDungeonEntrance(quest)
    local locations = quest.zoneOrSort and ZoneDB:GetDungeonLocation(quest.zoneOrSort)
    local entrance = locations and locations[1]
    if entrance and entrance[1] and entrance[2] and entrance[3] then
        return {
            questId = quest.Id,
            zone = entrance[1],
            x = entrance[2],
            y = entrance[3],
            name = ZoneDB:GetLocalizedDungeonName(quest.zoneOrSort) or quest.name,
        }
    end
end

local function _GetTarget(quest, useDungeonEntrance)
    -- An ordered dungeon quest should lead to the entrance while outside the instance.
    local needsDungeonEntrance = useDungeonEntrance and quest:IsComplete() ~= 1
    if needsDungeonEntrance and not IsInInstance() then
        local entrance = _GetDungeonEntrance(quest)
        if entrance then
            return entrance
        end
    end

    local spawn, zone, name, _, _, distance = QuestieMap:GetNearestQuestSpawn(quest)
    if spawn and zone and spawn[1] and spawn[2] then
        return {
            questId = quest.Id,
            zone = zone,
            x = spawn[1],
            y = spawn[2],
            name = name or quest.name,
            distance = distance,
        }
    end

    if needsDungeonEntrance then
        return _GetDungeonEntrance(quest)
    end
end

local function _ScoreQuest(questId, distance)
    local playerLevel = QuestiePlayer.GetPlayerLevel()
    if type(playerLevel) ~= "number" then
        return distance
    end
    local questLevel = QuestieLib.GetEffectiveQuestLevel(questId, playerLevel)
    if type(questLevel) ~= "number" or questLevel == 0 then
        return distance
    end

    local difference = questLevel - playerLevel
    if difference > LEVEL_ABOVE_CUTOFF then
        return UNREACHABLE
    elseif difference > 0 then
        return distance + difference * YARDS_PER_LEVEL_ABOVE
    end
    return distance - difference * YARDS_PER_LEVEL_BELOW
end

local function _PickNextTarget()
    local questLog = QuestiePlayer.currentQuestlog or {}

    for _, questId in ipairs(_GetRoute()) do
        local quest = questLog[questId]
        if quest and QuestieQuest:IsQuestTracked(questId) then
            local target = _GetTarget(quest, true)
            if target then
                return target
            end
        end
    end

    local bestTarget, bestScore = nil, UNREACHABLE
    for questId, quest in pairs(questLog) do
        if QuestieQuest:IsQuestTracked(questId) then
            local target = _GetTarget(quest, false)
            if target and type(target.distance) == "number" then
                local score = _ScoreQuest(questId, target.distance)
                if score < bestScore or (score == bestScore and bestTarget and questId < bestTarget.questId) then
                    bestTarget, bestScore = target, score
                end
            end
        end
    end
    return bestTarget
end

local function _IsSameTarget(left, right)
    return left and right
        and left.questId == right.questId
        and left.zone == right.zone
        and left.x == right.x
        and left.y == right.y
end

function AutoRoute.GetRoutePosition(questId)
    for position, routeQuestId in ipairs(_GetRoute()) do
        if routeQuestId == questId then
            return position
        end
    end
end

function AutoRoute.AddToRoute(questId)
    if AutoRoute.GetRoutePosition(questId) then
        return
    end
    tinsert(_GetRoute(), questId)
    AutoRoute.ScheduleUpdate()
end

function AutoRoute.RemoveFromRoute(questId)
    local position = AutoRoute.GetRoutePosition(questId)
    if position then
        tremove(_GetRoute(), position)
    end
    -- A quest outside the ordered route can still be the automatic target.
    AutoRoute.ScheduleUpdate()
end

function AutoRoute.MoveInRoute(questId, delta)
    local route = _GetRoute()
    local position = AutoRoute.GetRoutePosition(questId)
    local target = position and position + delta
    if not target or target < 1 or target > #route then
        return
    end
    route[position], route[target] = route[target], route[position]
    AutoRoute.ScheduleUpdate()
end

function AutoRoute.ClearRoute()
    Questie.db.char.autoRouteOrder = {}
    AutoRoute.ScheduleUpdate()
end

function AutoRoute.PruneRoute()
    local questLog = QuestiePlayer.currentQuestlog or {}
    local route = _GetRoute()
    for position = #route, 1, -1 do
        if not questLog[route[position]] then
            tremove(route, position)
        end
    end
end

function AutoRoute.ClearSavedAutomaticHandle()
    -- Automatic waypoints are not persisted by TomTom. A saved numeric UID may
    -- refer to a different waypoint after login, so never try to remove it.
    if Questie.db.char._tom_waypoint_source == "autoRoute" then
        Questie.db.char._tom_waypoint = nil
        Questie.db.char._tom_waypoint_quest = nil
        Questie.db.char._tom_waypoint_source = nil
    end
    lastAutoTarget = nil
end

function AutoRoute.ClearAutomaticTarget()
    if Questie.db.char._tom_waypoint_source == "autoRoute" then
        TrackerUtils:ClearTomTomTarget()
    end
    lastAutoTarget = nil
end

function AutoRoute.Update()
    if not Questie.started or not Questie.db.profile.autoRouteEnabled or not TomTom or not TomTom.AddWaypoint then
        return
    end
    if not Questie.db.profile.trackerEnabled then
        AutoRoute.ClearAutomaticTarget()
        return
    end

    -- A waypoint set by a player, including one without a quest ID, takes priority.
    local waypoint = Questie.db.char._tom_waypoint
    if waypoint and TomTom.IsValidWaypoint and not TomTom:IsValidWaypoint(waypoint) then
        TrackerUtils:ClearTomTomTarget()
        lastAutoTarget = nil
        waypoint = nil
    end
    if waypoint and Questie.db.char._tom_waypoint_source ~= "autoRoute" then
        return
    end

    local target = _PickNextTarget()
    if not target then
        AutoRoute.ClearAutomaticTarget()
        return
    end
    if waypoint and Questie.db.char._tom_waypoint_source == "autoRoute" and _IsSameTarget(lastAutoTarget, target) then
        return
    end

    TrackerUtils:SetTomTomTarget(target.name, target.zone, target.x, target.y, target.questId, nil, "autoRoute")
    if Questie.db.char._tom_waypoint_source == "autoRoute" then
        lastAutoTarget = target
    else
        lastAutoTarget = nil
    end
end

function AutoRoute.ScheduleUpdate(delay)
    if not Questie.db.profile.autoRouteEnabled then
        return
    end
    updateGeneration = updateGeneration + 1
    local generation = updateGeneration
    C_Timer.After(delay or 0.15, function()
        if generation == updateGeneration then
            AutoRoute.Update()
        end
    end)
end

function AutoRoute.SetEnabled(enabled)
    Questie.db.profile.autoRouteEnabled = enabled
    updateGeneration = updateGeneration + 1
    if enabled then
        AutoRoute.ScheduleUpdate(0)
    else
        AutoRoute.ClearAutomaticTarget()
    end
end
