-- Run from the addon root with Lua 5.1 or 5.2+.
-- Real comms decoders and tooltip registrations must agree after group departure.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local function fixture()
    local f = {members = {["Friend-Realm"] = "party1"}, decoded = 0, redraws = 0}
    local modules = {}
    local function module(name) modules[name] = modules[name] or {private = {}}; return modules[name] end
    local env = setmetatable({}, {__index = _G})
    env._G, env.floor, env.tinsert, env.tremove = env, math.floor, table.insert, table.remove
    env.UnitName = function() return "Owner" end
    env.Questie = {Debug = noop, Error = function(message) error(message) end,
        db = {profile = {debugEnabled = true}}}
    env.QuestieCompat = {HBD = {}, C_Timer = {},
        GetGroupUnitByName = function(name) return f.members[name] end}
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    module("QuestieSerializer").Deserialize = function(_, _, encoding)
        equal(encoding, "b89", "ordinary comms retain Wrath encoding")
        f.decoded = f.decoded + 1
        return f.packet
    end
    module("QuestiePartyObjectives").ScheduleUpdate = function() f.redraws = f.redraws + 1 end
    module("QuestiePlayer").currentQuestlog = {}
    module("QuestieDB").GetQuest = function() end
    module("QuestieDB").GetNPC = function() return {name = "Objective target"} end
    module("QuestieLib").Count = function(_, values)
        local count = 0
        for _ in pairs(values) do count = count + 1 end
        return count
    end
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/Network/QuestieComms.lua")
    loadModule("Modules/Network/QuestieCommsData.lua")
    f.comms, f.private, f.env = module("QuestieComms"), module("QuestieComms").private, env
    function f:receive(distribution, name, packet)
        self.packet = packet
        self.private.OnCommReceived_unsafe(self.private, "payload", distribution, name or "Friend-Realm")
    end
    return f
end
local function groupPacket(id, target)
    return {id = id or 844, objectives = {{id = target or 123, typ = "m", fin = false, ful = 1, req = 7}}}
end
local function v2Packet(id, target)
    return {id or 844, 1, target or 123, string.byte("m"), 1, 7}
end

-- Late group transports are rejected before decoding; unrelated transports retain their behavior.
do
    local f = fixture()
    f.members["Friend-Realm"] = nil
    for _, distribution in ipairs({"PARTY", "RAID", "WHISPER", "INSTANCE_CHAT"}) do
        f:receive(distribution)
    end
    equal(f.decoded, 0, "departed senders must not reach deserialization")
    local legacyPacket = {msgId = 13, [1] = {844, 1, 8, 456, string.byte("m"), 2, 7}}
    f:receive("YELL", "Nearby", legacyPacket)
    equal(f.decoded, 0, "legacy YELL is ignored before deserialization")
    equal(next(f.comms.remoteQuestLogs), nil, "legacy YELL cannot create a quest snapshot")
    equal(f.comms.data:KeyExists("m_456"), nil, "legacy YELL cannot register tooltip data")
    for _, distribution in ipairs({"GUILD", "CHANNEL"}) do f:receive(distribution) end
    equal(f.decoded, 2, "other non-group transports still decode")
    f.members["Friend-Realm"] = "raid2"
    for _, distribution in ipairs({"PARTY", "RAID", "WHISPER", "INSTANCE_CHAT"}) do f:receive(distribution) end
    equal(f.decoded, 6, "current member transports still decode")
    f:receive("YELL", "Friend-Realm", legacyPacket)
    equal(f.decoded, 6, "YELL from a group member is ignored too")
end

-- Retired packet IDs are ignored, even when the sender is still grouped.
do
    local f = fixture()
    assert(not f.private.packets[10] and not f.private.packets[14], "retired handlers are removed")
    f:receive("WHISPER", nil, {msgId = 10, msgVer = 5, rawQuestList = {groupPacket()}})
    f:receive("PARTY", nil, {msgId = 14, msgVer = 5, [1] = v2Packet()})
    equal(next(f.comms.remoteQuestLogs), nil, "retired packets cannot create a quest snapshot")
    equal(f.redraws, 0, "retired packets do not schedule redraws")
end

-- Incremental and full-log records reject stale senders, and full-log blocks accumulate.
do
    local f = fixture()
    f.members["Friend-Realm"] = nil
    f.comms:InsertQuestDataPacket(groupPacket(), "Friend-Realm")
    local offset = f.comms:InsertFullQuestLogEntry(v2Packet(), "Friend-Realm", 1, false)
    equal(offset, 7, "rejected V2 record still consumes its complete block")
    equal(next(f.comms.remoteQuestLogs), nil, "late group decoders cannot restore a departed member")
    equal(f.comms.data:KeyExists("m_123"), nil, "late insertion cannot register tooltip data")
    f.members["Friend-Realm"] = "party1"
    f:receive("WHISPER", nil, {msgId = 12, msgVer = 5, [1] = {1, 844, 1, 123, string.byte("m"), 1, 7}})
    f:receive("WHISPER", nil, {msgId = 12, msgVer = 5, [1] = {2, 845, 1, 124, string.byte("m"), 1, 7,
        846, 1, 125, string.byte("m"), 1, 7}, [2] = {846}})
    assert(f.comms.remoteQuestLogs[844] and f.comms.remoteQuestLogs[845] and f.comms.remoteQuestLogs[846],
        "full-list blocks accumulate instead of replacing each other")
    equal(f.comms.remoteQuestLogs[846]["Friend-Realm"][1].status, "F", "full-log packet preserves failed status")
    assert(f.comms.data:GetTooltip("m_123")[844]["Friend-Realm"], "production tooltip registration exists")
    equal(f.comms:PruneRemoteGroupPlayers(), false, "current member is not pruned, independent of connectivity")
    f.members["Friend-Realm"] = nil
    equal(f.comms:PruneRemoteGroupPlayers(), true, "full Name-Realm sender is pruned after departure")
    equal(next(f.comms.remoteQuestLogs), nil, "departure removes all group quests and empty buckets")
    for _, key in ipairs({"m_123", "m_124", "m_125"}) do
        equal(f.comms.data:KeyExists(key), nil, "departure removes actual tooltip key " .. key)
    end
    local redraws = f.redraws
    equal(f.comms:PruneRemoteGroupPlayers(), false, "repeated pruning is a no-op")
    equal(f.redraws, redraws, "unchanged roster does not schedule another redraw")
end

-- Force group cleanup even when GROUP_LEFT arrives before membership APIs settle.
do
    local f = fixture()
    f.comms:InsertQuestDataPacket(groupPacket(), "Friend-Realm")
    f.comms:RemoveAllRemoteGroupPlayers()
    equal(next(f.comms.remoteQuestLogs), nil, "forced cleanup ignores stale membership API")
    equal(f.comms.data:KeyExists("m_123"), nil, "group tooltip removed")
end

do
    local f = fixture()
    f.comms:InsertQuestDataPacket(groupPacket(), "Friend-Realm")
    f.comms:ResetAll()
    equal(next(f.comms.remoteQuestLogs), nil, "explicit reset still removes all quest snapshots")
    equal(f.comms.data:KeyExists("m_123"), nil, "explicit reset clears tooltips")
    f.members["Friend-Realm"] = nil
    equal(f.comms:PruneRemoteGroupPlayers(), false, "explicit reset clears group provenance")
end
print("Group comms cleanup: late packets, additive snapshots, tooltip cleanup and retired packet rejection passed")
