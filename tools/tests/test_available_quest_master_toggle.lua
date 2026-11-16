-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the real visibility rules and quest-menu callbacks together.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local function run(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env)() end
    return assert(load(source, name, "t", env))()
end
env.CreateFrame, env.StaticPopupDialogs = function() return {} end, {}
env.QuestieCompat = {HBDPins = {}}
env.Questie = {LOWLEVEL_NONE = 1, LOWLEVEL_ALL = 2}
run(read("Modules/Options/QuestieOptionsDefaults.lua"), "@Modules/Options/QuestieOptionsDefaults.lua")
local profile = module("QuestieOptionsDefaults"):Load().profile
env.Questie.db = {profile = profile}
equal(profile.showAvailableQuests, true, "new profiles enable the available-quest master switch")
run(read("Modules/QuestieIconVisibility.lua"), "@Modules/QuestieIconVisibility.lua")
run(read("Modules/FramePool/QuestieFrame.lua"), "@Modules/FramePool/QuestieFrame.lua")
local visibility, db = module("QuestieIconVisibility"), module("QuestieDB")
for category in pairs(visibility.CATEGORY_CONFIG) do visibility:SetBoth(category, true) end
local kinds = {"normal", "repeatable", "event", "dungeon", "raid", "pvp", "trivialRepeatable"}
db.IsRepeatable = function(id) return id == 2 or id == 7 end
db.IsActiveEventQuest = function(id) return id == 3 end
db.IsDungeonQuest = function(id) return id == 4 end
db.IsRaidQuest = function(id) return id == 5 end
db.IsPvPQuest = function(id) return id == 6 end
db.QueryQuestSingle = function(id) return id == 7 and 1 or 70 end
db.IsTrivial = function(level) return level == 1 end
local refreshes, levelResets, prunes = {}, 0, 0
-- Load the menu builder unchanged; its refresh scheduler and level-filter work
-- are observed at the boundary rather than running unrelated database scans.
env.QuestieMenu, env.QuestieIconVisibility = {}, visibility
env.QuestieLib, env.l10n = {AddonPath = "Interface/AddOns/Questie-335/"}, function(text) return text end
env._RunFastAvailableRefresh = function(rebuild) refreshes[#refreshes + 1] = {rebuild = rebuild} end
env.AvailableQuests = {
    ResetLevelRequirementCache = function() levelResets = levelResets + 1 end,
    PruneByCurrentLevelFilter = function() prunes = prunes + 1 end,
}
local builder = assert(read("Modules/QuestieMenu/QuestieMenu.lua"):match("function QuestieMenu.buildQuestMenu%(%).-\nend"))
run(builder, "@QuestieMenu.buildQuestMenu")
local menu = env.QuestieMenu.buildQuestMenu()
local master, repeatable, trivial = menu[1], menu[3], menu[4]
equal(repeatable.text, "Repeatable Quests", "repeatable control remains separate")
equal(trivial.text, "Trivial Quest", "trivial control remains separate")
local function hidden(id, minimap, kind)
    return module("QuestieFrame").private.ShouldBeHidden({data = {Id = id, Type = kind or "available"}, miniMapIcon = minimap})
end
local function checkAll(expected)
    for id, kind in ipairs(kinds) do
        for _, minimap in ipairs({false, true}) do
            equal(hidden(id, minimap), expected, kind .. (minimap and " minimap" or " world map"))
        end
    end
end
checkAll(false)
profile.showAvailableQuests = nil
equal(master.checked(), true, "missing saved master value defaults to enabled")
checkAll(false)
master.func()
equal(master.checked(), false, "menu immediately reflects master off")
checkAll(true)
equal(refreshes[#refreshes].rebuild, true, "master uses the existing full available-quest refresh")
for _, minimap in ipairs({false, true}) do
    for _, kind in ipairs({"complete", "monster", "object", "item", "event"}) do
        equal(hidden(1, minimap, kind), false, "master leaves accepted quest icon untouched: " .. kind)
    end
end
master.func()
checkAll(false)

-- Preserve asymmetric surface preferences and the low-level filter across an off/on cycle.
profile.lowLevelStyle = env.Questie.LOWLEVEL_ALL
visibility:SetEnabled("available", false, false)
visibility:SetEnabled("repeatable", true, false)
visibility:SetEnabled("event", false, false)
visibility:SetEnabled("dungeon", true, false)
local saved, previousHidden = {}, {}
for key, value in pairs(profile) do if key ~= "showAvailableQuests" then saved[key] = value end end
for id in ipairs(kinds) do previousHidden[id] = {hidden(id, false), hidden(id, true)} end
master.func()
checkAll(true)
master.func()
for key, value in pairs(saved) do equal(profile[key], value, "master preserves preference: " .. key) end
for id, kind in ipairs(kinds) do
    equal(hidden(id, false), previousHidden[id][1], kind .. " world-map preference restored")
    equal(hidden(id, true), previousHidden[id][2], kind .. " minimap preference restored")
end

-- Category controls still change preferences while the master keeps icons hidden.
visibility:SetBoth("repeatable", true)
master.func()
repeatable.func()
equal(repeatable.checked(), false, "repeatable preference can be disabled under master off")
equal(master.checked(), false, "repeatable toggle does not enable master")
trivial.func()
equal(trivial.checked(), false, "trivial toggle changes its own level filter")
equal(profile.lowLevelStyle, env.Questie.LOWLEVEL_NONE, "trivial toggle retains its existing level-filter behavior")
equal(levelResets, 1, "trivial toggle invalidates the level cache")
equal(prunes, 1, "trivial toggle prunes unavailable levels")
equal(master.checked(), false, "trivial toggle does not enable master")
checkAll(true)
master.func()
for _, minimap in ipairs({false, true}) do equal(hidden(2, minimap), true, "disabled repeatable preference survives master restoration") end
equal(trivial.checked(), false, "master restoration preserves the trivial filter")
print("Available-quest master toggle passed: all categories, both maps, independent preferences and accepted quest icons")
