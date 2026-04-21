---@class InstanceLocations
local InstanceLocations = QuestieLoader:CreateModule("InstanceLocations")
InstanceLocations.private = InstanceLocations.private or {}

local _InstanceLocations = InstanceLocations.private

---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type MeetingStones
local MeetingStones = QuestieLoader:ImportModule("MeetingStones")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Map = QuestieCompat.C_Map

local HBD_PINS_WORLDMAP_SHOW_WORLD = 3

local PROFILE_KEYS = {
    dungeon = "showDungeonLocations",
    raid = "showRaidLocations",
}

local MANUAL_TYPES = {
    dungeon = "instanceDungeon",
    raid = "instanceRaid",
}

local ICON_ATLAS = QuestieLib.AddonPath .. "Icons\\instance_icons.blp"
local ICON_TEXTURES = {
    dungeon = ICON_ATLAS,
    raid = ICON_ATLAS,
    locked = QuestieLib.AddonPath .. "Icons\\instance_locked.blp",
}

local ICON_TEX_COORDS = {
    dungeon = {0.912109, 0.955078, 0.0449219, 0.0664062},
    raid = {0.689453, 0.732422, 0.166016, 0.1875},
    locked = {0, 1, 0, 1},
}

local ICON_SCALE = {
    dungeon = 1.6,
    raid = 1.6,
    locked = 2.35,
}

local DEFAULT_SCALE = {
    map = 0.6,
    minimap = 0.7,
}

local TITLE_COLORS = {
    dungeon = "|cFF44C8FF",
    raid = "|cFF37B24D",
    locked = "|cFFB8B8B8",
}

local RAID_GROUP_SIZES = {
    [1977] = "20-man",    -- Zul'Gurub
    [2159] = "10/25-man", -- Onyxia's Lair
    [2677] = "40-man",    -- Blackwing Lair
    [2717] = "40-man",    -- Molten Core
    [3428] = "40-man",    -- Temple of Ahn'Qiraj
    [3429] = "20-man",    -- Ruins of Ahn'Qiraj
    [3456] = "10/25-man", -- Naxxramas
    [3457] = "10-man",    -- Karazhan
    [3606] = "25-man",    -- Hyjal Summit
    [3607] = "25-man",    -- Serpentshrine Cavern
    [3805] = "10-man",    -- Zul'Aman
    [3836] = "25-man",    -- Magtheridon's Lair
    [3845] = "25-man",    -- The Eye
    [3923] = "25-man",    -- Gruul's Lair
    [3959] = "25-man",    -- Black Temple
    [4075] = "25-man",    -- Sunwell Plateau
    [4273] = "10/25-man", -- Ulduar
    [4493] = "10/25-man", -- The Obsidian Sanctum
    [4500] = "10/25-man", -- The Eye of Eternity
    [4603] = "10/25-man", -- Vault of Archavon
    [4722] = "10/25-man", -- Trial of the Crusader
    [4812] = "10/25-man", -- Icecrown Citadel
    [4987] = "10/25-man", -- The Ruby Sanctum
}

local RAID_AREA_IDS = {
    [1977] = true, -- Zul'Gurub
    [2159] = true, -- Onyxia's Lair
    [2677] = true, -- Blackwing Lair
    [2717] = true, -- Molten Core
    [3428] = true, -- Ahn'Qiraj Temple
    [3429] = true, -- Ruins of Ahn'Qiraj
    [3456] = true, -- Naxxramas
    [3457] = true, -- Karazhan
    [3606] = true, -- Hyjal Summit
    [3607] = true, -- Serpentshrine Cavern
    [3805] = true, -- Zul'Aman
    [3836] = true, -- Magtheridon's Lair
    [3845] = true, -- The Eye
    [3923] = true, -- Gruul's Lair
    [3959] = true, -- Black Temple
    [4075] = true, -- Sunwell Plateau
    [4273] = true, -- Ulduar
    [4493] = true, -- The Obsidian Sanctum
    [4500] = true, -- The Eye of Eternity
    [4603] = true, -- Vault of Archavon
    [4722] = true, -- Trial of the Crusader
    [4812] = true, -- Icecrown Citadel
    [4987] = true, -- The Ruby Sanctum
}

_InstanceLocations.entries = _InstanceLocations.entries or {
    dungeon = {},
    raid = {},
}
_InstanceLocations.lockouts = _InstanceLocations.lockouts or {}

local SUPPLEMENTAL_INSTANCE_NAMES = {
    [1977] = "Zul'Gurub",
    [2159] = "Onyxia's Lair",
    [2677] = "Blackwing Lair",
    [2717] = "Molten Core",
    [3428] = "Temple of Ahn'Qiraj",
    [3429] = "Ruins of Ahn'Qiraj",
    [3607] = "Serpentshrine Cavern",
    [3845] = "The Eye",
}

local SORT_ORDER = {
    raid = 1,
    dungeon = 2,
}

local function _NormalizeInstanceName(name)
    if not name then
        return nil
    end

    return strlower(name)
end

local function _UpdateLockouts()
    table.wipe(_InstanceLocations.lockouts)

    if not GetNumSavedInstances or not GetSavedInstanceInfo then
        return
    end

    for index = 1, GetNumSavedInstances() do
        local name, _, _, _, locked, _, _, _, _, difficultyName = GetSavedInstanceInfo(index)

        if locked and name then
            local key = _NormalizeInstanceName(name)

            if key then
                if not _InstanceLocations.lockouts[key] then
                    _InstanceLocations.lockouts[key] = {}
                end

                table.insert(_InstanceLocations.lockouts[key], {
                    difficultyName = difficultyName,
                })
            end
        end
    end
end

local function _GetEntryLockouts(entry)
    for _, lookupName in ipairs(entry.lookupNames) do
        local lockoutInfo = _InstanceLocations.lockouts[lookupName]

        if lockoutInfo then
            return lockoutInfo
        end
    end

    return nil
end

local function _IsEntryLocked(entry)
    return _GetEntryLockouts(entry) ~= nil
end

local function _EnsureProfileDefaults()
    if Questie.db.profile.showDungeonLocations == nil then
        Questie.db.profile.showDungeonLocations = true
    end

    if Questie.db.profile.showRaidLocations == nil then
        Questie.db.profile.showRaidLocations = true
    end

    if Questie.db.profile.globalInstanceScale == nil then
        Questie.db.profile.globalInstanceScale = DEFAULT_SCALE.map
    end

    if Questie.db.profile.globalMiniMapInstanceScale == nil then
        Questie.db.profile.globalMiniMapInstanceScale = DEFAULT_SCALE.minimap
    end
end

local function _GetTypeLabel(kind)
    if kind == "raid" then
        return l10n("Raid")
    end

    return l10n("Dungeon")
end

local function _GetGroupSizeLabel(entry)
    if entry.kind ~= "raid" then
        return nil
    end

    return RAID_GROUP_SIZES[entry.sourceAreaId]
end

local function _GetInstanceNames(areaId, dungeonEntry)
    local sourceName = SUPPLEMENTAL_INSTANCE_NAMES[areaId] or (dungeonEntry and dungeonEntry[1]) or ZoneDB:GetLocalizedDungeonName(areaId) or C_Map.GetAreaInfo(areaId)

    if sourceName then
        return sourceName, l10n(sourceName)
    end

    return nil, nil
end

local function _BuildTooltipTitle(entry, iconType)
    local title = entry.name
    local typeLabel = _GetTypeLabel(entry.kind)
    local groupSizeLabel = _GetGroupSizeLabel(entry)

    if entry.levelRange then
        title = title .. " " .. entry.levelRange
    end

    if groupSizeLabel then
        title = title .. " [" .. typeLabel .. ", " .. l10n(groupSizeLabel) .. "]"
    else
        title = title .. " [" .. typeLabel .. "]"
    end

    return (TITLE_COLORS[iconType] or "|cFFFFFFFF") .. title .. "|r"
end

local function _BuildTooltipBody(entry)
    local body = {}

    local lockouts = _GetEntryLockouts(entry)

    if lockouts then
        for _, lockout in ipairs(lockouts) do
            table.insert(body, { "|cFFA6A6A6Saved:|r", tostring(lockout.difficultyName or UNKNOWN) })
        end
    end

    return body
end

local function _RegisterManualFrame(kind, id, frameName)
    local typ = MANUAL_TYPES[kind]

    if not QuestieMap.manualFrames[typ] then
        QuestieMap.manualFrames[typ] = {}
    end

    if not QuestieMap.manualFrames[typ][id] then
        QuestieMap.manualFrames[typ][id] = {}
    end

    table.insert(QuestieMap.manualFrames[typ][id], frameName)
end

local function _CreateIconData(entry)
    local data = {}
    local isLocked = _IsEntryLocked(entry)
    local iconType = isLocked and "locked" or entry.kind

    data.id = entry.id
    data.Id = entry.id
    data.Icon = ICON_TEXTURES[iconType]
    data.TexCoords = ICON_TEX_COORDS[iconType]
    data.Type = "manual"
    data.Name = entry.name
    data.IsObjectiveNote = false
    data.ManualScaleType = "instance"
    data.GetIconScale = function()
        return ICON_SCALE[iconType] or ICON_SCALE.dungeon
    end
    data.IconScale = data:GetIconScale()
    data.ManualTooltipData = {
        Title = _BuildTooltipTitle(entry, iconType),
        Body = _BuildTooltipBody(entry),
        SortOrder = SORT_ORDER[entry.kind] or 99,
        SortName = entry.name,
        disableShiftToRemove = true,
    }

    return data
end

local function _GetProfileScale(isMinimap)
    if isMinimap then
        return Questie.db.profile.globalMiniMapInstanceScale or DEFAULT_SCALE.minimap
    end

    return Questie.db.profile.globalInstanceScale or DEFAULT_SCALE.map
end

local function _DrawEntry(entry)
    local data = _CreateIconData(entry)
    local uiMapId = ZoneDB:GetUiMapIdByAreaId(entry.areaId)

    if not uiMapId then
        return
    end

    local icon, iconMinimap = QuestieMap:DrawManualIcon(data, entry.areaId, entry.x, entry.y, MANUAL_TYPES[entry.kind])
    if not icon or not iconMinimap then
        return
    end

    icon.texture:SetTexCoord(unpack(data.TexCoords or ICON_TEX_COORDS.locked))
    icon.texture:SetVertexColor(1, 1, 1, 1)
    icon:SetWidth(16 * data:GetIconScale() * _GetProfileScale(false))
    icon:SetHeight(16 * data:GetIconScale() * _GetProfileScale(false))

    iconMinimap.texture:SetTexCoord(unpack(data.TexCoords or ICON_TEX_COORDS.locked))
    iconMinimap.texture:SetVertexColor(1, 1, 1, 1)
    iconMinimap.texture.r = 1
    iconMinimap.texture.g = 1
    iconMinimap.texture.b = 1
    iconMinimap.texture.a = 1
    iconMinimap:SetWidth(16 * data:GetIconScale() * _GetProfileScale(true))
    iconMinimap:SetHeight(16 * data:GetIconScale() * _GetProfileScale(true))

    QuestieMap.utils:RescaleIcon(icon)
    QuestieMap.utils:RescaleIcon(iconMinimap)
end

local function _GetLookupNames(...)
    local lookupNames = {}
    local seenNames = {}

    for index = 1, select("#", ...) do
        local lookupName = select(index, ...)
        local normalizedName = _NormalizeInstanceName(lookupName)

        if normalizedName and (not seenNames[normalizedName]) then
            seenNames[normalizedName] = true
            table.insert(lookupNames, normalizedName)
        end
    end

    return lookupNames
end

local function _BuildEntries()
    if _InstanceLocations.built then
        return
    end

    local dungeons = ZoneDB:GetDungeons()
    local areaIds = {}
    local seen = {}
    local nextId = 900000

    for areaId in pairs(dungeons) do
        areaIds[areaId] = true
    end

    for areaId in pairs(RAID_AREA_IDS) do
        if ZoneDB:GetDungeonLocation(areaId) then
            areaIds[areaId] = true
        end
    end

    for areaId in pairs(areaIds) do
        local dungeonEntry = dungeons[areaId]
        local locations = ZoneDB:GetDungeonLocation(areaId)
        if locations then
            local kind = RAID_AREA_IDS[areaId] and "raid" or "dungeon"
            local sourceName, localizedName = _GetInstanceNames(areaId, dungeonEntry)
            local lookupNames = _GetLookupNames(sourceName, localizedName)
            local levelRange = MeetingStones:GetLevelRangeByDungeonName(sourceName)

            for _, location in ipairs(locations) do
                local locationAreaId, x, y = location[1], location[2], location[3]
                local key = kind .. ":" .. localizedName .. ":" .. tostring(locationAreaId) .. ":" .. tostring(x) .. ":" .. tostring(y)

                if not seen[key] then
                    seen[key] = true
                    nextId = nextId + 1

                    table.insert(_InstanceLocations.entries[kind], {
                        id = nextId,
                        sourceAreaId = areaId,
                        areaId = locationAreaId,
                        x = x,
                        y = y,
                        kind = kind,
                        name = localizedName,
                        levelRange = levelRange,
                        lookupNames = lookupNames,
                    })
                end
            end
        end
    end

    table.sort(_InstanceLocations.entries.dungeon, function(a, b)
        if a.areaId == b.areaId then
            return a.name < b.name
        end
        return a.areaId < b.areaId
    end)

    table.sort(_InstanceLocations.entries.raid, function(a, b)
        if a.areaId == b.areaId then
            return a.name < b.name
        end
        return a.areaId < b.areaId
    end)

    _InstanceLocations.built = true
end

function InstanceLocations.Initialize()
    _EnsureProfileDefaults()
    _BuildEntries()
    _UpdateLockouts()

    if not _InstanceLocations.eventFrame then
        _InstanceLocations.eventFrame = CreateFrame("Frame")
        _InstanceLocations.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        _InstanceLocations.eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
        _InstanceLocations.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" and RequestRaidInfo then
                RequestRaidInfo()
            end

            _UpdateLockouts()

            if Questie.db and Questie.db.profile and (Questie.db.profile.showDungeonLocations or Questie.db.profile.showRaidLocations) then
                InstanceLocations:Refresh()
            end
        end)
    end
end

function InstanceLocations:Refresh(kind, forceRemove)
    _EnsureProfileDefaults()
    _BuildEntries()
    _UpdateLockouts()

    local kinds = kind and {kind} or {"dungeon", "raid"}

    for _, currentKind in ipairs(kinds) do
        QuestieMap:ResetManualFrames(MANUAL_TYPES[currentKind])

        if (not forceRemove) and Questie.db.profile[PROFILE_KEYS[currentKind]] then
            for _, entry in ipairs(_InstanceLocations.entries[currentKind]) do
                _DrawEntry(entry)
            end
        end
    end

    QuestieMap.ProcessQueue()
    QuestieMap.ProcessQueue()
end

function InstanceLocations:Toggle(kind)
    local profileKey = PROFILE_KEYS[kind]
    if not profileKey then
        return
    end

    Questie.db.profile[profileKey] = not Questie.db.profile[profileKey]
    self:Refresh(kind)
end

function InstanceLocations:OnLogin(forceRemove)
    self:Refresh(nil, forceRemove)
end