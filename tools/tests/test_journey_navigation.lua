-- Run from the addon root with Lua 5.1 or 5.2+.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G, env.abs = env, math.abs
env.string = setmetatable({trim = function(value) return tostring(value):match("^%s*(.-)%s*$") end}, {__index = string})
local modules, widgets, links, rendered, chat = {}, {}, {}, {}, {}
local shift, tooltipShown = false, false
local function module(name)
    modules[name] = modules[name] or {private = {}}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end, ImportModule = function(_, name) return module(name) end}
env.Questie = {db = {char = {complete = {}, hidden = {}}, profile = {}}, Colorize = function(_, text) return text end}
env.QuestieCompat = {C_Timer = {After = noop}}
env.UnitLevel = function() return 80 end
env.YES, env.NO = "Yes", "No"
env.GetItemInfo = function() return "Item", "item:5" end
env.GetItemIcon = noop
env.IsShiftKeyDown = function() return shift end
env.ChatEdit_InsertLink = function(link) chat[#chat + 1] = link end
env.GameTooltip = {IsShown = function() return tooltipShown end, Hide = function() tooltipShown = false end}
local popupId
env.ItemRefTooltip = {SetHyperlink = function(_, link) popupId = tonumber(link:match("questie:(%d+):")) end}
local function create(_, kind)
    local widget = {kind = kind, children = {}, callbacks = {}, userdata = {}, treeframe = {SetWidth = noop},
        text = {SetFontObject = noop}, content = {SetHeight = noop}}
    widget.frame = {obj = widget}
    setmetatable(widget, {__index = function() return noop end})
    function widget:AddChild(child) self.children[#self.children + 1] = child end
    function widget:ReleaseChildren() self.children = {} end
    function widget:SetText(value) self.value = value end
    function widget:SetTitle(value) self.title = value end
    function widget:SetFullWidth(value) self.fullWidth = value end
    function widget:GetText() return self.value or "" end
    function widget:SetUserData(key, value) self.userdata[key] = value end
    function widget:GetUserData(key) return self.userdata[key] end
    function widget:SetCallback(event, callback) self.callbacks[event] = callback end
    function widget:Fire(event, ...)
        if self.callbacks[event] then self.callbacks[event](self, event, ...) end
    end
    function widget:SelectTab(value) self:Fire("OnGroupSelected", value) end
    -- AceGUI selection fires OnGroupSelected; OnClick is a separate mouse event.
    function widget:SelectByValue(value)
        self.selected = tostring(value)
        self:Fire("OnGroupSelected", self.selected)
    end
    function widget:Click(value)
        value = tostring(value)
        self:Fire("OnClick", value, self.selected == value)
        if self.selected ~= value then self:SelectByValue(value) end
    end
    widgets[kind] = widget
    if kind == "InteractiveLabel" then links[#links + 1] = widget end
    return widget
end
env.LibStub = function() return {Create = create} end
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    if setfenv then setfenv(assert(loadstring(source, "@" .. path)), env)()
    else assert(load(source, "@" .. path, "t", env))() end
end
local l10n = module("l10n")
setmetatable(l10n, {__call = function(_, text, ...) return string.format(text, ...) end})
module("QuestieJourneyUtils").Spacer = noop
module("QuestieServerProgress").AddQuestDetails = noop
module("QuestieCorrections").hiddenQuests = {}
module("QuestieCorrections").questItemBlacklist = {}
module("QuestieReputation").GetReputationReward = noop
local journey = module("QuestieJourney")
journey.private.CreateObjectiveText = function() return "Objective" end
journey.private.ShowJourneyTooltip = noop
journey.private.HideJourneyTooltip = env.GameTooltip.Hide
local lib = module("QuestieLib")
lib.GetEffectiveQuestLevel = function() return 80 end
lib.GetRaceString, lib.GetClassString = function() return "" end, function() return "" end
lib.GetColoredQuestName = function(_, id) return "Quest " .. id end
module("QuestieLink").GetQuestInsertStringById = function(_, id) return "335-link:" .. id end
local db = module("QuestieDB")
db.GetQuest = function(id) return {Id = id, name = "Quest " .. id, level = 80} end
db.QueryQuestSingle = function(_, key)
    if key == "requiredLevel" or key == "questLevel" then return 80 end
    if key == "name" then return "Quest" end
end
db.QueryNPCSingle = function(_, key)
    if key == "name" then return "NPC" end
    if key == "spawns" then return {[1] = {{25, 25}}} end
end
db.QueryObjectSingle, db.QueryItemSingle = function() return "Object" end, function() return "Item" end
db.QueryItem = function() return {{6}, nil, nil} end
db.IsRepeatable = function() return false end
db.IsDoableVerbose = function() return nil, false end
local search = module("QuestieSearch")
search.LastResult = {query = "", quest = {}, npc = {}, object = {}, item = {}}
search.ByID = function(_, id)
    search.LastResult = {query = id, quest = {[id] = true}, npc = {[id] = true}, object = {[id] = true}, item = {[id] = true}}
end
loadModule("Modules/Journey/QuestDetailsFrame.lua")
loadModule("Modules/Journey/QuestieSearchResults.lua")
local results, details = modules.QuestieSearchResults, modules.QuestDetailsFrame
local drawQuest, drawItem = details.Draw, results.ItemDetailsFrame
details.Draw = function(_, _, quest) rendered[#rendered + 1] = {type = "quest", id = quest.Id} end
results.SpawnDetailsFrame = function(_, _, id, kind) rendered[#rendered + 1] = {type = kind, id = id} end
results.ItemDetailsFrame = function(_, _, id) rendered[#rendered + 1] = {type = "item", id = id} end
local searchOpened = false
journey.tabGroup = {SelectTab = function(_, tab)
    equal(tab, "search", "prerequisite opens Advanced Search")
    equal(tooltipShown, false, "hover tooltip hidden before changing tabs")
    results:DrawSearchTab(create(nil, "SimpleGroup"))
    searchOpened = true
end}

-- Prerequisites use existing labels, navigate from a view with no search controls, and normalize signed IDs.
drawQuest(details, create(nil, "SimpleGroup"), {Id = 5, name = "Parent", preQuestSingle = {-6}, preQuestGroup = {7, 8}})
equal(#links, 3, "single and grouped prerequisite links rendered")
for _, link in ipairs(links) do
    equal(link.fullWidth, true, "prerequisite links use the available paragraph width")
    tooltipShown = true
    link:Fire("OnClick")
    equal(searchOpened, true, "search created before linked navigation")
    equal(rendered[#rendered].id, link:GetUserData("id"), "each link selects its own quest")
    equal(widgets.TreeGroup.selected, tostring(link:GetUserData("id")), "linked quest highlighted")
end
equal(popupId, nil, "prerequisites navigate instead of opening a popup")
journey.private:GetInteractiveQuestLabel(db.GetQuest(9)):Fire("OnClick")
equal(popupId, 9, "other quest labels retain their popup behavior")

-- Automatic navigation opens exactly one detail panel of the requested type, even with Shift held.
shift = true
for _, kind in ipairs({"quest", "npc", "object", "item"}) do
    local before = #rendered
    results:SetSearch(kind, 5)
    equal(#rendered, before + 1, "one detail draw for " .. kind)
    equal(rendered[#rendered].type, kind, "matching IDs select requested result type")
    equal(rendered[#rendered].id, 5, "requested ID rendered")
end
equal(#chat, 0, "programmatic selection never inserts chat links")

-- A normal click renders once; Shift-click works even on an already selected quest.
shift = false
results:DrawSearchResultTab(create(nil, "SimpleGroup"), 2, 5, false)
local tree, before = widgets.TreeGroup, #rendered
tree:Click(5)
equal(#rendered, before + 1, "mouse selection draws details once")
shift = true
tree:Click(5)
equal(#chat, 1, "Shift-click on selected quest inserts a link")
equal(chat[1], "335-link:5", "existing 3.3.5 chat-link function used")
equal(#rendered, before + 1, "selected quest is not redundantly redrawn")

-- Exercise the real item-source label from the reported navigation path.
drawItem(results, create(nil, "SimpleGroup"), 5)
local sourceLink = links[#links]
equal(sourceLink:GetUserData("type"), "npc", "item source is a linked NPC")
tooltipShown = true
sourceLink:Fire("OnClick")
equal(tooltipShown, false, "source hover tooltip hidden")
equal(rendered[#rendered].type, "npc", "item source immediately opens NPC details")
equal(rendered[#rendered].id, 6, "item source opens the right NPC")
equal(#chat, 1, "source navigation does not insert a chat link")

-- The real details renderer shows reference chains, independent of the player's eligibility.
local function drawChain(records, hidden)
    local query, isDoable = db.QueryQuestSingle, db.IsDoableVerbose
    local corrections = module("QuestieCorrections")
    local previousHidden = corrections.hiddenQuests
    local linkReads = 0
    db.QueryQuestSingle = function(id, field)
        if field == "nextQuestInChain" or field == "breadcrumbForQuestId" then
            linkReads = linkReads + 1
            assert(linkReads <= 40, "cyclic chains must not hang the details renderer")
            return records[id] and records[id][field]
        end
        return query(id, field)
    end
    db.IsDoableVerbose = function() return "Different class", true, "WRONG_CLASS" end
    corrections.hiddenQuests = hidden or {}
    local frame = create(nil, "SimpleGroup")
    drawQuest(details, frame, {Id = 1, name = "Chain root"})
    db.QueryQuestSingle, db.IsDoableVerbose = query, isDoable
    corrections.hiddenQuests = previousHidden
    local section
    for _, child in ipairs(frame.children) do
        if child.kind == "InlineGroup" and child.title == "Next in chain:" then
            assert(not section, "only one follow-up section is rendered")
            section = child
        end
    end
    local ids = {}
    for _, link in ipairs(section and section.children or {}) do
        ids[#ids + 1] = link:GetUserData("id")
        equal(link.fullWidth, true, "linked follow-up uses the available paragraph width")
    end
    return table.concat(ids, ","), section
end
for _, missing in ipairs({"zero", "nil"}) do
    local ids, section = drawChain({[1] = {nextQuestInChain = missing == "zero" and 0 or nil, breadcrumbForQuestId = 2},
        [2] = {nextQuestInChain = 3}, [3] = {nextQuestInChain = 0}})
    equal(ids, "2,3", "initial " .. missing .. " link follows breadcrumb and keeps later chain order")
    assert(section, "breadcrumb chain has a localized section")
end
do
    local ids, section = drawChain({[1] = {nextQuestInChain = 2, breadcrumbForQuestId = 4},
        [2] = {nextQuestInChain = 0, breadcrumbForQuestId = 3}})
    equal(ids, "2,3", "explicit chain wins and breadcrumb fallback works at later steps")
    tooltipShown, searchOpened = true, false
    section.children[1]:Fire("OnClick")
    equal(searchOpened, true, "follow-up link creates Advanced Search before navigation")
    equal(tooltipShown, false, "follow-up navigation dismisses the hover tooltip")
    equal(rendered[#rendered].id, 2, "follow-up link opens its own quest details")
    equal(widgets.TreeGroup.selected, "2", "follow-up link selects its quest in search")
    equal(#chat, 1, "follow-up navigation does not insert chat links")
end
equal(drawChain({[1] = {nextQuestInChain = 2}, [2] = {breadcrumbForQuestId = 3},
    [3] = {nextQuestInChain = 2}}), "2,3", "mixed cycles do not duplicate follow-ups")
equal(drawChain({[1] = {nextQuestInChain = 2}, [2] = {nextQuestInChain = 1}}), "2", "cycle does not redisplay the root quest")
equal(drawChain({[1] = {breadcrumbForQuestId = 1}}), "", "self-link is omitted")
equal(drawChain({[1] = {nextQuestInChain = 2}, [2] = {nextQuestInChain = 3}}, {[3] = true}), "2", "hidden follow-up stops the reference chain")
for _, records in ipairs({{}, {[1] = {nextQuestInChain = 0}},
    {[1] = {nextQuestInChain = -2, breadcrumbForQuestId = 3}}}) do
    local ids, section = drawChain(records)
    equal(ids, "", "absent or negative endpoint has no follow-ups")
    equal(section, nil, "absent chain has no empty section")
end
local _, hiddenSection = drawChain({[1] = {nextQuestInChain = 2}}, {[2] = true})
equal(hiddenSection, nil, "hidden first follow-up has no empty section")

-- Compare Journey's displayed threshold with the native 3.3.5 green ranges.
-- The native helper indexes {4, 4, 5, 5, 6, 6, 7, 7, 8, ...} by player level / 5.
local baseQuery = db.QueryQuestSingle
local function difficultyText(questLevel, minLevel)
    db.QueryQuestSingle = function(id, key)
        if key == "questLevel" then return questLevel end
        if key == "requiredLevel" then return minLevel end
        return baseQuery(id, key)
    end
    local frame = create(nil, "SimpleGroup")
    drawQuest(details, frame, {Id = 5, name = "Difficulty test"})
    db.QueryQuestSingle = baseQuery
    for _, child in ipairs(frame.children) do
        if type(child.value) == "string" and child.value:find("Difficulty Range:", 1, true) then
            return child.value
        end
    end
    error("missing rendered difficulty range")
end
for questLevel = 1, 80 do
    local gray = questLevel + 3
    while true do
        local greenRange = gray < 10 and 4 or gray < 20 and 5 or gray < 30 and 6 or gray < 40 and 7 or 8
        if gray - questLevel > greenRange then break end
        gray = gray + 1
    end
    local text = difficultyText(questLevel, 1)
    equal(tonumber(text:match("|cFFC0C0C0%[(%d+)%]|r")), gray, "native gray threshold for quest level " .. questLevel)
    equal(tonumber(text:match("|cFF40C040%[(%d+)%]|r")), questLevel + 3, "green threshold preserved")
    equal(tonumber(text:match("|cFFFFFF00%[(%d+)%]|r")), math.max(1, questLevel - 2), "yellow threshold preserved")
end
equal(tonumber(difficultyText(5, 20):match("|cFFC0C0C0%[(%d+)%]|r")), 20, "minimum level still clamps gray threshold")
local scaling = difficultyText(-1, 1)
assert(not scaling:find("|cFFC0C0C0", 1, true), "scaling quests have no gray threshold")
assert(scaling:find("|cFFFFFF00[1-80]|r", 1, true), "scaling quest follows player level")
assert(difficultyText(-1, 85):find("|cFFFFFF00[85]|r", 1, true), "scaling quest respects a higher minimum level")

-- AceGUI is shared across addons. Newer TreeGroups leave pooled buttons visible
-- when SetTree(nil) returns before the row-hiding pass; an empty table clears them.
local pooledTree = {rows = {"Year 2026"}, treeframe = {SetWidth = noop},
    SetFullWidth = noop, SetFullHeight = noop, EnableButtonTooltips = noop, SetCallback = noop}
function pooledTree:SetTree(tree)
    self.tree = tree
    if tree then self.rows = tree end
end
env.LibStub = function() return {Create = function(_, kind)
    equal(kind, "TreeGroup", "quest list acquires a pooled tree")
    return pooledTree
end} end
journey.private.questsByZone = {}
journey.private.lastZoneSelection = {}
module("QuestieJourneyFactions").BuildFactionIntroductionOrder = function() return {} end
loadModule("Modules/Journey/tabs/QuestsByZone/QuestsByZone.lua")
loadModule("Modules/Journey/tabs/QuestsByFaction/QuestsByFactions.lua")
for _, tab in ipairs({journey.private.questsByZone, journey.private.questsByFaction}) do
    local container = create(nil, "SimpleGroup")
    pooledTree.rows = {"Year 2026"}
    tab:ManageTree(container, nil)
    equal(#pooledTree.rows, 0, "unselected filter clears pooled Journey history")
    local quests = {{value = "a", text = "Available quests"}}
    tab:ManageTree(container, quests)
    equal(pooledTree.rows, quests, "selecting a filter displays its quests")
    tab:ManageTree(container, nil)
    equal(#pooledTree.rows, 0, "changing filter clears the previous quest list")
    tab:ManageTree(container, {})
    equal(#pooledTree.rows, 0, "empty quest result remains blank")
end

-- Restoring a saved selection must tolerate either missing tree input.
do
    local zone = journey.private.questsByZone
    local separator = string.char(1)
    local saved = "a" .. separator .. "6"
    local tree = {{value = "a", children = {{value = 6}}}}
    local selections, scheduled = {}, {}
    local target = {SelectByValue = function(_, value) selections[#selections + 1] = value end}
    env.strsplit = function(_, value) return value:match("([^" .. separator .. "]+)" .. separator .. "(.*)") end
    local after = env.QuestieCompat.C_Timer.After
    env.QuestieCompat.C_Timer.After = function(_, callback) scheduled[#scheduled + 1] = callback end
    journey.private.lastZoneSelection[3] = saved
    zone:RestoreSavedQuestSelection(nil, tree)
    zone:RestoreSavedQuestSelection(target, nil)
    zone:RestoreSavedQuestSelection(nil, nil)
    equal(journey.private.lastZoneSelection[3], saved, "missing tree inputs preserve the saved selection")
    equal(#selections, 0, "missing tree inputs do not select a row")
    equal(#scheduled, 0, "missing tree inputs do not schedule a detail redraw")
    zone:RestoreSavedQuestSelection(target, tree)
    equal(selections[1], saved, "valid tree still restores its selected quest")
    equal(#scheduled, 1, "valid restoration still schedules details")
    zone:RestoreSavedQuestSelection(target, {{value = "p", children = {{value = 6}}}})
    equal(journey.private.lastZoneSelection[3], "p" .. separator .. "6", "restoration follows category changes")
    zone:RestoreSavedQuestSelection(target, {})
    equal(journey.private.lastZoneSelection[3], nil, "valid empty tree clears an obsolete selection")
    env.QuestieCompat.C_Timer.After = after
end
do
    loadModule("Modules/Journey/QuestieJourney.lua")
    env.Questie.started = true
    env.QuestieJourneyFrame = {Show = noop, Hide = noop}
    env.PlaySound = noop
    module("QuestieOptions").HideFrame = noop
    local requests, draws = 0, 0
    env.QuestieCompat.RequestCompletedQuestRefresh = function() requests = requests + 1 end
    journey.private.HandleTabChange = function() draws = draws + 1 end
    journey:ToggleJourneyWindow()
    equal(requests, 1, "opening Journey requests server completions")
    equal(draws, 1, "Journey draws immediately from the local cache")
    journey:RefreshCompletionView()
    equal(draws, 2, "the open Journey tab refreshes when new completions arrive")
    journey.private.lastOpenWindow = "search"
    journey:RefreshCompletionView()
    equal(draws, 2, "a response leaves the in-progress search alone")
    journey:ToggleJourneyWindow()
    equal(requests, 1, "closing Journey does not request a refresh")
    journey:RefreshCompletionView()
    equal(draws, 2, "a closed Journey does not redraw")
end
print("Journey navigation, quest chains, difficulty, pooled trees, selection and completion refresh passed")
