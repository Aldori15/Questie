---@class QuestiePlayer
---@field numberOfGroupMembers number ---The number of players currently in the group
local QuestiePlayer = QuestieLoader:CreateModule("QuestiePlayer");
local _QuestiePlayer = QuestiePlayer.private
-------------------------
--Import modules.
-------------------------
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Map = QuestieCompat.C_Map
local UnitRace = QuestieCompat.UnitRace
local UnitClass = QuestieCompat.UnitClass
local UnitInParty = QuestieCompat.UnitInParty
local IsInGroup = QuestieCompat.IsInGroup
local GetHomePartyInfo = QuestieCompat.GetHomePartyInfo
local GetClassColor = QuestieCompat.GetClassColor
local LE_PARTY_CATEGORY_INSTANCE = QuestieCompat.LE_PARTY_CATEGORY_INSTANCE
local GetTime = GetTime
local UI_MAP_TYPE_COSMIC = 0
local UI_MAP_TYPE_WORLD = 1
local UI_MAP_TYPE_CONTINENT = 2

QuestiePlayer.currentQuestlog = {} --Gets populated by QuestieQuest:GetAllQuestIds(), this is either an object to the quest in question, or the ID if the object doesn't exist.
_QuestiePlayer.playerLevel = -1
_QuestiePlayer.playerLevelSetAt = 0
local playerRaceId = -1
local playerRaceFlag = 255 -- dummy default value to always return race not matching, corrected in init
local playerRaceFlagX2 = 1 -- dummy default value to always return race not matching, corrected in init
local playerClassName = ""
local playerClassFlag = 255 -- dummy default value to always return class not matching, corrected in init
local playerClassFlagX2 = 1 -- dummy default value to always return class not matching, corrected in init

QuestiePlayer.numberOfGroupMembers = 0

function QuestiePlayer:Initialize()
    _QuestiePlayer.playerLevel = UnitLevel("player")

    playerRaceId = select(3, UnitRace("player"))
    playerRaceFlag = 2 ^ (playerRaceId - 1)
    playerRaceFlagX2 = 2 * playerRaceFlag

    playerClassName = select(1, UnitClass("player"))
    local classId = select(3, UnitClass("player"))
    playerClassFlag = 2 ^ (classId - 1)
    playerClassFlagX2 = 2 * playerClassFlag
end

-- Cache player level from events (or fallback UnitLevel when event value is unavailable).
---@param level Level
function QuestiePlayer:SetPlayerLevel(level)
    if level and level > 0 then
        _QuestiePlayer.playerLevel = level
        _QuestiePlayer.playerLevelSetAt = GetTime()
    else
        local localLevel = UnitLevel("player")
        if localLevel and localLevel > 0 then
            _QuestiePlayer.playerLevel = localLevel
            _QuestiePlayer.playerLevelSetAt = GetTime()
        end
    end
end

-- Return cached level immediately after level events and sync back to UnitLevel once stable.
---@return Level
function QuestiePlayer.GetPlayerLevel()
    local level = UnitLevel("player")
    local cachedLevel = _QuestiePlayer.playerLevel

    if cachedLevel and cachedLevel > 0 then
        if level and level > 0 and level ~= cachedLevel and (GetTime() - (_QuestiePlayer.playerLevelSetAt or 0)) >= 1 then
            _QuestiePlayer.playerLevel = level
            _QuestiePlayer.playerLevelSetAt = GetTime()
            return level
        end
        return cachedLevel
    end

    return level
end

-- Find out if the player is at max level for the active expansion
---@return boolean isMaxLevel
function QuestiePlayer.IsMaxLevel()
    local level = QuestiePlayer.GetPlayerLevel()
    return (Questie.IsWotlk and level == 80) or (Questie.IsTBC and level == 70) or (Questie.IsClassic and level == 60)
end

---@return number
function QuestiePlayer:GetRaceId()
    return playerRaceId
end

---@return string
function QuestiePlayer:GetLocalizedClassName()
    return playerClassName
end

function QuestiePlayer:GetGroupType()
    if(UnitInRaid("player")) then
        return "raid";
    elseif(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
        return "instance";
    elseif(UnitInParty("player")) then
        return "party";
    else
        return nil;
    end
end

---@return boolean
function QuestiePlayer.HasRequiredRace(requiredRaces)
    -- test a bit flag: (value % (2*flag) >= flag)
    return (not requiredRaces) or (requiredRaces == 0) or ((requiredRaces % playerRaceFlagX2) >= playerRaceFlag)
end

---@return boolean
function QuestiePlayer.HasRequiredClass(requiredClasses)
    -- test a bit flag: (value % (2*flag) >= flag)
    return (not requiredClasses) or (requiredClasses == 0) or ((requiredClasses % playerClassFlagX2) >= playerClassFlag)
end

function QuestiePlayer:GetCurrentZoneId()
    local uiMapId = C_Map.GetBestMapForUnit("player")
    if uiMapId and uiMapId > 0 then
        local mapInfo = C_Map.GetMapInfo(uiMapId)
        local mapType = mapInfo and mapInfo.mapType
        if not mapInfo or (mapType ~= UI_MAP_TYPE_WORLD and mapType ~= UI_MAP_TYPE_CONTINENT and mapType ~= UI_MAP_TYPE_COSMIC) then
            local success, areaId = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, uiMapId)
            if success then
                return areaId
            end
        end
    end

    local instanceId = select(8, GetInstanceInfo())
    if instanceId then
        return ZoneDB.instanceIdToUiMapId[instanceId]
    end

    return nil
end

---@return number
function QuestiePlayer:GetCurrentContinentId()
    local currentZoneId = QuestiePlayer:GetCurrentZoneId()
    if (not currentZoneId) or currentZoneId == 0 then
        return 0 -- Default to Eastern Kingdom
    end

    local currentContinentId = 0 -- Default to Eastern Kingdom
    for cId, cont in pairs(l10n.zoneLookup) do
        for id, _ in pairs(cont) do
            if id == currentZoneId then
                currentContinentId = cId
            end
        end
    end

    return currentContinentId
end

function QuestiePlayer:GetPartyMembers()
    local partyMembers = GetHomePartyInfo()
    if partyMembers then
        local party = {}
        for _, v in pairs(partyMembers) do
            local member = {}
            member.Name = v;
            local class, _, _ = UnitClass(v)
            member.Class = class
            member.Level = UnitLevel(v);
            table.insert(party, member);
        end
        return party
    end
    return nil
end

function QuestiePlayer:GetPartyMemberByName(playerName)
    if(UnitInParty("player") or UnitInRaid("player")) then
        local player = {}
        for index=1, 40 do
            local name = UnitName("party"..index);
            local _, classFilename = UnitClass("party"..index);
            if name == playerName then
                player.name = playerName;
                player.class = classFilename;
                local rPerc, gPerc, bPerc, argbHex = GetClassColor(classFilename)
                player.r = rPerc;
                player.g = gPerc;
                player.b = bPerc;
                player.colorHex = argbHex;
                return player;
            end
            if(index > 6 and not UnitInRaid("player")) then
                break;
            end
        end
    end
    return nil;
end

function QuestiePlayer:GetPartyMemberList()
    local members = {}
    if(UnitInParty("player") or UnitInRaid("player")) then
        for index=1, 40 do
            local name = UnitName("party"..index)
            if name then
                members[name] = true
            end
            if(index > 6 and not UnitInRaid("player")) then
                break
            end
        end
    end
    return members
end

return QuestiePlayer
