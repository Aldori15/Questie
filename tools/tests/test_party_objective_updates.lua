-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the real party renderer with queued frames and pooled icon ownership.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function setup()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    -- Lua 5.2 runners permit protected calls to yield; WoW 3.3.5's Lua 5.1 does not.
    local protectedDepth, mainThread = {}, {}
    local unpackValues = unpack or table.unpack
    local function protectedCall(base, callback, ...)
        local worker = coroutine.running() or mainThread
        protectedDepth[worker] = (protectedDepth[worker] or 0) + 1
        local result = {base(callback, ...)}
        protectedDepth[worker] = protectedDepth[worker] - 1
        return unpackValues(result)
    end
    env.xpcall = function(callback, handler) return protectedCall(xpcall, callback, handler) end
    env.pcall = function(callback, ...) return protectedCall(pcall, callback, ...) end
    env.coroutine = setmetatable({yield = function(...)
        assert((protectedDepth[coroutine.running() or mainThread] or 0) == 0, "yield crossed a Lua 5.1 protected-call boundary")
        return coroutine.yield(...)
    end}, {__index = coroutine})
    local modules, queue = {}, {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    local s = {env = env, modules = modules, quests = {}, pins = {}, errors = {}, draws = 0,
        unloads = 0, refreshes = 0, group = true, online = true, visible = true, perObjective = 1}
    local function later(callback) queue[#queue + 1] = callback end
    function s.step()
        local work = queue
        queue = {}
        local before = s.unloads
        for _, callback in ipairs(work) do callback() end
        return s.unloads - before
    end
    function s.drain()
        for _ = 1, 1000 do
            if #queue == 0 then
                assert(s.failQuest or #s.errors == 0, table.concat(s.errors, "\n"))
                return
            end
            s.step()
        end
        error("party scheduler did not settle")
    end
    function s.active(id, index)
        local count = 0
        for _, pin in ipairs(s.pins) do
            if pin.data and (not id or pin.data.Id == id)
                and (not index or pin.data.ObjectiveIndex == index) and not pin.minimap then count = count + 1 end
        end
        return count
    end
    env.Questie = {db = {profile = {showPartyQuestObjectives = true, enableObjectives = true}}, Debug = function() end}
    env.QUEST_MONSTERS_KILLED, env.QUEST_ITEMS_NEEDED, env.QUEST_OBJECTS_FOUND = "%s slain: %d/%d", "%s: %d/%d", "%s: %d/%d"
    env.UnitIsConnected = function() return s.online end
    env.CallErrorHandler = function(message) s.errors[#s.errors + 1] = tostring(message) end
    env.QuestieCompat = {C_Timer = {After = function(_, callback) later(callback) end},
        C_QuestLog = {GetQuestObjectives = function() return {} end},
        GetQuestLogIndexByID = function(id) return module("QuestLogCache").questLog_DO_NOT_MODIFY[id] and id end,
        GetGroupUnitByName = function() return "party1" end, GetNumGroupMembers = function() return 2 end,
        IsQuestSequenced = function() return false end}
    local function thread(callback, completed, immediate)
        local worker = coroutine.create(callback)
        local function resume()
            local ok, message = coroutine.resume(worker)
            if not ok then
                env.CallErrorHandler(message)
                if completed then completed(false, message) end
            elseif coroutine.status(worker) == "dead" then
                if completed then completed(true) end
            else later(resume) end
        end
        if immediate then resume() else later(resume) end
    end
    module("ThreadLib").ThreadCallback = function(callback, _, completed) thread(callback, completed) end
    -- On 3.3.5 these aliases still schedule their first resume for a later frame.
    module("ThreadLib").ThreadCallbackInstant = function(callback, completed) thread(callback, completed) end
    module("ThreadLib").ThreadInstant = function(callback) thread(callback) end
    module("ThreadLib").Thread = function(callback, _, _, completed) thread(callback, completed) end
    module("QuestiePlayer").GetGroupType = function() return s.group and "party" or nil end
    module("QuestLogCache").questLog_DO_NOT_MODIFY = {}
    module("QuestieComms").remoteQuestLogs = {}
    module("CommsVisibility").ShouldShowPartyObjective = function() return s.visible end
    module("QuestieIconVisibility").IsEnabledAnywhere = function() return env.Questie.db.profile.enableObjectives end
    module("QuestieIconVisibility").IsEnabled = module("QuestieIconVisibility").IsEnabledAnywhere
    module("QuestieLib").ColorWheel = function() return {} end
    module("QuestieLib").GetFullObjectiveText = function(text) return text end
    local db = module("QuestieDB")
    db.GetQuest = function(id) return s.quests[id] end
    db.GetNPC, db.GetItem, db.GetObject = function(_, id) return {name = "Target " .. tostring(id)} end,
        function(_, id) return {name = "Item " .. tostring(id)} end, function(_, id) return {name = "Object " .. tostring(id)} end
    module("MapIconTooltip").RefreshQuest = function() s.refreshes = s.refreshes + 1 end
    module("QuestieFramePool").UnloadFrame = function(_, pin)
        assert(pin.data, "already released icon unloaded again")
        pin.data = nil
        s.unloads = s.unloads + 1
    end
    module("QuestieQuest").PopulateObjective = function(_, quest, index, objective)
        s.draws = s.draws + 1
        if s.failQuest == quest.Id then error("fixture draw failure") end
        objective.spawnList = {true}
        if not env.Questie.db.profile.enableObjectives then return end
        local data = {Id = quest.Id, ObjectiveIndex = index, ObjectiveData = objective}
        local spawn = {data = data, mapRefs = {}, minimapRefs = {}}
        objective.AlreadySpawned[1] = spawn
        for _ = 1, s.perObjective do
            local mapPin, miniPin = {data = data}, {data = data, minimap = true}
            spawn.mapRefs[#spawn.mapRefs + 1], spawn.minimapRefs[#spawn.minimapRefs + 1] = mapPin, miniPin
            s.pins[#s.pins + 1], s.pins[#s.pins + 2] = mapPin, miniPin
        end
        if s.yieldDraw and (not s.yieldIndex or s.yieldIndex == index) then env.coroutine.yield() end
    end
    function s.quest(id, count)
        local quest = {Id = id, ObjectiveData = {}, Objectives = {}, SpecialObjectives = {}}
        local remote = {}
        for index = 1, count or 1 do
            quest.ObjectiveData[index] = {Id = id * 10 + index, Type = "monster", Text = "Target " .. index}
            remote[index] = {id = id * 10 + index, type = "m", fulfilled = 0, required = 5, finished = false}
        end
        s.quests[id] = quest
        module("QuestieComms").remoteQuestLogs[id] = {Friend = remote}
        return quest, remote
    end
    local source = assert(io.open("Modules/Network/QuestiePartyObjectives.lua", "r"))
    local code = source:read("*a"); source:close()
    if setfenv then setfenv(assert(loadstring(code)), env)() else assert(load(code, "@QuestiePartyObjectives.lua", "t", env))() end
    s.party = module("QuestiePartyObjectives")
    function s.update() s.party:Update(); s.drain() end
    return s
end

do
    local s = setup()
    local _, remote = s.quest(1)
    s.update()
    equal(s.active(1), 1, "initial party icon")
    local draws, unloads = s.draws, s.unloads
    remote[1].fulfilled = 1
    s.update()
    equal(s.draws, draws, "counter-only full refresh keeps existing icons")
    equal(s.unloads, unloads, "counter-only refresh never unloads icons")
    assert(s.refreshes > 0, "retained icons refresh tooltip progress")
    remote[1].fulfilled = 2
    s.party:ScheduleUpdate(1)
    s.drain()
    equal(s.draws, draws, "counter-only incremental refresh also reuses icons")
    s.pins[1].data = nil
    s.update()
    equal(s.draws, draws + 1, "lost or recycled party icon is rebuilt")
    remote[1].finished = true
    s.update()
    equal(s.active(1), 0, "party completion removes obsolete icons")
    remote[1].finished = false
    s.update()
    equal(s.active(1), 1, "newly needed objective returns")
    s.modules.QuestieComms.remoteQuestLogs[1] = nil
    s.update()
    equal(s.active(1), 0, "full refresh removes quests no longer reported")
end

do
    local s = setup()
    s.modules.QuestieLib.GetFullObjectiveText = function(text)
        return text:match("^(.*): %d+/%d+$")
    end
    s.quest(1)
    s.update()
    equal(s.pins[1].data.ObjectiveData.FullDescription, "Target 1 slain", "party fallback uses the client objective wording")
end

do
    local s = setup()
    s.quest(10)
    s.update()
    local draws = s.draws
    for _, pin in ipairs(s.pins) do pin._needsUnload = true end
    s.update()
    equal(s.draws, draws + 1, "icons awaiting unload cannot satisfy an unchanged draw signature")
    equal(s.active(10), 1, "pending unload is replaced by one live party icon")
end

for _, special in ipairs({false, true}) do
    local s = setup()
    local quest = s.quest(11)
    if special then quest.SpecialObjectives = {{Id = 111, Type = "item", Description = "Extra"}} end
    s.yieldDraw, s.yieldIndex = true, special and 65 or 1
    s.party:Update()
    s.step()
    local interrupted
    for _, pin in ipairs(s.pins) do
        if pin.data and pin.data.ObjectiveIndex == s.yieldIndex then interrupted = pin.data.ObjectiveData; break end
    end
    assert(interrupted, "fixture suspends the requested normal or special draw")
    interrupted.AlreadySpawned = {}
    s.drain()
    equal(s.active(11), 0, "interrupted draw releases its original spawn cache")
    for _, pin in ipairs(s.pins) do assert(not pin.data, "interrupted draw releases original minimap frames too") end
    local draws = s.draws
    s.yieldDraw = false
    s.update()
    assert(s.draws > draws, "next refresh retries instead of retaining a zero-icon entry")
    equal(s.active(11), special and 2 or 1, "normal or special interrupted draw recovers")
end

do
    local s = setup()
    local quest = s.quest(2, 2)
    quest.Objectives = {{Completed = false}, {Completed = true}}
    s.modules.QuestLogCache.questLog_DO_NOT_MODIFY[2] = {isComplete = 0,
        objectives = {{finished = false}, {finished = true}}}
    s.update()
    equal(s.active(2, 1), 0, "local unfinished objective is not duplicated")
    equal(s.active(2, 2), 1, "party still gets locally completed objective")
    s.modules.QuestLogCache.questLog_DO_NOT_MODIFY[2].isComplete = 1
    s.update()
    equal(s.active(2), 2, "local quest completion retains all party-needed objectives")
end

do
    local s = setup()
    local quest, remote = s.quest(3)
    quest.SpecialObjectives = {{Id = 31, Type = "item", Description = "Linked", RealObjectiveIndex = 1},
        {Id = 32, Type = "item", Description = "Unlinked"}}
    s.update()
    equal(s.active(3), 3, "remote quest draws needed linked and unlinked extras")
    remote[1].status = "F"
    s.update()
    equal(s.active(3), 0, "failed remote quest has no actionable icons")
    remote[1].status = nil
    s.online = false
    s.update()
    equal(s.active(3), 0, "offline member contributes no party icons")
    s.online, s.visible = true, false
    s.update()
    equal(s.active(3), 0, "hidden member contributes no party icons")
    s.visible = true
    s.env.Questie.db.profile.enableObjectives = false
    s.update()
    equal(s.active(3), 0, "disabled objectives draw no icons")
    s.env.Questie.db.profile.enableObjectives = true
    s.update()
    equal(s.active(3), 3, "reenabling objectives restores icons")
end

do
    local s = setup()
    s.quest(4)
    s.perObjective = 60
    s.update()
    equal(s.active(4), 60, "large objective is drawn")
    s.party:Clear()
    local reused = s.pins[1]
    reused.data = {Id = 99}
    while true do
        local before = s.unloads
        local amount = s.step()
        assert(amount <= 50, "removal exceeds its per-frame icon budget")
        if s.unloads == before then break end
    end
    s.drain()
    equal(reused.data.Id, 99, "deferred removal cannot unload a reused icon")
    equal(s.active(4), 0, "party clear eventually removes remaining old icons")
    equal(s.unloads, 119, "all original map and minimap icons except reused icon are removed")
end

do
    local s = setup()
    s.quest(5)
    s.yieldDraw = true
    s.party:Update()
    s.step()
    equal(s.active(5), 1, "fixture suspends after producing an owned icon")
    s.group = false
    s.party:Clear()
    s.drain()
    equal(s.active(5), 0, "leaving during a queued or yielded draw leaves no orphan icons")
    for _, pin in ipairs(s.pins) do assert(not pin.data, "leaving also removes minimap icons") end
end

do
    local s = setup()
    s.quest(9)
    s.yieldDraw = true
    s.party:Update()
    s.step()
    equal(s.active(9), 1, "old generation is suspended with an icon")
    s.party:Clear()
    s.yieldDraw = false
    s.party:Update()
    s.drain()
    equal(s.active(9), 1, "stale worker cleanup preserves the replacement generation")
end

do
    local s = setup()
    s.quest(6)
    s.quest(7)
    s.failQuest = 6
    s.update()
    equal(s.active(7), 1, "malformed quest cannot block another party quest")
    assert(#s.errors > 0, "fixture exercises the guarded error path")
    local big = setup()
    big.quest(8, 2)
    big.perObjective = 300
    big.update()
    assert(big.active() <= 500, "party icon limit remains enforced")
end
print("Party objective updates passed: reuse, shared quests, extras, visibility, batched cleanup and cancellation")
