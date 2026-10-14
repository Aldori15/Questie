-- Run from the addon root with Lua 5.1 or 5.2+.
-- Native keyboard/clipboard behavior still requires in-game verification.
local function equal(a, b, label) assert(a == b, label) end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules, locale = {}, 'enUS'
env.QuestieLoader = {
    CreateModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {}; return modules[name] end,
}
local l10n = env.QuestieLoader:ImportModule('l10n')
l10n.GetUILocale = function() return locale end
setmetatable(l10n, {__call = function(_, text) return text end})
env.QuestieCompat = {LibUIDropDownMenu = {Create_UIDropDownMenu = function() return {} end}}
env.Questie, env.StaticPopupDialogs = {}, {}
env.UIParent, env.UISpecialFrames, env.CLOSE, env.tinsert = {}, {}, 'Close', table.insert
local function widget()
    local obj = {scripts = {}}
    for _, method in ipairs({'SetPoint', 'SetFrameStrata', 'EnableMouse', 'SetClampedToScreen',
        'SetFontObject', 'SetAutoFocus', 'SetMaxLetters', 'SetBackdropColor'}) do
        obj[method] = function() end
    end
    function obj:SetScript(event, callback) self.scripts[event] = callback end
    function obj:Hide()
        local shown = self.shown
        self.shown = false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function obj:Show() self.shown = true end
    function obj:IsShown() return self.shown end
    function obj:SetWidth(width) self.width = width end
    function obj:SetHeight(height) self.height = height end
    function obj:SetSize(width, height) self.width, self.height = width, height end
    function obj:SetBackdrop(backdrop) self.backdrop = backdrop end
    function obj:SetTextInsets(left, right) self.leftInset, self.rightInset = left, right end
    function obj:SetText(value) self.text = value end
    function obj:GetStringWidth() return #self.text * 8 end
    function obj:GetStringHeight() return 14 end
    function obj:SetFocus() self.focused = true end
    function obj:ClearFocus() self.focused = false end
    function obj:SetCursorPosition(value) self.cursor = value end
    function obj:HighlightText() self.highlighted = true end
    function obj:CreateFontString() return widget() end
    return obj
end
env.CreateFrame = function(kind, name, parent)
    local obj = widget()
    obj.kind, obj.parent = kind, parent
    if name then env[name] = obj end
    return obj
end
local file = assert(io.open('Modules/Tracker/TrackerMenu.lua', 'r'))
local source = file:read('*a') .. '\nreturn ShowWowheadURL'
file:close()
local show
if setfenv then show = setfenv(assert(loadstring(source)), env)()
else show = assert(load(source, '@Modules/Tracker/TrackerMenu.lua', 't', env))() end
local function popup() return env.QuestieWowheadURLDialog end
for _, entry in ipairs({{'quest', 8345}, {'achievement', 42}}) do
    local kind, id = entry[1], entry[2]
    show(kind, id, 'Name')
    local p, box = popup(), popup().editBox
    equal(box.text, 'https://wowhead.com/wotlk/' .. kind .. '=' .. id, 'full Wrath URL')
    assert(box.width - box.leftInset - box.rightInset >= #box.text * 8, 'entire URL fits')
    assert(box.backdrop.edgeFile and box.backdrop.tile, 'scalable field border')
    equal(box.focused, true, 'URL focused')
    equal(box.highlighted, true, 'URL selected')
    equal(box.cursor, 0, 'viewport starts at beginning')
    for _, event in ipairs({'OnEscapePressed', 'OnEnterPressed'}) do
        show(kind, id, 'Name')
        box.scripts[event](box)
        equal(p.shown, false, 'manual close hides dialog')
        equal(box.focused, false, 'closing clears focus')
    end
end
locale = 'deDE'
show('achievement', 123456, 'Name')
equal(popup().editBox.text, 'https://wowhead.com/wotlk/de/achievement=123456', 'localized URL')
equal(#env.UISpecialFrames, 1, 'Escape registration is not duplicated')
print('WoWHead dialog regressions passed')
