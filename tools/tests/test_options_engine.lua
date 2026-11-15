-- Run from the addon root with Lua 5.1 or 5.2+. Real Ace schema validation,
-- callback dispatch and profiles; native frames/AceGUI controls are strict stand-ins.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local env = setmetatable({}, {__index = _G})
env._G, env.unpack = env, unpack or table.unpack
env.tinsert, env.tremove, env.format, env.strmatch = table.insert, table.remove, string.format, string.match
env.wipe = function(t) for key in pairs(t) do t[key] = nil end end
local s = {frames = {}, widgets = {}, combat = false, errors = {}, hiddenPanels = 0, journey = false}
local function compile(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env) end
    return assert(load(source, name, "t", env))
end
local function loadFile(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return compile(source, "@" .. path)()
end
env.loadstring = compile
env.geterrorhandler = function() return function(message) s.errors[#s.errors + 1] = message end end
env.InCombatLockdown = function() return s.combat end
env.IsAddOnLoaded = function() return false end
env.UnitName, env.GetRealmName = function() return "Tester" end, function() return "Realm" end
env.UnitClass, env.UnitRace = function() return "Warrior", "WARRIOR" end, function() return "Human", "Human" end
env.UnitFactionGroup, env.GetLocale = function() return "Alliance" end, function() return "enUS" end
env.GetBuildInfo = function() return "3.3.5", "12340", "", 30300 end
env.CloseSpecialWindows = function() return false end
env.UISpecialFrames, env.StaticPopupDialogs = {}, {}
env.ACCEPT, env.CANCEL, env.OKAY, env.STATICPOPUP_NUMDIALOGS = "Accept", "Cancel", "Okay", 4
env.NORMAL_FONT_COLOR_CODE, env.FONT_COLOR_CODE_CLOSE, env.ERR_NOT_IN_COMBAT = "|cffffffff", "|r", "In combat"
env.NORMAL_FONT_COLOR = {r = 1, g = 1, b = 1}
env.GameFontHighlight, env.GameFontHighlightLarge, env.GameFontHighlightSmall = {}, {}, {}
local frameMethods = {}
for _, name in ipairs({"SetPoint", "SetAllPoints", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "EnableMouse", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing", "SetJustifyH", "SetVertexColor", "ClearAllPoints"}) do
    frameMethods[name] = noop
end
function frameMethods:SetWidth(value) self.width = value end
function frameMethods:SetPoint(point, ...) self.points[point] = {...} end
function frameMethods:ClearAllPoints() self.points = {} end
function frameMethods:SetHeight(value) self.height = value end
function frameMethods:SetSize(width, height) self.width, self.height = width, height end
function frameMethods:GetWidth() return self.width or 100 end
function frameMethods:GetHeight() return self.height or 100 end
function frameMethods:SetScale(value) self.scale = value end
function frameMethods:SetParent(value) self.parent = value end
function frameMethods:GetParent() return self.parent end
function frameMethods:SetFrameLevel(value) self.frameLevel = value end
function frameMethods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel() + 1) or 0 end
function frameMethods:SetNormalFontObject(value) self.normalFont = value end
function frameMethods:SetHighlightFontObject(value) self.highlightFont = value end
function frameMethods:SetDisabledFontObject(value) self.disabledFont = value end
function frameMethods:GetName() return self.name end
function frameMethods:GetFrameStrata() return "DIALOG" end
function frameMethods:SetText(value) self.text = value end
function frameMethods:SetTextColor(...) self.textColor = {...} end
function frameMethods:SetTexture(value) self.texture = value end
function frameMethods:EnableMouse(value) self.mouseEnabled = value end
function frameMethods:SetHighlightTexture(value) self.highlightTexture = value end
function frameMethods:Enable() self.disabled = false end
function frameMethods:Disable() self.disabled = true end
function frameMethods:RegisterEvent(event) self.events[event] = true end
function frameMethods:SetScript(event, callback) self.scripts[event] = callback end
function frameMethods:GetScript(event) return self.scripts[event] end
function frameMethods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function frameMethods:IsShown() return self.shown end
function frameMethods:CreateTexture() return env.CreateFrame("Texture", nil, self) end
function frameMethods:CreateFontString() return env.CreateFrame("FontString", nil, self) end
env.CreateFrame = function(kind, name, parent)
    assert(kind == "Frame" or kind == "Button" or kind == "GameTooltip" or kind == "Texture" or kind == "FontString",
        "unexpected native frame type: " .. tostring(kind))
    local frame = setmetatable({kind = kind, name = name, parent = parent, scripts = {}, points = {}, events = {}, shown = true},
        {__index = frameMethods})
    s.frames[#s.frames + 1] = frame
    if name then env[name] = frame end
    return frame
end
env.UIParent = env.CreateFrame("Frame")
env.UIParent:SetSize(1024, 768)
env.InterfaceOptionsFramePanelContainer = env.CreateFrame("Frame")
env.InterfaceOptionsFrame, env.GameMenuFrame, env.ColorPickerFrame =
    env.CreateFrame("Frame"), env.CreateFrame("Frame"), env.CreateFrame("Frame")
env.HideUIPanel = function(frame) s.hiddenPanels = s.hiddenPanels + 1; frame:Hide() end
env.InterfaceOptions_AddCategory = function(category) s.category = category end
env.StaticPopup_Show = function(name) s.popup = assert(env.StaticPopupDialogs[name]); return env.CreateFrame("Frame") end

loadFile("Libs/LibStub/LibStub.lua")
loadFile("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
loadFile("Libs/AceDB-3.0/AceDB-3.0.lua")
loadFile("Libs/AceDBOptions-3.0/AceDBOptions-3.0.lua")
local gui = env.LibStub:NewLibrary("AceGUI-3.0", 35)
local widgetMethods = {}
function widgetMethods:SetUserData(key, value) self.userdata[key] = value end
function widgetMethods:GetUserData(key) return self.userdata[key] end
function widgetMethods:GetUserDataTable() return self.userdata end
function widgetMethods:SetCallback(event, callback) self.callbacks[event] = callback end
function widgetMethods:Fire(event, ...)
    local callback = self.callbacks[event]
    if callback then return callback(self, event, ...) end
end
function widgetMethods:AddChild(child) child.parent = self; self.children[#self.children + 1] = child end
function widgetMethods:ReleaseChildren()
    for _, child in ipairs(self.children) do
        child:ReleaseChildren()
        child:Fire("OnRelease")
        child.released = true
    end
    self.children = {}
end
function widgetMethods:SetLayout(layout) self.layout = layout end
function widgetMethods:SetDisabled(value) self.disabled = value end
function widgetMethods:SetText(value) self.text = value end
function widgetMethods:SetLabel(value) self.label = value end
function widgetMethods:SetTitle(value) self.title = value end
function widgetMethods:SetValue(value) self.value = value end
function widgetMethods:SetList(value) self.list = value end
function widgetMethods:SetWidth(value) self.frame:SetWidth(value) end
function widgetMethods:SetHeight(value) self.frame:SetHeight(value) end
function widgetMethods:SetColor(...) self.color = {...} end
function widgetMethods:SetHasAlpha(value) self.alphaEnabled = value end
function widgetMethods:SetType(value) self.checkType = value end
function widgetMethods:SetSliderValues(...) self.range = {...} end
function widgetMethods:SetIsPercent(value) self.percent = value end
function widgetMethods:SetImage(value) self.image = value end
function widgetMethods:SetImageSize(...) self.imageSize = {...} end
function widgetMethods:Show() self.frame:Show() end
for _, name in ipairs({"SetTriState", "SetDescription", "SetFontObject", "SetStatusTable", "PauseLayout",
    "ResumeLayout", "DoLayout", "PerformLayout", "SetFullWidth", "SetRelativeWidth"}) do widgetMethods[name] = noop end
local function widget(kind)
    local value = setmetatable({type = kind, userdata = {}, callbacks = {}, children = {},
        frame = env.CreateFrame("Frame")}, {__index = widgetMethods})
    value.frame:SetSize(170, 20)
    if kind == "CheckBox" then value.highlight = value.frame:CreateTexture() end
    if kind == "ColorPicker" then
        value.frame:SetScript("OnClick", function()
            env.ColorPickerFrame.func = function() value:Fire("OnValueChanged", 0.4, 0.3, 0.2, 0.1) end
            env.ColorPickerFrame.opacityFunc, env.ColorPickerFrame.cancelFunc =
                env.ColorPickerFrame.func, env.ColorPickerFrame.func
            env.ColorPickerFrame:Show()
        end)
    end
    s.widgets[#s.widgets + 1] = value
    return value
end
gui.WidgetRegistry = {}
gui.RegisterWidgetType = function(_, name, constructor) gui.WidgetRegistry[name] = constructor end
gui.RegisterAsContainer = function(_, value)
    value.userdata, value.callbacks, value.children = {}, {}, {}
    setmetatable(value, {__index = widgetMethods})
    s.widgets[#s.widgets + 1] = value
    return value
end
gui.Create = function(_, kind)
    if gui.WidgetRegistry[kind] then return gui.WidgetRegistry[kind]() end
    assert(({ScrollFrame = true, InlineGroup = true, SimpleGroup = true, CheckBox = true, Slider = true,
        Dropdown = true, Button = true, Icon = true, ColorPicker = true, Label = true, InteractiveLabel = true,
        EditBox = true, Heading = true, LSM30_Font = true})[kind], "unsupported AceGUI widget: " .. kind)
    return widget(kind)
end
gui.ClearFocus = function() s.focusCleared = (s.focusCleared or 0) + 1 end
gui.GetWidgetVersion = function() return 1 end
loadFile("Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
loadFile("Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua")
local registry, dialog = env.LibStub("AceConfigRegistry-3.0"), env.LibStub("AceConfigDialog-3.0")
env.LibStub:NewLibrary("AceConfig-3.0", 3).RegisterOptionsTable = function(_, ...) return registry:RegisterOptionsTable(...) end
loadFile("Modules/Libs/QuestieLoader.lua")
local loader = env.QuestieLoader
local l10n = loader:CreateModule("l10n")
setmetatable(l10n, {__call = function(_, value) return value end})
loader:CreateModule("QuestieLib").AddonPath = "Interface/AddOns/Questie-335/"
loader:CreateModule("QuestieOptions").HideFrame = function() s.optionsHidden = true end
loader:ImportModule("QuestieEventHandler").CancelWindowRestores = noop
local journey = loader:CreateModule("QuestieJourney")
journey.IsShown = function() return s.journey end
journey.ToggleJourneyWindow = function() s.journey = not s.journey end
journey.BuildMainFrame = function()
    s.journeyBuilt = (s.journeyBuilt or 0) + 1
    journey.tabGroup = {SelectTab = function(_, tab) s.journeyTab = tab end}
end
local db = env.LibStub("AceDB-3.0"):New({}, {profile = {enabled = true}}, "Default")
db:SetProfile("Spare"); db:SetProfile("Default")
env.Questie = {db = db}
local fonts = {Default = "font/default.ttf", Custom = "font/custom.ttf"}
local values, writes, executions = {inherited = true, font = "Default", level = 0.75}, {}, 0
local disabled = false
local handler = {
    Get = function(_, info) return values[info[#info]] end,
    Set = function(_, info, value) values[info[#info]] = value; writes[#writes + 1] = info[#info] end,
    Disabled = function() return disabled end,
    Execute = function() executions = executions + 1 end,
}
local schema = {type = "group", name = "Questie", handler = handler, args = {
    controls = {type = "group", name = function() return db:GetCurrentProfile() .. " controls" end, order = 1, args = {
        inheritedGroup = {type = "group", inline = true, name = "Inherited", disabled = "Disabled",
            get = "Get", set = "Set", args = {
                inherited = {type = "toggle", name = "Inherited", order = 1},
            }},
        font = {type = "select", dialogControl = "LSM30_Font", name = "Font", order = 2,
            values = fonts, get = "Get", set = "Set"},
        level = {type = "range", name = "Opacity", order = 3, min = 0, max = 1, step = 0.05,
            isPercent = true, get = "Get", set = "Set"},
        color = {type = "color", name = "Color", order = 4, hasAlpha = true,
            get = function() return 0.1, 0.2, 0.3, 0.4 end,
            set = function(_, ...) s.color = {...} end},
        flags = {type = "multiselect", name = "Flags", order = 5, values = {[0] = "Critical", [1] = "Info"},
            get = function(_, key) return key == 0 end,
            set = function(_, key, checked) s.flag = {key, checked} end},
        execute = {type = "execute", name = "Execute", order = 6, func = "Execute", confirm = true},
    }},
    profiles = env.LibStub("AceDBOptions-3.0"):GetOptionsTable(db),
    hidden = {type = "group", name = "Hidden", order = 2, hidden = function() return not s.showHidden end,
        args = {description = {type = "description", name = "Hidden content"}}},
}}
local originalSet = schema.args.controls.args.inheritedGroup.set
-- Include the complete production tab schemas, not just representative controls.
env.Questie.Debug = noop
env.Questie.Colorize = function(_, value) return value end
env.Questie.GetIconNameFromPath = function() return "default" end
env.Questie.icons = setmetatable({}, {__index = function(_, key) return "icon/" .. key end})
env.Questie.LOWLEVEL_NONE, env.Questie.LOWLEVEL_ALL, env.Questie.LOWLEVEL_OFFSET, env.Questie.LOWLEVEL_RANGE = 1, 2, 3, 4
env.IsMacClient, env.GetExpansionLevel = function() return false end, function() return 2 end
env.GetCVar, env.InCombatLockdown = function() return "0" end, function() return s.combat end
env.QuestieCompat = {C_Timer = {}, CALENDAR_WEEKDAY_NAMES = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}}
env.bit = bit or bit32
l10n.GetFallbackLocale = function(_, locale) return locale end
loader:ImportModule("QuestieIconVisibility").IsEnabled = function() return true end
loader:ImportModule("QuestieIconVisibility").IsEnabledAnywhere = function() return true end
loader:ImportModule("TrackerUtils").IsVoiceOverLoaded = function() return false end
local media = env.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
media.MediaType = {SOUND = "sound"}
media.HashTable = function() return fonts end
media.List = function() return {} end
loader:ImportModule("QuestieOptions").tabs = {}
loader:ImportModule("IsleOfQuelDanas").localizedPhaseNames = {[1] = "Phase 1", [2] = "Phase 2"}
local sourceFile = assert(io.open("Modules/Options/QuestieOptions.lua", "r"))
local controllerSource = sourceFile:read("*a"):gsub("\r\n", "\n")
sourceFile:close()
for _, method in ipairs({"GetProfileValue", "SetProfileValue"}) do
    local code = assert(controllerSource:match("(function QuestieOptions:" .. method .. "%([^%)]*%).-\nend)"))
    compile('local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")\n' .. code, "production option accessors")()
end
loadFile("Modules/Options/QuestieOptionsDefaults.lua")
db:RegisterDefaults(loader:ImportModule("QuestieOptionsDefaults"):Load())
loadFile("Modules/Options/QuestieOptionsUtils.lua")
local actualTabs = {general = "General", map = "Map", icons = "Icons", tracker = "Tracker",
    auto = "Auto", nameplate = "Nameplate", advanced = "Advanced"}
for key, name in pairs(actualTabs) do
    loadFile("Modules/Options/" .. name .. "Tab/QuestieOptions" .. name .. ".lua")
    schema.args["actual_" .. key] = loader:ImportModule("QuestieOptions").tabs[key]:Initialize()
    schema.args["actual_" .. key].order = 20
end
local popupNames = {"QUESTIE_RELOAD", "QUESTIE_LANG_CHANGED_RELOAD", "QUESTIE_RESET_CONFIRM",
    "QUESTIE_JOURNEY_RESET_CONFIRM", "QUESTIE_RECOMPILE_DATABASE_CONFIRM"}
s.accepted = {}
for _, name in ipairs(popupNames) do
    env.StaticPopupDialogs[name] = {OnAccept = function(self, value)
        s.accepted[name] = (s.accepted[name] or 0) + 1
        equal(self, s, "popup callback retains its receiver")
        equal(value, "pending", "popup callback retains its arguments")
        return name
    end}
end
local unrelatedAccept = function() s.unrelatedAccepted = true end
env.StaticPopupDialogs.UNRELATED = {OnAccept = unrelatedAccept}
registry:RegisterOptionsTable("Questie", schema)
loadFile("Modules/Options/QuestieOptionsEngine.lua")
local engine = loader:ImportModule("QuestieOptionsEngine")
engine:Initialize(schema)
local cloned = registry:GetOptionsTable("QuestieSettings")("dialog", "AceConfigDialog-3.0")
local function tick()
    for _, frame in ipairs(s.frames) do
        local update = frame:GetScript("OnUpdate")
        if update then update(frame) end
    end
    assert(not next(s.errors), s.errors[1])
end
local function control(key, value)
    for index = #s.widgets, 1, -1 do
        local widget = s.widgets[index]
        local path = widget:GetUserData("path")
        if not widget.released and path and path[#path] == key
            and (value == nil or widget:GetUserData("value") == value) then return widget end
    end
    error("missing rendered control: " .. key)
end

-- Exercise the shipped layout algorithm with the controls produced by the real
-- dialog. Uniform control heights isolate wrapping/column alignment from fonts.
local flow
do
    local file = assert(io.open("Libs/AceGUI-3.0/AceGUI-3.0.lua", "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    local layout = assert(source:match('(local layoutrecursionblock = nil.-AceGUI:RegisterLayout%("Flow".+)$'))
    local previous = env._layoutCapture
    env._layoutCapture = {RegisterLayout = function(_, name, callback)
        equal(name, "Flow", "the actual AceGUI Flow layout is loaded")
        flow = callback
    end}
    compile('local AceGUI = _layoutCapture\nlocal math_max = math.max\nlocal safecall = function(fn, ...) if fn then return fn(...) end end\n' .. layout,
        "production AceGUI Flow")()
    env._layoutCapture = previous
end
local function geometry(children, width)
    local content = env.CreateFrame("Frame")
    content:SetWidth(width)
    content.obj = {LayoutFinished = noop}
    local proxies, frames = {}, {}
    for _, child in ipairs(children) do
        local frame = env.CreateFrame("Frame")
        frame:SetSize(child.frame.width or 170, 20)
        local proxy = {frame = frame, width = child.width, relWidth = child.relWidth,
            SetWidth = function(_, value) frame:SetWidth(value) end}
        proxies[#proxies + 1], frames[child] = proxy, frame
    end
    flow(content, proxies)
    local function position(frame)
        if frame == content then return 0, 0 end
        local p = assert(frame.points.TOPLEFT, "Flow positions each visible control")
        local x, y = position(p[1])
        if p[2] == "TOPRIGHT" then x = x + p[1]:GetWidth() end
        return x + (p[3] or 0), y + (p[4] or 0)
    end
    return function(child)
        local frame = assert(frames[child], "control belongs to the tested row")
        local x, y = position(frame)
        return x, y, frame:GetWidth()
    end
end
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.001,
        label .. ": expected " .. expected .. ", got " .. actual)
end
local groups = 0
assert(cloned ~= schema and cloned.args ~= schema.args, "standalone schema is independent")
equal(cloned.handler, handler, "handler identity is preserved")
equal(cloned.args.profiles.handler, schema.args.profiles.handler, "real AceDBOptions handler is preserved")
equal(cloned.args.controls.args.font.values, fonts, "SharedMedia lists retain identity")
equal(schema.args.controls.args.inheritedGroup.set, originalSet, "legacy schema callbacks are not replaced")
equal(schema.args.controls.args.inheritedGroup.args.inherited.disabled, nil, "legacy disabled inheritance is untouched")
equal(cloned.args.profiles.args.new.get, false, "explicit false getter survives cloning")
groups = groups + 1

for _, name in ipairs(popupNames) do
    local pendingAccept = env.StaticPopupDialogs[name].OnAccept
    s.combat = true
    pendingAccept(s, "pending")
    equal(s.accepted[name], nil, "pending Questie popup is blocked during combat: " .. name)
    s.combat = false
    equal(pendingAccept(s, "pending"), name, "Questie popup preserves callback result outside combat")
    equal(s.accepted[name], 1, "Questie popup runs once outside combat: " .. name)
end
equal(env.StaticPopupDialogs.UNRELATED.OnAccept, unrelatedAccept, "other addons' popup callbacks remain untouched")
s.combat = true
env.StaticPopupDialogs.UNRELATED.OnAccept()
equal(s.unrelatedAccepted, true, "unrelated popup is not intercepted by Questie's guard")
s.combat = false
groups = groups + 1

engine:ShowFrame()
assert(engine:IsShown() and s.optionsHidden, "standalone settings use the shared window close entry point")
equal(env.QuestieSettingsFrame.heading.text, "Default controls", "sidebar selects first visible category")
assert(env.QuestieSettingsFrame.scale <= 1, "native settings frame fits the screen")
equal(control("font").list, fonts, "real AceConfig renders the media selector")
equal(control("font").value, "Default", "method getter resolves inherited handler")
equal(control("color").color[4], 0.4, "real AceConfig preserves RGBA getter returns")
assert(control("level").percent and control("level").range[3] == 0.05, "real AceConfig preserves percentage slider precision")
equal(control("flags", 0).value, true, "zero-key multiselect renders its checked state")
control("flags", 0):Fire("OnValueChanged", false)
equal(s.flag[1], 0, "zero-key multiselect dispatches the original key")
equal(s.flag[2], false, "multiselect dispatches the selected state")
control("font"):Fire("OnValueChanged", "Custom")
equal(values.font, "Custom", "real AceConfig invokes the cloned method setter")
groups = groups + 1

disabled = true
engine:RefreshStates()
equal(control("inherited").disabled, true, "cloned controls retain ancestor method disabled state")
disabled = false
s.combat = true
engine:RefreshStates()
assert(control("font").disabled and control("color").disabled, "combat disables editable controls")
control("font"):Fire("OnValueChanged", "Default")
equal(values.font, "Custom", "already-open callbacks cannot write during combat")
s.combat = false
engine:RefreshStates()
control("execute"):Fire("OnClick")
assert(s.popup and s.popup.OnAccept, "real AceConfig opens its confirmation dialog")
s.combat = true
s.popup.OnAccept()
equal(executions, 0, "delayed confirmation cannot execute after combat begins")
s.combat = false
engine:RefreshStates()
control("execute"):Fire("OnClick")
s.popup.OnAccept()
equal(executions, 1, "confirmed method action executes outside combat")
groups = groups + 1

local color = control("color")
color.frame:GetScript("OnClick")(color.frame)
env.ColorPickerFrame.func()
equal(s.color[4], 0.1, "owned color picker dispatches RGBA changes")
local oldPicker = env.ColorPickerFrame.func
engine:SelectCategory("profiles")
assert(not env.ColorPickerFrame:IsShown() and env.ColorPickerFrame.func ~= oldPicker,
    "navigation detaches an owned color callback before controls are released")
local selected = control("choose")
selected:Fire("OnValueChanged", "Spare")
equal(db:GetCurrentProfile(), "Spare", "real AceDBOptions profile setter runs through cloned method callback")
tick()
equal(env.QuestieSettingsFrame.heading.text, "Profiles", "profile refresh preserves the current category")
engine:SelectCategory("controls")
equal(env.QuestieSettingsFrame.heading.text, "Spare controls", "category labels reflect current profile")
for _, change in ipairs({function() db:CopyProfile("Default") end, function() db:ResetProfile() end}) do
    local rendered = #s.widgets
    change(); tick()
    assert(#s.widgets > rendered, "profile copy/reset notification refreshes the standalone view")
end
groups = groups + 1

local before = #s.widgets
registry:NotifyChange("Questie")
registry:NotifyChange("Questie")
tick()
assert(#s.widgets > before, "legacy registry notifications refresh the standalone view")
s.showHidden = true
registry:NotifyChange("QuestieSettings")
tick()
engine:SelectCategory("hidden")
equal(env.QuestieSettingsFrame.heading.text, "Hidden", "newly visible categories can be selected")
s.showHidden = false
engine:RefreshStates()
equal(env.QuestieSettingsFrame.heading.text, "Spare controls", "hiding the selected category chooses a visible fallback")
color = control("color")
color.frame:GetScript("OnClick")(color.frame)
local foreign = function() end
env.ColorPickerFrame.func = foreign
local hidden = s.hiddenPanels
engine:HideFrame()
equal(env.ColorPickerFrame.func, foreign, "closing settings preserves another addon's color picker callback")
equal(s.hiddenPanels, hidden, "closing settings does not hide another addon's color picker")
assert(not engine:IsShown(), "standalone settings close")
before = #s.widgets
registry:NotifyChange("QuestieSettings"); tick()
equal(#s.widgets, before, "hidden settings do not rerender on notifications")
engine:ToggleConfigWindow()
assert(engine:IsShown(), "toggle reopens settings")
engine:ToggleConfigWindow()
assert(not engine:IsShown(), "toggle closes settings")
groups = groups + 1
engine:ShowFrame()
local renderedTabs = 0
for key in pairs(actualTabs) do
    engine:SelectCategory("actual_" .. key)
    tick()
    assert(engine:IsShown(), "production tab renders in the standalone frame: " .. key)
    if key == "tracker" then
        local fontSelectors = 0
        for _, widget in ipairs(s.widgets) do
            if not widget.released and widget.type == "LSM30_Font" then fontSelectors = fontSelectors + 1 end
        end
        equal(fontSelectors, 4, "all four production Tracker font selectors render")
    elseif key == "icons" then
        control("iconOverridesToggle"):Fire("OnClick")
        tick()
        assert(control("iconTypeSlay"), "production icon override notification reveals its controls")
    end
    renderedTabs = renderedTabs + 1
end
equal(renderedTabs, 7, "all production tab definitions validate and render through the real AceConfigDialog")
groups = groups + 1

for _, width in ipairs({548, 568, 708}) do
    engine:SelectCategory("actual_general"); tick()
    local at = geometry(control("questCompleteSound").parent.children, width)
    local previousY
    for _, key in ipairs({"questCompleteSound", "objectiveCompleteSound", "objectiveProgressSound"}) do
        local x, y = at(control(key))
        near(x, 0, "sound row begins at the left edge at " .. width)
        if previousY then assert(y < previousY, "each sound selection starts a separate row") end
        local buttonX, buttonY = at(control(key .. "Button"))
        local choiceX, choiceY = at(control(key .. "Choice"))
        near(buttonX, 204, "sound preview keeps its column")
        near(choiceX, 289, "sound selector keeps its column")
        near(buttonY, y, "sound preview stays with its toggle")
        near(choiceY, y, "sound selector stays with its toggle")
        previousY = y
    end
    engine:SelectCategory("actual_icons"); tick()
    at = geometry(control("showNormalQuestsMap").parent.children, width)
    previousY = nil
    for _, key in ipairs({"showNormalQuests", "showEventQuests", "showRepeatableQuests", "showTrivialRepeatableQuests",
        "showPvPQuests", "showDungeonQuests", "showRaidQuests", "showCompleteQuests", "showObjectivesToggle", "showItemStartQuests"}) do
        local x, y = at(control(key .. "Label"))
        local mapX, mapY = at(control(key .. "Map"))
        local miniX, miniY = at(control(key .. "Minimap"))
        near(x, 0, "quest icon labels keep their left column")
        near(mapX, 272, "quest world-map checkboxes keep their column")
        near(miniX, 348.5, "quest minimap checkboxes keep their column")
        near(mapY, y, "world-map checkbox remains on its labeled row")
        near(miniY, y, "minimap checkbox remains on its labeled row")
        if previousY then assert(y < previousY, "quest icon categories never run together") end
        previousY = y
    end
    if width <= 568 then
        local firstX, firstY = at(control("townsfolkOptions"))
        local _, middleY = at(control("professionOptions"))
        local lastX, lastY, lastWidth = at(control("vendorOptions"))
        near(middleY, firstY, "profession button shares the Other Icons row")
        near(lastY, firstY, "vendor button shares the Other Icons row")
        if width == 548 then
            assert(math.abs(firstX - (width - lastX - lastWidth)) < 6,
                "Other Icons buttons remain centered in the narrower content area")
        end
        local rootAt = geometry(control("show_icons").parent.children, width)
        near(rootAt(control("show_icons")), 0, "Enable Icons begins at the left edge")
        near(rootAt(control("hideMapIconsForUntrackedToggle")), 0,
            "Hide untracked icons aligns with Enable Icons")
        at = geometry(control("iconTypeSlay").parent.children, width)
        local function row(keys)
            local firstY
            for index, key in ipairs(keys) do
                local x, y = at(control(key))
                near(x, (index - 1) * (170 * (#keys == 3 and 1 or 1.5)), "override columns align without spacer offsets")
                if firstY then near(y, firstY, "related override controls share a row") else firstY = y end
            end
        end
        row({"iconTypeSlay", "iconTypeLoot", "iconTypeObject"})
        row({"iconTypeEvent", "iconTypeTalk", "iconTypeInteract"})
        row({"iconTypeAvailable", "iconTypeComplete", "iconTypeAvailableGray"})
        row({"iconTypeRepeatable", "iconTypeRepeatableComplete"})
        row({"iconTypeEventQuest", "iconTypeEventQuestComplete"})
        row({"iconTypePVPQuest", "iconTypePVPQuestComplete"})
        engine:SelectCategory("actual_nameplate"); tick()
        for _, key in ipairs({"nameplateEnabled", "nameplateShowObjectiveText", "nameplateObjectiveTextTargetOnly",
            "nameplateScale", "nameplateTextScale", "nameplateTargetFrameEnabled", "nameplateTargetFrameScale"}) do
            local widget = control(key)
            at = geometry(widget.parent.children, width)
            local x, _, measuredWidth = at(widget)
            near(x, 0, "nameplate controls do not inherit empty spacer offsets")
            near(measuredWidth, width, "long nameplate controls fill their own row")
        end
        for _, pair in ipairs({{"nameplateX", "nameplateY"}, {"nameplateTextX", "nameplateTextY"},
            {"nameplateTargetFrameX", "nameplateTargetFrameY"}}) do
            at = geometry(control(pair[1]).parent.children, width)
            local x, y = at(control(pair[1]))
            local rightX, rightY = at(control(pair[2]))
            near(x, 0, "nameplate X starts its row")
            near(rightX, 204, "nameplate Y follows the X slider")
            near(y, rightY, "nameplate coordinate pairs stay together")
        end
    end
end
local baselinePanel = gui:Create("QuestieSettingsPanel")
dialog:Open("Questie", baselinePanel, "actual_general")
local oldAt = geometry(control("questCompleteSound").parent.children, 708)
local _, oldToggleY = oldAt(control("questCompleteSound"))
local _, oldPreviewY = oldAt(control("questCompleteSoundButton"))
assert(oldToggleY ~= oldPreviewY, "the source sound schema reproduces the wider-row wrapping regression")
dialog:Open("Questie", baselinePanel, "actual_icons")
oldAt = geometry(control("showNormalQuestsMap").parent.children, 708)
local _, oldLabelY = oldAt(control("showNormalQuestsLabel"))
local _, oldMapY = oldAt(control("showNormalQuestsMap"))
assert(oldLabelY ~= oldMapY, "the source matrix reproduces split category rows")
baselinePanel:ReleaseChildren()
equal(schema.args.actual_general.args.sound_options_group.args.soundLineBreak.width, 0.1,
    "source sound layout remains unchanged")
equal(schema.args.actual_icons.args.iconOverrides.args.iconTypeSlay.width, 0.796,
    "source override widths remain unchanged")
equal(schema.args.actual_nameplate.args.nameplate_options_group.args.nameplateDescSpacer.hidden, nil,
    "source nameplate spacer definitions remain unchanged")
equal(schema.args.actual_nameplate.args.nameplate_options_group.args.nameplateScale.width, 2.7,
    "source nameplate slider width remains unchanged")
groups = groups + 1

local settingsFrame = env.QuestieSettingsFrame
equal(settingsFrame:GetWidth(), 820, "standalone window uses the narrower presentation")
local journeyButton = settingsFrame.journeyButton
local sidebar = journeyButton:GetParent()
equal(sidebar:GetParent(), settingsFrame, "Journey belongs to the settings sidebar")
equal(sidebar.points.BOTTOMLEFT[1], 12, "sidebar keeps its lower window anchor")
equal(journeyButton.points.BOTTOMLEFT[1], 9, "Journey is inset inside the sidebar")
equal(journeyButton.points.BOTTOMLEFT[2], 12, "Journey remains at the sidebar bottom")
equal(journeyButton.mouseEnabled, true, "Journey button receives mouse input")
local settingsPanel
for _, widget in ipairs(s.widgets) do
    if widget.type == "QuestieSettingsPanel" and widget.frame:GetParent() == settingsFrame then settingsPanel = widget.frame end
end
assert(settingsPanel, "standalone settings use their own Ace container")
equal(settingsPanel:GetParent(), settingsFrame, "settings pane belongs to the window")
equal(settingsPanel.points.BOTTOMRIGHT[1], -24, "settings pane keeps its right window anchor")
equal(settingsPanel.points.BOTTOMRIGHT[2], 42, "settings pane remains above the footer")
engine:ShowFrame()
env.Questie.started = false
env.Questie.Print = function(_, message) s.waitMessage = message end
journeyButton:GetScript("OnClick")()
equal(s.waitMessage, "Please wait a moment for Questie to finish loading", "Journey waits for addon initialization")
assert(engine:IsShown() and not s.journeyBuilt, "startup clicks do not build Journey before its data is ready")
env.Questie.started = true
s.combat = true
engine:RefreshStates()
assert(journeyButton.disabled, "Journey is disabled in combat")
journeyButton:GetScript("OnClick")()
assert(engine:IsShown() and not s.journeyBuilt, "already-pending Journey clicks cannot run in combat")
s.combat = false
engine:RefreshStates()
assert(not journeyButton.disabled, "Journey becomes clickable after combat")
journeyButton:GetScript("OnClick")()
equal(s.journeyBuilt, 1, "Journey builds its tabs before selecting one")
equal(s.journeyTab, "journey", "settings opens the Journey tab")
assert(s.journey and not engine:IsShown(), "Journey button opens Journey and closes settings")
journeyButton:GetScript("OnClick")()
assert(s.journey, "a repeated Journey action does not close an already shown window")
s.journey = false
groups = groups + 1

local file = assert(io.open("Modules/QuestieEventHandler.lua", "r"))
local eventSource = file:read("*a"):gsub("\r\n", "\n")
file:close()
local combatSource = assert(eventSource:match(
    "(local journeyHiddenByCombat.-function _EventHandler:PlayerRegenEnabled%(%).-\nend)"))
local combatModule = loader:ImportModule("QuestieEventHandler")
local events = combatModule.private
env._settingsCombatEvents = combatModule
loader:ImportModule("QuestieTracker").HandleCombatStarted = noop
loader:ImportModule("QuestieTracker").HandleCombatEnded = noop
compile([[
    local QuestieEventHandler = _settingsCombatEvents
    local _EventHandler = QuestieEventHandler.private
    local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
    local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
]] .. combatSource, "production settings combat events")()
for _, priorJourney in ipairs({false, true}) do
    for _, closeDuringCombat in ipairs({false, true}) do
        engine:HideFrame(); s.journey = priorJourney
        s.combat = true
        events:PlayerRegenDisabled()
        engine:ShowFrame()
        if closeDuringCombat then engine:HideFrame() end
        s.combat = false
        events:PlayerRegenEnabled()
        equal(engine:IsShown(), not closeDuringCombat, "combat end preserves the user's new settings window state")
        assert(not s.journey, "selecting settings cancels restoration of an earlier Journey window")
    end
end
engine:HideFrame(); s.journey = true
events:PlayerRegenDisabled()
assert(not s.journey, "combat hides Journey")
events:PlayerRegenEnabled()
assert(s.journey, "ordinary combat restores the previously hidden Journey window")
equal(env.QuestieConfigFrame, nil, "combat handling does not create a legacy settings window")
groups = groups + 1

local hide = assert(controllerSource:match("(function QuestieOptions:HideFrame%(%).-\nend)"))
compile([[
    local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
    local QuestieOptionsEngine = QuestieLoader:ImportModule("QuestieOptionsEngine")
]] .. hide, "production settings hide")()
file = assert(io.open("Modules/Journey/QuestieJourney.lua", "r"))
local journeySource = file:read("*a"):gsub("\r\n", "\n")
file:close()
local toggle = assert(journeySource:match("(function QuestieJourney:ToggleJourneyWindow%(%).-\nend)"))
env.Questie.started, env.PlaySound = true, noop
env.QuestieJourneyFrame = env.CreateFrame("Frame")
env.QuestieJourneyFrame:Hide()
journey.IsShown = function() return env.QuestieJourneyFrame:IsShown() end
compile([[
    local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
    local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
    local l10n = QuestieLoader:ImportModule("l10n")
    local isWindowShown = false
    local _QuestieJourney = {HandleTabChange = function() return {} end}
]] .. toggle, "production Journey toggle")()
engine:ShowFrame()
journey:ToggleJourneyWindow()
assert(journey:IsShown() and not engine:IsShown(),
    "real Journey toggle closes settings before opening Journey")
journey:ToggleJourneyWindow()
equal(journey:IsShown(), false, "real Journey toggle can close Journey again")
groups = groups + 1
assert(not next(s.errors), s.errors[1])
print("Standalone options engine: " .. groups .. " groups passed (real Ace validation, callbacks, profiles and native frame lifecycle)")
