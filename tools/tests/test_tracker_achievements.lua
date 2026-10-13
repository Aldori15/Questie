-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the tracker public API with native watch hooks and deferred events.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
local function noop() end
local unpackValues = unpack or table.unpack

local function setup(nativeIds, savedIds)
    local env = setmetatable({}, {__index = _G})
    env._G, env.strmatch, env.format = env, string.match, string.format
    local s = {env = env, native = {}, saved = savedIds or {}, hooks = {}, timers = {}, queued = {},
        now = 10, updates = 0, removes = 0, errors = 0, uiLoads = 0, uiUpdates = 0, watchUpdates = 0}
    for _, id in ipairs(nativeIds or {}) do s.native[id] = true end
    env.Questie = {db = {profile = {trackerEnabled = true}, char = {trackedAchievementIds = s.saved,
        collapsedQuests = {}, collapsedZones = {}, TrackedQuests = {}, AutoUntrackedQuests = {}}}, Debug = noop}
    env.GetTime = function() return s.now end
    env.debugstack = noop
    env.GetNumQuestWatches = function() return 0 end
    env.IsQuestWatched = function() return false end
    env.GetTrackedAchievements = function()
        local ids = {}
        for id in pairs(s.native) do ids[#ids + 1] = id end
        table.sort(ids)
        return unpackValues(ids)
    end
    env.IsTrackedAchievement = function(id) return s.native[id] == true end
    env.GetNumTrackedAchievements = function()
        local count = 0
        for _ in pairs(s.native) do count = count + 1 end
        return count
    end
    s.originalIsTracked, s.originalCount = env.IsTrackedAchievement, env.GetNumTrackedAchievements
    env.WatchFrame_Update = function() s.watchUpdates = s.watchUpdates + 1 end
    env.AchievementFrame_LoadUI = function()
        s.uiLoads = s.uiLoads + 1
        env.AchievementFrame = {IsShown = function() return s.uiShown end}
    end
    env.AchievementFrameAchievements_ForceUpdate = function() s.uiUpdates = s.uiUpdates + 1 end
    env.IsShiftKeyDown = function() return s.shift end
    env.GetMouseFocus = function()
        if s.mouseName then return {GetName = function() return s.mouseName end} end
    end
    env.IsAddOnLoaded = function(name) return name == "Krowi_AchievementFilter" and s.krowi end
    env.UIErrorsFrame = {AddMessage = function() s.errors = s.errors + 1 end}
    env.StaticPopup_Show = noop
    env.LibStub = function() return {} end
    env.QuestLogFrame = {IsShown = function() return false end}
    env.QuestieCompat = {C_Timer = {After = function(delay, callback)
        s.timers[#s.timers + 1] = {delay = delay, callback = callback}
    end}}
    loadModule("Modules/Libs/QuestieLoader.lua", env)
    local loader = env.QuestieLoader
    local l10n = loader:CreateModule("l10n")
    setmetatable(l10n, {__call = function(_, text) return text end})
    loader:CreateModule("QuestieCombatQueue").Queue = function(_, callback) s.queued[#s.queued + 1] = callback end
    loader:CreateModule("TrackerQuestTimers").HideBlizzardTimer = noop
    loader:ImportModule("TrackerQuestTimers").ShowBlizzardTimer = noop
    s.tracker = loader:ImportModule("QuestieTracker")
    local function notify(id) s.tracker:UpdateAchieveTrackerCache(id) end
    env.AddTrackedAchievement = function(id) s.native[id] = true; notify(id) end
    env.RemoveTrackedAchievement = function(id)
        s.removes = s.removes + 1
        s.native[id] = nil
        notify(id)
    end
    for _, name in ipairs({"UIParent_ManageFramePositions", "AddQuestWatch", "RemoveQuestWatch"}) do env[name] = noop end
    env.hooksecurefunc = function(name, callback)
        s.hooks[name] = (s.hooks[name] or 0) + 1
        local original = assert(env[name], "native hook target exists")
        env[name] = function(...)
            original(...)
            callback(...)
        end
    end
    loadModule("Modules/Tracker/TrackerAchievements.lua", env)
    loadModule("Modules/Tracker/QuestieTracker.lua", env)
    s.controller = loader:ImportModule("TrackerAchievements")
    s.tracker.Update = function() s.updates = s.updates + 1 end
    s.tracker:HookBaseTracker()
    s.timers, s.queued = {}, {} -- Discard the unrelated initial quest redraw.
    function s.flushTimers()
        while #s.timers > 0 do
            local timer = table.remove(s.timers, 1)
            assert(timer.delay == 0.1 or timer.delay == 0.5, "achievement event or startup delay")
            s.now = s.now + timer.delay
            timer.callback()
        end
    end
    function s.settle()
        while #s.timers > 0 or #s.queued > 0 do
            s.flushTimers()
            while #s.queued > 0 do table.remove(s.queued, 1)() end
        end
    end
    function s.add(id) s.now = s.now + 1; env.AddTrackedAchievement(id) end
    function s.cache(id) return s.controller.GetTrackedIds()[id] end
    return s
end

local groups = 0
do
    local s = setup({973}, {[978] = true})
    local loader = s.env.QuestieLoader
    for _, name in ipairs({"TrackerBaseFrame", "TrackerHeaderFrame", "TrackerQuestFrame"}) do
        loader:ImportModule(name).Initialize = function() return {} end
    end
    for _, name in ipairs({"TrackerLinePool", "TrackerFadeTicker", "TrackerNearestQuestItem"}) do
        loader:ImportModule(name).Initialize = noop
    end
    loader:ImportModule("TrackerNearestQuestItem").SetupKeybinding = noop
    loader:ImportModule("TrackerUtils").IsVoiceOverLoaded = function() return false end
    s.env.DurabilityFrame = {GetPoint = noop}
    s.tracker.HandleZoneChanged = noop
    local thread = coroutine.create(s.tracker.Initialize)
    local ok, errorMessage = coroutine.resume(thread)
    assert(ok, errorMessage)
    s.settle()
    equal(s.tracker.started, true, "real tracker startup completes")
    equal(s.cache(973), true, "real tracker startup transfers native watches")
    equal(s.cache(978), true, "real tracker startup restores saved watches")
    equal(s.native[973], nil, "real tracker startup clears native watch")
    equal(s.uiUpdates, 1, "real startup refreshes achievements once")
    ok, errorMessage = coroutine.resume(coroutine.create(s.tracker.Initialize))
    assert(ok, errorMessage)
    equal(s.uiUpdates, 1, "repeat tracker initialization leaves achievement state intact")
    groups = groups + 1
end
do
    local s = setup({973}, {[978] = true, [999] = false})
    s.controller.Initialize()
    equal(s.saved[973], true, "native watch transferred to saved tracking")
    equal(s.native[973], nil, "native watch removed")
    equal(s.cache(973), true, "transferred watch enters render cache")
    equal(s.cache(978), true, "saved watch restored")
    equal(s.cache(999), nil, "false saved entry excluded from render cache")
    equal(s.uiLoads, 1, "native transfer loads achievement UI")
    equal(s.uiUpdates, 1, "native transfer refreshes achievement UI")
    equal(s.watchUpdates, 1, "native watch frame refreshed")
    s.settle()
    groups = groups + 1
end
do
    local s = setup({}, {[978] = true})
    s.controller.Initialize()
    equal(s.cache(978), true, "reload restores saved achievement")
    equal(s.uiLoads, 0, "saved-only initialization leaves UI unloaded")
    groups = groups + 1
end
do
    local s = setup()
    s.add(978)
    equal(s.saved[978], true, "programmatic watch saved")
    equal(s.native[978], nil, "Questie removes native watch")
    equal(s.uiLoads, 1, "programmatic watch lazily loads UI")
    equal(s.cache(978), nil, "render cache waits for deferred event")
    s.flushTimers()
    equal(s.cache(978), true, "deferred event updates render cache")
    equal(#s.queued, 1, "duplicate native events queue one changed-state redraw")
    equal(s.updates, 0, "redraw waits for combat queue")
    s.settle()
    equal(s.updates, 1, "one redraw after queue drains")
    groups = groups + 1
end
for _, mode in ipairs({"checkbox", "shift", "other", "krowi"}) do
    local s = setup()
    s.env.AchievementFrame_LoadUI()
    s.uiShown = true
    s.mouseName = mode == "checkbox" and "AchievementFrameAchievementsContainerButton1Tracked" or "OtherButton"
    s.shift = mode == "shift" or mode == "krowi"
    s.krowi = mode == "krowi"
    s.add(978); s.settle()
    equal(s.saved[978], mode ~= "other" and true or nil, "achievement UI gesture: " .. mode)
    if mode ~= "other" then
        s.add(978); s.settle()
        equal(s.saved[978], nil, "second achievement UI gesture untracks: " .. mode)
        equal(s.cache(978), nil, "untrack removes render cache: " .. mode)
    end
    groups = groups + 1
end
do
    local s = setup()
    s.env.AchievementFrame_LoadUI()
    s.uiShown, s.shift = true, true
    s.env.Questie.db.char.collapsedQuests[978] = true
    s.env.Questie.db.char.collapsedZones.Achievements = true
    s.add(978); s.settle()
    equal(s.env.Questie.db.char.collapsedQuests[978], nil, "tracking expands achievement")
    equal(s.env.Questie.db.char.collapsedZones.Achievements, nil, "tracking expands achievement zone")
    groups = groups + 1
end
do
    local saved = {}
    for id = 1, 10 do saved[id] = true end
    local s = setup({}, saved)
    s.add(978); s.settle()
    equal(s.saved[978], nil, "eleventh achievement rejected")
    equal(s.native[978], nil, "rejected native watch cleared")
    equal(s.errors, 1, "tracking limit error shown")
    equal(s.env.GetNumTrackedAchievements(true), 10, "Questie tracking count")
    equal(s.env.GetNumTrackedAchievements(), 0, "Blizzard watch count stays hidden")
    equal(s.env.IsTrackedAchievement(1), true, "saved achievement query")
    equal(s.env.IsTrackedAchievement(978), false, "untracked achievement query")
    groups = groups + 1
end
for _, owner in ipairs({"native", "questie", "disabledHooks"}) do
    local s = setup({}, {[978] = true})
    s.controller.Initialize()
    s.tracker.disableHooks = owner == "disabledHooks"
    s.env.RemoveTrackedAchievement(978, owner == "questie")
    s.settle()
    equal(s.saved[978], owner ~= "native" and true or nil, "removal ownership: " .. owner)
    equal(s.cache(978), owner ~= "native" and true or nil, "cache removal ownership: " .. owner)
    groups = groups + 1
end
do
    local s = setup({}, {[978] = true})
    s.controller.Initialize()
    s.tracker:UntrackAchieveId(978)
    s.tracker:UpdateAchieveTrackerCache(978)
    s.settle()
    equal(s.saved[978], nil, "menu/earned event clears saved watch")
    equal(s.cache(978), nil, "menu/earned event clears render cache")
    equal(s.updates, 1, "menu/earned event refreshes tracker")
    groups = groups + 1
end
do
    local s = setup()
    s.tracker:TrackAchieve(0)
    equal(s.removes, 0, "invalid zero achievement skipped")
    s.env.Questie.db.profile.trackerEnabled = false
    s.add(978)
    equal(s.saved[978], nil, "disabled tracker ignores additions")
    equal(#s.timers, 0, "disabled tracker ignores watch events")
    groups = groups + 1
end
do
    local s = setup()
    s.tracker:UpdateAchieveTrackerCache(978)
    s.env.Questie.db.profile.trackerEnabled = false
    s.flushTimers()
    equal(#s.queued, 0, "disabling during delayed event prevents redraw")
    groups = groups + 1
end
do
    local s = setup()
    s.env.AchievementFrame_LoadUI()
    s.uiShown, s.mouseName = true, "OtherButton"
    s.tracker:TrackAchieve(978)
    s.tracker:TrackAchieve(978)
    equal(s.removes, 1, "same-ID rapid calls throttled")
    s.now = s.now + 0.2
    s.tracker:TrackAchieve(978)
    equal(s.removes, 2, "throttle expires")
    groups = groups + 1
end
do
    local s = setup({}, {[978] = true})
    s.tracker:HookBaseTracker()
    equal(s.hooks.AddTrackedAchievement, 1, "secure add hook installed once")
    equal(s.hooks.RemoveTrackedAchievement, 1, "secure remove hook installed once")
    s.tracker:Unhook()
    equal(s.env.IsTrackedAchievement, s.originalIsTracked, "native tracking query restored")
    equal(s.env.GetNumTrackedAchievements, s.originalCount, "native count query restored")
    s.tracker:HookBaseTracker()
    equal(s.hooks.AddTrackedAchievement, 1, "re-enabling reuses secure hook")
    equal(s.env.GetNumTrackedAchievements(true), 1, "re-enabling reinstalls Questie query")
    equal(s.tracker.GetNumTrackedAchievements, s.originalCount, "native function snapshot preserved")
    groups = groups + 1
end
do
    local s = setup({}, {[978] = true})
    s.controller.Initialize()
    s.tracker:Disable()
    equal(next(s.env.Questie.db.char.trackedAchievementIds), nil, "disable clears saved tracking")
    equal(s.cache(978), true, "disable retains existing cache until reload as before")
    groups = groups + 1
end

do
    local s = setup()
    for _, name in ipairs({"RemoveTrackedAchievement", "UpdateAchieveTrackerCache", "UntrackAchieveId", "TrackAchieve"}) do
        equal(s.tracker[name], s.controller[name], "public entry point preserved: " .. name)
    end
    local count, seen = 0, false
    for line in io.lines("Questie-335.toc") do
        if line == "Modules\\Tracker\\TrackerAchievements.lua" then count, seen = count + 1, true
        elseif line == "Modules\\Tracker\\QuestieTracker.lua" then equal(seen, true, "achievement module loads before renderer") end
    end
    equal(count, 1, "achievement module registered exactly once")
    groups = groups + 1
end
print("Tracker achievement regressions passed (" .. groups .. " groups)")
