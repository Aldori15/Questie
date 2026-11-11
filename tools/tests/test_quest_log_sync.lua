-- Run from the addon root with Lua 5.1 or 5.2. Exercise the real cache and recovery lifecycle.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local function objective(name, count, required)
    return {text = name .. ": " .. count .. "/" .. required, type = "item",
        numFulfilled = count, numRequired = required, finished = count >= required}
end
local function harness()
    local env = setmetatable({}, {__index = _G})
    env._G, env.unpack, env.bit = env, unpack or table.unpack, bit or bit32
    env.coroutine = setmetatable({running = function()
        local thread, main = coroutine.running()
        if not main then return thread end
    end}, {__index = coroutine})
    local modules = {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    local h = {records = {}, order = {}, removed = {}, draws = {}, broadcasts = {}, snapshots = {},
        party = {}, callbacks = {}, jobs = {}, timers = {}, questSounds = 0, objectiveSounds = 0, accepts = 0}
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.GetTime = function() return 0 end
    env.CreateFrame = function() return {} end
    env.GetCursorInfo = noop
    env.Questie = {Debug = noop, Warning = error, db = {profile = {}, char = {
        TrackerHiddenQuests = {}, TrackerHiddenObjectives = {}, collapsedQuests = {}, AutoUntrackedQuests = {}}},
        SendMessage = function(_, message, id)
            if message == "QC_ID_BROADCAST_QUEST_UPDATE" then
                h.broadcasts[id] = (h.broadcasts[id] or 0) + 1
            end
        end}
    local function timer(_, callback)
        local value = {callback = callback, Cancel = function(self) self.cancelled = true end}
        h.timers[#h.timers + 1] = value
        return value
    end
    local function index(id)
        for i, questId in ipairs(h.order) do
            if id == questId and h.records[id].present then return i end
        end
        return 0
    end
    env.QuestieCompat = {HBD = {}, C_Timer = {After = timer, NewTimer = timer, NewTicker = timer},
        GetQuestLogIndexByID = index,
        GetQuestLogTitle = function(i)
            local id = h.order[i]
            if id then return "Quest " .. id, 1, nil, false, false, h.records[id].flag, 1, id end
        end,
        HaveQuestData = function(id) return h.records[id].ready end,
        C_QuestLog = {GetQuestObjectives = function(id) return h.records[id].rows end}}
    module("QuestieLib").TrimObjectiveText = function(text) return text end
    module("QuestieLib").CacheItemNames = noop
    module("Sounds").PlayObjectiveProgress = noop
    module("Sounds").PlayObjectiveComplete = function() h.objectiveSounds = h.objectiveSounds + 1 end
    module("Sounds").PlayQuestComplete = function() h.questSounds = h.questSounds + 1 end
    module("QuestieCombatQueue").Queue = function(_, callback)
        if h.deferCombat then h.jobs[#h.jobs + 1] = callback else callback() end
    end
    module("QuestieTracker").Update, module("QuestieTracker").UpdateFromQuestLog = noop, noop
    module("QuestieNameplate").UpdateNameplate = noop
    module("QuestiePartyObjectives").ScheduleUpdate = function(_, id) h.party[id] = true end
    module("CommsVisibility").ScheduleSnapshot = function(_, reason) h.snapshots[#h.snapshots + 1] = reason end
    module("QuestieJourney").AcceptQuest = function() h.accepts = h.accepts + 1 end
    module("QuestieAnnounce").AcceptedQuest = function() error("Recovery must not announce acceptance") end
    module("BreadcrumbQuests").CheckQuestBreadcrumbs = noop
    module("TrackerUtils").ClearTomTomTargetForQuest = noop
    module("IsleOfQuelDanas").CheckForActivePhase = function() return false end
    module("AutoRoute").ScheduleUpdate = noop
    module("QuestiePlayer").currentQuestlog = {}
    module("QuestieDB").HasQuestData = function(id) return h.records[id].mapped end
    module("QuestieDB").GetQuest = function(id) return h.records[id].quest end
    module("AvailableQuests").CalculateAndDrawAll = noop
    module("AvailableQuests").RemoveQuest = function(id, callback)
        h.removed[id] = true
        if h.deferRemoval then h.callbacks[#h.callbacks + 1] = callback else callback() end
    end
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/Quest/QuestLogCache.lua")
    loadModule("Modules/Quest/QuestieQuest.lua")
    loadModule("Modules/Quest/Lifecycle/QuestLifecycle.lua")
    loadModule("Modules/Quest/QuestEventHandler.lua")
    -- Keep the real shared login setup; stub only inventory, map drawing and rendering.
    local questModule = modules.QuestieQuest
    questModule.CheckQuestSourceItem = function() return true end
    questModule.PopulateQuestLogInfo = function(_, quest)
        for i in ipairs(modules.QuestLogCache.GetQuestObjectives(quest.Id)) do quest.Objectives[i] = {Index = i} end
    end
    questModule.ShouldShowQuestNotes = function() return true end
    questModule.PopulateObjectiveNotes = function(_, quest)
        h.draws[quest.Id] = (h.draws[quest.Id] or 0) + 1
        h.drawnStatus = quest:IsComplete()
    end
    questModule.UpdateQuest = function(_, id) h.updatedStatus = modules.QuestLogCache.GetQuest(id).isComplete end
    h.cache, h.events, h.modules, h.env = modules.QuestLogCache, modules.QuestEventHandler.private, modules, env
    function h:add(id, rows, flag, mapped)
        self.order[#self.order + 1] = id
        self.records[id] = {rows = rows, flag = flag, mapped = mapped, ready = true, present = true}
        if mapped then
            self.records[id].quest = {Id = id, Objectives = {}, SpecialObjectives = {{Index = 2}},
                IsComplete = function() return self.cache.GetQuest(id).isComplete end}
        end
    end
    function h:scan() return self.cache.CheckForChanges(nil, true, true) end
    function h:complete(id) return self.cache.GetQuest(id).isComplete end
    function h:flush() while #self.callbacks > 0 do table.remove(self.callbacks, 1)() end end
    return h
end

-- Real item losses reopen the quest after the bag has settled, but cursor-held stacks do not.
do
    local h = harness()
    h:add(1, {objective("Item", 1, 1)}, 1)
    h:scan()
    h.records[1].flag, h.records[1].rows = nil, {objective("Item", 0, 1)}
    local miss = h.cache.CheckForChanges(nil, true, false)
    equal(miss, true, "unsettled item loss is deferred")
    equal(h.cache.HasPendingItemRegression(), true, "bag confirmation requested")
    equal(h:complete(1), 1, "cursor-held stack does not reopen quest")
    miss = h:scan()
    equal(miss, false, "settled loss accepted outside loading")
    equal(h:complete(1), 0, "settled loss clears cached completion")
    equal(h.cache.HasPendingItemRegression(), false, "settled loss clears bag confirmation")
    h.records[1].flag, h.records[1].rows = 1, {objective("Item", 1, 1)}
    h:scan(); h:scan()
    equal(h:complete(1), 1, "retrieving item completes quest again")
    equal(h.questSounds, 1, "recompletion sound plays once")
end

-- Missing rows, empty text and placeholder text keep loading recovery active, even beside unfinished rows.
for _, missing in ipairs({"absent", "empty", "placeholder"}) do
    local h = harness()
    h:add(1, {objective("First", 0, 1), objective("Second", 0, 1)}, nil)
    h:scan(); h.cache.OnPlayerLeavingWorld()
    h.records[1].rows = {objective("First", 0, 1)}
    if missing ~= "absent" then
        h.records[1].rows[2] = {text = missing == "empty" and "" or " ", type = "item",
            numFulfilled = 0, numRequired = 1, finished = false}
    end
    equal(h:scan(), true, missing .. " row keeps recovery active beside unfinished row")
    h.records[1].rows = {objective("First", 1, 1)}
    equal(h:scan(), true, missing .. " row prevents false completion on next scan")
    equal(h:complete(1), 0, "partial loading data cannot complete quest")
    equal(h.questSounds, 0, "rejected snapshot plays no quest sound")
    equal(h.objectiveSounds, 0, "rejected snapshot plays no objective sound")
    h.records[1].rows = {objective("First", 1, 1), objective("Second", 0, 1)}
    equal(h:scan(), false, "restored objectives recover normally")
    equal(h:complete(1), 0, "restored unfinished objective retained")
    equal(h.objectiveSounds, 1, "valid progress plays sound once")
end

do
    local h = harness()
    h:add(1, {objective("First", 1, 1)}, nil)
    h:scan()
    h.records[1].rows[2] = objective("Restored", 0, 1)
    h:scan()
    equal(h:complete(1), 0, "incorrect completion can correct itself when rows load")
    h.records[1].rows = {}
    h:scan()
    equal(#h.cache.GetQuestObjectives(1), 0, "row count changes are committed without changed retained rows")
    local miss, _, _, unlisted = h.cache.CheckForChanges({}, false)
    equal(miss, false, "unlisted quest is discovered without scanning it")
    equal(unlisted[1], true, "cache reports unlisted live quest ID")
end

-- Loading protection remains bounded when an actual item loss happens during a transition.
do
    local h = harness()
    h:add(1, {objective("Item", 1, 1)}, 1)
    h:scan(); h.cache.OnPlayerLeavingWorld()
    h.records[1].flag, h.records[1].rows = nil, {objective("Item", 0, 1)}
    for _ = 1, 10 do equal(h:scan(), true, "loading loss retains completed cache temporarily") end
    equal(h:scan(), false, "loading retry limit eventually permits genuine loss")
    equal(h:complete(1), 0, "genuine loading-time loss does not remain completed forever")
end

-- Missed accepts are adopted after data loads, without losing saved tracker choices.
for _, mapped in ipairs({true, false}) do
    local h = harness()
    h:add(1, {objective("Item", 0, 1)}, nil, mapped)
    h.records[1].ready = false
    local char = h.env.Questie.db.char
    char.collapsedQuests[1], char.AutoUntrackedQuests[1] = true, true
    char.TrackerHiddenQuests[1], char.TrackerHiddenObjectives["1 1"], char.TrackerHiddenObjectives["1 2"] = true, true, true
    h.events:UpdateAllQuests()
    equal(h.draws[1], nil, "missing data cannot draw adopted quest")
    h.records[1].ready = true
    h.events:UpdateAllQuests(); h.events:UpdateAllQuests()
    equal(h.cache.GetQuestCount(), 1, "missed accept joins native cache once")
    equal(h.accepts, 0, "adoption adds no Journey acceptance")
    equal(char.collapsedQuests[1], true, "adoption preserves collapsed choice")
    equal(char.AutoUntrackedQuests[1], true, "adoption preserves untracked choice")
    equal(h.party[1], true, "party objective ownership refreshed")
    equal(h.broadcasts[1], 1, "party receives recovered quest once")
    if mapped then
        local quest = h.modules.QuestiePlayer.currentQuestlog[1]
        assert(quest.HideIcons and quest.Objectives[1].HideIcons and quest.SpecialObjectives[1].HideIcons,
            "hidden quest, objective and helper choices restored before drawing")
        equal(h.removed[1], true, "stale starter removed before adopted notes")
        equal(h.draws[1], 1, "adopted quest draws once")
    else
        equal(h.modules.QuestiePlayer.currentQuestlog[1], nil, "native-only quest needs no database map object")
        equal(h.draws[1], nil, "native-only quest creates no invented map location")
    end
end

-- Ready-to-turn-in quests use the same setup; queued adoption cannot outlive its log membership or lifecycle.
for _, change in ipairs({"removed", "reaccepted"}) do
    local h = harness()
    h:add(1, {objective("Item", 1, 1)}, 1, true)
    h.deferRemoval = true
    h.events:UpdateAllQuests()
    if change == "removed" then
        h.records[1].present = false
    else
        h.deferCombat = true
        h.events:QuestAccepted(1, 1)
    end
    h:flush()
    equal(h.draws[1], nil, "stale adoption callback cannot draw after " .. change)
    equal(h.broadcasts[1], nil, "stale adoption callback cannot broadcast after " .. change)
end
do
    local h = harness()
    h:add(1, {objective("Item", 1, 1)}, 1, true)
    h.events:UpdateAllQuests()
    equal(h.drawnStatus, 1, "completed missed quest draws its completed state")
end
do
    local h = harness()
    h:add(1, {objective("Item", 0, 1)}, nil, true)
    h.modules.QuestieQuest.PopulateObjectiveNotes = function()
        h.records[1].present = false
        h.modules.QuestiePlayer.currentQuestlog[1] = nil
    end
    h.events:UpdateAllQuests()
    equal(h.broadcasts[1], nil, "removal during yielded population cannot broadcast stale membership")
end
for _, mapped in ipairs({true, false}) do
    local h = harness()
    h:add(1, {objective("Item", 0, 1)}, nil, mapped)
    h:scan() -- The cache can be ready before the acceptance lifecycle exists.
    h.records[1].ready = false
    h:add(2, {objective("Other", 0, 1)}, nil, mapped)
    h.events:UpdateAllQuests()
    equal(h.broadcasts[1], nil, "cached quest waits for its own valid scan")
    equal(h.broadcasts[2], 1, "loading quest does not block another ready adoption")
    h.records[1].ready = true
    h.events:UpdateAllQuests(); h.events:UpdateAllQuests()
    equal(h.broadcasts[1], 1, "unchanged cached quest is adopted once")
    equal(h.draws[1], mapped and 1 or nil, "unchanged cached mapped quest draws its notes")
    equal(h.accepts, 0, "unchanged cache recovery creates no Journey acceptance")
end

print("Quest log sync regressions passed (item loss, loading snapshots, discovery, adoption and native quests)")
