-- Run from the addon root with Lua 5.1 or 5.2+. Exercise real tracker menus and map flashing.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local function setup()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local modules = {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    local s = {env = env, modules = modules, time = 0, timers = {}, afters = {}, icons = {},
        quests = {}, native = {}, toggles = 0, refreshes = 0, mapShows = 0, soloCalls = {}}
    s.char = {TrackerHiddenQuests = {}, TrackerHiddenObjectives = {}, collapsedQuests = {}, AutoUntrackedQuests = {}}
    env.Questie = {db = {profile = {}, char = s.char}, Debug = noop, SendMessage = noop}
    env.QuestLogListScrollFrame = {ScrollBar = {}}
    env.IsAddOnLoaded = function() return false end
    local timer = {}
    function timer.NewTicker(_, callback)
        local ticker = {callback = callback, Cancel = function(self) self.cancelled = true end}
        s.timers[#s.timers + 1] = ticker
        return ticker
    end
    function timer.After(delay, callback) s.afters[#s.afters + 1] = {due = s.time + delay, callback = callback} end
    env.QuestieCompat = {C_Timer = timer, C_Map = {}, GetQuestLogIndexByID = function(id) return s.native[id] and 1 end,
        HBDPins = {UpdateWorldMap = function()
            s.refreshes = s.refreshes + 1
            for _, icon in ipairs(s.icons) do if icon.offMap then icon.texture:Hide() end end
        end},
        WorldMapFrame = {Show = function() s.mapShows = s.mapShows + 1 end,
            SetMapID = function(_, id) s.mapId = id end},
        LibUIDropDownMenu = {Create_UIDropDownMenu = function() return {} end, CloseDropDownMenus = noop}}
    setmetatable(module("l10n"), {__call = function(_, text) return text end})
    module("QuestieLib").GetColoredQuestName = function(_, id) return "Quest " .. id end
    module("ZoneDB").GetUiMapIdByAreaId = function(_, id) return id + 1000 end
    module("TrackerData").GetQuest = function(id) return s.quests[id] end
    module("TrackerData").ContainsQuest = function(id) return s.native[id] == true end
    module("QuestiePlayer").currentQuestlog = s.quests
    module("QuestieDB").GetQuest = function(id) return s.quests[id] or s.quest end
    module("QuestieDB").QueryQuestSingle = noop
    module("QuestLogCache").TryGetQuest = function(id) return s.native[id] and {} end
    local questModule = module("QuestieQuest")
    questModule.ToggleQuestNotes = function(show) equal(show, true, "show action reveals notes"); s.toggles = s.toggles + 1 end
    questModule.ClearLootedSpawns, questModule.PopulateQuestLogInfo, questModule.PopulateObjectiveNotes = noop, noop, noop
    module("QuestieTooltips").RemoveQuest = noop
    module("QuestieCombatQueue").Queue = function(_, callback) callback() end
    module("QuestieTracker").Update, module("QuestieTracker").RemoveQuest = noop, noop
    module("CommsVisibility").ScheduleSnapshot = noop
    module("AutoRoute").ScheduleUpdate = noop
    module("AvailableQuests").RemoveQuest = function(_, callback) if callback then callback() end end
    module("AvailableQuests").CalculateAndDrawAll = noop
    module("QuestieWaypoints").SetSolo = function(data) s.solo = data; s.soloCalls[#s.soloCalls + 1] = data or false end
    local map = module("QuestieMap")
    map.questIdFrames = {}
    map.GetFramesForQuest = function(_, id)
        local frames = {}
        for _, name in pairs(map.questIdFrames[id] or {}) do frames[name] = env[name] end
        return frames
    end
    map.GetNearestSpawn = function(_, objective)
        if objective.zone then return {50, 50}, objective.zone, "NPC", objective.npcId, "monster", objective.distance end
    end
    map.GetNearestQuestSpawn = function() return {50, 50}, 12 end
    function s:icon(id, shown)
        local texture = {shown = true, Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end, IsShown = function(self) return self.shown end}
        local icon = {data = {Id = id}, width = 16, height = 16, shown = shown ~= false, texture = texture, writes = 0,
            IsShown = function(self) return self.shown end, Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end, GetWidth = function(self) return self.width end,
            GetHeight = function(self) return self.height end,
            SetWidth = function(self, value) self.width = assert(value); self.writes = self.writes + 1 end,
            SetHeight = function(self, value) self.height = assert(value) end}
        self.icons[#self.icons + 1] = icon
        local name = "Icon" .. #self.icons
        env[name] = icon
        map.questIdFrames[id] = map.questIdFrames[id] or {}
        map.questIdFrames[id][name] = name
        return icon
    end
    local function objective(index, zone, npcId, distance)
        return {Index = index, questId = 100, Description = "Objective " .. index, Completed = false,
            zone = zone, npcId = npcId, distance = distance, AlreadySpawned = {},
            spawnList = zone and {{Spawns = {[zone] = {{50, 50}}}}} or {}}
    end
    s.first, s.special = objective(1, 12, 1, 100), objective(65, 14, 999, 5)
    s.completed, s.unlocated = objective(2, 15, 2, 1), objective(3)
    s.completed.Completed = true
    s.quest = {Id = 100, name = "Quest 100", state = 0, Objectives = {s.first, s.completed, s.unlocated},
        SpecialObjectives = {s.special, objective(66)}, IsComplete = function(self) return self.state end}
    s.quests[100], s.native[100] = s.quest, true
    s.shared, s.other, s.hidden = s:icon(100), s:icon(200), s:icon(300, false)
    s.offMap = s:icon(400)
    s.offMap.offMap, s.offMap.texture.shown = true, false
    s.first.AlreadySpawned[1] = {mapRefs = {s.shared}}
    s.special.AlreadySpawned[1] = {mapRefs = {s.shared}}
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/Quest/Lifecycle/QuestLifecycle.lua")
    loadModule("Modules/Tracker/TrackerUtils.lua")
    loadModule("Modules/Tracker/TrackerMenu.lua")
    s.lifecycle, s.utils, s.menu = modules.QuestLifecycle, modules.TrackerUtils, modules.TrackerMenu
    function s:step()
        self.time = self.time + 0.1
        for i = 1, #self.timers do
            local ticker = self.timers[i]
            if not ticker.cancelled then ticker.callback() end
        end
        for i = #self.afters, 1, -1 do
            if self.afters[i].due <= self.time + 1e-6 then table.remove(self.afters, i).callback() end
        end
    end
    function s:finish() for _ = 1, 100 do self:step() end end
    function s:rootAction()
        for _, item in ipairs(self.menu:GetMenuForQuest(self.quest)) do
            if item.text == "Show on Map" then return item.func end
        end
    end
    return s
end

local groups = 0
do
    local s = setup()
    assert(s:rootAction(), "incomplete quest has a root Show on Map action")
    s.quest.state = 1
    local finisher = assert(s:rootAction(), "completed quest retains Show on Map")
    local calls = 0
    s.utils.ShowFinisherOnMap = function(_, quest) equal(quest, s.quest, "completed action uses finisher"); calls = calls + 1 end
    finisher()
    equal(calls, 1, "completed action preserves finisher behavior")
    s.quest.state, s.first.spawnList, s.special.spawnList = 0, {}, nil
    equal(s:rootAction(), nil, "completed and unlocated objectives cannot create a root action")
    groups = groups + 1
end
do
    local s = setup()
    local selected
    s.utils.ShowQuestObjectivesOnMap = function(_, objectives) selected = objectives end
    s.char.TrackerFocus = 100
    assert(s:rootAction())()
    local seen = {}
    for _, objective in ipairs(assert(selected)) do seen[objective] = true end
    equal(#selected, 2, "batch contains only located unfinished normal and special objectives")
    assert(seen[s.first] and seen[s.special], "both objective kinds are selected")
    equal(s.char.TrackerFocus, 100, "same-quest focus remains active")
    equal(s.toggles, 0, "visible quest needs no hidden-state redraw")
    groups = groups + 1
end
for _, runtimeHidden in ipairs({true, false}) do
    local s = setup()
    s.char.TrackerFocus = "100 1" -- Objective focus would fade the other selected objective.
    s.quest.HideIcons, s.first.HideIcons, s.special.HideIcons = runtimeHidden, runtimeHidden, runtimeHidden
    s.char.TrackerHiddenQuests[100] = true
    s.char.TrackerHiddenObjectives["100 1"], s.char.TrackerHiddenObjectives["100 65"] = true, true
    s.utils.ShowQuestObjectivesOnMap = noop
    assert(s:rootAction())()
    equal(s.char.TrackerFocus, nil, "same-quest objective focus is cleared")
    assert(not s.quest.HideIcons and not s.first.HideIcons and not s.special.HideIcons, "runtime hidden flags are cleared")
    equal(s.char.TrackerHiddenQuests[100], nil, "saved quest hidden flag is cleared")
    equal(s.char.TrackerHiddenObjectives["100 1"], nil, "saved normal objective hidden flag is cleared")
    equal(s.char.TrackerHiddenObjectives["100 65"], nil, "saved special objective hidden flag is cleared")
    equal(s.toggles, 1, "hidden-state changes redraw once")
    groups = groups + 1
end
for _, change in ipairs({"complete", "native-missing", "removed", "reaccepted", "replaced"}) do
    local s = setup()
    local action = assert(s:rootAction())
    if change == "complete" then s.quest.state = 1
    elseif change == "native-missing" then s.native[100] = nil
    elseif change == "removed" then s.lifecycle:AbandonQuest(100); s.native[100] = nil
    elseif change == "reaccepted" then s.lifecycle:AbandonQuest(100); s.lifecycle:AcceptQuest(100)
    else s.quests[100] = {Id = 100} end
    action()
    equal(s.mapShows, 0, "stale menu does not open a map after " .. change)
    equal(#s.timers, 0, "stale menu does not start flashing after " .. change)
    equal(s.toggles, 0, "stale menu does not alter hidden state after " .. change)
    groups = groups + 1
end
do
    local s = setup()
    local unique = s:icon(100)
    s.special.AlreadySpawned[1].mapRefs[2] = unique
    s.utils:ShowQuestObjectivesOnMap({s.first, s.special})
    equal(s.mapId, 1014, "nearest objective uses sixth distance return, not fourth NPC ID")
    equal(#s.timers, 1, "all selected objectives use one flash ticker")
    local writes, uniqueWrites = s.shared.writes, unique.writes
    s:step()
    equal(s.shared.writes - writes, 1, "shared world-map frame pulses once")
    equal(unique.writes - uniqueWrites, 1, "distinct special-objective frame pulses in the same batch")
    assert(s.solo and s.solo[s.shared.data] and s.solo[unique.data], "patrol solo includes both selected frame data")
    equal(s.other.shown, false, "unrelated quest icon is hidden while flashing")
    s:finish()
    assert(s.timers[1].cancelled, "flash ticker finishes")
    equal(s.shared.width, 16, "flash restores original width")
    equal(s.shared.height, 16, "flash restores original height")
    equal(unique.width, 16, "flash restores the distinct objective frame")
    equal(s.other.shown, true, "cleanup restores previously visible icons")
    equal(s.hidden.shown, false, "cleanup preserves previously hidden icons")
    equal(s.offMap.texture.shown, false, "off-map texture stays hidden after pin refresh")
    equal(s.solo, nil, "cleanup clears patrol solo selection")
    assert(s.refreshes > 0, "cleanup refreshes native world-map pins")
    groups = groups + 1
end
do
    local s = setup()
    s.first.AlreadySpawned, s.special.AlreadySpawned = nil, {}
    s.utils:FlashObjective(s.first)
    s.utils:FlashObjectives({s.first, s.special})
    equal(#s.timers, 0, "unspawned objectives start no flash ticker")
    equal(s.other.shown, true, "unspawned objectives do not hide unrelated icons")
    equal(#s.soloCalls, 0, "unspawned objectives do not change patrol solo selection")
    groups = groups + 1
end
do
    local s = setup()
    s.utils:ShowObjectiveOnMap(s.first)
    equal(s.mapId, 1012, "single-objective map action stays available")
    equal(#s.timers, 1, "single objective uses the shared flash path")
    s:finish()
    equal(s.shared.width, 16, "single-objective cleanup restores dimensions")
    groups = groups + 1
end
print("Tracker Show on Map: " .. groups .. " groups passed (menus, ownership, visibility, nearest map and batched flashing)")
