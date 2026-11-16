-- Run from the addon root with Lua 5.1 or 5.2+.
-- Reuse native-style frames and the full line pool, then load the real timer module.
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local source = read("tools/tests/test_tracker_initialization.lua")
local first = assert(source:find('print("Tracker initialization regression tests passed', 1, true))
source = source:sub(1, first - 1) .. [[
local function compile(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env) end
    return assert(load(source, name, "t", env))
end
env.Questie.Colorize = function(_, text) return text end
local remaining, selection = 12, 4
env.QuestieCompat.GetQuestLogIndexByID = function(id) return id == 853 and 2 end
env.GetQuestTimers = function() return remaining end
env.GetQuestLogSelection = function() return selection end
env.SelectQuestLogEntry = function(index) selection = index end
env.GetQuestLogTimeLeft = function(index)
    equal(index, 2, "native timer reads the matching quest")
    return remaining
end
env.SecondsToTime = function(value) return tostring(value) .. " Secs" end
loader:ImportModule("TrackerAchievements").RefreshDragonUI = noop
loadModule("Modules/Tracker/TrackerQuestTimers.lua")
local timers = loader:ImportModule("TrackerQuestTimers")
local row = env.linePool1
local timedQuest = {Id = 853, trackTimedQuest = true}
row:SetQuest(timedQuest)
row.label.activeTimer = true
row:RefreshTimedQuestUpdater()
assert(row:GetScript("OnUpdate"), "active timer owns a row updater")

remaining = 0.5
row:GetScript("OnUpdate")(row, 1.1)
equal(row.label:GetText(), "0.5 Secs", "positive fractional time is not announced as expired")
equal(selection, 4, "timer reads preserve quest-log selection")
remaining = 0
row:GetScript("OnUpdate")(row, 1.1)
equal(row.label:GetText(), "Time's up!", "zero reaches the expiration message")

-- Simulate combat holding the queued tracker refresh: text must clear before it runs.
inCombat = true
remaining = nil
local updatesBefore = trackerUpdates
row:GetScript("OnUpdate")(row, 1.1)
equal(row.label:GetText(), "", "expired text clears without waiting for combat to end")
equal(row.label.activeTimer, false, "expired row retires its timer flag")
equal(row:GetScript("OnUpdate"), nil, "expired row stops polling")
equal(#queued, 1, "expiration still queues the normal tracker refresh")
equal(trackerUpdates, updatesBefore, "queued refresh has not executed")
inCombat = false

-- Resetting/reusing a line must leave its new text alone.
row:SetQuest({Id = 844})
row.label:SetText("Plainstrider Beak: 0/7")
row:OnUpdate(2)
equal(row.label:GetText(), "Plainstrider Beak: 0/7", "reused objective cannot inherit timer text")
equal(row:GetScript("OnUpdate"), nil, "reused ordinary row has no timer updater")

-- The public stored-frame path clears a disappeared timer once, then retires it.
remaining = 12
row:SetQuest(timedQuest)
row.label.activeTimer = true
row:RefreshTimedQuestUpdater()
local textWrites = 0
local setText = row.label.SetText
row.label.SetText = function(self, text)
    textWrites = textWrites + 1
    setText(self, text)
end
timers:GetRemainingTime(timedQuest, row, false)
timers:UpdateTimerFrame()
equal(row.label:GetText(), "12 Secs", "stored frame uses the native timer")
remaining = nil
textWrites = 0
timers:UpdateTimerFrame()
equal(row.label:GetText(), "", "stored timer expiry clears its last text")
timers:UpdateTimerFrame()
equal(textWrites, 1, "retired stored timer cannot clear the row repeatedly")

-- Execute the initial-render decision from the real tracker, not a copied condition.
local file = assert(io.open("Modules/Tracker/QuestieTracker.lua", "r"))
local trackerSource = file:read("*a"):gsub("\r\n", "\n")
file:close()
local render = assert(trackerSource:match("(local timerLabelText%s+local activeTimer = false.-)\n%s*%-%- Only create a timer line"))
env.l10n = l10n
local initial = compile("return function(quest, timeRemaining, timeRemainingString)\n" .. render ..
    "\nreturn timerLabelText, activeTimer end", "@production-initial-timer-render")()
for _, seconds in ipairs({0.5, 1, 2}) do
    local text, active = initial(timedQuest, seconds, tostring(seconds) .. " Secs")
    equal(text, tostring(seconds) .. " Secs", "initial rendering retains positive time")
    equal(active, true, "positive initial timer keeps updating")
end
local text, active = initial(timedQuest, 0, "0 Secs")
equal(text, "Time's up!", "initial zero time is expired")
equal(active, false, "initial expired timer does not start polling")
text = initial({timedBlizzardQuest = true}, 12, "12 Secs")
equal(text, "Blizzard Timer Active!", "native timer rendering remains supported")
print("Tracker timer expiry passed: zero boundary, immediate combat cleanup, row reuse and stored-frame retirement")
]]
if setfenv then setfenv(assert(loadstring(source, "tracker timer expiry regression")), _G)()
else assert(load(source, "tracker timer expiry regression", "t", _G))() end
