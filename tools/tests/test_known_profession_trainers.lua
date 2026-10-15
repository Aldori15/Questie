-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the real profession cache, menu, and Wrath dropdown adapter together.
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G, env.tinsert = env, table.insert
local modules, hooks, timers, skills = {}, {}, {}, {}
local function module(name)
    if not modules[name] then modules[name] = {private = {}} end
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local chunk
    if setfenv then chunk = setfenv(assert(loadstring(source, "@" .. path)), env)
    else chunk = assert(load(source, "@" .. path, "t", env)) end
    chunk()
end
env.hooksecurefunc = function(name, fn) hooks[name] = fn end
env.AbandonSkill, env.UIDropDownMenu_AddButton = noop, noop
env.ExpandSkillHeader, env.IsSpellKnown = noop, function() return false end
env.GetNumSkillLines = function() return #skills end
env.GetSkillLineInfo = function(index)
    local skill = skills[index]
    if skill then return skill[1], false, nil, skill[2] end
end
env.UnitFactionGroup = function() return "Horde" end
env.Questie = {Debug = noop, Colorize = function(_, text) return text end,
    db = {profile = {townsfolkKnownProfessions = false, townsfolkConfig = {}},
        global = {professionTrainers = {}, townsfolk = {}}, char = {townsfolk = {}, vendorList = {}}}}
local profile = env.Questie.db.profile
local l10n = module("l10n")
l10n.translations = setmetatable({}, {__index = function() return {enUS = true} end})
setmetatable(l10n, {__call = function(_, text) return text end})
module("QuestieLib").AddonPath = "Interface\\AddOns\\Questie-335\\"
module("QuestieQuest").ResetAutoblacklistCategory = noop
module("AvailableQuests").CalculateAndDrawAll = noop
module("QuestieCorrections").questNPCBlacklist = {}
module("Townsfolk").IsVendorCategory = function() return false end
module("Townsfolk").EnsureVendorDataInitialized = noop
module("InstanceLocations").OnLogin = noop
local moonwells = false
module("Moonwell").ShowAll = function() moonwells = true end
module("Moonwell").HideAll = function() moonwells = false end
module("QuestieDB").QueryNPCSingle = function(id, field)
    return field == "name" and ("Trainer " .. id) or nil
end
local map, shown, draws = module("QuestieMap"), {}, 0
map._mapDrawQueue, map._minimapDrawQueue = {}, {}
map.ProcessQueue = noop
map.ShowNPC = function(_, id, _, _, _, _, _, key)
    shown[key] = shown[key] or {}
    shown[key][id] = true
    draws = draws + 1
end
map.UnloadManualFrames = function(_, id, key)
    if shown[key] then shown[key][id] = nil end
end
local function visible(key) return shown[key] and next(shown[key]) ~= nil or false end
env.QuestieCompat = {HBD = {}, C_Timer = {NewTicker = function(_, callback)
    local timer = {callback = callback, Cancel = function(self) self.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end}}
local function region()
    return {SetPoint = noop, SetTexture = noop, SetHeight = noop,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetDesaturated = function(self, value) self.desaturated = value end,
        SetAlpha = function(self, value) self.alpha = value end}
end
env.UIParent = {CreateFontString = region}
loadModule("Compat/UI.lua")
loadModule("Modules/QuestieProfessions.lua")
loadModule("Modules/QuestieMenu/QuestieMenu.lua")
local professions, menu = module("QuestieProfessions"), module("QuestieMenu")
professions:Init()
local keys = professions.professionKeys
local alchemy, mining, cooking, tailoring = keys.ALCHEMY, keys.MINING, keys.COOKING, keys.TAILORING
for index, key in ipairs({alchemy, mining, cooking, tailoring}) do
    env.Questie.db.global.professionTrainers[key] = {1000 + index}
end
local function setSkills(...)
    skills = {}
    for _, key in ipairs({...}) do skills[#skills + 1] = {professions:GetProfessionName(key), 1} end
    professions:Update()
end
local function find(entries, text)
    for _, info in ipairs(entries) do if info.text == text then return info end end
    error("missing menu entry " .. text)
end
local function findProfession(entries, key)
    return find(entries, professions:GetProfessionName(key))
end
env.UIDROPDOWNMENU_MAXLEVELS = 3
local function display(entries, level)
    local name = "DropDownList" .. level
    local list = env[name] or {GetName = function() return name end, IsShown = function() return true end}
    env[name] = list
    list.numButtons = 0
    for index, info in ipairs(entries) do
        local buttonName = name .. "Button" .. index
        local button = env[buttonName]
        if not button then
            button = {GetName = function() return buttonName end, CreateTexture = region,
                Enable = function(self) self.enabled = true end,
                Disable = function(self) self.enabled = false end,
                LockHighlight = noop, UnlockHighlight = noop}
            env[buttonName] = button
            env[buttonName .. "Check"] = region()
            env[buttonName .. "InvisibleButton"] = region()
        end
        -- Native 3.3.5 does not have an UnCheck region or SetEnabled/SetShown.
        if info.disabled or info.isTitle then button:Disable() else button:Enable() end
        list.numButtons = index
        hooks.UIDropDownMenu_AddButton(info, level)
    end
    return list
end

setSkills(alchemy, mining, cooking)
local entries = menu.buildProfessionMenu()
local known, a, m, c = entries[1], findProfession(entries, alchemy),
    findProfession(entries, mining), findProfession(entries, cooking)
equal(known.checked(), false, "default disabled")
a.func()
display(entries, 2)
known.func()
equal(a.checked(), true, "manual profession remains tracked")
equal(a.disabled, false, "manual profession remains yellow and clickable")
equal(m.disabled, true, "known mining is automatic")
equal(c.disabled, true, "known secondary profession is automatic")
assert(visible(alchemy) and visible(mining) and visible(cooking))
equal(profile.townsfolkConfig[mining], nil, "automatic selection never writes manual preference")
local miningButton
for i = 1, env.DropDownList2.numButtons do
    local button = env["DropDownList2Button" .. i]
    if button.questieProfessionMenu == m then miningButton = button end
end
assert(miningButton and not miningButton.enabled)
local check = env[miningButton:GetName() .. "Check"]
assert(check.shown and check.desaturated and check.alpha == 0.5)
m.func() -- Simulate a skin forwarding a click on a disabled row's icon.
equal(profile.townsfolkConfig[mining], nil, "forwarded locked click ignored")
a.func()
equal(a.disabled, true, "unchecking manual known profession changes to automatic")
assert(visible(alchemy))
known.func()
assert(not visible(alchemy) and not visible(mining) and not visible(cooking))
assert(miningButton.enabled and not check.shown and not check.desaturated and check.alpha == 1)
a.func()
known.func()
known.func()
assert(visible(alchemy) and not visible(mining), "master off preserves manual tracking")

known.func()
local before = draws
professions:Update()
equal(draws, before, "unchanged skills never redraw trainers")
setSkills(alchemy, mining, cooking, tailoring)
assert(visible(tailoring), "learning updates map immediately")
local tailoringEntries = findProfession(entries, tailoring).menuList
display(tailoringEntries, 3)
assert(tailoringEntries[1].checked() and tailoringEntries[1].disabled)
tailoringEntries[2].func()
assert(moonwells, "Moonwell toggle remains independent")
tailoringEntries[2].func()
assert(not moonwells)
local miningIndex
for index, data in ipairs(skills) do if data[1] == professions:GetProfessionName(mining) then miningIndex = index end end
hooks.AbandonSkill(miningIndex)
table.remove(skills, miningIndex)
assert(not visible(mining) and not m.disabled, "AbandonSkill immediately removes automatic trainers")
local _, newProfession = professions:Update()
equal(newProfession, false, "later skill refresh does not need a new profession")
setSkills(alchemy, cooking)
assert(not visible(tailoring), "cache refresh also detects removal without AbandonSkill")

-- Simulate login/profile refresh with automatic professions absent from manual settings.
menu:OnLogin(true)
assert(visible(alchemy) and visible(cooking) and not visible(mining))
profile.townsfolkKnownProfessions = false
menu.RefreshKnownProfessionTrainers()
assert(visible(alchemy) and not visible(cooking))

-- Use more IDs than the immediate batch so disabling must cancel pending work.
local ids = env.Questie.db.global.professionTrainers[mining]
for i = 1, 500 do ids[i] = 2000 + i end
setSkills(alchemy, mining, cooking)
known.func()
local pending = timers[#timers]
assert(pending and not pending.cancelled)
known.func()
assert(pending.cancelled and not visible(mining), "disabled profession cancels pending drawing")
for _, timer in ipairs(timers) do if not timer.cancelled then timer.callback() end end
assert(not visible(mining), "pending work cannot restore disabled trainers")

-- Switching characters with a shared profile replaces automatic selections only.
known.func()
setSkills(tailoring)
assert(visible(alchemy) and visible(tailoring) and not visible(mining) and not visible(cooking))

-- A native row reused by another addon must not keep Questie's gray check or line.
display({{text = "Known", questieProfession = true, checked = function() return true end, disabled = true}}, 1)
local reused = env.DropDownList1Button1
local reusedCheck = env.DropDownList1Button1Check
assert(reusedCheck.desaturated)
display({entries[2]}, 1)
assert(reused.questieSeparator and reused.questieSeparator.shown)
display({{text = "Other addon"}}, 1)
assert(not reused.questieProfessionMenu and not reusedCheck.desaturated and reusedCheck.alpha == 1)
assert(not reused.questieSeparator.shown)
print("PASS: known/manual professions, native live checks, learning/unlearning, Tailoring/Moonwell, login, ticker cancellation, shared profiles, pooled rows")
