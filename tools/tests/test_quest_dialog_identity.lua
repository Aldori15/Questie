-- Run from the addon root with Lua 5.1 or 5.2+. Check Wrath dialog GUIDs, automation and persisted availability.
local unpackValues = unpack or table.unpack
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function read(path)
    local file = assert(io.open(path, "r")); local source = file:read("*a"); file:close()
    return source:gsub("\r\n", "\n")
end
local function compile(source, env)
    if setfenv then return setfenv(assert(loadstring(source)), env)() end
    return assert(load(source, "@quest-dialog-fixture", "t", env))()
end
local function loadModule(path, env) compile(read(path), env) end
local function loadFunction(path, declaration, prefix, env)
    local pattern = declaration:gsub("(%W)", "%%%1") .. ".-\nend"
    compile((prefix or "") .. assert(read(path):match(pattern), declaration), env)
end
local function upvalue(fn, name)
    for index = 1, 40 do
        local key, value = debug.getupvalue(fn, index)
        if key == name then return value end
    end
    error("Missing fixture upvalue: " .. name)
end
local function rawGuid(id, object)
    return string.format("0xF1%s0%06X%06X", object and "1" or "3", id, 1)
end

local function harness()
    local env = setmetatable({}, {__index = _G})
    env._G, env.tinsert, env.time, env.date = env, table.insert, os.time, os.date
    env.strsplit = function(delimiter, value)
        local parts = {}; for part in value:gmatch("[^" .. delimiter .. "]+") do parts[#parts + 1] = part end
        return unpackValues(parts)
    end
    local modules, units, calls, drawn, broadcasts, actions = {}, {}, {}, {}, {}, {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}; return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.UnitGUID = function(unit)
        assert(unit ~= "target", "Selected target must not identify a dialog giver")
        calls[#calls + 1] = unit; return units[unit]
    end
    env.UnitFactionGroup = function() return "Alliance" end
    env.GetRealmName = function() return "Dialog realm" end
    env.MAX_NUM_QUESTS = 2
    env.GetTitleText = function() return "Offered quest" end
    local availableTitles = {"Offered quest"}
    env.GetAvailableTitle = function(index) return availableTitles[index] end
    env.GetActiveTitle = function() return "Active quest", true end
    env.GetNumActiveQuests = function() return 0 end
    env.GetNumAvailableQuests = function() return 1 end
    env.QuestTitleButton1 = {IsVisible = function() return true end, GetID = function() return 1 end}
    env.QuestTitleButton2 = {isActive = 1, IsVisible = function() return true end, GetID = function() return 1 end}
    env.UnitInBattleground = function() return true end
    env.IsQuestCompletable = function() return true end
    env.GetNumQuestChoices = function() return 1 end
    for _, action in ipairs({"AcceptQuest", "CompleteQuest", "GetQuestReward", "SelectAvailableQuest", "SelectGossipAvailableQuest", "DeclineQuest"}) do
        env[action] = function() actions[action] = (actions[action] or 0) + 1 end
    end
    env.Questie = {Debug = noop, Print = noop, db = {profile = {autocomplete = true,
        autoAccept = {enabled = true, trivial = true, repeatable = true, pvp = true, rejectSharedInBattleground = true}},
        global = {}, char = {complete = {}, hidden = {}}}}
    local compat = {C_Timer = {After = noop}, GetQuestResetTime = function() return 3600 end,
        GetServerTime = function() return 1791302400, {year = 2026, month = 10, day = 6, hour = 12, weekday = 3} end}
    env.QuestieCompat = compat
    -- Exercise the actual hex-GUID adapter, not a fixture with modern client GUIDs.
    loadFunction("Compat/Compat.lua", "function QuestieCompat.UnitGUID(unit)",
        'local GUIDType = {[1]="GameObject", [3]="Creature", [5]="Vehicle"}\n', env)
    local db = module("QuestieDB")
    local names = {[10] = "Offered quest", [11] = "Other daily", [12] = "Server choice",
        [13] = "Condition quest", [14] = "High level", [15] = "Active quest", [20] = "Offered quest"}
    db.QueryQuestSingle = function(id, field)
        if field == "name" then return names[id] end
    end
    db.QueryNPCSingle = function(id) return id == 111 and {10, 11, 12, 13, 14, 15} or {20} end
    db.QueryObjectSingle = function() return {10} end
    db.IsDoable = function() return true end
    db.IsDailyQuest = function() return true end
    db.IsWeeklyQuest, db.IsMonthlyQuest, db.IsRepeatable = function() return false end, function() return false end, function() return false end
    db.SetUnavailableQuestChecker = noop
    db.IsAzerothCoreAvailabilityConditionFulfilled = function(_, id) return id ~= 13 end
    db.GetQuest = function(id) return names[id] and {Id = id, Starts = {}} end
    db.GetQuestStartInfo = function(id) return db.GetQuest(id) end
    module("QuestiePlayer").currentQuestlog = {[15] = {}}
    module("QuestiePlayer").GetPlayerLevel = function() return 80 end
    module("QuestieLib").GetEffectiveQuestLevel = function(id) return 1, id == 14 and 90 or 1 end
    module("QuestieServer").GetQuestAvailabilityState = function(_, id) if id == 12 then return true end end
    module("ZoneDB").zoneIDs = {ICECROWN = 210}
    module("ZoneDB").GetDungeons = function() return {} end
    module("QuestieMap").questIdFrames = {}
    module("QuestieTooltips").lookupKeysByQuestId = {}
    module("DailyQuestComms").BroadcastUnavailableDailyQuests = function(id, quests)
        broadcasts[#broadcasts + 1] = {id = id, quests = quests}
    end
    loadFunction("Database/QuestieDB.lua", "function QuestieDB.GetQuestIDFromName(name, questgiverGUID, questStarter)",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\nlocal QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")\n', env)
    loadFunction("Compat/QuestLog.lua", "function QuestieCompat.GetQuestID(questStarter, title, unit)",
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB")\n', env)
    compat.GetAvailableQuests = function() return "Offered quest", 1, false, 1, false, false, false end
    compat.GetActiveQuests = function() return "Active quest", 1, false, false, false, false end
    loadModule("Modules/Auto/QuestieAuto.lua", env)
    loadModule("Modules/Quest/AvailableQuests.lua", env)
    local available = module("AvailableQuests")
    available.DrawAvailableQuest = function(quest) drawn[quest.Id] = (drawn[quest.Id] or 0) + 1 end
    local byNpc = upvalue(available.ValidateAvailableQuestsFromGossipShow, "availableQuestsByNpc")
    local h = {auto = module("QuestieAuto"), available = available, units = units, actions = actions,
        calls = calls, broadcasts = broadcasts, drawn = drawn, db = db, compat = compat,
        player = module("QuestiePlayer"), titles = availableTitles}
    function h:npc(id, questIds)
        byNpc[id] = {}; for _, questId in ipairs(questIds) do byNpc[id][questId] = true end
    end
    function h:mark(id, questId) available.RemoveQuestsForToday(id, {questId}) end
    function h:clearCalls() for index in pairs(calls) do calls[index] = nil end end
    return h
end

-- Each dialog reads its own token, even when both tokens refer to different givers.
for _, case in ipairs({{"GOSSIP_SHOW", "npc", "SelectGossipAvailableQuest"},
    {"QUEST_GREETING", "npc", "SelectAvailableQuest"}, {"QUEST_DETAIL", "questnpc", "AcceptQuest"},
    {"QUEST_PROGRESS", "questnpc", "CompleteQuest"}, {"QUEST_COMPLETE", "questnpc", "GetQuestReward"}}) do
    local h = harness(); h.units.npc, h.units.questnpc = rawGuid(111), rawGuid(222)
    h.auto[case[1]]()
    equal(h.actions[case[3]], 1, case[1] .. " retains automation")
    for _, unit in ipairs(h.calls) do equal(unit, case[2], case[1] .. " uses its dialog giver") end
    h = harness(); h.units.npc, h.units.questnpc = rawGuid(111), rawGuid(111)
    h.auto.private.disallowedNPCs = {[111] = true}; h.auto[case[1]]()
    equal(h.actions[case[3]], nil, case[1] .. " honors actual NPC exclusions")
    h = harness(); h.units.npc, h.units.questnpc = rawGuid(111, true), rawGuid(111, true)
    h.auto.private.disallowedNPCs = {[111] = true}; h.auto[case[1]]()
    equal(h.actions[case[3]], 1, case[1] .. " does not apply NPC exclusions to objects")
end
local h = harness(); h.auto.QUEST_DETAIL()
equal(h.actions.AcceptQuest, 1, "An item offer without a giver still accepts")
equal(h.actions.DeclineQuest, nil, "A missing giver does not trigger shared-quest rejection")
h = harness(); h.units.npc, h.units.questnpc = rawGuid(222), rawGuid(111)
equal(h.compat.GetQuestID(true), 20, "Default title lookup retains gossip context")
equal(h.compat.GetQuestID(true, nil, "questnpc"), 10, "Detail title lookup disambiguates the actual giver")
h.auto.private.disallowedQuests = {accept = {[20] = true}, turnIn = {[10] = true}}
h.auto.QUEST_DETAIL()
equal(h.actions.AcceptQuest, 1, "An unrelated greeting giver cannot apply its quest exclusion")
h.player.currentQuestlog[10] = {}
h.auto.QUEST_PROGRESS()
equal(h.actions.CompleteQuest, nil, "Turn-in exclusions use the detail giver's quest ID")
h.units.npc = rawGuid(111); h.units.questnpc = rawGuid(222)
h.auto.QUEST_DETAIL()
equal(h.actions.AcceptQuest, 1, "The actual detail quest's exclusion still applies")
h = harness(); h.units.npc, h.units.questnpc = rawGuid(111), rawGuid(222)
h.compat.GetAvailableQuests = function() return {title = "Unresolved quest", questID = 0} end
h.auto.private.disallowedQuests = {accept = {[20] = true}}
h.auto.GOSSIP_SHOW()
equal(h.actions.SelectGossipAvailableQuest, 1, "An unresolved list entry cannot borrow another dialog's quest ID")

for _, case in ipairs({{"ValidateAvailableQuestsFromGossipShow", "npc"},
    {"ValidateAvailableQuestsFromQuestGreeting", "npc"}, {"ValidateAvailableQuestsFromQuestDetail", "questnpc"}}) do
    h = harness(); h.units.npc, h.units.questnpc = rawGuid(111), rawGuid(111)
    h:mark(111, 10); h:mark(222, 10); h:mark(222, 20)
    h:npc(111, {11, 12, 13, 14, 15}); h:npc(222, {20}); h:clearCalls()
    h.available[case[1]]()
    for _, unit in ipairs(h.calls) do equal(unit, case[2], "Availability uses the actual dialog token") end
    equal(h.drawn[10], 1, "Explicit offers restore previously hidden quests")
    equal(h.available.IsUnavailableForCurrentReset(10), false, "Offer clears talk-based unavailability")
    local snapshot = h.available.GetUnavailableQuestSnapshot()
    for _, bucket in pairs(snapshot or {}) do
        for _, entry in pairs(bucket) do
            for _, id in pairs(entry.questIds) do assert(id ~= 10, "Offer must clear all persisted giver records") end
        end
    end
    equal(h.available.IsUnavailableForCurrentReset(20), true, "Other NPC observations survive")
    equal(h.available.IsUnavailableForCurrentReset(11), true, "Identified NPC's absent daily is hidden")
    equal(h.available.IsUnavailableForCurrentReset(12), false, "Authoritative server choice is preserved")
    equal(h.available.IsUnavailableForCurrentReset(13), false, "AzerothCore condition exclusion is preserved")
    equal(h.available.IsUnavailableForCurrentReset(14), false, "Level exclusion is preserved")
    if case[2] == "npc" then equal(h.available.IsUnavailableForCurrentReset(15), false, "Active quests remain available") end
    equal(h.broadcasts[1].id, 111, "Unavailable daily broadcasts belong to the actual NPC")
    h.available[case[1]](); equal(h.drawn[10], 1, "Repeated validation does not redraw an unchanged offer")

    h = harness(); h.units.npc, h.units.questnpc = rawGuid(111, true), rawGuid(111, true)
    h:mark(111, 10); h:npc(111, {11}); h.available[case[1]]()
    equal(h.drawn[10], 1, "Object GUID still resolves the offered quest by title")
    equal(h.available.IsUnavailableForCurrentReset(11), false, "Object cannot hide a same-ID NPC's quests")
    equal(#h.broadcasts, 0, "Object offers cannot broadcast NPC-specific absences")
end

-- An unresolved greeting leaves its NPC retryable when title data becomes available.
h = harness(); h.units.npc = rawGuid(111); h:npc(111, {11}); h.titles[1] = "Loading title"
h.available.ValidateAvailableQuestsFromQuestGreeting()
equal(h.available.IsUnavailableForCurrentReset(11), false, "An incomplete list cannot prove absence")
h.titles[1] = "Offered quest"; h.available.ValidateAvailableQuestsFromQuestGreeting()
equal(h.available.IsUnavailableForCurrentReset(11), true, "The same giver can be retried after a title loads")

-- Structured offers can be restored without giver identity; absence cannot be inferred.
h = harness(); h:mark(111, 10); h:npc(111, {11})
h.compat.GetAvailableQuests = function() return {questID = 10, title = "Offered quest"} end
h.available.ValidateAvailableQuestsFromGossipShow()
equal(h.drawn[10], 1, "Explicit structured IDs work without an NPC")
equal(h.available.IsUnavailableForCurrentReset(11), false, "Unknown identity cannot hide another NPC's daily")
equal(#h.broadcasts, 0, "Unknown identity produces no NPC-specific broadcast")

h = harness(); h.db.IsDailyQuest = function(id) return id ~= 10 end
h.db.IsWeeklyQuest = function(id) return id == 10 end
h.units.questnpc = rawGuid(111, true); h:mark(111, 10); h:mark(222, 10)
h.available.ValidateAvailableQuestsFromQuestDetail()
equal(h.available.IsUnavailableForCurrentReset(10), false, "Weekly offers also clear persisted observations")
equal(h.available.GetUnavailableQuestSnapshot(), nil, "An explicit offer removes all stale weekly records")

-- Missing map guidance must not invent completion or discard client progress.
do
    local state = {entry = {isComplete = 0}, objectives = {}, finishers = 0}
    local questModule = {
        GetAllLeaderBoardDetails = function() return state.objectives end,
        AddFinisher = function() state.finishers = state.finishers + 1 end,
    }
    local private = {}
    local env = setmetatable({FixtureQuest = questModule, FixturePrivate = private}, {__index = _G})
    env.bit = bit or bit32 or {band = function(value, mask)
        assert(mask == 2); return math.floor(value / 2) % 2 * 2
    end}
    env.FixtureLog = {GetQuest = function() return state.entry end}
    env.FixtureDB = {questEventTooltipTargets = {[155] = {{"monster", 467}}}}
    env.FixtureAvailable = {RemoveQuest = function(_, callback) callback() end}
    env.FixtureLib = {GetFullObjectiveText = function(text) return text end}
    env.FixtureAddon = {Debug = noop}
    local prefix = 'local QuestieQuest, _QuestieQuest = FixtureQuest, FixturePrivate\n'
        .. 'local Questie, QuestieLib = FixtureAddon, FixtureLib\n'
        .. 'local QuestLogCache, AvailableQuests = FixtureLog, FixtureAvailable\n'
        .. 'local QuestieDB = FixtureDB\n'
    loadFunction("Modules/Quest/QuestieQuest.lua", "function _QuestieQuest.ObjectiveUpdate(self)", prefix, env)
    loadFunction("Modules/Quest/QuestieQuest.lua", "function QuestieQuest:PopulateQuestLogInfo(quest)", prefix, env)
    local function quest(flags, data)
        return {Id = 155, specialFlags = flags, ObjectiveData = data, Objectives = {}, SpecialObjectives = {}, Finisher = {Id = 467}}
    end
    local eventQuest = quest(2)
    questModule:PopulateQuestLogInfo(eventQuest)
    assert(not eventQuest.isComplete and state.finishers == 0, "An unfinished event was marked ready to turn in")
    local delivery = quest(0)
    questModule:PopulateQuestLogInfo(delivery)
    assert(delivery.isComplete and state.finishers == 1, "Objective-free delivery lost its finisher")
    state.objectives = {{type = "event", text = "Escort the NPC", raw_text = "Escort the NPC", finished = false}}
    eventQuest = quest(2)
    questModule:PopulateQuestLogInfo(eventQuest)
    assert(not eventQuest.isComplete and eventQuest.Objectives[1].Completed == false)
    equal(eventQuest.Objectives[1].Description, "Escort the NPC", "Client event progress survives omitted map guidance")
    assert(next(eventQuest.Objectives[1].Coordinates) == nil, "Unverified event coordinates appeared")
    state.objectives = {{type = "monster", text = "Target: 1/3", raw_text = "Target: 1/3", numFulfilled = 1, numRequired = 3}}
    local unknown = quest(0)
    questModule:PopulateQuestLogInfo(unknown)
    assert(not unknown.isComplete and unknown.Objectives[1].Collected == 1 and unknown.Objectives[1].Needed == 3)
    assert(next(unknown.Objectives[1].Coordinates) == nil, "Missing targets produced a fabricated map pin")
    local mapped = quest(0, {{Type = "monster", Id = 42}})
    questModule:PopulateQuestLogInfo(mapped)
    equal(mapped.Objectives[1].Id, 42, "Verified objective data was replaced by a fallback")
    state.entry.isComplete, state.objectives = 1, {}
    eventQuest = quest(2)
    questModule:PopulateQuestLogInfo(eventQuest)
    assert(eventQuest.isComplete, "Authoritative server completion was ignored")
end

-- A duplicate source item must not suppress later, independently useful tools.
do
    local state = {registered = {}, queried = {}}
    local env = setmetatable({Questie = {Debug = noop}}, {__index = _G})
    -- Fix array traversal order so the duplicate is always encountered first.
    env.pairs = ipairs
    env.QuestieDB = {
        QueryQuestSingle = function() return state.objectives end,
        QueryItemSingle = function(id)
            state.queried[#state.queried + 1] = id
            return "Tool " .. id
        end,
    }
    env.QuestieTooltips = {RegisterObjectiveTooltip = function(_, questId, key, objective)
        equal(questId, 24461, "Source-item tooltip keeps its quest")
        assert(objective.IsRequiredSourceItem and objective.QuestData == state.quest)
        state.registered[key] = objective
    end}
    local declaration = "local function _AddRequiredSourceItemObjective(quest)"
    local pattern = declaration:gsub("(%W)", "%%%1") .. ".-\nend"
    compile(assert(read("Modules/Quest/QuestieQuest.lua"):match(pattern), declaration)
        .. "\nFixtureRun = _AddRequiredSourceItemObjective", env)
    local function run(objectives, sourceItemId, required)
        state.objectives, state.queried, state.registered = objectives, {}, {}
        state.quest = {Id = 24461, sourceItemId = sourceItemId, requiredSourceItems = required}
        env.FixtureRun(state.quest)
    end
    run({nil, nil, {{49739, 1}}}, nil, {49739, 49740})
    equal(#state.queried, 1, "An objective item is not registered twice")
    equal(state.queried[1], 49740, "Processing continues after an objective duplicate")
    equal(state.registered.i_49740.Index, 2, "Later tool keeps its source-item index")
    run(nil, 49718, {49718, 49723})
    equal(#state.queried, 1, "A provided source item is not registered twice")
    assert(state.registered.i_49723, "A source-item duplicate suppressed the next tool")
    run(nil, nil, {49723})
    assert(state.registered.i_49723, "Missing objective data suppressed a verified tool")
    run({nil, nil, {{49739, 49723}}}, nil, {49723})
    assert(state.registered.i_49723, "An objective count was mistaken for an item ID")
end

print("Quest dialog identity tests passed")
