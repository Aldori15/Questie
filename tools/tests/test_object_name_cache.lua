-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function setup(count)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.unpack = unpack or table.unpack
    local modules = {}
    env.QuestieLoader = {
        CreateModule = function(_, name)
            modules[name] = modules[name] or {private = {}}
            return modules[name]
        end,
        ImportModule = function(_, name)
            modules[name] = modules[name] or setmetatable({private = setmetatable({}, {__index = function() return noop end})},
                {__index = function() return noop end})
            return modules[name]
        end,
    }
    env.Questie = {Debug = noop, SetIcons = noop, db = {profile = {}, global = {
        dbIsCompiled = true, dbCompiledOnVersion = "test", dbCompiledLang = "enUS", dbCompiledSchemaVersion = 1,
    }, char = {townsfolk = {}, townsfolkClass = "WARRIOR"}}}
    env.QuestieCompat = {C_Timer = {After = noop}, ReleaseCorrectionRegistries = noop}
    env.GetLocale = function() return "enUS" end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    env.collectgarbage = noop
    local state = {queried = 0}
    modules.QuestieDB = {ObjectPointers = {}, Initialize = noop}
    for id = 1, count do modules.QuestieDB.ObjectPointers[id] = true end
    modules.QuestieDB.QueryObjectSingle = function(id, key)
        equal(key, "name", "only object names queried")
        state.queried = state.queried + 1
        if state.failAt == state.queried then error("query failed") end
        if id == 1 then return "Unique" end
        if id == count then return nil end
        return "Shared"
    end
    local function loadModule(path)
        local file = assert(io.open(path, "r"))
        local source = file:read("*a")
        file:close()
        if setfenv then
            setfenv(assert(loadstring(source, "@" .. path)), env)()
        else
            assert(load(source, "@" .. path, "t", env))()
        end
    end
    loadModule("Localization/l10n.lua")
    state.env, state.modules, state.loadModule = env, modules, loadModule
    state.l10n = modules.l10n
    return state
end
local function resume(thread)
    local ok, message = coroutine.resume(thread)
    assert(ok, message)
end
local function finish(thread)
    while coroutine.status(thread) ~= "dead" do resume(thread) end
end
local function verifyCache(state, count)
    equal(state.l10n._objectCacheBuilt, true, "complete cache published")
    equal(state.l10n:GetObjectNameLookup("Unique"), 1, "unique name remains a number")
    local shared = state.l10n:GetObjectNameLookup("Shared")
    equal(#shared, count - 2, "all duplicate names retained")
    local seen = {}
    for _, id in ipairs(shared) do
        assert(id > 1 and id < count and not seen[id], "correct duplicate ID without repetition")
        seen[id] = true
    end
    local before = state.queried
    equal(state.l10n:GetObjectNameLookup("Missing"), nil, "missing name returns nil")
    equal(state.l10n.objectNameLookup.Missing, false, "missing name cached after completion")
    equal(state.l10n:GetObjectNameLookup(nil), nil, "nil name returns nil")
    state.l10n:BuildObjectNameCache()
    state.l10n:BuildObjectNameCacheAsync()
    equal(state.queried, before, "completed index is reused without rescanning")
end

-- Each startup resume processes at most 250 IDs; incomplete buckets stay private.
do
    local s = setup(501)
    local original = s.l10n.objectNameLookup
    local thread = coroutine.create(function() s.l10n:BuildObjectNameCacheAsync() end)
    for batch = 1, 2 do
        resume(thread)
        equal(s.queried, batch * 250, "bounded startup batch")
        equal(coroutine.status(thread), "suspended", "startup yields")
        assert(not s.l10n._objectCacheBuilt, "incomplete cache is not marked ready")
        equal(s.l10n.objectNameLookup, original, "incomplete cache is not published")
        equal(next(original), nil, "no partial name buckets")
    end
    resume(thread)
    equal(coroutine.status(thread), "dead", "startup completes after final batch")
    equal(s.queried, 501, "each object queried once")
    verifyCache(s, 501)
end

-- A tooltip on the main thread can still build synchronously, without yielding.
do
    local s = setup(501)
    equal(s.l10n:GetObjectNameLookup("Unique"), 1, "cold tooltip fallback")
    equal(s.queried, 501, "synchronous fallback scans all IDs")
    verifyCache(s, 501)
end

-- If a tooltip finishes a suspended build, startup must preserve that complete cache.
do
    local s = setup(501)
    local thread = coroutine.create(function() s.l10n:BuildObjectNameCacheAsync() end)
    resume(thread)
    equal(s.l10n:GetObjectNameLookup("Missing"), nil, "early tooltip gets complete missing-name result")
    local completed, before = s.l10n.objectNameLookup, s.queried
    finish(thread)
    equal(s.l10n.objectNameLookup, completed, "startup retains fallback cache")
    equal(s.l10n.objectNameLookup.Missing, false, "startup retains negative cache entries")
    equal(s.queried, before, "startup does not resume an obsolete scan")
    verifyCache(s, 501)
end

-- A failed scan cannot leave a ready flag or partial buckets behind; retry succeeds.
do
    local s = setup(501)
    s.failAt = 300
    local thread = coroutine.create(function() s.l10n:BuildObjectNameCacheAsync() end)
    resume(thread)
    local ok, message = coroutine.resume(thread)
    assert(not ok and message:find("query failed", 1, true), "query failure reported")
    assert(not s.l10n._objectCacheBuilt, "failed cache not marked complete")
    equal(next(s.l10n.objectNameLookup), nil, "failed scan not published")
    s.failAt = nil
    finish(coroutine.create(function() s.l10n:BuildObjectNameCacheAsync() end))
    verifyCache(s, 501)
end

-- Empty databases finish immediately.
do
    local s = setup(0)
    s.l10n:BuildObjectNameCacheAsync()
    equal(s.l10n._objectCacheBuilt, true, "empty cache ready")
    equal(s.queried, 0, "empty cache has no queries")
end

-- Execute the actual startup stages: player setup must wait for the complete name cache.
do
    local s = setup(501)
    local loader = s.env.QuestieLoader
    loader:ImportModule("DBCompiler").compiledSchemaVersion = 1
    loader:ImportModule("QuestieLib").GetAddonVersionString = function() return "test" end
    loader:ImportModule("QuestieValidateGameCache").IsCacheGood = function() return true end
    local playerInitialized = false
    loader:ImportModule("QuestiePlayer").Initialize = function()
        equal(s.l10n._objectCacheBuilt, true, "cache ready before player setup")
        playerInitialized = true
    end
    s.loadModule("Modules/QuestieInit.lua")
    local thread = coroutine.create(function()
        s.modules.QuestieInit.Stages[1]()
        s.modules.QuestieInit.Stages[2]()
    end)
    while s.queried < 250 do resume(thread) end
    equal(s.queried, 250, "Stage 1 uses yielding cache builder")
    equal(playerInitialized, false, "player setup waits during name scan")
    finish(thread)
    equal(playerInitialized, true, "startup continues after completed scan")
    verifyCache(s, 501)
end

print("Object name cache regressions passed")
