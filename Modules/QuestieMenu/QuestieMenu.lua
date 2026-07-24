---@class QuestieMenu
local QuestieMenu = QuestieLoader:CreateModule("QuestieMenu")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type MeetingStones
local MeetingStones = QuestieLoader:ImportModule("MeetingStones")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type InstanceLocations
local InstanceLocations = QuestieLoader:ImportModule("InstanceLocations")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")
---@type Moonwell
local Moonwell = QuestieLoader:ImportModule("Moonwell")
---@type QuestieIconVisibility
local QuestieIconVisibility = QuestieLoader:ImportModule("QuestieIconVisibility")
---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

local LibDropDown = QuestieCompat.LibUIDropDownMenu or LibStub:GetLibrary("LibUIDropDownMenuQuestie-4.0")
local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")

local tinsert = tinsert
local strlower = string.lower
local math_max = math.max
local math_huge = math.huge

local professionKeys = QuestieProfessions.professionKeys
local _instanceIconAtlas = QuestieLib.AddonPath .. "Icons\\instance_icons.blp"
local _instanceIconTexCoords = {
    dungeon = {0.912109, 0.955078, 0.0449219, 0.0664062},
    raid = {0.689453, 0.732422, 0.166016, 0.1875},
}

local _townsfolk_texturemap = {
    ["Flight Master"] = "Interface\\Minimap\\tracking\\flightmaster",
    ["Meeting Stones"] = QuestieLib.AddonPath.."Icons\\mstone.blp",
    ["Class Trainer"] = "Interface\\Minimap\\tracking\\class",
    ["Stable Master"] = "Interface\\Minimap\\tracking\\stablemaster",
    ["Spirit Healer"] = "Interface\\raidframe\\raid-icon-rez",
    ["Weapon Master"] = QuestieLib.AddonPath.."Icons\\weaponmaster.blp",
    ["Barber"] = QuestieLib.AddonPath.."Icons\\barbershop.blp",
    ["Riding Trainer"] = "Interface\\Icons\\ability_mount_ridinghorse",
    ["Moonwell"] = "Interface\\Icons\\inv_fabric_moonrag_01.blp",
    ["Profession Trainers"] = "Interface\\Minimap\\tracking\\profession",
    ["Ammo"] = "Interface\\Minimap\\tracking\\ammunition",
    ["Bags"] = 133634,--select(10, GetItemInfo(4496)) -- small brown pouch
    ["Potions"] = 134831,--select(10, GetItemInfo(929)) -- Healing Potion
    ["Trade Goods"] = 132912,--select(10, GetItemInfo(2321)) -- thread
    ["Drink"] = 134712,--select(10, GetItemInfo(8766)) -- morning glory dew
    ["Food"] = 133964,--select(10, GetItemInfo(4540)) -- bread
    ["Pet Food"] = 132165,--select(3, GetSpellInfo(6991)) -- feed pet
    ["Portal Trainer"] = "Interface\\Minimap\\vehicle-alliancemageportal",
    ["Reagents"] = "Interface\\Minimap\\tracking\\reagents",
    ["Poisons"] = "Interface\\Minimap\\tracking\\poisons",
    [professionKeys.FIRST_AID] = "Interface\\Icons\\spell_holy_sealofsacrifice",
    [professionKeys.BLACKSMITHING] = "Interface\\Icons\\trade_blacksmithing",
    [professionKeys.LEATHERWORKING] = "Interface\\Icons\\trade_leatherworking",
    [professionKeys.ALCHEMY] = "Interface\\Icons\\trade_alchemy",
    [professionKeys.HERBALISM] = "Interface\\Icons\\trade_herbalism",
    [professionKeys.COOKING] = "Interface\\Icons\\inv_misc_food_15",
    [professionKeys.MINING] = "Interface\\Icons\\trade_mining",
    [professionKeys.TAILORING] = "Interface\\Icons\\trade_tailoring",
    [professionKeys.ENGINEERING] = "Interface\\Icons\\trade_engineering",
    [professionKeys.ENCHANTING] = "Interface\\Icons\\trade_engraving",
    [professionKeys.FISHING] = "Interface\\Icons\\trade_fishing",
    [professionKeys.SKINNING] = "Interface\\Icons\\inv_misc_pelt_wolf_01",
    [professionKeys.JEWELCRAFTING] = "Interface\\Icons\\inv_misc_gem_01",
    [professionKeys.INSCRIPTION] = "Interface\\Icons\\inv_inscription_tradeskill01",
}
QuestieMenu.private.townsfolk_texturemap = _townsfolk_texturemap

local _spawned = {} -- used to check if we have already spawned an icon for this npc
local _availableRefreshTicker

---@param id NpcId
---@param key string|number
---@return string
local function getNpcTitle(id, key)
    local npcName = QuestieDB.QueryNPCSingle(id, "name") or ("Missing NPC name for " .. tostring(id))
    local npcTitle = Questie:Colorize(npcName, "white")

    local subName = QuestieDB.QueryNPCSingle(id, "subName")
    if (not subName) or subName == "" then
        local trainerName = QuestieProfessions.GetTrainerName(key)
        if trainerName then
            subName = l10n(trainerName)
        else
            subName = l10n(tostring(key))
        end
    end

    return npcTitle .. " (" .. subName .. ")"
end

local function _FlushDrawQueue()
    -- Drain part of the queue immediately so freshly enabled townsfolk icons
    -- appear sooner instead of waiting only for the periodic queue ticker.
    local queueSize = math_max(#QuestieMap._mapDrawQueue, #QuestieMap._minimapDrawQueue)
    local iterations = 1

    if queueSize > 800 then
        iterations = 6
    elseif queueSize > 400 then
        iterations = 4
    elseif queueSize > 150 then
        iterations = 3
    elseif queueSize > 0 then
        iterations = 2
    end

    for _ = 1, iterations do
        if (#QuestieMap._mapDrawQueue == 0) and (#QuestieMap._minimapDrawQueue == 0) then
            break
        end
        QuestieMap.ProcessQueue()
    end
end

local function _RunFastAvailableRefresh(rebuildAll)
    if _availableRefreshTicker then
        _availableRefreshTicker:Cancel()
        _availableRefreshTicker = nil
    end

    _availableRefreshTicker = C_Timer.NewTicker(0.02, function()
        _FlushDrawQueue()
    end)

    local refreshFunction = rebuildAll and AvailableQuests.RebuildAll or AvailableQuests.CalculateAndDrawAll
    refreshFunction(function()
        _FlushDrawQueue()
        if _availableRefreshTicker then
            _availableRefreshTicker:Cancel()
            _availableRefreshTicker = nil
        end
    end, true)
end

local function toggle(key, forceRemove) -- /run QuestieLoader:ImportModule("QuestieMap"):ShowNPC(525, nil, 1, "teaste", {}, true)
    if key == "Moonwell" then
        if Questie.db.profile.townsfolkConfig[key] and (not forceRemove) then
            Moonwell:ShowAll()
        else
            Moonwell:HideAll()
        end
        return
    end

    if Townsfolk:IsVendorCategory(key) or Questie.db.global.professionTrainers[key] then
        Townsfolk:EnsureVendorDataInitialized()
    end

    local ids = Questie.db.global.townsfolk[key] or
            Questie.db.char.townsfolk[key] or
            Questie.db.global.professionTrainers[key] or
            Questie.db.char.vendorList[key]

    if (not ids) then
        Questie:Debug(Questie.DEBUG_INFO, "Invalid townsfolk key", tostring(key))
        return
    end

    local icon = _townsfolk_texturemap[key] or ("Interface\\Minimap\\tracking\\" .. strlower(key))
    if key == "Mailbox" or key == "Meeting Stones" then -- object type townsfolk
        if Questie.db.profile.townsfolkConfig[key] and (not forceRemove) then
            for _, id in pairs(ids) do
                if key == "Meeting Stones" then
                    local dungeonName, levelRange = MeetingStones:GetLocalizedDungeonNameAndLevelRangeByObjectId(id)
                    if dungeonName and levelRange then
                        QuestieMap:ShowObject(id, icon, 1.2, Questie:Colorize(l10n("Meeting Stone"), "white") .. "|n" .. dungeonName .. " " .. levelRange, {}, true, key)
                    end
                else
                    QuestieMap:ShowObject(id, icon, 1.2, Questie:Colorize(l10n(key), "white"), {}, true, key)
                end
            end
            _FlushDrawQueue()
        else
            for _, id in pairs(ids) do
                QuestieMap:UnloadManualFrames(id, key)
            end
        end
    else
        if Questie.db.profile.townsfolkConfig[key] and (not forceRemove) then
            local faction = UnitFactionGroup("Player")
            local timer
            local e = 1
            local maxIndex = #ids
            local function _DrawTownsfolkBatch(batchSize)
                local count = 0
                while e <= maxIndex and count < batchSize do
                    local id = ids[e]
                    if (not _spawned[id]) then
                        local friendly = QuestieDB.QueryNPCSingle(id, "friendlyToFaction")
                        if ((not friendly) or friendly == "AH" or (faction == "Alliance" and friendly == "A") or (faction == "Horde" and friendly == "H")) and (not QuestieCorrections.questNPCBlacklist[id]) then
                            local npcTitle = getNpcTitle(id, key)
                            QuestieMap:ShowNPC(id, icon, 1.2, npcTitle, {}, true, key, true)
                            _spawned[id] = true
                        end
                    end
                    e = e + 1
                    count = count + 1
                end
                return e > maxIndex
            end

            -- Draw a larger first chunk immediately for better responsiveness when enabling townsfolk.
            if _DrawTownsfolkBatch(192) then
                _FlushDrawQueue()
                return
            end
            _FlushDrawQueue()

            timer = C_Timer.NewTicker(0.01, function()
                if _DrawTownsfolkBatch(192) then
                    _FlushDrawQueue()
                    timer:Cancel()
                    return
                end
                _FlushDrawQueue()
            end)
        else
            for _, id in pairs(ids) do
                QuestieMap:UnloadManualFrames(id, key)
                _spawned[id] = nil
            end
        end
    end
end

local function build(key)
    local icon = _townsfolk_texturemap[key] or ("Interface\\Minimap\\tracking\\" .. strlower(key))

    return {
        text = l10n(tostring(key)),
        func = function() Questie.db.profile.townsfolkConfig[key] = not Questie.db.profile.townsfolkConfig[key] toggle(key) end,
        icon=icon,
        notCheckable=false,
        checked=Questie.db.profile.townsfolkConfig[key],
        isNotRadio=true,
        keepShownOnClick=true
    }
end

local function buildLocalized(key, localizedText)
    local icon = _townsfolk_texturemap[key] or ("Interface\\Minimap\\tracking\\" .. strlower(key))

    return {
        text = localizedText,
        func = function() Questie.db.profile.townsfolkConfig[key] = not Questie.db.profile.townsfolkConfig[key] toggle(key) end,
        icon=icon,
        notCheckable=false,
        checked=Questie.db.profile.townsfolkConfig[key],
        isNotRadio=true,
        keepShownOnClick=true
    }
end

local function _GetFindNearestIds(key)
    local globalTownsfolk = Questie.db.global.townsfolk or {}
    local charTownsfolk = Questie.db.char.townsfolk or {}
    local professionTrainers = Questie.db.global.professionTrainers or {}
    local vendorList = Questie.db.char.vendorList or {}

    if Townsfolk:IsVendorCategory(key) or professionTrainers[key] then
        Townsfolk:EnsureVendorDataInitialized()
        vendorList = Questie.db.char.vendorList or vendorList
    end

    return globalTownsfolk[key] or charTownsfolk[key] or professionTrainers[key] or vendorList[key]
end

local function _IsFindNearestObjectCategory(key)
    return key == "Mailbox" or key == "Meeting Stones"
end

local function _IsFindNearestNPCAllowed(npcId)
    local friendly = QuestieDB.QueryNPCSingle(npcId, "friendlyToFaction")
    local faction = UnitFactionGroup("Player")

    return ((not friendly) or friendly == "AH" or (faction == "Alliance" and friendly == "A") or (faction == "Horde" and friendly == "H"))
            and (not QuestieCorrections.questNPCBlacklist[npcId])
end

local function _IsFindNearestSpawnVisible(spawn)
    return Phasing.IsSpawnDataVisible(spawn)
end

local function _GetFindNearestPlayerWorldPosition()
    if QuestieCompat.GetCurrentPlayerMinimapWorldPosition then
        local playerX, playerY, playerInstance = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
        if playerX and playerY then
            return playerX, playerY, playerInstance
        end
    end

    if HBD and HBD.GetPlayerWorldPosition then
        return HBD:GetPlayerWorldPosition()
    end
end

local function _GetResolvedFindNearestSpawns(zone, spawn)
    if spawn[1] ~= -1 and spawn[2] ~= -1 then
        return {{ zone = zone, x = spawn[1], y = spawn[2] }}
    end

    local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
    if not dungeonLocation then
        local parentZoneId = ZoneDB:GetParentZoneId(zone)
        if parentZoneId then
            dungeonLocation = ZoneDB:GetDungeonLocation(parentZoneId)
        end
    end

    local resolvedSpawns = {}
    for _, location in pairs(dungeonLocation or {}) do
        tinsert(resolvedSpawns, { zone = location[1], x = location[2], y = location[3] })
    end

    return resolvedSpawns
end

local function _CheckFindNearestSpawn(best, id, name, zone, spawn, playerX, playerY, playerInstance)
    if not (HBD and HBD.GetWorldCoordinatesFromZone and HBD.GetWorldDistance) then
        return best
    end

    if not _IsFindNearestSpawnVisible(spawn) then
        return best
    end

    for _, resolvedSpawn in pairs(_GetResolvedFindNearestSpawns(zone, spawn)) do
        local uiMapId = ZoneDB:GetUiMapIdByAreaId(resolvedSpawn.zone)
        if uiMapId then
            local worldX, worldY, spawnInstance = HBD:GetWorldCoordinatesFromZone(resolvedSpawn.x / 100, resolvedSpawn.y / 100, uiMapId)
            if worldX and worldY and spawnInstance then
                local distance = HBD:GetWorldDistance(spawnInstance, playerX, playerY, worldX, worldY)
                if distance then
                    if playerInstance and spawnInstance ~= playerInstance then
                        distance = 500000 + distance * 100
                    end

                    if distance < best.distance then
                        best.distance = distance
                        best.id = id
                        best.name = name
                        best.zone = resolvedSpawn.zone
                        best.x = resolvedSpawn.x
                        best.y = resolvedSpawn.y
                    end
                end
            end
        end
    end

    return best
end

local function _FindNearestTownsfolkSpawn(key, ids, isObjectCategory)
    local playerX, playerY, playerInstance = _GetFindNearestPlayerWorldPosition()
    if not playerX or not playerY then
        Questie:Print(l10n("Unable to determine player position."))
        return nil
    end

    local best = { distance = math_huge }
    for _, id in pairs(ids) do
        local spawns, name
        if isObjectCategory then
            spawns = QuestieDB.QueryObjectSingle(id, "spawns")
            name = QuestieDB.QueryObjectSingle(id, "name") or l10n(tostring(key))
        elseif _IsFindNearestNPCAllowed(id) then
            spawns = QuestieDB.QueryNPCSingle(id, "spawns")
            name = QuestieDB.QueryNPCSingle(id, "name") or l10n(tostring(key))
        end

        if spawns then
            for zone, zoneSpawns in pairs(spawns) do
                for _, spawn in pairs(zoneSpawns) do
                    best = _CheckFindNearestSpawn(best, id, name, zone, spawn, playerX, playerY, playerInstance)
                end
            end
        end
    end

    if best.zone then
        return best
    end
end

function QuestieMenu.FindNearest(key, localizedText)
    if not (TomTom and TomTom.AddWaypoint) then
        Questie:Print(l10n("TomTom is not installed."))
        return
    end

    local ids = _GetFindNearestIds(key)
    if not ids then
        Questie:Print(l10n("No locations found for %s.", localizedText))
        return
    end

    local nearest = _FindNearestTownsfolkSpawn(key, ids, _IsFindNearestObjectCategory(key))
    if not nearest then
        Questie:Print(l10n("No nearby location found for %s.", localizedText))
        return
    end

    local title = l10n("Find Nearest") .. ": " .. localizedText
    if nearest.name then
        title = title .. " - " .. nearest.name
    end

    TrackerUtils:SetTomTomTarget(title, nearest.zone, nearest.x, nearest.y)
    Questie:Print(l10n("TomTom waypoint set: %s.", title))
end

local function buildFindNearest(key, localizedText)
    local icon = _townsfolk_texturemap[key] or ("Interface\\Minimap\\tracking\\" .. strlower(key))
    localizedText = localizedText or l10n(tostring(key))

    return {
        text = localizedText,
        func = function() QuestieMenu.FindNearest(key, localizedText) end,
        icon = icon,
        notCheckable = true
    }
end

function QuestieMenu.buildInstancesMenu()
    return {
        build("Meeting Stones"),
        {
            text = l10n("Dungeon Locations"),
            func = function()
                InstanceLocations:Toggle("dungeon")
            end,
            icon = _instanceIconAtlas,
            tCoordLeft = _instanceIconTexCoords.dungeon[1],
            tCoordRight = _instanceIconTexCoords.dungeon[2],
            tCoordTop = _instanceIconTexCoords.dungeon[3],
            tCoordBottom = _instanceIconTexCoords.dungeon[4],
            notCheckable = false,
            checked = Questie.db.profile.showDungeonLocations,
            isNotRadio = true,
            keepShownOnClick = true
        },
        {
            text = l10n("Raid Locations"),
            func = function()
                InstanceLocations:Toggle("raid")
            end,
            icon = _instanceIconAtlas,
            tCoordLeft = _instanceIconTexCoords.raid[1],
            tCoordRight = _instanceIconTexCoords.raid[2],
            tCoordTop = _instanceIconTexCoords.raid[3],
            tCoordBottom = _instanceIconTexCoords.raid[4],
            notCheckable = false,
            checked = Questie.db.profile.showRaidLocations,
            isNotRadio = true,
            keepShownOnClick = true
        }
    }
end

function QuestieMenu:OnLogin(forceRemove) -- toggle all icons
    if (not Questie.db.profile.townsfolkConfig) then
        Questie.db.profile.townsfolkConfig = {
            ["Flight Master"] = true,
            ["Mailbox"] = true,
            ["Meeting Stones"] = false,
            ["Moonwell"] = false
        }
    else
        if Questie.db.profile.townsfolkConfig["Meeting Stones"] == nil then
            Questie.db.profile.townsfolkConfig["Meeting Stones"] = false
        end

        if Questie.db.profile.townsfolkConfig["Moonwell"] == nil then
            Questie.db.profile.townsfolkConfig["Moonwell"] = false
        end
    end

    for key in pairs(Questie.db.profile.townsfolkConfig) do
        if forceRemove then
            toggle(key, forceRemove)
        end
        toggle(key)
    end

    InstanceLocations:OnLogin(forceRemove)
end

local div = { -- from libEasyMenu code
    hasArrow = false,
    dist = 0,
    isTitle = true,
    isUninteractable = true,
    notCheckable = true,
    iconOnly = true,
    isSeparator = true,
    icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
    tCoordLeft = 0,
    tCoordRight = 1,
    tCoordTop = 0,
    tCoordBottom = 1,
    tSizeX = 0,
    tSizeY = 8,
    tFitDropDownSizeX = true,
    text="",
    iconInfo = {
        tCoordLeft = 0,
        tCoordRight = 1,
        tCoordTop = 0,
        tCoordBottom = 1,
        tSizeX = 0,
        tSizeY = 8,
        tFitDropDownSizeX = true
    },
}
local secondaryProfessions = {
    [professionKeys.FIRST_AID] = true,
    [professionKeys.COOKING] = true,
    [professionKeys.FISHING] = true
}

function QuestieMenu.buildTailoringSubmenu()
    return {
        {
            text = l10n(QuestieProfessions:GetProfessionName(professionKeys.TAILORING)),
            func = function()
                Questie.db.profile.townsfolkConfig[professionKeys.TAILORING] = not Questie.db.profile.townsfolkConfig[professionKeys.TAILORING]
                toggle(professionKeys.TAILORING)
            end,
            icon = _townsfolk_texturemap[professionKeys.TAILORING],
            notCheckable = false,
            checked = Questie.db.profile.townsfolkConfig[professionKeys.TAILORING],
            isNotRadio = true,
            keepShownOnClick = true
        },
        {
            text = l10n("Moonwell"),
            func = function()
                Questie.db.profile.townsfolkConfig["Moonwell"] = not Questie.db.profile.townsfolkConfig["Moonwell"]
                toggle("Moonwell")
            end,
            icon = "Interface\\Icons\\inv_fabric_moonrag_01",
            notCheckable = false,
            checked = Questie.db.profile.townsfolkConfig["Moonwell"],
            isNotRadio = true,
            keepShownOnClick = true
        }
    }
end

function QuestieMenu.buildProfessionMenu()
    Townsfolk:EnsureVendorDataInitialized()

    local profMenu = {}
    local profMenuSorted = {}
    local secondaryProfMenuSorted = {}
    local profMenuData = {}
    for key, _ in pairs(Questie.db.global.professionTrainers) do
        local localizedKey = l10n(QuestieProfessions:GetProfessionName(key))
        if key == professionKeys.TAILORING then
            profMenuData[localizedKey] = {
                text = localizedKey,
                func = function() end,
                keepShownOnClick = true,
                hasArrow = true,
                menuList = QuestieMenu.buildTailoringSubmenu(),
                notCheckable = true
            }
        else
            profMenuData[localizedKey] = buildLocalized(key, localizedKey)
        end
        if secondaryProfessions[key] then
            tinsert(secondaryProfMenuSorted, localizedKey)
        else
            tinsert(profMenuSorted, localizedKey)
        end
    end
    table.sort(profMenuSorted)
    table.sort(secondaryProfMenuSorted)
    for _, key in pairs(profMenuSorted) do
        tinsert(profMenu, profMenuData[key])
    end
    tinsert(profMenu, div)
    for _, key in pairs(secondaryProfMenuSorted) do
        tinsert(profMenu, profMenuData[key])
    end
    return profMenu
end

function QuestieMenu.buildVendorMenu()
    Townsfolk:EnsureVendorDataInitialized()

    local vendorMenu = {}
    local vendorMenuSorted = {}
    local vendorMenuData = {}
    for key, _ in pairs(Questie.db.char.vendorList) do
        local localizedKey = l10n(tostring(key))
        vendorMenuData[localizedKey] = build(key)
        tinsert(vendorMenuSorted, localizedKey)
    end
    table.sort(vendorMenuSorted)
    for _, key in pairs(vendorMenuSorted) do
        tinsert(vendorMenu, vendorMenuData[key])
    end
    return vendorMenu
end

local function _BuildSortedFindNearestMenu(entries, useSecondarySections)
    local menu, primary, secondary, data = {}, {}, {}, {}

    for _, entry in pairs(entries) do
        local key, localizedKey = entry[1], entry[2]
        data[localizedKey] = buildFindNearest(key, localizedKey)
        tinsert((useSecondarySections and secondaryProfessions[key]) and secondary or primary, localizedKey)
    end

    table.sort(primary)
    table.sort(secondary)
    for _, key in pairs(primary) do
        tinsert(menu, data[key])
    end

    if useSecondarySections and #secondary > 0 then
        tinsert(menu, div)
        for _, key in pairs(secondary) do
            tinsert(menu, data[key])
        end
    end

    return menu
end

local function _GetFindNearestTownsfolkEntries()
    local entries, seen = {}, {}
    for _, source in pairs({Questie.db.global.townsfolk or {}, Questie.db.char.townsfolk or {}}) do
        for key in pairs(source) do
            if key ~= "Meeting Stones" and not seen[key] then
                seen[key] = true
                tinsert(entries, {key, l10n(tostring(key))})
            end
        end
    end
    return entries
end

local function _GetFindNearestProfessionEntries()
    Townsfolk:EnsureVendorDataInitialized()

    local entries = {}
    for key in pairs(Questie.db.global.professionTrainers or {}) do
        tinsert(entries, {key, l10n(QuestieProfessions:GetProfessionName(key))})
    end
    return entries
end

local function _GetFindNearestVendorEntries()
    Townsfolk:EnsureVendorDataInitialized()

    local entries = {}
    for key in pairs(Questie.db.char.vendorList or {}) do
        tinsert(entries, {key, l10n(tostring(key))})
    end
    return entries
end

function QuestieMenu.buildFindNearestMenu()
    return {
        {
            text = l10n("Townsfolk"),
            func = function() end,
            keepShownOnClick = true,
            hasArrow = true,
            menuList = _BuildSortedFindNearestMenu(_GetFindNearestTownsfolkEntries()),
            notCheckable = true
        },
        {
            text = l10n("Profession Trainers"),
            func = function() end,
            keepShownOnClick = true,
            hasArrow = true,
            menuList = _BuildSortedFindNearestMenu(_GetFindNearestProfessionEntries(), true),
            notCheckable = true
        },
        {
            text = l10n("Vendor"),
            func = function() end,
            keepShownOnClick = true,
            hasArrow = true,
            menuList = _BuildSortedFindNearestMenu(_GetFindNearestVendorEntries()),
            notCheckable = true
        }
    }
end

function QuestieMenu.buildTownsfolkMenu()
    local townsfolkMenu, townsfolkSorted, townsfolkData, seen = {}, {}, {}, {}
    for _, source in pairs({Questie.db.global.townsfolk or {}, Questie.db.char.townsfolk or {}}) do
        for key in pairs(source) do
            if key ~= "Meeting Stones" and not seen[key] then
                local localizedKey = l10n(tostring(key))
                seen[key] = true
                townsfolkData[localizedKey] = build(key)
                tinsert(townsfolkSorted, localizedKey)
            end
        end
    end

    table.sort(townsfolkSorted)
    for _, key in pairs(townsfolkSorted) do
        tinsert(townsfolkMenu, townsfolkData[key])
    end
    return townsfolkMenu
end

function QuestieMenu.buildQuestMenu()
    return {
        {
            text = l10n("Available Quest"),
            func = function()
                local value = not QuestieIconVisibility:IsEnabledAnywhere("available")
                QuestieIconVisibility:SetBoth("available", value)
                _RunFastAvailableRefresh(true)
            end,
            icon = QuestieLib.AddonPath.."Icons\\available.blp",
            notCheckable = false,
            checked = QuestieIconVisibility:IsEnabledAnywhere("available"),
            isNotRadio = true,
            keepShownOnClick = true
        },
        {
            text = l10n("Objective"),
            func = function()
                local value = not QuestieIconVisibility:IsEnabledAnywhere("objective")
                QuestieIconVisibility:SetBoth("objective", value)
                if value then
                    -- Rebuild objective notes that were not created while objectives were disabled.
                    QuestieQuest:GetAllQuestIds()
                end
                QuestieQuest:RefreshQuestIconVisibility()
            end,
            icon = QuestieLib.AddonPath.."Icons\\event.blp",
            notCheckable = false,
            checked = QuestieIconVisibility:IsEnabledAnywhere("objective"),
            isNotRadio = true,
            keepShownOnClick = true
        },
        {
            text = l10n("Repeatable Quests"),
            func = function()
                local value = not QuestieIconVisibility:IsEnabledAnywhere("repeatable")
                QuestieIconVisibility:SetBoth("repeatable", value)
                _RunFastAvailableRefresh()
            end,
            icon = QuestieLib.AddonPath.."Icons\\repeatable.blp",
            notCheckable = false,
            checked = QuestieIconVisibility:IsEnabledAnywhere("repeatable"),
            isNotRadio = true,
            keepShownOnClick = true
        },
        {
            text = l10n("Trivial Quest"),
            func = function()
                local value = Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_ALL
                if value then
                    Questie.db.profile.lowLevelStyle = Questie.LOWLEVEL_NONE
                else
                    Questie.db.profile.lowLevelStyle = Questie.LOWLEVEL_ALL
                end
                AvailableQuests.ResetLevelRequirementCache()
                AvailableQuests.PruneByCurrentLevelFilter()
                _RunFastAvailableRefresh()
            end,
            icon = QuestieLib.AddonPath.."Icons\\available_gray.blp",
            notCheckable = false,
            checked = Questie.db.profile.lowLevelStyle==Questie.LOWLEVEL_ALL,
            isNotRadio = true,
            keepShownOnClick = true
        }
    }
end

function QuestieMenu:Show(hideDelay)
    if not Questie.db.profile.townsfolkConfig then
        Questie.db.profile.townsfolkConfig = {}
    end
    if not QuestieMenu.menu then
        QuestieMenu.menu = LibDropDown:Create_UIDropDownMenu("QuestieTownsfolkMenuFrame", UIParent)
    end
    local menuTable = {}
    tinsert(menuTable, {text = l10n("Instances"), func = function() end, keepShownOnClick = true, hasArrow = true, menuList = QuestieMenu.buildInstancesMenu(), notCheckable = true})
    tinsert(menuTable, {text= l10n("Profession Trainers"), func = function() end, keepShownOnClick=true, hasArrow=true, menuList=QuestieMenu.buildProfessionMenu(), notCheckable=true})
    tinsert(menuTable, {text = l10n("Quests"), func = function() end, keepShownOnClick = true, hasArrow = true, menuList = QuestieMenu.buildQuestMenu(), notCheckable = true})
    tinsert(menuTable, {text = l10n("Townsfolk"), func = function() end, keepShownOnClick = true, hasArrow = true, menuList = QuestieMenu.buildTownsfolkMenu(), notCheckable = true})
    tinsert(menuTable, {text= l10n("Vendor"), func = function() end, keepShownOnClick=true, hasArrow=true, menuList=QuestieMenu.buildVendorMenu(), notCheckable=true})
    tinsert(menuTable, div)
    tinsert(menuTable, {text = Questie:Colorize(l10n("Find Nearest"), "lightBlue"), func = function() end, keepShownOnClick = true, hasArrow = true, menuList = QuestieMenu.buildFindNearestMenu(), notCheckable = true})

    tinsert(menuTable, div)

    tinsert(menuTable, { text= l10n('Advanced Search'), func=function()
        QuestieOptions:HideFrame()
        QuestieJourney:BuildMainFrame()
        QuestieJourney.tabGroup:SelectTab("search")
        if not QuestieJourney:IsShown() then
            QuestieJourney:ToggleJourneyWindow()
        end
    end})
    tinsert(menuTable, { text= l10n('Quests by Zone'), func=function()
        QuestieOptions:HideFrame()
        QuestieJourney:BuildMainFrame()
        QuestieJourney.tabGroup:SelectTab("zone")
        if not QuestieJourney:IsShown() then
            QuestieJourney:ToggleJourneyWindow()
        end
    end})
    tinsert(menuTable, { text= l10n('Quests by Faction'), func=function()
        QuestieOptions:HideFrame()
        QuestieJourney:BuildMainFrame()
        QuestieJourney.tabGroup:SelectTab("faction")
        if not QuestieJourney:IsShown() then
            QuestieJourney:ToggleJourneyWindow()
        end
    end})
    tinsert(menuTable, { text= l10n("Questie Options"), func=function()
        QuestieCombatQueue:Queue(function()
            QuestieOptions:OpenConfigWindow()
        end)
    end})

    tinsert(menuTable, { text= l10n('My Journey'), func=function()
        QuestieCombatQueue:Queue(function()
            QuestieOptions:HideFrame()
            QuestieJourney:BuildMainFrame()
            QuestieJourney.tabGroup:SelectTab("journey")
            if not QuestieJourney:IsShown() then
                QuestieJourney:ToggleJourneyWindow()
            end
        end)
    end})

    if Questie.db.profile.debugEnabled then -- add recompile db & reload buttons when debugging is enabled
        tinsert(menuTable, { text= l10n('Recompile Database'), func=function()
            Questie.db.global.dbIsCompiled = false
            ReloadUI()
        end})
        tinsert(menuTable, { text= l10n('Reload UI'), func=function() ReloadUI() end})
    end

    tinsert(menuTable, {text= Questie:Colorize(l10n("Cancel"), "pvpRed"), func=function() end})
    LibDropDown:EasyMenu(menuTable, QuestieMenu.menu, "cursor", -80, -15, "MENU", hideDelay or 2)
end

function QuestieMenu:ShowTownsfolk(hideDelay)
    if not Questie.db.profile.townsfolkConfig then
        Questie.db.profile.townsfolkConfig = {}
    end
    if not QuestieMenu.menuTowns then
        QuestieMenu.menuTowns = LibDropDown:Create_UIDropDownMenu("QuestieTownsfolkMenuFrameTownsfolk", UIParent)
    end
    local menuTable = QuestieMenu.buildTownsfolkMenu()
    tinsert(menuTable, {text = l10n("Instances"), func = function() end, keepShownOnClick = true, hasArrow = true, menuList = QuestieMenu.buildInstancesMenu(), notCheckable = true})
    tinsert(menuTable, {text= l10n('Cancel'), func=function() end})
    LibDropDown:EasyMenu(menuTable, QuestieMenu.menuTowns, "cursor", -80, -15, "MENU", hideDelay)
end

function QuestieMenu:ShowProfessions(hideDelay)
    if not Questie.db.profile.townsfolkConfig then
        Questie.db.profile.townsfolkConfig = {}
    end
    if not QuestieMenu.menuProfs then
        QuestieMenu.menuProfs = LibDropDown:Create_UIDropDownMenu("QuestieTownsfolkMenuFrameProfs", UIParent)
    end
    local menuTable = QuestieMenu.buildProfessionMenu()
    tinsert(menuTable, {text= l10n('Cancel'), func=function() end})
    LibDropDown:EasyMenu(menuTable, QuestieMenu.menuProfs, "cursor", -75, -15, "MENU", hideDelay)
end

function QuestieMenu:ShowVendors(hideDelay)
    if not Questie.db.profile.townsfolkConfig then
        Questie.db.profile.townsfolkConfig = {}
    end
    if not QuestieMenu.menuVendors then
        QuestieMenu.menuVendors = LibDropDown:Create_UIDropDownMenu("QuestieTownsfolkMenuFrameVendors", UIParent)
    end
    local menuTable = QuestieMenu.buildVendorMenu()
    tinsert(menuTable, {text= l10n('Cancel'), func=function() end})
    LibDropDown:EasyMenu(menuTable, QuestieMenu.menuVendors, "cursor", -60, -15, "MENU", hideDelay)
end
