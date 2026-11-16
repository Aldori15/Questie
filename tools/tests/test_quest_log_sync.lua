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
        party = {}, callbacks = {}, jobs = {}, timers = {}, questSounds = 0, objectiveSounds = 0,
        accepts = 0, abandons = 0}
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.GetTime = function() return 0 end
    env.CreateFrame = function() return {} end
    env.GetCursorInfo = noop
    env.debugstack = function() return "test stack" end
    env.Questie = {Debug = noop, Print = noop, Error = error, Warning = error, db = {profile = {}, char = {
        complete = {}, TrackerHiddenQuests = {}, TrackerHiddenObjectives = {}, collapsedQuests = {}, AutoUntrackedQuests = {}}},
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
        SetQuestComplete = function(id) env.Questie.db.char.complete[id] = true end,
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
    module("QuestieTracker").RemoveQuest = noop
    module("QuestieNameplate").UpdateNameplate = noop
    module("QuestiePartyObjectives").ScheduleUpdate = function(_, id) h.party[id] = true end
    module("CommsVisibility").ScheduleSnapshot = function(_, reason) h.snapshots[#h.snapshots + 1] = reason end
    module("QuestieJourney").AcceptQuest = function() h.accepts = h.accepts + 1 end
    module("QuestieJourney").CompleteQuest = noop
    module("QuestieJourney").AbandonQuest = function() h.abandons = h.abandons + 1 end
    module("QuestieAnnounce").AcceptedQuest = function() error("Recovery must not announce acceptance") end
    module("QuestieAnnounce").CompletedQuest = noop
    module("QuestieAnnounce").AbandonedQuest = noop
    module("BreadcrumbQuests").CheckQuestBreadcrumbs = noop
    module("TrackerUtils").ClearTomTomTargetForQuest = noop
    module("IsleOfQuelDanas").CheckForActivePhase = function() return false end
    module("AutoRoute").ScheduleUpdate = noop
    module("AutoRoute").RemoveFromRoute = noop
    module("QuestiePlayer").currentQuestlog = {}
    module("QuestieDB").HasQuestData = function(id) return h.records[id].mapped end
    module("QuestieDB").GetQuest = function(id) return h.records[id].quest end
    module("QuestieDB").QueryQuestSingle = noop
    module("AvailableQuests").CalculateAndDrawAll = noop
    module("AvailableQuests").ResetLastNpcGuid = noop
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
    h.loadModule = loadModule
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

-- Wrath's reward confirmation can precede the native log removing its old row.
-- That row must not be mistaken for a missed accept and restore tracker/map state.
do
    local h = harness()
    h:add(844, {objective("Beaks", 7, 7)}, 1, true)
    h:add(868, {objective("Eggs", 0, 12)}, nil, true)
    h.events:UpdateAllQuests()
    local draws, broadcasts = h.draws[844], h.broadcasts[844]
    h.events:QuestTurnedIn(844)
    h.events:QuestRemoved(844)
    equal(h.modules.QuestiePlayer.currentQuestlog[844], nil, "turn-in removes mapped membership")
    h.records[844].flag, h.records[844].rows = nil, {objective("Beaks", 0, 7)}
    h.events:UpdateAllQuests()
    equal(h.modules.QuestiePlayer.currentQuestlog[844], nil, "stale turned-in native row cannot be adopted")
    equal(h.cache.questLog_DO_NOT_MODIFY[844], nil, "stale turned-in native row cannot rebuild cache")
    h.order, h.records[844].present = {868}, false
    h.events:UpdateAllQuests()
    equal(h.draws[844], draws, "turned-in quest cannot redraw objective notes")
    equal(h.broadcasts[844], broadcasts, "turned-in quest cannot broadcast restored membership")
    h.env.GetNumQuestLogEntries = function() return #h.order end
    h.loadModule("Modules/Tracker/TrackerData.lua")
    local displayed = h.modules.TrackerData.Refresh()
    equal(displayed[844], nil, "tracker excludes turned-in quest after native removal")
    assert(displayed[868], "remaining Egg Hunt quest stays tracked")
    -- Once absence is observed, a later missed acceptance of the same ID can recover.
    h.order, h.records[844].present = {844, 868}, true
    h.events:UpdateAllQuests()
    assert(h.modules.QuestiePlayer.currentQuestlog[844], "new missed acceptance can recover after confirmed removal")
end

-- A scan can observe absence between turn-in and removal notifications.
-- Keep turn-in state until removal arrives so it cannot become an abandonment.
do
    local h = harness()
    h:add(844, {objective("Beaks", 7, 7)}, 1, true)
    h.events:UpdateAllQuests()
    h.events:QuestTurnedIn(844)
    h.order, h.records[844].present = {}, false
    h.events:UpdateAllQuests()
    h.events:QuestRemoved(844)
    h.events:UpdateAllQuests()
    h.order, h.records[844].present = {844}, true
    h.records[844].flag, h.records[844].rows = nil, {objective("Beaks", 0, 7)}
    h.events:UpdateAllQuests()
    assert(h.modules.QuestiePlayer.currentQuestlog[844], "delayed removal releases the completed lifecycle after absence")
end

-- Removal may also arrive first; both mapped and native-only quests must recover later.
for _, mapped in ipairs({true, false}) do
    local h = harness()
    h:add(844, {objective("Beaks", 7, 7)}, 1, mapped)
    h.events:UpdateAllQuests()
    local broadcasts = h.broadcasts[844]
    h.events:QuestRemoved(844)
    h.events:QuestTurnedIn(844)
    h.records[844].flag, h.records[844].rows = nil, {objective("Beaks", 0, 7)}
    h.events:UpdateAllQuests()
    equal(h.cache.questLog_DO_NOT_MODIFY[844], nil, "removal before turn-in cannot restore a stale snapshot")
    equal(h.broadcasts[844], broadcasts, "removal before turn-in cannot announce restored membership")
    h.order, h.records[844].present = {}, false
    h.events:UpdateAllQuests()
    h.order, h.records[844].present = {844}, true
    h.events:UpdateAllQuests()
    equal(h.broadcasts[844], broadcasts + 1, "removal-first lifecycle allows a later missed acceptance")
end

-- A real repeatable acceptance supersedes retained turn-in state immediately.
do
    local h = harness()
    h:add(844, {objective("Beaks", 7, 7)}, 1, true)
    h.events:UpdateAllQuests()
    h.events:QuestTurnedIn(844)
    h.events:QuestRemoved(844)
    h.records[844].flag, h.records[844].rows = nil, {objective("Beaks", 0, 7)}
    h.modules.QuestieAnnounce.AcceptedQuest = noop
    h.events:QuestAccepted(1, 844)
    assert(h.modules.QuestiePlayer.currentQuestlog[844], "explicit reaccept needs no intervening absent scan")
    equal(h.accepts, 1, "explicit reaccept retains normal acceptance behavior")
    equal(h:complete(844), 0, "explicit reaccept uses fresh objective progress")
end

-- Acceptance cleanup must belong to the current acceptance, not just the same quest ID/object.
for _, change in ipairs({"turned-in", "abandoned", "reaccepted", "cache-missing", "rebuilt"}) do
    local h = harness()
    h:add(844, {objective("Beaks", 0, 7)}, nil, true)
    h:scan()
    h.deferRemoval = true
    local lifecycle = h.modules.QuestLifecycle
    lifecycle:AcceptQuest(844)
    if change == "turned-in" then
        lifecycle:CompleteQuest(844)
        h.cache.RemoveQuest(844)
        h.order, h.records[844].present = {}, false
    elseif change == "abandoned" or change == "reaccepted" then
        lifecycle:AbandonQuest(844)
        if change == "reaccepted" then lifecycle:AcceptQuest(844) end
    elseif change == "cache-missing" then
        h.cache.RemoveQuest(844)
    else
        local quest = h.modules.QuestiePlayer.currentQuestlog[844]
        h.modules.QuestiePlayer.currentQuestlog = {}
        h.modules.QuestiePlayer.currentQuestlog = {[844] = quest}
    end
    h:flush()
    local expected = (change == "reaccepted" or change == "rebuilt") and 1 or nil
    equal(h.draws[844], expected, "acceptance draws only current work after " .. change)
    equal(h.broadcasts[844], expected, "acceptance broadcasts only current work after " .. change)
end

-- Abandoning Back to Billy removes its granted pie before the native quest row disappears.
-- A bag-triggered scan of that old row must not recover it as a missed acceptance.
for _, immediate in ipairs({true, false}) do
    local h = harness()
    h:add(84, {}, 1, true)
    h:add(844, {objective("Beaks", 0, 7)}, nil, true)
    h.events:UpdateAllQuests()
    local draws, broadcasts = h.draws[84], h.broadcasts[84]
    h.events:QuestRemoved(84, immediate)
    if not immediate then h.events:MarkQuestAsAbandoned(84) end
    equal(h.modules.QuestiePlayer.currentQuestlog[84], nil, "abandon removes the granted-item quest")
    h.records[84].flag = nil -- The pie is gone, but the native log still lists the quest.
    h.events:UpdateAllQuests()
    equal(h.modules.QuestiePlayer.currentQuestlog[84], nil, "stale abandoned native row cannot be adopted")
    equal(h.cache.TryGetQuest(84), nil, "stale abandoned native row cannot rebuild cache")
    h.events:MarkQuestAsAbandoned(84) -- A late removal callback must not repeat abandonment.
    equal(h.abandons, 1, "abandonment is recorded once")
    h.order, h.records[84].present = {844}, false
    h.events:UpdateAllQuests()
    equal(h.draws[84], draws, "abandoned quest cannot redraw its missing-source-item notes")
    equal(h.broadcasts[84], broadcasts, "abandoned quest cannot broadcast restored membership")
    h.env.GetNumQuestLogEntries = function() return #h.order end
    h.loadModule("Modules/Tracker/TrackerData.lua")
    local displayed = h.modules.TrackerData.Refresh()
    equal(displayed[84], nil, "tracker excludes Back to Billy after native removal")
    assert(displayed[844], "Plainstrider Menace remains tracked")
    h.order, h.records[84].present, h.records[84].flag = {84, 844}, true, 1
    h.events:UpdateAllQuests()
    assert(h.modules.QuestiePlayer.currentQuestlog[84], "a later missed reacceptance can recover after confirmed removal")
end

-- A real acceptance replaces an abandonment marker even without an intervening absent scan.
do
    local h = harness()
    h:add(84, {}, 1, true)
    h.events:UpdateAllQuests()
    h.events:QuestRemoved(84, true)
    h.modules.QuestieAnnounce.AcceptedQuest = noop
    h.events:QuestAccepted(1, 84)
    assert(h.modules.QuestiePlayer.currentQuestlog[84], "explicit reaccept supersedes a retained abandonment marker")
    equal(h.accepts, 1, "explicit reaccept retains normal acceptance behavior")
end

-- The native row may disappear before a delayed abandonment timer acknowledges removal.
do
    local h = harness()
    h:add(84, {}, 1, true)
    h.events:UpdateAllQuests()
    h.events:QuestRemoved(84)
    h.order, h.records[84].present = {}, false
    h.events:UpdateAllQuests()
    h.events:MarkQuestAsAbandoned(84)
    h.order, h.records[84].present = {84}, true
    h.events:UpdateAllQuests()
    assert(h.modules.QuestiePlayer.currentQuestlog[84], "delayed abandonment releases a marker for an already absent row")
end

-- GetAllQuestIds yields after five quests; live removals and tooltips can run between batches.
local function beginQuestLogRebuild()
    local h = harness()
    for id = 1, 6 do h:add(id, {objective("Item", 0, 1)}, nil, true) end
    h.events:UpdateAllQuests()
    local draws = {}
    for id = 1, 6 do draws[id] = h.draws[id] end
    local thread = coroutine.create(function() h.modules.QuestieQuest:GetAllQuestIds() end)
    local ok, message = coroutine.resume(thread)
    assert(ok, message)
    equal(coroutine.status(thread), "suspended", "rebuild pauses between quest batches")
    local pending
    for id = 1, 6 do
        if h.draws[id] == draws[id] then pending = id; break end
    end
    assert(pending, "one snapshot quest waits for the next rebuild batch")
    return h, thread, pending
end
local function finishQuestLogRebuild(thread)
    while coroutine.status(thread) ~= "dead" do
        local ok, message = coroutine.resume(thread)
        assert(ok, message)
    end
end

do
    local h, thread, pending = beginQuestLogRebuild()
    assert(h.cache.TryGetQuest(pending), "pending quest remains cached during the rebuild")
    assert(h.env.QuestieCompat.GetQuestLogIndexByID(pending) > 0, "pending quest remains in the native log")
    equal(h.modules.QuestiePlayer.currentQuestlog[pending], h.records[pending].quest,
        "rebuild preserves pending accepted membership")

    h.env.UnitName = function() return "Tester" end
    h.env.QuestieCompat.IsInGroup = function() return false end
    h.modules.QuestiePlayer.numberOfGroupMembers = 0
    h.modules.QuestiePlayer.GetPartyMemberByName = noop
    local lib = h.modules.QuestieLib
    lib.AddonPath = "Interface\\AddOns\\Questie-335\\"
    lib.GetColoredQuestName = function(_, id) return "Quest " .. id end
    lib.GetRGBForObjective = function() return "|cFFFFFFFF" end
    lib.GetObjectiveDescription = function(_, entry) return entry.Description end
    lib.SortQuestIDsByLevel = function(_, ids)
        local sorted = {}
        for id in pairs(ids) do sorted[#sorted + 1] = id end
        table.sort(sorted)
        return sorted
    end
    h.modules.QuestieDB.GetItemDroprate = noop
    h.loadModule("Modules/Tooltips/Tooltip.lua")
    h.modules.QuestieComms.remotePlayerEnabled = {}
    local tips = h.modules.QuestieTooltips
    local entry = {Index = 1, Id = 1, Type = "monster", Description = "Rebuild objective",
        Needed = 1, Collected = 0, Update = noop}
    h.records[pending].quest.Objectives[1] = entry
    tips:RegisterObjectiveTooltip(pending, "m_1", entry)
    local lines = tips:GetTooltip("m_1")
    assert(tips.lookupByKey.m_1[pending .. " 1"], "hover during rebuild cannot purge an accepted objective")
    assert(lines and #lines == 2 and lines[2]:find("Rebuild objective", 1, true),
        "hover during rebuild retains the objective text")
    finishQuestLogRebuild(thread)
end

do
    local h, thread, pending = beginQuestLogRebuild()
    local draws = h.draws[pending]
    h.events:QuestTurnedIn(pending)
    h.events:QuestRemoved(pending)
    h.records[pending].present = false
    for index, id in ipairs(h.order) do
        if id == pending then table.remove(h.order, index); break end
    end
    finishQuestLogRebuild(thread)
    equal(h.modules.QuestiePlayer.currentQuestlog[pending], nil, "old rebuild snapshot cannot restore a turned-in quest")
    equal(h.cache.TryGetQuest(pending), nil, "rebuild leaves the turned-in cache removed")
    equal(h.draws[pending], draws, "rebuild cannot draw the removed snapshot quest")
end

do
    local h, thread, pending = beginQuestLogRebuild()
    local quest, draws = h.records[pending].quest, h.draws[pending]
    h.events:QuestRemoved(pending, true)
    h.modules.QuestieAnnounce.AcceptedQuest = noop
    h.events:QuestAccepted(h.env.QuestieCompat.GetQuestLogIndexByID(pending), pending)
    equal(h.modules.QuestiePlayer.currentQuestlog[pending], quest, "reacceptance reuses the database quest object")
    equal(h.draws[pending], draws + 1, "new acceptance draws its objectives once")
    finishQuestLogRebuild(thread)
    equal(h.draws[pending], draws + 1, "old rebuild cannot redraw a replacement acceptance")
    equal(h.accepts, 1, "reacceptance is recorded once during rebuild")
end

print("Quest log sync regressions passed (item loss, loading snapshots, discovery, adoption, turn-in/abandon ordering, acceptance ownership, rebuilds and native quests)")
