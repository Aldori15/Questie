---@class TrackerLinePool
local TrackerLinePool = QuestieLoader:CreateModule("TrackerLinePool")
local QuestFocusButton = QuestieLoader:ImportModule("QuestFocusButton")
-------------------------
--Import QuestieTracker modules.
-------------------------
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerBaseFrame
local TrackerBaseFrame = QuestieLoader:ImportModule("TrackerBaseFrame")
---@type TrackerQuestFrame
local TrackerQuestFrame = QuestieLoader:ImportModule("TrackerQuestFrame")
---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type TrackerQuestTimers
local TrackerQuestTimers = QuestieLoader:ImportModule("TrackerQuestTimers")
---@type TrackerMenu
local TrackerMenu = QuestieLoader:ImportModule("TrackerMenu")
---@type TrackerFadeTicker
local TrackerFadeTicker = QuestieLoader:ImportModule("TrackerFadeTicker")
---@type TrackerQuestItemButtons
local TrackerQuestItemButtons = QuestieLoader:ImportModule("TrackerQuestItemButtons")
-------------------------
--Import Questie modules.
-------------------------
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local TrackerData = QuestieLoader:ImportModule("TrackerData")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID

local LibDropDown = QuestieCompat.LibUIDropDownMenu or LibStub:GetLibrary("LibUIDropDownMenuQuestie-4.0")
local LSM30 = LibStub("LibSharedMedia-3.0")

local coYield = coroutine.yield
local TICKS_PER_YIELD = 50

local linePoolSize = 250
local lineIndex = 0
local linePool = {}
local lineMarginLeft = 10

local function GetCachedUnboundedStringWidth(label)
    local text = label:GetText()
    local font, size, flags = label:GetFont()
    if label.measuredWidth == nil or label.measuredText ~= text or label.measuredFont ~= font
        or label.measuredFontSize ~= size or label.measuredFontFlags ~= flags then
        label.measuredWidth = QuestieCompat.GetUnboundedStringWidth(label)
        label.measuredText, label.measuredFont, label.measuredFontSize, label.measuredFontFlags = text, font, size, flags
    end
    return label.measuredWidth
end

local function _UpdatePlayButton(playButton)
    local questId = playButton.mode
    local button = VoiceOver.QuestOverlayUI.questPlayButtons[questId]
    local isPlaying = button and button.soundData and VoiceOver.SoundQueue:Contains(button.soundData)
    local hasSound = isPlaying or VoiceOver.DataModules:PrepareSound({
        event = VoiceOver.Enums.SoundEvent.QuestAccept, questID = questId,
    })
    playButton:SetNormalTexture(QuestieLib.AddonPath .. "Icons\\QuestLog" .. (isPlaying and "Stop" or "Play") .. "Button")
    playButton:SetAlpha(hasSound and 1 or 0.33)
end

local function ToggleAllQuestsInZone(expandZone)
    local zoneId = expandZone and expandZone.zoneId
    if not zoneId or Questie.db.char.collapsedZones[zoneId] then
        return
    end

    local zoneLineIndex
    for i = 1, lineIndex do
        if linePool[i].expandZone == expandZone then
            zoneLineIndex = i
            break
        end
    end

    if not zoneLineIndex then
        return
    end

    local questIds = {}
    for i = zoneLineIndex + 1, lineIndex do
        local line = linePool[i]
        if line.expandZone and line.expandZone:IsShown() then
            break
        end

        local expandQuest = line.expandQuest
        if expandQuest and expandQuest.zoneId == zoneId and expandQuest.questId then
            questIds[expandQuest.questId] = true
        end
    end

    if not next(questIds) then
        return
    end

    if Questie.db.char.minAllQuestsInZone[zoneId] and not Questie.db.char.minAllQuestsInZone[zoneId].isTrue then
        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:minAllQuestsInZone] - Maximize")
        for questId, _ in pairs(questIds) do
            Questie.db.char.collapsedQuests[questId] = nil
        end

        Questie.db.char.minAllQuestsInZone[zoneId] = nil
    else
        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:minAllQuestsInZone] - Minimize")
        Questie.db.char.minAllQuestsInZone[zoneId] = questIds
        for questId, _ in pairs(questIds) do
            Questie.db.char.collapsedQuests[questId] = true
        end
    end

    QuestieCombatQueue:Queue(function()
        QuestieTracker:Update()
    end)
end

---@param questFrame Frame
function TrackerLinePool.Initialize(questFrame)
    local trackerQuestFrame = questFrame
    local trackerFontSizeQuest = Questie.db.profile.trackerFontSizeQuest

    -- create linePool for quests/achievements
    local nextFrame
    local yieldCount = 0
    for i = 1, linePoolSize do
        local timeElapsed = 0
        local line = CreateFrame("Button", "linePool" .. i, trackerQuestFrame.ScrollChildFrame)
        line:SetWidth(1)
        line:SetHeight(1)
        line.label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        line.label.GetUnboundedStringWidth = GetCachedUnboundedStringWidth
        line.label.GetWrappedWidth = line.label.GetWidth
        line.label.GetNumLines = QuestieCompat.GetNumLines
        line.label:SetJustifyH("LEFT")
        line.label:SetJustifyV("TOP")
        line.label:SetPoint("TOPLEFT", line)
        line.label:Hide()

        -- autoadjust parent size for clicks
        line.label._SetText = line.label.SetText
        line.label.frame = line
        line.label.SetText = function(self, text)
            self:_SetText(text)
            self.frame:SetWidth(self:GetWidth())
            self.frame:SetHeight(self:GetHeight())
        end

        if nextFrame then
            -- Second lineIndex hearafter
            line:SetPoint("TOPLEFT", nextFrame, "BOTTOMLEFT", 0, 0)
        else
            -- First lineIndex
            line:SetPoint("TOPLEFT", trackerQuestFrame.ScrollChildFrame, "TOPLEFT", lineMarginLeft, 0)
        end

        line.SetMode = TrackerLinePool.SetMode

        function line:SetZone(ZoneId)
            if type(ZoneId) == "string" then
                self.expandZone.zoneId = ZoneId
            elseif type(ZoneId) == "number" then
                self.ZoneId = TrackerUtils:GetZoneNameByID(ZoneId)
                self.expandZone.zoneId = ZoneId
            end
        end

        function line:SetQuest(Quest)
            if type(Quest) == "number" then
                Quest = {
                    Id = Quest
                }
                self.Quest = Quest
                self.expandQuest.questId = Quest.Id
            else
                self.Quest = Quest
                self.expandQuest.questId = Quest.Id
            end

            -- Set Timed Quest Flag
            self.trackTimedQuest = Quest.trackTimedQuest or nil
            self.label.activeTimer = false
            self:RefreshTimedQuestUpdater()
        end

        function line:SetObjective(Objective)
            self.Objective = Objective
        end

        function line:RefreshTimedQuestUpdater()
            if self.trackTimedQuest and self.label.activeTimer then
                if self:GetScript("OnUpdate") ~= self.OnUpdate then
                    timeElapsed = 0
                    self:SetScript("OnUpdate", self.OnUpdate)
                end
            else
                timeElapsed = 0
                if self:GetScript("OnUpdate") == self.OnUpdate then
                    self:SetScript("OnUpdate", nil)
                end
            end
        end

        line.OnUpdate = function(self, elapsed)
            timeElapsed = timeElapsed + elapsed

            if timeElapsed > 1 and self.trackTimedQuest and self.label.activeTimer then
                local timeRemainingString, timeRemaining = TrackerQuestTimers:GetRemainingTimeByQuestId(self.Quest.Id)

                if timeRemaining ~= nil then
                    if timeRemaining > 1 then
                        TrackerQuestTimers:UpdateTimerFrame(self, self.Quest.Id, timeRemainingString)
                    else
                        TrackerQuestTimers:UpdateTimerFrame(self, self.Quest.Id, l10n("Time's up!"))
                    end

                    timeElapsed = 0
                else
                    self.label.activeTimer = false
                    self:RefreshTimedQuestUpdater()
                    timeElapsed = 0

                    QuestieCombatQueue:Queue(function()
                        QuestieTracker:Update(true)
                    end)
                    return
                end
            end
        end

        function line:SetVerticalPadding(amount)
            if self.mode == "zone" then
                self:SetHeight(Questie.db.profile.trackerFontSizeZone + amount)
            elseif self.mode == "quest" or self.mode == "achieve" then
                self:SetHeight(Questie.db.profile.trackerFontSizeQuest + amount)
            else
                self:SetHeight(Questie.db.profile.trackerFontSizeObjective + amount)
            end
        end

        line:EnableMouse(true)
        line:EnableMouseWheel(true)
        line:RegisterForDrag("LeftButton")
        line:RegisterForClicks("RightButtonUp", "LeftButtonUp")
        line:SetScript("OnMouseWheel", TrackerQuestFrame.OnMouseWheel)

        function line:SetOnClick(onClickmode)
            if onClickmode == "quest" then
                self:SetScript("OnClick", TrackerLinePool.OnClickQuest)
            elseif onClickmode == "achieve" then
                self:SetScript("OnClick", TrackerLinePool.OnClickAchieve)
            end
        end

        line:SetScript("OnDragStart", TrackerBaseFrame.OnDragStart)
        line:SetScript("OnDragStop", TrackerBaseFrame.OnDragStop)

        line:SetScript("OnEnter", function(self)
            TrackerLinePool.OnHighlightEnter(self)
            TrackerFadeTicker.Unfade()
        end)

        line:SetScript("OnLeave", function(self)
            TrackerLinePool.OnHighlightLeave(self)
            TrackerFadeTicker.Fade()
        end)

        -- create objective complete criteria marks
        local criteriaMark = CreateFrame("Button", "linePool.criteriaMark" .. i, line)
        criteriaMark.texture = criteriaMark:CreateTexture(nil, "OVERLAY", nil, 0)
        criteriaMark.texture:SetWidth(Questie.db.profile.trackerFontSizeObjective)
        criteriaMark.texture:SetHeight(Questie.db.profile.trackerFontSizeObjective)
        criteriaMark.texture:SetAllPoints(criteriaMark)

        criteriaMark:SetWidth(1)
        criteriaMark:SetHeight(1)
        criteriaMark:SetPoint("RIGHT", line.label, "LEFT", -4, 0)
        criteriaMark:SetFrameLevel(100)

        criteriaMark.SetCriteria = function(self, criteria)
            if criteria ~= self.mode then
                self.mode = criteria

                if criteria == true then
                    self.texture:SetTexture(QuestieLib.AddonPath.."Icons\\Checkmark")
                    ---------------------------------------------------------------------
                    -- Just in case we decide to show the minus sign for incompletes
                    ---------------------------------------------------------------------
                    --self.texture:SetAlpha(1)
                    --else
                    --self.texture:SetAlpha(0.5)
                    ---------------------------------------------------------------------
                end

                self:SetWidth(Questie.db.profile.trackerFontSizeObjective)
                self:SetHeight(Questie.db.profile.trackerFontSizeObjective)
            end
        end

        criteriaMark:SetCriteria(false)
        criteriaMark:Hide()

        line.criteriaMark = criteriaMark

        -- create expanding zone headers for quests sorted by zones
        local expandZone = CreateFrame("Button", "linePool.expandZone" .. i, line)
        expandZone:SetWidth(1)
        expandZone:SetHeight(1)
        expandZone:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)

        expandZone.SetMode = function(self, mode)
            if mode ~= self.mode then
                self.mode = mode
            end
        end

        expandZone:SetMode(1) -- maximized
        expandZone:EnableMouse(true)
        expandZone:RegisterForDrag("LeftButton")
        expandZone:RegisterForClicks("LeftButtonUp", "LeftButtonDown", "RightButtonUp", "RightButtonDown")

        expandZone:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                if IsShiftKeyDown() then
                    ToggleAllQuestsInZone(self)
                else
                    if self.mode == 1 then
                        self:SetMode(0)
                        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:expandZone] - Minimize")
                    else
                        self:SetMode(1)
                        Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:expandZone] - Maximize")
                    end

                    if Questie.db.char.collapsedZones[self.zoneId] == true then
                        Questie.db.char.collapsedZones[self.zoneId] = nil
                    else
                        Questie.db.char.collapsedZones[self.zoneId] = true
                    end

                    QuestieCombatQueue:Queue(function()
                        QuestieTracker:Update()
                    end)
                end
            end
        end)

        expandZone:SetScript("OnEnter", function(self)
            TrackerLinePool.OnHighlightEnter(self)
            TrackerFadeTicker.Unfade()
        end)

        expandZone:SetScript("OnLeave", function(self)
            TrackerLinePool.OnHighlightLeave(self)
            TrackerFadeTicker.Fade()
        end)

        expandZone:Hide()

        line.expandZone = expandZone

        -- VoiceOver has its own column; playback never covers other tracker controls.
        local playButton = CreateFrame("Button", "linePool.playButton" .. i, line)
        playButton:SetHitRectInsets(2, 2, 2, 2)
        playButton:SetFrameLevel(100)
        playButton:SetNormalTexture(QuestieLib.AddonPath .. "Icons\\QuestLogPlayButton")
        playButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight")

        playButton.SetPlayButton = function(self, questId)
            if not questId or questId <= 0 or not Questie.db.profile.trackerShowPlayButtons
                or not TrackerUtils:IsVoiceOverLoaded() then
                self.mode = nil
                self:Hide()
                return
            end
            self.mode = questId
            local margins = TrackerUtils:GetTrackerMargins()
            self:SetWidth(margins.playButtonSize)
            self:SetHeight(margins.playButtonSize)
            self:ClearAllPoints()
            self:SetPoint("CENTER", line, "TOPLEFT", margins.playButtonRight - margins.playButtonSize / 2, 1 - margins.buttonSize / 2)
            _UpdatePlayButton(self)
            self:Show()
        end

        playButton:EnableMouse(true)
        playButton:RegisterForClicks("LeftButtonUp")
        playButton:SetScript("OnClick", function(self)
            local questId = self.mode
            if not questId or not Questie.db.profile.trackerShowPlayButtons or not TrackerUtils:IsVoiceOverLoaded()
                or not line.Quest or line.Quest.Id ~= questId then return end
            local questIndex = GetQuestLogIndexByID(questId)
            if not questIndex or questIndex <= 0 then return end

            local button = VoiceOver.QuestOverlayUI.questPlayButtons[questId]
            if not button then return end
            if not button.soundData then
                local kind, id = VoiceOver.DataModules:GetQuestLogQuestGiverTypeAndID(questId)
                button.soundData = {
                    event = VoiceOver.Enums.SoundEvent.QuestAccept,
                    questID = questId,
                    name = id and VoiceOver.DataModules:GetObjectName(kind, id) or "Unknown Name",
                    title = GetQuestLogTitle(questIndex),
                    unitGUID = id and VoiceOver.Enums.GUID:CanHaveID(kind) and VoiceOver.Utils:MakeGUID(kind, id) or nil,
                }
            end

            local soundData = button.soundData
            if VoiceOver.SoundQueue:Contains(soundData) then
                VoiceOver.SoundQueue:RemoveSoundFromQueue(soundData)
            elseif VoiceOver.DataModules:PrepareSound(soundData) then
                soundData.stopCallback = function()
                    local owner = VoiceOver.QuestOverlayUI.questPlayButtons[questId]
                    -- A stopped sound must not clear audio for a later acceptance of this quest.
                    if owner and owner.soundData == soundData then owner.soundData = nil end
                    VoiceOver.QuestOverlayUI:UpdatePlayButtonTexture(questId)
                    if self.mode == questId then _UpdatePlayButton(self) end
                end
                VoiceOver.SoundQueue:AddSoundToQueue(soundData)
            end
            VoiceOver.QuestOverlayUI:UpdatePlayButtonTexture(questId)
            _UpdatePlayButton(self)

            if Questie.db.profile.stickyDurabilityFrame and DurabilityFrame and DurabilityFrame:IsVisible() and VoiceOverFrame then
                local _, _, _, _, offset = VoiceOverFrame:GetPoint()
                if offset and offset < -125 then QuestieTracker:UpdateVoiceOverFrame() end
            end
        end)
        playButton:Hide()
        line.playButton = playButton

        -- create expanding buttons for quests with objectives
        local expandQuest = CreateFrame("Button", "linePool.expandQuest" .. i, line)
        expandQuest.texture = expandQuest:CreateTexture(nil, "OVERLAY", nil, 0)
        expandQuest.texture:SetWidth(trackerFontSizeQuest)
        expandQuest.texture:SetHeight(trackerFontSizeQuest)
        expandQuest.texture:SetAllPoints(expandQuest)

        expandQuest:SetWidth(trackerFontSizeQuest)
        expandQuest:SetHeight(trackerFontSizeQuest)
        expandQuest:SetPoint("RIGHT", line, "LEFT", 0, 0)
        expandQuest:SetFrameLevel(100)

        expandQuest.SetMode = function(self, mode)
            if mode ~= self.mode then
                self.mode = mode
                local texture = mode == 1 and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up"
                self.texture:SetTexture(texture)
                self:SetHighlightTexture(texture, "ADD")
            end
            self:SetWidth(Questie.db.profile.trackerFontSizeQuest + 3)
            self:SetHeight(Questie.db.profile.trackerFontSizeQuest + 3)
        end

        expandQuest:SetMode(1) -- maximized
        expandQuest:EnableMouse(true)
        expandQuest:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        expandQuest:SetScript("OnClick", function(self)
            if self.mode == 1 then
                self:SetMode(0)
                Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:expandQuest] - Minimize")
            else
                self:SetMode(1)
                Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:expandQuest] - Maximize")
            end
            if Questie.db.char.collapsedQuests[self.questId] then
                Questie.db.char.collapsedQuests[self.questId] = nil

                -- This keeps both tables in sync so we can use them to maintain Min/Max states.
                if Questie.db.char.minAllQuestsInZone[self.zoneId] and Questie.db.char.minAllQuestsInZone[self.zoneId][self.questId] then
                    Questie.db.char.minAllQuestsInZone[self.zoneId][self.questId] = nil
                end
            else
                Questie.db.char.collapsedQuests[self.questId] = true

                -- This keeps both tables in sync so we can use them to maintain Min/Max states.
                if Questie.db.char.minAllQuestsInZone[self.zoneId] then
                    Questie.db.char.minAllQuestsInZone[self.zoneId][self.questId] = true
                end
            end
            QuestieCombatQueue:Queue(function()
                QuestieTracker:Update()
            end)
        end)

        if Questie.db.profile.trackerFadeMinMaxButtons then
            expandQuest:SetAlpha(0)
        end

        expandQuest:SetScript("OnEnter", function()
            TrackerFadeTicker.Unfade()
        end)

        expandQuest:SetScript("OnLeave", function()
            TrackerFadeTicker.Fade()
        end)

        expandQuest:Hide()

        -- create a small status icon to the left of the expand/minimize button
        local statusIcon = CreateFrame("Button", "linePool.statusIcon" .. i, line)
        statusIcon.texture = statusIcon:CreateTexture(nil, "OVERLAY", nil, 0)
        statusIcon.texture:SetWidth(trackerFontSizeQuest)
        statusIcon.texture:SetHeight(trackerFontSizeQuest)
        statusIcon.texture:SetAllPoints(statusIcon)
        statusIcon:SetWidth(trackerFontSizeQuest + 3)
        statusIcon:SetHeight(trackerFontSizeQuest + 3)
        statusIcon:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 1)
        statusIcon:SetFrameLevel(100)
        statusIcon:EnableMouse(false)
        QuestFocusButton.Configure(statusIcon)
        statusIcon:Hide()

        line.statusIcon = statusIcon

        line.expandQuest = expandQuest

        for _, button in ipairs({statusIcon, playButton, expandQuest}) do
            button:HookScript("OnEnter", function()
                TrackerLinePool.OnHighlightEnter(line)
                TrackerFadeTicker.Unfade()
            end)
            button:HookScript("OnLeave", function()
                TrackerLinePool.OnHighlightLeave()
                TrackerFadeTicker.Fade()
            end)
        end

        linePool[i] = line
        nextFrame = line

        yieldCount = yieldCount + 1
        if yieldCount >= TICKS_PER_YIELD then
            yieldCount = 0
            coYield()
        end
    end

    TrackerQuestItemButtons.Initialize()
end

function TrackerLinePool.ResetLinesForChange()
    if TrackerBaseFrame.isSizing == true or TrackerBaseFrame.isMoving == true then
        Questie.Debug(Questie.DEBUG_SPAM, "[TrackerLinePool:ResetLinesForChange]")
    else
        Questie.Debug(Questie.DEBUG_INFO, "[TrackerLinePool:ResetLinesForChange]")
    end

    if InCombatLockdown() or not Questie.db.profile.trackerEnabled then
        return
    end

    for _, line in pairs(linePool) do
        line.mode = nil
        line.trackTimedQuest = nil
        line.label.activeTimer = false
        line.timerReserveWidth = nil
        line:RefreshTimedQuestUpdater()
        if line.expandQuest then
            line.expandQuest.mode = nil
            line.expandQuest.questId = nil
            line.expandQuest.zoneId = nil
        end
        if line.statusIcon then
            line.statusIcon.questId = nil
            line.statusIcon.expectedQuest = nil
            line.statusIcon.acceptance = nil
            line.statusIcon:EnableMouse(false)
            line.statusIcon:Hide()
        end
        if line.expandZone then
            line.expandZone.mode = nil
            line.expandZone.zoneId = nil
        end
        if line.criteriaMark then
            line.criteriaMark.mode = nil
            line.criteriaMark:SetCriteria(false)
            line.criteriaMark:Hide()
        end
        if line.playButton then
            line.playButton.mode = nil
            line.playButton:Hide()
        end
    end

    lineIndex = 0
end

-- Keep tracker layout callers independent of the item-button pool implementation.
function TrackerLinePool.ResetButtonsForChange()
    return TrackerQuestItemButtons.ResetForChange()
end

---@param callback function
function TrackerLinePool.UpdateObjectiveLines(callback)
    for _, line in pairs(linePool) do
        if line.mode == "objective" then
            callback(line)
        end
    end
end

---@param callback function
function TrackerLinePool.UpdateQuestTitleLines(callback)
    for _, line in pairs(linePool) do
        if line.mode == "quest" then
            callback(line)
        end
    end
end

function TrackerLinePool.UpdateWrappedLineWidths(trackerLineWidth)
    local margins = TrackerUtils:GetTrackerMargins()
    local objectiveMarginLeft, questItemButtonSize = margins.objective, margins.itemButtonSize

    -- Updates all the line.label widths in the linePool for wrapped text only
    for _, line in pairs(linePool) do
        if Questie.db.profile.TrackerWidth == 0 then
            if line.mode == "objective" then
                if line.label:GetUnboundedStringWidth() > line.label:GetWidth() + 1 and line:GetHeight() > Questie.db.profile.trackerFontSizeObjective then
                    line.label:SetText(line.label:GetText())

                    if line.altButton then
                        line.label:SetWidth(trackerLineWidth - objectiveMarginLeft - questItemButtonSize)
                        line:SetWidth(trackerLineWidth + questItemButtonSize)
                    else
                        line.label:SetWidth(trackerLineWidth - objectiveMarginLeft)
                        line:SetWidth(trackerLineWidth)
                    end

                    local _, fontSize = line.label:GetFont()
                    local lineHeight = (fontSize * line.label:GetNumLines()) + 1
                    line.label:SetHeight(lineHeight)
                    line:SetHeight(lineHeight + 1)
                end
            end
        end
    end
end

---@return table|nil lineIndex linePool[lineIndex + 1]
function TrackerLinePool.GetNextLine()
    lineIndex = lineIndex + 1
    if not linePool[lineIndex] then
        return nil -- past the line limit
    end

    return linePool[lineIndex]
end

---@return Button|nil button
function TrackerLinePool.GetNextItemButton()
    return TrackerQuestItemButtons.GetNextButton()
end

---@param index number
---@return table index linePool[index]
function TrackerLinePool.GetLine(index)
    return linePool[index]
end

---@return table lineIndex linePool[lineIndex]
function TrackerLinePool.GetCurrentLine()
    return linePool[lineIndex]
end

---@return Button|nil button
function TrackerLinePool.GetCurrentButton()
    return TrackerQuestItemButtons.GetCurrentButton()
end

---@return table linePool linePool[1]
function TrackerLinePool.GetFirstLine()
    return linePool[1]
end

---@return table linePool linePool[linePoolSize]
function TrackerLinePool.GetLastLine()
    return linePool[linePoolSize]
end

function TrackerLinePool.HideUnusedLines()
    if TrackerBaseFrame.isSizing == true or TrackerBaseFrame.isMoving == true then
        Questie.Debug(Questie.DEBUG_SPAM, "[TrackerLinePool:HideUnusedLines]")
    else
        Questie.Debug(Questie.DEBUG_INFO, "[TrackerLinePool:HideUnusedLines]")
    end
    local startUnusedLines = 0

    if Questie.db.char.isTrackerExpanded then
        startUnusedLines = lineIndex + 1
    end

    for i = startUnusedLines, linePoolSize do
        local line = linePool[i]
        if line then -- Safe Guard to really concurrent triggers
            line:Hide()
            if line.statusIcon then
                line.statusIcon:Hide()
            end
            line.mode = nil
            line.ZoneId = nil
            line.Quest = nil
            line.Objective = nil
            line.Button = nil
            line.altButton = nil
            line.questHasSecondaryQIB = false
            line.trackTimedQuest = nil
            line.label.activeTimer = false
            line.timerReserveWidth = nil
            line:RefreshTimedQuestUpdater()
            line.expandQuest.mode = nil
            line.expandQuest.questId = nil
            line.expandQuest.zoneId = nil
            line.expandZone.mode = nil
            line.expandZone.zoneId = nil
            line.criteriaMark.mode = nil
            line.playButton.mode = nil
        end
    end
end

function TrackerLinePool.HideUnusedButtons()
    return TrackerQuestItemButtons.HideUnusedButtons()
end

---@return number lineIndex
function TrackerLinePool.GetHighestIndex()
    return lineIndex > linePoolSize and linePoolSize or lineIndex
end


---@param alpha number
function TrackerLinePool.SetAllExpandQuestAlpha(alpha)
    local highestIndex = TrackerLinePool.GetHighestIndex()
    for i = 1, highestIndex do
        linePool[i].expandQuest:SetAlpha(alpha)
    end
end

---@param alpha number
function TrackerLinePool.SetAllItemButtonAlpha(alpha)
    local highestIndex = TrackerLinePool.GetHighestIndex()
    -- TODO: I don't remember why I coded this hasButton variable. Going to leave it here for now.
    --local hasButton = false

    for i = 1, highestIndex do
        local line = linePool[i]

        if line.button then
            line.button:SetAlpha(alpha)
            --if line.button:GetAlpha() < 0.07 then
            --    hasButton = true
            --end
        end

        if line.altButton then
            line.altButton:SetAlpha(alpha)
            --if line.altButton:GetAlpha() < 0.07 then
            --    hasButton = true
            --end
        end
    end

    --[[
    if hasButton then
        QuestieTracker:Update()
    end
    --]]
end

---@param alpha number
function TrackerLinePool.SetAllStatusIconAlpha(alpha)
    local highestIndex = TrackerLinePool.GetHighestIndex()
    for i = 1, highestIndex do
        local line = linePool[i]
        if line and line.statusIcon then
            line.statusIcon:SetAlpha(alpha)
        end
    end
end

function TrackerLinePool.HideAllStatusIcons()
    local highestIndex = TrackerLinePool.GetHighestIndex()
    for i = 1, highestIndex do
        local line = linePool[i]
        if line and line.statusIcon then
            line.statusIcon:Hide()
        end
    end
end

---@param button string
TrackerLinePool.OnClickQuest = function(self, button)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:_OnClickQuest]")
    if (not self.Quest) then
        return
    end

    if TrackerMenu.menuFrame:IsShown() then
        LibDropDown:CloseDropDownMenus()
    end

    if not self.Quest.NativeOnly and TrackerUtils:IsBindTrue(Questie.db.profile.trackerbindSetTomTom, button) then
        local spawn, zone, name = QuestieMap:GetNearestQuestSpawn(self.Quest)
        if spawn then
            TrackerUtils:SetTomTomTarget(name, zone, spawn[1], spawn[2], self.Quest.Id)
        else
            TrackerUtils:SetTomTomTargetToDungeonEntrance(self.Quest)
        end
    elseif TrackerUtils:IsBindTrue(Questie.db.profile.trackerbindUntrack, button) then
        if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
            ChatEdit_InsertLink(TrackerData.GetQuestLink(self.Quest))
        else
            QuestieTracker:UntrackQuestId(self.Quest.Id)
            local questLogFrame = QuestLogExFrame or ClassicQuestLog or QuestLogFrame
            if questLogFrame:IsShown() then
                QuestLog_Update()
            end
        end
    elseif TrackerUtils:IsBindTrue(Questie.db.profile.trackerbindOpenQuestLog, button) then
        TrackerUtils:ShowQuestLog(self.Quest)
    elseif button == "RightButton" then
        local menu = TrackerMenu:GetMenuForQuest(self.Quest)
        LibDropDown:EasyMenu(menu, TrackerMenu.menuFrame, "cursor", 0, 0, "MENU")
    end
end

---@param button string
TrackerLinePool.OnClickAchieve = function(self, button)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerLinePool:_OnClickAchieve]")
    if (not self.Quest) then
        return
    end

    if TrackerMenu.menuFrame:IsShown() then
        LibDropDown:CloseDropDownMenus()
    end

    if TrackerUtils:IsBindTrue(Questie.db.profile.trackerbindUntrack, button) then
        if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
            ChatEdit_InsertLink(GetAchievementLink(self.Quest.Id))
        else
            if IsTrackedAchievement(self.Quest.Id) then
                QuestieTracker:UntrackAchieveId(self.Quest.Id)
                QuestieTracker:UpdateAchieveTrackerCache(self.Quest.Id)

                if (not AchievementFrame) then
                    AchievementFrame_LoadUI()
                end

                AchievementFrameAchievements_ForceUpdate()
            else
                -- Assume this is an Objective of an Achievement
                UIErrorsFrame:AddMessage(format(l10n("You can't untrack an objective of an achievement.")), 1.0, 0.1, 0.1, 1.0)
            end
        end
    elseif TrackerUtils:IsBindTrue(Questie.db.profile.trackerbindOpenQuestLog, button) then
        if (not AchievementFrame) then
            AchievementFrame_LoadUI()
        end

        if (not AchievementFrame:IsShown()) then
            AchievementFrame_ToggleAchievementFrame()
            AchievementFrame_SelectAchievement(self.Quest.Id)
        else
            if (AchievementFrameAchievements.selection ~= self.Quest.Id) then
                AchievementFrame_SelectAchievement(self.Quest.Id)
            end
        end
    elseif button == "RightButton" then
        local menu = TrackerMenu:GetMenuForAchievement(self.Quest)
        LibDropDown:EasyMenu(menu, TrackerMenu.menuFrame, "cursor", 0, 0, "MENU")
    end
end

TrackerLinePool.OnHighlightEnter = function(self)
    if Questie.db.profile.trackerDisableHoverFade then
        return
    end
    
    local highestIndex = TrackerLinePool.GetHighestIndex()
    for i = 1, highestIndex do
        local line = linePool[i]
        line:SetAlpha(0.5)

        if (line.Quest ~= nil and line.Quest == self.Quest) or (line.expandZone ~= nil and self:GetParent().expandZone ~= nil and line.expandZone.zoneId == self:GetParent().expandZone.zoneId) then
            line:SetAlpha(1)
        end
    end
end

TrackerLinePool.OnHighlightLeave = function()
    local highestIndex = TrackerLinePool.GetHighestIndex()
    for i = 1, highestIndex do
        linePool[i]:SetAlpha(1)
    end
end

-- Reused rows can move under a stationary cursor when quests or objectives change.
function TrackerLinePool.RefreshHighlight()
    TrackerLinePool.OnHighlightLeave()
    for i = 1, TrackerLinePool.GetHighestIndex() do
        local line = linePool[i]
        if line:IsVisible() then
            local hovered = MouseIsOver(line)
            if not hovered then
                for _, button in pairs({line.statusIcon, line.playButton, line.expandQuest, line.button, line.altButton}) do
                    if button:GetParent() == line and button:IsVisible() and MouseIsOver(button) then
                        hovered = true
                        break
                    end
                end
            end
            if hovered then
                TrackerLinePool.OnHighlightEnter(line.expandZone:IsVisible() and line.expandZone or line)
                return
            end
        end
    end
end

---@param mode string
TrackerLinePool.SetMode = function(self, mode)
    if mode ~= self.mode then
        self.mode = mode
        if mode == "zone" then
            local trackerFontSizeZone = Questie.db.profile.trackerFontSizeZone
            self.label:SetFont(LSM30:Fetch("font", Questie.db.profile.trackerFontZone), trackerFontSizeZone, Questie.db.profile.trackerFontOutline)
            self.label:SetHeight(trackerFontSizeZone)
            if self.statusIcon then
                self.statusIcon:Hide()
            end
        elseif mode == "quest" or mode == "achieve" then
            local trackerFontSizeQuest = Questie.db.profile.trackerFontSizeQuest
            self.label:SetFont(LSM30:Fetch("font", Questie.db.profile.trackerFontQuest), trackerFontSizeQuest, Questie.db.profile.trackerFontOutline)
            self.label:SetHeight(trackerFontSizeQuest)
            self.button = nil
            if self.statusIcon then
                if mode == "quest" and not Questie.db.profile.trackerShowQuestFocusButtons then
                    self.statusIcon.texture:SetWidth(trackerFontSizeQuest)
                    self.statusIcon.texture:SetHeight(trackerFontSizeQuest)
                    self.statusIcon:SetWidth(trackerFontSizeQuest)
                    self.statusIcon:SetHeight(trackerFontSizeQuest)
                    self.statusIcon:ClearAllPoints()
                    self.statusIcon:SetPoint("TOPLEFT", self, "TOPLEFT", TrackerUtils:GetTrackerMargins().statusLeft, 1)
                    self.statusIcon:SetHighlightTexture(nil)
                    self.statusIcon.isFocusButton = false
                    self.statusIcon:EnableMouse(false)
                    self.statusIcon:Show()
                else
                    self.statusIcon:Hide()
                end
            end
        elseif mode == "objective" then
            local trackerFontSizeObjective = Questie.db.profile.trackerFontSizeObjective
            self.label:SetFont(LSM30:Fetch("font", Questie.db.profile.trackerFontObjective), trackerFontSizeObjective, Questie.db.profile.trackerFontOutline)
            self.label:SetHeight(trackerFontSizeObjective)
            if self.statusIcon then
                self.statusIcon:Hide()
            end
        end
    end
end
