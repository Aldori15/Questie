-- Run from the addon root with Lua 5.1 or 5.2+. Exercise the owning Wrath module without compatibility overrides.
local unpackValues = unpack or table.unpack
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function harness(enabled)
    local env = setmetatable({}, {__index = _G})
    local modules, created, children, tickers, delayed, units = {}, {}, {}, {}, {}, {}
    local hooks, scans, forbidGUID = 0, 0, false
    local function module(name) modules[name] = modules[name] or {private = {}}; return modules[name] end
    local function frame(parent)
        local f = {parent = parent, shown = true, hooks = {}, regions = {}, left = 0, centerY = 0, scale = 1}
        function f:GetParent() return self.parent end
        function f:SetParent(value) self.parent = value end
        function f:IsShown() return self.shown end
        function f:Show()
            local changed = not self.shown; self.shown = true
            if changed then for _, callback in ipairs(self.hooks.OnShow or {}) do callback(self) end end
        end
        function f:Hide()
            local changed = self.shown; self.shown = false
            if changed then for _, callback in ipairs(self.hooks.OnHide or {}) do callback(self) end end
        end
        function f:HookScript(event, callback)
            self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], callback)
        end
        function f:GetRegions() return unpackValues(self.regions) end
        function f:GetObjectType() return "Texture" end
        function f:SetTexture(value) self.texture = value end
        function f:GetTexture() return self.texture end
        function f:SetText(value) self.text = value end
        function f:GetText() return self.text end
        function f:SetPoint(...) self.point = {...} end
        function f:SetAllPoints(value) self.allPoints = value end
        function f:SetWidth(value) self.width = value end
        function f:SetHeight(value) self.height = value end
        function f:SetFrameLevel(value) self.level = value end
        function f:SetFont(path, size) self.font, self.fontSize = path, size end
        function f:GetLeft() return self.left end
        function f:GetCenter() return self.left, self.centerY end
        function f:GetEffectiveScale() return self.scale end
        f.EnableMouse, f.SetFrameStrata, f.ClearAllPoints = noop, noop, noop
        f.SetJustifyH, f.SetShadowOffset, f.SetWordWrap, f.SetTextHeight = noop, noop, noop, noop
        function f:CreateTexture() return frame(self) end
        function f:CreateFontString() return frame(self) end
        return f
    end
    env.CreateFrame = function(_, _, parent)
        local f = frame(parent); created[#created + 1] = f; return f
    end
    env.WorldFrame, env.TargetFrame = frame(), frame()
    function env.WorldFrame:GetNumChildren() scans = scans + 1; return #children end
    function env.WorldFrame:GetChildren() return unpackValues(children) end
    env.UnitGUID = function(unit) assert(not forbidGUID, "Removal must not query unit GUIDs"); return units[unit] and units[unit].guid end
    env.UnitName = function(unit) return units[unit] and units[unit].name end
    env.strsplit = function(_, value)
        local parts = {}; for part in value:gmatch("[^-]+") do parts[#parts + 1] = part end
        return unpackValues(parts)
    end
    env.tremove = table.remove
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    env.Questie = {Debug = noop, ICON_TYPE_SLAY = 1, icons = {slay = "slay-icon"}, db = {profile = {
        nameplateEnabled = enabled, nameplateShowObjectiveText = true, nameplateObjectiveTextTargetOnly = false,
        nameplateScale = 1, nameplateTargetFrameEnabled = true, nameplateTargetFrameScale = 1,
        nameplateTargetFrameX = 0, nameplateTargetFrameY = 0}}}
    env.QuestieCompat = {UnitGUID = function(unit)
        local data = units[unit]; if data then return "Creature-0-0-0-0-" .. data.id .. "-00000001" end
    end, C_Timer = {After = function(_, callback) delayed[#delayed + 1] = callback end,
        NewTicker = function(delay, callback) equal(delay, 0.25, "Existing discovery interval"); tickers[#tickers + 1] = callback end}}
    env.hooksecurefunc = function(owner, key, callback)
        hooks = hooks + 1
        local original = owner[key]
        owner[key] = function(...) original(...); callback(...) end
    end
    module("QuestieDB").QueryNPCSingle = function(id) return id == 101 and "Wolf" or "Boar" end
    module("QuestieLib").GetObjectiveDescription = function(_, objective) return objective.Description end
    module("QuestieLib").GetRGBForObjective = function() return "" end
    local tooltips = module("QuestieTooltips"); tooltips.lookupByKey = {}
    function tooltips:RegisterObjectiveTooltip(_, key, objective) self.lookupByKey[key] = {{objective = objective}} end
    if setfenv then setfenv(assert(loadfile("Modules/QuestieNameplate.lua")), env)()
    else assert(loadfile("Modules/QuestieNameplate.lua", "t", env))() end
    local h = {module = module("QuestieNameplate"), profile = env.Questie.db.profile, tooltips = tooltips, targetFrame = env.TargetFrame}
    function h:register(id)
        local objective = {Icon = 1, Description = "Beasts slain", Collected = 1, Needed = 8, Update = noop}
        tooltips:RegisterObjectiveTooltip(1, "m_" .. id, objective)
        return objective
    end
    function h:plate(name, kind, shown)
        local plate, nameRegion = frame(env.WorldFrame), frame()
        plate.shown, nameRegion.text = shown ~= false, name
        for index = 1, 7 do plate.regions[index] = frame() end
        plate.regions[2].texture = "Interface\\Tooltips\\Nameplate-Border"
        plate.regions[7] = nameRegion
        if kind then plate[kind] = {} end
        children[#children + 1] = plate
        return plate, nameRegion
    end
    function h:icon(plate)
        for _, f in ipairs(created) do
            if f.Icon and f.parent == plate and f:IsShown() then return f end
        end
    end
    function h:iconCount()
        local count = 0; for _, f in ipairs(created) do if f.Icon then count = count + 1 end end; return count
    end
    function h:tick() for _, callback in ipairs(tickers) do callback() end end
    function h:counts() return #tickers, hooks, scans end
    function h:unit(token, guid, id, name) units[token] = guid and {guid = guid, id = id, name = name} or nil end
    function h:noGUID(value) forbidGUID = value end
    function h:flush() for _, callback in ipairs(delayed) do callback() end; delayed = {} end
    return h
end

local h = harness(true)
local update = h.module.UpdateNameplate
h.module:Initialize(); h.module:Initialize()
local timers, hooks, scans = h:counts()
equal(timers, 1, "Initialization owns one scanner"); equal(hooks, 1, "Initialization hooks tooltip registration once")
equal(update, h.module.UpdateNameplate, "Initialization does not replace public update methods")
h:tick(); _, _, scans = h:counts(); equal(scans, 0, "No discovery scan without quest NPCs")
local objective = h:register(101)
local plate = h:plate("Wolf")
h:tick()
local icon = assert(h:icon(plate), "Visible native plate receives an icon")
equal(icon.Icon.texture, "slay-icon", "Initial objective icon")
equal(icon.Text.text, "[Beasts slain: 1/8]|r", "Initial objective text")
objective.Collected = 2; h.module:UpdateNameplate()
equal(icon.Text.text, "[Beasts slain: 2/8]|r", "Live objective progress")
local allocated = h:iconCount()
plate:Hide(); h.module:UpdateNameplate()
equal(h:icon(plate), nil, "Hidden plates stay released during updates")
equal(h:iconCount(), allocated, "Hidden updates allocate no replacement icons")
plate:Show()
equal(h:icon(plate), icon, "Returning plate reuses its icon")
equal(icon.Icon.texture, "slay-icon", "Reuse restores a texture cleared during removal")
equal(#plate.hooks.OnShow, 1, "One creation hook per plate")
equal(#plate.hooks.OnHide, 1, "One removal hook per plate")
h.profile.nameplateEnabled = false; h:noGUID(true); plate:Hide(); h:noGUID(false)
equal(h:icon(plate), nil, "Hide cleans up even after icons are disabled")
plate:Show(); equal(h:icon(plate), nil, "Disabled icons are not recreated on show")
h.profile.nameplateEnabled = true; h.module:UpdateNameplate()
equal(h:icon(plate), icon, "Enabled updates reuse released frames")
objective.Completed = true; h.module:UpdateNameplate()
equal(h:icon(plate), nil, "Completed objectives release icons")
objective.Completed = false; h.module:UpdateNameplate()
equal(h:icon(plate), icon, "Active objectives recover without another scanner pass")
h.tooltips.lookupByKey.m_101 = nil; h.module:UpdateNameplate()
equal(h:icon(plate), nil, "Removed tooltip releases its icon")
objective = h:register(101); h.module:UpdateNameplate()
h.module:HideCurrentFrames(); equal(h:icon(plate), nil, "Public hide clears actual frame-based icons")
h.module:UpdateNameplate(); equal(h:icon(plate), icon, "Updates recover after public hide")
h.profile.nameplateShowObjectiveText = false; h.module:UpdateNameplate()
equal(icon.lastText, nil, "Text setting hides progress"); equal(icon.TextFrame:IsShown(), false, "Text frame is hidden")
h.profile.nameplateEnabled = false; h.module:UpdateNameplate()
equal(h:icon(plate), nil, "Disabling then updating releases visible icons")

-- Preserve supported addon markers and attach hooks only once when new children appear.
h = harness(true); h.module:Initialize(); h:register(101)
local plates = {}
for _, marker in ipairs({"UnitFrame", "extended", "aloftData", "kui"}) do plates[#plates + 1] = h:plate("Wolf", marker) end
h:tick()
for _, p in ipairs(plates) do assert(h:icon(p), "Addon nameplate marker retained") end
h:plate("Other unit"); h:tick()
for _, p in ipairs(plates) do equal(#p.hooks.OnHide, 1, "Rescanning does not duplicate hooks") end
allocated = h:iconCount(); h.module:HideCurrentFrames(); h.module:UpdateNameplate()
equal(h:iconCount(), allocated, "Bulk hide returns all icons to the pool")

-- Frame reuse changes creature identity without leaving the old quest texture/text.
h:register(102); local p = plates[1]; p:Hide(); p.regions[7]:SetText("Boar"); p:Show()
assert(h:icon(p), "Recycled native plate uses its new name")
p:Hide(); p.regions[7]:SetText("Other unit"); p:Show()
equal(h:icon(p), nil, "A recycled non-quest plate retains no quest icon")

-- Native Wrath falls back to unique names; addon unit metadata uses raw, spawn-specific GUIDs.
h = harness(true); h.module:Initialize(); h:register(101); h.profile.nameplateObjectiveTextTargetOnly = true
local first, second = h:plate("Wolf"), h:plate("Wolf")
h:unit("target", "0xF130000065000002", 101, "Wolf"); h:tick(); h.module:UpdateNameplate()
equal(h:icon(first).lastText, nil, "Duplicate native names do not guess the target")
equal(h:icon(second).lastText, nil, "Duplicate names do not duplicate target text")
second:Hide(); h.module:UpdateNameplate()
assert(h:icon(first).lastText, "A single matching name retains target-only text")
first.unit, second.unit = "plate1", "plate2"
h:unit("plate1", "0xF130000065000001", 101, "Wolf")
h:unit("plate2", "0xF130000065000002", 101, "Wolf")
second:Show(); h.module:UpdateNameplate()
equal(h:icon(first).lastText, nil, "Same NPC ID with different spawn GUID is not the target")
assert(h:icon(second).lastText, "Exact raw GUID identifies the target")
second.UnitFrame = {Health = h.targetFrame}
h.profile.nameplateScale, h.profile.nameplateTextScale = 1.5, 2
h.module:RedrawIcons()
local targetIcon = h:icon(second)
equal(targetIcon.point[2], second.UnitFrame.Health, "Target text retains addon health-bar anchoring")
equal(targetIcon.Icon.width, 24, "Icon scaling retained")
equal(targetIcon.Text.fontSize, 20, "Text scaling retained")
h:unit("target", nil); h.module:UpdateNameplate()
equal(targetIcon.lastText, nil, "Clearing target removes target-only text")
h:flush()

-- Target-frame objectives remain independent of world nameplate enablement.
h = harness(false); h.module:Initialize(); h:register(101)
timers, hooks = h:counts(); equal(timers, 0, "Disabled startup has no scanner"); equal(hooks, 0, "Disabled startup has no discovery hook")
h:unit("target", "0xF130000065000001", 101, "Wolf"); h.module:DrawTargetFrame()
local targetFrameIcon = assert(h:icon(h.targetFrame), "Target-frame icon works with world nameplates disabled")
equal(targetFrameIcon.Icon.texture, "slay-icon", "Target-frame texture retained")
h.profile.nameplateTargetFrameScale = 2; h.module:RedrawFrameIcon()
equal(targetFrameIcon.width, 32, "Target-frame scaling retained")
h.module:HideCurrentTargetFrame(); equal(h:icon(h.targetFrame), nil, "Target-frame cleanup retained")

print("Wrath nameplates: discovery, lifecycle, reuse, cleanup, progress, addon frames, target matching and layout passed")
