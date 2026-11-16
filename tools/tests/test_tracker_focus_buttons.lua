-- Run from the addon root with Lua 5.1 or 5.2+. Exercise the native tracker focus button.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function setup()
    local env, modules = setmetatable({}, {__index = _G}), {}
    env._G = env
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end, StampLoadBoundary = function() end}
    local s = {env = env, modules = modules, native = true, quests = {}, queued = {},
        focuses = 0, unfocuses = 0, refreshes = 0, mapCalls = 0, updates = 0, unfades = 0, fades = 0}
    s.profile = {trackerShowQuestFocusButtons = true, trackerFadeQuestFocusButtons = false, trackerFontSizeQuest = 12}
    s.char = {}
    env.Questie = {db = {profile = s.profile, char = s.char}}
    env.QuestieCompat = {C_Timer = {}, WorldMapFrame = {IsShown = function() return s.mapOpen == true end}}
    -- A global modern frame must not override the native compatibility adapter.
    env.WorldMapFrame = {IsShown = function() error("use the compatibility map frame") end}
    env.GameTooltip = {SetOwner = function(_, owner, anchor) s.tipOwner, s.tipAnchor = owner, anchor end,
        SetText = function(_, text) s.tipText = text end, Show = function() s.tipShown = true end,
        Hide = function() s.tipShown = false end}
    s.quest = {Id = 100, name = "Quest 100", located = true, state = 0, IsComplete = function(self) return self.state end}
    s.quests[100] = s.quest
    module("QuestiePlayer").currentQuestlog = s.quests
    module("TrackerData").ContainsQuest = function(id) return s.quests[id] ~= nil and s.native end
    module("TrackerData").GetQuest = function(id) return s.quests[id] end
    module("QuestieMap").GetNearestQuestSpawn = function(_, quest)
        s.locationReads = (s.locationReads or 0) + 1
        if quest.located then
            if quest.state == 1 then return {60, 70}, 13, "Finisher" end
            return {50, 50}, 12, quest.name
        end
    end
    module("TrackerUtils").FocusQuest = function(_, id)
        s.focuses = s.focuses + 1
        s.char.TrackerFocus = id -- The fork's real method deliberately returns nil.
    end
    module("TrackerUtils").UnFocus = function() s.unfocuses = s.unfocuses + 1; s.char.TrackerFocus = nil end
    module("TrackerUtils").ShowQuestOnMap = function(_, quest)
        equal(quest, s.quest, "map action retains quest identity")
        s.mapCalls = s.mapCalls + 1
    end
    module("QuestieQuest").RefreshQuestIconVisibility = function() s.refreshes = s.refreshes + 1 end
    module("QuestieTracker").Update = function(_, force)
        equal(force, true, "button bypasses the normal layout throttle")
        s.updates = s.updates + 1
    end
    module("QuestieCombatQueue").Queue = function(_, callback) s.queued[#s.queued + 1] = callback end
    module("TrackerFadeTicker").Unfade = function() s.unfades = s.unfades + 1 end
    module("TrackerFadeTicker").Fade = function() s.fades = s.fades + 1 end
    module("QuestieLib").AddonPath = "Interface\\AddOns\\Questie-335\\"
    setmetatable(module("l10n"), {__call = function(_, text) return text end})
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/Quest/Lifecycle/QuestLifecycle.lua")
    module("ZoneDB").GetUiMapIdByAreaId = function(_, zone) return zone + 1000 end
    env.QuestieCompat.UiMapData = {[1012] = {}, [1013] = {}}
    env.QuestieCompat.GetLegacyMapContinentAndZone = function(id) return 1, id - 1000 end
    loadModule("Compat/TomTom.lua")
    loadModule("Modules/Tracker/TrackerWaypoints.lua")
    local waypoints = module("TrackerWaypoints")
    module("TrackerUtils").SetTomTomTarget = waypoints.SetTomTomTarget
    module("TrackerUtils").ClearTomTomTargetForQuest = waypoints.ClearTomTomTargetForQuest
    loadModule("Modules/Tracker/QuestFocusButton.lua")
    s.control, s.lifecycle = modules.QuestFocusButton, modules.QuestLifecycle
    s.button = {parent = {}, scripts = {}, alpha = 1, shown = false, texture = {
        SetTexture = function(_, path) s.texture = path end},
        RegisterForClicks = function(_, event) s.clickEvent = event end,
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        SetWidth = function(self, width) self.width = width end,
        SetHeight = function(self, height) self.height = height end,
        GetParent = function(self) return self.parent end,
        SetHighlightTexture = function(self, texture, mode) self.highlightTexture, self.highlightMode = texture, mode end,
        ClearAllPoints = function(self) self.point = nil end,
        SetPoint = function(self, ...) self.point = {...} end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        EnableMouse = function(self, value) self.mouse = value end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end}
    s.control.Configure(s.button)
    function s:render(complete) self.control.SetQuest(self.button, self.quest, complete) end
    function s:click() self.button.scripts.OnClick(self.button) end
    function s:drain() while #self.queued > 0 do table.remove(self.queued, 1)() end end
    function s:enableTomTom()
        self.added, self.removed = {}, {}
        local uid = 100
        env.TomTom = {waypoints = {}, AddWaypoint = function() end}
        function env.TomTom:AddZWaypoint(...)
            local call = {...}
            s.added[#s.added + 1] = call
            uid = uid + 1
            self.waypoints[uid] = {zone = call[2], coord = call[3] .. "," .. call[4], title = call[5]}
            return uid
        end
        function env.TomTom:RemoveWaypoint(id)
            s.removed[#s.removed + 1] = id
            self.waypoints[id] = nil
        end
    end
    return s
end

local groups = 0
do
    local s = setup()
    equal(s.control.GetColumnWidth(), 17, "focus column includes icon and gap")
    equal(s.clickEvent, "LeftButtonUp", "native left-button release activates focus")
    for _, complete in ipairs({false, true}) do
        for _, focused in ipairs({false, true}) do
            s.char.TrackerFocus = focused and 100 or nil
            s:render(complete)
            local name = "poi_" .. (complete and "complete" or "incomplete") .. (focused and "_focused" or "") .. ".blp"
            equal(s.texture, s.modules.QuestieLib.AddonPath .. "Icons\\" .. name, "four-state focus texture")
            equal(s.button.highlightTexture, s.texture, "hover highlights the current focus icon itself")
            equal(s.button.highlightMode, "ADD", "native additive hover keeps the focus icon shape")
        end
    end
    equal(s.button.width, 15, "focus button follows quest font size")
    equal(s.button.point[1], "TOPLEFT", "focus column uses title parent anchor")
    equal(s.button.point[2], s.button.parent, "button is anchored inside its pooled line")
    s.profile.trackerShowQuestFocusButtons = false
    s:render(false)
    equal(s.control.GetColumnWidth(), 0, "disabled focus control reserves no column")
    assert(not s.button.shown and not s.button.mouse and not s.button.isFocusButton, "disabled control is inert")
    equal(s.button.questId, nil, "disabled control clears stale quest ID")
    groups = groups + 1
end
do
    local s = setup()
    s:render(false); s:click()
    equal(s.char.TrackerFocus, 100, "nil-returning FocusQuest still toggles focus on")
    equal(s.mapCalls, 0, "focusing keeps a closed map closed")
    equal(s.refreshes, 1, "focus refreshes existing icons")
    equal(s.updates, 0, "tracker redraw is queued")
    s:drain(); equal(s.updates, 1, "focus forces a tracker redraw")
    s:click(); s:drain()
    equal(s.char.TrackerFocus, nil, "second click unfocuses")
    equal(s.unfocuses, 1, "unfocus runs once")
    s.char.TrackerFocus, s.mapOpen = "100 1", true
    s:render(false); s:click(); s:drain()
    equal(s.char.TrackerFocus, 100, "objective focus switches to whole-quest focus")
    equal(s.mapCalls, 1, "new focus navigates and flashes an already-open map")
    s:click()
    equal(s.mapCalls, 1, "unfocusing does not navigate the map")
    groups = groups + 1
end
for _, change in ipairs({"removed", "native-missing", "reaccepted", "replaced", "failed", "location-lost", "disabled"}) do
    local s = setup()
    s:enableTomTom()
    s:render(false)
    if change == "removed" then s.quests[100] = nil
    elseif change == "native-missing" then s.native = false
    elseif change == "reaccepted" then s.lifecycle.InvalidateQuestWork(100); s.lifecycle.GetAcceptance(100)
    elseif change == "replaced" then s.quests[100] = {Id = 100}
    elseif change == "failed" then s.quest.state = -1
    elseif change == "disabled" then s.profile.trackerShowQuestFocusButtons = false
    else s.quest.located = false end
    s:click(); s:drain()
    equal(s.focuses, 0, "stale button cannot focus after " .. change)
    equal(s.refreshes, 0, "stale button cannot refresh after " .. change)
    equal(s.updates, 0, "stale button cannot redraw after " .. change)
    equal(#s.added, 0, "stale button cannot set a waypoint after " .. change)
    groups = groups + 1
end
for _, change in ipairs({"native-only", "unlocated", "failed", "removed"}) do
    local s = setup()
    if change == "native-only" then s.quest.NativeOnly = true
    elseif change == "unlocated" then s.quest.located = false
    elseif change == "failed" then s.quest.state = -1
    else s.native = false end
    s:render(false)
    assert(not s.button.shown and not s.button.mouse, "ineligible button stays hidden: " .. change)
    equal(s.button.expectedQuest, nil, "ineligible button clears captured quest: " .. change)
    groups = groups + 1
end
do
    local s = setup()
    s.char.TrackerFocus, s.quest.located, s.quest.state = 100, false, -1
    s:render(false)
    assert(s.button.shown and s.button.mouse, "current focus can be cleared without a remaining map target")
    s:click()
    equal(s.char.TrackerFocus, nil, "unavailable focused quest can be unfocused")
    assert(not s.button.shown and not s.button.mouse, "unfocused unavailable quest becomes inert")
    groups = groups + 1
end
do
    local s = setup()
    s.profile.trackerFadeQuestFocusButtons = true
    s:render(false)
    equal(s.button.alpha, 0, "new fading button starts transparent")
    s.button.alpha = 0.4
    s:render(true)
    equal(s.button.alpha, 0.4, "rerender does not restart a fade in progress")
    s.button:Hide()
    s.button.questId, s.button.expectedQuest, s.button.acceptance = nil, nil, nil
    s:render(false)
    equal(s.button.alpha, 0.4, "layout reset preserves independent fade progress")
    s.button.scripts.OnEnter(s.button)
    equal(s.tipText, "Focus Quest", "hover describes whole-quest focus")
    equal(s.unfades, 1, "hover unfades tracker controls")
    s.char.TrackerFocus = 100
    s.button.scripts.OnEnter(s.button)
    equal(s.tipText, "Unfocus", "focused hover offers unfocus")
    s.button.scripts.OnLeave(s.button)
    assert(not s.tipShown and s.fades == 1, "leaving hides tooltip and starts fading")
    s.profile.trackerFadeQuestFocusButtons = false
    s:render(false)
    equal(s.button.alpha, 1, "disabling fading restores opaque focus button")
    groups = groups + 1
end
for _, complete in ipairs({false, true}) do
    local s = setup()
    s:enableTomTom()
    s.quest.state = complete and 1 or 0
    s:render(complete); s:click()
    local call = s.added[1]
    equal(call[2], complete and 13 or 12, "focus targets objective or finisher zone")
    equal(call[3], complete and 60 or 50, "focus passes native x coordinate")
    equal(call[4], complete and 70 or 50, "focus passes native y coordinate")
    equal(call[11], true, "native TomTom adapter enables the arrow")
    equal(s.char._tom_waypoint_source, "questFocus", "focus waypoint has its own source")
    equal(s.char._tom_waypoint_quest.questId, 100, "focus waypoint retains quest association")
    equal(s.mapCalls, 0, "TomTom focus keeps a closed world map closed")
    local uid = s.char._tom_waypoint
    s.env.TomTom.waypoints[999] = {zone = 12, coord = "1,2", title = "Unrelated"}
    s:click()
    equal(s.removed[1], uid, "unfocus clears its focus waypoint")
    assert(s.env.TomTom.waypoints[999], "unfocus preserves unrelated TomTom waypoints")
    equal(s.char._tom_waypoint, nil, "unfocus forgets focus target")
    groups = groups + 1
end
for _, source in ipairs({"manual", "autoRoute", "questFocus"}) do
    local s = setup()
    s:enableTomTom()
    s:render(false); s:click()
    s.modules.TrackerUtils:SetTomTomTarget("Replacement", 12, 10, 20, source == "questFocus" and 200 or 100, nil, source)
    local replacement, removed = s.char._tom_waypoint, #s.removed
    s:click()
    equal(#s.removed, removed, "unfocus preserves a replacement from " .. source)
    equal(s.char._tom_waypoint, replacement, "replacement ownership survives unfocus")
    groups = groups + 1
end
do
    local s = setup()
    s:enableTomTom()
    s:render(false); s:click()
    local first = s.char._tom_waypoint
    s.quest = {Id = 200, name = "Quest 200", located = true, state = 0, IsComplete = function(self) return self.state end}
    s.quests[200] = s.quest
    s:render(false); s:click()
    equal(s.removed[1], first, "switching focus removes the previous Questie waypoint")
    equal(s.char._tom_waypoint_quest.questId, 200, "switching focus targets the new quest")
    equal(#s.added, 2, "switching focus creates one waypoint per selection")
    groups = groups + 1
end
print("Tracker focus buttons: " .. groups .. " groups passed (textures, clicks, native ownership, fading and TomTom)")
