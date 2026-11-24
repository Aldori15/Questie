---@class TrackerUtils
local TrackerUtils = QuestieLoader:CreateModule("TrackerUtils")
local QuestieWaypoints = QuestieLoader:ImportModule("QuestieWaypoints")
-------------------------
--Import QuestieTracker modules.
-------------------------
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerWaypoints
local TrackerWaypoints = QuestieLoader:ImportModule("TrackerWaypoints")
---@type TrackerLinePool
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
---@type TrackerFadeTicker
local TrackerFadeTicker = QuestieLoader:ImportModule("TrackerFadeTicker")
-------------------------
--Import Questie modules.
-------------------------
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local C_Map = QuestieCompat.C_Map
local GetQuestLogTitle = QuestieCompat.GetQuestLogTitle
local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID
local WorldMapFrame = QuestieCompat.WorldMapFrame

local tinsert = table.insert

local function _RefreshWorldMapPins()
    if QuestieCompat.HBDPins and QuestieCompat.HBDPins.UpdateWorldMap then
        QuestieCompat.HBDPins.UpdateWorldMap(true)
    end
end

local objectiveFlashTicker
local objectiveFlashRestore
local zoneCache = {}
local shortcutButtons = {LeftButton = "left", RightButton = "right"}
local shortcutSettings = {
    "trackerbindOpenQuestLog", "trackerbindUntrack", "trackerbindShareQuest", "trackerbindSetTomTom",
}

local _QuestLogScrollBar = QuestLogScrollFrameScrollBar or QuestLogListScrollFrame.ScrollBar or QuestLogListScrollFrameScrollBar

---@param quest table The table provided by QuestieDB.GetQuest(questId)
function TrackerUtils:ShowQuestLog(quest)
    -- Priority order first check if addon exist otherwise default to original
    local questFrame = QuestLogExFrame or ClassicQuestLog or QuestLogFrame
    --HideUIPanel(questFrame) -- don't use as I don't see why to use and protected function taints in combat
    local questLogIndex = GetQuestLogIndexByID(quest.Id)
    if (not questLogIndex) then
        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerUtils:ShowQuestLog] Missing quest log index for tracked quest:", quest.Id)
        QuestieTracker:UntrackQuestId(quest.Id)
        return
    end
    if quest.NativeOnly and questLogIndex > GetNumQuestLogEntries() then
        ExpandQuestHeader(GetQuestSortIndex(questLogIndex))
        questLogIndex = GetQuestLogIndexByID(quest.Id)
        if not questLogIndex then return end
    end
    SelectQuestLogEntry(questLogIndex)

    -- Scroll to the quest in the quest log
    local scrollSteps = _QuestLogScrollBar:GetValueStep()
    _QuestLogScrollBar:SetValue(questLogIndex * scrollSteps - scrollSteps * 3)

    if not questFrame:IsShown() then
        if not InCombatLockdown() then
            ShowUIPanel(questFrame)

            --Addon specific behaviors
            if (QuestLogEx) then
                QuestLogEx:Maximize()
            end
        else
            Questie:Print(l10n("Can't open Quest Log while in combat. Open it manually."))
        end
    end

    QuestLog_UpdateQuestDetails()
    QuestLog_Update()
end

-- Preserve entry points used by map icons, menus, quest lifecycle, and AutoRoute.
TrackerUtils.ForgetTomTomTarget = TrackerWaypoints.ForgetTomTomTarget
TrackerUtils.GetTomTomTarget = TrackerWaypoints.GetTomTomTarget
TrackerUtils.ClearTomTomTarget = TrackerWaypoints.ClearTomTomTarget
TrackerUtils.ClearTomTomTargetForQuest = TrackerWaypoints.ClearTomTomTargetForQuest
TrackerUtils.SetTomTomTarget = TrackerWaypoints.SetTomTomTarget
TrackerUtils.SetTomTomTargetToDungeonEntrance = TrackerWaypoints.SetTomTomTargetToDungeonEntrance

---@param objective table The table provided by QuestieDB.GetQuest(questId).Objectives[objective]
function TrackerUtils:ShowObjectiveOnMap(objective)
    local spawn, zone = QuestieMap:GetNearestSpawn(objective)
    if spawn then
        WorldMapFrame:Show()
        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
        WorldMapFrame:SetMapID(uiMapId)
        TrackerUtils:FlashObjective(objective)
    end
end

---@param objectives QuestObjective[]
function TrackerUtils:ShowQuestObjectivesOnMap(objectives)
    local bestZone, bestDistance
    for _, objective in pairs(objectives) do
        local spawn, zone, _, _, _, distance = QuestieMap:GetNearestSpawn(objective)
        if spawn and (not bestDistance or distance < bestDistance) then
            bestZone, bestDistance = zone, distance
        end
    end
    if bestZone then
        WorldMapFrame:Show()
        WorldMapFrame:SetMapID(ZoneDB:GetUiMapIdByAreaId(bestZone))
        TrackerUtils:FlashObjectives(objectives)
    end
end

---@param quest table The table provided by QuestieDB.GetQuest(questId)
function TrackerUtils:ShowFinisherOnMap(quest)
    local spawn, zone = QuestieMap:GetNearestQuestSpawn(quest)
    if spawn then
        WorldMapFrame:Show()
        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
        WorldMapFrame:SetMapID(uiMapId)
        TrackerUtils:FlashFinisher(quest)
    end
end

---@param quest Quest
function TrackerUtils:ShowQuestOnMap(quest)
    self:ShowFinisherOnMap(quest)
end

local function _FlashMapFrames(frames)
    if objectiveFlashRestore then objectiveFlashRestore() end

    local targets, hidden, patrolData = {}, {}, {}
    for _, frame in pairs(frames) do
        if not frame.miniMapIcon and frame.data then
            targets[frame] = {data = frame.data, width = frame:GetWidth(), height = frame:GetHeight()}
            patrolData[frame.data] = true
        end
    end
    if not next(targets) then return end

    local function HideIcon(frameName)
        local icon = _G[frameName]
        if icon and not icon.miniMapIcon and not targets[icon] and icon:IsShown() then
            hidden[icon] = icon.data
            icon._hidden_by_flash = true
            icon:Hide()
        end
    end
    for _, framelist in pairs(QuestieMap.questIdFrames) do
        for _, frameName in pairs(framelist) do HideIcon(frameName) end
    end
    for _, entries in pairs(QuestieMap.manualFrames or {}) do
        for _, framelist in pairs(entries) do
            for _, frameName in pairs(framelist) do HideIcon(frameName) end
        end
    end

    local function RestoreSizes()
        for frame, target in pairs(targets) do
            if not target.restored then
                if frame.data == target.data then
                    frame:SetWidth(target.width)
                    frame:SetHeight(target.height)
                end
                target.restored = true
            end
        end
    end
    local ticker
    local function RestoreFlash()
        if objectiveFlashTicker ~= ticker then return end
        ticker:Cancel()
        RestoreSizes()
        for frame, data in pairs(hidden) do
            if frame.data == data and frame._hidden_by_flash then
                frame._hidden_by_flash = nil
                frame:Show()
            end
        end
        objectiveFlashTicker, objectiveFlashRestore = nil, nil
        if QuestieWaypoints.SetSolo then QuestieWaypoints.SetSolo(nil) end
        _RefreshWorldMapPins()
    end

    if QuestieWaypoints.SetSolo then QuestieWaypoints.SetSolo(patrolData) end
    local flashW, growing, flashDone, finishing = 1, true, 0, false
    ticker = C_Timer.NewTicker(0.065, function()
        if objectiveFlashTicker ~= ticker or finishing then return end
        for frame, target in pairs(targets) do
            if frame.data == target.data then
                frame:SetWidth(target.width + flashW)
                frame:SetHeight(target.height + flashW)
            end
        end
        if growing then
            flashW = flashW + (16 - flashW) / 2 + 0.06
            if flashW >= 9.5 then growing = false end
        else
            flashW = flashW - 2
            if flashW < 1 then
                growing = true
                flashDone = flashDone + 1
                if flashDone == 2 then
                    finishing = true
                    C_Timer.After(0.1, function()
                        if objectiveFlashTicker ~= ticker then return end
                        ticker:Cancel()
                        RestoreSizes()
                    end)
                    C_Timer.After(0.5, RestoreFlash)
                end
            end
        end
    end)
    objectiveFlashTicker, objectiveFlashRestore = ticker, RestoreFlash
end

---@param objective table The table provided by QuestieDB.GetQuest(questId).Objectives[objective]
function TrackerUtils:FlashObjective(objective)
    self:FlashObjectives({objective})
end

---@param objectives QuestObjective[]
function TrackerUtils:FlashObjectives(objectives)
    local frames = {}
    for _, objective in pairs(objectives) do
        for _, spawn in pairs(objective.AlreadySpawned or {}) do
            for _, frame in pairs(spawn.mapRefs or {}) do
                frames[frame] = frame
            end
        end
    end
    _FlashMapFrames(frames)
end

---@param quest table The table provided by QuestieDB.GetQuest(questId)
function TrackerUtils:FlashFinisher(quest)
    local frames = {}
    for _, frameName in pairs(QuestieMap.questIdFrames[quest.Id] or {}) do
        local frame = _G[frameName]
        if frame then frames[frame] = frame end
    end
    _FlashMapFrames(frames)
end

---@param button string
---@return string? shortcut
function TrackerUtils.GetClickShortcut(button)
    local suffix = shortcutButtons[button]
    if not suffix then return nil end

    local shift, ctrl, alt = IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown()
    if (shift and (ctrl or alt)) or (ctrl and alt) then return nil end
    local modifier = (shift and "shift") or (ctrl and "ctrl") or (alt and "alt") or ""
    return modifier .. suffix
end

function TrackerUtils.SetShortcut(setting, shortcut)
    local profile = Questie.db.profile
    if shortcut ~= "disabled" then
        for _, otherSetting in ipairs(shortcutSettings) do
            if otherSetting ~= setting and profile[otherSetting] == shortcut then
                profile[otherSetting] = "disabled"
            end
        end
    end
    profile[setting] = shortcut
end

function TrackerUtils.IsTomTomAvailable()
    return TomTom ~= nil and type(TomTom.AddWaypoint) == "function"
end

local function WithQuestSelected(questId, callback)
    local index = GetQuestLogIndexByID(questId)
    if not index or index <= 0 then return end
    local previous = GetQuestLogSelection()
    SelectQuestLogEntry(index)
    local result = callback()
    SelectQuestLogEntry(previous or 0)
    return result
end

function TrackerUtils.CanShareQuest(questId)
    if not (QuestieCompat.IsInGroup() or QuestieCompat.IsInRaid()) then return false end
    return WithQuestSelected(questId, GetQuestLogPushable) and true or false
end

function TrackerUtils.ShareQuest(questId)
    if InCombatLockdown() then
        Questie:Print(l10n("Can't share a Quest while in combat."))
        return false
    end
    if not TrackerUtils.CanShareQuest(questId) then return false end
    WithQuestSelected(questId, QuestLogPushQuest)
    return true
end

---@param itemId number
---@return boolean
function TrackerUtils:IsQuestItemUsable(itemId)
    if itemId and (GetItemSpell(itemId) or IsEquippableItem(itemId)) then
        return true
    end

    return false
end

---@param quest Quest
---@return ItemId[]
function TrackerUtils:GetUsableQuestItemIds(quest)
    local usableQuestItems = {}
    local seenQuestItems = {}

    local function AddUsableQuestItem(itemId)
        if itemId and (not seenQuestItems[itemId]) and QuestieDB.QueryItemSingle(itemId, "class") == 12 and GetItemCount(itemId) > 0 and self:IsQuestItemUsable(itemId) then
            seenQuestItems[itemId] = true
            tinsert(usableQuestItems, itemId)
        end
    end

    if quest.NativeOnly then
        local itemId = quest.sourceItemId
        if itemId and GetItemCount(itemId) > 0 and self:IsQuestItemUsable(itemId) then
            tinsert(usableQuestItems, itemId)
        end
        return usableQuestItems
    end

    local sourceItemId = quest.sourceItemId
    if sourceItemId == nil then
        sourceItemId = QuestieDB.QueryQuestSingle(quest.Id, "sourceItemId")
    end
    AddUsableQuestItem(sourceItemId)

    for _, itemId in ipairs(quest.requiredSourceItems or {}) do
        AddUsableQuestItem(itemId)
    end

    for _, objective in ipairs(quest.ObjectiveData or {}) do
        if objective.Type == "item" then
            AddUsableQuestItem(objective.Id)
        end
    end

    return usableQuestItems
end

---Use the same item selection for layout and unchanged-data checks.
---@param quest Quest
---@param complete number
---@return ItemId[] items
---@return boolean usableWhenComplete
function TrackerUtils:GetQuestItemButtonState(quest, complete)
    local items = self:GetUsableQuestItemIds(quest)
    local isComplete = quest.isComplete == true or #quest.Objectives == 0
    if complete ~= 1 or not isComplete then return items, false end

    local sourceItemId = quest.sourceItemId
    if sourceItemId == nil and not quest.NativeOnly then
        sourceItemId = QuestieDB.QueryQuestSingle(quest.Id, "sourceItemId")
    end
    local sourceItem = sourceItemId and sourceItemId > 0
        and (quest.NativeOnly or QuestieDB.QueryItemSingle(sourceItemId, "class") == 12)
        and GetItemCount(sourceItemId) > 0 and self:IsQuestItemUsable(sourceItemId)
    if sourceItem then return items, true end

    for _, itemId in pairs(quest.requiredSourceItems or {}) do
        if itemId and QuestieDB.QueryItemSingle(itemId, "class") == 12
            and GetItemCount(itemId) > 0 and self:IsQuestItemUsable(itemId) then
            return items, true
        end
    end
    return items, false
end

---@param quest Quest
---@return string|nil completionText Quest Completion text string or nil
function TrackerUtils:GetCompletionText(quest)
    local completionText
    if GetQuestLogCompletionText then
        local questIndex = GetQuestLogIndexByID(quest.Id)
        if questIndex then
            completionText = GetQuestLogCompletionText(questIndex)
        end
    end

    if completionText then
        return completionText
    elseif quest.Description and next(quest.Description) then
        local descr = quest.Description[1]:gsub("%.", "")
        return descr
    end
end

---@param zoneId number Zone ID number
---@return string @Zone Name (Localized) or "Unknown Zone"
local function GetLocalizedZoneNameFromLookup(zoneId)
    if zoneCache[zoneId] then
        return zoneCache[zoneId]
    end

    if zoneId <= 0 or type(zoneId) ~= "number" then
        return "Unknown Zone"
    end

    for _, zone in pairs(l10n.zoneLookup) do
        if zone[zoneId] then
            zoneCache[zoneId] = l10n(zone[zoneId])
            return zoneCache[zoneId]
        end
    end

    return nil
end

---@param zoneId number Zone ID number
---@return string @Zone Name (Localized) or "Unknown Zone"
local function GetZoneNameByIDFallback(zoneId)
    local localizedZoneName = GetLocalizedZoneNameFromLookup(zoneId)
    if localizedZoneName then
        return localizedZoneName
    end

    Questie.Debug(Questie.DEBUG_CRITICAL, "[GetZoneNameByIDFallback]: Unable to find a zone name for zoneId", zoneId)

    return "Unknown Zone"
end

---@param zoneId number Zone ID number
---@return string @Zone Name (Localized)
function TrackerUtils:GetZoneNameByID(zoneId)
    if zoneCache[zoneId] then
        return zoneCache[zoneId]
    end

    local localizedZoneName = GetLocalizedZoneNameFromLookup(zoneId)
    if localizedZoneName then
        zoneCache[zoneId] = localizedZoneName
    elseif C_Map.GetAreaInfo(zoneId) then
        zoneCache[zoneId] = C_Map.GetAreaInfo(zoneId)
    elseif ZoneDB:GetLocalizedDungeonName(zoneId) then
        zoneCache[zoneId] = l10n(ZoneDB:GetLocalizedDungeonName(zoneId))
    else
        zoneCache[zoneId] = GetZoneNameByIDFallback(zoneId)
    end

    return zoneCache[zoneId]
end

---@param catId number Catagory ID number
---@return string CatagoryName Catagory Name (Localized) or "Unknown Category"
function TrackerUtils:GetCategoryNameByID(catId)
    if zoneCache[catId] then
        return zoneCache[catId]
    end

    if type(catId) == "number" and catId < 0 and type(l10n.questCategoryLookup[catId]) == "string" then
        zoneCache[catId] = l10n(l10n.questCategoryLookup[catId])
        return zoneCache[catId]
    end

    return "Unknown Category"
end

function TrackerUtils:UnFocus()
    -- reset HideIcons to match savedvariable state
    if (not Questie.db.char.TrackerFocus) then
        return
    end
    for questId in pairs(QuestiePlayer.currentQuestlog) do
        local quest = QuestieDB.GetQuest(questId)

        if quest then
            quest.FadeIcons = nil
            if next(quest.Objectives) then
                if Questie.db.char.TrackerHiddenQuests[quest.Id] then
                    quest.HideIcons = true
                    quest.FadeIcons = nil
                else
                    quest.HideIcons = nil
                    quest.FadeIcons = nil
                end

                for _, objective in pairs(quest.Objectives) do
                    if Questie.db.char.TrackerHiddenObjectives[tostring(questId) .. " " .. tostring(objective.Index)] then
                        objective.HideIcons = true
                        objective.FadeIcons = nil
                    else
                        objective.HideIcons = nil
                        objective.FadeIcons = nil
                    end
                end

                for _, objective in pairs(quest.SpecialObjectives) do
                    if Questie.db.char.TrackerHiddenObjectives[tostring(questId) .. " " .. tostring(objective.Index)] then
                        objective.HideIcons = true
                        objective.FadeIcons = nil
                    else
                        objective.HideIcons = nil
                        objective.FadeIcons = nil
                    end
                end
            end
        end
    end

    Questie.db.char.TrackerFocus = nil
end

---@param questId number Quest ID number
---@param objectiveIndex number Objective Index number
function TrackerUtils:FocusObjective(questId, objectiveIndex)
    if Questie.db.char.TrackerFocus and (type(Questie.db.char.TrackerFocus) ~= "string" or Questie.db.char.TrackerFocus ~= tostring(questId) .. " " .. tostring(objectiveIndex)) then
        TrackerUtils:UnFocus()
    end

    Questie.db.char.TrackerFocus = tostring(questId) .. " " .. tostring(objectiveIndex)
    for questLogQuestId in pairs(QuestiePlayer.currentQuestlog) do
        local quest = QuestieDB.GetQuest(questLogQuestId)
        if quest and next(quest.Objectives) then
            if questLogQuestId == questId then
                quest.HideIcons = nil
                quest.FadeIcons = nil

                for _, objective in pairs(quest.Objectives) do
                    if objective.Index == objectiveIndex then
                        objective.HideIcons = nil
                        objective.FadeIcons = nil
                    else
                        objective.FadeIcons = true
                    end
                end

                for _, objective in pairs(quest.SpecialObjectives) do
                    if objective.Index == objectiveIndex then
                        objective.HideIcons = nil
                        objective.FadeIcons = nil
                    else
                        objective.FadeIcons = true
                    end
                end
            else
                quest.FadeIcons = true
            end
        end
    end
end

---@param questId number Quest ID number
function TrackerUtils:FocusQuest(questId)
    if Questie.db.char.TrackerFocus and (type(Questie.db.char.TrackerFocus) ~= "number" or Questie.db.char.TrackerFocus ~= questId) then
        TrackerUtils:UnFocus()
    end

    Questie.db.char.TrackerFocus = questId
    for questLogQuestId in pairs(QuestiePlayer.currentQuestlog) do
        local quest = QuestieDB.GetQuest(questLogQuestId)
        if quest then
            if questLogQuestId == questId then
                quest.HideIcons = nil
                quest.FadeIcons = nil
            else
                quest.FadeIcons = true
            end
        end
    end
end

function TrackerUtils:IsVoiceOverLoaded()
    if not (IsAddOnLoaded("VoiceOverRedux") or IsAddOnLoaded("AI_VoiceOver")
        or IsAddOnLoaded("AI_VoiceOver_Continued")) then return false end

    local voice = VoiceOver
    local overlay, data, queue = voice and voice.QuestOverlayUI, voice and voice.DataModules, voice and voice.SoundQueue
    local enums, utils = voice and voice.Enums, voice and voice.Utils
    return overlay and type(overlay.questPlayButtons) == "table" and type(overlay.displayedButtons) == "table"
        and type(overlay.CreatePlayButton) == "function" and type(overlay.UpdatePlayButtonTexture) == "function"
        and data and type(data.PrepareSound) == "function" and type(data.GetQuestLogQuestGiverTypeAndID) == "function"
        and type(data.GetObjectName) == "function" and queue and type(queue.Contains) == "function"
        and type(queue.AddSoundToQueue) == "function" and type(queue.RemoveSoundFromQueue) == "function"
        and enums and enums.SoundEvent and enums.SoundEvent.QuestAccept
        and enums.GUID and type(enums.GUID.CanHaveID) == "function"
        and utils and type(utils.MakeGUID) == "function" and true or false
end

local itemColumnShown, passiveStatusShown = false, false

function TrackerUtils:SetTrackerColumns(itemsShown, statusShown)
    itemColumnShown, passiveStatusShown = itemsShown == true, statusShown == true
end

function TrackerUtils:GetTrackerMargins()
    local fontSize = Questie.db.profile.trackerFontSizeQuest
    local buttonSize, itemButtonSize = fontSize + 3, fontSize + 12
    local statusSlot = Questie.db.profile.trackerShowQuestFocusButtons and (buttonSize + 2)
        or (passiveStatusShown and (fontSize + 2) or 0)
    local playButtonSize = buttonSize + 2
    local playSlot = Questie.db.profile.trackerShowPlayButtons and self:IsVoiceOverLoaded() and (playButtonSize + 2) or 0
    local itemColumn = itemColumnShown and itemButtonSize or buttonSize
    local itemButtonLeft = statusSlot + playSlot
    local quest = itemButtonLeft + itemColumn + 2
    return {
        left = 14, right = 30, quest = quest, objective = quest + fontSize,
        buttonSize = buttonSize, itemButtonSize = itemButtonSize, itemButtonLeft = itemButtonLeft,
        expandQuestRight = quest - 2 - math.floor((itemColumn - buttonSize) / 2),
        playButtonSize = playButtonSize, playButtonRight = itemButtonLeft - 2, statusLeft = 0,
    }
end

function TrackerUtils:UpdateVoiceOverPlayButtons()
    if self:IsVoiceOverLoaded() then
        if Questie_BaseFrame.isSizing == true or Questie_BaseFrame.isMoving == true then
            Questie.Debug(Questie.DEBUG_SPAM, "[TrackerUtils:UpdateVoiceOverPlayButtons]")
        else
            Questie.Debug(Questie.DEBUG_INFO, "[TrackerUtils:UpdateVoiceOverPlayButtons]")
        end

        for i = 1, 75 do
            local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)

            if not (title and questId) then
                break
            end

            if not isHeader then
                if not VoiceOver.QuestOverlayUI.questPlayButtons[questId] then
                    VoiceOver.QuestOverlayUI:CreatePlayButton(questId)
                    table.insert(VoiceOver.QuestOverlayUI.displayedButtons, VoiceOver.QuestOverlayUI.questPlayButtons[questId])
                end
            end
        end
        TrackerLinePool.UpdateQuestTitleLines(function(line)
            line.playButton:SetPlayButton(line.Quest.Id)
        end)
    end
end

---@return boolean @true if the Tracker tracks a quest, false if not
function TrackerUtils.HasQuest()
    local hasQuest

    if (GetNumQuestWatches(true) == 0) then
        if (GetNumTrackedAchievements() == 0) then
            hasQuest = false
        else
            hasQuest = true
        end
    else
        if not Questie.db.profile.trackerShowCompleteQuests then
            local isTrackingIncompleteQuest = false
            for _, quest in pairs(QuestiePlayer.currentQuestlog) do
                if not quest then break end
                if IsQuestWatched(GetQuestLogIndexByID(quest.Id)) and quest:IsComplete() == 0 then
                    isTrackingIncompleteQuest = true
                    break
                end
            end

            -- This hides the Tracker when all tracked Quests are complete
            if (not isTrackingIncompleteQuest) then
                hasQuest = false
            else
                hasQuest = true
            end
        else
            hasQuest = true
        end
    end

    Questie.Debug(Questie.DEBUG_SPAM, "[TrackerUtils.HasQuest] - ", hasQuest)
    return hasQuest
end
