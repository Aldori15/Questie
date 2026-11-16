-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the tracker cache with the real 3.3.5 scratch-fontstring helpers.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local env = setmetatable({}, {__index = _G})
env._G, env.QuestieCompat = env, {}
local modules = {}
local function module(name)
    modules[name] = modules[name] or {}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
env.LibStub = setmetatable({GetLibrary = function() return {} end}, {__call = function() return {} end})
local measurements, mutations = 0, 0
local scratch = {}
function scratch:SetPoint() end
function scratch:Hide() end
function scratch:SetWidth(width) self.width = width; mutations = mutations + 1 end
function scratch:SetFont(font, size, flags)
    self.font, self.size, self.flags = font, size, flags
    mutations = mutations + 1
end
function scratch:SetText(text) self.text = text; mutations = mutations + 1 end
function scratch:GetStringWidth()
    measurements = measurements + 1
    return #(self.text or "") * self.size
end
function scratch:GetHeight()
    return math.max(1, math.ceil(#(self.text or "") * self.size / self.width)) * self.size
end
env.UIParent = {CreateFontString = function() return scratch end}
local function run(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env)() end
    return assert(load(source, name, "t", env))()
end
run(read("Compat/UI.lua"), "@Compat/UI.lua")
local source = read("Modules/Tracker/TrackerLinePool.lua")
assert(source:find("line.label.GetUnboundedStringWidth = GetCachedUnboundedStringWidth", 1, true),
    "tracker labels must use the cache")
local measure = run(source .. "\nreturn GetCachedUnboundedStringWidth", "@Modules/Tracker/TrackerLinePool.lua")
local function label(text)
    return {text = text, font = "Font A", size = 10, flags = "", width = 100,
        GetText = function(self) return self.text end,
        GetFont = function(self) return self.font, self.size, self.flags end,
        GetWidth = function(self) return self.width end}
end
local first = label("Quest")
equal(measure(first), 50, "first width")
local before, beforeMutations = measurements, mutations
for _ = 1, 100 do equal(measure(first), 50, "unchanged width") end
equal(measurements, before, "unchanged text avoids native measurement")
equal(mutations, beforeMutations, "cache hits do not mutate the scratch label")

for _, change in ipairs({{"text", "Other quest"}, {"font", "Font B"}, {"size", 12}, {"flags", "OUTLINE"}}) do
    first[change[1]] = change[2]
    before = measurements
    equal(measure(first), #first.text * first.size, "changed " .. change[1] .. " width")
    equal(measurements, before + 1, "changed " .. change[1] .. " remeasured")
end
first.width = 30
before = measurements
measure(first)
equal(measurements, before, "available wrapping width does not affect unbounded width")

local empty = label("")
equal(measure(empty), 0, "empty label measures zero")
before = measurements
equal(measure(empty), 0, "zero width remains a valid cache entry")
equal(measurements, before, "zero width is cached")

local second = label("Another label")
measure(second)
env.QuestieCompat.GetNumLines(second)
before, beforeMutations = measurements, mutations
equal(measure(first), #first.text * first.size, "shared scratch changes cannot corrupt another label's cache")
equal(measurements, before, "wrapping a different label does not force measurement")
equal(mutations, beforeMutations, "cache remains independent of shared scratch contents")

first.text, first.font, first.size, first.flags = "Reused objective", "Font C", 14, nil
before = measurements
equal(measure(first), #first.text * first.size, "pooled row reassignment updates width")
equal(measurements, before + 1, "pooled row measures its new content")
first.text = nil
equal(measure(first), 0, "clearing a pooled row clears measured width")
print("Tracker width cache passed: unchanged labels, all font keys, zero width, pooled reuse and shared scratch isolation")
