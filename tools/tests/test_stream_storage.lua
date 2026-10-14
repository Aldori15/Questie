-- Run from the addon directory with Lua 5.1 or 5.2. Load the real modules
-- without compatibility startup patches; protect database and message bytes.
local function loadInEnv(path, env)
    if setfenv then
        return setfenv(assert(loadfile(path)), env)()
    end
    return assert(loadfile(path, "t", env))()
end

-- Lua 5.1 CI does not install a bit library. These unsigned operations supply
-- the WoW API used by the stream and serializer in this test.
local testBit = bit32 or bit or {
    band = function(a, b)
        local result, place = 0, 1
        for _ = 1, 32 do
            if a % 2 == 1 and b % 2 == 1 then result = result + place end
            a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        return result
    end,
    lshift = function(a, n) return (a * 2 ^ n) % 4294967296 end,
    rshift = function(a, n) return math.floor(a / 2 ^ n) end,
}

local function makeEnv(realm)
    local modules = {}
    local env = setmetatable({
        bit = testBit, tremove = table.remove, unpack = unpack or table.unpack,
        GetCVar = function() return realm or "" end,
        QuestieCompat = {},
        Questie = {Error = function(message) error(message) end},
    }, {__index = _G})
    env.QuestieLoader = {
        CreateModule = function(_, name)
            assert(not modules[name], "module declared only once")
            modules[name] = {}
            return modules[name]
        end,
        ImportModule = function(_, name)
            modules[name] = modules[name] or {}
            return modules[name]
        end,
    }
    loadInEnv("Modules/QuestieStream.lua", env)
    return env, modules
end

local env, modules = makeEnv()
local streamLib = modules.QuestieStreamLib
local modes = {"raw", "raw_assert", "1short", "b89"}
local byteChars = {}
for value = 0, 255 do byteChars[#byteChars + 1] = string.char(value) end
local allBytes = table.concat(byteChars)
local shortBytes = string.char(238) .. allBytes:sub(2, 237)
    .. string.char(237, 1, 237, 2) .. allBytes:sub(240)

-- Fixed wire fixtures independently check escapes and b89 level changes.
for _, mode in ipairs(modes) do
    local stream = streamLib:GetStream(mode)
    assert(stream:Save() == "", mode .. " starts empty")
    for value = 0, 255 do stream:WriteByte(value) end
    local saved = stream:Save()
    if mode == "raw" or mode == "raw_assert" then
        assert(saved == allBytes, "raw wire bytes unchanged")
    elseif mode == "1short" then
        assert(saved == shortBytes, "1short wire escapes unchanged")
    end
    stream:Load(saved)
    for value = 0, 255 do assert(stream:ReadByte() == value, mode .. " byte round-trip") end
    assert(stream._pointer == #saved + 1, mode .. " reader stays aligned")
end
for _, realm in ipairs({"", "logon.warmane.com"}) do
    local _, realmModules = makeEnv(realm)
    local stream = realmModules.QuestieStreamLib:GetStream("b89")
    local fixture = {0, 1, 6, 59, 85, 86, 171, 172, 255}
    for _, value in ipairs(fixture) do stream:WriteByte(value) end
    local expected = realm == "" and "!{|}vy!vz!t" or "!{~}vy!vz!t"
    assert(stream:Save() == expected, "realm-specific b89 wire fixture unchanged")
    stream:Load(expected)
    for _, value in ipairs(fixture) do assert(stream:ReadByte() == value) end
end

-- Exercise the public typed methods and strings beyond the 4,096-byte loader
-- batch/unpack limit, including embedded NULs and encoding control characters.
local tiny = allBytes:sub(1, 255)
local long = string.rep(allBytes, 20)
for _, mode in ipairs(modes) do
    local stream = streamLib:GetStream(mode)
    stream:WriteShort(65535)
    stream:WriteInt24(16777215)
    stream:WriteInt(4294967295)
    stream:WriteInt12Pair(4095, 2048)
    stream:WriteTinyString(tiny)
    stream:WriteTinyString("")
    stream:WriteTinyString("")
    stream:WriteShortString(long)
    stream:WriteByte(42)
    local saved = stream:Save()
    stream:Load(saved)
    assert(stream:ReadShort() == 65535)
    assert(stream:ReadInt24() == 16777215)
    assert(stream:ReadInt() == 4294967295)
    local a, b = stream:ReadInt12Pair()
    assert(a == 4095 and b == 2048)
    assert(stream:ReadTinyString() == tiny)
    assert(stream:ReadTinyString() == "")
    assert(stream:ReadTinyStringNil() == nil)
    assert(stream:ReadShortString() == long)
    assert(stream:ReadByte() == 42 and stream._pointer == #saved + 1)
end

-- An escaped value straddles two storage tables. This checks the allocation
-- limit, saved bytes, batched Load, pointer seeking, and decoding together.
local limit = 524288
for _, mode in ipairs({"raw_assert", "1short", "b89"}) do
    local stream = streamLib:GetStream(mode)
    for _ = 1, limit - 1 do stream:WriteByte(1) end
    stream:WriteByte(237)
    stream:WriteByte(0)
    stream:WriteByte(255)
    local prefix = string.rep(mode == "b89" and "{" or string.char(1), limit - 1)
    local suffix = mode == "b89" and "zbx!zt"
        or mode == "1short" and string.char(237, 1, 238, 255) or string.char(237, 0, 255)
    assert(#stream._bin[1] == limit and #stream._bin[2] == #suffix - 1)
    local saved = stream:Save()
    assert(saved == prefix .. suffix, mode .. " large payload wire bytes unchanged")
    stream:Load(saved)
    if mode ~= "raw_assert" then assert(#stream._bin[1] == limit) end
    stream:SetPointer(limit)
    assert(stream:ReadByte() == 237, "boundary escape decodes")
    assert(stream:ReadByte() == 0 and stream:ReadByte() == 255)
    assert(stream._pointer == #saved + 1, "boundary reader stays aligned")
end

local stream = streamLib:GetStream("raw_assert")
for _, invalid in ipairs({-1, 256, "1"}) do
    assert(not pcall(stream.WriteByte, stream, invalid), "raw assertions preserved")
end
stream:WriteByte(7)
stream:finished()
local recycled = streamLib:GetStream("raw_assert")
assert(recycled == stream and recycled:Save() == "", "pool resets storage")
recycled:WriteByte(8)
assert(recycled:Save() == string.char(8), "recycled writer has no stale bytes")

loadInEnv("Modules/Libs/QuestieSerializer.lua", env)
local serializer = modules.QuestieSerializer
local fixture = {"repeated string", "repeated string", true, 42, 65536,
    {key = "value", nested = {1, 2, 3}}, long}
local function same(actual, expected)
    assert(type(actual) == type(expected), "serialized type preserved")
    if type(expected) ~= "table" then assert(actual == expected); return end
    for key, value in pairs(expected) do same(actual[key], value) end
    for key in pairs(actual) do assert(expected[key] ~= nil) end
end
for _, mode in ipairs(modes) do
    same(serializer:Deserialize(serializer:Serialize(fixture, mode), mode), fixture)
end

-- The renamed compatibility file still forwards nil arguments/results and
-- invokes custom or client error handlers, without importing the stream.
local boundaries = 0
env.QuestieLoader.StampLoadBoundary = function() boundaries = boundaries + 1 end
env.geterrorhandler = function() return function() return "client error" end end
env.loadstring = function(code, name)
    if setfenv then return setfenv(assert(loadstring(code, name)), env) end
    return load(code, name, "t", env)
end
loadInEnv("Compat/ProtectedCall.lua", env)
assert(boundaries == 1, "protected-call file records its load boundary")
local ok, first, middle, last = env.QuestieCompat.xpcall(function(...)
    assert(select("#", ...) == 3, "trailing nil argument preserved")
    local a, b, c = ...
    assert(a == 7 and b == nil and c == nil)
    return "result", nil, 9
end, nil, 7, nil, nil)
assert(ok and first == "result" and middle == nil and last == 9)
ok, first = env.QuestieCompat.xpcall(function() return 23 end)
assert(ok and first == 23)
ok, first = env.QuestieCompat.xpcall(function() error("failure") end,
    function(message) assert(message:find("failure", 1, true)); return "handled" end, 1)
assert(not ok and first == "handled")
ok, first = env.QuestieCompat.xpcall(function() error("failure") end)
assert(not ok and first == "client error")

print("Stream storage: wire fixtures, typed values, large payloads, pooling, serializer and protected calls passed")
