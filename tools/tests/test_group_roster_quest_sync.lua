-- Run from the Questie addon root with Lua 5.1 or 5.2+.
-- Regression: existing group members request native Questie logs when the party grows.
-- This exercises the production GroupRosterUpdate handler, not a copied implementation.

local function equal(actual, expected, label)
    assert(actual == expected,
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end

local modules = {}
local function getModule(name)
    if not modules[name] then modules[name] = {private = {}} end
    return modules[name]
end

local env = setmetatable({}, {__index = _G})
env._G = env
local groupSize = 0
local requests, visibilitySnapshots, redraws, prunes = 0, 0, 0, 0
local remoteOnline = true

env.QuestieLoader = {
    CreateModule = function(_, name) return getModule(name) end,
    ImportModule = function(_, name) return getModule(name) end,
}
env.Questie = {
    Debug = noop,
    SendMessage = function(_, name)
        equal(name, "QC_ID_REQUEST_FULL_QUESTLIST", "native full quest-log request")
        requests = requests + 1
    end,
}
env.QuestieCompat = {
    C_Timer = {},
    GetNumGroupMembers = function() return groupSize end,
    GetGroupUnitByName = function(name)
        return name == "Remote" and "party1" or nil
    end,
    IsInGroup = function() return groupSize >= 2 end,
    UnitInParty = function() return groupSize >= 2 end,
}
env.UnitIsConnected = function(unit)
    equal(unit, "party1", "remote group member unit")
    return remoteOnline
end
-- Used while compiling localized event-handler patterns at module load time.
env.ERR_QUEST_ACCEPTED_S = "Quest accepted: %s"
env.ERR_QUEST_COMPLETE_S = "Quest complete: %s"

local player = getModule("QuestiePlayer")
player.numberOfGroupMembers = 0
local comms = getModule("QuestieComms")
comms.remoteQuestLogs = {}
getModule("CommsVisibility").PruneRemotePlayers = function() prunes = prunes + 1 end
getModule("CommsVisibility").ScheduleSnapshot = function(_, reason)
    equal(reason, "GROUP_ROSTER_UPDATE", "visibility snapshot reason")
    visibilitySnapshots = visibilitySnapshots + 1
end
getModule("QuestiePartyObjectives").ScheduleUpdate = function() redraws = redraws + 1 end

local path = "Modules/QuestieEventHandler.lua"
local chunk
if setfenv then
    chunk = assert(loadfile(path))
    setfenv(chunk, env)
else
    chunk = assert(loadfile(path, "t", env))
end
chunk()
local groupRosterUpdate = assert(getModule("QuestieEventHandler").private.GroupRosterUpdate)

local function update(newSize, expectedRequests, label)
    groupSize = newSize
    groupRosterUpdate()
    equal(requests, expectedRequests, label)
    equal(player.numberOfGroupMembers, newSize, "group-size cache: " .. label)
end

update(0, 0, "solo roster must not request logs")
update(1, 0, "solo-count compatibility does not request logs")
update(2, 0, "initial party uses GroupJoined, not a duplicate request")
update(3, 1, "2 to 3 members requests new member's quest log")
update(3, 1, "unchanged roster does not request logs")
update(4, 2, "3 to 4 members requests another log refresh")
update(3, 2, "member leaving does not request logs")
update(2, 2, "shrinking to two members does not request logs")
update(3, 3, "rejoining a preexisting party requests logs")
update(3, 3, "duplicate roster event does not request twice")

-- Zone/online-status notifications must not trigger a full quest-log request.
comms.remoteQuestLogs[788] = {Remote = {}}
update(3, 3, "online-state discovery does not request logs")
remoteOnline = false
update(3, 3, "online-to-offline transition does not request logs")
remoteOnline = true
update(3, 3, "offline-to-online transition does not request logs")
assert(prunes >= 13, "roster changes must continue pruning visibility state")
assert(visibilitySnapshots > 0 and redraws > 0, "roster changes must still refresh party objectives")

print("Questie native party roster quest-sync regression tests passed")
