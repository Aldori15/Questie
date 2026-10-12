-- Run from the addon root with Lua 5.1 or 5.2+.
-- Use the production loader and QuestieQuest tracking rules, including Blizzard watches.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function loadModule(path, env)
    local chunk
    if setfenv then
        chunk = setfenv(assert(loadfile(path)), env)
    else
        chunk = assert(loadfile(path, "t", env))
    end
    chunk()
end

local trackerFiles = {}
for line in io.lines("Questie-335.toc") do
    local path = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
    if path == "Modules/Tracker/TrackerNearestQuestItem.lua"
        or path == "Modules/Tracker/QuestieTracker.lua" then
        trackerFiles[#trackerFiles + 1] = path
    end
end
equal(#trackerFiles, 2, "both tracker modules registered exactly once")
equal(trackerFiles[1], "Modules/Tracker/TrackerNearestQuestItem.lua", "controller loads before tracker")

local function setup(enabled)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local s = {quests = {}, watched = {}, distances = {}, spells = {},
        tickers = {}, frames = 0, itemReads = 0, inCombat = false}
    env.Questie = {db = {profile = {trackerEnabled = enabled, autoTrackQuests = false},
        char = {TrackedQuests = {}, AutoUntrackedQuests = {}}}}
    env.GetTime = function() return 0 end
    env.debugstack = function() end
    env.GetNumQuestWatches = function() return 0 end
    env.GetTrackedAchievements = function() end
    env.LibStub = function() return {} end
    env.hooksecurefunc = function() end
    env.UIParent = {}
    env.IsQuestWatched = function(index) return s.watched[index] end
    env.InCombatLockdown = function() return s.inCombat end
    env.GetItemSpell = function(id) return s.spells[id] end
    env.QuestieCompat = {GetQuestLogIndexByID = function(id) return s.quests[id] and id end,
        C_Timer = {NewTicker = function(interval, callback)
            s.tickers[#s.tickers + 1] = {interval = interval, callback = callback}
        end}}
    loadModule("Modules/Libs/QuestieLoader.lua", env)
    local loader = env.QuestieLoader
    local function module(name) return loader:CreateModule(name) end
    setmetatable(module("l10n"), {__call = function(_, text) return text end})
    module("QuestiePlayer").currentQuestlog = s.quests
    module("TrackerUtils").GetTomTomTarget = function() return s.target end
    module("TrackerUtils").GetUsableQuestItemIds = function(_, quest)
        s.itemReads = s.itemReads + 1
        return quest.items
    end
    module("QuestieMap").GetNearestQuestSpawn = function(_, quest)
        return nil, nil, nil, nil, nil, s.distances[quest.Id]
    end
    module("QuestieDB").QueryQuestSingle = function() end
    env.CreateFrame = function(kind, name, parent, template)
        equal(kind, "Button", "secure frame type")
        equal(name, "Questie_NearestQuestItemButton", "saved binding target retained")
        equal(parent, env.UIParent, "button parent")
        equal(template, "SecureActionButtonTemplate", "secure template")
        s.frames = s.frames + 1
        local button = {attributes = {}, writes = 0}
        function button:SetAttribute(key, value)
            assert(not s.inCombat, "secure attributes must not change in combat")
            self.attributes[key], self.writes = value, self.writes + 1
        end
        function button:RegisterForClicks(value) self.clicks = value end
        function button:Hide() self.hidden = true end
        s.button, env[name] = button, button
        return button
    end
    loadModule("Modules/Quest/QuestieQuest.lua", env)
    for _, path in ipairs(trackerFiles) do loadModule(path, env) end
    s.questModule = loader:ImportModule("QuestieQuest")
    s.controller = loader:ImportModule("TrackerNearestQuestItem")
    s.tracker = loader:ImportModule("QuestieTracker")
    equal(type(s.controller.SetupKeybinding), "function", "binding setup available before startup")
    equal(type(s.controller.Initialize), "function", "controller available before startup")
    function s.start()
        if env.Questie.db.profile.trackerEnabled then
            s.tracker.SetupKeybinding()
            s.controller.Initialize()
        else
            local thread = coroutine.create(s.tracker.Initialize)
            local ok, message = coroutine.resume(thread)
            assert(ok, message)
            equal(coroutine.status(thread), "dead", "disabled startup does not render tracker")
        end
    end
    function s.tick() s.tickers[1].callback() end
    function s.selected() return s.button.attributes.item end
    function s.quest(id, item, distance, tracked)
        local quest = {Id = id, items = {item}, Objectives = {{}}}
        function quest:IsComplete() return self.completeState end
        s.quests[id], s.distances[id] = quest, distance
        env.Questie.db.char.TrackedQuests[id] = tracked
        s.spells[item] = "Use item"
        return quest
    end
    s.env = env
    return s
end

local tests = 0

-- Reproduce disabling the tracker and reloading with no Blizzard watches.
do
    local s = setup(false)
    s.quest(11516, 34253, 10, false)
    equal(s.questModule:IsQuestTracked(11516), false, "quest is not Blizzard-watched")
    s.start()
    equal(s.selected(), "item:34253", "disabled tracker still selects an unwatched quest item")
    equal(s.button.attributes.type, "item", "item action retained")
    equal(s.button.clicks, "AnyDown", "click timing retained")
    equal(s.button.hidden, true, "binding button stays hidden")
    equal(s.tickers[1].interval, 5, "refresh interval retained")
    equal(s.env["BINDING_NAME_CLICK Questie_NearestQuestItemButton:LeftButton"],
        "Use Nearest Quest Item", "binding label registered while disabled")
    s.start()
    equal(s.frames, 1, "repeated startup reuses button")
    equal(#s.tickers, 1, "repeated startup reuses timer")
    tests = tests + 1
end

-- Disabled selection uses proximity across the log without changing map/watch rules.
do
    local s = setup(false)
    s.quest(10, 100, 20, true); s.quest(20, 101, 1, false)
    s.watched[10] = true
    s.start()
    equal(s.selected(), "item:101", "closer unwatched quest selected while disabled")
    equal(s.questModule:IsQuestTracked(10), true, "Blizzard watched quest still tracked")
    equal(s.questModule:IsQuestTracked(20), false, "unwatched map tracking unchanged")
    s.distances[10] = 0.5; s.tick()
    equal(s.selected(), "item:100", "movement changes selection")
    tests = tests + 1
end

-- Enabling/disabling the setting switches selection scope on the next safe tick.
do
    local s = setup(true)
    s.quest(10, 100, 20, true); s.quest(20, 101, 1, false)
    s.start()
    equal(s.selected(), "item:100", "enabled tracker respects manual tracking")
    s.env.Questie.db.profile.trackerEnabled = false; s.tick()
    equal(s.selected(), "item:101", "disabling includes all log quests")
    s.env.Questie.db.profile.trackerEnabled = true; s.tick()
    equal(s.selected(), "item:100", "enabling restores tracking filter")
    s.env.Questie.db.char.TrackedQuests[10] = nil; s.tick()
    equal(s.selected(), nil, "no tracked quests clears enabled selection")
    tests = tests + 1
end

-- Auto-untracking remains respected when Questie's tracker is enabled.
do
    local s = setup(true)
    s.quest(10, 100, 20, false); s.quest(20, 101, 1, false)
    s.env.Questie.db.profile.autoTrackQuests = true
    s.env.Questie.db.char.AutoUntrackedQuests[20] = true
    s.start()
    equal(s.selected(), "item:100", "auto-untracked closer quest excluded")
    tests = tests + 1
end

-- Explicit route targets keep their priority, independent of tracker/watch state.
for _, enabled in ipairs({true, false}) do
    local s = setup(enabled)
    s.quest(10, 100, 1, true); s.quest(20, 101, 100, false)
    s.target = {}
    s.env.Questie.db.char._tom_waypoint_quest = {questId = 20}
    s.start()
    equal(s.selected(), "item:101", "route target takes priority")
    s.target = nil; s.tick()
    equal(s.selected(), "item:100", "stale route returns to proximity")
    tests = tests + 1
end

-- Disabling the tracker still cannot change a secure action during combat.
do
    local s = setup(true)
    s.quest(10, 100, 20, true); s.quest(20, 101, 1, false)
    s.start()
    local writes, reads = s.button.writes, s.itemReads
    s.inCombat = true
    s.env.Questie.db.profile.trackerEnabled = false; s.tick()
    equal(s.selected(), "item:100", "combat retains secure selection")
    equal(s.button.writes, writes, "no secure writes in combat")
    equal(s.itemReads, reads, "no selection work in combat")
    s.inCombat = false; s.tick()
    equal(s.selected(), "item:101", "next safe tick changes scope")
    s.quests[10], s.quests[20] = nil, nil; s.tick()
    equal(s.selected(), nil, "abandoned or rewarded quests clear selection")
    writes = s.button.writes; s.tick()
    equal(s.button.writes, writes, "empty selection is not repeatedly cleared")
    tests = tests + 1
end

-- Completion and castability rules still apply when selecting from the entire log.
do
    local s = setup(false)
    local quest = s.quest(10, 100, 1, false)
    quest.completeState, quest.isComplete, quest.sourceItemId = 1, true, 101
    s.start()
    equal(s.selected(), nil, "completed objective-only item rejected")
    quest.requiredSourceItems = {100}; s.tick()
    equal(s.selected(), "item:100", "completed required source item retained")
    quest.requiredSourceItems, quest.sourceItemId = nil, 100; s.tick()
    equal(s.selected(), "item:100", "completed source item retained")
    s.spells[100] = nil; s.tick()
    equal(s.selected(), nil, "equipment-only item rejected")
    tests = tests + 1
end

print("Tracker nearest quest-item regressions passed (" .. tests .. " groups)")
