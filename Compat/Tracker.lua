---@type TrackerLinePool
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")

function QuestieCompat.QuestieTracker_Initialize(trackerQuestFrame)
    -- TrackerHeaderFrame.Initialize
    Questie_HeaderFrame.trackedQuests.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
    -- TrackerQuestFrame.Initialize
    trackerQuestFrame.ScrollFrame.scrollBarHideable = true
    trackerQuestFrame.ScrollBar:ClearAllPoints()
    trackerQuestFrame.ScrollBar:SetPoint("TOPRIGHT", trackerQuestFrame.ScrollUpButton, "BOTTOMRIGHT", -1, 4)
    trackerQuestFrame.ScrollBar:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollDownButton, "TOPRIGHT", -1, -4)
    trackerQuestFrame.ScrollDownButton:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollFrame, "BOTTOMRIGHT", -4, 12)
    trackerQuestFrame.ScrollBg:SetTexture(0, 0, 0, 0.35)
    trackerQuestFrame.ScrollBg:Show()
    trackerQuestFrame.ScrollBar.Show = function() end
    -- TrackerLinePool.Initialize
    for i = 1, 250 do
        local line = _G["linePool" .. i]
        line.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
        line.label.GetWrappedWidth = line.label.GetWidth
        line.label.GetNumLines = QuestieCompat.GetNumLines
    end
end

function QuestieCompat.RegisterTrackerCompatibilityHooks()
    hooksecurefunc(TrackerLinePool, "Initialize", QuestieCompat.QuestieTracker_Initialize)
end
