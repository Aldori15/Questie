---@type QuestieJourney
local QuestieJourney = QuestieLoader:CreateModule("QuestieJourney")
local _QuestieJourney = QuestieJourney.private
-------------------------
--Import modules.
-------------------------
---@type QuestieJourneyUtils
local QuestieJourneyUtils = QuestieLoader:ImportModule("QuestieJourneyUtils")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local AceGUI = LibStub("AceGUI-3.0")

local RESET = -1000

local _CreateContinentDropdown, _CreateZoneDropdown
local _HandleContinentSelection, _HandleZoneSelection
local _GetCategorySelectText, _GetRelevantProfessions

local selectedContinentId
local contDropdown, zoneDropdown, treegroup

-- function that draws the Tab for Zone Quests
function _QuestieJourney.questsByZone:DrawTab(container)
    ---@class AceSimpleGroup
    treegroup = AceGUI:Create("SimpleGroup")

    -- Header
    local header = AceGUI:Create("Heading")
    header:SetText(l10n('Select Category'))
    header:SetFullWidth(true)
    container:AddChild(header)

    QuestieJourneyUtils:Spacer(container)

    contDropdown = _CreateContinentDropdown()
    container:AddChild(contDropdown)

    zoneDropdown = _CreateZoneDropdown()
    container:AddChild(zoneDropdown)

    QuestieJourneyUtils:Spacer(container)

    header = AceGUI:Create("Heading")
    header:SetText(l10n('Quests'))
    header:SetFullWidth(true)
    container:AddChild(header)

    QuestieJourneyUtils:Spacer(container)

    treegroup:SetFullHeight(true)
    treegroup:SetFullWidth(true)
    treegroup:SetLayout("fill")
    container:AddChild(treegroup)
end

_GetCategorySelectText = function(categoryId)
    local questCategoryKeys = QuestieJourney.questCategoryKeys
    if categoryId == questCategoryKeys.DUNGEONS then
        return l10n('Select Dungeon')
    elseif categoryId == questCategoryKeys.BATTLEGROUNDS then
        return l10n('Select Battleground')
    elseif categoryId == questCategoryKeys.EVENTS then
        return l10n('Select Event')
    elseif categoryId == questCategoryKeys.PROFESSIONS then
        return l10n('Select Profession')
    end

    return l10n('Select Zone')
end

_GetRelevantProfessions = function()
    local professionList = QuestieJourney.zones[QuestieJourney.questCategoryKeys.PROFESSIONS] or {}
    local playerProfessions = QuestieProfessions:GetPlayerProfessionNames()

    local relevantProfessions = {}
    for id, possibleName in pairs(professionList) do
        for _, name in pairs(playerProfessions) do
            if possibleName == name then
                relevantProfessions[id] = professionList[id]
                break
            end
        end
    end

    return relevantProfessions
end

_CreateContinentDropdown = function()
    local dropdown = AceGUI:Create("Dropdown")
    local list = {
        ["ALL_QUESTS"] = l10n("All Quests"),
        ["_SEPARATOR"] = "|cff7f7f7f----------------|r"
    }
    for id, name in pairs(QuestieJourney.continents) do
        list[id] = name
    end
    local order = { "ALL_QUESTS", "_SEPARATOR" }
    -- Sort by numeric key (questCategoryKeys order) instead of alphabetically
    local sortedKeys = {}
    for id in pairs(QuestieJourney.continents) do
        table.insert(sortedKeys, id)
    end
    table.sort(sortedKeys)
    for _, key in ipairs(sortedKeys) do
        table.insert(order, key)
    end
    dropdown:SetList(list, order)
    dropdown:SetText(l10n('All Quests'))
    dropdown:SetCallback("OnValueChanged", _HandleContinentSelection)

    local currentContinentId = QuestiePlayer:GetCurrentContinentId()

    local questCategoryKeys = QuestieJourney.questCategoryKeys
    -- This mapping translates the actual continent ID to the keys of l10n.continentLookup
    if currentContinentId == 0 then -- Eastern Kingdoms
        selectedContinentId = questCategoryKeys.EASTERN_KINGDOMS
    elseif currentContinentId == 1 then -- Kalimdor
        selectedContinentId = questCategoryKeys.KALIMDOR
    elseif currentContinentId == 530 then -- Outland
        selectedContinentId = questCategoryKeys.OUTLAND
    elseif currentContinentId == 571 then -- Northrend
        selectedContinentId = questCategoryKeys.NORTHREND
    elseif currentContinentId == 870 then -- Pandaria
        selectedContinentId = questCategoryKeys.PANDARIA
    elseif l10n.zoneLookup[currentContinentId] then -- Dungeon
        selectedContinentId = questCategoryKeys.DUNGEONS
    end

    if _QuestieJourney.lastZoneSelection[1] then
        selectedContinentId = _QuestieJourney.lastZoneSelection[1]
    end

    if not selectedContinentId then
        selectedContinentId = questCategoryKeys.EASTERN_KINGDOMS
    end

    dropdown:SetValue(selectedContinentId)
    return dropdown
end

_CreateZoneDropdown = function()
    local dropdown = AceGUI:Create("Dropdown")

    local currentZoneId = QuestiePlayer:GetCurrentZoneId()
    if _QuestieJourney.lastZoneSelection[2] then
        currentZoneId = _QuestieJourney.lastZoneSelection[2]
    end

    local zones = QuestieJourney.zones[selectedContinentId]
    if selectedContinentId == QuestieJourney.questCategoryKeys.PROFESSIONS then
        zones = _GetRelevantProfessions()
        if not next(zones) then
            zones = nil
        end
    end

    if zones then
        local sortedZones = QuestieJourneyUtils:GetSortedZoneKeys(zones)
        dropdown:SetList(zones, sortedZones)

        if currentZoneId and currentZoneId ~= RESET and zones[currentZoneId] then
            dropdown:SetValue(currentZoneId)

            local zoneTree = _QuestieJourney.questsByZone:CollectZoneQuests(currentZoneId)
            if zoneTree then
                _QuestieJourney.questsByZone:ManageTree(treegroup, zoneTree)
            end
        else
            dropdown:SetText(_GetCategorySelectText(selectedContinentId))
        end
    elseif selectedContinentId == QuestieJourney.questCategoryKeys.PROFESSIONS then
        dropdown:SetList({})
        dropdown:SetText(l10n('No Quests found'))
        dropdown:SetDisabled(true)
    else
        dropdown:SetDisabled(true)
    end

    dropdown:SetCallback("OnValueChanged", _HandleZoneSelection)
    return dropdown
end

_HandleContinentSelection = function(key, _)
    if (key.value == QuestieJourney.questCategoryKeys.CLASS) then
        local _, class, _ = UnitClass("player")
        local classKey = QuestieDB:GetZoneOrSortForClass(class)
        local zoneTree = _QuestieJourney.questsByZone:CollectZoneQuests(classKey)
        _QuestieJourney.questsByZone:ManageTree(treegroup, zoneTree)
        zoneDropdown.frame:Hide()
    elseif (key.value == QuestieJourney.questCategoryKeys.DUNGEONS) then
        local text = l10n('Select Dungeon')
        local dungeonZones = QuestieJourney.zones[QuestieJourney.questCategoryKeys.DUNGEONS] or {}
        local sortedDungeons = QuestieJourneyUtils:GetSortedZoneKeys(dungeonZones)
        zoneDropdown:SetList(dungeonZones, sortedDungeons)
        zoneDropdown:SetDisabled(false)
        zoneDropdown:SetText(text)
        zoneDropdown.frame:Show()
    elseif (key.value == QuestieJourney.questCategoryKeys.BATTLEGROUNDS) then
        local text = l10n('Select Battleground')
        local bgZones = QuestieJourney.zones[QuestieJourney.questCategoryKeys.BATTLEGROUNDS] or {}
        local sortedBGs = QuestieJourneyUtils:GetSortedZoneKeys(bgZones)
        zoneDropdown:SetList(bgZones, sortedBGs)
        zoneDropdown:SetDisabled(false)
        zoneDropdown:SetText(text)
        zoneDropdown.frame:Show()
    elseif (key.value == QuestieJourney.questCategoryKeys.EVENTS) then
        local text = l10n('Select Event')
        local eventZones = QuestieJourney.zones[QuestieJourney.questCategoryKeys.EVENTS] or {}
        local sortedEvents = QuestieJourneyUtils:GetSortedZoneKeys(eventZones)
        zoneDropdown:SetList(eventZones, sortedEvents)
        zoneDropdown:SetDisabled(false)
        zoneDropdown:SetText(text)
        zoneDropdown.frame:Show()
    elseif (key.value == QuestieJourney.questCategoryKeys.PROFESSIONS) then
        local relevantProfessions = _GetRelevantProfessions()
        local text = l10n('Select Profession')
        if (not next(relevantProfessions)) then
            text = l10n('No Quests found')
            zoneDropdown:SetDisabled(true)
        else
            zoneDropdown:SetDisabled(false)
        end
        zoneDropdown:SetList(relevantProfessions)
        zoneDropdown:SetText(text)
        zoneDropdown.frame:Show()
    else
        local sortedZones = QuestieJourneyUtils:GetSortedZoneKeys(QuestieJourney.zones[key.value])
        zoneDropdown:SetList(QuestieJourney.zones[key.value], sortedZones)
        zoneDropdown:SetText(l10n("Select Zone"))
        zoneDropdown:SetDisabled(false)
        zoneDropdown.frame:Show()
    end

    _QuestieJourney.lastZoneSelection[2] = RESET
    _QuestieJourney.lastZoneSelection[1] = key.value
end

_HandleZoneSelection = function(key, _)
    local zoneTree = _QuestieJourney.questsByZone:CollectZoneQuests(key.value)
    _QuestieJourney.questsByZone:ManageTree(treegroup, zoneTree)
    _QuestieJourney.lastZoneSelection[2] = key.value
end
