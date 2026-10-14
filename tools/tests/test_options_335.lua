-- Run from the addon root with Lua 5.1 or 5.2+.
-- Load the owning modules whole; exercise their registered callbacks without Compat startup patching.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local env = setmetatable({}, {__index = _G})
env._G = env
env.unpack, env.tinsert = unpack or table.unpack, table.insert
local function loadModule(path)
    local source = read(path)
    local chunk
    if setfenv then
        chunk = setfenv(assert(loadstring(source, "@" .. path)), env)
    else
        chunk = assert(load(source, "@" .. path, "t", env))
    end
    chunk()
end
local function noop() end
local function forbidden() error("obsolete options callback used") end
local profile = {enabled = true, enableMapIcons = true, debugEnabled = false,
    initDelay = 0.01, useQuestieLinks = false, resetDailyQuests = true, weeklyResetDay = 4}
local char = {dailyQuests = {[101] = true}, weeklyQuests = {[102] = true}}
env.Questie = {db = {profile = profile, char = char, global = {}}, Debug = noop,
    LOWLEVEL_NONE = 1, LOWLEVEL_ALL = 2, LOWLEVEL_OFFSET = 3, LOWLEVEL_RANGE = 4,
    icons = setmetatable({}, {__index = function(_, key) return "icon/" .. key end})}
env.StaticPopupDialogs, env.UISpecialFrames = {}, {}
env.CANCEL, env.YES, env.NO = "Cancel", "Yes", "No"
env.GetExpansionLevel = function() return 2 end
local popups, reloads, cvar = 0, 0, "0"
env.ReloadUI = function() reloads = reloads + 1 end
env.StaticPopup_Show = function(name)
    equal(name, "QUESTIE_RELOAD", "reload prompt")
    assert(env.StaticPopupDialogs[name], "popup must be registered before settings are used")
    popups = popups + 1
end
env.GetCVar = function(name)
    equal(name, "questFadingDisable", "native instant-text CVar")
    return cvar
end
env.SetCVar = function(name, value)
    equal(name, "questFadingDisable", "native instant-text CVar")
    equal(type(value), "string", "native CVar value type")
    equal(env.QUEST_FADING_DISABLE, value, "global agrees with CVar")
    cvar = value
end
local visibilityCalls, cacheCleared = 0, false
env.QuestieCompat = {C_Timer = {}, CALENDAR_WEEKDAY_NAMES = {
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"},
    ClearExplorationCache = function() cacheCleared = true end}
loadModule("Modules/Libs/QuestieLoader.lua")
local loader = env.QuestieLoader
local quest = loader:CreateModule("QuestieQuest")
quest.ToggleNotes = forbidden
quest.RefreshQuestIconVisibility = function()
    assert(cacheCleared, "exploration cache must be cleared before visibility refresh")
    cacheCleared = false
    visibilityCalls = visibilityCalls + 1
end
loader:CreateModule("QuestieNameplate").HideCurrentFrames = forbidden
loader:CreateModule("QuestieOptionsDefaults").Load = function() return {profile = {}} end
loader:CreateModule("QuestieOptionsUtils").Spacer = function() return {} end
local l10n = loader:CreateModule("l10n")
setmetatable(l10n, {__call = function(_, value) return value end})

local registered, opened
local frame = {SetMinResize = noop}
local configFrame = {frame = frame, Hide = noop, SetLayout = noop, EnableResize = noop}
env.CreateFrame = function()
    return {SetSize = noop, SetPoint = noop, SetText = noop, SetScript = noop}
end
local libraries = {
    ["AceGUI-3.0"] = {Create = function() return configFrame end},
    ["AceConfigDialog-3.0"] = {AddToBlizOptions = noop, SetDefaultSize = noop,
        Open = function()
            assert(registered.args.advanced_tab.args.weeklyResetDay, "settings exist before the UI opens")
            opened = true
        end},
    ["AceConfig-3.0"] = {RegisterOptionsTable = function(_, name, options)
        equal(name, "Questie", "registered options name")
        assert(options.args.advanced_tab.args.initDelay, "settings exist at registration")
        registered = options
    end},
    ["AceDBOptions-3.0"] = {GetOptionsTable = function() return {type = "group", args = {}} end},
    ["AceConfigRegistry-3.0"] = {GetOptionsTable = forbidden},
    ["LibSharedMedia-3.0"] = {MediaType = {SOUND = "sound"}, List = function() return {} end},
}
env.LibStub = function(name) return assert(libraries[name], "unexpected library: " .. name) end
loadModule("Modules/Options/QuestieOptions.lua")
local options = loader:ImportModule("QuestieOptions")
local initialize = options.Initialize
-- Follow the TOC order for the tabs involved in this refactor.
loadModule("Modules/Options/AdvancedTab/QuestieOptionsAdvanced.lua")
loadModule("Modules/Options/GeneralTab/QuestieOptionsGeneral.lua")
loadModule("Modules/Options/IconsTab/QuestieOptionsIcons.lua")
loadModule("Modules/Options/NameplateTab/QuestieOptionsNameplate.lua")
for _, tab in ipairs({"map", "tracker", "auto"}) do
    options.tabs[tab] = {Initialize = function() return {type = "group", args = {}} end}
end
local initialization = coroutine.create(function() options:Initialize() end)
while coroutine.status(initialization) ~= "dead" do
    local ok, message = coroutine.resume(initialization)
    assert(ok, message)
end
assert(opened, "options frame initialization completed")
equal(options.Initialize, initialize, "initialization method is not replaced")
equal(env.QuestieConfigFrame, configFrame, "initialized frame published")
equal(env.UISpecialFrames[1], "QuestieConfigFrame", "frame can close with Escape")

local instant = registered.args.general_tab.args.interface_options_group.args.instantQuest
local nameplate = registered.args.nameplate_tab.args.nameplate_options_group.args.nameplateEnabled
local unexplored = registered.args.icons_tab.args.map_settings_group.args.hideUnexploredMapIconsToggle
local advanced = registered.args.advanced_tab.args
local tests = 1
for _, value in ipairs({true, false}) do
    instant.set({}, value)
    equal(cvar, value and "1" or "0", "instant-text state")
    equal(instant.get(), value, "instant-text getter")
    local prompts = popups
    nameplate.set({"nameplateEnabled"}, value)
    equal(profile.nameplateEnabled, value, "nameplate setting persisted")
    equal(nameplate.get({"nameplateEnabled"}), value, "nameplate getter")
    equal(popups, prompts + 1, "nameplate change prompts for reload")
    unexplored.set({}, value)
    equal(profile.hideUnexploredMapIcons, value, "unexplored setting persisted")
    equal(unexplored.get(), value, "unexplored getter")
    equal(profile.enabled, true, "visibility change does not disable Questie")
    tests = tests + 1
end
equal(visibilityCalls, 2, "both visibility changes refreshed")

equal(advanced.initDelay.get({"initDelay"}), 0.1, "init-delay display units")
advanced.initDelay.set({"initDelay"}, 0.7)
assert(math.abs(profile.initDelay - 0.07) < 0.000001, "init-delay saved units")
equal(advanced.initDelay.hidden(), true, "init-delay hidden without debugging")
profile.debugEnabled = true
equal(advanced.initDelay.hidden(), false, "init-delay visible with debugging")
tests = tests + 1

for _, value in ipairs({true, false}) do
    local prompts = popups
    advanced.useQuestieLinks.set({"useQuestieLinks"}, value)
    equal(advanced.useQuestieLinks.get({"useQuestieLinks"}), value, "link setting persisted")
    equal(popups, prompts + 1, "link change prompts for reload")

    profile.dailyResetTime, char.dailyResetTime = 111, 222
    prompts = popups
    advanced.resetDailyQuests.set({"resetDailyQuests"}, value)
    equal(advanced.resetDailyQuests.get({"resetDailyQuests"}), value, "daily-reset setting persisted")
    equal(profile.dailyResetTime, nil, "profile daily timestamp invalidated")
    equal(char.dailyResetTime, 222, "character daily timestamp preserved")
    equal(popups, prompts + 1, "daily-reset change prompts for reload")
    equal(advanced.weeklyResetDay.disabled(), not value, "weekly setting depends on daily reset")
    tests = tests + 1
end

equal(advanced.weeklyResetDay.values, env.QuestieCompat.CALENDAR_WEEKDAY_NAMES, "weekday labels")
profile.weeklyResetTime, char.weeklyResetTime = 333, 444
local prompts = popups
advanced.weeklyResetDay.set({"weeklyResetDay"}, 7)
equal(advanced.weeklyResetDay.get({"weeklyResetDay"}), 7, "weekly day persisted")
equal(profile.weeklyResetTime, nil, "profile weekly timestamp invalidated")
equal(char.weeklyResetTime, nil, "character weekly timestamp invalidated")
equal(popups, prompts + 1, "weekly change prompts for reload")
equal(char.dailyQuests[101], true, "daily quest history preserved")
equal(char.weeklyQuests[102], true, "weekly quest history preserved")
tests = tests + 1

local popup = env.StaticPopupDialogs.QUESTIE_RELOAD
popup.OnAccept()
equal(reloads, 1, "accepting reload prompt reloads UI")
local strata
popup.OnShow({SetFrameStrata = function(_, value) strata = value end})
equal(strata, "TOOLTIP", "reload prompt remains above other windows")
equal(popup.timeout, 0, "reload prompt does not expire")
equal(popup.hideOnEscape, true, "reload prompt can be dismissed")
tests = tests + 1
print("3.3.5 options regression tests passed (" .. tests .. " groups)")
