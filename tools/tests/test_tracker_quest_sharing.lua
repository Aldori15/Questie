-- Run from the addon root with Lua 5.1 or 5.2+. Exercise native 3.3.5 quest sharing.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local env = setmetatable({}, {__index = _G})
env._G = env
local modules = {}
local function module(name) modules[name] = modules[name] or {}; return modules[name] end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
local s = {group = true, raid = false, selected = 7, pushable = true, index = 2, pushes = 0, prints = 0, closes = 0}
local function noop() end
env.Questie = {db = {profile = {trackerbindShareQuest = "altleft", trackerbindUntrack = "shiftleft",
    trackerbindSetTomTom = "ctrlleft", trackerbindOpenQuestLog = "left"}, char = {collapsedQuests = {}}}, Debug = noop,
    Print = function() s.prints = s.prints + 1 end}
env.QuestLogListScrollFrame = {ScrollBar = {}}
env.QuestLogFrame = {IsShown = function() return false end}
env.GetQuestLogSelection = function() return s.selected end
env.SelectQuestLogEntry = function(index) s.selected = index end
env.GetQuestLogPushable = function() equal(s.selected, 2, "pushability checks selected quest"); return s.pushable end
env.QuestLogPushQuest = function() equal(s.selected, 2, "push uses selected quest"); s.pushes = s.pushes + 1 end
env.InCombatLockdown = function() return s.combat end
env.IsShiftKeyDown = function() return s.shift end
env.IsControlKeyDown = function() return s.ctrl end
env.IsAltKeyDown = function() return s.alt end
env.IsModifiedClick = function() return s.shift end
env.ChatEdit_GetActiveWindow = function() return s.chat end
env.ChatEdit_InsertLink = function(link) s.link = link end
env.IsAddOnLoaded = function() return false end
local dropdown = {Create_UIDropDownMenu = function() return {IsShown = function() return false end} end,
    CloseDropDownMenus = function() s.closes = s.closes + 1 end}
env.QuestieCompat = {IsInGroup = function() return s.group end, IsInRaid = function() return s.raid end,
    GetQuestLogIndexByID = function(id) return id == 900001 and s.index or nil end,
    C_Timer = {}, C_Map = {}, LibUIDropDownMenu = dropdown}
env.LibStub = setmetatable({GetLibrary = function() return {} end}, {__call = function() return {} end})
setmetatable(module("l10n"), {__call = function(_, text) return text end})
module("QuestieDB").GetQuest = function() error("sharing must not depend on Questie database records") end
module("TrackerData").GetQuestLink = function(quest) return "|Hquest:" .. quest.Id .. ":20|h[Native quest]|h" end
module("TrackerData").GetColoredQuestName = function() return "Native quest" end
module("QuestieLib").GetColoredQuestName = function() return "Mapped quest" end
module("QuestieTracker").UntrackQuestId = function(_, id) s.untracked = id end
module("QuestieMap").GetNearestQuestSpawn = function() s.tomtom = true; return nil end
local function loadModule(path)
    if setfenv then setfenv(assert(loadfile(path)), env)() else assert(loadfile(path, "t", env))() end
end
loadModule("Modules/Tracker/TrackerUtils.lua")
loadModule("Modules/Tracker/TrackerMenu.lua")
loadModule("Modules/Tracker/TrackerLinePool.lua")
local utils, menu, lines = module("TrackerUtils"), module("TrackerMenu"), module("TrackerLinePool")
utils.SetTomTomTargetToDungeonEntrance = noop
utils.ShowQuestLog = function() s.log = true end
local quest = {Id = 900001, NativeOnly = true, name = "Native quest", Objectives = {}, SpecialObjectives = {},
    IsComplete = function() return 1 end}
equal(utils.CanShareQuest(nil), false, "missing quest ID")
equal(utils.CanShareQuest(844), false, "absent native quest")
equal(utils.CanShareQuest(900001), true, "database-unknown completed quest may be shared")
equal(s.selected, 7, "inspection restores other selected quest")
s.selected = 0
equal(utils.ShareQuest(900001), true, "native sharing succeeds")
equal(s.selected, 0, "sharing restores empty selection")
equal(s.pushes, 1, "one native push")
s.group = false
equal(utils.CanShareQuest(900001), false, "solo cannot share")
s.raid = true
equal(utils.CanShareQuest(900001), true, "native raid qualifies")
s.group, s.raid, s.pushable = true, false, false
equal(utils.CanShareQuest(900001), false, "native unpushable quest")
s.pushable, s.index = true, 0
equal(utils.CanShareQuest(900001), false, "invalid quest log index")
s.index = 2
local function shareOption(record)
    for _, item in ipairs(menu:GetMenuForQuest(record)) do if item.text == "Share Quest" then return item end end
end
local option = assert(shareOption(quest), "native quest menu offers sharing")
quest.NativeOnly = false
assert(shareOption(quest), "mapped quest menu offers sharing")
quest.NativeOnly = true
s.index = nil
option.func()
equal(s.pushes, 1, "stale menu does not share removed quest")
equal(s.closes, 1, "share callback dismisses menu")
s.index, s.group = 2, false
option.func()
equal(s.pushes, 1, "stale menu rechecks group membership")
s.group, s.combat = true, true
option.func()
equal(s.prints, 1, "combat explains refusal")
equal(s.pushes, 1, "combat cannot push or queue sharing")
s.combat = false
equal(s.pushes, 1, "leaving combat does not replay share")
s.shift, s.chat = true, {}
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.link, module("TrackerData").GetQuestLink(quest), "Shift-click links a native-only quest into open chat")
equal(s.pushes, 1, "chat link does not push")
local getLink = module("TrackerData").GetQuestLink
module("TrackerData").GetQuestLink = function() return nil end
s.link = "existing chat text"
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.link, "existing chat text", "missing quest link preserves chat input")
equal(s.pushes, 1, "missing chat link does not fall through to sharing")
module("TrackerData").GetQuestLink = getLink
s.shift, s.alt = false, true
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.pushes, 2, "the share shortcut still shares while chat is open")
s.chat = nil
env.Questie.db.profile.trackerbindShareQuest = "shiftleft"
s.alt, s.shift = false, true
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.pushes, 3, "share takes priority over colliding untrack shortcut")
equal(s.untracked, nil, "sharing does not untrack")
env.Questie.db.profile.trackerbindShareQuest = "disabled"
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.untracked, 900001, "disabled sharing preserves existing untrack shortcut")
s.untracked, s.chat = nil, {}
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.untracked, nil, "Shift-click takes priority when chat is open")
quest.NativeOnly, s.shift, s.ctrl, s.chat = false, false, true, nil
env.Questie.db.profile.trackerbindShareQuest = "ctrlleft"
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.tomtom, nil, "unavailable TomTom does not consume the shortcut")
equal(s.pushes, 4, "sharing receives the click without TomTom")
local tomtomMenu = {}
menu.addTomTomOption(tomtomMenu, quest, nil)
equal(#tomtomMenu, 0, "tracker menu omits waypoint actions without TomTom")
env.TomTom = {AddWaypoint = noop}
menu.addTomTomOption(tomtomMenu, quest, nil)
equal(#tomtomMenu, 1, "tracker menu exposes the waypoint action with TomTom")
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.tomtom, true, "TomTom keeps priority over sharing")
equal(s.pushes, 4, "TomTom collision does not share")

utils.SetShortcut("trackerbindUntrack", "ctrlleft")
equal(env.Questie.db.profile.trackerbindSetTomTom, "disabled", "assigning untrack clears TomTom's conflicting shortcut")
equal(env.Questie.db.profile.trackerbindShareQuest, "disabled", "assigning untrack clears the share conflict")
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.untracked, quest.Id, "Ctrl-click runs its exact binding")
local profile = env.Questie.db.profile
utils.SetShortcut("trackerbindUntrack", "left")
utils.SetShortcut("trackerbindOpenQuestLog", "altleft")
s.untracked, s.ctrl, s.alt = nil, false, true
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.untracked, nil, "plain Left Click does not shadow Alt-click")
equal(s.log, true, "Alt-click selects the quest log binding")
s.log, s.ctrl = nil, true
lines.OnClickQuest({Quest = quest}, "LeftButton")
equal(s.log, nil, "Alt+Ctrl does not match Alt")
equal(s.untracked, nil, "Alt+Ctrl does not match unmodified Left Click")
equal(profile.trackerbindUntrack, "left", "plain shortcut remains assigned")
s.alt, s.ctrl, s.shift, s.chat = false, false, true, {}
env.GetAchievementLink = function(id) return "achievement:" .. id end
lines.OnClickAchieve({Quest = {Id = 6}}, "LeftButton")
equal(s.link, "achievement:6", "Shift-click links an achievement with untrack bound elsewhere")

-- Every new player-facing string has an explicit translation for every supported locale.
local translations = module("l10n")
translations.translations = {}
loadModule("Localization/Translations/Options/Tracker.lua")
loadModule("Localization/Translations/TrackerUI.lua")
for _, key in ipairs({"Untrack", "This shortcut removes a Quest or an Achievement from the Questie Tracker.",
    "This shortcut shares a Quest with your group.",
    "Share Quest", "Can't share a Quest while in combat."}) do
    for _, locale in ipairs({"enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}) do
        assert(translations.translations[key][locale], key .. " missing " .. locale)
    end
end
-- Menu links must use the active edit box, not the first edit box's visibility.
do
    local insertLink = env.ChatEdit_InsertLink
    env.ChatFrame1EditBox = {IsVisible = function() return true end}
    env.GetAchievementLink = function(id) return "achievement:" .. id end
    local opened, inserted, draft
    env.ChatFrame_OpenChat = function(link) opened = link end
    env.ChatEdit_InsertLink = function(link)
        if s.chat then inserted = link; draft = draft .. link end
    end
    for _, case in ipairs({
        {add = menu.addLinkToChatOption, record = {Id = 900001}, link = getLink({Id = 900001})},
        {add = menu.addLinkToChatOption, record = {Id = 900001, NativeOnly = true}, link = getLink({Id = 900001})},
        {add = menu.addAchieveLinkToChatOption, record = {Id = 6}, link = "achievement:6"},
    }) do
        for _, active in ipairs({false, true}) do
            s.chat = active and {} or nil -- Active box can belong to a different chat frame.
            opened, inserted, draft = nil, nil, "Existing draft "
            local entries = {}
            case.add(entries, case.record)
            local closes = s.closes
            entries[1].func()
            equal(s.closes, closes + 1, "menu link closes dropdown")
            if active then
                equal(inserted, case.link, "link inserted into active edit box")
                equal(draft, "Existing draft " .. case.link, "active draft preserved")
                equal(opened, nil, "active chat is not reopened")
            else
                equal(opened, case.link, "idle visible edit box opens chat with link")
                equal(inserted, nil, "inactive chat does not receive insertion")
            end
        end
    end
    env.ChatEdit_InsertLink = insertLink
end
print("Tracker quest sharing and menu links: native selection, combat, shortcuts, chat focus and all locales passed")
