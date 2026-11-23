-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise native tracker ownership through the real timer, startup and migration modules.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end, FinishLoadTimings = noop}
local function loadModule(path)
    if setfenv then return setfenv(assert(loadfile(path)), env)() end
    return assert(loadfile(path, "t", env))()
end
local profile = {trackerEnabled = true, showBlizzardQuestTimer = true, migrationVersion = 32,
    trackerFontSizeQuest = 12, trackerFontSizeObjective = 10, trackerFontOutline = "OUTLINE",
    trackerFontObjective = "Font", trackerShowCompleteQuests = false}
env.Questie = {db = {profile = profile, char = {isTrackerExpanded = true}}, Debug = noop,
    Error = error, Colorize = function(_, text) return text end}
local watch = {shown = false, scripts = {}}
function watch:HookScript(event, callback) self.scripts[event] = callback end
function watch:Show()
    if not self.shown then
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
end
function watch:Hide() self.shown = false end
env.WatchFrame = watch
env.LibStub = function() return {Fetch = function() return "Font" end} end
local selection, remaining = 5, 20
env.QuestieCompat = {GetQuestLogIndexByID = function(id) return id == 853 and 2 end}
env.GetQuestTimers = function() return remaining end
env.GetQuestLogSelection = function() return selection end
env.SelectQuestLogEntry = function(index) selection = index end
env.GetQuestLogTimeLeft = function(index) equal(index, 2, "native timer quest"); return remaining end
env.SecondsToTime = function(seconds) return tostring(seconds) .. " Secs" end
local dragonRefreshes = 0
module("TrackerAchievements").RefreshDragonUI = function() dragonRefreshes = dragonRefreshes + 1 end
loadModule("Modules/Tracker/TrackerQuestTimers.lua")
local timers, tracker = module("TrackerQuestTimers"), module("QuestieTracker")
timers:Initialize()
watch:Show()
equal(watch.shown, false, "active Questie tracker suppresses the native frame despite obsolete saved preference")
assert(dragonRefreshes > 0, "native-frame suppression refreshes DragonUI")
tracker.disableHooks = true
watch:Show()
equal(watch.shown, true, "unhooking allows the native frame to remain shown")
watch:Hide()
tracker.disableHooks, profile.trackerEnabled = nil, false
watch:Show()
equal(watch.shown, true, "disabled Questie tracker does not re-hide the native frame")
profile.trackerEnabled = true
watch:Hide()
watch:Show()
equal(watch.shown, false, "reactivated Questie tracker suppresses native timers again")

local quest = {Id = 853}
local text, seconds = timers:GetRemainingTime(quest, nil, true)
equal(text, "20 Secs", "timer text remains available")
equal(seconds, 20, "timer duration remains available")
equal(quest.trackTimedQuest, true, "timed quest always uses the Questie countdown")
equal(quest.timedBlizzardQuest, nil, "removed native timer flag is not recreated")
equal(selection, 5, "timer read preserves selected quest-log entry")
remaining = nil
timers:GetRemainingTime(quest, nil, true)
equal(quest.trackTimedQuest, false, "expired quest stops being marked timed")
equal(timers.ShowBlizzardTimer, nil, "obsolete timer-show method is removed")

-- An obsolete true value cannot restore the native watch frame at addon startup.
env.bit = {band = noop}
module("QuestieValidateGameCache").StartCheck = noop
module("QuestieLib").AddonPath = "Interface/AddOns/Questie-335/"
loadModule("Questie.lua")
watch.shown = true
env.Questie:OnEnable()
equal(watch.shown, false, "startup ignores obsolete true timer preference")
profile.trackerEnabled = false
watch.shown = true
env.Questie:OnEnable()
equal(watch.shown, true, "startup preserves native tracker when Questie tracker is disabled")

-- Timer cleanup preserves unrelated preferences when upgrading an existing profile.
env.table = setmetatable({getn = function(value) return #value end}, {__index = table})
loadModule("Modules/Migration.lua")
module("Migration"):Migrate()
equal(profile.migrationVersion, 35, "profile migrations complete")
equal(profile.showBlizzardQuestTimer, nil, "migration removes obsolete saved preference")
equal(profile.trackerShowCompleteQuests, false, "migration preserves unrelated tracker preference")
profile.trackerShowCompleteQuests = true
module("Migration"):Migrate()
equal(profile.trackerShowCompleteQuests, true, "already migrated profile retains subsequent preferences")

-- Announcement migration runs once per profile and preserves later user choices.
for _, channel in ipairs({"party", "raid", "both", "disabled", false}) do
    local migrated = {migrationVersion = 33, questAnnounceChannel = channel or nil, trimObjectiveText = true,
        questAnnounceLocally = true, questAnnounceItems = true, questieShutUp = false}
    env.Questie.db.profile = migrated
    module("Migration"):Migrate()
    equal(migrated.questAnnounceChannel, "disabled", "migration disables every previous channel")
    equal(migrated.migrationVersion, 35, "profile migrations record completion")
    equal(migrated.trimObjectiveText, nil, "migration removes the retired objective wording setting")
    equal(migrated.questAnnounceLocally, true, "local announcement preference preserved")
    equal(migrated.questAnnounceItems, true, "starter-item preference preserved")
    equal(migrated.questieShutUp, false, "master silence preference preserved")
    migrated.questAnnounceChannel = "party"
    module("Migration"):Migrate()
    equal(migrated.questAnnounceChannel, "party", "manual re-enabling survives repeated migration")
end
print("Tracker timer policy passed: native ownership, legacy settings, startup, Questie countdowns and migration")
