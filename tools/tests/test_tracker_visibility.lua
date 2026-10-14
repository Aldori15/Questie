-- Run from the addon root with Lua 5.1 or 5.2+.
-- Test the tracker entry points, frame visibility, and actual combat queue.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
local function noop() end
local unpackValues = unpack or table.unpack
local handlers = {"HandleZoneChanged", "HandleCombatStarted", "HandleCombatEnded",
    "OnMinimizeInInstancesChanged", "OnHideInInstancesChanged", "OnMinimizeInCombatChanged", "OnHideInCombatChanged"}

local function setup(options)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local s = {env = env, instance = false, combat = false, ghost = false, hasQuest = true,
        tickers = {}, redraws = 0, clicks = 0}
    local profile = {trackerEnabled = true, trackerHeaderEnabled = true, trackerFontSizeHeader = 14, trackerFontSizeZone = 13}
    for key, value in pairs(options or {}) do profile[key] = value end
    env.Questie = {db = {profile = profile, char = {isTrackerExpanded = true}}, Debug = noop}
    env.GetTime = function() return 10 end
    env.debugstack = noop
    env.GetNumQuestWatches = function() return 0 end
    env.GetTrackedAchievements = noop
    env.IsInInstance = function() return s.instance end
    env.InCombatLockdown = function() return s.combat end
    env.UnitIsGhost = function(unit) equal(unit, "player", "ghost check uses player"); return s.ghost end
    env.LibStub = function() return {} end
    env.QuestieCompat = {C_Timer = {NewTicker = function(interval, callback)
        equal(interval, 0.1, "actual combat queue interval")
        local ticker = {callback = callback}
        function ticker:Cancel() self.cancelled = true end
        s.tickers[#s.tickers + 1] = ticker
        return ticker
    end}}
    loadModule("Modules/Libs/QuestieLoader.lua", env)
    local loader = env.QuestieLoader
    local lib = loader:CreateModule("QuestieLib")
    lib.tpack = function(...) return {n = select("#", ...), ...} end
    lib.tunpack = function(args) return unpackValues(args, 1, args.n) end
    loadModule("Modules/Libs/QuestieCombatQueue.lua", env)
    loader:ImportModule("QuestieCombatQueue").Initialize()
    local utils = loader:ImportModule("TrackerUtils")
    utils.HasQuest = function() return s.hasQuest end
    utils.ShowVoiceOverPlayButtons, utils.UpdateVoiceOverPlayButtons = noop, noop
    for _, name in ipairs({"TrackerBaseFrame", "TrackerHeaderFrame", "TrackerQuestFrame"}) do loader:ImportModule(name).Update = noop end
    local pool = loader:ImportModule("TrackerLinePool")
    pool.HideUnusedLines, pool.HideUnusedButtons = noop, noop
    pool.GetCurrentLine = noop
    loadModule("Modules/Tracker/TrackerVisibility.lua", env)
    loadModule("Modules/Tracker/QuestieTracker.lua", env)
    local tracker = loader:ImportModule("QuestieTracker")
    s.tracker, s.profile, s.char = tracker, profile, env.Questie.db.char
    tracker.started = true
    tracker.Update = function() s.redraws = s.redraws + 1 end
    local base = {shown = true, Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end, IsShown = function(self) return self.shown end, SetMinResize = noop}
    local header = {GetWidth = function() return 100 end, GetHeight = function() return 16 end,
        trackedQuests = {Click = function()
            s.char.isTrackerExpanded = not s.char.isTrackerExpanded
            s.clicks = s.clicks + 1
        end}}
    s.base = base
    local function upvalue(method, name, value)
        for index = 1, math.huge do
            local actual = debug.getupvalue(method, index)
            assert(actual, "missing frame fixture upvalue: " .. name)
            if actual == name then debug.setupvalue(method, index, value); return end
        end
    end
    upvalue(tracker.Show, "trackerBaseFrame", base)
    upvalue(tracker.Collapse, "trackerHeaderFrame", header)
    upvalue(tracker.UpdateFormatting, "allowFormattingUpdate", true)
    function s.flush()
        for _ = 1, 20 do
            local active = false
            for _, ticker in ipairs(s.tickers) do
                if not ticker.cancelled then active = true; ticker.callback() end
            end
            if not active or s.combat then return end
        end
        error("combat queue did not drain")
    end
    function s.layout() tracker:UpdateFormatting() end
    return s
end

local groups = 0
for _, mode in ipairs({"minimize", "hide"}) do
    local s = setup({[mode .. "TrackerInInstances"] = true})
    s.instance = true
    s.tracker.HandleZoneChanged()
    if mode == "minimize" then
        equal(s.char.isTrackerExpanded, true, "instance minimize waits for combat queue")
        s.flush(); equal(s.char.isTrackerExpanded, false, "instance automatically minimized")
    else
        equal(s.base.shown, false, "instance automatically hidden")
        s.tracker:Show(); s.layout()
        equal(s.base.shown, false, "Show/layout respect instance hiding")
    end
    s.instance = false; s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, true, "leaving instance restores expansion")
    equal(s.base.shown, true, "leaving instance restores visibility")
    groups = groups + 1
end
do
    local s = setup({minimizeTrackerInInstances = true})
    s.tracker:Collapse()
    s.instance = true; s.tracker.HandleZoneChanged(); s.flush()
    s.instance = false; s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, false, "manual collapse is not undone when leaving instance")
    equal(s.clicks, 1, "manual collapse not toggled twice")
    groups = groups + 1
end
do
    local s = setup({minimizeTrackerInInstances = true})
    s.instance = true; s.tracker.HandleZoneChanged(); s.flush()
    s.instance, s.ghost = false, true
    s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, false, "ghost outside instance remains minimized")
    s.ghost = false; s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, true, "resurrection outside instance restores expansion")
    groups = groups + 1
end
for _, mode in ipairs({"minimize", "hide"}) do
    local s = setup({[mode .. "TrackerInCombat"] = true})
    s.combat = true; s.tracker.HandleCombatStarted()
    if mode == "minimize" then equal(s.char.isTrackerExpanded, false, "combat immediately minimizes tracker")
    else
        equal(s.base.shown, false, "combat immediately hides tracker")
        s.tracker:Show(); s.layout(); s.flush()
        equal(s.base.shown, false, "Show/layout cannot undo combat hiding")
    end
    s.combat = false; s.tracker.HandleCombatEnded(); s.flush()
    equal(s.char.isTrackerExpanded, true, "combat end restores expansion")
    equal(s.base.shown, true, "combat end restores visibility")
    groups = groups + 1
end
for _, mode in ipairs({"minimize", "hide"}) do
    local s = setup({[mode .. "TrackerInCombat"] = true, [mode .. "TrackerInInstances"] = true})
    s.combat = true; s.tracker.HandleCombatStarted()
    s.instance = true; s.tracker.HandleZoneChanged(); s.flush()
    s.combat = false; s.tracker.HandleCombatEnded(); s.flush()
    if mode == "minimize" then equal(s.char.isTrackerExpanded, false, "instance keeps tracker minimized after combat")
    else
        s.layout(); equal(s.base.shown, false, "instance keeps tracker hidden after combat")
    end
    s.instance = false; s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, true, "leaving overlapping instance restores expansion")
    equal(s.base.shown, true, "leaving overlapping instance restores visibility")
    groups = groups + 1
end
do
    local s = setup({minimizeTrackerInInstances = true})
    s.instance, s.combat = true, true
    s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, true, "real combat queue blocks queued instance collapse")
    s.combat = false; s.flush()
    equal(s.char.isTrackerExpanded, false, "queued instance collapse runs after combat")
    groups = groups + 1
end
for _, context in ipairs({"Instances", "Combat"}) do
    for _, mode in ipairs({"Minimize", "Hide"}) do
        local s = setup()
        s.instance, s.combat = context == "Instances", context == "Combat"
        local key = mode:lower() .. "TrackerIn" .. context
        local method = "On" .. mode .. "In" .. context .. "Changed"
        s.profile[key] = true; s.tracker[method](true)
        s.combat = false; s.flush()
        if mode == "Minimize" then equal(s.char.isTrackerExpanded, false, "option enabled in active context")
        else equal(s.base.shown, false, "hide option enabled in active context") end
        s.profile[key] = false; s.tracker[method](false); s.flush()
        equal(s.char.isTrackerExpanded, true, "disabling option restores expansion")
        equal(s.base.shown, true, "disabling option restores visibility")
        groups = groups + 1
    end
end
for _, mode in ipairs({"Minimize", "Hide"}) do
    local s = setup({[mode:lower() .. "TrackerInInstances"] = true})
    s.combat = true
    local key = mode:lower() .. "TrackerInCombat"
    local method = "On" .. mode .. "InCombatChanged"
    s.profile[key] = true; s.tracker[method](true)
    s.instance = true
    s.profile[key] = false; s.tracker[method](false)
    s.combat = false; s.flush()
    if mode == "Minimize" then equal(s.char.isTrackerExpanded, false, "disabling combat option hands minimization to instance")
    else equal(s.base.shown, false, "disabling combat option hands hiding to instance") end
    s.instance = false; s.tracker.HandleZoneChanged(); s.flush()
    equal(s.char.isTrackerExpanded, true, "instance handoff releases minimization on exit")
    equal(s.base.shown, true, "instance handoff releases hiding on exit")
    groups = groups + 1
end
for _, enabled in ipairs({false, true}) do
    local s = setup({hideTrackerInCombat = true, hideTrackerInInstances = true})
    s.profile.trackerEnabled, s.tracker.started = enabled, not enabled
    s.instance, s.combat = true, true
    s.tracker.HandleZoneChanged(); s.tracker.HandleCombatStarted(); s.flush()
    equal(s.base.shown, true, "disabled/unstarted trackers ignore automatic hiding")
    equal(s.clicks, 0, "disabled/unstarted trackers ignore automatic minimization")
    groups = groups + 1
end
do
    local s = setup()
    s.hasQuest = false; s.layout()
    equal(s.base.shown, false, "empty tracker hidden")
    s.profile.alwaysShowTracker = true; s.layout()
    equal(s.base.shown, true, "always-show option displays empty tracker")
    s.profile.hideTrackerInCombat, s.combat = true, true
    s.tracker.HandleCombatStarted(); s.layout()
    equal(s.base.shown, false, "combat hiding overrides always-show option")
    groups = groups + 1
end
do
    local s = setup({hideTrackerInCombat = true, hideTrackerInInstances = true})
    s.instance = true; s.tracker.HandleZoneChanged()
    s.combat = true; s.tracker.HandleCombatStarted()
    s.instance = false; s.tracker.HandleZoneChanged()
    s.layout(); equal(s.base.shown, false, "combat retains hiding when leaving instance")
    s.combat = false; s.tracker.HandleCombatEnded(); s.flush(); s.layout()
    equal(s.base.shown, true, "last automatic hide reason releases tracker")
    groups = groups + 1
end
do
    local s = setup()
    s.tracker:Hide(); s.tracker:Show(); s.flush()
    equal(s.base.shown, true, "manual Show restores visible tracker")
    s.profile.trackerEnabled = false
    s.tracker:Hide(); s.tracker:Show()
    equal(s.base.shown, false, "Show respects disabled tracker")
    groups = groups + 1
end

do
    local s = setup()
    local controller = s.env.QuestieLoader:ImportModule("TrackerVisibility")
    for _, name in ipairs(handlers) do equal(s.tracker[name], controller[name], "public event/option entry point: " .. name) end
    local count, seen = 0, false
    for line in io.lines("Questie-335.toc") do
        if line == "Modules\\Tracker\\TrackerVisibility.lua" then count, seen = count + 1, true
        elseif line == "Modules\\Tracker\\QuestieTracker.lua" then equal(seen, true, "visibility module loads before renderer") end
    end
    equal(count, 1, "visibility module registered exactly once")
    groups = groups + 1
end
-- Deferred instance collapses must use the policy at execution time, for both
-- zone events and setting changes, rather than the context that queued them.
for _, entryPoint in ipairs({"HandleZoneChanged", "OnMinimizeInInstancesChanged"}) do
    local function queueCollapse(s)
        s.instance = true
        s.tracker[entryPoint](true)
        equal(s.char.isTrackerExpanded, true, "instance collapse is queued: " .. entryPoint)
    end
    do
        local s = setup({minimizeTrackerInInstances = true})
        queueCollapse(s)
        s.instance = false
        s.tracker.HandleZoneChanged()
        s.flush()
        equal(s.char.isTrackerExpanded, true, "leaving before queued collapse keeps tracker expanded: " .. entryPoint)
        equal(s.clicks, 0, "cancelled instance collapse does not toggle tracker: " .. entryPoint)
        groups = groups + 1
    end
    do
        local s = setup({minimizeTrackerInInstances = true})
        s.combat = true
        queueCollapse(s)
        s.flush()
        equal(s.char.isTrackerExpanded, true, "combat delays instance collapse: " .. entryPoint)
        s.instance = false
        s.tracker.HandleZoneChanged()
        s.combat = false
        s.tracker.HandleCombatEnded()
        s.flush()
        equal(s.char.isTrackerExpanded, true, "combat-delayed collapse cannot run after exit: " .. entryPoint)
        equal(s.clicks, 0, "combat-delayed collapse makes no stale toggle: " .. entryPoint)
        groups = groups + 1
    end
    for _, policyChange in ipairs({"minimizeTrackerInInstances", "trackerEnabled", "started"}) do
        local s = setup({minimizeTrackerInInstances = true})
        queueCollapse(s)
        if policyChange == "started" then s.tracker.started = false
        else s.profile[policyChange] = false end
        s.flush()
        equal(s.char.isTrackerExpanded, true, "queued collapse respects changed " .. policyChange .. ": " .. entryPoint)
        equal(s.clicks, 0, "changed policy suppresses tracker toggle: " .. entryPoint)
        groups = groups + 1
    end
end
print("Tracker visibility regressions passed (" .. groups .. " groups)")
