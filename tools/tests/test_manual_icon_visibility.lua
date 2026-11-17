-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local profile = {enabled = true, enableMapIcons = true, enableMiniMapIcons = true}
env.Questie = {db = {profile = profile, char = {hidden = {}}}, Debug = noop}
env.QuestieCompat = {HBD = {}, C_Timer = {}}
module("ThreadLib").ThreadInstant = function(callback) coroutine.wrap(callback)() end
module("AvailableQuests").CalculateAndDrawAll = noop
local map = module("QuestieMap")
map.questIdFrames, map.manualFrames = {}, {}
if setfenv then setfenv(assert(loadfile("Modules/Quest/QuestieQuest.lua")), env)()
else assert(loadfile("Modules/Quest/QuestieQuest.lua", "t", env))() end
local quest = module("QuestieQuest")
quest.GetAllQuestIds = noop
local function icon(minimap)
    local frame = {miniMapIcon = minimap, hidden = false, hides = 0, shows = 0}
    function frame:FakeHide() self.hidden = true; self.hides = self.hides + 1 end
    function frame:FakeShow() self.hidden = false; self.shows = self.shows + 1 end
    function frame:ShouldBeHidden() error("manual markers must not use quest-specific filters") end
    return frame
end

for _, category in ipairs({{group = "any", id = -31}, {group = "Repair", id = 2994},
    {group = "Riding Trainer", id = 7954}}) do
    local world, mini = icon(false), icon(true)
    env.ManualWorld, env.ManualMini = world, mini
    map.manualFrames = {[category.group] = {[category.id] = {"ManualWorld", "ManualMini", "MissingFrame"}}}
    profile.enabled, profile.enableMapIcons, profile.enableMiniMapIcons = true, true, true
    profile.enableMiniMapIcons = false
    quest:ToggleNotes(false)
    equal(world.hidden, false, "minimap off preserves world marker: " .. category.group)
    equal(mini.hidden, true, "minimap off hides minimap marker")
    quest:ToggleNotes(false)
    equal(mini.hides, 1, "unchanged visibility does not repeat hide")
    profile.enableMapIcons = false
    quest:ToggleNotes(false)
    profile.enableMapIcons = true
    quest:ToggleNotes(true)
    equal(world.hidden, false, "world map can be restored independently")
    equal(mini.hidden, true, "world map restoration does not restore disabled minimap")
    profile.enableMapIcons = false
    quest:ToggleNotes(false)
    profile.enableMiniMapIcons = true
    quest:ToggleNotes(true)
    equal(world.hidden, true, "minimap restoration does not restore disabled world map")
    equal(mini.hidden, false, "minimap restored independently")
    local shows = mini.shows
    quest:ToggleNotes(true)
    equal(mini.shows, shows, "unchanged visibility does not repeat show")
    profile.enabled = false
    quest:ToggleNotes(false)
    quest:ToggleNotes(true)
    equal(world.hidden, true, "global off keeps world marker hidden")
    equal(mini.hidden, true, "global off keeps minimap marker hidden")
    profile.enabled = true
    quest:ToggleNotes(true)
    equal(world.hidden, true, "global restoration preserves disabled world map")
    equal(mini.hidden, false, "global restoration restores enabled minimap")
    profile.enableMapIcons = true
    quest:ToggleNotes(true)
    profile.enableObjectives, profile.showAvailableQuests = false, false
    quest:ToggleNotes(false)
    equal(world.hidden, false, "quest filters leave manual world markers visible")
    equal(mini.hidden, false, "quest filters leave manual minimap markers visible")
end
print("Manual icon visibility: independent maps, global toggles, categories and quest-filter isolation passed")
