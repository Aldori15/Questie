---@class TrackerQuestTimers
local TrackerQuestTimers = QuestieLoader:CreateModule("TrackerQuestTimers")
-------------------------
--Import QuestieTracker modules.
-------------------------
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerLinePool
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
-------------------------
--Import Questie modules.
-------------------------
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

--- COMPATIBILITY ---
local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID

local LSM30 = LibStub("LibSharedMedia-3.0")

local WatchFrame = QuestTimerFrame or WatchFrame
local blizzardTimerLocation = {}
local timer

local function _ApplyTimerText(frame, timeRemainingString)
    if not frame or not frame.label then
        return
    end

    frame.label:SetFont(LSM30:Fetch("font", Questie.db.profile.trackerFontObjective), Questie.db.profile.trackerFontSizeObjective, Questie.db.profile.trackerFontOutline)
    frame.label:SetText(Questie:Colorize(timeRemainingString, "lightBlue"))

    local unboundedWidth = frame.label:GetUnboundedStringWidth() + 2
    if frame.timerReserveWidth and frame.timerReserveWidth > unboundedWidth then
        unboundedWidth = frame.timerReserveWidth
    end

    frame.label:SetWidth(unboundedWidth)
    frame:SetWidth(unboundedWidth + ((34) - (18 - Questie.db.profile.trackerFontSizeQuest)) + Questie.db.profile.trackerFontSizeQuest)
end

-- Save the default location of the Blizzard QuestTimerFrame
if not (Questie.IsWotlk or QuestieCompat.Is335) then
    blizzardTimerLocation = { QuestTimerFrame:GetPoint() }
end

function TrackerQuestTimers:Initialize()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestTimers:Initialize]")

    if QuestieTracker.started or (not Questie.db.profile.trackerEnabled) then
        return
    end

    -- All Classic expansions
    WatchFrame:HookScript("OnShow", function()
        if Questie.db.profile.showBlizzardQuestTimer then
            TrackerQuestTimers:ShowBlizzardTimer()
        else
            TrackerQuestTimers:HideBlizzardTimer()
        end
    end)

    -- Pre-Classic WotLK
    if not (Questie.IsWotlk or QuestieCompat.Is335) then
        local timeElapsed = 0

        WatchFrame:HookScript("OnUpdate", function(_, elapsed)
            timeElapsed = timeElapsed + elapsed
            if timeElapsed > 1 then
                TrackerQuestTimers:UpdateTimerFrame()
                timeElapsed = 0
            end
        end)
    end
end

function TrackerQuestTimers:HideBlizzardTimer()
    if Questie.IsWotlk or QuestieCompat.Is335 then
        -- Classic WotLK
        WatchFrame:Hide()
    else
        -- Classic WoW: This moves the QuestTimerFrame off screen. A faux Hide().
        -- Otherwise, if the frame is hidden then the OnUpdate doesn't work.
        WatchFrame:ClearAllPoints()
        WatchFrame:SetPoint("TOP", "UIParent", -10000, -10000)
    end
end

function TrackerQuestTimers:ShowBlizzardTimer()
    if Questie.IsWotlk or QuestieCompat.Is335 then
        -- Classic WotLK
        WatchFrame:Show()
    else
        -- Classic WoW: This moves the QuestTimerFrame
        -- back its default location. A faux Show()
        if blizzardTimerLocation[1] then
            WatchFrame:ClearAllPoints()
            WatchFrame:SetPoint(unpack(blizzardTimerLocation))
        end
    end
end

---@param quest table
---@param frame frame
---@param clear boolean
---@return string|nil timeRemainingString, number|nil timeRemaining
function TrackerQuestTimers:GetRemainingTime(quest, frame, clear)
    local timeRemainingString, timeRemaining = TrackerQuestTimers:GetRemainingTimeByQuestId(quest.Id)

    if (timeRemainingString == nil) then
        quest.timedBlizzardQuest = nil
        quest.trackTimedQuest = false
        return nil
    end

    if clear then
        timer = nil
    elseif frame then
        timer = {
            frame = frame,
            questId = quest.Id
        }
    end

    if timeRemaining then
        if Questie.db.profile.showBlizzardQuestTimer then
            TrackerQuestTimers:ShowBlizzardTimer()
            quest.timedBlizzardQuest = true
            quest.trackTimedQuest = false
        else
            TrackerQuestTimers:HideBlizzardTimer()
            quest.timedBlizzardQuest = false
            quest.trackTimedQuest = true
        end
    end

    return timeRemainingString, timeRemaining
end

---@param questId number
---@return string timeRemainingString, number timeRemaining, nil
function TrackerQuestTimers:GetRemainingTimeByQuestId(questId)
    local questLogIndex = GetQuestLogIndexByID(questId)
    if (not questLogIndex) then
        return nil
    end

    local questTimers = GetQuestTimers(questId)
    if (not questTimers) then
        return nil
    end

    if type(questTimers) == "number" then
        local currentQuestLogSelection = GetQuestLogSelection()
        SelectQuestLogEntry(questLogIndex)
        -- We can't use GetQuestTimers because we don't know for which quest the timer is.
        -- GetQuestLogTimeLeft returns the correct value though.
        local timeRemaining = GetQuestLogTimeLeft(questLogIndex)
        SelectQuestLogEntry(currentQuestLogSelection)

        if timeRemaining ~= nil then
            local timeRemainingString = SecondsToTime(timeRemaining, false, true)

            if not strfind(timeRemainingString, "Seconds?") then
                timeRemainingString = timeRemainingString .. " 0 Seconds"
            end
            return timeRemainingString, timeRemaining
        else
            return nil
        end
    else
        Questie:Error("The return value of GetQuestTimers is not number, something is off. Please report this!")
    end

    return nil
end

---@param frame frame|nil
---@param questId number|nil
---@param timeRemainingString string|nil
function TrackerQuestTimers:UpdateTimerFrame(frame, questId, timeRemainingString)
    if not (Questie.db.profile.trackerEnabled and Questie.db.char.isTrackerExpanded and (QuestieTracker.disableHooks ~= true)) then
        return
    end

    local timerFrame = frame
    local timerQuestId = questId

    if (not timerFrame) or (not timerQuestId) then
        if not timer then
            return
        end

        timerFrame = timer.frame
        timerQuestId = timer.questId
    end

    if timerFrame and timerQuestId then
        timeRemainingString = timeRemainingString or TrackerQuestTimers:GetRemainingTimeByQuestId(timerQuestId)
        if timeRemainingString ~= nil then
            Questie:Debug(Questie.DEBUG_SPAM, "[TrackerQuestTimers:UpdateTimerFrame] - ", timeRemainingString)

            QuestieCombatQueue:Queue(function()
                if (not timerFrame) or (not timerFrame.label) then
                    return
                end

                _ApplyTimerText(timerFrame, timeRemainingString)
            end)
        else
            Questie:Debug(Questie.DEBUG_SPAM, "[TrackerQuestTimers] Quest Timer Expired!")
            if timer and timer.frame == timerFrame and timer.questId == timerQuestId then
                timer = nil
            end
            return
        end
    end
end
