-- Run from the addon directory with Lua 5.1 or newer.
local function loadLootParser(formats)
    local env = setmetatable(formats, {__index = _G})
    env.QuestieCompat = {}
    env.QuestieLoader = {ImportModule = function() return {} end}
    env.UnitName = function() return "Tester" end
    env.bit = {band = function() error("Unexpected bit operation") end}

    local loadQuestLog
    if setfenv then
        loadQuestLog = setfenv(assert(loadfile("Compat/QuestLog.lua")), env)
    else
        loadQuestLog = assert(loadfile("Compat/QuestLog.lua", "t", env))
    end
    loadQuestLog()
    env.QuestieCompat.InitializeQuestLogCompatibility()
    return env.QuestieCompat.ChatMessageLoot
end

local item = "|Hitem:34338:0:0:0:0:0:0:0|h[Mana Remnants]|h"
local coloredItem = "|cffffffff" .. item .. "|r"
local english = loadLootParser({
    LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
    LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.",
    LOOT_ITEM_CREATED_SELF = "You create: %s.",
    LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d.",
})
for _, prefix in ipairs({"You receive loot: ", "You receive item: ", "You create: "}) do
    assert(english(prefix .. coloredItem .. ".") == "Tester")
    assert(english(prefix .. item .. "x12.") == "Tester")
end
assert(english("PartyMember receives loot: " .. coloredItem .. ".") == "")
assert(english("You receive loot: " .. coloredItem .. "!") == "")

local localized = loadLootParser({
    LOOT_ITEM_SELF = "%1$s erbeutet.",
    LOOT_ITEM_SELF_MULTIPLE = "(+%2$d) %1$s erbeutet.",
})
assert(localized(coloredItem .. " erbeutet.") == "Tester")
assert(localized("(+12) " .. coloredItem .. " erbeutet.") == "Tester")
assert(localized("PartyMember " .. coloredItem .. " erbeutet.") == "")
assert(localized(nil) == "")
assert(loadLootParser({})("You receive loot: " .. coloredItem .. ".") == "")

print("Localized quest loot tests passed")
