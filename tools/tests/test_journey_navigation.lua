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

print("Journey navigation regressions passed")
