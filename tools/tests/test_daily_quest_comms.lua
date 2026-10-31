-- Run from the addon directory with Lua 5.1 or 5.2. Exercise daily sync through
-- the bundled libraries and production timers, with isolated library upgrades.
local function read(path)
    local file = assert(io.open(path, "rb"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local function harness(incompatible, upgradeAfterEmbed)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local function execute(source, name)
        if setfenv then return setfenv(assert(loadstring(source, name)), env)() end
        return assert(load(source, name, "t", env))()
    end
    local function file(path) return execute(read(path), "@" .. path) end
    env.loadstring = function(source, name)
        if setfenv then return setfenv(assert(loadstring(source, name)), env) end
        return load(source, name, "t", env)
    end
    env.unpack = unpack or table.unpack

    local state = {now = 100, guild = true, party = false, raid = false, frames = {}, wire = {}, attempts = 0}
    local function frame()
        local result = {scripts = {}}
        state.frames[#state.frames + 1] = result
        function result:SetScript(event, callback) self.scripts[event] = callback end
        function result:RegisterEvent() end
        function result:UnregisterAllEvents() end
        function result:Hide() self.shown = false end
        function result:Show() self.shown = true end
        function result:IsShown() return self.shown end
        function result:CreateAnimationGroup()
            local group = {playing = false}
            function group:CreateAnimation()
                local animation = {scripts = {}}
                self.animation = animation
                function animation:GetParent() return group end
                function animation:SetDuration(duration) self.duration = duration end
                function animation:SetScript(event, callback) self.scripts[event] = callback end
                return animation
            end
            function group:SetLooping() end
            function group:Play() self.playing = true; state.group = self end
            function group:Stop() self.playing = false end
            function group:Finish()
                if self.playing then self.animation.scripts.OnFinished(self.animation) end
            end
            return group
        end
        return result
    end
    env.CreateFrame = frame
    env.GetTime = function() return state.now end
    env.GetFramerate = function() return 60 end
    env.hooksecurefunc = function() end
    env.UnitName = function() return "Tester" end
    env.GetRealmName = function() return "TestRealm" end
    env.IsInGuild = function() return state.guild end
    env.geterrorhandler = function() return error end
    env.debugstack = function() return debug.traceback("original send stack", 2) end
    env.SendChatMessage = function() end
    env.SendAddonMessage = function(prefix, text, distribution, target)
        assert(#prefix + #text <= 254, "wire frames respect the 3.3.5 budget")
        state.wire[#state.wire + 1] = {prefix, text, distribution, target}
    end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function() end}
    env.QuestieCompat = {
        frame = frame(),
        IsInGroup = function() return state.party or state.raid end,
        IsInRaid = function() return state.raid end,
    }
    local modules = {}
    env.QuestieLoader = {
        StampLoadBoundary = function() end,
        CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    }
    env.Questie = {Debug = function() end}
    file("Libs/LibStub/LibStub.lua")
    file("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    file("Libs/AceComm-3.0/ChatThrottleLib.lua")
    file("Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
    local source = read("Libs/AceComm-3.0/AceComm-3.0.lua")
    local newer = source:gsub('"AceComm%-3%.0", 6', '"AceComm-3.0", 999')
        :gsub("local maxtextlen = 254 %- #prefix", "local maxtextlen = 255")
    if incompatible and not upgradeAfterEmbed then execute(newer, "@incompatible-AceComm.lua") end
    execute(source, "@Libs/AceComm-3.0/AceComm-3.0.lua")
    local comm = env.LibStub("AceComm-3.0")
    comm:Embed(env.Questie)
    if incompatible and upgradeAfterEmbed then execute(newer, "@incompatible-AceComm.lua") end
    local send = env.ChatThrottleLib.SendAddonMessage
    env.ChatThrottleLib.SendAddonMessage = function(self, ...)
        state.attempts = state.attempts + 1
        return send(self, ...)
    end
    env.ChatThrottleLib.HardThrottlingBeginTime = 0
    env.ChatThrottleLib.avail = 4000
    file("Compat/Timers.lua")

    local ids = {}
    for i = 1, 30 do ids[i] = 10000 + i end
    state.snapshot = {daily = {{npcId = 823, questIds = ids}}, weekly = {}}
    modules.AvailableQuests = {GetUnavailableQuestSnapshot = function() return state.snapshot end}
    file("Modules/Network/DailyQuestComms/DailyQuestComms.lua")
    state.env, state.daily, state.comm = env, modules.DailyQuestComms, comm
    function state:audienceEvent()
        self.frames[#self.frames].scripts.OnEvent()
    end
    function state:finish()
        self.now = self.now + 0.5
        return pcall(function() self.group:Finish() end)
    end
    return state
end

-- A normal large initial request still uses AceComm multipart and reassembles
-- byte-for-byte. An empty request remains a normal single-part message.
for _, empty in ipairs({false, true}) do
    local h = harness(false)
    if empty then h.snapshot = {daily = {}, weekly = {}} end
    local expected = h.env.LibStub("AceSerializer-3.0"):Serialize({
        eventName = "RequestUnavailableQuestState", data = h.snapshot,
    })
    h.daily.Initialize()
    assert(h.group.animation.duration == 0.5)
    assert(h:finish())
    assert(not h.group.playing and #h.wire == (empty and 1 or 2))
    local receiver = harness(false)
    local received
    receiver.env.Questie:RegisterComm("Questie335DlyV2", function(_, message) received = message end)
    for _, packet in ipairs(h.wire) do
        receiver.comm.frame.scripts.OnEvent(receiver.comm.frame, "CHAT_MSG_ADDON",
            packet[1], packet[2], packet[3], "Sender")
    end
    assert(received == expected, "the complete serialized snapshot is preserved")
    h:audienceEvent()
    assert(not h.group.playing, "successful initial sync does not restart")
end

-- Both load orders reproduce #176 without changing any on-disk library. The
-- original communication stack and size/version context survive timer rethrow.
for _, after in ipairs({false, true}) do
    local h = harness(true, after)
    h.daily.Initialize()
    local ok, message = h:finish()
    assert(not ok and not h.group.playing)
    for _, expected in ipairs({
        "prefix + message length cannot exceed 254 bytes", "prefix=Questie335DlyV2",
        "bytes=436", "distribution=GUILD", "AceComm=999", "CTL=21",
        "ChatThrottleLib.lua", "incompatible-AceComm.lua", "RequestUnavailableQuestState",
    }) do
        assert(message:find(expected, 1, true), "missing diagnostic: " .. expected .. " in " .. message)
    end
    local attempts = h.attempts
    for _ = 1, 65 do
        assert(h:finish())
        h:audienceEvent()
    end
    assert(h.attempts == attempts and not h.group.playing, "failure stops retries, including audience events")
    local _, revision = h.env.LibStub:GetLibrary("AceComm-3.0")
    assert(revision == 999, "the shared library is never forced back to revision 6")

    -- Explicit sends can still be attempted, with bounded diagnostics. A failed
    -- request is never marked successful when its repeated report is suppressed.
    assert(h.daily.RequestUnavailableQuestState() == false)
    h.now = h.now + 60
    ok, message = pcall(h.daily.RequestUnavailableQuestState)
    assert(not ok and message:find("distribution=GUILD", 1, true))

    -- A newly initialized session may retry; small messages remain supported.
    h.snapshot = {daily = {}, weekly = {}}
    h.daily.Initialize()
    assert(h:finish())
    assert(not h.group.playing and #h.wire == 1)
end

-- Whisper replies and ordinary broadcasts get the same diagnostics and keep
-- their distribution/target arguments. Missing debugstack has a safe fallback.
do
    local h = harness(true)
    h.daily.Initialize()
    local ok, message = pcall(h.daily.SendUnavailableQuestState, "Friend")
    assert(not ok and message:find("distribution=WHISPER", 1, true) and not h.group.playing)
    h.env.debugstack = false
    h.now = h.now + 60
    ok, message = pcall(h.daily.BroadcastUnavailableDailyQuests, 823, h.snapshot.daily[1].questIds)
    assert(not ok and message:find("Send failed", 1, true))
end
for _, distribution in ipairs({"GUILD", "PARTY", "RAID", "WHISPER"}) do
    local h = harness(false)
    h.guild, h.party, h.raid = distribution == "GUILD", distribution == "PARTY", distribution == "RAID"
    if distribution == "WHISPER" then h.daily.SendUnavailableQuestState("Friend")
    else h.daily.BroadcastUnavailableDailyQuests(823, h.snapshot.daily[1].questIds) end
    assert(#h.wire > 1)
    for _, packet in ipairs(h.wire) do
        assert(packet[3] == distribution)
        assert(packet[4] == (distribution == "WHISPER" and "Friend" or nil))
    end
end

-- Returning false (rather than throwing) retains the normal 60-attempt bound.
do
    local h = harness(false)
    local calls = 0
    h.daily.RequestUnavailableQuestState = function() calls = calls + 1; return false end
    h.daily.Initialize()
    for _ = 1, 65 do assert(h:finish()) end
    assert(calls == 60 and not h.group.playing)
end
do
    local h = harness(false)
    h.guild = false
    h.daily.Initialize()
    assert(not h.group and h.attempts == 0, "no audience starts no timer or sends")
end

print("Daily quest comms: multipart, incompatible libraries, diagnostics, retry bounds and audiences passed")
