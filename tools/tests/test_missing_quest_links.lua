-- Run from the addon root with Lua 5.1 or 5.2. Missing data must preserve usable chat text.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function noop() end
local modules, hooks, printed = {}, {}, {}
local env = setmetatable({}, {__index = _G})
env._G, env.unpack, env.bit = env, unpack or table.unpack, {band = function() return 0 end}
env.QuestieLoader = {ImportModule = function(_, name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end}
env.QuestieLoader.CreateModule = env.QuestieLoader.ImportModule
local function module(name) return env.QuestieLoader:ImportModule(name) end
local function loadModule(path)
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
end
-- Match l10n's format/unpack behavior, including missing trailing argument errors.
local l10n = setmetatable({GetUILocale = function() return "enUS" end}, {__call = function(_, key, ...)
    local args = {...}
    for i, value in ipairs(args) do args[i] = tostring(value) end
    return string.format(key, env.unpack(args))
end})
modules.l10n = l10n
local profile = {questAnnounceLocally = true, questAnnounceObjectives = true, questAnnounceItems = true,
    questAnnounceAccepted = true, questAnnounceAbandoned = true, questAnnounceCompleted = true}
env.Questie = {started = true, db = {profile = profile, char = {complete = {}}}, Debug = noop,
    Print = function(_, text) printed[#printed + 1] = assert(text) end}
env.UnitName, env.UnitGUID = function() return "Player" end, function() return "Player-GUID" end
local names = {[1] = "Known Quest", [3] = "Known Native Quest", [5] = ""}
local nativeIds = {2, 3}
local function nativeLink(id) return "|cffffff00|Hquest:" .. id .. ":10|h[Native " .. id .. "]|h|r" end
env.GetQuestLogTitle = function(index)
    local id = nativeIds[index]
    if id then return "Native " .. id, 10, nil, 0, false, false, nil, false, id end
end
env.GetQuestLink = function(index) return nativeLink(nativeIds[index]) end
local chatText, insertions = "Keep my draft", 0
env.ChatFrame1EditBox = {GetText = function() return chatText end, SetText = function(_, text) chatText = text end}
env.ChatEdit_GetActiveWindow = function() return env.ChatFrame1EditBox end
env.ChatEdit_InsertLink = function(text) insertions = insertions + 1; chatText = text end
env.IsShiftKeyDown = function() return true end
env.string = setmetatable({split = function(_, value) return value:match("([^:]+):([^:]+):?(.*)") end}, {__index = string})
env.hooksecurefunc = function(name, callback) hooks[name] = callback end
env.ItemRefTooltip, env.GameTooltip = {SetHyperlink = noop}, {SetHyperlink = noop}
env.ChatFrame_AddMessageEventFilter, env.ChatFrame_RemoveMessageEventFilter = noop, noop
env.GetItemInfo = function() return "Quest item", "[Quest item]" end
env.SelectQuestLogEntry, env.SetAbandonQuest, env.AbandonQuest = noop, noop, noop
env.QuestieCompat = {IsInGroup = function() return false end, IsInRaid = function() return false end, C_Timer = {}}
local db, lib = module("QuestieDB"), module("QuestieLib")
db.QueryQuestSingle = function(id, field) if field == "name" then return names[id] end end
db.QuestPointers = {[1] = true, [3] = true, [6] = true}
db.IsRepeatable, db.IsPvPQuest = function() return false end, function() return false end
local itemQuestId
db.QueryItemSingle = function(_, field) if field == "startQuest" then return itemQuestId end end
lib.AddonPath = "Interface/AddOns/Questie-335/"
lib.GetEffectiveQuestLevel = function() return 10, 10 end
lib.GetColoredQuestName = function(_, id)
    assert(names[id] and names[id] ~= "", "missing name reached quest coloring")
    return names[id]
end
lib.PrintDifficultyColor = function(_, _, text) return text end
module("QuestieEvent").IsEventQuest = function() return false end
loadModule("Compat/QuestLog.lua")
loadModule("Modules/QuestLinks/Link.lua")
loadModule("Modules/QuestLinks/ChatFilter.lua")
loadModule("Modules/QuestieAnnounce.lua")
loadModule("Modules/Quest/BreadcrumbQuests.lua")
local link, announce = module("QuestieLink"), module("QuestieAnnounce")

-- Unknown/empty database rows get ordinary native links or readable text, never custom links.
for _, id in ipairs({2, 4, 5}) do
    equal(link:GetQuestLinkStringById(id), id == 2 and nativeLink(2) or "Quest " .. id, "missing quest link " .. id)
    equal(link:GetQuestHyperLink(id), nil, "missing quest cannot build custom hyperlink " .. id)
end
equal(link:GetQuestLinkStringById(1), "|cffffff00|Hquest:1:10|h[Known Quest]|h|r", "known quest link stays native")
equal(link:GetQuestLinkStringById(3), nativeLink(3), "known quest keeps its live native link")
assert(link:GetQuestHyperLink(1):find("|Hquestie:1:", 1, true), "known custom hyperlinks remain available")
-- Keep the compatibility insertion contract used by native-only quests and chat commands.
equal(link:GetQuestInsertStringById(2), nativeLink(2), "native-only quest can still be inserted")
local filter = module("ChatFilter").Filter
for _, id in ipairs({2, 6}) do
    local original = "Look at " .. nativeLink(id)
    local suppressed, replacement = filter({}, "CHAT_MSG_SAY", original, "Player")
    assert(not suppressed, "missing custom link must not suppress chat")
    equal(replacement or original, original, "native chat link remains intact " .. id)
end
local _, converted = filter({}, "CHAT_MSG_SAY", "[Known Quest (1)]", "Player")
assert(converted and converted:find("|Hquestie:1:", 1, true), "known chat links still convert")
local insert = link.GetQuestInsertStringById
link.GetQuestInsertStringById = function() end
hooks.ChatFrame_OnHyperlinkShow({}, "questie:4:Player-GUID", "[Missing]", "LeftButton")
equal(chatText, "Keep my draft", "nil shift-click replacement preserves draft")
equal(insertions, 0, "nil shift-click replacement is not inserted")
link.GetQuestInsertStringById = insert

-- Exercise all message paths with nil/empty quest names and a usable native-only quest.
for _, id in ipairs({2, 4, 5}) do
    local expected = id == 2 and nativeLink(2) or "Quest " .. id
    local function checkMessage(callback, label)
        local before = #printed
        callback()
        equal(#printed, before + 1, label .. " prints once")
        assert(printed[#printed]:find(expected, 1, true), label .. " must retain a readable quest reference")
    end
    checkMessage(function() announce:AnnounceObjectiveToChannel(id, "Objective", "1/1") end, "objective")
    checkMessage(function() announce:AnnounceQuestItemLootedToChannel(id, 100 + id) end, "quest item")
    for _, method in ipairs({"AcceptedQuest", "AbandonedQuest", "CompletedQuest"}) do
        checkMessage(function() announce[method](announce, id) end, method)
    end
    itemQuestId, profile.questAnnounceLocally = id, false
    checkMessage(function() announce:ItemLooted("|Hitem:" .. (200 + id) .. "|h[Quest item]|h", "Player", nil, nil, "Player") end,
        "self item announcement")
    profile.questAnnounceLocally = true
    checkMessage(function() announce.IncompleteBreadcrumbQuest(1, id) end, "incomplete breadcrumb")
    checkMessage(function() assert(module("BreadcrumbQuests").AbandonQuest(2, id)) end, "breadcrumb abandonment")
end
-- Solo starter-item notifications honor their item toggle and the master silence setting.
profile.questAnnounceChannel = "disabled"
itemQuestId = 1
local itemId = 500
local getItemInfo = env.GetItemInfo
env.GetItemInfo = function(id) return "Item " .. id, "[Item " .. id .. "]" end
for _, items in ipairs({true, false}) do
    for _, locally in ipairs({true, false}) do
        for _, shutUp in ipairs({true, false}) do
            itemId = itemId + 1
            profile.questAnnounceItems, profile.questAnnounceLocally, profile.questieShutUp = items, locally, shutUp
            local before = #printed
            announce:ItemLooted("|Hitem:" .. itemId .. "|h[Test]|h", "Player", nil, nil, "Player")
            local expected = items and not shutUp and 1 or 0
            equal(#printed, before + expected, "starter-item notification respects settings")
            if expected == 1 then
                local wording = locally and "Picked up " or "You picked up "
                equal(printed[#printed], wording .. "[Item " .. itemId .. "] which starts "
                    .. link:GetQuestHyperLink(1) .. "!", "enabled notification preserves wording and links")
            end
        end
    end
end
env.GetItemInfo = getItemInfo

-- Exercise quest-link progress with the original sparse objective indices.
local addPlayerProgress
for index = 1, 30 do
    local name, value = debug.getupvalue(link.CreateQuestTooltip, index)
    if name == "_AddPlayerQuestProgress" then
        addPlayerProgress = value
        break
    end
end
assert(addPlayerProgress)
env.Questie.Colorize = function(_, text) return text end
db.IsComplete = function() return 0 end
lib.GetObjectiveDescription = function(_, objective) return objective.Description end
lib.GetRGBForObjective = function() return "" end
module("QuestiePlayer").currentQuestlog = {[1] = true}
local cache = module("QuestLogCache")
local native = {type = "item", raw_text = "Étoffe de laine : 2/5"}
cache.TryGetQuest = function() return {objectives = {[3] = native}} end
local objective = {Index = 3, Type = "item", Description = "Wool Cloth", Collected = 2, Needed = 5}
local function progressLine()
    local lines = {}
    addPlayerProgress({AddLine = function(_, text) lines[#lines + 1] = text end}, {Id = 1, Objectives = {[3] = objective}})
    return lines[3]
end
equal(progressLine(), " - Étoffe de laine : 2/5|r", "quest links preserve native wording and counter placement")
objective.Collected = 3
equal(progressLine(), " - Wool Cloth: 3/5|r", "updated progress wins over a stale client text counter")
objective.Collected, objective.IsRequiredSourceItem = 2, true
equal(progressLine(), " - Wool Cloth: 2/5|r", "synthetic source items cannot borrow a native row")
objective.IsRequiredSourceItem = nil
objective.Type, objective.Needed, native.type, native.raw_text = "event", 0, "event", "Read the note."
equal(progressLine(), " - Read the note.|r", "action instructions keep their text without a fabricated counter")

print("Missing quest links: native fallbacks, chat preservation, announcement formats and item settings passed")
