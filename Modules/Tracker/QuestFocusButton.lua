---@class QuestFocusButton
local QuestFocusButton = QuestieLoader:CreateModule("QuestFocusButton")
local QuestLifecycle = QuestieLoader:ImportModule("QuestLifecycle")
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
local TrackerData = QuestieLoader:ImportModule("TrackerData")
local TrackerFadeTicker = QuestieLoader:ImportModule("TrackerFadeTicker")
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
local l10n = QuestieLoader:ImportModule("l10n")
local WorldMapFrame = QuestieCompat.WorldMapFrame

local function isCurrent(quest, acceptance)
    return quest and not quest.NativeOnly and TrackerData.ContainsQuest(quest.Id)
        and TrackerData.GetQuest(quest.Id) == quest
        and QuestLifecycle.IsCurrentAcceptance(quest.Id, acceptance)
end

local function canFocus(quest)
    if quest:IsComplete() == -1 then return end
    return QuestieMap:GetNearestQuestSpawn(quest)
end

function QuestFocusButton.GetColumnWidth()
    return Questie.db.profile.trackerShowQuestFocusButtons and (Questie.db.profile.trackerFontSizeQuest + 5) or 0
end

function QuestFocusButton.SetQuest(button, quest, isComplete)
    local acceptance = quest and QuestLifecycle.GetAcceptance(quest.Id)
    local focused = quest and Questie.db.char.TrackerFocus == quest.Id
    if not Questie.db.profile.trackerShowQuestFocusButtons or not isCurrent(quest, acceptance)
        or (not focused and not canFocus(quest)) then
        button.isFocusButton = false
        button.questId, button.expectedQuest, button.acceptance = nil, nil, nil
        button:EnableMouse(false)
        button:Hide()
        return
    end

    local wasFocusButton = button.isFocusButton
    button.isFocusButton = true
    button.questId, button.expectedQuest, button.acceptance = quest.Id, quest, acceptance
    local size = Questie.db.profile.trackerFontSizeQuest + 3
    button:SetWidth(size)
    button:SetHeight(size)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", 0, 1)
    local texture = (isComplete == true or isComplete == 1) and "complete" or "incomplete"
    local path = QuestieLib.AddonPath .. "Icons\\poi_" .. texture .. (focused and "_focused" or "") .. ".blp"
    button.texture:SetTexture(path)
    button:SetHighlightTexture(path, "ADD")
    if not Questie.db.profile.trackerFadeQuestFocusButtons then
        button:SetAlpha(1)
    elseif not wasFocusButton then
        button:SetAlpha(0)
    end
    button:EnableMouse(true)
    button:Show()
end

function QuestFocusButton.Configure(button)
    button.isFocusButton = false
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function(self)
        local quest = self.expectedQuest
        if not Questie.db.profile.trackerShowQuestFocusButtons or not self.isFocusButton
            or not isCurrent(quest, self.acceptance) then return end

        local focused = Questie.db.char.TrackerFocus == quest.Id
        if focused then
            TrackerUtils:UnFocus()
            if Questie.db.char._tom_waypoint_source == "questFocus" then
                TrackerUtils:ClearTomTomTargetForQuest(quest.Id)
            end
        else
            local spawn, zone, name = canFocus(quest)
            if not spawn then return end
            TrackerUtils:FocusQuest(quest.Id)
            TrackerUtils:SetTomTomTarget(name or quest.name, zone, spawn[1], spawn[2], quest.Id, nil, "questFocus")
        end
        QuestFocusButton.SetQuest(self, quest, quest:IsComplete() == 1)
        QuestieQuest:RefreshQuestIconVisibility()
        if not focused and WorldMapFrame:IsShown() then
            TrackerUtils:ShowQuestOnMap(quest)
        end
        QuestieCombatQueue:Queue(function() QuestieTracker:Update(true) end)
    end)
    button:SetScript("OnEnter", function(self)
        if not self.isFocusButton or not self.questId then return end
        TrackerFadeTicker.Unfade()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(l10n(Questie.db.char.TrackerFocus == self.questId and "Unfocus" or "Focus Quest"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self.isFocusButton then TrackerFadeTicker.Fade() end
    end)
end
