-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the status registry, minimap display, and real ThreadLib startup failure callbacks.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function setup(lazy)
    local env = setmetatable({}, {__index = _G})
    env._G, env.unpack = env, unpack or table.unpack
    local modules = {}
    local s = {timers = {}, errors = {}, profilerRefreshes = 0, badgeHosts = 0}
    local function module(name, declared)
        if not modules[name] then
            modules[name] = {private = {}}
            if not declared then
                setmetatable(modules[name], {__index = function() return noop end})
                setmetatable(modules[name].private, {__index = function() return noop end})
            end
        end
        return modules[name]
    end
    env.QuestieLoader = {
        CreateModule = function(_, name) return module(name, true) end,
        ImportModule = function(_, name) return module(name) end,
        GetUnresolvedModuleImports = function() return {} end,
    }
    env.Questie = {started = false, Debug = noop, SetIcons = noop, Colorize = function(_, text) return text end,
        Error = function(...) s.errors[#s.errors + 1] = {...} end,
        db = {profile = {minimap = {}}, global = {dbIsCompiled = true, dbCompiledOnVersion = "test",
            dbCompiledLang = "enUS", dbCompiledSchemaVersion = 1}, char = {townsfolk = {}, townsfolkClass = "WARRIOR"}}}
    env.geterrorhandler = function() return env.Questie.Error end
    env.debugstack = function() return "test stack" end
    env.GetLocale = function() return "enUS" end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    env.GetCursorPosition = function() return 200, 200 end
    env.collectgarbage = noop
    env.loadstring = loadstring or load
    local methods = {}
    local function frame(parent)
        return setmetatable({parent = parent, shown = true, scripts = {}, textures = {}, width = 140, height = 140}, {__index = methods})
    end
    function methods:GetParent() return self.parent end
    function methods:SetParent(parent) self.parent = parent end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetWidth(value) self.width = value end
    function methods:SetHeight(value) self.height = value end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:GetCenter() return 200, 200 end
    function methods:GetEffectiveScale() return 1 end
    function methods:ClearAllPoints() self.point = nil end
    function methods:SetPoint(...) self.point = {...} end
    function methods:SetAllPoints(target) self.allPoints = target end
    function methods:GetFrameLevel() return self.level or 8 end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
    function methods:SetTexCoord(...) self.coords = {...} end
    function methods:SetTexture(value) self.texture = value; return value ~= "missing" end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, callback) self.scripts[event] = callback end
    for _, name in ipairs({"SetMovable", "SetClampedToScreen", "StartMoving", "StopMovingOrSizing"}) do methods[name] = noop end
    function methods:CreateTexture(_, layer)
        equal(layer, "OVERLAY", "badge uses legacy overlay texture")
        local texture = frame(self)
        self.textures[#self.textures + 1] = texture
        s.badge = texture
        return texture
    end
    env.UIParent, env.Minimap = frame(), frame()
    env.CreateFrame = function(kind, name, parent)
        equal(kind, "Frame", "badge host is a plain frame")
        equal(name, nil, "badge host is unnamed")
        s.badgeHosts = s.badgeHosts + 1
        s.badgeHost = frame(parent)
        return s.badgeHost
    end
    local function makeButton()
        if not s.button then
            s.button = frame(env.Minimap)
            s.button.icon = frame(s.button)
            s.button.textures[1] = s.button.icon
        end
        return s.button
    end
    local iconLib = {
        Register = function(_, _, object, db)
            s.broker = object
            if not lazy then makeButton().shown = not db.hide end
        end,
        GetMinimapButton = function() return s.button end,
        Show = function() makeButton():Show() end,
        Hide = function() if s.button then s.button:Hide() end end,
    }
    env.LibStub = function(name)
        if name == "LibDBIcon-1.0" then return iconLib end
        return {NewDataObject = function(_, _, object) return object end}
    end
    env.QuestieCompat = {ReleaseCorrectionRegistries = noop, C_Timer = {
        After = noop,
        NewTicker = function(_, callback)
            local timer = {tick = callback, Cancel = function(self) self.cancelled = true end}
            s.timers[#s.timers + 1] = timer
            return timer
        end,
    }}
    local lib = module("QuestieLib")
    lib.AddonPath = "Interface\\AddOns\\Questie-335\\"
    lib.GetAddonVersionString = function() return "test" end
    local locale = module("l10n")
    locale.GetUILocale = function() return "enUS" end
    setmetatable(locale, {__index = function() return noop end,
        __call = function(_, text, ...) return string.format(text, ...) end})
    module("DBCompiler").compiledSchemaVersion = 1
    module("Profiler").active = true
    module("Profiler").RefreshHooks = function() s.profilerRefreshes = s.profilerRefreshes + 1; return true end
    module("QuestieOptions").Initialize = function()
        if s.failOptions then error("options failed") end
        while s.waitOptions do coroutine.yield() end
    end
    local function loadModule(path)
        local file = assert(io.open(path, "r"))
        local source = file:read("*a")
        file:close()
        if setfenv then setfenv(assert(loadstring(source, "@" .. path)), env)()
        else assert(load(source, "@" .. path, "t", env))() end
    end
    loadModule("Modules/Status/QuestieStatus.lua")
    loadModule("Modules/Libs/ThreadLib.lua")
    loadModule("Modules/MinimapIcon.lua")
    loadModule("Modules/QuestieInit.lua")
    s.status, s.icon, s.init = modules.QuestieStatus, modules.MinimapIcon, modules.QuestieInit
    -- Keep production Stage 1 (including its separate options job); isolate later UI-heavy stages.
    s.init.Stages[2] = function() coroutine.yield() end
    s.init.Stages[3] = function()
        env.Questie.started = true
        if s.failNil then coroutine.yield(); error(nil) end
        if s.failLate then coroutine.yield(); error(s.failLate) end
    end
    function s.finish(timer)
        for _ = 1, 100 do
            if timer.cancelled then return end
            timer.tick()
        end
        error("timer did not finish")
    end
    function s.tooltip()
        local lines = {}
        local tooltip = {AddLine = function(_, text) lines[#lines + 1] = text end,
            AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " " .. b end}
        s.broker.OnTooltipShow(tooltip)
        return table.concat(lines, "\n")
    end
    s.env, s.modules = env, modules
    return s
end

-- Notice snapshots, severity priority, stable ordering, and a nonfatal display observer.
do
    local s = setup()
    local notice = {severity = 3, message = "%s", args = {"original"}, icon = {texture = "custom"}}
    s.status.Set("info", notice)
    notice.args[1], notice.icon.texture = "changed", "changed"
    equal(s.status.GetIssues()[1].args[1], "original", "notice arguments copied")
    equal(s.status.GetIssues()[1].icon.texture, "custom", "notice icon copied")
    local snapshot = s.status.GetIssues()[1]
    snapshot.args[1] = "changed again"
    equal(s.status.GetIssues()[1].args[1], "original", "getter returns independent snapshot")
    s.status.Set("warning", {severity = 2, message = "Warning"})
    s.status.Set("error.custom", {severity = 1, message = "Error", icon = {texture = "custom"}})
    s.status.Set("error.default", {severity = 1, message = "Error"})
    equal(s.status.GetBadgeIssue().id, "error.default", "default badge beats custom icon at same severity")
    s.status.Set("error.custom", {severity = 1, message = "Updated", icon = {texture = "custom"}})
    equal(s.status.GetIssues()[1].id, "error.custom", "updates preserve activation order")
    equal(s.status.SetOnChange(function() error("display failed") end), false, "observer failure remains nonfatal")
    equal(s.status.GetBadgeIssue().id, "error.default", "observer failure preserves recorded status")
    s.status.SetOnChange(nil)
    s.status.Clear("error.custom"); s.status.Clear("error.default")
    equal(s.status.GetBadgeIssue().id, "warning", "warnings precede information")
end

-- Badge/tooltip state follows notices and never forces a hidden or detached button into another mode.
do
    local s = setup()
    s.env.Questie.db.profile.minimap.hide = true
    s.icon:Init()
    equal(s.button.shown, false, "hidden preference preserved")
    s.status.Set("info", {severity = 3, message = "Information"})
    equal(s.badge.texture, "Interface\\AddOns\\Questie-335\\Icons\\green_plus.blp", "converted BLP used")
    equal(s.badge.shown, true, "informational badge displayed")
    equal(s.button.shown, false, "notice does not reveal hidden button")
    assert(not s.tooltip():find("Left Click", 1, true), "unready controls not advertised")
    s.status.Set("warning", {severity = 2, message = "Warning"})
    equal(s.badge.texture, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", "legacy warning triangle")
    s.status.Set("error", {severity = 1, message = "Questie could not start: %s", args = {"failure"}})
    equal(s.badge.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "legacy error texture")
    assert(s.tooltip():find("failure", 1, true), "error details reach broker tooltip")
    s.status.Clear("error"); s.status.Clear("warning"); s.status.Clear("info")
    equal(s.badge.shown, false, "badge hidden with no notices")
    s.env.Questie.started = true
    assert(s.tooltip():find("Left Click", 1, true), "ready controls advertised")
    s.env.Questie.db.profile.minimap.detached = true
    s.icon:SetShown(true)
    equal(s.button:GetParent(), s.env.UIParent, "detached mode retained")
    s.status.Set("info", {severity = 3, message = "Information", icon = {texture = "missing"}})
    equal(s.badge.parent.parent, s.button, "badge follows detached button through its host")
    equal(s.button:GetParent(), s.env.UIParent, "status update does not reparent the button")
    equal(s.badge.texture, "Interface\\AddOns\\Questie-335\\Icons\\green_plus.blp", "missing custom texture falls back")
    equal(s.badgeHosts, 1, "refresh reuses one badge host")
    equal(#s.badgeHost.textures, 1, "refresh reuses one badge")
end

-- Button skin texture scans cannot reposition, crop, or stretch a hosted badge.
do
    local s = setup()
    s.icon:Init()
    s.status.Set("info", {severity = 3, message = "Information"})
    -- Simulate a skin treating every direct button texture as the full launcher icon.
    for _, region in ipairs(s.button.textures) do
        region:SetSize(21, 21)
        region:ClearAllPoints()
        region:SetPoint("CENTER", s.button, "CENTER")
        region:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        assert(region ~= s.badge, "badge is outside the skin's region scan")
    end
    equal(s.badgeHost:GetParent(), s.button, "badge retains launcher parent")
    equal(s.badgeHost:GetWidth(), 12, "skin does not stretch badge")
    equal(s.badgeHost.point[3], "TOPRIGHT", "skin does not move badge from the corner")
    equal(s.badge.coords[1], 0, "skin does not crop badge")
    equal(s.badge.allPoints, s.badgeHost, "texture fills its own host")
    assert(s.badgeHost:GetFrameLevel() > s.button:GetFrameLevel(), "badge renders above launcher artwork")
    equal(s.badgeHost.mouseEnabled, false, "badge does not intercept clicks or tooltip hover")
end

-- Delayed minimap creation replays notices recorded before the button exists.
do
    local s = setup(true)
    s.icon:Init()
    s.status.Set("warning", {severity = 2, message = "Warning"})
    equal(s.badge, nil, "no badge before delayed button exists")
    s.icon:SetShown(true)
    equal(s.badge.texture, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", "delayed badge replays current notice")
end

-- Successful startup waits for its options job before clearing progress, retaining profiler cleanup.
do
    local s = setup()
    s.waitOptions = true
    s.init:Init()
    s.finish(s.timers[1])
    equal(s.env.Questie.started, true, "successful startup is ready")
    equal(s.status.GetBadgeIssue().id, "startup.initializing", "progress remains until options finish")
    equal(s.profilerRefreshes, 1, "successful startup retains profiler refresh")
    s.waitOptions = false
    s.finish(s.timers[2])
    equal(s.status.GetBadgeIssue(), nil, "completed startup clears progress")
end

-- An options failure cancels suspended login work, records the first failure, and blocks restart.
do
    local s = setup()
    s.failOptions = true
    s.init:Init()
    s.timers[1].tick()
    s.finish(s.timers[2])
    equal(s.timers[1].cancelled, true, "options failure cancels login thread")
    equal(s.env.Questie.started, false, "failed startup is not ready")
    equal(s.status.GetBadgeIssue().id, "startup.options", "options failure recorded")
    equal(s.badge.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "startup failure displays red badge")
    s.init.private.OnInitializationComplete(false, "later failure")
    equal(s.status.GetBadgeIssue().id, "startup.options", "first failure preserved")
    s.init:Init()
    equal(#s.timers, 2, "failed startup does not submit another job")
end

-- A late login failure revokes readiness and does not run successful completion cleanup.
do
    local s = setup()
    s.failLate = "late failure"
    s.init:Init()
    s.finish(s.timers[1])
    equal(s.env.Questie.started, false, "late failure revokes readiness")
    equal(s.timers[2].cancelled, true, "login failure cancels options thread")
    equal(s.profilerRefreshes, 0, "failed completion does not run success cleanup")
    assert(s.tooltip():find("late failure", 1, true), "startup report shown")
end

-- Lua errors with nil payloads still produce a usable tooltip argument.
do
    local s = setup()
    s.failNil = true
    s.init:Init()
    s.finish(s.timers[1])
    equal(s.status.GetBadgeIssue().args[1], "nil", "nil error captured as text")
    assert(s.tooltip():find("Questie could not start: nil", 1, true), "nil error tooltip formats safely")
end

-- Invalid serialized database chunks must stop initialization rather than continuing with missing data.
do
    local s = setup()
    s.modules.QuestieDB.objectData = "invalid Lua !"
    s.init.Stages[2] = function() s.init:LoadDatabase("objectData") end
    s.init:Init()
    s.finish(s.timers[1])
    equal(s.env.Questie.started, false, "invalid database does not reach readiness")
    assert(s.status.GetBadgeIssue().args[1]:find("Failed to load database objectData", 1, true), "database failure identified")
end

print("Minimap status regressions passed")
