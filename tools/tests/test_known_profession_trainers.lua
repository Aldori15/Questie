-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the real profession cache, menu, and Wrath dropdown adapter together.
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G, env.tinsert = env, table.insert
local modules, hooks, timers, skills = {}, {}, {}, {}
local skillsCollapsed, expansions, skillResets, questRedraws = true, 0, 0, 0
local skillEvent
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
env.ExpandSkillHeader = function(index)
    equal(index, 0, "all skill headers expand together")
    expansions = expansions + 1
    skillsCollapsed = false
    if skillEvent then skillEvent("SKILL_LINES_CHANGED") end
end
env.IsSpellKnown = function() return false end
env.GetNumSkillLines = function() return skillsCollapsed and 1 or #skills + 1 end
env.GetSkillLineInfo = function(index)
    if index == 1 then return "Professions", true, not skillsCollapsed end
    local skill = not skillsCollapsed and skills[index - 1]
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
module("QuestieQuest").ResetAutoblacklistCategory = function(category)
    equal(category, "skill", "profession changes invalidate skill eligibility")
    skillResets = skillResets + 1
end
module("AvailableQuests").CalculateAndDrawAll = function() questRedraws = questRedraws + 1 end
module("QuestieCorrections").questNPCBlacklist = {}
module("Townsfolk").IsVendorCategory = function() return false end
module("Townsfolk").EnsureVendorDataInitialized = noop
module("InstanceLocations").OnLogin = noop
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
map.ShowObject = function(_, id, icon, _, title, body, persistent, key)
    shown[key] = shown[key] or {}
    shown[key][id] = {icon = icon, title = title, body = body, persistent = persistent}
end
map.ResetManualFrames = function(_, key) shown[key] = nil end
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
loadModule("Modules/Map/ProfessionStations.lua")
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
    local list = env[name] or {GetName = function() return name end,
        IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end}
    env[name] = list
    list:Show()
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
equal(expansions, 1, "collapsed profession header is expanded once")
local initialResets = skillResets
local initialUpdate, initialLearned = professions:Update()
assert(not initialUpdate and not initialLearned, "unchanged profession snapshot reports no change")
equal(skillResets, initialResets, "unchanged profession snapshot preserves eligibility caches")
equal(expansions, 1, "expanded skill headers do not expand again")
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
local tailoringEntry = findProfession(entries, tailoring)
assert(tailoringEntry.checked() and tailoringEntry.disabled)
assert(not tailoringEntry.hasArrow and not tailoringEntry.menuList, "Tailoring is a direct trainer toggle")
local moonwellEntry = find(menu.buildTownsfolkMenu(), "Moonwell")
moonwellEntry.func()
assert(visible("Moonwell"), "Moonwell toggle remains independent")
moonwellEntry.func()
assert(not visible("Moonwell"))
local miningIndex
for index, data in ipairs(skills) do if data[1] == professions:GetProfessionName(mining) then miningIndex = index + 1 end end
local resetsBeforeAbandon, redrawsBeforeAbandon = skillResets, questRedraws
hooks.AbandonSkill(miningIndex)
table.remove(skills, miningIndex - 1)
assert(not visible(mining) and not m.disabled, "AbandonSkill immediately removes automatic trainers")
equal(skillResets, resetsBeforeAbandon + 1, "AbandonSkill immediately resets skill eligibility")
equal(questRedraws, redrawsBeforeAbandon + 1, "AbandonSkill immediately redraws available quests")
local _, newProfession = professions:Update()
equal(newProfession, false, "later skill refresh does not need a new profession")
equal(skillResets, resetsBeforeAbandon + 1, "later refresh does not invalidate an already removed profession twice")
local resetsBeforeRemoval = skillResets
table.remove(skills, #skills) -- Tailoring is removed outside the native AbandonSkill API.
local removed, newlyLearned = professions:Update()
equal(removed, true, "loss-only snapshot reports an availability update")
equal(newlyLearned, false, "profession loss is not a newly learned profession")
equal(skillResets, resetsBeforeRemoval + 1, "external profession removal resets skill eligibility")
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

-- Exercise the production registration and handler through the real combined AceBucket.
profile.townsfolkKnownProfessions = false
setSkills(alchemy, mining)
local clock, scheduled, listeners, errors = 0, {}, {}, {}
env.geterrorhandler = function() return function(message) errors[#errors + 1] = message end end
env.loadstring = function(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env) end
    return assert(load(source, name, "t", env))
end
loadModule("Libs/LibStub/LibStub.lua")
local aceEvent = env.LibStub:NewLibrary("AceEvent-3.0", 1)
aceEvent.RegisterEvent = function(owner, event, method)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], {owner = owner, method = method})
end
local aceTimer = env.LibStub:NewLibrary("AceTimer-3.0", 1)
aceTimer.ScheduleTimer = function(_, callback, delay, argument)
    equal(delay, 2, "both skill events retain the existing two-second bucket")
    local timer = {due = clock + delay, callback = callback, argument = argument}
    scheduled[#scheduled + 1] = timer
    return timer
end
loadModule("Libs/AceBucket-3.0/AceBucket-3.0.lua")
env.Questie.RegisterBucketEvent = env.LibStub("AceBucket-3.0").RegisterBucketEvent
env.ERR_QUEST_ACCEPTED_S, env.ERR_QUEST_COMPLETE_S = "Quest accepted: %s", "Quest complete: %s"
local trackerUpdates = 0
module("QuestieTracker").Update = function() trackerUpdates = trackerUpdates + 1 end
module("QuestieCombatQueue").Queue = function(_, callback) callback() end
loadModule("Modules/QuestieEventHandler.lua")
env._EventHandler = module("QuestieEventHandler").private
local file = assert(io.open("Modules/QuestieEventHandler.lua", "r"))
local eventSource = file:read("*a")
file:close()
local registrations = 0
for arguments in eventSource:gmatch("Questie:RegisterBucketEvent(%b())") do
    if arguments:find("_EventHandler.ChatMsgSkill", 1, true) then
        env.loadstring("Questie:RegisterBucketEvent" .. arguments, "production skill registration")()
        registrations = registrations + 1
    end
end
equal(registrations, 1, "both skill events share one production bucket registration")
assert(listeners.CHAT_MSG_SKILL and listeners.SKILL_LINES_CHANGED, "native skill-line changes must be registered")
equal(listeners.CHAT_MSG_SKILL[1].owner, listeners.SKILL_LINES_CHANGED[1].owner, "both events use the same bucket")
skillEvent = function(event)
    for _, listener in ipairs(listeners[event] or {}) do
        listener.owner[listener.method](listener.owner, event)
    end
end
local function advance(seconds)
    local target = clock + seconds
    for _ = 1, 20 do
        local first
        for i, timer in ipairs(scheduled) do
            if timer.due <= target and (not first or timer.due < scheduled[first].due) then first = i end
        end
        if not first then clock = target; return end
        local timer = table.remove(scheduled, first)
        clock = timer.due
        timer.callback(timer.argument)
        assert(not next(errors), errors[1])
    end
    error("skill event timers did not settle")
end
local update, updates = professions.Update, 0
professions.Update = function(self, ...)
    updates = updates + 1
    return update(self, ...)
end
local resets, redraws, expanded = skillResets, questRedraws, expansions
skillEvent("CHAT_MSG_SKILL"); skillEvent("SKILL_LINES_CHANGED"); skillEvent("CHAT_MSG_SKILL")
advance(1)
equal(updates, 0, "skill bursts wait for their bucket")
advance(5)
equal(updates, 1, "mixed skill event burst scans professions once")
equal(trackerUpdates, 1, "mixed event burst retains skill achievement tracker refresh")
equal(skillResets, resets, "unchanged event snapshot does not reset skill eligibility")
equal(questRedraws, redraws, "unchanged event snapshot does not redraw quests")
equal(expansions, expanded, "unchanged event snapshot leaves expanded headers alone")
equal(#scheduled, 0, "unchanged skill event bucket settles")

skillsCollapsed = true
skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(expansions, expanded + 1, "collapsed header expands once during the native event refresh")
equal(updates, 2, "header expansion event does not create repeating profession scans")
equal(#scheduled, 0, "header expansion feedback settles")
equal(questRedraws, redraws, "header expansion alone does not redraw quests")

table.remove(skills, 2) -- A server-side removal bypasses AbandonSkill and chat text.
skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(skillResets, resets + 1, "skill-line-only removal invalidates availability")
equal(questRedraws, redraws + 1, "skill-line-only removal redraws available quests")
equal(professions:HasProfessionAndSkillLevel({mining, 1}), false, "native removal clears the profession cache")

skills[1][2] = 5
skillEvent("CHAT_MSG_SKILL"); skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(questRedraws, redraws + 2, "combined events preserve five-level skill progression refresh")
skills[#skills + 1] = {professions:GetProfessionName(cooking), 1}
skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(skillResets, resets + 2, "learning through a skill-line-only event resets eligibility")
equal(questRedraws, redraws + 3, "learning through a skill-line-only event redraws quests")
equal(professions:HasProfessionAndSkillLevel({cooking, 1}), true, "skill-line-only learning updates the cache")
equal(#scheduled, 0, "learning event bucket settles")

-- Use the real menu builders and native adapter; native globals own open state.
local menuBuilds, menuCloses, lastMenu = 0, 0
env.CreateFrame = function(_, name)
    return {GetName = function() return name end}
end
env.CloseDropDownMenus = function(level)
    menuCloses = menuCloses + 1
    for index = level or 1, env.UIDROPDOWNMENU_MAXLEVELS do
        if env["DropDownList" .. index] then env["DropDownList" .. index]:Hide() end
    end
    if not level or level == 1 then env.UIDROPDOWNMENU_OPEN_MENU = nil end
end
env.EasyMenu = function(items, frame)
    menuBuilds, lastMenu = menuBuilds + 1, items
    for index = 1, env.UIDROPDOWNMENU_MAXLEVELS do
        if env["DropDownList" .. index] then env["DropDownList" .. index]:Hide() end
    end
    env.UIDROPDOWNMENU_OPEN_MENU = frame
    display(items, 1)
end
env.CloseDropDownMenus()
for _, case in ipairs({{"ShowTownsfolk", "menuTowns"}, {"ShowProfessions", "menuProfs"}, {"ShowVendors", "menuVendors"}}) do
    local show, key = case[1], case[2]
    local before = menuBuilds
    menu[show](menu, 1)
    equal(menuBuilds, before + 1, "first click builds " .. show)
    equal(env.UIDROPDOWNMENU_OPEN_MENU, menu[key], "native state identifies " .. show)
    assert(env.DropDownList1:IsShown(), "first click opens " .. show)
    display({{text = "Nested menu"}}, 2)
    menu[show](menu, 1)
    equal(menuBuilds, before + 1, "second click closes before reinitializing " .. show)
    assert(not env.DropDownList1:IsShown() and not env.DropDownList2:IsShown(), "second click closes all submenu levels")
    menu[show](menu, 1)
    equal(menuBuilds, before + 2, "third click reopens " .. show)
    assert(env.DropDownList1:IsShown(), "reopened flyout is visible")
    lastMenu[#lastMenu].func() -- Native dropdown code closes after the Cancel action.
    env.CloseDropDownMenus()
    menu[show](menu, 1)
    equal(menuBuilds, before + 3, "cancelling does not strand toggle state for " .. show)
    env.DropDownList1:Hide() -- Native auto-hide may retain OPEN_MENU temporarily.
    menu[show](menu, 1)
    equal(menuBuilds, before + 4, "an auto-hidden menu can reopen despite a stale native owner")
    assert(env.DropDownList1:IsShown(), "auto-hidden flyout opens again")
    env.CloseDropDownMenus()
end
menu:ShowTownsfolk(1)
local beforeSwitch = menuBuilds
menu:ShowProfessions(1)
equal(menuBuilds, beforeSwitch + 1, "a different flyout button switches menus")
equal(env.UIDROPDOWNMENU_OPEN_MENU, menu.menuProfs, "switching uses the new native menu owner")
menu:ShowVendors(1)
equal(env.UIDROPDOWNMENU_OPEN_MENU, menu.menuVendors, "vendor button also switches an existing flyout")
assert(env.DropDownList1:IsShown() and menuCloses > 0, "switching never leaves the requested flyout hidden")

setSkills(alchemy, keys.ENGINEERING, tailoring)
local townsfolk = menu.buildTownsfolkMenu()
local stations = {
    {"Anvil", 141840, "INV_Hammer_20"},
    {"Forge", 141841, "Spell_Fire_FlameBlades"},
    {"Alchemy Lab", 183848, "Trade_Alchemy"},
    {"Moonwell", 20806, "inv_fabric_moonrag_01.blp"},
}
for _, station in ipairs(stations) do
    local key, id, texture = station[1], station[2], "Interface\\Icons\\" .. station[3]
    local row = find(townsfolk, key)
    equal(row.icon, texture, key .. " menu texture")
    row.func()
    local pin = assert(shown[key][id], key .. " draws the AzerothCore object")
    equal(pin.icon, texture, key .. " pin texture")
    equal(pin.title, key, key .. " pin title")
    equal(pin.persistent, true, key .. " pin is controlled by its toggle")
    equal(pin.body == nil, key == "Moonwell", key .. " default object ID tooltip")
end

skills = {{professions:GetProfessionName(mining), 1}}
skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(visible("Anvil"), false, "unlearning engineering hides anvils")
equal(visible("Alchemy Lab"), false, "unlearning alchemy hides labs")
equal(profile.townsfolkConfig["Alchemy Lab"], true, "unlearning retains the saved setting")
equal(visible("Moonwell"), false, "unlearning tailoring hides moonwells")
equal(profile.townsfolkConfig["Moonwell"], true, "unlearning retains the old Moonwell preference")
equal(visible("Forge"), true, "mining keeps forges visible")
townsfolk = menu.buildTownsfolkMenu()
for _, row in ipairs(townsfolk) do
    assert(row.text ~= "Anvil" and row.text ~= "Alchemy Lab" and row.text ~= "Moonwell",
        "unavailable station rows are hidden")
end
find(townsfolk, "Forge").func()
equal(visible("Forge"), false, "unchecking a station removes its pins")

skills = {{professions:GetProfessionName(alchemy), 1}, {professions:GetProfessionName(tailoring), 1}}
skillEvent("SKILL_LINES_CHANGED")
advance(6)
equal(visible("Alchemy Lab"), true, "learning alchemy restores the saved pins")
equal(visible("Moonwell"), true, "learning tailoring restores the saved moonwell pins")
equal(find(menu.buildTownsfolkMenu(), "Moonwell").checked(), true, "Moonwell is checked in Townsfolk")
equal(visible("Forge"), false, "the forge stays unchecked")
print("PASS: profession trainers and stations, learning and unlearning, shared skill-event bucket, progression and cache invalidation")

do
    local key = "Portal Trainer"
    local db = module("QuestieDB")
    local standing = {[934] = 3, [935] = 4, [1090] = 4}
    module("QuestieReputation").GetFactionStandingId = function(_, id) return standing[id] end
    env.Questie.db.char.townsfolk[key] = {19340, 20791, 29156, 2485}
    local xs = {[19340] = 1, [20791] = 2, [29156] = 3, [2485] = 0.5}
    db.QueryNPCSingle = function(id, field)
        if field == "friendlyToFaction" then return id == 2485 and "A" or "" end
        if field == "name" then return tostring(id) end
        if field == "spawns" then return {[12] = {{xs[id], 1}}} end
    end
    find(menu.buildTownsfolkMenu(), key).func()
    assert(shown[key][20791] and shown[key][29156], "neutral reputation allows portal trainers")
    assert(not shown[key][19340] and not shown[key][2485], "unfriendly and opposing faction trainers stay hidden")

    env.TomTom = {AddWaypoint = noop}
    env.Questie.Print = noop
    env.QuestieCompat.GetCurrentPlayerMinimapWorldPosition = function() return 0, 0, 1 end
    env.QuestieCompat.HBD.GetWorldCoordinatesFromZone = function(_, x, y) return x, y, 1 end
    env.QuestieCompat.HBD.GetWorldDistance = function(_, _, px, py, nx, ny) return (px - nx)^2 + (py - ny)^2 end
    module("ZoneDB").GetUiMapIdByAreaId = function(_, id) return id end
    module("Phasing").IsSpawnDataVisible = function() return true end
    local waypoint
    module("TrackerUtils").SetTomTomTarget = function(_, title) waypoint = title end
    menu.FindNearest(key, key)
    assert(waypoint:find("20791", 1, true), "Find Nearest skips inaccessible portal trainers")

    standing[934], standing[935] = 4, 3
    menu.RefreshPortalTrainers()
    assert(shown[key][19340] and not shown[key][20791], "standing changes refresh enabled trainer pins")
    menu.FindNearest(key, key)
    assert(waypoint:find("19340", 1, true), "Find Nearest uses the new standings")
end
print("PASS: portal trainer reputation, pin refresh and Find Nearest")
