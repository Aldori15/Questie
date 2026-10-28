---@class QuestieCorrections
local QuestieCorrections = QuestieLoader:CreateModule("QuestieCorrections")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type RamerDouglasPeucker
local RamerDouglasPeucker = QuestieLoader:ImportModule("RamerDouglasPeucker")
---@type QuestieQuestBlacklist
local QuestieQuestBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
---@type QuestieNPCBlacklist
local QuestieNPCBlacklist = QuestieLoader:ImportModule("QuestieNPCBlacklist")
---@type QuestieItemBlacklist
local QuestieItemBlacklist = QuestieLoader:ImportModule("QuestieItemBlacklist")

---@type ItemRuntimeCorrections
local ItemRuntimeCorrections = QuestieLoader:ImportModule("ItemRuntimeCorrections")
---@type NPCRuntimeCorrections
local NPCRuntimeCorrections = QuestieLoader:ImportModule("NPCRuntimeCorrections")
---@type ObjectRuntimeCorrections
local ObjectRuntimeCorrections = QuestieLoader:ImportModule("ObjectRuntimeCorrections")
---@type QuestRuntimeCorrections
local QuestRuntimeCorrections = QuestieLoader:ImportModule("QuestRuntimeCorrections")

---@type IsleOfQuelDanas
local IsleOfQuelDanas = QuestieLoader:ImportModule("IsleOfQuelDanas")

-- Static data belongs to the generated bases. This module initializes runtime
-- faction overrides, blacklists, race inference and waypoint optimization.

-- Expansion-specific hide flags used by blacklist and event definitions.
QuestieCorrections.TBC_ONLY = 1 -- Hide only in TBC
QuestieCorrections.CLASSIC_ONLY = 2 -- Hide only in Classic
QuestieCorrections.WOTLK_ONLY = 3 -- Hide only in Wotlk
QuestieCorrections.TBC_AND_WOTLK = 4 -- Hide in TBC and Wotlk
QuestieCorrections.CLASSIC_AND_TBC = 7 -- Hide in both Classic and TBC

QuestieCorrections.killCreditObjectiveFirst = {}
QuestieCorrections.itemObjectiveFirst = {}
QuestieCorrections.questTooltipHints = {}
QuestieCorrections.objectiveTooltipHints = {}
---@type table<QuestId, table<integer, { [1]: "monster"|"object"|"item", [2]: number }>>
QuestieCorrections.triggerEndTooltipTargets = {}

-- Resolve expansion-specific hide flags for the Wrath client.
---@generic T
---@param values T
---@return T
local function filterExpansion(values)
    for k, v in pairs(values) do
        if v == QuestieCorrections.WOTLK_ONLY then
            values[k] = true
        elseif v == QuestieCorrections.TBC_ONLY then
            values[k] = nil
        elseif v == QuestieCorrections.CLASSIC_ONLY then
            values[k] = nil
        elseif v == QuestieCorrections.TBC_AND_WOTLK then
            values[k] = true
        elseif v == QuestieCorrections.CLASSIC_AND_TBC then
            values[k] = nil
        end
    end
    return values
end

do
    local type, assert = type, assert
    --- Add runtime overrides for the database
    ---@param override_table table<number, table<number, string|table|number>>
    ---@param new_overrides table<number, table<number, string|table|number>>
    local function addOverride(override_table, new_overrides)
        assert(type(override_table) == "table", "Override table must be a table!")
        assert(type(new_overrides) == "table", "New overrides must be a table!")
        for id, data in pairs(new_overrides) do
            assert(type(id) == "number", "Override id must be a number!")
            assert(type(data) == "table", "Override data must be a table!")
            -- If no override exist assign it
            if not override_table[id] then
                override_table[id] = data
            else
                -- Override already exists, merge the new data
                for key, value in pairs(data) do
                    override_table[id][key] = value
                end
            end
        end
    end

    function QuestieCorrections:MinimalInit() -- db already compiled
        QuestRuntimeCorrections:LoadEventTooltipTargets()
        ItemRuntimeCorrections:ApplyFactionFixes(QuestieDB.itemDataOverrides, addOverride)
        NPCRuntimeCorrections:ApplyFactionFixes(QuestieDB.npcDataOverrides, addOverride)
        ObjectRuntimeCorrections:ApplyFactionFixes(QuestieDB.objectDataOverrides, addOverride)
        QuestRuntimeCorrections:ApplyFactionFixes(QuestieDB.questDataOverrides, addOverride)

        QuestieCorrections.questItemBlacklist = filterExpansion(QuestieItemBlacklist:Load())
        QuestieCorrections.questNPCBlacklist = filterExpansion(QuestieNPCBlacklist:Load())
        QuestieCorrections.hiddenQuests = filterExpansion(QuestieQuestBlacklist:Load())

        -- Isle of Quel'Danas Phase Blacklist
        if Questie.db.profile.isleOfQuelDanasPhase == IsleOfQuelDanas.MAX_ISLE_OF_QUEL_DANAS_PHASES then
            for id, hide in pairs(IsleOfQuelDanas.quests[Questie.db.profile.isleOfQuelDanasPhase]) do
                -- This has to be a nil-check, because the value could be false
                if (QuestieCorrections.hiddenQuests[id] == nil) then
                    QuestieCorrections.hiddenQuests[id] = hide
                end
            end
        end

        -- Wotlk Blacklist
        -- We only add blacklist if no blacklist entry for the quest already exists
        for id, hide in pairs(QuestieQuestBlacklist.LoadAutoBlacklistWotlk()) do
            -- This has to be a nil-check, because the value could be false
            if (QuestieCorrections.hiddenQuests[id] == nil) then
                QuestieCorrections.hiddenQuests[id] = hide
            end
        end

        QuestieCompat.LoadBlacklists()

    end
end

function QuestieCorrections:Initialize()
    -- Static corrections are included in the generated base databases.
    -- MinimalInit retains faction overrides and blacklists on fresh and cached startup.

    QuestieDB.requiredItemConditionQuestIds = {}
    for questId, quest in pairs(QuestieDB.questData) do
        local requiredItemConditions = quest[QuestieDB.questKeys.requiredItemConditions]
        if requiredItemConditions and next(requiredItemConditions) then
            QuestieDB.requiredItemConditionQuestIds[questId] = true
        end

        if not quest[QuestieDB.questKeys.requiredRaces] or quest[QuestieDB.questKeys.requiredRaces] == 0 then
            -- An endpoint-based client availability filter supplements AC's race mask.
            -- Mixed, neutral, missing, object and item endpoints remain unrestricted.
            local team
            local consistent = true
            local foundStarter = false
            for side = 1, 2 do
                local relation = quest[side == 1 and QuestieDB.questKeys.startedBy or QuestieDB.questKeys.finishedBy]
                if relation then
                    if (relation[2] and next(relation[2])) or (relation[3] and next(relation[3])) then
                        consistent = false
                    end
                    for _, id in pairs(relation[1] or {}) do
                        local npc = QuestieDB.npcData[id]
                        local friendly = npc and npc[QuestieDB.npcKeys.friendlyToFaction]
                        if friendly ~= "A" and friendly ~= "H" then
                            consistent = false
                        elseif team and team ~= friendly then
                            consistent = false
                        else
                            team = friendly
                        end
                        if side == 1 then
                            foundStarter = true
                        end
                    end
                end
            end
            if consistent and foundStarter and team then
                quest[QuestieDB.questKeys.requiredRaces] = team == "A" and QuestieDB.raceKeys.ALL_ALLIANCE or QuestieDB.raceKeys.ALL_HORDE
            end
        end
    end

    QuestieCorrections:MinimalInit()
end

local WAYPOINT_MIN_DISTANCE = 1.5 -- todo: make this a config value maybe?
local ZONE_SCALES = {
    [ZoneDB.zoneIDs.STORMWIND_CITY] = 0.5,
    [ZoneDB.zoneIDs.IRONFORGE] = 0.5,
    [ZoneDB.zoneIDs.TELDRASSIL] = 0.5,

    [ZoneDB.zoneIDs.ORGRIMMAR] = 0.5,
    [ZoneDB.zoneIDs.THUNDER_BLUFF] = 0.5,
    [ZoneDB.zoneIDs.UNDERCITY] = 0.5,
}


local abs, sqrt = math.abs, math.sqrt
local function euclid(x, y, i, e)
    local xd = abs(x - i)
    local yd = abs(y - e)
    return sqrt(xd * xd + yd * yd)
end

function QuestieCorrections:OptimizeWaypoints(waypointData)
    local newWaypointZones = {}
    for zone, waypointList in pairs(waypointData) do
        local newWaypointList = {}
        if waypointList[1] and type(waypointList[1][1]) == "number" then
            waypointList = {waypointList} -- corrections support both {{x,y}, ...} and {{{x,y}, ...}, {{x,y}, ...}, ...}
        end
        for _, waypoints in pairs(waypointList) do
            -- apply RDP algorithm
            local minDist = WAYPOINT_MIN_DISTANCE * (ZONE_SCALES[zone] or 1)
            local newWaypoints = RamerDouglasPeucker(waypoints, 0.1, true)

            waypoints = newWaypoints
            newWaypoints = {}

            -- subdivide waypoints where needed
            -- We do this because the clickable area of waypoint lines can only be a square, so lines need to be broken up in some places
            local lastWay
            for _, way in pairs(waypoints) do
                if lastWay then
                    local dist = euclid(way[1], way[2], lastWay[1], lastWay[2])
                    if dist > minDist then
                        local divs = math.ceil(dist/minDist)
                        for i=1,divs do
                            local mul0 = i/divs
                            local mul1 = 1-mul0
                            newWaypoints[#newWaypoints+1] = {way[1] * mul0 + lastWay[1] * mul1, way[2] * mul0 + lastWay[2] * mul1}
                        end
                    else
                        newWaypoints[#newWaypoints+1] = way
                    end
                else
                    newWaypoints[#newWaypoints+1] = way
                end
                lastWay = way
            end
            newWaypointList[#newWaypointList+1] = newWaypoints
        end
        newWaypointZones[zone] = newWaypointList
    end
    return newWaypointZones
end

function QuestieCorrections:PreCompile() -- this happens only if we are about to compile the database. Run intensive preprocessing tasks here (like ramer-douglas-peucker)
    local waypointKey = QuestieDB.npcKeys["waypoints"]
    local npcData = QuestieDB.npcData

    local count = 0
    for id, data in pairs(npcData) do
        local way = data[waypointKey]
        if way then
            npcData[id][waypointKey] = QuestieCorrections:OptimizeWaypoints(way)
        end

        if count > 500 then -- 500 seems like a good number
            count = 0
            coroutine.yield()
        end
        count = count + 1
    end
end
