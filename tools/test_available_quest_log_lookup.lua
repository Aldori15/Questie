-- Run with Lua 5.2+. Exercise the client-log snapshot and real availability job.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local env = setmetatable({}, {__index = _G})
local modules, rows, titleCalls, jobs = {}, {}, 0, {}
local function noop() end
env.bit, env.time, env.date = bit32, os.time, os.date
env.ERR_QUEST_COMPLETE_S, env.DAILY_QUESTS_REMAINING = "%s completed.", "%d dailies remaining"
env.UnitFactionGroup = function() return "Alliance" end
env.UnitName = function() return "Tester" end
env.GetRealmName = function() return "Test realm" end
env.GetQuestGreenRange = function() return 100 end
env.GetQuestLogTitle = function(index)
    titleCalls = titleCalls + 1
    local row = rows[index]
    if row then return "Entry " .. index, 80, nil, 0, row.header, false, 0, false, row.id end
end
env.Questie = {db = {profile = {lowLevelStyle = "default", showAQWarEffortQuests = true,
    showScourgeInvasionQuests = true, showSunsReachQuests = true}, global = {},
    char = {complete = {}, hidden = {}}}, Debug = noop, Error = error}
env.QuestieCompat = {Is335 = true}
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
}
modules.QuestiePlayer = {currentQuestlog = {}, GetPlayerLevel = function() return 80 end}
assert(loadfile("Compat/QuestLog.lua", "t", env))()
local compat = env.QuestieCompat
compat.GetQuestResetTime = function() return 3600 end
compat.GetServerTime = function() return 1791302400, {year = 2026, month = 10, day = 6, hour = 12, weekday = 3} end

-- Membership matches the existing client lookup, including misses and headers.
rows = {{header = true, id = 999}, {id = 10}, {id = 20}}
local snapshot = compat.GetQuestLogQuestIds()
equal(titleCalls, 4, "snapshot reads the log once")
for _, id in ipairs({10, 20, 999, 12345}) do
    equal(snapshot[id] == true, compat.C_QuestLog.IsOnQuest(id), "live membership parity " .. id)
end
rows = {}
equal(next(compat.GetQuestLogQuestIds()), nil, "empty log")
rows = {}
for index = 1, 76 do rows[index] = {id = index} end
snapshot = compat.GetQuestLogQuestIds()
equal(snapshot[75], true, "last supported log entry")
equal(snapshot[76], nil, "same 75-entry bound as live lookup")

modules.ZoneDB = {zoneIDs = {ICECROWN = 210}, GetDungeons = function() return {} end}
modules.QuestieServer = {GetQuestAvailabilityState = function() return nil end,
    GetStateControlledQuests = function() return nil end}
modules.QuestieCorrections = {hiddenQuests = {}}
modules.QuestieEvent = {IsEventQuestInCurrentExpansion = function() return false end}
modules.DailyQuests = {ShouldBeHidden = function() return false end, IsAtDailyQuestLimit = function() return false end}
modules.IsleOfQuelDanas = {GetHiddenQuests = function() return {} end}
modules.QuestieQuestBlacklist = {AQWarEffortQuests = {}, ScourgeInvasionQuests = {}, SunsReachQuests = {}}
modules.QuestieIconVisibility = {IsEnabledAnywhere = function() return true end}
modules.QuestieTooltips = {RemoveAvailableQuest = noop}
modules.QuestieMap = {ForQuestFrames = function() return true end, UnloadQuestFrames = noop}
modules.ThreadLib = {Thread = function(fn, _, _, callback)
    jobs[#jobs + 1] = {thread = coroutine.create(fn), callback = callback}
    return {}
end}
assert(loadfile("Database/QuestieDB.lua", "t", env))()
local db = modules.QuestieDB
-- Initialize only the character caches normally assigned during DB initialization.
for index = 1, 100 do
    local name = debug.getupvalue(db.IsDoable, index)
    if not name then break end
    if name == "QuestieCorrectionshiddenQuests" then debug.setupvalue(db.IsDoable, index, modules.QuestieCorrections.hiddenQuests) end
    if name == "Questiedbcharhidden" then debug.setupvalue(db.IsDoable, index, env.Questie.db.char.hidden) end
end
db.QueryQuestSingle = function() end
db.IsDailyQuest, db.IsWeeklyQuest, db.IsMonthlyQuest = function() return false end, function() return false end, function() return false end
db.IsRepeatable, db.IsPvPQuest, db.IsDungeonQuest, db.IsRaidQuest = function() return false end, function() return false end,
    function() return false end, function() return false end
db.IsLevelRequirementsFulfilled = function() return true end
db.IsComplete = function() return -1 end
db.IsAzerothCoreAvailabilityConditionFulfilled = function() return true end
db.private.CheckAchievementRequirements = function() return true end
db.GetQuest = function(id) return {Id = id, Starts = {}, tagInfoWasCached = true} end
db.GetQuestTagInfo = noop

-- Snapshot hits/misses bypass live searches; ordinary callers remain live.
rows = {{id = 10}}
snapshot = compat.GetQuestLogQuestIds()
modules.QuestieServer.GetQuestAvailabilityState = function() return false end
local before = titleCalls
equal(db.IsDoable(10, false, true, snapshot), true, "on-quest override retained")
equal(db.IsDoable(20, false, true, snapshot), false, "snapshot miss retains server gate")
equal(titleCalls, before, "both snapshot hits and misses avoid client reads")
equal(db.IsDoable(10), true, "default caller uses live lookup")
rows = {{id = 20}}
equal(db.IsDoable(10), false, "default caller sees removed quest immediately")
equal(db.IsDoable(20), true, "default caller sees accepted quest immediately")
snapshot = compat.GetQuestLogQuestIds()
env.Questie.db.char.complete[20] = true
equal(db.IsDoable(20, false, true, snapshot), false, "completion still precedes membership")
env.Questie.db.char.complete[20] = nil
env.Questie.db.char.hidden[20] = true
equal(db.IsDoable(20, false, true, snapshot), false, "manual hide still precedes membership")
env.Questie.db.char.hidden[20] = nil
modules.QuestieServer.GetQuestAvailabilityState = function() return nil end

assert(loadfile("Modules/Quest/AvailableQuests.lua", "t", env))()
local available = modules.AvailableQuests
available.DrawAvailableQuest = noop
db.questData = {}
for id = 1, 1030 do db.questData[id] = true end
-- Use a full client log plus headers to make repeated misses expensive.
rows = {{header = true}}
for id = 10001, 10025 do rows[#rows + 1] = {id = id} end
local originalIsDoable, observed, snapshots = db.IsDoable, 0, {}
db.IsDoable = function(id, debugPrint, ignoreLocations, ids)
    observed = observed + 1
    assert(ids, "availability must pass a client snapshot")
    snapshots[#snapshots + 1] = ids
    return originalIsDoable(id, debugPrint, ignoreLocations, ids)
end
titleCalls = 0
available.CalculateAndDrawAll(nil, true)
local job = table.remove(jobs, 1)
local ok, message = coroutine.resume(job.thread)
assert(ok, message)
local firstBatch = observed
assert(firstBatch > 1 and firstBatch < 1030, "fast refresh must split candidates into batches")
equal(titleCalls, 27, "one client scan for the entire first batch")
for index = 2, firstBatch do equal(snapshots[index], snapshots[1], "shared snapshot within batch") end

-- Accept/remove and header reordering between resumes must not reuse old membership.
rows = {{id = 20000}, {header = true}}
ok, message = coroutine.resume(job.thread)
assert(ok, message)
equal(observed, math.min(firstBatch * 2, 1030), "second fast batch")
equal(titleCalls, 30, "next resume rereads the changed client log")
assert(snapshots[firstBatch + 1] ~= snapshots[1], "fresh snapshot after yield")
equal(snapshots[firstBatch + 1][10001], nil, "removed quest absent after yield")
equal(snapshots[firstBatch + 1][20000], true, "accepted quest present after yield")
while coroutine.status(job.thread) ~= "dead" do
    ok, message = coroutine.resume(job.thread)
    assert(ok, message)
end
job.callback(true)
equal(observed, 1030, "all candidates checked")
local snapshotCount, previousSnapshot = 0, nil
for _, ids in ipairs(snapshots) do
    if ids ~= previousSnapshot then snapshotCount = snapshotCount + 1; previousSnapshot = ids end
end
equal(titleCalls, 27 + (snapshotCount - 1) * 3, "one scan per batch")
assert(snapshotCount < observed / 10, "client scans reduced by at least 90 percent")

-- A new refresh with every quest outside the level filter does no membership work.
available.ResetLevelRequirementCache()
db.IsLevelRequirementsFulfilled = function() return false end
titleCalls = 0
available.CalculateAndDrawAll(nil, true)
job = table.remove(jobs, 1)
repeat
    ok, message = coroutine.resume(job.thread)
    assert(ok, message)
until coroutine.status(job.thread) == "dead"
job.callback(true)
equal(titleCalls, 0, "filtered batches skip client snapshots")
print("Available quest lookup: membership parity, live fallback, yield freshness and scan reduction passed")
