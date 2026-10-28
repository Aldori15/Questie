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
    return {quest = quest, module = questModule, modules = modules, tooltips = tooltips, jobs = jobs,
        runJobs = runJobs, count = count,
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

print("Quest objective completion regression tests passed (" .. tests .. " groups)")
