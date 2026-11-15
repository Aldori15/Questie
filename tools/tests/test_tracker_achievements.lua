-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise native achievement watches, legacy import, tracker lifecycle and WatchFrame presentation.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
local function noop() end
local unpackValues = unpack or table.unpack

local function setup(nativeIds, savedIds, options)
    options = options or {}
    local env = setmetatable({}, {__index = _G})
    env._G, env.strmatch, env.format = env, string.match, string.format
    local s = {env = env, native = {}, saved = savedIds or {}, completed = options.completed or {},
        hooks = {}, timers = {}, queued = {}, updates = 0, adds = 0, removes = 0,
        uiLoads = 0, uiUpdates = 0, watchUpdates = 0, displayCalls = {}, questDisplays = 0, timerDisplays = 0}
    for _, id in ipairs(nativeIds or {}) do s.native[id] = true end
    env.Questie = {db = {profile = {trackerEnabled = true}, char = {trackedAchievementIds = s.saved,
        collapsedQuests = {}, collapsedZones = {}, TrackedQuests = {}, AutoUntrackedQuests = {}}}, Debug = noop}
    env.GetTime, env.debugstack = function() return 10 end, noop
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
    env.GetAchievementInfo = function(id)
        if type(id) == "number" and id > 0 and id % 1 == 0 and id ~= 9999 then
            return id, "Achievement " .. id, 10, s.completed[id] == true
        end
    end
    s.originalIsTracked, s.originalCount, s.originalIds =
        env.IsTrackedAchievement, env.GetNumTrackedAchievements, env.GetTrackedAchievements
    env.WatchFrame_DisplayTrackedAchievements = function(line, offset, height, width, ...)
        local ids = {...}
        s.displayCalls[#s.displayCalls + 1] = {line = line, offset = offset, height = height, width = width,
            ids = ids, count = select("#", ...)}
        s.visibleAchievementRows = #ids
        return offset + #ids * 10, #ids, width
    end
    env.WatchFrame_HandleDisplayTrackedAchievements = function(line, offset, height, width)
        return env.WatchFrame_DisplayTrackedAchievements(line, offset, height, width, env.GetTrackedAchievements())
    end
    s.nativeHandler = env.WatchFrame_HandleDisplayTrackedAchievements
    s.questHandler = function() s.questDisplays = s.questDisplays + 1 end
    s.timerHandler = function() s.timerDisplays = s.timerDisplays + 1 end
    s.otherHandler = function() end
    env.WATCHFRAME_OBJECTIVEHANDLERS = {s.questHandler, s.nativeHandler, s.timerHandler, s.otherHandler}
    env.WatchFrame_Update = function()
        s.watchUpdates = s.watchUpdates + 1
        for _, handler in ipairs(env.WATCHFRAME_OBJECTIVEHANDLERS) do handler("watch-line", 12, 300, 200) end
    end
    env.AchievementFrame_LoadUI = function()
        s.uiLoads = s.uiLoads + 1
        env.AchievementFrame = {IsShown = function() return s.uiShown end}
    end
    env.AchievementFrameAchievements_ForceUpdate = function() s.uiUpdates = s.uiUpdates + 1 end
    env.IsShiftKeyDown, env.GetMouseFocus, env.IsAddOnLoaded = function() return false end, noop, function() return false end
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
    -- Native Wrath can report membership through TRACKED_ACHIEVEMENT_UPDATE too.
    local function notify(id)
        if s.watchEvent then s.watchEvent(id)
        else s.tracker:UpdateAchieveTrackerCache(id) end
    end
    env.AddTrackedAchievement = function(id)
        s.adds = s.adds + 1
        local valid, _, _, completed = env.GetAchievementInfo(id)
        if not valid or completed or s.native[id] or env.GetNumTrackedAchievements() >= 10 then return end
        s.native[id] = true
        notify(id)
    end
    env.RemoveTrackedAchievement = function(id)
        s.removes = s.removes + 1
        if not s.native[id] then return end
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
    loadModule("Modules/Tracker/TrackerVisibility.lua", env)
    loadModule("Modules/Tracker/TrackerAchievements.lua", env)
    loadModule("Modules/Tracker/QuestieTracker.lua", env)
    s.controller = loader:ImportModule("TrackerAchievements")
    s.tracker.Update = function() s.updates = s.updates + 1 end
    if not options.skipHook then
        s.tracker:HookBaseTracker()
        s.tracker.started = true
        s.timers, s.queued = {}, {} -- Discard the unrelated initial quest redraw.
    end
    function s.settle()
        for _ = 1, 20 do
            if #s.timers == 0 and #s.queued == 0 then return end
            while #s.timers > 0 do table.remove(s.timers, 1).callback() end
            while #s.queued > 0 do table.remove(s.queued, 1)() end
        end
        error("achievement work did not settle")
    end
    function s.nativeQueriesUnchanged()
        equal(env.IsTrackedAchievement, s.originalIsTracked, "native membership query is never replaced")
        equal(env.GetNumTrackedAchievements, s.originalCount, "native count query is never replaced")
        equal(env.GetTrackedAchievements, s.originalIds, "native watch list query is never replaced")
    end
    function s.watched(id) return s.controller.GetTrackedIds()[id] end
    return s
end

local function installAchievementEvents(s)
    local file = assert(io.open("Modules/QuestieEventHandler.lua", "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    local helper = assert(source:match(
        "(local function _HasTrackedAchievements%(%).-)%s*\nfunction QuestieEventHandler:RegisterEarlyEvents"),
        "missing production tracked-achievement helper")
    local registration = assert(source:match(
        "%-%- UI Achievement Events\n(.-)%-%- Money based Achievement updates"),
        "missing production achievement event registrations")
    s.events, s.availabilityUpdates = {}, 0
    s.env.Questie.RegisterEvent = function(_, event, callback) s.events[event] = callback end
    s.env.QuestieLoader:ImportModule("AvailableQuests").CalculateAndDrawAll = function()
        s.availabilityUpdates = s.availabilityUpdates + 1
    end
    local code = [[
        local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
        local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
        local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
        local C_Timer = QuestieCompat.C_Timer
        local criteriaUpdateQueued
    ]] .. helper .. "\n" .. registration
    if setfenv then setfenv(assert(loadstring(code, "production achievement events")), s.env)()
    else assert(load(code, "production achievement events", "t", s.env))() end
    for _, event in ipairs({"ACHIEVEMENT_EARNED", "TRACKED_ACHIEVEMENT_LIST_CHANGED",
        "TRACKED_ACHIEVEMENT_UPDATE", "CRITERIA_UPDATE"}) do
        assert(s.events[event], "missing native achievement event: " .. event)
    end
    function s.fire(event, ...) return s.events[event](event, ...) end
    s.watchEvent = function(id) s.fire("TRACKED_ACHIEVEMENT_UPDATE", id) end
end

-- Stand-in for DragonUI's public collector API; production code owns the filtering.
local function installDragonUI(s, withQuest)
    local d = {collectors = {}, blocks = {}, enabled = true, refreshes = 0,
        source = {{kind = "achievement", id = 978}, {kind = "timer", id = 844},
            {kind = "recipe", id = 2018}, {kind = "other", id = 1}}}
    if withQuest then table.insert(d.source, 1, {kind = "quest", id = 844}) end
    d.tracker = {
        AddCollector = function(callback)
            assert(type(callback) == "function", "DragonUI AddCollector receives a plain collector function")
            d.collectors[#d.collectors + 1] = callback
        end,
        Refresh = function()
            d.refreshes = d.refreshes + 1
            d.blocks = {}
            if not d.enabled then return end
            for _, block in ipairs(d.source) do d.blocks[#d.blocks + 1] = block end
            for _, callback in ipairs(d.collectors) do callback(d.blocks) end
        end,
    }
    s.env.DragonUI = {ObjectiveTracker = d.tracker}
    function d.has(kind)
        for _, block in ipairs(d.blocks) do if block.kind == kind then return true end end
        return false
    end
    return d
end

local groups = 0
do
    local s = setup({973}, {[978] = true}, {skipHook = true})
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
    local ok, message = coroutine.resume(coroutine.create(s.tracker.Initialize))
    assert(ok, message)
    s.settle()
    equal(s.tracker.started, true, "real tracker startup completes")
    assert(s.watched(973) and s.watched(978), "startup preserves native watches and imports legacy watches")
    equal(s.env.Questie.db.char.trackedAchievementIds, nil, "successful legacy import removes obsolete saved data")
    equal(s.removes, 0, "startup never removes existing native watches")
    equal(s.uiLoads, 0, "startup does not load the achievement UI")
    local adds = s.adds
    ok, message = coroutine.resume(coroutine.create(s.tracker.Initialize))
    assert(ok, message)
    equal(s.adds, adds, "repeat tracker initialization does not reimport watches")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({973}, {[978] = true}, {skipHook = true})
    local loader = s.env.QuestieLoader
    loader:ImportModule("TrackerNearestQuestItem").Initialize = noop
    loader:ImportModule("TrackerNearestQuestItem").SetupKeybinding = noop
    s.env.Questie.db.profile.trackerEnabled = false
    local ok, message = coroutine.resume(coroutine.create(s.tracker.Initialize))
    assert(ok, message)
    s.settle()
    equal(s.tracker.started, nil, "disabled startup does not initialize the Questie tracker")
    assert(s.watched(973) and s.watched(978), "disabled startup imports legacy watches for Blizzard")
    equal(s.env.Questie.db.char.trackedAchievementIds, nil, "disabled startup consumes successful legacy imports")
    equal(#s.queued, 0, "disabled startup imports do not enqueue tracker work")
    equal(s.env.WATCHFRAME_OBJECTIVEHANDLERS[2], s.nativeHandler, "disabled startup preserves the native handler")
    s.env.WatchFrame_Update()
    equal(s.visibleAchievementRows, 2, "Blizzard displays both watches when Questie starts disabled")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({973}, {[973] = true, [978] = true, [979] = false, [980] = true, [9999] = true, [0] = true,
        [-1] = true, bad = true}, {completed = {[980] = true}})
    s.controller.Initialize()
    assert(s.watched(973) and s.watched(978), "migration merges legacy and native watches")
    equal(s.adds, 1, "migration never re-adds a legacy ID already watched natively")
    assert(not s.watched(979) and not s.watched(980), "false and completed legacy entries are not imported")
    equal(s.saved[9999], true, "unresolved legacy watch remains available for a later login")
    for _, id in ipairs({973, 978, 979, 980, 0, -1, "bad"}) do
        equal(s.saved[id], nil, "imported or invalid legacy entry removed: " .. id)
    end
    s.tracker:UntrackAchieveId(978)
    s.controller.Initialize()
    equal(s.watched(978), nil, "repeat initialization cannot re-add a deliberately untracked imported watch")
    s.settle()
    groups = groups + 1
end
for _, enabled in ipairs({true, false}) do
    local ids = {}
    for id = 1, 10 do ids[id] = id end
    local s = setup(ids, {[978] = true})
    s.controller.Initialize()
    equal(s.saved[978], true, "full native watch list defers a legacy import")
    s.tracker:UntrackAchieveId(1)
    s.settle()
    s.env.Questie.db.profile.trackerEnabled = enabled
    s.env.AddTrackedAchievement(978)
    equal(s.saved[978], nil, "manual native tracking consumes a deferred legacy entry while enabled=" .. tostring(enabled))
    equal(s.env.Questie.db.char.trackedAchievementIds, nil, "consuming the last deferred entry clears legacy storage")
    s.env.RemoveTrackedAchievement(978)
    s.settle()
    local nextLogin = setup({s.env.GetTrackedAchievements()}, s.env.Questie.db.char.trackedAchievementIds)
    nextLogin.controller.Initialize()
    equal(nextLogin.watched(978), nil, "manually untracked deferred achievement stays untracked after login")
    groups = groups + 1
end
do
    local s = setup(nil, nil, {skipHook = true})
    s.tracker:UpdateAchieveTrackerCache(978)
    equal(#s.queued, 0, "pre-initialization events do not leave a pending tracker refresh")
    s.tracker.started = true
    s.env.AddTrackedAchievement(978)
    equal(#s.queued, 1, "first initialized watch event can still queue a refresh")
    s.settle()
    equal(s.updates, 1, "pre-initialization events do not suppress later redraws")
    groups = groups + 1
end
do
    local ids = {}
    for i = 1, 9 do ids[i] = i end
    local s = setup(ids, {[978] = true, [979] = true})
    s.controller.Initialize()
    equal(s.env.GetNumTrackedAchievements(), 10, "migration honors native ten-watch capacity")
    assert(s.watched(978) and not s.watched(979), "migration uses deterministic order for the last available slot")
    equal(s.saved[978], nil, "successfully imported last-slot watch is consumed")
    equal(s.saved[979], true, "over-cap legacy watch remains for a later login")
    s.tracker:UntrackAchieveId(978)
    s.controller.Initialize()
    equal(s.watched(979), nil, "profile or repeat initialization does not import deferred watches mid-session")
    local nextLogin = setup({1}, s.saved)
    nextLogin.controller.Initialize()
    equal(nextLogin.watched(979), true, "remaining legacy watch imports on a later login")
    equal(nextLogin.env.Questie.db.char.trackedAchievementIds, nil, "later successful migration finishes cleanup")
    groups = groups + 1
end
for _, malformed in ipairs({false, "invalid", 123}) do
    local s = setup({973})
    s.env.Questie.db.char.trackedAchievementIds = malformed
    s.controller.Initialize()
    equal(s.watched(973), true, "malformed legacy data does not remove a native watch")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup()
    s.env.AchievementFrame_LoadUI()
    s.uiShown = true
    s.env.AddTrackedAchievement(978)
    s.env.AddTrackedAchievement(978)
    s.tracker:TrackAchieve(978)
    equal(s.watched(978), true, "programmatic tracking works with the achievement UI open")
    equal(s.env.GetNumTrackedAchievements(), 1, "repeat native adds and public adds are idempotent")
    equal(s.removes, 0, "repeat adds never toggle a watch off")
    equal(#s.timers, 0, "native watch updates need no delayed cache timers")
    equal(#s.queued, 1, "native watch event queues a single combat-safe redraw")
    s.settle()
    equal(s.updates, 1, "queued native watch change redraws once")
    local snapshot = s.controller.GetTrackedIds()
    snapshot[978] = nil
    equal(s.watched(978), true, "renderer snapshots do not own native watch state")
    s.native[979] = true
    equal(s.watched(979), true, "renderer reads current native watches without a prior cache event")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({978})
    s.env.RemoveTrackedAchievement(978)
    equal(s.watched(978), nil, "native UI untrack is immediately visible to the renderer")
    s.tracker:TrackAchieve(978)
    equal(s.watched(978), true, "public tracker API can retrack natively")
    s.tracker:UntrackAchieveId(978)
    s.tracker:UntrackAchieveId(978)
    equal(s.removes, 2, "repeated public untrack does not call native removal twice")
    equal(s.watched(978), nil, "public untrack clears the native watch")
    equal(#s.queued, 1, "untrack/retrack burst coalesces into one redraw")
    s.settle()
    equal(s.updates, 1, "watch burst redraws once after combat queue settles")
    groups = groups + 1
end
do
    local s = setup({978})
    s.completed[978] = true
    s.tracker:UntrackAchieveId(978) -- ACHIEVEMENT_EARNED uses this public wrapper.
    s.tracker:UpdateAchieveTrackerCache(978)
    equal(s.env.GetNumTrackedAchievements(), 0, "completion cleanup removes the native watch")
    s.tracker:TrackAchieve(978)
    equal(s.watched(978), nil, "native API rejects retracking a completed achievement")
    s.settle()
    equal(s.updates, 1, "earned and watch-list notifications coalesce")
    groups = groups + 1
end
do
    local ids = {}
    for id = 1, 10 do ids[id] = id end
    local s = setup(ids)
    s.tracker:TrackAchieve(978)
    equal(s.env.GetNumTrackedAchievements(), 10, "native API remains authoritative for the tracking limit")
    equal(s.watched(978), nil, "eleventh watch is not fabricated in a private cache")
    s.tracker:TrackAchieve(0); s.tracker:UntrackAchieveId(0)
    equal(s.removes, 0, "invalid untrack request never reaches the native API")
    groups = groups + 1
end
do
    local s = setup()
    local char = s.env.Questie.db.char
    char.collapsedQuests[978], char.collapsedZones.Achievements = true, true
    s.env.AddTrackedAchievement(978)
    assert(not char.collapsedQuests[978] and not char.collapsedZones.Achievements,
        "newly tracked achievement and section expand")
    char.collapsedQuests[978], char.collapsedZones.Achievements = true, true
    s.tracker:UpdateAchieveTrackerCache(978)
    assert(char.collapsedQuests[978] and char.collapsedZones.Achievements,
        "criteria or timed progress preserves intentionally collapsed rows")
    s.settle()
    groups = groups + 1
end
for _, disable in ipairs({"profile", "hooks"}) do
    local s = setup()
    s.env.AddTrackedAchievement(978)
    if disable == "profile" then s.env.Questie.db.profile.trackerEnabled = false
    else s.tracker:Unhook() end
    s.settle()
    equal(s.updates, 0, disable .. " disabling before queued work prevents a stale redraw")
    equal(s.watched(978), true, disable .. " disabling preserves native watches")
    s.env.Questie.db.profile = {trackerEnabled = false}
    s.env.AddTrackedAchievement(979)
    equal(s.watched(979), true, "native watches work while the Questie tracker is disabled")
    equal(#s.queued, 0, "disabled tracker does not queue watch redraws")
    s.env.Questie.db.profile.trackerEnabled, s.tracker.disableHooks = true, nil
    s.tracker:UpdateAchieveTrackerCache(979)
    s.settle()
    equal(s.updates, 1, "reenabling can queue a fresh native-watch redraw")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({978}, {[979] = true})
    s.tracker:Disable()
    equal(s.watched(978), true, "tracker Disable preserves the game's achievement watch")
    equal(s.saved[979], true, "tracker Disable does not discard unimported legacy watches")
    s.tracker:Unhook()
    equal(s.env.WATCHFRAME_OBJECTIVEHANDLERS[2], s.nativeHandler, "unhook restores Blizzard's native achievement display")
    equal(s.visibleAchievementRows, 1, "restored native watch frame can display the retained watch")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({973, 978}, nil, {skipHook = true})
    s.env.WatchFrame_Update()
    equal(s.visibleAchievementRows, 2, "fixture starts with native achievement rows")
    s.tracker:HookBaseTracker()
    equal(s.visibleAchievementRows, 0, "presentation replacement clears previously visible achievement rows")
    local display = s.displayCalls[#s.displayCalls]
    equal(display.count, 0, "hidden achievement renderer receives zero IDs")
    assert(display.line == "watch-line" and display.offset == 12 and display.height == 300 and display.width == 200,
        "hidden renderer retains WatchFrame layout arguments")
    local handlers = s.env.WATCHFRAME_OBJECTIVEHANDLERS
    assert(handlers[1] == s.questHandler and handlers[3] == s.timerHandler and handlers[4] == s.otherHandler,
        "presentation replacement preserves quest, timer and other-addon handlers")
    local offset, rows, width = handlers[2]("watch-line", 12, 300, 200)
    assert(offset == 12 and rows == 0 and width == 200, "hidden renderer preserves native display return values")
    assert(s.questDisplays > 0 and s.timerDisplays > 0, "quest and timer handlers remain active")
    equal(s.env.GetNumTrackedAchievements(), 2, "hidden presentation leaves native watches intact")
    equal(s.hooks.AddTrackedAchievement, nil, "native achievement add function has no Questie secure hook")
    equal(s.hooks.RemoveTrackedAchievement, nil, "native achievement remove function has no Questie secure hook")
    local calls = s.watchUpdates
    s.controller.HideBlizzardAchievements()
    equal(s.watchUpdates, calls, "repeated presentation installation is idempotent")
    s.tracker:Unhook()
    equal(handlers[2], s.nativeHandler, "unhook restores the native handler")
    equal(s.visibleAchievementRows, 2, "unhook restores native achievement rows")
    s.tracker:HookBaseTracker()
    equal(s.visibleAchievementRows, 0, "rehooking hides only achievement rows again")
    equal(s.hooks.AddQuestWatch, 1, "rehooking preserves the existing quest secure-hook lifecycle")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({978})
    local handlers = s.env.WATCHFRAME_OBJECTIVEHANDLERS
    local thirdParty = function() end
    handlers[2] = thirdParty
    s.controller.RestoreBlizzardAchievements()
    equal(handlers[2], thirdParty, "restoration never overwrites another addon's replacement handler")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup()
    for _, name in ipairs({"UpdateAchieveTrackerCache", "UntrackAchieveId", "TrackAchieve"}) do
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
do
    local s = setup({978})
    s.env.Questie.db.char.trackedAchievementIds = nil
    local char = s.env.Questie.db.char
    char.collapsedQuests[978], char.collapsedZones.Achievements = true, true
    installAchievementEvents(s)
    s.fire("CRITERIA_UPDATE"); s.fire("CRITERIA_UPDATE"); s.fire("CRITERIA_UPDATE")
    equal(#s.timers, 1, "native-only criterion burst starts one settling timer without legacy saved data")
    equal(s.timers[1].delay, 0.1, "criterion refresh retains its short settling delay")
    equal(#s.queued, 0, "criterion refresh waits for criteria state to settle")
    table.remove(s.timers, 1).callback()
    equal(#s.queued, 1, "settled criterion event queues one combat-safe tracker refresh")
    equal(s.updates, 0, "criterion refresh waits for the combat queue")
    s.settle()
    equal(s.updates, 1, "criterion burst redraws native watches once")
    assert(char.collapsedQuests[978] and char.collapsedZones.Achievements,
        "criterion progress leaves intentionally collapsed native watches closed")
    equal(s.availabilityUpdates, 0, "ordinary criterion progress does not redraw available quests")
    groups = groups + 1
end
for _, reason in ipairs({"untracked", "disabled"}) do
    local s = setup(reason == "disabled" and {978} or {})
    s.env.Questie.db.char.trackedAchievementIds = nil
    if reason == "disabled" then s.env.Questie.db.profile.trackerEnabled = false end
    installAchievementEvents(s)
    s.fire("CRITERIA_UPDATE")
    equal(#s.timers, 0, reason .. " criterion event starts no timer")
    equal(#s.queued, 0, reason .. " criterion event queues no refresh")
    equal(s.updates, 0, reason .. " criterion event causes no redraw")
    groups = groups + 1
end
do
    local s = setup({978})
    installAchievementEvents(s)
    s.fire("CRITERIA_UPDATE")
    s.env.Questie.db.profile.trackerEnabled = false
    s.settle()
    equal(s.updates, 0, "disabling during criterion settling prevents a stale tracker redraw")
    equal(#s.queued, 0, "disabled settled criterion event leaves no combat work")
    groups = groups + 1
end
do
    local s = setup({978})
    installAchievementEvents(s)
    s.completed[978] = true
    s.fire("ACHIEVEMENT_EARNED", 978, false)
    equal(s.removes, 1, "earned event explicitly untracks the native achievement")
    equal(s.watched(978), nil, "earned native achievement is absent from rendering")
    equal(s.availabilityUpdates, 1, "earned event preserves AzerothCore quest availability refresh")
    equal(s.uiLoads, 1, "earned event can initialize Blizzard achievement UI")
    equal(s.uiUpdates, 1, "earned event refreshes Blizzard achievement UI")
    equal(#s.queued, 1, "earned and native update notifications coalesce into one refresh")
    s.settle()
    equal(s.updates, 1, "earned event redraws the Questie tracker once")
    groups = groups + 1
end
do
    local s = setup()
    installAchievementEvents(s)
    s.events.TRACKED_ACHIEVEMENT_LIST_CHANGED = function() error("Wrath UPDATE-only path must not require LIST_CHANGED") end
    local char = s.env.Questie.db.char
    char.collapsedQuests[978], char.collapsedZones.Achievements = true, true
    s.env.AddTrackedAchievement(978)
    equal(s.watched(978), true, "UPDATE-only watch event exposes newly tracked native achievements")
    equal(#s.queued, 1, "UPDATE-only watch event queues a tracker refresh")
    assert(not char.collapsedQuests[978] and not char.collapsedZones.Achievements,
        "UPDATE-only membership addition expands newly tracked rows")
    s.settle()
    char.collapsedQuests[978], char.collapsedZones.Achievements = true, true
    s.fire("TRACKED_ACHIEVEMENT_UPDATE", 978)
    assert(char.collapsedQuests[978] and char.collapsedZones.Achievements,
        "UPDATE-only progress keeps manually collapsed rows closed")
    s.settle()
    equal(s.updates, 2, "native membership and later timed progress both refresh")
    s.env.RemoveTrackedAchievement(978)
    s.env.AddTrackedAchievement(978)
    assert(not char.collapsedQuests[978] and not char.collapsedZones.Achievements,
        "UPDATE-only untrack and retrack recognizes new membership again")
    s.settle()
    equal(s.updates, 3, "UPDATE-only untrack/retrack burst coalesces")
    groups = groups + 1
end
for _, withQuest in ipairs({false, true}) do
    local s = setup({978})
    local d = installDragonUI(s, withQuest)
    d.tracker.Refresh()
    assert(d.has("achievement") and d.has("quest") == withQuest,
        "DragonUI initially collects native watches independently of Questie")
    s.controller.RefreshDragonUI()
    assert(not d.has("achievement") and not d.has("quest"),
        "DragonUI cannot duplicate Questie's quest or achievement rows with quests=" .. tostring(withQuest))
    assert(not d.has("timer") and d.has("recipe") and d.has("other"),
        "default timer preference hides only matching rows and preserves other collectors")
    equal(#d.collectors, 1, "late DragonUI availability installs one collector")
    for _ = 1, 3 do s.controller.RefreshDragonUI() end
    equal(#d.collectors, 1, "repeated DragonUI refreshes do not duplicate the collector")
    equal(#d.source, withQuest and 5 or 4, "filter leaves DragonUI source records intact")
    equal(s.env.GetNumTrackedAchievements(), 1, "DragonUI filtering preserves native achievement count")
    equal(s.removes, 0, "DragonUI filtering never removes native watches")
    s.nativeQueriesUnchanged()

    d.enabled = false
    s.controller.RefreshDragonUI()
    equal(#d.blocks, 0, "disabled DragonUI module has no displayed rows")
    d.enabled = true
    d.tracker.Refresh()
    assert(not d.has("quest") and not d.has("achievement"), "re-enabled DragonUI module retains the filter")
    equal(#d.collectors, 1, "DragonUI module re-enable does not register another collector")

    s.env.Questie.db.profile = {trackerEnabled = false}
    s.controller.RefreshDragonUI()
    assert(d.has("achievement") and d.has("timer") and d.has("quest") == withQuest,
        "disabled Questie profile restores DragonUI's native rows")
    s.env.Questie.db.profile.trackerEnabled = true
    s.controller.RefreshDragonUI()
    assert(not d.has("quest") and not d.has("achievement"), "re-enabled Questie profile reapplies the collector dynamically")
    s.tracker:Unhook()
    assert(d.has("achievement") and d.has("timer") and d.has("quest") == withQuest,
        "unhooking Questie refreshes DragonUI with native rows restored")
    s.tracker:HookBaseTracker()
    assert(not d.has("achievement") and not d.has("quest"), "rehooking Questie refreshes DragonUI without duplicates")
    equal(#d.collectors, 1, "Questie hook lifecycle keeps a single DragonUI collector")
    groups = groups + 1
end
do
    local s = setup({978})
    local d = installDragonUI(s, true)
    s.controller.RefreshDragonUI()
    local settings = {enabled = true}
    s.env.DragonUI.db = {profile = {questtracker = settings}}
    local watch = {shown = true}
    function watch:Show() self.shown = true end
    function watch:Hide() self.shown = false end
    s.env.WatchFrame = watch
    loadModule("Modules/Tracker/TrackerQuestTimers.lua", s.env)
    local timers = s.env.QuestieLoader:ImportModule("TrackerQuestTimers")
    local profile = s.env.Questie.db.profile
    profile.showBlizzardQuestTimer = true
    local refreshed = d.refreshes
    timers:ShowBlizzardTimer()
    assert(watch.shown and d.has("timer"), "real ShowBlizzardTimer restores the native timer in DragonUI")
    assert(not d.has("quest") and not d.has("achievement"), "showing Blizzard timers does not restore duplicate tracker rows")
    assert(d.refreshes > refreshed, "real ShowBlizzardTimer refreshes DragonUI")
    profile.showBlizzardQuestTimer = false
    refreshed = d.refreshes
    timers:HideBlizzardTimer()
    assert(not watch.shown and not d.has("timer"), "real HideBlizzardTimer removes the DragonUI timer row")
    assert(d.refreshes > refreshed, "real HideBlizzardTimer refreshes DragonUI")
    assert(d.has("recipe") and d.has("other"), "timer toggles preserve recipe and third-party rows")
    profile.trackerEnabled = false
    timers:ShowBlizzardTimer()
    assert(d.has("quest") and d.has("achievement") and d.has("timer"),
        "disabling Questie restores all DragonUI rows regardless of Questie's timer preference")
    equal(s.env.DragonUI.db.profile.questtracker, settings, "compatibility never replaces DragonUI settings")
    equal(settings.enabled, true, "compatibility never disables DragonUI's tracker setting")
    equal(#d.collectors, 1, "real timer toggles keep one DragonUI collector")
    equal(s.watched(978), true, "real timer toggles preserve native achievement membership")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
do
    local s = setup({978}, nil, {skipHook = true})
    local d = installDragonUI(s, true)
    s.controller.RefreshDragonUI()
    assert(d.has("quest") and d.has("achievement") and d.has("timer"),
        "DragonUI remains intact before Questie starts")
    s.tracker.started = true
    d.tracker.Refresh()
    assert(not d.has("quest") and not d.has("achievement"), "collector reads tracker startup state dynamically")
    local previous = d
    d = installDragonUI(s, false)
    s.controller.RefreshDragonUI()
    s.controller.RefreshDragonUI()
    equal(#previous.collectors, 1, "replaced DragonUI tracker retains its original collector only")
    equal(#d.collectors, 1, "replacement DragonUI tracker receives exactly one collector")
    assert(not d.has("achievement") and d.has("recipe"), "replacement public tracker is filtered correctly")
    groups = groups + 1
end
for _, unsupported in ipairs({"missing", "empty", "legacy"}) do
    local s = setup({978})
    local refreshes = 0
    if unsupported == "missing" then s.env.DragonUI = nil
    elseif unsupported == "empty" then s.env.DragonUI = {}
    else s.env.DragonUI = {ObjectiveTracker = {Refresh = function() refreshes = refreshes + 1 end}} end
    s.controller.RefreshDragonUI()
    s.controller.HideBlizzardAchievements()
    s.tracker:Unhook()
    equal(refreshes, 0, "unsupported DragonUI API is skipped: " .. unsupported)
    equal(s.watched(978), true, "unsupported DragonUI API does not alter native watches")
    s.nativeQueriesUnchanged()
    groups = groups + 1
end
print("Native achievement tracking regressions passed (" .. groups .. " groups)")
