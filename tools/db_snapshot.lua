-- Headless correction-pipeline capture. Invoked by db_snapshot.py, not the addon.
local Snapshot = {}

local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text:gsub("\r\n", "\n"):gsub("^\239\187\191", "")
end

local function quote(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        if char == '"' then return '\\"' end
        if char == "\\" then return "\\\\" end
        return string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function keys(value)
    local result = {}
    for key in pairs(value) do
        assert(type(key) == "number" or type(key) == "string", "unsupported table key: " .. type(key))
        result[#result + 1] = key
    end
    table.sort(result, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return result
end

local function number(value)
    assert(value == value and math.abs(value) ~= math.huge, "non-finite number")
    if math.type and math.type(value) == "integer" then return tostring(value) end
    return string.format("%.17g", value)
end

-- Every Lua table is a JSON object with typed keys. Do not use # or ipairs:
-- sparse objectives, absent values, false, zero, and {} must remain distinct.
function Snapshot.encode(value, active)
    local kind = type(value)
    if kind == "string" then return quote(value) end
    if kind == "boolean" then return tostring(value) end
    if kind == "number" then return number(value) end
    assert(kind == "table", "unsupported snapshot value: " .. kind)
    active = active or {}
    assert(not active[value], "cyclic snapshot value")
    active[value] = true
    local parts = {}
    for _, key in ipairs(keys(value)) do
        local prefix = type(key) == "number" and "n:" or "s:"
        local name = prefix .. (type(key) == "number" and number(key) or key)
        parts[#parts + 1] = quote(name) .. ":" .. Snapshot.encode(value[key], active)
    end
    active[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function band(a, b)
    a, b = a % 4294967296, b % 4294967296
    local result, place = 0, 1
    for _ = 1, 32 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end

local function compile(source, label, env)
    if setfenv then return setfenv(assert(loadstring(source, label)), env) end
    return assert(load(source, label, "t", env))
end

local function environment(root, paths, context)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local modules = {}
    env.QuestieLoader = {
        ImportModule = function(_, name)
            modules[name] = modules[name] or {private = {}}
            return modules[name]
        end,
        StampLoadBoundary = function() end,
    }
    env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
    env.bit = {band = band}
    env.UnitFactionGroup = function() return context.faction end
    env.GetLocale = function() return "enUS" end
    env.hooksecurefunc = function() end -- no UI/skill hooks are installed headlessly
    env.strlower, env.strfind, env.strsub = string.lower, string.find, string.sub
    env.tinsert, env.tremove, env.unpack = table.insert, table.remove, unpack or table.unpack
    env.wipe = function(value) for key in pairs(value) do value[key] = nil end; return value end
    env.print = function(...) error("unexpected addon print during capture", 2) end
    env.Questie = {
        db = {profile = {isleOfQuelDanasPhase = context.islePhase}, char = {complete = {}}, global = {}},
        Debug = function() end,
        Warning = function(message) error(message, 2) end,
    }
    env.Questie.Error = env.Questie.Warning
    env.QuestieCompat = {C_QuestLog = {}, C_Timer = {}, C_DateAndTime = {}, C_Map = {}}
    env.QuestieDB = env.QuestieLoader:ImportModule("QuestieDB")
    env.QuestieCorrections = env.QuestieLoader:ImportModule("QuestieCorrections")
    env.QuestieInit = env.QuestieLoader:ImportModule("QuestieInit")
    local l10n = env.QuestieLoader:ImportModule("l10n")
    setmetatable(l10n, {__call = function(_, text, ...)
        if select("#", ...) > 0 then return string.format(text, ...) end
        return text
    end})
    for line in read(root .. "/Questie.lua"):gmatch("[^\n]+") do
        if line:match("^Questie%.ICON_TYPE_[%w_]+%s*=%s*%d+%s*$") then
            compile(line, "@Questie.lua icon constants", env)()
        end
    end
    assert(env.Questie.ICON_TYPE_EVENT, "missing Questie icon constants")
    setmetatable(env.Questie, {__index = function(_, key)
        if type(key) == "string" and key:match("^ICON_TYPE_") then
            error("missing Questie icon constant: " .. key, 2)
        end
    end})
    local compat = read(root .. "/Compat/Compat.lua")
    local registry = assert(compat:match("(local correctionsRegistry = {}.-)\nfunction QuestieCompat:ADDON_LOADED"),
        "compatibility registry boundary changed; update capture adapter")
    compile(registry, "@Compat/Compat.lua correction registry", env)()
    for _, path in ipairs(paths) do
        compile(read(root .. "/" .. path), "@" .. path, env)()
    end
    return env, modules
end

local function runtimeState(env)
    local result = {}
    for name, value in pairs(env.QuestieLoader:ImportModule("QuestieCorrections")) do
        if name ~= "private" and type(value) ~= "function" then result[name] = copy(value) end
    end
    return result
end

local function namedRecords(db, kind, records)
    local reversed = assert(db[kind .. "KeysReversed"], "missing schema: " .. kind)
    local result = {}
    for id, row in pairs(records) do
        local named = {}
        for index, value in pairs(row) do
            named[assert(reversed[index], "unknown " .. kind .. " field: " .. tostring(index))] = value
        end
        result[id] = named
    end
    return result
end

function Snapshot.capture(root, paths, context, emit)
    local env, modules = environment(root, paths, context)
    local db, corrections = env.QuestieDB, modules.QuestieCorrections
    assert(corrections and corrections.Initialize, "missing correction initializer")
    assert(context.islePhase >= 1 and context.islePhase <= modules.IsleOfQuelDanas.MAX_ISLE_OF_QUEL_DANAS_PHASES,
        "invalid Quel'Danas phase")
    local init = read(root .. "/Modules/QuestieInit.lua")
    local baseLoader = assert(init:match("(function QuestieInit:LoadDatabase%(key%).-)\nfunction _QuestieInit.StartStageCoroutine"),
        "base loader boundary changed; update capture adapter")
    env.coYield = coroutine.yield
    env.loadstring = function(source, label) return compile(source, label or "@base database", env) end
    compile(baseLoader, "@Modules/QuestieInit.lua base loader", env)()
    local thread = coroutine.create(function()
        env.QuestieInit:LoadBaseDB()
        corrections:Initialize()
    end)
    repeat
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
    until coroutine.status(thread) == "dead"

    local sections = {}
    for _, kind in ipairs({"quest", "npc", "object", "item"}) do
        assert(type(db[kind .. "Data"]) == "table", "base database not loaded: " .. kind)
        sections[kind .. "Data"] = namedRecords(db, kind, db[kind .. "Data"])
        sections["overrides/fresh/" .. kind] = copy(namedRecords(db, kind, db[kind .. "DataOverrides"]))
        sections["schemas/" .. kind] = {
            keys = assert(db[kind .. "Keys"]),
            compilerTypes = assert(db[kind .. "CompilerTypes"]),
            compilerOrder = assert(db[kind .. "CompilerOrder"]),
        }
    end
    sections["auxiliary/fresh"] = runtimeState(env)
    sections["derived"] = {requiredItemConditionQuestIds = assert(db.requiredItemConditionQuestIds)}
    sections["server/availability"] = assert(env.QuestieCompat.AzerothCoreQuestAvailabilityConditions)
    sections["server/reputationRates"] = assert(env.QuestieCompat.AzerothCoreReputationRates)
    sections["events/static"] = {quests = assert(modules.QuestieEvent.eventQuests)}

    -- Recreate the cached-startup environment: source modules load, but neither
    -- LoadBaseDB nor Initialize runs. No binary compiler or client locale runs.
    local cached, cachedModules = environment(root, paths, context)
    cachedModules.QuestieCorrections:MinimalInit()
    for _, kind in ipairs({"quest", "npc", "object", "item"}) do
        sections["overrides/cached/" .. kind] = namedRecords(cached.QuestieDB, kind, cached.QuestieDB[kind .. "DataOverrides"])
    end
    sections["auxiliary/cached"] = runtimeState(cached)

    -- Exercise the production Darkmoon override setter with raw-table query
    -- adapters. Compiler caches, calendar timers, and live server state are out
    -- of scope; field precedence and override restoration are captured.
    db.QueryNPCSingle = function(id, field)
        local index = assert(db.npcKeys[field], field)
        local override = db.npcDataOverrides[id]
        if override and override[index] ~= nil then return override[index] end
        local row = db.npcData[id]
        if row then return row[index] end
    end
    db.InvalidateNPC = function() end
    for _, location in ipairs({1, 2, 3}) do
        modules.QuestieEvent.SetServerDarkmoonLocations({location})
        sections["overrides/darkmoon-" .. location .. "/npc"] = copy(namedRecords(db, "npc", db.npcDataOverrides))
    end
    modules.QuestieEvent.SetServerDarkmoonLocations(nil)
    sections["overrides/darkmoon-reset/npc"] = namedRecords(db, "npc", db.npcDataOverrides)
    for _, section in ipairs(keys(sections)) do
        for _, id in ipairs(keys(sections[section])) do emit(section, id, sections[section][id]) end
    end
end

if arg and arg[1] == "--capture" then
    local plan = assert(loadfile(assert(arg[2], "missing capture plan")))()
    for _, context in ipairs(plan.contexts) do
        io.stderr:write("Capturing " .. context.name .. "\n")
        Snapshot.capture(plan.root, plan.files, context, function(section, id, value)
            local encodedId = type(id) == "number" and number(id) or quote(id)
            io.write('{"context":' .. quote(context.name) .. ',"section":' .. quote(section)
                .. ',"id":' .. encodedId .. ',"value":' .. Snapshot.encode(value) .. '}\n')
        end)
        collectgarbage("collect")
    end
else
    return Snapshot
end
