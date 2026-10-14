---@class TrackerVisibility
local TrackerVisibility = QuestieLoader:CreateModule("TrackerVisibility")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

-- Remember which automatic policy changed the tracker, so leaving combat or an
-- instance preserves a player's manual collapse and the other active policy.
local minimizedByInstance = false
local hiddenByInstance = false
local minimizedByCombat = false
local hiddenByCombat = false

local function CollapseInInstance()
    -- Combat can delay this work until the player leaves or changes settings.
    if minimizedByInstance and QuestieTracker.started and Questie.db.profile.trackerEnabled
        and Questie.db.profile.minimizeTrackerInInstances and IsInInstance() then
        QuestieTracker:Collapse()
    end
end

---@return boolean
function TrackerVisibility.IsHidden()
    return hiddenByInstance or hiddenByCombat
end

---@param frame Frame
function TrackerVisibility.UpdateFrameVisibility(frame)
    if hiddenByInstance or hiddenByCombat then
        frame:Hide()
    elseif (not QuestieTracker:HasQuest()) then
        if Questie.db.profile.alwaysShowTracker then
            frame:Show()
        else
            frame:Hide()
        end
    else
        frame:Show()
    end
end

function TrackerVisibility.HandleZoneChanged()
    if (not QuestieTracker.started) or (not Questie.db.profile.trackerEnabled) then
        return
    end

    if IsInInstance() then
        if Questie.db.profile.minimizeTrackerInInstances then
            if Questie.db.char.isTrackerExpanded then
                minimizedByInstance = true
                QuestieCombatQueue:Queue(CollapseInInstance)
            end
        elseif Questie.db.profile.hideTrackerInInstances then
            hiddenByInstance = true
            QuestieTracker:Hide()
        end
    else
        if minimizedByInstance and (not UnitIsGhost("player")) then
            minimizedByInstance = false
            if Questie.db.profile.minimizeTrackerInInstances and (not Questie.db.char.isTrackerExpanded) then
                QuestieCombatQueue:Queue(function()
                    QuestieTracker:Expand()
                end)
            end
        end

        if hiddenByInstance then
            hiddenByInstance = false
            if Questie.db.profile.hideTrackerInInstances then
                QuestieTracker:Show()
            end
        end
    end
end

---@param enabled boolean
function TrackerVisibility.OnMinimizeInInstancesChanged(enabled)
    if enabled then
        if QuestieTracker.started and IsInInstance() and Questie.db.char.isTrackerExpanded then
            minimizedByInstance = true
            QuestieCombatQueue:Queue(CollapseInInstance)
        end
    elseif minimizedByInstance then
        minimizedByInstance = false
        QuestieCombatQueue:Queue(function()
            QuestieTracker:Expand()
        end)
    end
end

---@param enabled boolean
function TrackerVisibility.OnHideInInstancesChanged(enabled)
    if enabled then
        if QuestieTracker.started and IsInInstance() then
            hiddenByInstance = true
            QuestieTracker:Hide()
        end
    elseif hiddenByInstance then
        hiddenByInstance = false
        QuestieTracker:Show()
    end
end

function TrackerVisibility.HandleCombatStarted()
    if (not QuestieTracker.started) or (not Questie.db.profile.trackerEnabled) then
        return
    end

    if Questie.db.profile.minimizeTrackerInCombat and Questie.db.char.isTrackerExpanded and (not minimizedByCombat) then
        minimizedByCombat = true
        QuestieTracker:Collapse()
    elseif Questie.db.profile.hideTrackerInCombat and (not hiddenByCombat) then
        hiddenByCombat = true
        QuestieTracker:Hide()
    end

    if IsInInstance() and Questie.db.profile.minimizeTrackerInInstances then
        QuestieTracker:Collapse()
    end
end

function TrackerVisibility.HandleCombatEnded()
    if Questie.db.profile.minimizeTrackerInCombat and minimizedByCombat then
        if IsInInstance() and Questie.db.profile.minimizeTrackerInInstances then
            minimizedByCombat = false
            minimizedByInstance = true
        else
            minimizedByCombat = false
            QuestieTracker:Expand()
        end

        QuestieCombatQueue:Queue(function()
            QuestieTracker:Update()
        end)
    elseif Questie.db.profile.hideTrackerInCombat and hiddenByCombat then
        if IsInInstance() and Questie.db.profile.hideTrackerInInstances then
            hiddenByCombat = false
            hiddenByInstance = true
        else
            hiddenByCombat = false
            QuestieTracker:Show()
        end
    end
end

---@param enabled boolean
function TrackerVisibility.OnMinimizeInCombatChanged(enabled)
    if enabled then
        if QuestieTracker.started and InCombatLockdown() and Questie.db.char.isTrackerExpanded then
            minimizedByCombat = true
            QuestieTracker:Collapse()
        end
    elseif minimizedByCombat then
        if IsInInstance() and Questie.db.profile.minimizeTrackerInInstances then
            minimizedByCombat = false
            minimizedByInstance = true
        else
            minimizedByCombat = false
            QuestieTracker:Expand()
        end
    end
end

---@param enabled boolean
function TrackerVisibility.OnHideInCombatChanged(enabled)
    if enabled then
        if QuestieTracker.started and InCombatLockdown() then
            hiddenByCombat = true
            QuestieTracker:Hide()
        end
    elseif hiddenByCombat then
        if IsInInstance() and Questie.db.profile.hideTrackerInInstances then
            hiddenByCombat = false
            hiddenByInstance = true
        else
            hiddenByCombat = false
            QuestieTracker:Show()
        end
    end
end
