-- Run from the addon root with Lua 5.1 or 5.2+. Real AceDB callbacks and profile consumers.
local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G, env.unpack = env, unpack or table.unpack
local function loadFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"); file:close()
    if setfenv then return setfenv(assert(loadstring(source, "@" .. path)), env)() end
    return assert(load(source, "@" .. path, "t", env))()
end
env.wipe = function(value) for key in pairs(value) do value[key] = nil end end
env.geterrorhandler = function() return error end
env.UnitName, env.GetRealmName = function() return "Tester" end, function() return "AzerothCore" end
env.UnitClass, env.UnitRace = function() return "Warrior", "WARRIOR" end, function() return "Human", "Human" end
env.UnitFactionGroup = function() return "Alliance" end
env.GetCVar, env.GetLocale = function() return "" end, function() return "enUS" end
env.bit = bit or bit32 or {band = noop}
local frames = {}
local methods = {}
for _, name in ipairs({"RegisterEvent", "UnregisterEvent", "SetFrameStrata", "SetFrameLevel", "EnableMouse", "ClearAllPoints"}) do
    methods[name] = noop
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:SetPoint(...) self.point = {...} end
function methods:SetParent(value) self.parent = value end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetAllPoints(value) self.allPoints = value end
function methods:SetTexture(value) self.texture = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:CreateTexture() return env.CreateFrame("Texture", nil, self) end
env.CreateFrame = function(_, _, parent)
    local frame = setmetatable({scripts = {}, parent = parent, shown = true}, {__index = methods})
    frames[#frames + 1] = frame
    return frame
end
env.TargetFrame = env.CreateFrame("Frame")
env.UnitGUID = function() return "0xF130000065000001" end
env.strsplit = function(_, value)
    local parts = {}; for part in value:gmatch("[^-]+") do parts[#parts + 1] = part end
    return env.unpack(parts)
end
env.tremove = table.remove
local modules = {}
local function module(name) modules[name] = modules[name] or {private = {}}; return modules[name] end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end, FinishLoadTimings = noop}
env.Questie = {Debug = noop, Error = error, db = {profile = {}}}
env.QuestieCompat = {UnitGUID = function() return "Creature-0-0-0-0-101-00000001" end,
    C_Timer = {After = noop, NewTicker = noop}}
env.LibStub = nil
loadFile("Libs/LibStub/LibStub.lua")
loadFile("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
loadFile("Libs/AceDB-3.0/AceDB-3.0.lua")
env.LibStub:NewLibrary("HereBeDragonsQuestie-2.0", 1).GetWorldCoordinatesFromZone = function() return 0, 0, 1 end
local hud = {HUDEnabled = true, Version = 1, zoom = 100, rate = 0.03}
function hud:SetFixedZoom(value) self.zoom = value end
function hud:SetFixedUpdateRate(value) self.rate = value end
hud.ClearAllEdges, hud.FreeEncounterMarkerByTarget = noop, noop
env.DBM = {HudMap = hud, Schedule = noop, Unschedule = noop, AddMsg = noop}
env.GetInstanceInfo = function() return nil, nil, nil, nil, nil, nil, nil, 1 end
env.IsInInstance = function() return false end
loadFile("Modules/QuestieDBMIntegration.lua")
loadFile("Modules/QuestieNameplate.lua")
modules.QuestieNameplate.private.GetValidIcon = function() return "quest-icon" end
module("QuestieTooltips").lookupByKey = {}
local defaults = {profile = {nameplateTargetFrameEnabled = true, nameplateTargetFrameScale = 1,
    nameplateTargetFrameX = 0, nameplateTargetFrameY = 0, DBMHUDZoom = 100, DBMHUDRefresh = 0.03}}
module("QuestieOptionsDefaults").Load = function() return defaults end
module("ProfilerPreHook").StartIfEnabled = noop
module("QuestieEventHandler").RegisterEarlyEvents = noop
module("QuestieValidateGameCache").StartCheck = noop
module("QuestieLib").AddonPath = "Interface\\AddOns\\Questie-335\\"
local refreshes, trackerChanges, snapshots = 0, 0, 0
module("QuestieQuest").SmoothReset = function()
    refreshes = refreshes + 1
    modules.QuestieDBMIntegration:ClearAll()
end
module("MinimapIcon").Refresh = noop
module("TrackerBaseFrame").OnProfileChange = function() trackerChanges = trackerChanges + 1 end
module("CommsVisibility").ScheduleSnapshot = function() snapshots = snapshots + 1 end
loadFile("Questie.lua")
env.Questie.SetIcons = noop
env.QuestieConfig = {profiles = {
    Second = {nameplateTargetFrameScale = 2, nameplateTargetFrameX = 4, nameplateTargetFrameY = 7,
        DBMHUDZoom = 200, DBMHUDRefresh = 0.06},
    Hidden = {nameplateTargetFrameEnabled = false},
}}
env.Questie:OnInitialize()
local db = env.Questie.db
modules.QuestieDBMIntegration:EnableHUD()
local function targetIcon()
    for _, frame in ipairs(frames) do
        if frame.parent == env.TargetFrame and frame.Icon and frame.shown then return frame end
    end
end
local function applied(count)
    equal(refreshes, count, "AceDB applies runtime effects once")
    equal(trackerChanges, count, "existing tracker profile callback retained")
    equal(snapshots, count, "profile visibility snapshot retained")
end
modules.QuestieNameplate:DrawTargetFrame()
equal(assert(targetIcon()).width, 16, "initial target icon scale")
db:SetProfile("Second")
applied(1)
local icon = assert(targetIcon())
equal(icon.width, 32, "profile switch reapplies target icon scale")
equal(icon.point[2], 4, "profile switch reapplies target icon X")
equal(icon.point[3], 7, "profile switch reapplies target icon Y")
equal(hud.zoom, 200, "active HUD adopts profile zoom")
equal(hud.rate, 0.06, "active HUD adopts profile refresh rate")

db:CopyProfile("Default")
applied(2)
equal(assert(targetIcon()).width, 16, "copied profile reapplies target layout")
equal(hud.zoom, 100, "copied profile reapplies HUD zoom")
db.profile.nameplateTargetFrameScale, db.profile.DBMHUDZoom = 3, 300
db:ResetProfile()
applied(3)
equal(assert(targetIcon()).width, 16, "reset profile reapplies target layout")
equal(hud.zoom, 100, "reset profile reapplies HUD defaults")

db:SetProfile("Hidden")
applied(4)
equal(targetIcon(), nil, "disabled target objective disappears after profile switch")
db:SetProfile("Second")
applied(5)
assert(targetIcon(), "enabled target objective returns after profile switch")

env.DBM = nil
modules.QuestieNameplate:HideCurrentTargetFrame()
db:SetProfile("Default")
applied(6)
equal(assert(targetIcon()).width, 16, "profile refresh tolerates absent HUD and recreates the target icon")
print("Profile refresh regressions passed (6 groups; real AceDB, target icon and HUD consumers)")
