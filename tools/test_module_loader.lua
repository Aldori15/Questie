-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the real loader's forward references, diagnostics, and profiler observer.
local tests = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function compile(source, label, env)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local function setup(clock)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    if clock then
        env.GetTimePreciseSec = clock
        env.debugstack = function(level)
            equal(level, 3, "profiler caller depth remains unchanged")
            return "Interface/AddOns/Questie-335/Modules/Example.lua:1: in main chunk"
        end
    end
    compile(read("Modules/Libs/QuestieLoader.lua"), "@Modules/Libs/QuestieLoader.lua", env)()
    return env.QuestieLoader, env
end

-- Import-before-definition must keep the same table, private state, and captured references.
do
    local loader = setup()
    local forward = loader:ImportModule("Later")
    forward.private.pending = true
    equal(loader:ImportModule("Later"), forward, "repeated import identity")
    equal(loader:GetUnresolvedModuleImports()[1], "Later", "forward import is unresolved until declared")
    equal(loader:CreateModule("Later"), forward, "declaration preserves the placeholder")
    equal(forward.private.pending, true, "private state preserved")
    equal(loader:CreateModule("Later"), forward, "repeated declaration remains supported")
    equal(#loader:GetUnresolvedModuleImports(), 0, "forward declaration resolves diagnostics")
    equal(loader._modules.Later, forward, "profiler module registry preserved")
    tests = tests + 1
end

-- A typo stays visible even when its placeholder acquires data. Diagnostics never repair or throw.
do
    local loader = setup()
    local beta = loader:ImportModule("BetaTypo")
    local alpha = loader:ImportModule("AlphaTypo")
    beta.private.value = 42
    loader:CreateModule("Valid")
    local missing = loader:GetUnresolvedModuleImports()
    equal(#missing, 2, "two unresolved imports")
    equal(missing[1], "AlphaTypo", "diagnostics sorted first")
    equal(missing[2], "BetaTypo", "diagnostics sorted second")
    missing[1] = "ChangedByCaller"
    equal(loader:GetUnresolvedModuleImports()[1], "AlphaTypo", "diagnostics return a fresh list")
    equal(loader:ImportModule("AlphaTypo"), alpha, "diagnostic preserves imported table")
    equal(beta.private.value, 42, "diagnostic preserves imported data")
    tests = tests + 1
end

-- Exempt only the explicitly named stub; do not infer that any empty module is disabled.
do
    local loader = setup()
    local stub = loader:ImportModule("Disabled")
    loader:ImportModule("Typo")
    loader:MarkModuleDisabled("Disabled")
    equal(loader:ImportModule("Disabled"), stub, "disabled marker preserves references")
    equal(type(stub.private), "table", "disabled marker does not install behavior")
    equal(#loader:GetUnresolvedModuleImports(), 1, "unrelated typo still diagnosed")
    equal(loader:GetUnresolvedModuleImports()[1], "Typo", "only intended stub exempted")
    loader:MarkModuleDisabled("FutureStub")
    loader:ImportModule("FutureStub")
    equal(#loader:GetUnresolvedModuleImports(), 1, "stub can be registered before its import")
    tests = tests + 1
end

-- Observer order and load timing must stay intact: the profiler observes the old registry state.
do
    local time = 0
    local loader = setup(function() return time end)
    local calls = {}
    loader:SetModuleCallObserver(function(name)
        calls[#calls + 1] = name
        if #calls == 1 then equal(loader._modules.First, nil, "observer runs before table creation") end
    end)
    time = 0.01
    local first = loader:CreateModule("First")
    time = 0.02
    equal(loader:ImportModule("First"), first, "observed import keeps identity")
    loader:MarkModuleDisabled("Stub")
    loader:GetUnresolvedModuleImports()
    equal(#calls, 2, "diagnostics do not trigger module observers")
    equal(calls[1], "First", "declaration observer")
    equal(calls[2], "First", "import observer")
    loader:SetModuleCallObserver(nil)
    time = 0.03
    loader:CreateModule("Second")
    equal(#calls, 2, "observer can be detached")
    loader:FinishLoadTimings()
    assert(loader.loadTimings["Modules/Libs/QuestieLoader.lua"] > 0, "loader interval recorded")
    assert(loader.loadTimings["Modules/Example.lua"] > 0, "calling file interval recorded")
    tests = tests + 1
end

-- The initialization callback reports only in debug mode, after declarations/stubs settle.
do
    local loader, env = setup()
    local messages = {}
    env.Questie = {db = {profile = {debugEnabled = false}}, DEBUG_CRITICAL = 1,
        Debug = function(_, message, names) messages[#messages + 1] = {message, names} end}
    env.QuestieProfiler = {active = false}
    env._QuestieInit = {}
    local callback = assert(read("Modules/QuestieInit.lua"):match("function _QuestieInit%.OnInitializationComplete%(%)\n.-\nend"))
    compile(callback, "@Modules/QuestieInit.lua", env)()
    loader:ImportModule("Misspelled")
    env._QuestieInit.OnInitializationComplete()
    equal(#messages, 0, "normal startup has no diagnostic output")
    env.Questie.db.profile.debugEnabled = true
    env._QuestieInit.OnInitializationComplete()
    equal(#messages, 1, "debug startup reports unresolved import")
    equal(messages[1][2], "Misspelled", "debug message identifies the import")
    loader:CreateModule("Misspelled")
    loader:ImportModule("Disabled")
    loader:MarkModuleDisabled("Disabled")
    env._QuestieInit.OnInitializationComplete()
    equal(#messages, 1, "settled modules have no false diagnostic")
    tests = tests + 1
end

print("Module loader regression tests passed (" .. tests .. " groups)")
