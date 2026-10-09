-- Run with Lua 5.2+. Exercise production level/repeatability checks and availability caching.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env.bit, env.time, env.date = bit32, os.time, os.date
env.UnitFactionGroup = function() return "Alliance" end
env.GetQuestGreenRange = function() return 5 end
env.GetRealmName = function() return "Test realm" end
env.QUEST_MONSTERS_KILLED, env.QUEST_ITEMS_NEEDED, env.QUEST_OBJECTS_FOUND = "monster", "item", "object"
env.Questie = {LOWLEVEL_RANGE = "range", LOWLEVEL_OFFSET = "offset", LOWLEVEL_ALL = "all",
    db = {profile = {lowLevelStyle = "default", showAQWarEffortQuests = true,
        showScourgeInvasionQuests = true, showSunsReachQuests = true}, global = {}, char = {complete = {}, hidden = {}}},
    Debug = noop, Error = error}
env.QuestieCompat = {Is335 = true, addonName = "Questie-335", C_QuestLog = {IsOnQuest = function() return false end},
    GetQuestResetTime = function() return 3600 end,
    GetServerTime = function() return 1791302400, {year = 2026, month = 10, day = 6, hour = 12, weekday = 3} end,
    GetQuestLogQuestIds = function() return {} end}
local modules, jobs, drawn, data = {}, {}, {}, {}
local playerLevel, showRepeatable = 80, true
local levelCalls, repeatableCalls, wrapperCalls = 0, 0, 0
local levelCallsByQuest = {}
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
}
modules.ZoneDB = {zoneIDs = {ICECROWN = 210}, GetDungeons = function() return {} end}
modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return playerLevel end}
modules.QuestieServer = {GetStateControlledQuests = function() end}
modules.QuestieCorrections = {hiddenQuests = {}}
modules.QuestieEvent = {activeQuests = {}}
modules.IsleOfQuelDanas = {GetHiddenQuests = function() return {} end}
modules.QuestieQuestBlacklist = {AQWarEffortQuests = {}, ScourgeInvasionQuests = {}, SunsReachQuests = {}}
modules.QuestieIconVisibility = {IsEnabledAnywhere = function(_, kind) return kind ~= "repeatable" or showRepeatable end}
modules.QuestieTooltips = {RemoveAvailableQuest = noop}
modules.QuestieMap = {ForQuestFrames = function(_, id) return drawn[id] end,
    UnloadQuestFrames = function(_, id) drawn[id] = nil end}
modules.ThreadLib = {Thread = function(fn, _, _, callback)
    jobs[#jobs + 1] = {thread = coroutine.create(fn), callback = callback}
    return {}
end}
assert(loadfile("Database/QuestieDB.lua", "t", env))()
assert(loadfile("Modules/Libs/QuestieLib.lua", "t", env))()
local db = modules.QuestieDB
db.questData = {}
db.QueryQuestSingle = function(id, field) return data[id] and data[id][field] end
db.GetQuest = function(id) return {Id = id, Starts = {}, tagInfoWasCached = true} end
db.IsDoable = function() return true end
db.IsComplete = function() return 0 end
db.SetUnavailableQuestChecker = noop
local realLevel, realRepeatable = db.IsLevelRequirementsFulfilled, db.IsRepeatable
db.IsLevelRequirementsFulfilled = function(id, ...)
    levelCalls = levelCalls + 1
    levelCallsByQuest[id] = (levelCallsByQuest[id] or 0) + 1
    return realLevel(id, ...)
end
db.IsRepeatable = function(id)
    repeatableCalls = repeatableCalls + 1
    return realRepeatable(id)
end
assert(loadfile("Modules/Quest/AvailableQuests.lua", "t", env))()
local available = modules.AvailableQuests
available.DrawAvailableQuest = function(quest) drawn[quest.Id] = true end
local levelLookup = available.IsLevelRequirementsFulfilled
available.IsLevelRequirementsFulfilled = function(...)
    wrapperCalls = wrapperCalls + 1
    return levelLookup(...)
end
local function add(id, level, flags, required, maximum, parent)
    db.questData[id] = true
    data[id] = {questLevel = level, specialFlags = flags, requiredLevel = required or 1,
        requiredMaxLevel = maximum or 0, parentQuest = parent}
end
local function finish(job)
    while coroutine.status(job.thread) ~= "dead" do
        local ok, message = coroutine.resume(job.thread)
        assert(ok, message)
    end
    job.callback(true)
end
local function calculate()
    available.CalculateAndDrawAll(nil, true)
    finish(table.remove(jobs, 1))
end
add(1, 80, 0, 1, 0, 0)
add(2, 10, 0)
add(3, 10, 1)
add(4, 10, 1, 1, 79)
add(5, 90, 0, 90)
add(6, -1, 0)
add(7, 80, 0)
add(8, 80, 0)
add(9, 80, 0)
add(10, 80, 0)
add(11, 80, 0)
env.Questie.db.char.complete[7] = true
env.Questie.db.char.hidden[8] = true
modules.QuestieCorrections.hiddenQuests[9] = true
db.autoBlacklist[10] = "race"
modules.QuestiePlayer.currentQuestlog[11] = {}
calculate()
for id, expected in ipairs({true, false, true, false, false, true, false, false, false, false, false}) do
    equal(drawn[id] == true, expected, "initial availability " .. id)
end
equal(repeatableCalls, 6, "cheap exclusions avoid flag checks")
local previousLevelCalls, previousRepeatableCalls = levelCalls, repeatableCalls
wrapperCalls = 0
calculate()
equal(levelCalls, previousLevelCalls, "warm scan reuses true and false level decisions")
equal(repeatableCalls, previousRepeatableCalls, "warm scan reuses true and false repeatability flags")
equal(wrapperCalls, 0, "warm scan avoids per-quest level wrapper calls")

-- Reusing flags must not freeze settings, completion, hiding or absolute level ranges.
showRepeatable = false
calculate()
equal(drawn[3], nil, "repeatable visibility toggles off")
showRepeatable = true
calculate()
equal(drawn[3], true, "repeatable visibility toggles back on")
env.Questie.db.char.complete[3] = true
calculate()
equal(drawn[3], nil, "completion remains live with cached repeatability")
env.Questie.db.char.complete[3] = nil
env.Questie.db.char.hidden[3] = true
calculate()
equal(drawn[3], nil, "manual hiding remains live")
env.Questie.db.char.hidden[3] = nil
env.Questie.db.profile.lowLevelStyle = "range"
env.Questie.db.profile.minLevelFilter, env.Questie.db.profile.maxLevelFilter = 75, 80
calculate()
equal(drawn[3], nil, "absolute range suppresses trivial repeatable exception")
env.Questie.db.profile.lowLevelStyle = "all"
calculate()
equal(drawn[2], true, "style changes do not reuse a different style's result")
env.Questie.db.profile.lowLevelStyle = "offset"
env.Questie.db.profile.manualLevelOffset = 75
calculate()
equal(drawn[2], true, "manual offset uses its own level bounds")
env.Questie.db.profile.lowLevelStyle = "default"
playerLevel = 90
calculate()
equal(drawn[5], true, "new player level selects a new cache")
playerLevel = 79
equal(available.IsLevelRequirementsFulfilled(4, 1, 90), true, "implicit player level permits quest below required maximum")
playerLevel = 80
equal(available.IsLevelRequirementsFulfilled(4, 1, 90), false, "implicit player level is part of cache context")

-- Unknown flag data may become available later; do not cache nil as non-repeatable.
add(12, 10, nil)
calculate()
equal(drawn[12], nil, "unknown flags use ordinary level filtering")
data[12].specialFlags = 1
calculate()
equal(drawn[12], true, "newly available repeatable flags are reread")

-- Parent-log and event overrides must follow live state without a manual reset.
add(13, 10, 0, 1, 0, 10000)
add(14, 10, 0)
calculate()
equal(drawn[13], nil, "inactive parent does not bypass level filtering")
equal(drawn[14], nil, "inactive event does not bypass level filtering")
modules.QuestiePlayer.currentQuestlog[10000] = {}
modules.QuestieEvent.activeQuests[14] = true
calculate()
equal(drawn[13], true, "accepted parent enables child despite old false result")
equal(drawn[14], true, "active event bypasses cached false level result")
modules.QuestiePlayer.currentQuestlog[10000] = nil
modules.QuestieEvent.activeQuests[14] = nil
calculate()
equal(drawn[13], nil, "abandoned parent restores level filter")
equal(drawn[14], nil, "ended event restores level filter")

-- A suspended warm scan must switch to the replacement cache after a reset.
for id = 100, 700 do add(id, 80, 0) end
calculate()
available.CalculateAndDrawAll(nil, true)
local job = table.remove(jobs, 1)
local ok, message = coroutine.resume(job.thread)
assert(ok, message)
assert(coroutine.status(job.thread) ~= "dead", "large warm scan yields")
for id = 100, 700 do data[id].requiredLevel = 90 end
available.ResetLevelRequirementCache()
local previousCallsByQuest = {}
for id = 100, 700 do previousCallsByQuest[id] = levelCallsByQuest[id] end
finish(job)
local rereadAfterReset = false
for id = 100, 700 do
    if levelCallsByQuest[id] > previousCallsByQuest[id] then rereadAfterReset = true end
end
assert(rereadAfterReset, "resumed scan honors reset instead of reading the old cache")
calculate()
for id = 100, 700 do equal(drawn[id], nil, "new refresh respects reset level requirements " .. id) end
print("Available quest filters: warm caches, exclusions, settings, levels, live parent/event overrides, unknown flags and suspended resets passed")
