-- Run from the Questie addon root with Lua 5.1 or 5.2+.
-- Regressions: native quest-log requests on party growth, real-player cleanup on
-- departure, preservation during disconnects, and restoration on rejoining.
-- Loads the production event handler and the production RemoveRemotePlayer function.

local function equal(actual, expected, label)
    assert(actual == expected,
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end

local modules = {}
local function getModule(name)
    if not modules[name] then modules[name] = { private = {} } end
    return modules[name]
end

local env = setmetatable({}, { __index = _G })
env._G = env
local groupSize = 0
local partyNames = {}
local requests, visibilitySnapshots, redraws, prunes = 0, 0, 0, 0
local remoteOnline = true
local testtwooOnline = true
local removedTooltips = {}
local tooltipOwners = {}

local function setRoster(size, names)
    groupSize = size
    partyNames = names or {}
    if size >= 2 and not names then
        local defaults = { "Remote", "Testtwoo", "Fourth", "Fifth" }
        for i = 1, size - 1 do partyNames[i] = defaults[i] end
    end
end

local function unitName(unit)
    if unit == "player" then return "Owner" end
    local partyIndex = unit:match("^party(%d+)$")
    if partyIndex then return partyNames[tonumber(partyIndex)] end
    return nil
end

env.UnitName = unitName
env.GetNumPartyMembers = function() return groupSize >= 2 and groupSize - 1 or 0 end
env.GetNumRaidMembers = function() return 0 end
env.UnitIsConnected = function(unit)
    if unit == "party1" then return remoteOnline end
    if unit == "party2" then return testtwooOnline end
    return true
end

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
        if name == "Owner" then return "player" end
        for i, member in ipairs(partyNames) do
            if member == name then return "party" .. i end
        end
        return nil
    end,
    IsInGroup = function() return groupSize >= 2 end,
    IsInRaid = function() return false end,
    UnitInParty = function() return groupSize >= 2 end,
}
-- Required when compiling the event handler's localized patterns.
env.ERR_QUEST_ACCEPTED_S = "Quest accepted: %s"
env.ERR_QUEST_COMPLETE_S = "Quest complete: %s"

local player = getModule("QuestiePlayer")
player.numberOfGroupMembers = 0
local comms = getModule("QuestieComms")
comms.remoteQuestLogs = {}
comms.remotePlayerTimes = {}
comms.remotePlayerEnabled = {}
comms.remotePlayerClasses = {}
comms.data = {
    RemovePlayer = function(_, name)
        removedTooltips[name] = (removedTooltips[name] or 0) + 1
        tooltipOwners[name] = nil
    end,
}
comms.CheckInGroup = function(_, name)
    return env.QuestieCompat.GetGroupUnitByName(name) ~= nil
end
comms.ResetAll = function(self)
    self.remoteQuestLogs = {}
    tooltipOwners = {}
end

env.QuestieComms = comms
local partyObjectives = getModule("QuestiePartyObjectives")
env.QuestiePartyObjectives = partyObjectives
partyObjectives.ScheduleUpdate = function() redraws = redraws + 1 end
partyObjectives.Clear = noop
local visibility = getModule("CommsVisibility")
visibility.PruneRemotePlayers = function() prunes = prunes + 1 end
visibility.ScheduleSnapshot = function(_, reason)
    equal(reason, "GROUP_ROSTER_UPDATE", "visibility snapshot reason")
    visibilitySnapshots = visibilitySnapshots + 1
end
visibility.ResetAll = noop
getModule("DailyQuestComms").CancelPendingUnavailableQuestGroupResponses = noop

local function loadProduction(path)
    local chunk
    if setfenv then
        chunk = assert(loadfile(path))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(path, "t", env))
    end
    chunk()
end

-- Load the real cleanup function without executing the entire comms module,
-- which otherwise requires the WoW addon runtime and serializer libraries.
local function loadProductionRemoteCleanup()
    local f = assert(io.open("Modules/Network/QuestieComms.lua", "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    local code = assert(source:match(
        "(function QuestieComms:RemoveRemotePlayer%(name%).-)\nfunction QuestieComms:SortRemotePlayers"),
        "Could not locate production QuestieComms:RemoveRemotePlayer")
    local chunk
    if setfenv then
        chunk = assert(loadstring(code, "QuestieComms.RemoveRemotePlayer"))
        setfenv(chunk, env)
    else
        chunk = assert(load(code, "QuestieComms.RemoveRemotePlayer", "t", env))
    end
    chunk()
end

loadProductionRemoteCleanup()
loadProduction("Modules/QuestieEventHandler.lua")
local handler = getModule("QuestieEventHandler").private
local groupRosterUpdate = assert(handler.GroupRosterUpdate)

local function update(size, expectedRequests, label, names)
    setRoster(size, names)
    groupRosterUpdate()
    equal(requests, expectedRequests, label)
    equal(player.numberOfGroupMembers, size, "group-size cache: " .. label)
end

-- Original party growth and no-duplicate-request regressions.
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

-- Zone notifications and connection changes must not request a full quest log.
comms.remoteQuestLogs[788] = { Remote = {} }
update(3, 3, "online-state discovery does not request logs")
remoteOnline = false
update(3, 3, "online-to-offline does not request logs")
remoteOnline = true
update(3, 3, "offline-to-online does not request logs")

-- A disconnected player who is still in the party retains their data.
comms.remoteQuestLogs[788] = { Remote = { fulfilled = 1 }, Testtwoo = { fulfilled = 2 } }
comms.remoteQuestLogs[789] = { Testtwoo = { fulfilled = 1 } }
comms.remotePlayerTimes.Testtwoo = 123
comms.remotePlayerEnabled.Testtwoo = true
comms.remotePlayerClasses.Testtwoo = "WARRIOR"
tooltipOwners.Testtwoo = true
local removedBefore = removedTooltips.Testtwoo or 0

testtwooOnline = false
update(3, 3, "disconnect while grouped does not request logs")
assert(comms.remoteQuestLogs[788].Testtwoo, "disconnect discarded group member's quest")
assert(tooltipOwners.Testtwoo, "disconnect discarded group member's tooltip")
equal(removedTooltips.Testtwoo or 0, removedBefore,
    "disconnect must not call RemovePlayer")
testtwooOnline = true
update(3, 3, "reconnect while grouped does not request logs")

-- Leaving removes cached quests, tooltip registrations and stale metadata.
update(2, 3, "departed member does not cause full-sync request")
equal(removedTooltips.Testtwoo, removedBefore + 1, "departure clears tooltip")
assert(not tooltipOwners.Testtwoo, "departure retained registered tooltip")
assert(comms.remoteQuestLogs[788] and comms.remoteQuestLogs[788].Remote,
    "departure removed remaining member's quest")
assert(not comms.remoteQuestLogs[788].Testtwoo,
    "departure retained stale quest objective")
assert(not comms.remoteQuestLogs[789], "departure retained empty quest cache")
assert(not comms.remotePlayerTimes.Testtwoo and
    not comms.remotePlayerEnabled.Testtwoo and
    not comms.remotePlayerClasses.Testtwoo, "departure retained metadata")
update(2, 3, "duplicate departure event does not request logs")
equal(removedTooltips.Testtwoo, removedBefore + 1,
    "duplicate roster event must not repeatedly clean player")

-- Rejoining requests new data and must not inherit a previous snapshot.
update(3, 4, "rejoining requests a fresh quest log")
assert(not comms.remoteQuestLogs[788].Testtwoo,
    "rejoining reused stale data before a response")
comms.remoteQuestLogs[788].Testtwoo = { fulfilled = 3 } -- Simulate native response.
tooltipOwners.Testtwoo = true
update(3, 4, "unchanged rejoined roster does not request twice")
assert(comms.remoteQuestLogs[788].Testtwoo and tooltipOwners.Testtwoo,
    "rejoining lost newly received quest data")

-- Even with unchanged group size, replacing Testtwoo must discard Testtwoo.
update(3, 4, "same-size member replacement", { "Remote", "Replacement" })
assert(not comms.remoteQuestLogs[788].Testtwoo,
    "same-size replacement retained departed member")
assert(comms.remoteQuestLogs[788].Remote,
    "same-size replacement removed a remaining member")
assert(not tooltipOwners.Testtwoo,
    "same-size replacement retained departed tooltip")

-- Full group departure resets the roster baseline for a fresh group.
setRoster(0)
assert(handler.GroupLeft, "GroupLeft handler unavailable")
handler:GroupLeft()
update(2, 4, "new group after GroupLeft does not request twice")
assert(prunes > 0 and visibilitySnapshots > 0 and redraws > 0,
    "roster changes must continue updating visibility and objectives")

print("Questie native party roster join/depart/rejoin regression tests passed")
