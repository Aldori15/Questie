---@class QuestieTooltips
local QuestieTooltips = QuestieLoader:CreateModule("QuestieTooltips");
local _QuestieTooltips = QuestieTooltips.private
-------------------------
--Import modules.
-------------------------
---@type QuestieComms
local QuestieComms = QuestieLoader:ImportModule("QuestieComms");
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib");
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer");
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

--- COMPATIBILITY ---
local UnitInParty = QuestieCompat.UnitInParty
local IsInGroup = QuestieCompat.IsInGroup
local GetClassColor = QuestieCompat.GetClassColor
local C_Map = QuestieCompat.C_Map

local tinsert = table.insert
local zoneNameToAreaIds
QuestieTooltips.lastGametooltip = ""
QuestieTooltips.lastGametooltipCount = -1;
QuestieTooltips.lastGametooltipType = "";
QuestieTooltips.lastFrameName = "";

local TOOLTIP_OBJECT_POLL_INTERVAL = 0.1

QuestieTooltips.lookupByKey = {
    --["u_Grell"] = {questid, {"Line 1", "Line 2"}}
}
QuestieTooltips.lookupKeysByQuestId = {
    --["questId"] = {["u_Grell"] = true, ... }
}

local MAX_GROUP_MEMBER_COUNT = 6

local _InitObjectiveTexts

local function _GetTooltipPrimaryText(tooltip)
    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    local titleFrame = tooltipName and _G[tooltipName .. "TextLeft1"]
    return titleFrame and titleFrame:GetText() or nil
end

local function _ResetTooltipTracking(tooltip)
    QuestieTooltips.lastGametooltip = ""
    QuestieTooltips.lastItemRefTooltip = ""
    QuestieTooltips.lastGametooltipItem = nil
    QuestieTooltips.lastGametooltipUnit = nil
    QuestieTooltips.lastGametooltipCount = 0
    QuestieTooltips.lastGametooltipType = ""
    QuestieTooltips.lastFrameName = ""

    if tooltip then
        tooltip.questieTooltipElapsed = 0
    end
end

local function _StoreTooltipTracking(tooltip)
    QuestieTooltips.lastGametooltip = _GetTooltipPrimaryText(tooltip) or ""
    if tooltip and tooltip.NumLines then
        local tooltipLineCount = tooltip:NumLines() or 0
        if tooltipLineCount > (QuestieTooltips.lastGametooltipCount or 0) then
            QuestieTooltips.lastGametooltipCount = tooltipLineCount
        end
    end
end

local function GetZoneNameToAreaIds()
    if zoneNameToAreaIds then
        return zoneNameToAreaIds
    end

    zoneNameToAreaIds = {}
    if not l10n or not l10n.zoneLookup then
        return zoneNameToAreaIds
    end

    for _, lookupTable in pairs(l10n.zoneLookup) do
        if type(lookupTable) == "table" then
            for areaId, zoneName in pairs(lookupTable) do
                if zoneName and zoneName ~= "" then
                    zoneNameToAreaIds[zoneName] = zoneNameToAreaIds[zoneName] or {}
                    tinsert(zoneNameToAreaIds[zoneName], areaId)
                end
            end
        end
    end

    return zoneNameToAreaIds
end

local function AddAreaIdAndParents(areaId, areaSet)
    while areaId and not areaSet[areaId] do
        areaSet[areaId] = true
        areaId = ZoneDB:GetParentZoneId(areaId)
    end
end

local function BuildRelatedPlayerAreaIds(playerZone)
    local areaSet = {}
    AddAreaIdAndParents(playerZone, areaSet)

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local uiMapId = C_Map.GetBestMapForUnit("player")
        local mapInfo = uiMapId and C_Map.GetMapInfo(uiMapId)
        local areaIds = mapInfo and mapInfo.name and GetZoneNameToAreaIds()[mapInfo.name]
        if areaIds then
            for _, areaId in ipairs(areaIds) do
                AddAreaIdAndParents(areaId, areaSet)
            end
        end
    end

    return areaSet
end

local function IsObjectSpawnInCurrentZone(spawns, playerZone)
    if not spawns or playerZone == 0 then
        return true
    end

    local relatedPlayerAreaIds = BuildRelatedPlayerAreaIds(playerZone)
    for zoneId in pairs(spawns) do
        local currentZoneId = zoneId
        while currentZoneId do
            if relatedPlayerAreaIds[currentZoneId] then
                return true
            end
            currentZoneId = ZoneDB:GetParentZoneId(currentZoneId)
        end
    end

    return false
end

---@param questId number
---@param level number
---@return string
---@return string
local function _GetQuestTooltipIconNames(questId, level)
    if QuestieEvent:IsEventQuest(questId) then
        return "eventquest", "eventquest_complete"
    elseif QuestieDB.IsPvPQuest(questId) then
        return "pvpquest", "pvpquest_complete"
    elseif QuestieDB.IsRepeatable(questId) then
        return "repeatable", "repeatable_complete"
    end

    local r, g, b = QuestieLib:GetDifficultyColorPercent(level)
    if r >= 0.95 then
        if g <= 0.20 then
            -- No dedicated red tooltip icon exists; closest match in current assets.
            return "pvpquest", "pvpquest_complete"
        elseif g <= 0.70 then
            return "pvpquest", "pvpquest_complete"
        else
            return "available", "complete"
        end
    elseif r <= 0.40 and g >= 0.70 and b <= 0.40 then
        -- No dedicated green tooltip icon exists; eventquest is the matching green style.
        return "eventquest", "eventquest_complete"
    end

    return "available_gray", "available_gray"
end

---@param questId number
---@param key string monster: m_, items: i_, objects: o_ + string name of the objective
---@param objective table
function QuestieTooltips:RegisterObjectiveTooltip(questId, key, objective)
    if not QuestieTooltips.lookupByKey[key] then
        QuestieTooltips.lookupByKey[key] = {};
    end
    if not QuestieTooltips.lookupKeysByQuestId[questId] then
        QuestieTooltips.lookupKeysByQuestId[questId] = {}
    end
    local tooltip = {
        questId = questId,
        objective = objective,
    };
    QuestieTooltips.lookupByKey[key][tostring(questId) .. " " .. objective.Index] = tooltip
    QuestieTooltips.lookupKeysByQuestId[questId][key] = true
end

---@param questId number
---@param name string The name of the object or NPC the tooltip should show on
---@param starterId number The ID of the object or NPC the tooltip should show on
---@param key string @Either m_<npcId> or o_<objectId>
function QuestieTooltips:RegisterQuestStartTooltip(questId, name, starterId, key, type)
    if not QuestieTooltips.lookupByKey[key] then
        QuestieTooltips.lookupByKey[key] = {};
    end
    if not QuestieTooltips.lookupKeysByQuestId[questId] then
        QuestieTooltips.lookupKeysByQuestId[questId] = {}
    end
    local tooltip = {
        questId = questId,
        name = name,
        starterId = starterId,
        type = type
    };
    QuestieTooltips.lookupByKey[key][tostring(questId) .. " " .. name .. " " .. starterId] = tooltip
    QuestieTooltips.lookupKeysByQuestId[questId][key] = true
end

---@param questId number
function QuestieTooltips:RemoveQuest(questId)
    if (not QuestieTooltips.lookupKeysByQuestId[questId]) then
        -- Tooltip has already been removed
        return
    end

    -- Remove tooltip related keys from quest table so that
    -- it can be readded/registered by other quest functions.
    local quest = QuestieDB.GetQuest(questId)

    if quest then
        for _, objective in pairs(quest.Objectives) do
            objective.AlreadySpawned = {}
            objective.hasRegisteredTooltips = false
            objective.registeredItemTooltips = false
        end

        for _, objective in pairs(quest.SpecialObjectives) do
            objective.AlreadySpawned = {}
            objective.hasRegisteredTooltips = false
            objective.registeredItemTooltips = false
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieTooltips:RemoveQuest]", questId)

    for key in pairs(QuestieTooltips.lookupKeysByQuestId[questId] or {}) do
        --Count to see if we should remove the main object
        local totalCount = 0
        local totalRemoved = 0
        for _, tooltipData in pairs(QuestieTooltips.lookupByKey[key] or {}) do
            --Remove specific quest
            if (tooltipData.questId == questId and tooltipData.objective) then
                QuestieTooltips.lookupByKey[key][tostring(tooltipData.questId) .. " " .. tooltipData.objective.Index] = nil
                totalRemoved = totalRemoved + 1
            elseif (tooltipData.questId == questId and tooltipData.name) then
                QuestieTooltips.lookupByKey[key][tostring(tooltipData.questId) .. " " .. tooltipData.name .. " " .. tooltipData.starterId] = nil
                totalRemoved = totalRemoved + 1
            end
            totalCount = totalCount + 1
        end
        if (totalCount == totalRemoved) then
            QuestieTooltips.lookupByKey[key] = nil
        end
    end

    QuestieTooltips.lookupKeysByQuestId[questId] = nil
end

---@param questId number
function QuestieTooltips:RemoveAvailableQuest(questId)
    if (not QuestieTooltips.lookupKeysByQuestId[questId]) then
        return
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieTooltips:RemoveAvailableQuest]", questId)

    local removedAnyKey
    for key in pairs(QuestieTooltips.lookupKeysByQuestId[questId] or {}) do
        local removedForKey = false
        local remainingForKey = false

        for tooltipKey, tooltipData in pairs(QuestieTooltips.lookupByKey[key] or {}) do
            if tooltipData.questId == questId and tooltipData.name and tooltipData.type ~= "Finisher" then
                QuestieTooltips.lookupByKey[key][tooltipKey] = nil
                removedForKey = true
            elseif QuestieTooltips.lookupByKey[key][tooltipKey] then
                remainingForKey = true
            end
        end

        if removedForKey then
            removedAnyKey = true
            if not remainingForKey then
                QuestieTooltips.lookupByKey[key] = nil
            end

            if QuestieTooltips.lookupByKey[key] == nil then
                QuestieTooltips.lookupKeysByQuestId[questId][key] = nil
            else
                local hasQuestEntriesForKey = false
                for _, tooltipData in pairs(QuestieTooltips.lookupByKey[key]) do
                    if tooltipData.questId == questId then
                        hasQuestEntriesForKey = true
                        break
                    end
                end
                if not hasQuestEntriesForKey then
                    QuestieTooltips.lookupKeysByQuestId[questId][key] = nil
                end
            end
        end
    end

    if removedAnyKey and not next(QuestieTooltips.lookupKeysByQuestId[questId]) then
        QuestieTooltips.lookupKeysByQuestId[questId] = nil
    end
end

-- This function contains the rules for formatting text for drop rate tooltips.
---@param rate number
---@return string
local function FormatDropText(rate)
    if rate >= 10 then
        return string.format("%.0f", rate)
    elseif rate >= 2 then
        return string.format("%.1f", rate)
    elseif rate >= 0.01 then
        return string.format("%.2f", rate)
    else
        return string.format("%.3f", rate)
    end
end

-- This code is related to QuestieComms, here we fetch all the tooltip data that exist in QuestieCommsData
-- It uses a similar system like here with i_ID etc as keys.
local function _FetchTooltipsForGroupMembers(key, tooltipData)
    local anotherPlayer = false;
    if QuestieComms.data:KeyExists(key) then
        ---@tooltipData @tooltipData[questId][playerName][objectiveIndex].text
        local tooltipDataExternal = QuestieComms.data:GetTooltip(key);
        for questId, playerList in pairs(tooltipDataExternal) do
            if (not tooltipData[questId]) then
                tooltipData[questId] = {
                    title = QuestieLib:GetColoredQuestName(questId, Questie.db.profile.enableTooltipsQuestLevel, true, true)
                }
            end
            for playerName, _ in pairs(playerList) do
                local playerInfo = QuestiePlayer:GetPartyMemberByName(playerName);
                if playerInfo or QuestieComms.remotePlayerEnabled[playerName] then
                    anotherPlayer = true
                    break
                end
            end
            if anotherPlayer then
                break
            end
        end
    end

    if QuestieComms.data:KeyExists(key) and anotherPlayer then
        ---@tooltipData @tooltipData[questId][playerName][objectiveIndex].text
        local tooltipDataExternal = QuestieComms.data:GetTooltip(key);
        for questId, playerList in pairs(tooltipDataExternal) do
            if (not tooltipData[questId]) then
                tooltipData[questId] = {
                    title = QuestieLib:GetColoredQuestName(questId, Questie.db.profile.enableTooltipsQuestLevel, true, true)
                }
            end
            for playerName, objectives in pairs(playerList) do
                local playerInfo = QuestiePlayer:GetPartyMemberByName(playerName);
                if playerInfo or QuestieComms.remotePlayerEnabled[playerName] then
                    anotherPlayer = true;
                    for objectiveIndex, objective in pairs(objectives) do
                        if (not objective) then
                            objective = {}
                        end

                        tooltipData[questId].objectivesText = _InitObjectiveTexts(tooltipData[questId].objectivesText, objectiveIndex, playerName)

                        local text;
                        local color = QuestieLib:GetRGBForObjective(objective)

                        if objective.required then
                            text = "   " .. color .. tostring(objective.fulfilled) .. "/" .. tostring(objective.required) .. " " .. objective.text;
                        else
                            text = "   " .. color .. objective.text;
                        end

                        tooltipData[questId].objectivesText[objectiveIndex][playerName] = { ["color"] = color, ["text"] = text };
                    end
                end
            end
        end
    end
    return anotherPlayer
end

---@param key string
function QuestieTooltips:GetTooltip(key)
    Questie:Debug(Questie.DEBUG_SPAM, "[QuestieTooltips:GetTooltip]", key)
    if (not key) then
        return nil
    end

    if QuestiePlayer.numberOfGroupMembers > MAX_GROUP_MEMBER_COUNT then
        return nil -- temporary disable tooltips in raids, we should make a proper fix
    end

    local isObjectTooltip = key:sub(1, 2) == "o_"
    if isObjectTooltip then
        local objectId = tonumber(key:sub(3))
        local spawns = QuestieDB.QueryObjectSingle(objectId, "spawns")
        local playerZone = QuestiePlayer:GetCurrentZoneId()
        local objectIsInCurrentZone = IsObjectSpawnInCurrentZone(spawns, playerZone)

        if (not objectIsInCurrentZone) then
            return nil
        end
    end

    --Do not remove! This is the datastrucutre for tooltipData!
    --[[tooltipdata[questId] = {
        title = coloredTitle,
        objectivesText = {
            [objectiveIndex] = {
                [playerName] = {
                    [color] = color,
                    [text] = text
                }
            }
        }
    }]]
    --
    local tooltipData = {}
    local tooltipLines = {}

    if QuestieTooltips.lookupByKey[key] then
        local playerName = UnitName("player")

        local finishedAndUnacceptedQuests = {}
        if Questie.db.profile.showQuestsInNpcTooltip then
            -- We built a table of all quests in the tooltip that can be accepted or turned in, to not show the objectives for those
            -- and also don't add the quest title twice.
            for _, tooltip in pairs(QuestieTooltips.lookupByKey[key]) do
                if tooltip.name then
                    finishedAndUnacceptedQuests[tooltip.questId] = true
                end
            end
        end

        for k, tooltip in pairs(QuestieTooltips.lookupByKey[key]) do
            local questId = tooltip.questId
            if tooltip.name then
                if Questie.db.profile.showQuestsInNpcTooltip then
                    local questString = QuestieLib:GetColoredQuestName(questId, Questie.db.profile.enableTooltipsQuestLevel, true, true)
                    if tooltip.type then
                        local level, _ = QuestieLib.GetTbcLevel(questId)
                        local availableIcon, completeIcon = _GetQuestTooltipIconNames(questId, level)
                        local iconSize = 18
                        if tooltip.type == "NPC" then
                            questString = "|T" .. QuestieLib.AddonPath .. "Icons\\" .. availableIcon .. ".blp:" .. iconSize .. "|t" .. questString
                        elseif tooltip.type == "Finisher" then
                            questString = "|T" .. QuestieLib.AddonPath .. "Icons\\" .. completeIcon .. ".blp:" .. iconSize .. "|t" .. questString
                        elseif tooltip.type == "itemFromMonster" then
                            questString = "|T" .. QuestieLib.AddonPath .. "Icons\\available_mobdrop.blp:" .. iconSize .. "|t" .. questString
                        elseif tooltip.type == "itemFromObject" or tooltip.type == "Object" then
                            questString = "|T" .. QuestieLib.AddonPath .. "Icons\\available_object.blp:" .. iconSize .. "|t" .. questString
                        end
                    end
                    tinsert(tooltipLines, questString)
                end
            elseif (not finishedAndUnacceptedQuests[questId]) then
                local objective = tooltip.objective
                if not (objective.IsSourceItem or objective.IsRequiredSourceItem) then
                    -- Tooltip was registered for a real "objective" and not for a sourceItem or requiredSourceItem
                    objective:Update()
                end
                local objectiveIndex = objective.Index;
                if (not tooltipData[questId]) then
                    tooltipData[questId] = {
                        title = QuestieLib:GetColoredQuestName(questId, Questie.db.profile.enableTooltipsQuestLevel, true, true)
                    }
                end
                if not QuestiePlayer.currentQuestlog[questId] then
                    -- TODO: Is this still required?
                    QuestieTooltips.lookupByKey[key][k] = nil
                else
                    tooltipData[questId].objectivesText = _InitObjectiveTexts(tooltipData[questId].objectivesText, objectiveIndex, playerName)
                    local text;
                    local color = QuestieLib:GetRGBForObjective(objective)

                    local npcId = tonumber(key:sub(3))
                    local objectiveId = objective.Id
                    if objective.Type == "spell" and objective.spawnList[npcId].ItemId then
                        text = "   " .. color .. tostring(QuestieDB.QueryItemSingle(objective.spawnList[npcId].ItemId, "name"));
                        tooltipData[questId].objectivesText[objectiveIndex][playerName] = { ["color"] = color, ["text"] = text };
                    else
                        local dropIcon, dropRateText = "", ""
                        local dropIconPath = QuestieLib.AddonPath .. "Icons\\"
                        local dropIconSize = 11
                        local dropRateData = QuestieDB.GetItemDroprate(objectiveId, npcId)
                        if dropRateData and dropRateData[1] and Questie.db.profile.enableTooltipDroprates then
                            if Questie.db.profile.debugEnabled and dropRateData and dropRateData[2] then
                                if dropRateData[2] == "cmangos" then
                                    dropIcon = "|T" .. dropIconPath .. "cmangos.blp:" .. dropIconSize .. "|t "
                                elseif dropRateData[2] == "azerothcore" then
                                    dropIcon = "|T" .. dropIconPath .. "azerothcore.blp:" .. dropIconSize .. "|t "
                                elseif dropRateData[2] == "mangos3" then
                                    dropIcon = "|T" .. dropIconPath .. "mangos3.blp:" .. dropIconSize .. "|t "
                                elseif dropRateData[2] == "wowhead" then
                                    dropIcon = "|T" .. dropIconPath .. "wowhead.blp:" .. dropIconSize .. "|t "
                                elseif dropRateData[2] == "questie" then
                                    dropIcon = "|T" .. dropIconPath .. "questie_flat.blp:" .. dropIconSize .. "|t "
                                end
                            end
                            dropRateText = "  |cFF999999" .. dropIcon .. "[" .. FormatDropText(dropRateData[1]) .. "%]|r";
                        end
                        if objective.Needed and ((not finishedAndUnacceptedQuests[questId]) or objective.Collected ~= objective.Needed) then
                            text = "   " .. color .. tostring(objective.Collected) .. "/" .. tostring(objective.Needed) .. " " .. tostring(objective.Description) .. dropRateText;
                            tooltipData[questId].objectivesText[objectiveIndex][playerName] = { ["color"] = color, ["text"] = text };
                        else
                            text = "   " .. color .. tostring(objective.Description) .. dropRateText;
                            tooltipData[questId].objectivesText[objectiveIndex][playerName] = { ["color"] = color, ["text"] = text };
                        end
                    end
                end
            end
        end
    end

    local anotherPlayer = false
    if IsInGroup() then
        anotherPlayer = _FetchTooltipsForGroupMembers(key, tooltipData)
    end

    local playerName = UnitName("player")

    for questId, questData in pairs(tooltipData) do
        local hasObjective = false
        local tempObjectives = {}
        for _, playerList in pairs(questData.objectivesText or {}) do
            for objectivePlayerName, objectiveInfo in pairs(playerList) do
                local playerInfo = QuestiePlayer:GetPartyMemberByName(objectivePlayerName)
                local playerColor
                local playerType = ""
                if playerInfo then
                    playerColor = "|c" .. playerInfo.colorHex
                elseif QuestieComms.remotePlayerEnabled[objectivePlayerName] and QuestieComms.remoteQuestLogs[questId] and QuestieComms.remoteQuestLogs[questId][objectivePlayerName] and (not Questie.db.profile.onlyPartyShared or UnitInParty(objectivePlayerName)) then
                    playerColor = QuestieComms.remotePlayerClasses[playerName]
                    if playerColor then
                        playerColor = Questie:GetClassColor(playerColor)
                        playerType = " (" .. l10n("Nearby") .. ")"
                    end
                end
                if objectivePlayerName == playerName and anotherPlayer then -- Add current player name to own objective
                    local _, classFilename = UnitClass("player");
                    local _, _, _, argbHex = GetClassColor(classFilename)
                    local dropIndex = string.find(objectiveInfo.text, "  |cFF999999")
                    local playerString = " (|c" .. argbHex .. objectivePlayerName .. "|r" .. objectiveInfo.color .. ")|r"
                    if dropIndex then
                        objectiveInfo.text = objectiveInfo.text:sub(1,dropIndex-1)..playerString.." "..objectiveInfo.text:sub(dropIndex+1) -- Ensures drop data is shown after player name
                    else
                        objectiveInfo.text = objectiveInfo.text .. playerString
                    end
                elseif playerColor and objectivePlayerName ~= playerName then -- Add other player name to their objective
                    objectiveInfo.text = objectiveInfo.text .. " (" .. playerColor .. objectivePlayerName .. "|r" .. objectiveInfo.color .. ")|r" .. playerType
                end
                -- We want the player to be on top.
                if objectivePlayerName == playerName then
                    tinsert(tempObjectives, 1, objectiveInfo.text);
                    hasObjective = true
                elseif playerColor then
                    tinsert(tempObjectives, objectiveInfo.text);
                    hasObjective = true
                end
            end
        end
        if hasObjective then
            tinsert(tooltipLines, questData.title);
            for _, text in pairs(tempObjectives) do
                tinsert(tooltipLines, text);
            end
        end
    end
    return tooltipLines
end

_InitObjectiveTexts = function(objectivesText, objectiveIndex, playerName)
    if (not objectivesText) then
        objectivesText = {}
    end
    if (not objectivesText[objectiveIndex]) then
        objectivesText[objectiveIndex] = {}
    end
    if (not objectivesText[objectiveIndex][playerName]) then
        objectivesText[objectiveIndex][playerName] = {}
    end
    return objectivesText
end

function QuestieTooltips:Initialize()
    -- For the clicked item frame.
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
        _QuestieTooltips.AddItemDataToTooltip(self)
        _StoreTooltipTracking(self)
    end)
    ItemRefTooltip:HookScript("OnHide", function(self)
        if (not self.IsForbidden) or (not self:IsForbidden()) then -- do we need this here also
            _ResetTooltipTracking(self)
        end
    end)

    -- For the hover frame.
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        if QuestiePlayer.numberOfGroupMembers > MAX_GROUP_MEMBER_COUNT then
            -- When in a raid, we want as little code running as possible
            return
        end

        _QuestieTooltips.AddUnitDataToTooltip(self)
        _StoreTooltipTracking(self)
    end)
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        _QuestieTooltips.AddItemDataToTooltip(self)
        _StoreTooltipTracking(self)
    end)
    GameTooltip:HookScript("OnShow", function(self)
        if QuestiePlayer.numberOfGroupMembers > MAX_GROUP_MEMBER_COUNT then
            -- When in a raid, we want as little code running as possible
            return
        end

        if (not self.IsForbidden) or (not self:IsForbidden()) then -- do we need this here also
            QuestieTooltips.lastGametooltipItem = nil
            QuestieTooltips.lastGametooltipUnit = nil
            QuestieTooltips.lastGametooltipCount = 0
            QuestieTooltips.lastGametooltipType = ""
            QuestieTooltips.lastFrameName = "";
            self.questieTooltipElapsed = 0
        end
    end)
    GameTooltip:HookScript("OnHide", function(self)
        if QuestiePlayer.numberOfGroupMembers > MAX_GROUP_MEMBER_COUNT then
            -- When in a raid, we want as little code running as possible
            return
        end

        if (not self.IsForbidden) or (not self:IsForbidden()) then -- do we need this here also
            _ResetTooltipTracking(self)
        end
    end)

    -- Fired whenever the cursor hovers something with a tooltip. And then on every frame
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        if QuestiePlayer.numberOfGroupMembers > MAX_GROUP_MEMBER_COUNT then
            -- When in a raid, we want as little code running as possible
            return
        end

        if (not self.IsForbidden) or (not self:IsForbidden()) then
            self.questieTooltipElapsed = (self.questieTooltipElapsed or 0) + (elapsed or 0)
            if self.questieTooltipElapsed < TOOLTIP_OBJECT_POLL_INTERVAL then
                return
            end
            self.questieTooltipElapsed = 0

            local tooltipText = _GetTooltipPrimaryText(self)
            if (not tooltipText) or self.ShownAsMapIcon then
                QuestieTooltips.lastGametooltip = tooltipText or ""
                return
            end

            local lineCount = self:NumLines() or 0
            if QuestieTooltips.lastGametooltipType ~= "" and
                tooltipText == QuestieTooltips.lastGametooltip and
                lineCount >= (QuestieTooltips.lastGametooltipCount or 0) then
                return
            end

            -- Because this is an OnUpdate we only probe unit/item/spell state after the visible tooltip changed.
            local uName, unit = self:GetUnit()
            if uName ~= nil or unit ~= nil then
                QuestieTooltips.lastGametooltip = tooltipText
                return
            end

            local iName, link = self:GetItem()
            if iName ~= nil or link ~= nil then
                QuestieTooltips.lastGametooltip = tooltipText
                return
            end

            local sName, spell = self:GetSpell()
            if sName ~= nil or spell ~= nil then
                QuestieTooltips.lastGametooltip = tooltipText
                QuestieTooltips.lastGametooltipType = "spell"
                QuestieTooltips.lastGametooltipCount = lineCount
                return
            end

            if tooltipText ~= QuestieTooltips.lastGametooltip or
                lineCount < (QuestieTooltips.lastGametooltipCount or 0) or
                QuestieTooltips.lastGametooltipType ~= "object" then
                _QuestieTooltips:AddObjectDataToTooltip(tooltipText)
                QuestieTooltips.lastGametooltipCount = _QuestieTooltips:CountTooltip()
            end
            QuestieTooltips.lastGametooltip = tooltipText
        end
    end)
end

return QuestieTooltips
