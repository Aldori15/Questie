-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exact strings protect color escapes, counts, and wrapped achievement labels.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    if setfenv then
        setfenv(assert(loadfile(path)), env)()
    else
        assert(loadfile(path, "t", env))()
    end
end

local env = setmetatable({}, {__index = _G})
env._G = env
env.Questie = {db = {profile = {trackerColorObjectives = "white"}}}
env.QuestieCompat = {}
-- These unrelated patterns are only used to initialize QuestieLib.
env.QUEST_MONSTERS_KILLED = "slain"
env.QUEST_ITEMS_NEEDED = "needed"
env.QUEST_OBJECTS_FOUND = "found"
loadModule("Modules/Libs/QuestieLoader.lua", env)
env.QuestieLoader:CreateModule("QuestieDB").questTagIds = {
    PVP = 1, CLASS = 2, ESCORT = 3, RAID = 4, RAID_10 = 5,
    RAID_25 = 6, DUNGEON = 7, HEROIC = 8, WORLD_EVENT = 9,
}
loadModule("Modules/Libs/QuestieLib.lua", env)
loadModule("Modules/Tracker/TrackerObjectiveText.lua", env)
loadModule("Modules/Tracker/TrackerData.lua", env)
local formatter = env.QuestieLoader:ImportModule("TrackerObjectiveText")
local library = env.QuestieLoader:ImportModule("QuestieLib")
local profile = env.Questie.db.profile
local white = "|cFFededed"
local half = "|cFFfefe00"
local groups = 0

local coloredTitle = "|cFFFFFF00Waste Not, Want Not|r"
profile.showQuestPercent = true
for _, case in ipairs({
    {progress = 0, suffix = " |cFFfe0000(0%)|r"},
    {progress = 0.5, suffix = " |cFFfefe00(50%)|r"},
    {progress = 1, suffix = " |cFF27fe27(100%)|r"},
    {progress = 0.259, suffix = " |cFFfe8300(25%)|r"},
    {progress = "unknown", suffix = ""},
    {suffix = ""},
}) do
    equal(formatter.GetQuestTitleText(coloredTitle, case.progress), coloredTitle .. case.suffix, "quest title percentage and fallback")
    groups = groups + 1
end
profile.showQuestPercent = false
equal(formatter.GetQuestTitleText(coloredTitle, 0.5), coloredTitle, "disabled title percentage")
groups = groups + 1

for _, percent in ipairs({false, true}) do
    for _, first in ipairs({false, true}) do
        profile.showQuestPercent, profile.showQuestProgressFirst = percent, first
        local expected
        if percent and first then
            expected = white .. "- |r" .. half .. "4/8|r " .. white .. "Salvaged Metal|r"
        elseif percent then
            expected = white .. "- Salvaged Metal: |r" .. half .. "4/8|r"
        elseif first then
            expected = "|cFFEEEEEE- 4/8 Salvaged Metal|r"
        else
            expected = "|cFFEEEEEE- Salvaged Metal: 4/8|r"
        end
        local objective = {Collected = 4, Needed = 8, Completed = false}
        equal(formatter.GetQuestObjectiveText(objective, "Salvaged Metal"), expected, "quest count placement and colors")
        equal(objective.Collected, 4, "formatting preserves collected count")
        equal(objective.Needed, 8, "formatting preserves required count")
        equal(objective.Completed, false, "formatting preserves completion state")
        groups = groups + 1
    end
end

profile.showQuestPercent, profile.showQuestProgressFirst = true, false
for _, progress in ipairs({{0, "|cFFfe0000"}, {2, "|cFFfe7f00"}, {6, "|cFF92fe13"}, {8, "|cFF27fe27"}}) do
    equal(formatter.GetQuestObjectiveText({Collected = progress[1], Needed = 8}, "Metal"),
        white .. "- Metal: |r" .. progress[2] .. progress[1] .. "/8|r", "progress gradient")
    groups = groups + 1
end

-- Non-numeric and zero-required quest objectives retain the ordinary-color path.
for _, objective in ipairs({{Collected = 0, Needed = 0}, {Collected = "?", Needed = 8}, {Needed = 8}}) do
    local expected = library:GetRGBForObjective(objective) .. "- Event: "
        .. tostring(objective.Collected) .. "/" .. tostring(objective.Needed) .. "|r"
    equal(formatter.GetQuestObjectiveText(objective, "Event"), expected, "non-percent fallback")
    groups = groups + 1
end

-- Read settings on each call so changing the profile requires no module reload.
profile.showQuestPercent = false
for _, mode in ipairs({"white", "minimal", "whiteAndGreen", "whiteToGreen", "redToGreen"}) do
    profile.trackerColorObjectives = mode
    for _, collected in ipairs({0, 4, 8}) do
        local objective = {Collected = collected, Needed = 8}
        equal(formatter.GetQuestObjectiveText(objective, "Metal"),
            library:GetRGBForObjective(objective) .. "- Metal: " .. collected .. "/8|r", "current objective palette: " .. mode)
        equal(formatter.GetAchievementLabelText("Criterion", collected == 8),
            library:GetRGBForObjective({Collected = collected == 8 and 1 or 0, Needed = 1}) .. "- Criterion", "achievement completion palette")
    end
    groups = groups + 1
end

profile.trackerColorObjectives = "white"
for _, percent in ipairs({false, true}) do
    profile.showQuestPercent = percent
    profile.showQuestProgressFirst = true -- This setting applies only to quests.
    for _, completed in ipairs({false, true}) do
        equal(formatter.GetAchievementLabelText("Criterion", completed),
            percent and (white .. "- Criterion|r") or "|cFFEEEEEE- Criterion", "single/no-criteria achievement")
        groups = groups + 1
    end
    for _, quantity in ipairs({"4 / 8", "|Tcoin:0|t4 / 8"}) do
        local ending = quantity:find("|") and "|Tcoin:0|t4 /8" or "4/8"
        local full, heading, detail = formatter.GetAchievementProgressText("Achievement", 4, 8, quantity)
        equal(full, percent and (white .. "- Achievement: |r" .. half .. ending .. "|r")
            or ("|cFFEEEEEE- Achievement: " .. ending), "achievement full line")
        equal(heading, percent and (white .. "- Achievement: |r") or "|cFFEEEEEE- Achievement: ", "wrapped heading")
        equal(detail, percent and (white .. "    > |r" .. half .. ending .. "|r")
            or ("|cFFEEEEEE    > " .. ending), "wrapped progress")
        groups = groups + 1
    end
end

profile.showQuestPercent = true
equal(formatter.GetAchievementProgressText("Unknown target", 0, 0, ""),
    white .. "- Unknown target: |r|cFFfe00000/0|r", "zero achievement denominator")
groups = groups + 1

local entries, seenFormatter = 0, false
for line in io.lines("Questie-335.toc") do
    local path = line:gsub("\\", "/")
    if path == "Modules/Tracker/TrackerObjectiveText.lua" then
        entries, seenFormatter = entries + 1, true
    elseif path == "Modules/Tracker/QuestieTracker.lua" then
        equal(seenFormatter, true, "formatter loads before tracker")
    end
end
equal(entries, 1, "formatter registered exactly once")
groups = groups + 1

-- Execute the actual tracker redraw: helper-only tests cannot catch a renderer
-- still calling a helper that became private during an extraction.
do
    local function noop() end
    local methods = {}
    for _, name in ipairs({"ClearAllPoints", "SetPoint", "SetOnClick", "SetZone", "SetObjective", "SetPlayButton", "SetMinResize"}) do
        methods[name] = noop
    end
    function methods:Hide() self.shown = false end
    function methods:Show() self.shown = true end
    function methods:IsShown() return self.shown end
    function methods:SetMode(mode) self.mode = mode end
    function methods:SetQuest(quest) self.quest = quest end
    function methods:SetWidth(width) self.width = width end
    function methods:GetWidth() return self.width or 500 end
    function methods:SetHeight(height) self.height = height end
    function methods:GetHeight() return self.height or 12 end
    function methods:GetStringHeight() return 12 end
    function methods:GetFont() return "font", 12 end
    function methods:GetNumLines() return 1 end
    function methods:SetText(text) self.text = text end
    function methods:GetUnboundedStringWidth()
        return #(self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 6
    end
    local function frame() return setmetatable({}, {__index = methods}) end
    local base, header, questFrame = frame(), frame(), frame()
    header.width = 100
    questFrame.ScrollChildFrame = frame()
    local rows, finished = {}, 0
    local loader = env.QuestieLoader
    local pool = loader:ImportModule("TrackerLinePool")
    pool.ResetLinesForChange = function() rows = {} end
    pool.ResetButtonsForChange, pool.HideAllStatusIcons = noop, noop
    pool.HideUnusedLines, pool.HideUnusedButtons, pool.UpdateWrappedLineWidths = noop, noop, noop
    pool.GetNextLine = function()
        local row = frame()
        for _, name in ipairs({"label", "expandQuest", "expandZone", "criteriaMark", "playButton"}) do row[name] = frame() end
        rows[#rows + 1] = row
        return row
    end
    pool.GetFirstLine = function() return rows[1] end
    pool.GetLastLine = function() return rows[#rows] end
    pool.GetCurrentLine = pool.GetLastLine
    pool.GetHighestIndex = function() return #rows end
    pool.GetLine = function(index) return rows[index] end
    local function visit(mode, callback)
        for _, row in ipairs(rows) do
            if row.mode == mode then callback(row) end
        end
    end
    pool.UpdateObjectiveLines = function(callback) visit("objective", callback) end
    pool.UpdateQuestTitleLines = function(callback) visit("quest", callback) end
    for _, name in ipairs({"TrackerBaseFrame", "TrackerHeaderFrame", "TrackerQuestFrame"}) do
        loader:ImportModule(name).Update = noop
    end
    loader:ImportModule("TrackerQuestTimers").GetRemainingTime = noop
    local utils = loader:ImportModule("TrackerUtils")
    utils.GetCompletionText = noop
    utils.GetUsableQuestItemIds = function() return {} end
    utils.HasQuest = function() return true end
    utils.ShowVoiceOverPlayButtons = noop
    utils.UpdateVoiceOverPlayButtons = function() finished = finished + 1 end
    loader:ImportModule("QuestieCombatQueue").Queue = function(_, callback) callback() end
    loader:ImportModule("QuestLogCache").questLog_DO_NOT_MODIFY = {}
    local quest = {Id = 10055, sourceItemId = 0, SpecialObjectives = {},
        Objectives = {{Index = 1, Collected = 4, Needed = 8, Description = "Salvaged Metal"},
            {Index = 2, Collected = 0, Needed = 8, Description = "Salvaged Wood"}},
        IsComplete = function() return 0 end}
    local title = "|cFFFFFF00[61] Waste Not, Want Not|r"
    local percent = 0.25
    loader:ImportModule("TrackerQuestOrder").GetSortedQuestIds = function()
        return {10055}, {[10055] = {quest = quest, zoneName = "Hellfire Peninsula", questCompletePercent = percent}}
    end
    library.GetColoredQuestName = function() return title end
    env.Questie.Debug = noop
    env.Questie.db.char = {isTrackerExpanded = true, collapsedZones = {}, collapsedQuests = {},
        minAllQuestsInZone = {}, AutoUntrackedQuests = {}}
    profile.trackerEnabled, profile.autoTrackQuests = true, true
    profile.trackerFontSizeQuest, profile.trackerFontSizeZone = 12, 13
    profile.trackerFontSizeObjective = 12
    profile.trackerQuestPadding, profile.trackerWidthRatio = 0, 1
    profile.TrackerWidth, profile.trackerFontSizeHeader = 0, 14
    profile.TrackerHeight, profile.trackerHeightRatio = 0, 1
    profile.trackerHeaderEnabled = true
    profile.showQuestProgressFirst = false
    env.QuestieCompat.C_Timer = {}
    env.LibStub = function() return {} end
    env.GetNumQuestWatches = function() return 1 end
    env.GetTrackedAchievements = noop
    env.GetTime = function() return 10 end
    env.GetScreenWidth = function() return 2000 end
    env.GetScreenHeight = function() return 1000 end
    env.InCombatLockdown = function() return false end
    loadModule("Modules/Tracker/TrackerVisibility.lua", env)
    loadModule("Modules/Tracker/TrackerAchievements.lua", env)
    loadModule("Modules/Tracker/QuestieTracker.lua", env)
    local tracker = loader:ImportModule("QuestieTracker")
    tracker.started = true
    -- Inject native frame stand-ins without replacing the production redraw.
    local function upvalue(method, name, value)
        for index = 1, math.huge do
            local actual = debug.getupvalue(method, index)
            assert(actual, "missing tracker fixture upvalue: " .. name)
            if actual == name then debug.setupvalue(method, index, value); return end
        end
    end
    upvalue(tracker.Update, "trackerBaseFrame", base)
    upvalue(tracker.UpdateWidth, "trackerHeaderFrame", header)
    upvalue(tracker.UpdateWidth, "trackerQuestFrame", questFrame)
    upvalue(tracker.Update, "isFirstRun", false)
    upvalue(tracker.UpdateFormatting, "allowFormattingUpdate", true)
    for _, enabled in ipairs({false, true, false, true}) do
        profile.showQuestPercent = enabled
        tracker:Update(true)
        equal(#rows, 4, "redraw reaches both objectives after the quest title")
        equal(rows[2].label.text, enabled and (title .. " |cFFfe7f00(25%)|r") or title, "percentage toggle redraws quest title")
        equal(rows[3].label.text, enabled and (white .. "- Salvaged Metal: |r" .. half .. "4/8|r")
            or "|cFFEEEEEE- Salvaged Metal: 4/8|r", "percentage toggle redraws objectives")
        assert(base:GetWidth() >= rows[2].label:GetUnboundedStringWidth() + 52, "redraw accounts for complete title width")
    end
    equal(finished, 4, "every toggle finishes rendering and reaches layout")
    for _, width in ipairs({400, 600}) do
        profile.TrackerWidth = width
        loader:ImportModule("TrackerBaseFrame").isSizing = true
        tracker:Update(true)
        equal(base:GetWidth(), width, "percentage-enabled tracker follows manual resize")
        equal(rows[2].label.text, title .. " |cFFfe7f00(25%)|r", "resize preserves title percentage")
        assert(rows[2].label:GetWidth() >= rows[2].label:GetUnboundedStringWidth(), "resized title fits")
    end
    equal(finished, 6, "resizing completes both redraws")

    -- The achievement renderer must consume the controller's synchronized cache.
    local achievements = loader:ImportModule("TrackerAchievements")
    env.Questie.db.char.trackedAchievementIds = {[978] = true}
    env.WatchFrame_Update = noop
    achievements.Initialize()
    setmetatable(loader:ImportModule("l10n"), {__call = function(_, text) return text end})
    env.GetNumTrackedAchievements = function() return 1 end
    env.GetAchievementInfo = function(id)
        if id == 978 then return 978, "3000 Quests Completed", nil, nil, nil, nil, nil, "Complete 3000 quests" end
    end
    env.GetAchievementNumCriteria = function() return 1 end
    env.GetAchievementCriteriaInfo = function()
        return "Quests completed", nil, false, 4, 3000, nil, nil, nil, "4/3000"
    end
    for _, first in ipairs({false, true}) do
        profile.listAchievementsFirst = first
        tracker:Update(true)
        equal(#rows, 7, "redraw includes achievement heading/title/criterion")
        local index = first and 2 or 6
        equal(rows[index].label.text, "|cFFFFFF003000 Quests Completed|r", "achievement title rendered from moved cache")
        assert(rows[index + 1].label.text:find("4/3000", 1, true), "achievement progress rendered")
    end
    equal(finished, 8, "both achievement ordering settings complete layout")

    -- Exercise the production renderer with a database-unknown action whose counter is full.
    quest.NativeOnly, quest.name, quest.level = true, "Custom action quest", 61
    quest.Objectives = {{Index = 1, NativeIndex = 1, NativeOnly = true, HasCounter = true,
        Type = "object", Description = "Activate device", NativeText = "Activate device: 1/1",
        Collected = 1, Needed = 1, Completed = false}}
    profile.trimObjectiveText, profile.showQuestPercent, profile.hideCompletedQuestObjectives = false, false, true
    library.PrintDifficultyColor = function(_, _, name) return name end
    tracker:Update(true)
    local nativeTitle, nativeObjective
    for _, row in ipairs(rows) do
        if row.mode == "quest" and row.label.text:find("Custom action quest", 1, true) then nativeTitle = true end
        if row.mode == "objective" and row.label.text:find("Activate device: 1/1", 1, true) then nativeObjective = true end
    end
    assert(nativeTitle and nativeObjective, "Native title and unfinished full-counter objective survive real rendering")
    groups = groups + 1
end
print("Tracker objective-text regressions passed (" .. groups .. " groups)")
