-- Run from the addon root with Lua 5.1 or 5.2+. Reuse the strict settings fixture,
-- but load the real AceGUI dropdown, pullout and menu items before the real engine.
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return source
end
local source = read("tools/tests/test_options_engine.lua")
local loadMarker = 'loadFile("Libs/AceGUI-3.0/widgets/AceGUIWidget-Button.lua")'
local first = assert(source:find(loadMarker, 1, true))
local nativeDropdowns = [[
for _, name in ipairs({"SetOrientation", "SetHitRectInsets", "SetThumbTexture", "SetToplevel", "SetBlendMode",
    "LockHighlight", "UnlockHighlight", "SetDrawLayer"}) do frameMethods[name] = noop end
function frameMethods:GetText() return self.text end
function frameMethods:GetChildren()
    local children = {}
    for _, child in ipairs(s.frames) do if child.parent == self then children[#children + 1] = child end end
    return env.unpack(children)
end
local createFrame = env.CreateFrame
env.CreateFrame = function(kind, name, parent, template)
    if kind == "BUTTON" then kind = "Button" end
    local frame = createFrame(kind, name, parent, template)
    if template == "UIDropDownMenuTemplate" then
        for _, suffix in ipairs({"Left", "Middle", "Right", "Text"}) do
            env.CreateFrame(suffix == "Text" and "FontString" or "Texture", name .. suffix, frame)
        end
        env.CreateFrame("Button", name .. "Button", frame)
    end
    return frame
end
env.CLOSE = "Close"
gui.SetFocus = function(_, widget) s.focus = widget end
gui.ClearFocus = function()
    local focus = s.focus
    s.focus = nil
    if focus then focus:ClearFocus() end
end
loadFile("Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown-Items.lua")
loadFile("Libs/AceGUI-3.0/widgets/AceGUIWidget-DropDown.lua")
]]
source = source:sub(1, first - 1) .. nativeDropdowns .. source:sub(first)
local initialize = assert(source:find("engine:Initialize(schema)", 1, true))
source = source:sub(1, initialize - 1) .. [[
local options = {}
for index = 1, 36 do options[index] = "Choice " .. index end
schema.args.controls.args.choice = {type = "select", name = "Choice", order = 1.5, values = options,
    get = function() return db.profile.lazyChoice or 2 end,
    set = function(_, value) db.profile.lazyChoice = value end}
schema.args.controls.args.radio = {type = "select", name = "Radio", style = "radio", hidden = true,
    values = options, get = function() return 1 end, set = noop}
local ordinaryConstructor = gui.WidgetRegistry.Dropdown
engine:Initialize(schema)
equal(gui.WidgetRegistry.Dropdown, ordinaryConstructor, "Questie never replaces the shared dropdown constructor")
local cloned = registry:GetOptionsTable("QuestieSettings")("dialog", "AceConfigDialog-3.0")
equal(cloned.args.controls.args.choice.dialogControl, "QuestieSettingsDropdown", "ordinary selections use the scoped lazy widget")
equal(cloned.args.controls.args.font.dialogControl, "LSM30_Font", "custom SharedMedia controls keep their widget")
equal(cloned.args.controls.args.flags.dialogControl, nil, "multiselect controls remain unchanged")
equal(cloned.args.controls.args.radio.dialogControl, nil, "radio selections remain unchanged")
equal(schema.args.controls.args.choice.dialogControl, nil, "source options remain unchanged")
local groups = 1
local function currentChoice()
    for index = #s.widgets, 1, -1 do
        local widget = s.widgets[index]
        local path = widget:GetUserData("path")
        if not widget.released and path and path[#path] == "choice" then return widget end
    end
    error("rendered choice control missing")
end
local function click(widget, cover)
    local frame = cover and widget.button_cover or widget.button
    frame:GetScript("OnClick")(frame, "LeftButton")
end
local function findItem(widget, value)
    for _, item in ipairs(widget.pullout.items) do
        if item:GetUserData("value") == value then return item end
    end
    error("menu item missing: " .. value)
end
engine:ShowFrame()
local choice = currentChoice()
equal(choice.type, "QuestieSettingsDropdown", "custom widget retains a separate pool type")
equal(#choice.pullout.items, 0, "closed dropdown holds no menu item frames")
equal(choice.text:GetText(), "Choice 2", "selected text is available before opening")
click(choice)
equal(#choice.pullout.items, 36, "first opening builds all choices")
assert(choice.open, "first opening still opens the real pullout")
assert(findItem(choice, 2):GetValue(), "opening marks the current selection")
click(choice)
equal(#choice.pullout.items, 0, "closing releases the built menu items")
equal(choice.text:GetText(), "Choice 2", "closing preserves selection text")
groups = groups + 1

options[2] = "Changed choice"
click(choice, true)
equal(findItem(choice, 2):GetText(), "Changed choice", "reopening reads current labels")
local item = findItem(choice, 3)
item.frame:GetScript("OnClick")(item.frame, "LeftButton")
equal(db.profile.lazyChoice, 3, "real menu selection dispatches the production setting callback")
assert(not next(s.errors), s.errors[1])
-- AceConfig can redraw synchronously or on its delayed refresh after the callback.
for _, frame in ipairs(s.frames) do
    local update = frame:GetScript("OnUpdate")
    if update then update(frame) end
end
choice = currentChoice()
equal(choice.text:GetText(), "Choice 3", "refreshed control displays its selected setting")
equal(#choice.pullout.items, 0, "redraw leaves unopened menus empty")
groups = groups + 1

db:SetProfile("Spare")
for _, frame in ipairs(s.frames) do
    local update = frame:GetScript("OnUpdate")
    if update then update(frame) end
end
choice = currentChoice()
equal(choice.text:GetText(), "Changed choice", "profile switch updates selected text without opening")
equal(#choice.pullout.items, 0, "profile switch does not eagerly build menus")
click(choice, true)
assert(findItem(choice, 2):GetValue(), "cover click opens the new profile's selected item")
choice.pullout:Close()
equal(#choice.pullout.items, 0, "programmatic menu close also releases choices")
groups = groups + 1

local custom = gui:Create("QuestieSettingsDropdown")
custom:SetList(options)
custom:SetValue(1)
equal(custom.text:GetText(), "Choice 1", "SetValue updates the selected label immediately while closed")
custom:SetDisabled(true)
click(custom)
equal(#custom.pullout.items, 0, "disabled controls do not build their menu")
assert(not custom.open, "disabled programmatic click cannot open a menu")
custom:SetDisabled(false)
click(custom, true)
equal(#custom.pullout.items, 36, "enabled cover click builds choices")
custom.pullout:Close()
gui:Release(custom)
-- Reacquire the same instance, as AceGUI's pool does, without constructing another wrapper.
custom.userdata, custom.callbacks, custom.released = {}, {}, nil
custom.events = custom.callbacks
custom:OnAcquire()
custom:SetList({[7] = "Reused choice"})
custom:SetValue(7)
equal(#custom.pullout.items, 0, "reacquired widget has no prior menu contents")
equal(custom.text:GetText(), "Reused choice", "reacquired widget has no prior label")
click(custom)
equal(#custom.pullout.items, 1, "reacquired menu uses only its replacement list")
local releasedPullout, releasedItem = custom.pullout, custom.pullout.items[1]
gui:Release(custom)
assert(releasedPullout.released and releasedItem.released, "releasing an open control releases its pullout and items")
equal(custom.pullout, nil, "released dropdown retains no pullout ownership")
equal(custom.questieListOrder, nil, "release clears deferred ordering")
equal(custom.questieItemType, nil, "release clears deferred item type")
groups = groups + 1

gui:RegisterWidgetType("TestDropdownItem", function()
    local item = gui.WidgetRegistry["Dropdown-Item-Toggle"]()
    item.type = "TestDropdownItem"
    return item
end, 1)
local ordered = gui:Create("QuestieSettingsDropdown")
ordered:SetList(options, {3, 1}, "TestDropdownItem")
ordered:SetValue(3)
equal(#ordered.pullout.items, 0, "custom item control stays deferred")
click(ordered)
equal(#ordered.pullout.items, 2, "explicit item order restricts the constructed list")
equal(ordered.pullout.items[1]:GetUserData("value"), 3, "explicit first item order is preserved")
equal(ordered.pullout.items[2]:GetUserData("value"), 1, "explicit second item order is preserved")
equal(ordered.pullout.items[1].type, "TestDropdownItem", "custom item type reaches the native list builder")
ordered:SetList({[3] = "Updated while open"}, {3}, "TestDropdownItem")
equal(#ordered.pullout.items, 1, "updating an open menu refreshes its items immediately")
equal(ordered.text:GetText(), "Updated while open", "list refresh immediately updates the selected label")
equal(ordered.pullout.items[1]:GetText(), "Updated while open", "open menu reads refreshed labels")
ordered.pullout:Close()
equal(#ordered.pullout.items, 0, "updated menu still releases its items on close")
click(ordered)
ordered:SetList(nil)
equal(ordered.text:GetText(), "", "removing a list clears its selected label")
equal(#ordered.pullout.items, 0, "removing an open list clears its items")
ordered.pullout:Close()
click(ordered)
equal(#ordered.pullout.items, 0, "missing list opens safely without items")
ordered.pullout:Close()
gui:Release(ordered)
groups = groups + 1

local foreign = gui:Create("Dropdown")
foreign:SetList({[1] = "Foreign first", [2] = "Foreign second"})
foreign:SetValue(2)
equal(foreign.type, "Dropdown", "foreign dropdown keeps its own pool type")
equal(#foreign.pullout.items, 2, "foreign dropdown retains eager construction")
equal(foreign.text:GetText(), "Foreign second", "foreign dropdown selection works after Questie releases widgets")
gui:Release(foreign)
engine:HideFrame()
assert(not next(s.errors), s.errors[1])
groups = groups + 1
print("Scoped lazy dropdown regressions passed (" .. groups .. " groups; real Ace dropdowns, pullouts, items and dialog)")
]]
local chunk
if setfenv then chunk = assert(loadstring(source, "@scoped-dropdown-fixture"))
else chunk = assert(load(source, "@scoped-dropdown-fixture", "t", _G)) end
chunk()
