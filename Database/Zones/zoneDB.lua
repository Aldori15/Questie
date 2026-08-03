---@class ZoneDB
local ZoneDB = QuestieLoader:CreateModule("ZoneDB")
---@type ZoneDBPrivate
ZoneDB.private = ZoneDB.private or {}

local _ZoneDB = ZoneDB.private

-------------------------
--Import modules.
-------------------------
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Map = QuestieCompat.C_Map
local UI_MAP_TYPE_COSMIC = 0
local UI_MAP_TYPE_WORLD = 1
local UI_MAP_TYPE_CONTINENT = 2

local areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}
local specialZoneIdToUiMapId = ZoneDB.private.specialZoneIdToUiMapId or {}
local uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
local dungeons = ZoneDB.private.dungeons or {}
local dungeonLocations = ZoneDB.private.dungeonLocations or {}
local dungeonParentZones = ZoneDB.private.dungeonParentZones or {}
local subZoneToParentZone = ZoneDB.private.subZoneToParentZone or {}

---Zone ids enum
ZoneDB.zoneIDs = ZoneDB.private.zoneIDs or {}

-- Generated from alternativeAreaId in dungeons
-- [alternativeDungeonAreaId] = dungeonZone
---@type table<AreaId, AreaId>
local alternativeDungeonAreaIdToDungeonAreaId = {}


-- Overrides for UiMapId to AreaId
local UiMapIdOverrides = {
    [246] = 3713,
    -- Continent maps are not real NPC/object zones, but the client can return them
    -- from C_Map.GetBestMapForUnit("player") while inside caves or similar sub-areas.
    [113] = 0, -- Northrend
    [1414] = 0, -- Kalimdor
    [1415] = 0, -- Eastern Kingdom
    [1945] = 0, -- Outland
}
local parentZoneToSubZone = {} -- Generated
local zoneMap = {} -- Generated


function ZoneDB:Initialize()
    _ZoneDB:GenerateParentZoneToStartingZoneTable()

    -- Run tests if debug enabled
    if Questie.db.profile.debugEnabled then
        _ZoneDB:RunTests()
    end

    for areaId, dungeonZoneEntry in pairs(dungeons) do
        local alternativeDungeonZone = dungeonZoneEntry[2]
        if alternativeDungeonZone then
            alternativeDungeonAreaIdToDungeonAreaId[alternativeDungeonZone] = areaId
        end
    end
end

function _ZoneDB:GenerateParentZoneToStartingZoneTable()
    for startingZone, parentZone in pairs(subZoneToParentZone) do
        parentZoneToSubZone[parentZone] = startingZone
    end
end

function ZoneDB:GetDungeons()
    return dungeons
end

---@param areaId AreaId
---@return UiMapId
function ZoneDB:GetUiMapIdByAreaId(areaId)
    local uiMapId = areaIdToUiMapId[areaId] or specialZoneIdToUiMapId[areaId]
    if (not uiMapId) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "No UiMapId found for AreaId: " .. tostring(areaId))
    end

    return uiMapId
end

---@param uiMapId UiMapId
---@return AreaId
function ZoneDB:GetAreaIdByUiMapId(uiMapId)
    --? Some areas have multiple areaIds, so we return the correct AreaId
    if UiMapIdOverrides[uiMapId] then
        return UiMapIdOverrides[uiMapId]
    end

    local foundId = uiMapIdToAreaId[uiMapId]
    if foundId then
        return foundId
    end

    -- As a last resort we try to match AreaId and UiMapId by name
    -- uses the original table in zoneTables as the area id's are
    -- all in that and we dont care if the uiMapId is there or not
    local mapInfo = C_Map.GetMapInfo(uiMapId)
    for areaId in pairs(areaIdToUiMapId) do
        local areaName = C_Map.GetAreaInfo(areaId)
        if mapInfo and mapInfo.name == areaName then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[ZoneDB:GetAreaIdByUiMapId] : ", "Found AreaId", areaName, ":", areaId, "for UiMapId", mapInfo.name, ":", uiMapId, "by name")
            return areaId
        end
    end
    error("No AreaId found for UiMapId: " .. tostring(uiMapId) .. ":" .. (mapInfo and mapInfo.name or "unknown map"))
end


---@param areaId AreaId
---@return AreaCoordinate?
function ZoneDB:GetDungeonLocation(areaId)
    local dungeonLocation = dungeonLocations[areaId]
    if dungeonLocation then
        return dungeonLocation
    end

    local alternativeDungeonAreaId = alternativeDungeonAreaIdToDungeonAreaId[areaId]
    if alternativeDungeonAreaId then
        return dungeonLocations[alternativeDungeonAreaId]
    end

    return nil
end

---@param areaId AreaId
---@return string?
function ZoneDB:GetLocalizedDungeonName(areaId)
    local dungeon = dungeons[areaId]
    local dungeonName
    if dungeon then
        dungeonName = dungeon[1]
    else
        local alternativeDungeonAreaId = alternativeDungeonAreaIdToDungeonAreaId[areaId]
        if alternativeDungeonAreaId then
            areaId = alternativeDungeonAreaId
            dungeonName = dungeons[alternativeDungeonAreaId][1]
        end
    end

    if dungeonName then
        -- The Questie DB has an entry for the area being a dungeon. We still prefer the Blizzard name if found.
        return C_Map.GetAreaInfo(areaId) or dungeonName
    end
    return nil
end

---@param areaId AreaId
function ZoneDB.IsDungeonZone(areaId)
    return dungeonLocations[areaId] ~= nil
end

---@param areaId AreaId
function ZoneDB:GetAlternativeZoneId(areaId)
    local entry = dungeons[areaId]
    if entry then
        return entry[2]
    end

    entry = parentZoneToSubZone[areaId]
    if entry then
        return entry
    end

    return nil
end

---@param areaId AreaId
function ZoneDB:GetParentZoneId(areaId)
    return dungeonParentZones[areaId] or subZoneToParentZone[areaId]
end


-- We keep localized variables outside of the function only used by GetZonesWithQuests
do
    -- This is for yielding
    local yieldAmount = 200
    local extraYield = yieldAmount / 4

    --Keep yield here as there is potentially a case where this wants to be run outside of a coroutine

    ---@param yield boolean?
    ---@return table
    function ZoneDB:GetZonesWithQuests(yield)
        local count = 0

        for questId in pairs(QuestieDB.QuestPointers) do
            local hiddenQuest = QuestieCorrections.hiddenQuests[questId]
            local isCurrentExpansionEventQuest = QuestieEvent:IsEventQuestInCurrentExpansion(questId)
            if (not hiddenQuest) or isCurrentExpansionEventQuest then
                if QuestiePlayer.HasRequiredRace(QuestieDB.QueryQuestSingle(questId, "requiredRaces"))
                    and QuestiePlayer.HasRequiredClass(QuestieDB.QueryQuestSingle(questId, "requiredClasses")) then

                    local zoneOrSort, requiredSkill = QuestieDB.QueryQuestSingle(questId, "zoneOrSort"), QuestieDB.QueryQuestSingle(questId, "requiredSkill")
                    local requiredSkillId = requiredSkill and requiredSkill[1]
                    local professionZoneId = requiredSkillId
                        and requiredSkillId ~= QuestieProfessions.professionKeys.RIDING
                        and QuestieProfessions:GetSortIdByProfessionId(requiredSkillId)

                    local eventSortKey = hiddenQuest and isCurrentExpansionEventQuest and _ZoneDB:GetEventSortKey(QuestieEvent:GetEventNameFor(questId))
                    if eventSortKey then
                        if (not zoneMap[eventSortKey]) then
                            zoneMap[eventSortKey] = {}
                        end
                        zoneMap[eventSortKey][questId] = true
                    elseif professionZoneId then
                        if (not zoneMap[professionZoneId]) then
                            zoneMap[professionZoneId] = {}
                        end
                        zoneMap[professionZoneId][questId] = true
                    elseif zoneOrSort and zoneOrSort > 0 then
                        local parentZoneId = ZoneDB:GetParentZoneId(zoneOrSort)

                        if parentZoneId then
                            if (not zoneMap[parentZoneId]) then
                                zoneMap[parentZoneId] = {}
                            end
                            zoneMap[parentZoneId][questId] = true
                        else
                            if (not zoneMap[zoneOrSort]) then
                                zoneMap[zoneOrSort] = {}
                            end
                            zoneMap[zoneOrSort][questId] = true
                        end
                    elseif _ZoneDB:IsSpecialQuest(zoneOrSort) then
                        if (not zoneMap[zoneOrSort]) then
                            zoneMap[zoneOrSort] = {}
                        end
                        zoneMap[zoneOrSort][questId] = true
                    else
                        -- This branch is kind of expensive so yield more often if it happens a lot
                        local startedBy = QuestieDB.QueryQuestSingle(questId, "startedBy")

                        if startedBy then
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromNPCs(zoneMap, startedBy[1])
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromObjects(zoneMap, startedBy[2])
                        end
                        if yield then
                            count = count + extraYield
                            if count >= yieldAmount then
                                count = 0
                                coroutine.yield()
                            end
                        end

                        local finishedBy = QuestieDB.QueryQuestSingle(questId, "finishedBy")
                        if finishedBy then
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromNPCs(zoneMap, finishedBy[1])
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromObjects(zoneMap, finishedBy[2])
                        end
                        if yield then count = count + extraYield end
                    end
                end
            end

            if yield then
                if count >= yieldAmount then
                    count = 0
                    coroutine.yield()
                end
                count = count + 1
            end
        end
        if yield then coroutine.yield() end
        zoneMap = _ZoneDB:SplitSeasonalQuests()

        return zoneMap
    end
end

---@param yield boolean?
---@return table
function ZoneDB:RebuildZonesWithQuests(yield)
    zoneMap = {}
    return self:GetZonesWithQuests(yield)
end

function _ZoneDB:GetEventSortKey(eventName)
    local sortKeys = QuestieDB.sortKeys
    local eventSortKeys = {
        ["Brewfest"] = sortKeys.BREWFEST,
        ["Children's Week"] = sortKeys.CHILDRENS_WEEK,
        ["Darkmoon Faire"] = sortKeys.DARKMOON_FAIRE,
        ["Day of the Dead"] = sortKeys.DAY_OF_THE_DEAD,
        ["Harvest Festival"] = sortKeys.HARVEST_FESTIVAL,
        ["Hallow's End"] = sortKeys.HALLOWS_END,
        ["Love is in the Air"] = sortKeys.LOVE_IS_IN_THE_AIR,
        ["Lunar Festival"] = sortKeys.LUNAR_FESTIVAL,
        ["Midsummer"] = sortKeys.MIDSUMMER,
        ["Noblegarden"] = sortKeys.NOBLEGARDEN,
        ["Pilgrim's Bounty"] = sortKeys.PILGRIMS_BOUNTY,
        ["Winter Veil"] = sortKeys.WINTER_VEIL,
    }

    return eventSortKeys[eventName]
end


---@param zoneOrSort ZoneOrSort
function _ZoneDB:IsSpecialQuest(zoneOrSort)
    for _, v in pairs(QuestieDB.sortKeys) do
        if zoneOrSort == v then
            return true
        end
    end
    return false
end

---@param zones any @ I have no idea what this is does or looks
---@param npcIds NpcId[]
---@return any @ Ditto
function _ZoneDB:GetZonesWithQuestsFromNPCs(zones, npcIds)
    if (not npcIds) then
        return zones
    end

    for npcId in pairs(npcIds) do
        local spawns = QuestieDB.QueryNPCSingle(npcId, "spawns")
        if spawns then
            for zone in pairs(spawns) do
                if not zones[zone] then zones[zone] = {} end
                zones[zone][npcId] = true
            end
        end
    end

    return zones
end
---@param zones any @ I have no idea what this is does or looks
---@param objectIds ObjectId[]
---@return any @ Ditto
function _ZoneDB:GetZonesWithQuestsFromObjects(zones, objectIds)
    if (not objectIds) then
        return zones
    end

    for objectId in pairs(objectIds) do
        local spawns = QuestieDB.QueryObjectSingle(objectId, "spawns")
        if spawns then
            for zone in pairs(spawns) do
                if not zones[zone] then zones[zone] = {} end
                zones[zone][objectId] = true
            end
        end
    end

    return zones
end

---@return table
function _ZoneDB:SplitSeasonalQuests()
    local sortKeys = QuestieDB.sortKeys

    if (not zoneMap[sortKeys.SPECIAL]) and (not zoneMap[sortKeys.SEASONAL]) then
        return zoneMap
    end

    local questsToSplit = {}
    if zoneMap[sortKeys.SEASONAL] then
        for k, v in pairs(zoneMap[sortKeys.SEASONAL]) do questsToSplit[k] = v end
    end

    -- Merging SEASONAL and SPECIAL quests to be split into real groups
    if zoneMap[sortKeys.SPECIAL] then
        for k, v in pairs(zoneMap[sortKeys.SPECIAL]) do questsToSplit[k] = v end
    end

    local updatedZoneMap = zoneMap

    for questId, _ in pairs(questsToSplit) do
        local eventSortKey = _ZoneDB:GetEventSortKey(QuestieEvent:GetEventNameFor(questId))
        if eventSortKey then
            if (not updatedZoneMap[eventSortKey]) then
                updatedZoneMap[eventSortKey] = {}
            end
            updatedZoneMap[eventSortKey][questId] = true
        else
            -- here for actual "Special" quests that are not part of events
            -- E.g. CLUCK!
            if (not updatedZoneMap[sortKeys.SPECIALTEMP]) then
                updatedZoneMap[sortKeys.SPECIALTEMP] = {}
            end
            updatedZoneMap[sortKeys.SPECIALTEMP][questId] = true
        end
    end

    updatedZoneMap[sortKeys.SEASONAL] = nil
    updatedZoneMap[sortKeys.SPECIAL] = nil
    return updatedZoneMap
end

function ZoneDB:GetRelevantZones()
    local zones = {}
    for category, data in pairs(l10n.zoneCategoryLookup) do
        zones[category] = {}
        for id, zoneName in pairs(data) do
            local zoneQuests = zoneMap[id]
            if (not zoneQuests) then
                zones[category][id] = nil
            else
                zones[category][id] = l10n(zoneName)
            end
        end
    end

    return zones
end



----- Tests -----

function _ZoneDB:RunTests()
    -- Fetch all UiMapIds (WOTLK/TBC, ERA)
    local maps = C_Map.GetMapChildrenInfo(946, nil, true) or C_Map.GetMapChildrenInfo(947, nil, true)
    Questie:Debug(Questie.DEBUG_CRITICAL, "[" .. Questie:Colorize("ZoneDBTests", "yellow") .. "] Testing ZoneDB")
    for _, map in pairs(maps) do
        --- We don't care about World, Continent or Cosmic
        if map.mapType ~= UI_MAP_TYPE_WORLD and map.mapType ~= UI_MAP_TYPE_CONTINENT and map.mapType ~= UI_MAP_TYPE_COSMIC then
            local success, result = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, map.mapID)
            if not success then
                Questie:Error("[ZoneDBTests] ZoneDB.GetAreaIdByUiMapId fails for " .. map.name .. " (" .. map.mapID .. "). Result: " .. result)
            end

        end
    end
    Questie:Debug(Questie.DEBUG_CRITICAL, "[" .. Questie:Colorize("ZoneDBTests", "yellow") .. "] Testing ZoneDB done")
end
