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
    {16, 26, 0, 0, 571, 0, 0, 133649},
    {17, 27, 1034, 2, 571, 4294967295, 4477, 4294967295},
    {18, 28, 0, 0, 622, 0, 0, 142849},
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

env.IsInInstance = function() return true end
modules.QuestieServer = {GetSpawnPhaseVisibility = function(_, _, region, mask)
    assert(region > 0 and mask > 0, "identity placeholders never query phase visibility")
    return false
end}
assert(loadfile("Modules/Phasing.lua", "t", env))()
local phasing = modules.Phasing
local identityOnly = {10, 20, 0, 0, 571, 0, 0, 133649}
assert(not phasing.HasDynamicSpawns({[4395] = {identityOnly}}), "identity alone never triggers phase redraws")
assert(phasing.IsSpawnDataVisible(identityOnly), "identity-only spawn stays unrestricted in instances")
local scoped = {10, 20, 0, 1, 571, 2, 4477, 123}
assert(phasing.HasDynamicSpawns({[210] = {scoped}}), "actual story phase still triggers redraws")
assert(not phasing.IsSpawnDataVisible(scoped), "actual story phase still filters the spawn")
print("Spawn phase metadata: binary round-trip, skipper and identity visibility checks passed")
