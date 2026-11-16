-- Run from the addon root with Lua 5.1 or 5.2+.
-- Reuse the chat/link fixture and load the full announcement module unchanged.
local file = assert(io.open("tools/tests/test_missing_quest_links.lua", "r"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local first = assert(source:find("-- Unknown/empty database rows", 1, true))
source = source:sub(1, first - 1)
source = source:gsub("IsInGroup = function%(%) return false end",
    "LE_PARTY_CATEGORY_INSTANCE = 2, IsInGroup = function(category) return category == nil end", 1)
source = source .. [[
profile.questAnnounceChannel = "party"
profile.questAnnounceObjectiveProgress = true
profile.questAnnounceAccepted, profile.questAnnounceAbandoned = false, false
local sent = {}
env.SendChatMessage = function(message, channel)
    assert(not message:find("|4", 1, true), "raw grammar marker reached SendChatMessage")
    equal(channel, "PARTY", "existing group channel is preserved")
    sent[#sent + 1] = message
end
local function contains(message, text, label)
    assert(message and message:find(text, 1, true), label .. ": " .. tostring(message))
end
local function expect(text)
    contains(sent[#sent], text, "outgoing wording")
    contains(printed[#printed], text, "local wording")
    assert(not printed[#printed]:find("|4", 1, true), "raw grammar marker reached local output")
end
local french = "Cible |4personnage tué:personnages tués;"
announce:ObjectiveChanged(1, french, 0, 4)
equal(#sent, 0, "incomplete baseline does not announce")
announce:ObjectiveChanged(1, french, 1, 4)
expect("1/4 Cible personnage tué")
contains(sent[#sent], link:GetQuestLinkStringById(1), "group quest link is preserved")
contains(printed[#printed], link:GetQuestHyperLink(1), "local quest hyperlink is preserved")
announce:ObjectiveChanged(1, french, 1, 4)
equal(#sent, 1, "duplicate progress remains suppressed")
announce:ObjectiveChanged(1, french, 2, 4)
expect("2/4 Cible personnages tués")
announce:ObjectiveChanged(1, french, 4, 4)
expect("4/4 Cible personnages tués")
equal(#sent, 3, "completion keeps the original objective state after grammar changes")
announce:ObjectiveChanged(1, french, 4, 4)
equal(#sent, 3, "duplicate completion remains suppressed")

for index, case in ipairs({{1, "яблоко"}, {2, "яблока"}, {3, "яблока"}, {4, "яблока"},
    {5, "яблок"}, {11, "яблок"}, {12, "яблок"}, {14, "яблок"}, {21, "яблоко"},
    {22, "яблока"}, {25, "яблок"}, {111, "яблок"}}) do
    local id, count = 1000 + index, case[1]
    local text = "Fruit |4яблоко:яблока:яблок;"
    announce:ObjectiveChanged(id, text, 0, count)
    announce:ObjectiveChanged(id, text, count, count)
    expect(count .. "/" .. count .. " Fruit " .. case[2])
end
for index, case in ipairs({{"Multiple |4one:many; and |4single:plural;", 2, "Multiple many and plural"},
    {"Fallback |4first:second:third:fourth;", 2, "Fallback first"},
    {"Single |4only;", 1, "Single only"}, {"Empty |4:plural;", 1, "Empty "},
    {"Plainstrider Beak", 7, "Plainstrider Beak"}}) do
    local id, text, count = 2000 + index, case[1], case[2]
    announce:ObjectiveChanged(id, text, 0, count)
    announce:ObjectiveChanged(id, text, count, count)
    expect(count .. "/" .. count .. " " .. case[3])
end

-- Disabling progress must still allow the eventual completion announcement.
profile.questAnnounceObjectiveProgress = false
local before = #sent
announce:ObjectiveChanged(3000, "Disabled |4one:many;", 1, 2)
equal(#sent, before, "disabled progress does not announce")
announce:ObjectiveChanged(3000, "Disabled |4one:many;", 2, 2)
expect("2/2 Disabled many")
equal(#sent, before + 1, "completion remains enabled independently of progress")

-- Login hydration establishes state without announcing existing completion.
env.Questie.started = false
before = #sent
announce:ObjectiveChanged(3001, "Loaded |4one:many;", 2, 2)
env.Questie.started = true
announce:ObjectiveChanged(3001, "Loaded |4one:many;", 2, 2)
equal(#sent, before, "loaded completion is not reannounced")

-- Acceptance and abandonment still retire old per-objective state.
local originalAnnounce, callbacks = announce.AnnounceObjectiveToChannel, 0
announce.AnnounceObjectiveToChannel = function() callbacks = callbacks + 1 end
for index, method in ipairs({"AcceptedQuest", "AbandonedQuest"}) do
    local id = 4000 + index
    announce:ObjectiveChanged(id, "Reset |4one:many;", 0, 2)
    announce[method](announce, id)
    announce:ObjectiveChanged(id, "Reset |4one:many;", 2, 2)
end
equal(callbacks, 0, "quest lifecycle resets do not retain incomplete announcement state")
announce.AnnounceObjectiveToChannel = originalAnnounce
print("Announcement grammar passed: progress/completion, French/Russian forms, links and duplicate/lifecycle handling")
]]
if setfenv then setfenv(assert(loadstring(source, "announcement grammar regression")), _G)()
else assert(load(source, "announcement grammar regression", "t", _G))() end
