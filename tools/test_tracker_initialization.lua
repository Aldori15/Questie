-- Run from the addon root with Lua 5.1 or 5.2+.
-- Execute complete tracker modules with native-style frames, without post-initialization patching.
local unpackValues = unpack or table.unpack
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G, env.unpack, env.tinsert = env, unpackValues, table.insert
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local chunk
    if setfenv then
        chunk = setfenv(assert(loadstring(source, "@" .. path)), env)
    else
        chunk = assert(load(source, "@" .. path, "t", env))
    end
    chunk()
end
local function noop() end
local methods = {}
local function object(name, parent)
    return setmetatable({name = name, parent = parent, width = 0, height = 0,
        text = "", font = {"Fonts/FRIZQT__.TTF", 12, ""}, points = {}, scripts = {}, shown = true},
        {__index = methods})
end
for _, method in ipairs({"EnableMouse", "EnableMouseWheel", "SetMovable", "SetResizable",
    "RegisterForDrag", "RegisterForClicks", "SetJustifyH", "SetJustifyV", "SetFrameLevel",
    "SetAlpha", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
    "SetVertexColor", "SetTexCoord", "SetAttribute", "RegisterEvent", "UnregisterEvent", "SetHitRectInsets"}) do
    methods[method] = noop
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width > 0 and self.width or self:GetStringWidth() end
function methods:GetHeight()
    if self.height > 0 then return self.height end
    return self.font[2] * math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth())))
end
function methods:SetAllPoints(relative)
    self.width, self.height = relative:GetWidth(), relative:GetHeight()
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...)
    local args = {...}
    if select("#", ...) == 5 then
        assert(type(args[2]) == "table", "anchor must reference an initialized control")
    end
    self.points[#self.points + 1] = args
end
function methods:SetTexture(...) self.texture = {...} end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, callback)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then original(...) end
        callback(...)
    end
end
function methods:CreateTexture() return object(nil, self) end
function methods:CreateFontString() return object(nil, self) end
function methods:SetFont(...) self.font = {...} end
function methods:GetFont() return unpackValues(self.font) end
function methods:SetText(value) self.text = value or "" end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text * self.font[2] / 2 end
function methods:SetValueStep(value) self.valueStep = value end
function methods:SetValue(value) self.value = value end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetScrollChild(child) self.scrollChild = child end

env.UIParent = object("UIParent")
local templates = {}
env.CreateFrame = function(kind, name, parent, template)
    local frame = object(name, parent)
    if name then env[name] = frame end
    if template then templates[template] = true end
    if template == "UIPanelScrollFrameTemplate" then
        for _, suffix in ipairs({"ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton"}) do
            env[name .. suffix] = object(name .. suffix, frame)
        end
    end
    return frame
end
env.Questie = {db = {profile = {trackerHeaderEnabled = true, trackerFontSizeHeader = 14,
    trackerFontSizeQuest = 12, trackerFontSizeObjective = 10, trackerFontSizeZone = 13,
    trackerEnabled = true}, char = {isTrackerExpanded = true}},
    icons = {complete = "complete"}, Debug = noop}
env.QuestieCompat = {NOOP = noop, NOOP_MT = {__index = function() return noop end},
    C_Timer = {}, C_QuestLog = {GetMaxNumQuestsCanAccept = function() return 25 end},
    LibUIDropDownMenu = {}}
env.LibStub = function(name)
    equal(name, "LibSharedMedia-3.0", "tracker media library")
    return {Fetch = function() return "Fonts/FRIZQT__.TTF" end}
end
loadModule("Modules/Libs/QuestieLoader.lua")
local loader = env.QuestieLoader
local l10n = loader:CreateModule("l10n")
setmetatable(l10n, {__call = function(_, text) return text end})
loader:CreateModule("QuestieTracker").HasQuest = function() return true end
loader:CreateModule("QuestieCombatQueue").Queue = function(_, callback) callback() end
loader:CreateModule("QuestieLib").AddonPath = "Interface/AddOns/Questie-335/"
loadModule("Compat/UI.lua")
loadModule("Modules/Tracker/TrackerHeaderFrame.lua")
loadModule("Modules/Tracker/TrackerQuestFrame.lua")
loadModule("Modules/Tracker/TrackerLinePool.lua")
local headerModule = loader:ImportModule("TrackerHeaderFrame")
local questModule = loader:ImportModule("TrackerQuestFrame")
local pool = loader:ImportModule("TrackerLinePool")
local base = object("Base")
local header = headerModule.Initialize(base)
local quest = questModule.Initialize(base, header)

-- The header can measure text correctly before the line pool is initialized.
local label = header.trackedQuests.label
label:SetFont("Fonts/FRIZQT__.TTF", 14, "")
label:SetText("Tracked Quests: 5")
label:SetWidth(10)
equal(label:GetUnboundedStringWidth(), 119, "header measures complete text")
equal(label:GetWidth(), 10, "header measurement preserves constrained width")
equal(headerModule.headerFrame, header, "header frame published")
equal(header:GetHeight(), 14, "header height preserves configured font size")
local tests = 1

-- Controls use the final layout immediately, without a later line-pool hook.
assert(templates.UIPanelScrollFrameTemplate, "native scroll template retained")
equal(quest.ScrollFrame.scrollBarHideable, true, "template scrollbar auto-show disabled")
equal(quest.ScrollBar:IsShown(), false, "scrollbar starts hidden")
quest.ScrollBar:Show()
equal(quest.ScrollBar:IsShown(), false, "template cannot show scrollbar again")
equal(quest.ScrollBg:IsShown(), true, "scrollbar background setup preserved")
equal(quest.ScrollBg.texture[4], 0.35, "scrollbar background opacity preserved")
equal(quest.ScrollUpButton:IsShown(), false, "up button remains hidden")
equal(quest.ScrollDownButton:IsShown(), false, "down button remains hidden")
equal(quest.ScrollBar.points[1][2], quest.ScrollUpButton, "scrollbar top uses up button")
equal(quest.ScrollBar.points[2][2], quest.ScrollDownButton, "scrollbar bottom uses down button")
equal(quest.ScrollBar.points[2][5], -4, "scrollbar lower offset preserved")
equal(quest.ScrollDownButton.points[1][5], 12, "down button offset preserved")
equal(quest.ScrollBar.valueStep, 25, "scroll increment retained")
equal(quest.ScrollFrame.scrollChild, quest.ScrollChildFrame, "scroll child attached")
tests = tests + 1

-- Mouse-wheel movement stays bounded even while the scrollbar itself is hidden.
quest.ScrollFrame:SetHeight(100)
quest.ScrollChildFrame:SetHeight(180)
quest.ScrollFrame:SetVerticalScroll(0)
quest.ScrollFrame:GetScript("OnMouseWheel")(quest.ScrollFrame, -1)
equal(quest.ScrollFrame:GetVerticalScroll(), 25, "wheel moves down")
equal(quest.ScrollBar.value, 25, "scrollbar value tracks wheel")
quest.ScrollChildFrame:GetScript("OnMouseWheel")(quest.ScrollChildFrame, -10)
equal(quest.ScrollFrame:GetVerticalScroll(), 80, "wheel clamps at bottom")
quest:GetScript("OnMouseWheel")(quest, 10)
equal(quest.ScrollFrame:GetVerticalScroll(), 0, "wheel clamps at top")
quest.ScrollChildFrame:SetHeight(80)
questModule.OnMouseWheel(quest, -1)
equal(quest.ScrollFrame:GetVerticalScroll(), 0, "short content does not scroll")
tests = tests + 1

-- Execute the whole pooled-frame initialization, including its coroutine yields and item buttons.
local resumes = 0
local initialization = coroutine.create(function() pool.Initialize(quest) end)
while coroutine.status(initialization) ~= "dead" do
    local ok, message = coroutine.resume(initialization)
    assert(ok, message)
    resumes = resumes + 1
    -- Every label already created must be ready, including during partially completed initialization.
    for index = 1, 250 do
        local line = env["linePool" .. index]
        if line then
            equal(line.label.GetUnboundedStringWidth, env.QuestieCompat.GetUnboundedStringWidth, "pooled text-width adapter")
            equal(line.label.GetWrappedWidth, line.label.GetWidth, "pooled wrapped-width adapter")
            equal(line.label.GetNumLines, env.QuestieCompat.GetNumLines, "pooled line-count adapter")
        end
    end
end
assert(resumes > 1, "initialization still yields to avoid a startup stall")
assert(env.linePool250 and not env.linePool251, "complete line pool created")
assert(env.Questie_ItemButton25 and not env.Questie_ItemButton26, "quest item button pool retained")
equal(pool.GetLastLine(), env.linePool250, "module pool matches created frames")
tests = tests + 1

-- Font adapters use separate measurement state; wrapped labels still resize their clickable frames.
local line = env.linePool1
label = line.label
label:SetFont("Fonts/FRIZQT__.TTF", 10, "")
label:SetWidth(45)
label:SetText("Collect nine items")
equal(label:GetUnboundedStringWidth(), 90, "objective measures full text width")
equal(label:GetWrappedWidth(), 45, "objective keeps wrapped width")
equal(label:GetNumLines(), 2, "objective reports wrapped line count")
equal(line:GetWidth(), 45, "clickable frame follows label width")
equal(line:GetHeight(), 20, "clickable frame follows wrapped label height")
label:SetWidth(90)
label:SetText("Collect nine items")
equal(label:GetNumLines(), 1, "wider objective wraps to one line")
equal(line:GetHeight(), 10, "clickable frame shrinks after unwrapping")
label:SetText("")
equal(label:GetUnboundedStringWidth(), 0, "empty objective has no text width")
tests = tests + 1
print("Tracker initialization regression tests passed (" .. tests .. " groups)")
