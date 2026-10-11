-- Run from the addon root with Lua 5.2+.
-- Verify that QuestiePlayer derives stable 3.3.5 race/class IDs and quest masks
-- from native UnitRace/UnitClass, without the removed compatibility wrappers.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Read the actual tables from Compat.lua without executing its event/UI setup.
local sourceFile = assert(io.open("Compat/Compat.lua", "r"))
local compatSource = sourceFile:read("*a")
sourceFile:close()
local function readMapping(name)
    local source = assert(
        compatSource:match("QuestieCompat%." .. name .. "%s*=%s*(%b{})"),
        "missing QuestieCompat." .. name .. " mapping"
    )
    return assert(load("return " .. source, name, "t", {}))()
end

local env = setmetatable({}, {__index = _G})
local modules = {}
local calls = {race = 0, class = 0}
local currentRace, currentClass, currentClassName

env.QuestieCompat = {
    ChrRaces = readMapping("ChrRaces"),
    ChrClasses = readMapping("ChrClasses"),
    C_Map = {},
    -- Intentionally no UnitRace or UnitClass compatibility wrappers.
}
env.QuestieLoader = {
    CreateModule = function(_, name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end,
    ImportModule = function(_, name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end,
}
env.UnitLevel = function(unit)
    equal(unit, "player", "level unit")
    return 80
end
env.UnitFactionGroup = function(unit)
    equal(unit, "player", "faction unit")
    return "Horde"
end
env.UnitRace = function(unit)
    equal(unit, "player", "race unit")
    calls.race = calls.race + 1
    return "Localized Race", currentRace -- The original 3.3.5 two-value API.
end
env.UnitClass = function(unit)
    equal(unit, "player", "class unit")
    calls.class = calls.class + 1
    return currentClassName, currentClass -- The original 3.3.5 two-value API.
end

assert(loadfile("Modules/QuestiePlayer.lua", "t", env))()
local player = assert(modules.QuestiePlayer)
local cases = {
    {"Human",    1,  "WARRIOR",     1},
    {"Orc",      2,  "SHAMAN",      7},
    {"Dwarf",    3,  "HUNTER",      3},
    {"NightElf", 4,  "DRUID",      11},
    {"Scourge",  5,  "WARLOCK",     9},
    {"Tauren",   6,  "DRUID",      11},
    {"Gnome",    7,  "MAGE",        8},
    {"Troll",    8,  "PRIEST",      5},
    {"BloodElf", 10, "ROGUE",       4},
    {"Draenei",  11, "PALADIN",     2},
    {"BloodElf", 10, "DEATHKNIGHT", 6},
}
for _, case in ipairs(cases) do
    local race, raceId, class, classId = table.unpack(case)
    currentRace, currentClass = race, class
    currentClassName = "Localized " .. class
    calls.race, calls.class = 0, 0
    player:Initialize()

    local label = race .. "/" .. class
    equal(player:GetRaceId(), raceId, label .. " race ID")
    equal(env.QuestieCompat.ChrRaces[race], raceId, label .. " race mapping")
    equal(env.QuestieCompat.ChrClasses[class], classId, label .. " class mapping")
    equal(player:GetLocalizedClassName(), currentClassName, label .. " localized class")
    equal(calls.race, 1, label .. " native race calls")
    equal(calls.class, 1, label .. " native class calls")

    local raceFlag, classFlag = 2 ^ (raceId - 1), 2 ^ (classId - 1)
    local otherRaceId = raceId == 1 and 2 or 1
    local otherClassId = classId == 1 and 2 or 1
    local otherRaceFlag, otherClassFlag = 2 ^ (otherRaceId - 1), 2 ^ (otherClassId - 1)

    equal(player.HasRequiredRace(raceFlag), true, label .. " matching race")
    equal(player.HasRequiredClass(classFlag), true, label .. " matching class")
    equal(player.HasRequiredRace(otherRaceFlag), false, label .. " wrong race")
    equal(player.HasRequiredClass(otherClassFlag), false, label .. " wrong class")
    equal(player.HasRequiredRace(raceFlag + otherRaceFlag), true, label .. " combined race flags")
    equal(player.HasRequiredClass(classFlag + otherClassFlag), true, label .. " combined class flags")
    equal(player.HasRequiredRace(nil), true, label .. " unrestricted race nil")
    equal(player.HasRequiredClass(nil), true, label .. " unrestricted class nil")
    equal(player.HasRequiredRace(0), true, label .. " unrestricted race zero")
    equal(player.HasRequiredClass(0), true, label .. " unrestricted class zero")
end
print("Player identity: " .. #cases .. " race/class cases and eligibility bitmask checks passed")
