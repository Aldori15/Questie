-- Run from the addon directory with Lua 5.2+. Exercise the production binary
-- spawn writer, reader and skipper; no database generation or client is needed.
local modules = {}
local env = setmetatable({bit = bit32, tremove = table.remove, unpack = table.unpack}, {__index = _G})
env.GetCVar = function() return "" end
env.QuestieCompat = {}
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
}
assert(loadfile("Modules/QuestieStream.lua", "t", env))()
assert(loadfile("Database/compiler.lua", "t", env))()
local compiler, streamLib = modules.DBCompiler, modules.QuestieStreamLib
local input = {[210] = {
    {10, 20}, {11, 21, 1034}, {12, 22, 0, 2, 571}, {-1, -1},
    {13, 23, 0, 1, 571, 1, 4477}, {14, 24, 0, 2, 571, 2, 4477},
    {15, 25, 1034, 1, 571, 4294967295, 4477},
}}
local stream = streamLib:GetStream("raw_assert")
compiler.writers.spawnlist(stream, input)
local endPointer = stream._pointer
stream:WriteInt(123456789)
stream._bin = table.concat(stream._bin)
stream._pointer = 1
local output = compiler.readers.spawnlist(stream)
assert(stream._pointer == endPointer, "reader consumed the complete variable-length spawn field")
assert(stream:ReadInt() == 123456789, "following field remains aligned after reading")
for i, expected in ipairs(input[210]) do
    local actual = output[210][i]
    assert(#actual == #expected, "tuple length preserved at spawn " .. i)
    for index, value in ipairs(expected) do
        if index <= 2 and value ~= -1 then
            assert(math.abs(actual[index] - value) < 0.03, "coordinate quantization remains bounded")
        else
            assert(actual[index] == value, "visibility metadata preserved at spawn " .. i .. ", field " .. index)
        end
    end
end
stream._pointer = 1
compiler.skippers.spawnlist(stream)
assert(stream._pointer == endPointer, "skipper matches reader for mixed legacy and scoped spawns")
assert(stream:ReadInt() == 123456789, "following field remains aligned after skipping")

stream = streamLib:GetStream("raw_assert")
compiler.writers.spawnlist(stream, nil)
stream._bin, stream._pointer = table.concat(stream._bin), 1
assert(compiler.readers.spawnlist(stream) == nil, "empty spawn field preserved")
assert(stream._pointer == 2, "empty field reader remains aligned")
stream._pointer = 1
compiler.skippers.spawnlist(stream)
assert(stream._pointer == 2, "empty field skipper remains aligned")
print("Spawn phase metadata: binary round-trip and skipper checks passed")
