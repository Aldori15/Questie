-- Run from the addon root with Lua 5.1 or 5.2+.
local snapshot = dofile("tools/db_snapshot.lua")
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
equal(snapshot.encode({[1] = false, [3] = 0, ["1"] = {}}), '{"n:1":false,"n:3":0,"s:1":{}}')
equal(snapshot.encode({}), "{}")
equal(snapshot.encode('line\n"quoted"\\'), '"line\\u000a\\"quoted\\"\\\\"')
local cyclic = {}; cyclic.self = cyclic
assert(not pcall(snapshot.encode, cyclic))
assert(not pcall(snapshot.encode, {callback = function() end}))

-- Use the same TOC/XML discovery as the Python CLI via an integration test in
-- Python when a Lua executable is available; this suite tests the Lua encoding
-- independently on every supported interpreter in CI.
print("Database snapshot Lua encoding tests passed")
