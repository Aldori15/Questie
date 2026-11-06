-- Run from the addon directory with Lua 5.2+. Investigates #155 using the
-- production objective population/completion code and simulated map frames.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function setup(historical)
    local env = setmetatable({}, {__index = _G})
    env.bit = bit or bit32 or {band = function(value, mask)
        assert(mask == 2)
        return math.floor(value / 2) % 2 * 2
    end}
    local modules, frames, tooltips, jobs = {}, {}, {}, {}
    local active, ready = true, 0
    local function noop() end
    env.coroutine = setmetatable({running = function()
        local thread, main = coroutine.running()
        if not main then return thread end
    end}, {__index = coroutine})
    env.QuestieLoader = {
        CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
        ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    }
    env.Questie = {db = {profile = {objectiveFilterDistance = 0}, char = {complete = {[12960] = historical}}},
        Debug = noop, SendMessage = noop}
    env.QuestieCompat = {C_Timer = {}, HBD = {GetWorldCoordinatesFromZone = function(_, x, y) return x, y end},
        GetQuestLogIndexByID = function() if active then return 1 end end}
    local cache = {{type = "item", text = "Wicked Sun Brooch", raw_text = "Wicked Sun Brooch: 0/1",
        numFulfilled = 0, numRequired = 1, finished = false}}
    modules.QuestLogCache = {GetQuest = function() return {isComplete = ready, objectives = cache} end,
        GetQuestObjectives = function() return cache end}
    modules.QuestieAnnounce = {ObjectiveChanged = noop}
    modules.QuestieCombatQueue = {Queue = function(_, fn) fn() end}
    modules.AvailableQuests = {RemoveQuest = function(_, callback) callback() end}
    modules.QuestieTracker = {Update = noop}
    modules.TrackerUtils = {ClearTomTomTargetForQuest = noop}
    modules.AutoRoute = {ScheduleUpdate = noop}
    modules.QuestieIconVisibility = {IsEnabledAnywhere = function() return true end}
    modules.Phasing = {IsSpawnDataVisible = function() return true end}
    modules.ZoneDB = {GetUiMapIdByAreaId = function(_, zone) return zone end, GetDungeonLocation = function() end}
    modules.QuestieLib = {ColorWheel = function() return {} end, Euclid = function() return 0 end,
        GetFullObjectiveText = function(text) return text end}
    modules.ThreadLib = {ThreadCallbackInstant = function(fn, callback)
        jobs[#jobs + 1] = {thread = coroutine.create(fn), callback = callback}
    end}
    modules.QuestieTooltips = {lookupByKey = {},
        RegisterObjectiveTooltip = function(_, _, key) tooltips[key] = true end,
        RegisterQuestStartTooltip = noop}
    modules.QuestieFramePool = {UnloadFrame = function(_, frame) frames[frame] = nil end}
    local quest = {Id = 12960, sourceItemId = 0, Objectives = {},
        SpecialObjectives = {[42105] = {Id = 42105, Type = "item", Description = "Iron Dwarf Brooch"}},
        ObjectiveData = {{Id = 43272, Type = "item"}},
        Finisher = {Id = 28701, Type = "monster"}, IsComplete = function() return ready end}
    modules.QuestiePlayer = {currentQuestlog = {[12960] = quest}}
    modules.QuestieDB = {GetQuest = function() return quest end, IsPvPQuest = function() return false end,
        QueryItemSingle = function(id) return tostring(id) end,
        GetNPC = function() return {id = 28701, name = "Timothy Jones", spawns = {[4395] = {{40, 35}}}} end}
    modules.QuestieEvent = {IsEventQuest = function() return false end}
    modules.QuestieMap = {
        FindClosestStarter = function() return {} end, IsLootedObjectSpawn = function() return false end,
        DrawWorldIcon = function(_, data)
            local map, mini = {}, {}
            frames[map], frames[mini] = data, data
            return map, mini
        end,
        UnloadQuestFrames = function()
            for frame in pairs(frames) do frames[frame] = nil end
            for _, objective in pairs(quest.Objectives) do objective.AlreadySpawned = {} end
            for _, objective in pairs(quest.SpecialObjectives) do objective.AlreadySpawned = {} end
        end,
    }
    assert(loadfile("Modules/Quest/QuestieQuest.lua", "t", env))()
    local questModule = modules.QuestieQuest
    questModule.private.objectiveSpawnListCallTable = {item = function(id)
        return {{Id = 1, ItemId = id, Name = "Item source", TooltipKey = "m_1",
            Spawns = {[394] = {{50, 50}}}, GetIconScale = function() return 1 end}}
    end, monster = function(id)
        return {{Id = id, Name = "Flight NPC", TooltipKey = "m_" .. id,
            Spawns = {[394] = {{60, 60}}}, GetIconScale = function() return 1 end}}
    end}
    local function runJobs()
        while #jobs > 0 do
            local job = table.remove(jobs, 1)
            local ok, message = coroutine.resume(job.thread)
            assert(ok, message)
            if coroutine.status(job.thread) == "dead" then job.callback(true)
            else jobs[#jobs + 1] = job end
        end
    end
    local function count(kind)
        local value = 0
        for _, data in pairs(frames) do if data.Type == kind then value = value + 1 end end
        return value
    end
    questModule:PopulateQuestLogInfo(quest)
    return {quest = quest, module = questModule, modules = modules, env = env, tooltips = tooltips, jobs = jobs,
        runJobs = runJobs, count = count,
        setObjectives = function(values) cache = values end,
        finish = function()
            ready = 1
            cache[1].finished, cache[1].numFulfilled = true, 1
            questModule:SetObjectivesDirty(12960)
            questModule:UpdateQuest(12960)
        end,
        setTravel = function(status)
            ready, cache = status, {}
            quest.Objectives, quest.ObjectiveData = {}, {}
            quest.SpecialObjectives = {{Optional = true, Type = "monster", Id = 20235,
                Description = "Speak with Gryphoneer Windbellow", AlreadySpawned = {}}}
        end,
        remove = function() active = false; modules.QuestiePlayer.currentQuestlog[12960] = nil end}
end

for _, history in ipairs({false, true}) do
    local s = setup(history)
    s.module:UpdateObjectiveNotes(s.quest); s.runJobs()
    equal(s.count("item"), 4, "both objective and ingredient locations drawn")
    s.finish(); s.runJobs()
    equal(s.count("item"), 0, "ready quest removes all ingredient/objective icons")
    equal(s.count("complete"), 2, "ready quest draws turn-in location despite history")
    equal(s.quest.WasComplete, true, "completion handled")
    equal(s.tooltips.m_1, true, "objective tooltips retained until turn-in")
    tests = tests + 1
end

-- Objective jobs queued before completion cannot restore ingredient icons afterwards.
do
    local s = setup(true)
    s.module:UpdateObjectiveNotes(s.quest)
    s.finish(); s.runJobs()
    equal(s.count("item"), 0, "late population cannot redraw completed ingredient")
    equal(s.count("complete"), 2, "late population preserves turn-in icons")
    tests = tests + 1
end

-- An asynchronous completion callback must not revive a rewarded/abandoned quest.
do
    local s = setup(true)
    s.module:UpdateObjectiveNotes(s.quest); s.runJobs()
    s.finish(); s.remove(); s.runJobs()
    equal(s.count("item"), 0, "removed quest objectives stay removed")
    equal(s.count("complete"), 0, "late cleanup does not revive removed finisher")
    tests = tests + 1
end

-- Optional travel guidance stays useful while an objective-free quest is ready to turn in.
for _, status in ipairs({0, 1}) do
    local s = setup(false)
    s.setTravel(status)
    s.module:UpdateQuest(s.quest.Id); s.runJobs()
    equal(s.count("complete"), 2, "delivery finisher remains visible with travel guidance, status " .. status)
    equal(s.count("monster"), 2, "flight NPC remains visible with finisher, status " .. status)
    tests = tests + 1
end

do
    local s = setup(false)
    s.setTravel(0)
    s.module:UpdateQuest(s.quest.Id); s.runJobs()
    s.setTravel(1)
    s.module:UpdateQuest(s.quest.Id); s.runJobs()
    equal(s.count("complete"), 2, "completion transition leaves one finisher pair")
    equal(s.count("monster"), 2, "completion cleanup restores one optional flight hint pair")
    tests = tests + 1
end

-- Finished bombing/collection quests keep normal cleanup; their takeoff helper
-- must not return after completion merely because travel guidance is optional.
do
    local s = setup(false)
    s.setTravel(1)
    s.quest.ObjectiveData = {{Type = "item", Id = 43272}}
    s.module:UpdateQuest(s.quest.Id); s.runJobs()
    equal(s.count("complete"), 2, "completed quest keeps its finisher")
    equal(s.count("monster"), 0, "completed source objectives do not restore a takeoff hint")
    tests = tests + 1
end

-- Queued helper redraws cannot revive abandoned quests or bypass hidden map notes.
for _, status in ipairs({0, 1}) do
    local s = setup(false)
    s.setTravel(status)
    s.module:UpdateQuest(s.quest.Id)
    s.modules.QuestieMap:UnloadQuestFrames(s.quest.Id)
    s.remove(); s.runJobs()
    equal(s.count("complete"), 0, "abandoned delivery finisher stays removed")
    equal(s.count("monster"), 0, "abandoned flight hint stays removed")
    local hidden = setup(false)
    hidden.setTravel(status)
    hidden.quest.HideIcons = true
    hidden.module:UpdateQuest(hidden.quest.Id); hidden.runJobs()
    equal(hidden.count("monster"), 0, "hidden flight hint is not redrawn")
    tests = tests + 1
end

-- Fishing guides belong to the real item objective, including after binary decoding.
for _, entry in ipairs({{1141, 12238, 148, 35.71, 44.68}, {1579, 6717, 148, 35.71, 44.68},
    {1580, 6718, 148, 50.7, 23.8}, {6607, 16967, 357, 62.6, 50.2},
    {9205, 13890, 357, 49, 11},
    {11665, 34864, 1519, 48.5, 67.9}, {11666, 34865, 3519, 51.9, 34.7},
    {11667, 34868, 3518, 62, 35}, {11668, 34866, 3521, 75.6, 82.9}, {11669, 34867, 3483, 39.4, 43},
    {13830, 45902, 3711, 48.2, 63.4, true}, {13832, 45903, 4560, 46, 68},
    {13833, 45905, 3537, 57.5, 33.2},
    {13834, 45904, 4197, 70, 36}, {13836, 45323, 4395, 67.43, 61.38}}) do
    local s = setup(false)
    local env, modules = s.env, s.modules
    local db = modules.QuestieDB
    local getNPC, isPvP = db.GetNPC, db.IsPvPQuest
    env._G, env.unpack, env.GetCVar = env, table.unpack, function() return "" end
    env.tremove = table.remove
    env.Questie.ICON_TYPE_NODE_FISH, env.Questie.Error = 20, error
    env.QuestieCompat.C_QuestLog = {IsOnQuest = function() return true end}
    env.QuestieCompat.HBDPins, env.QuestieCompat.C_Map = {}, {}
    env.QuestieCompat.HBD.GetPlayerWorldPosition = function() return 0, 0, 530 end
    env.QuestieCompat.HBD.GetWorldCoordinatesFromZone = function(_, x, y) return x, y, 530 end
    env.QuestieCompat.HBD.GetWorldDistance = function(_, _, x, y, a, b) return math.abs(a - x) + math.abs(b - y) end
    modules.QuestieLib.GetEffectiveQuestLevel = function() return 70, 70 end
    modules.ZoneDB.zoneIDs = {ICECROWN = 210}
    modules.QuestieCorrections = {hiddenQuests = {}, itemObjectiveFirst = {}, killCreditObjectiveFirst = {},
        triggerEndTooltipTargets = {}, questItemBlacklist = {}, questNPCBlacklist = {}}
    assert(loadfile("Database/QuestieDB.lua", "t", env))()
    assert(loadfile("Database/questDB.lua", "t", env))()
    assert(loadfile("Database/itemDB.lua", "t", env))()
    assert(loadfile("Modules/QuestieStream.lua", "t", env))()
    assert(loadfile("Database/compiler.lua", "t", env))()
    local questId, itemId, zone, x, y, sourceOnly = table.unpack(entry)
    local keys = db.questKeys
    local row = {[keys.name] = "Fishing daily", [keys.startedBy] = {}, [keys.finishedBy] = {},
        [keys.questLevel] = 70, [keys.requiredLevel] = 70, [keys.objectives] = {nil, nil, {{itemId}}}}
    local guide = {{{[zone] = {{x, y}}}, 20, "Fish here", 1}}
    local fishingIndex = 1
    if questId == 9205 then
        fishingIndex = 2
        row[keys.objectives][3] = {{22623}, {itemId}}
        guide[1][4] = fishingIndex
        s.setObjectives({{type = "item", text = "Craftsman's Writ", raw_text = "Craftsman's Writ: 1/1",
            numFulfilled = 1, numRequired = 1, finished = true},
            {type = "item", text = "Plated Armorfish", raw_text = "Plated Armorfish: 0/30",
             numFulfilled = 0, numRequired = 30, finished = false}})
    end
    if sourceOnly then
        row[keys.objectives], row[keys.requiredSourceItems] = nil, {itemId}
        guide[1][4], guide[1][5] = 0, {{"item", itemId}}
        s.setObjectives({{type = "event", text = "Discover the Ghostfish mystery", raw_text = "Discover the Ghostfish mystery",
            numFulfilled = 0, numRequired = 1, finished = false}})
    end
    local compiler = modules.DBCompiler
    local stream = modules.QuestieStreamLib:GetStream("raw")
    compiler.writers.extraobjectives(stream, guide)
    local encoded = stream:Save(); stream:finished()
    stream = modules.QuestieStreamLib:GetStream("raw"); stream:Load(encoded)
    row[keys.extraObjectives] = compiler.readers.extraobjectives(stream); stream:finished()
    db.QuestPointers = {[questId] = true}
    db.QueryQuestSingle = function(_, key) return row[keys[key]] end
    db.QueryQuest = function() return row end
    local itemRow = {[db.itemKeys.name] = "Quest fish"}
    db.QueryItem = function() return itemRow end
    if questId == 13833 then
        itemRow[db.itemKeys.objectDrops] = {194479}
        db.QueryObjectSingle = function(_, key) if key == "name" then return "Pool of Blood" end end
    end
    db.QueryNPCSingle = function(_, key)
        if key == "name" then return "Ordinary source" end
        if key == "spawns" then return {[4395] = {{40, 35}}} end
    end
    local parseQuest = db.GetQuest
    local parsed = assert(parseQuest(questId))
    local fishingData = sourceOnly and parsed.SpecialObjectives[itemId] or parsed.ObjectiveData[fishingIndex]
    if sourceOnly then
        equal(next(parsed.SpecialObjectives, itemId), nil, "required source item gets no duplicate fishing objective")
        equal(next(parsed.ObjectiveData), nil, "fishing helper does not invent an item or fixed completion objective")
    else
        equal(next(parsed.SpecialObjectives), nil, "linked fishing guide creates no duplicate special objective")
    end
    assert(fishingData.FallbackSpawnList, "binary guide is attached to existing item objective")
    local decoded = fishingData.FallbackSpawnList[1].Spawns[zone][1]
    assert(math.abs(decoded[1] - x) < 0.1 and math.abs(decoded[2] - y) < 0.1, "binary fishing coordinates keep normal precision")
    x, y = decoded[1], decoded[2]
    s.quest.ObjectiveData, s.quest.SpecialObjectives, s.quest.Objectives = parsed.ObjectiveData, parsed.SpecialObjectives, {}
    db.GetQuest, db.GetNPC, db.IsPvPQuest = function() return s.quest end, getNPC, isPvP
    assert(loadfile("Modules/Quest/QuestieQuestPrivates.lua", "t", env))()
    local map = modules.QuestieMap
    local draw, unload, closest = map.DrawWorldIcon, map.UnloadQuestFrames, map.FindClosestStarter
    assert(loadfile("Modules/Map/QuestieMap.lua", "t", env))()
    map.DrawWorldIcon, map.UnloadQuestFrames, map.FindClosestStarter = draw, unload, closest
    s.module:PopulateQuestLogInfo(s.quest)
    s.module:UpdateObjectiveNotes(s.quest); s.runJobs()
    equal(s.count("item"), 2, "one fishing location draws one map/minimap pair")
    if questId == 13833 then
        equal(s.tooltips.o_194479, true, "dynamic pool keeps its objective tooltip despite lacking fixed coordinates")
    end
    local objective = sourceOnly and s.quest.SpecialObjectives[itemId] or s.quest.Objectives[fishingIndex]
    local point, area = map:GetNearestSpawn(objective)
    equal(area, zone, "original item objective has fishing destination")
    equal(point[1], x, "original item objective preserves reviewed X coordinate")
    equal(point[2], y, "original item objective preserves reviewed Y coordinate")
    local questPoint, questArea = map:GetNearestQuestSpawn(s.quest)
    equal(questArea, zone, "quest-level navigation uses the same fishing location")
    equal(questPoint[1], x, "quest-level navigation agrees with objective navigation")
    local target
    env.TomTom = {AddWaypoint = function() end}
    env.QuestieCompat.TomTom_AddWaypoint = function(_, uiMap, tx, ty)
        target = {uiMap, tx, ty}; return 1
    end
    assert(loadfile("Modules/Tracker/TrackerWaypoints.lua", "t", env))()
    modules.TrackerWaypoints:SetTomTomTarget("Quest fish", area, point[1], point[2], s.quest.Id, objective.Index)
    equal(target[1], zone, "TomTom receives the fishing map")
    equal(target[2], x, "TomTom receives fishing X")
    equal(target[3], y, "TomTom receives fishing Y")
    local file = assert(io.open("Modules/FramePool/QuestieFrame.lua", "r"))
    local hiddenCheck = assert(file:read("*a"):gsub("\r\n", "\n"):match("function _QuestieFrame:ShouldBeHidden%(%).-\nend"))
    file:close()
    env._QuestieFrame, env.QuestieDB, env.QuestieIconVisibility = {}, db, modules.QuestieIconVisibility
    env.QuestieMap, env.QuestieQuest = map, s.module
    modules.QuestieIconVisibility.IsEnabled = function() return true end
    for _, name in ipairs({"IsRepeatable", "IsActiveEventQuest", "IsDungeonQuest", "IsRaidQuest"}) do
        db[name] = function() return false end
    end
    env.Questie.db.profile.enabled, env.Questie.db.profile.enableMapIcons = true, true
    assert(load(hiddenCheck, "@production-pin-visibility", "t", env))()
    local frame = {data = objective.AlreadySpawned[1].data}
    objective.HideIcons = true
    equal(env._QuestieFrame.ShouldBeHidden(frame), true, "hiding original item objective hides its fishing pins")
    objective.HideIcons = nil
    equal(env._QuestieFrame.ShouldBeHidden(frame), false, "showing original item objective restores fishing pins")
    itemRow[db.itemKeys.npcDrops] = {1}
    local actual = modules.QuestieQuest.private.objectiveSpawnListCallTable.item(itemId, objective, fishingData)
    assert(actual[1].Spawns ~= fishingData.FallbackSpawnList[1].Spawns,
        "normal mapped sources take precedence over fishing fallback")
    modules.QuestieCorrections.questItemBlacklist[itemId] = true
    equal(next(modules.QuestieQuest.private.objectiveSpawnListCallTable.item(itemId, objective, fishingData)), nil,
        "fallback never bypasses an item blacklist")
    modules.QuestieCorrections.questItemBlacklist[itemId] = nil
    s.finish(); s.runJobs()
    equal(s.count("item"), 0, "completion removes fishing guidance")
    for _, icon in ipairs(sourceOnly and {} or {20, 3}) do
        db.private.questCache[questId] = nil
        row[keys.extraObjectives][1][2] = icon
        row[keys.extraObjectives][1][4] = icon == 20 and 0 or 1
        local ordinary = parseQuest(questId)
        assert(ordinary.SpecialObjectives[1] and not ordinary.ObjectiveData[1].FallbackSpawnList,
            "unlinked fishing guides and other linked helper types retain ordinary special objectives")
    end
    if questId == 6607 then
        local fish = {{16967, 357}, {16970, 8}, {16968, 405}, {16969, 33}}
        row[keys.objectives], row[keys.extraObjectives] = {nil, nil, {}}, {}
        for index, location in ipairs(fish) do
            row[keys.objectives][3][index] = {location[1]}
            row[keys.extraObjectives][index] = {{[location[2]] = {{50, 50}}}, 20, "Fish here", index}
        end
        db.private.questCache[questId] = nil
        local multiple = parseQuest(questId)
        for index, location in ipairs(fish) do
            equal(multiple.ObjectiveData[index].Id, location[1], "multiple-fish objective keeps its item ID")
            assert(multiple.ObjectiveData[index].FallbackSpawnList[1].Spawns[location[2]],
                "each fish gets only its own fishing zone")
        end
        equal(next(multiple.SpecialObjectives), nil, "multiple fish create no duplicate helpers")
    end
    tests = tests + 1
end

print("Quest objective completion regression tests passed (" .. tests .. " groups)")
