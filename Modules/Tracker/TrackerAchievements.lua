---@class TrackerAchievements
local TrackerAchievements = QuestieLoader:CreateModule("TrackerAchievements")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

local initialized = false
local refreshQueued = false
local blizzardAchievementHandler
local dragonUITracker

-- Keep the renderer's ID-set interface while reading the game's current watches.
function TrackerAchievements.GetTrackedIds()
    local ids = {}
    for _, id in ipairs({GetTrackedAchievements()}) do
        ids[id] = true
    end
    return ids
end

local previousTrackedIds = TrackerAchievements.GetTrackedIds()

function TrackerAchievements.Initialize()
    if initialized then return end
    initialized = true

    -- Import the old Questie-only watches without replacing existing native watches.
    local saved = Questie.db.char.trackedAchievementIds
    if type(saved) == "table" then
        local ids = {}
        for id, tracked in pairs(saved) do
            if tracked and type(id) == "number" and id > 0 then
                ids[#ids + 1] = id
            else
                saved[id] = nil
            end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local achievementId, _, _, completed = GetAchievementInfo(id)
            if achievementId and not completed and not IsTrackedAchievement(id)
                and GetNumTrackedAchievements() < 10 then
                AddTrackedAchievement(id)
            end
            if IsTrackedAchievement(id) or (achievementId and completed) then
                saved[id] = nil
            end
        end
        -- Retain watches that could not be imported for a later login, not a profile change.
        if not next(saved) then Questie.db.char.trackedAchievementIds = nil end
    end
end

local function _HideBlizzardAchievementRows(lineFrame, initialOffset, maxHeight, frameWidth)
    -- No IDs means Blizzard releases old rows without changing native tracking or timers.
    return WatchFrame_DisplayTrackedAchievements(lineFrame, initialOffset, maxHeight, frameWidth)
end

local function _FilterDragonUIRows(blocks)
    if not QuestieTracker.started or not Questie.db.profile.trackerEnabled or QuestieTracker.disableHooks then return end
    for index = #blocks, 1, -1 do
        local kind = blocks[index].kind
        if kind == "quest" or kind == "achievement" or kind == "timer" then
            table.remove(blocks, index)
        end
    end
end

function TrackerAchievements.RefreshDragonUI()
    local tracker = DragonUI and DragonUI.ObjectiveTracker
    if not (tracker and tracker.AddCollector) then return end
    if dragonUITracker ~= tracker then
        tracker.AddCollector(_FilterDragonUIRows)
        dragonUITracker = tracker
    end
    if tracker.Refresh then tracker.Refresh() end
end

function TrackerAchievements.HideBlizzardAchievements()
    TrackerAchievements.RefreshDragonUI()
    for index, handler in ipairs(WATCHFRAME_OBJECTIVEHANDLERS or {}) do
        if handler == WatchFrame_HandleDisplayTrackedAchievements then
            blizzardAchievementHandler = handler
            WATCHFRAME_OBJECTIVEHANDLERS[index] = _HideBlizzardAchievementRows
            WatchFrame_Update()
            return
        end
    end
end

function TrackerAchievements.RestoreBlizzardAchievements()
    TrackerAchievements.RefreshDragonUI()
    if not blizzardAchievementHandler then return end
    for index, handler in ipairs(WATCHFRAME_OBJECTIVEHANDLERS or {}) do
        if handler == _HideBlizzardAchievementRows then
            WATCHFRAME_OBJECTIVEHANDLERS[index] = blizzardAchievementHandler
            WatchFrame_Update()
            break
        end
    end
    blizzardAchievementHandler = nil
end

local function _RefreshTracker()
    refreshQueued = false
    if Questie.db.profile.trackerEnabled and not QuestieTracker.disableHooks then
        QuestieTracker:Update()
    end
end

-- Kept as the existing public entry point; there is no separate watch cache anymore.
function TrackerAchievements:UpdateAchieveTrackerCache()
    -- A pending legacy watch may be added manually after a native slot is freed.
    -- Consume it now so untracking it cannot restore it on the next login.
    local saved = Questie.db.char.trackedAchievementIds
    if type(saved) == "table" then
        for _, id in ipairs({GetTrackedAchievements()}) do saved[id] = nil end
        if not next(saved) then Questie.db.char.trackedAchievementIds = nil end
    end
    if not QuestieTracker.started or not Questie.db.profile.trackerEnabled or QuestieTracker.disableHooks then return end
    -- Wrath also reports watch changes through TRACKED_ACHIEVEMENT_UPDATE.
    -- Compare membership so progress events never expand a manually collapsed section.
    local ids = TrackerAchievements.GetTrackedIds()
    for id in pairs(ids) do
        if not previousTrackedIds[id] then
            Questie.db.char.collapsedQuests[id] = nil
            Questie.db.char.collapsedZones["Achievements"] = nil
        end
    end
    previousTrackedIds = ids
    if not refreshQueued then
        refreshQueued = true
        QuestieCombatQueue:Queue(_RefreshTracker)
    end
end

function TrackerAchievements:UntrackAchieveId(achievementId)
    if achievementId and achievementId > 0 and IsTrackedAchievement(achievementId) then
        RemoveTrackedAchievement(achievementId)
    end
end

function TrackerAchievements:TrackAchieve(achievementId)
    if achievementId and achievementId > 0 and not IsTrackedAchievement(achievementId) then
        AddTrackedAchievement(achievementId)
    end
end
