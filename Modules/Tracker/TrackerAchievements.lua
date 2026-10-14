---@class TrackerAchievements
local TrackerAchievements = QuestieLoader:CreateModule("TrackerAchievements")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local C_Timer = QuestieCompat.C_Timer
local lastAchieveId = GetTime()
-- Capture native watches before Questie's tracker hooks are installed.
local trackedAchievements = {GetTrackedAchievements()}
local trackedAchievementIds = {}

-- The renderer reads this cache; changes are synchronized after watch events.
function TrackerAchievements.GetTrackedIds()
    return trackedAchievementIds
end

function TrackerAchievements.ClearSavedTracking()
    Questie.db.char.trackedAchievementIds = {}
end

function TrackerAchievements.Initialize()
    -- The trackedAchievements variable is populated by GetTrackedAchievements(). If Questie
    -- is enabled, this will always return nil so we need to save it before we enable Questie.
    if #trackedAchievements > 0 then
        local tempAchieves = trackedAchievements

        -- Remove achievement from the Blizzard Quest Watch and populate the tracker.
        for _, achieveId in pairs(tempAchieves) do
            if achieveId then
                RemoveTrackedAchievement(achieveId)
                Questie.db.char.trackedAchievementIds[achieveId] = true

                if (not AchievementFrame) then
                    AchievementFrame_LoadUI()
                end

                AchievementFrameAchievements_ForceUpdate()
            end
        end
    end

    trackedAchievements = {GetTrackedAchievements()}
    WatchFrame_Update()

    -- Sync and populate QuestieTrackers achievement cache
    if Questie.db.char.trackedAchievementIds ~= trackedAchievementIds then
        for achieveId in pairs(Questie.db.char.trackedAchievementIds) do
            if Questie.db.char.trackedAchievementIds[achieveId] == true then
                trackedAchievementIds[achieveId] = true
            end
        end
    end
end

function TrackerAchievements.RegisterHooks()
    -- Achievement secure hooks
    hooksecurefunc("AddTrackedAchievement", function(achieveId) QuestieTracker:TrackAchieve(achieveId) end)
    hooksecurefunc("RemoveTrackedAchievement", QuestieTracker.RemoveTrackedAchievement)
end

function TrackerAchievements.InstallQueryHooks()
    -- Achievement Hooks
    if not QuestieTracker.IsTrackedAchievement then
        QuestieTracker.IsTrackedAchievement = IsTrackedAchievement
        QuestieTracker.GetNumTrackedAchievements = GetNumTrackedAchievements
    end

    -- Intercept and return a Questie boolean value
    IsTrackedAchievement = function(achieveId)
        if Questie.db.char.trackedAchievementIds[achieveId] then
            return achieveId and Questie.db.char.trackedAchievementIds[achieveId]
        else
            return false
        end
    end

    -- Intercept and return only what Questie is tracking
    GetNumTrackedAchievements = function(isQuestie)
        if isQuestie and Questie.db.char.trackedAchievementIds then
            local numTrackedAchievements = 0
            for _ in pairs(Questie.db.char.trackedAchievementIds) do
                numTrackedAchievements = numTrackedAchievements + 1
            end
            return numTrackedAchievements
        else
            return 0
        end
    end
end

function TrackerAchievements.RestoreQueryHooks()
    -- Achievement Hooks
    if QuestieTracker.IsTrackedAchievement then
        IsTrackedAchievement = QuestieTracker.IsTrackedAchievement
        GetNumTrackedAchievements = QuestieTracker.GetNumTrackedAchievements
    end
end

TrackerAchievements.RemoveTrackedAchievement = function(achieveId, isQuestie)
    if QuestieTracker.disableHooks then
        return
    end

    if not isQuestie then
        if achieveId then
            QuestieTracker:UntrackAchieveId(achieveId)
            Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker.RemoveTrackedAchievement] - by Blizzard")
        end
    else
        Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker.RemoveTrackedAchievement] - by Questie")
    end
end

function TrackerAchievements:UpdateAchieveTrackerCache(achieveId)
    -- Since we're essentially adding & force removing an achievement from the QuestWatch frame while we add an achievement to the Questie Tracker, the event this
    -- function is called from, TRACKED_ACHIEVEMENT_LIST_CHANGED, fires twice. When we remove an achievement from the Questie Tracker the event still fires twice
    -- because the Blizzard function responsible for this is essentially a "toggle". It quickly re-adds the achievement to the QuestWatch frame and then removes it.
    -- So, again this event again fires twice. We only need to allow this to run once and it often fires before the Questie.db.char.trackedAchievementIds table is
    -- updated so we're going to throttle this 1/10th of a second.
    if Questie.db.profile.trackerEnabled then
        if achieveId then
            C_Timer.After(0.1, function()
                Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker:UpdateAchieveTrackerCache] - ", achieveId)

                if (not Questie.db.profile.trackerEnabled) or (achieveId == 0) then
                    return
                end

                -- Look for changes in the Saved VAR and update the achievement cache
                if Questie.db.char.trackedAchievementIds[achieveId] ~= trackedAchievementIds[achieveId] then
                    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker:UpdateAchieveTrackerCache] - Change Detected!")

                    trackedAchievementIds[achieveId] = Questie.db.char.trackedAchievementIds[achieveId]

                    QuestieCombatQueue:Queue(function()
                        C_Timer.After(0.1, function()
                            QuestieTracker:Update()
                        end)
                    end)
                else
                    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker:UpdateAchieveTrackerCache] - No Change Detected!")
                end
            end)
        end
    end
end

function TrackerAchievements:UntrackAchieveId(achieveId)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker:UntrackAchieve] - ", achieveId)
    if Questie.db.char.trackedAchievementIds[achieveId] then
        Questie.db.char.trackedAchievementIds[achieveId] = nil
    end
end

function TrackerAchievements:TrackAchieve(achieveId)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieTracker:TrackAchieve] - ", achieveId)
    if (not Questie.db.profile.trackerEnabled) or (achieveId == 0) then
        return
    end

    -- Questie removes achievements from Blizzard's tracker, so another click in the
    -- Achievement UI comes back through AddTrackedAchievement and needs to toggle off.
    if Questie.db.char.trackedAchievementIds[achieveId] then
        RemoveTrackedAchievement(achieveId, true)

        if AchievementFrame and AchievementFrame:IsShown() then
            QuestieTracker:UntrackAchieveId(achieveId)
        end

        return
    end

    -- Prevents tracking more than 10 Achievements
    if (GetNumTrackedAchievements(true) == 10) then
        RemoveTrackedAchievement(achieveId, true)
        UIErrorsFrame:AddMessage(format(l10n("You may only track 10 achievements at a time."), 10), 1.0, 0.1, 0.1, 1.0)
        return
    end

    -- This prevents double calling this function
    local now = GetTime()
    if achieveId and achieveId == QuestieTracker.last_achieveId and (now - lastAchieveId) < 0.1 then
        return
    end

    lastAchieveId = now
    QuestieTracker.last_achieveId = achieveId

    -- This removes achievements from the Blizzard QuestWatchFrame so when the
    -- option "Show Blizzard Timer" is enabled, that is all the player will see.
    RemoveTrackedAchievement(achieveId, true)

    if achieveId > 0 then
        -- This handles the Track check box in the Achievement UI
        local mouseFocus
        local frameMatch

        -- Krowi isn't using this check box for their Achievement frame
        if not IsAddOnLoaded("Krowi_AchievementFilter") then
            local mouseFocusFrame = GetMouseFocus()
            mouseFocus = mouseFocusFrame and mouseFocusFrame:GetName()

            if mouseFocus then
                frameMatch = strmatch(mouseFocus, "(AchievementFrameAchievementsContainerButton%dTracked.*)")
            end
        end

        -- Upon first login or reloadui, this frame isn't loaded
        if (not AchievementFrame) then
            AchievementFrame_LoadUI()
        end

        -- Allow achievements to be tracked through the Blizzard Achievement UI
        -- or programmatically through AddTrackedAchievement.
        if Questie.db.char.trackedAchievementIds[achieveId] then
            Questie.db.char.trackedAchievementIds[achieveId] = nil
        elseif not AchievementFrame:IsShown() then
            Questie.db.char.trackedAchievementIds[achieveId] = true
        elseif IsShiftKeyDown() and AchievementFrame:IsShown() then
            Questie.db.char.trackedAchievementIds[achieveId] = true
        elseif AchievementFrame:IsShown() and (mouseFocus == frameMatch) then
            Questie.db.char.trackedAchievementIds[achieveId] = true
        end

        -- Forces the achievement out of a minimized state
        if Questie.db.char.collapsedQuests[achieveId] == true then
            Questie.db.char.collapsedQuests[achieveId] = nil
        end

        -- Forces the 'Achievement Zone' out of a minimized state
        if Questie.db.char.collapsedZones["Achievements"] == true then
            Questie.db.char.collapsedZones["Achievements"] = nil
        end
    end
end
