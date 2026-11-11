-- Run from the addon root with Lua 5.1 or 5.2. Load real libraries against 3.3.5 UI contracts.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.000001, label)
end
local function harness()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.unpack = unpack or table.unpack
    env.wipe = function(value)
        for key in pairs(value) do value[key] = nil end
        return value
    end
    local function compile(source, name)
        if setfenv then return setfenv(assert(loadstring(source, name)), env) end
        return assert(load(source, name, "t", env))
    end
    env.loadstring = compile
    local function loadLibrary(path)
        local file = assert(io.open(path, "r"))
        local source = file:read("*a")
        file:close()
        compile(source, "@" .. path)()
    end
    local frames = {}
    local frameMethods = {}
    function frameMethods:SetScript(event, handler) self.scripts[event] = handler end
    function frameMethods:GetScript(event) return self.scripts[event] end
    function frameMethods:HookScript(event, handler)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            handler(...)
        end
    end
    function frameMethods:RegisterEvent(event) self.events[event] = true end
    function frameMethods:SetPoint(...) self.point = {...} end
    function frameMethods:ClearAllPoints() self.point = nil end
    function frameMethods:SetParent(parent) self.parent = parent end
    function frameMethods:GetParent() return self.parent end
    function frameMethods:SetWidth(width) self.width = width end
    function frameMethods:SetHeight(height) self.height = height end
    function frameMethods:GetWidth() return self.width end
    function frameMethods:GetHeight() return self.height end
    function frameMethods:GetCenter() return 100, 100 end
    function frameMethods:GetEffectiveScale() return 1 end
    function frameMethods:SetFrameStrata(strata) self.strata = strata end
    function frameMethods:SetFrameLevel(level) self.level = level end
    function frameMethods:GetFrameLevel() return self.level or 1 end
    function frameMethods:RegisterForClicks(...) self.clicks = {...} end
    function frameMethods:RegisterForDrag(...) self.drags = {...} end
    function frameMethods:SetHighlightTexture(texture) self.highlight = texture end
    function frameMethods:SetTexture(texture) self.texture = texture end
    function frameMethods:SetTexCoord(...) self.texCoord = {...} end
    function frameMethods:SetVertexColor(r, g, b, a)
        assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "numeric vertex colors required")
        self.vertexColor = {r, g, b, a}
    end
    function frameMethods:GetVertexColor() return env.unpack(self.vertexColor or {1, 1, 1, 1}) end
    function frameMethods:SetText(text) self.text = text end
    function frameMethods:GetText() return self.text end
    function frameMethods:SetTextColor(...) self.textColor = {...} end
    function frameMethods:SetJustifyH(value) self.justify = value end
    function frameMethods:SetDesaturated(value) self.desaturated = value end
    function frameMethods:EnableMouse(value) self.mouseEnabled = value end
    function frameMethods:Enable() self.enabled = true end
    function frameMethods:Disable() self.enabled = false end
    function frameMethods:IsVisible() return self.shown end
    function frameMethods:SetOwner(owner) self.owner = owner end
    function frameMethods:SetHyperlink(link) self.link = link end
    function frameMethods:SetClampedToScreen(value) self.clamped = value end
    function frameMethods:SetColorRGB(...) self.color = {...} end
    function frameMethods:GetColorRGB() return env.unpack(self.color) end
    function frameMethods:LockHighlight() self.lockedHighlight = true end
    function frameMethods:UnlockHighlight() self.lockedHighlight = nil end
    function frameMethods:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frameMethods:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    env.CreateFrame = function(_, name, parent)
        local frame = setmetatable({scripts = {}, events = {}, parent = parent, shown = true,
            width = 150, height = 150}, {__index = frameMethods})
        frames[#frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    function frameMethods:CreateTexture() return env.CreateFrame("Texture", nil, self) end
    function frameMethods:CreateFontString() return env.CreateFrame("FontString", nil, self) end
    env.UIParent = env.CreateFrame("Frame")
    env.Minimap = env.CreateFrame("Minimap")
    env.GameTooltip = env.CreateFrame("GameTooltip")
    env.geterrorhandler = function() return env.errorHandler or function(message) error(message, 0) end end
    env.GetRealmName = function() return "AzerothCore" end
    env.UnitName = function() return "Tester" end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    env.UnitRace = function() return "Human", "Human" end
    env.UnitFactionGroup = function() return "Alliance" end
    env.GetMinimapShape = function() return env.shape or "ROUND" end
    env.GetCursorPosition = function() return 180, 100 end
    loadLibrary("Libs/LibStub/LibStub.lua")
    loadLibrary("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    return env, loadLibrary, frames
end

do
    local env = harness()
    local errors, calls = {}, 0
    env.errorHandler = function(message) errors[#errors + 1] = message end
    local target = {}
    local registry = env.LibStub("CallbackHandler-1.0"):New(target)
    target.RegisterCallback({}, "Probe", function() error("callback failure") end)
    target.RegisterCallback({}, "Probe", function(event, first, last)
        equal(event, "Probe", "callback event name")
        equal(first, nil, "callback retains nil argument")
        equal(last, "tail", "callback retains trailing argument")
        calls = calls + 1
    end)
    registry:Fire("Probe", nil, "tail")
    equal(calls, 1, "callback failure does not stop other listeners")
    equal(#errors, 1, "failed callback reported once")
    equal(env.securecallfunction, nil, "native compatibility fallback stays library-local")
end

do
    local env, loadLibrary = harness()
    loadLibrary("Libs/AceDB-3.0/AceDB-3.0.lua")
    local db = env.LibStub("AceDB-3.0"):New({}, {profile = {defaultValue = 7}}, "Active")
    equal(db.keys.char, "Tester - AzerothCore", "3.3.5 character identity")
    equal(db.keys.factionrealm, "Alliance - AzerothCore", "3.3.5 faction identity")
    db.profile.keep = true
    local child = db:RegisterNamespace("Loaded", {profile = {defaultValue = 9}})
    child.profile.keep = true
    db.sv.namespaces.Unloaded = {profiles = {Source = {nested = {value = 42}}, Active = {stale = true}}}
    db.sv.namespaces.Empty = {profiles = {Active = {stale = true}}}
    db.profiles.Source = {value = 5}
    child.profiles.Source = {value = 6}
    db:CopyProfile("Source")
    equal(db.profile.value, 5, "parent profile copied")
    equal(child.profile.value, 6, "loaded namespace copied")
    local unloaded = db.sv.namespaces.Unloaded.profiles
    equal(unloaded.Active.stale, nil, "unloaded destination cleared")
    equal(unloaded.Active.nested.value, 42, "unloaded namespace copied")
    unloaded.Active.nested.value = 43
    equal(unloaded.Source.nested.value, 42, "namespace copy does not alias source")
    equal(next(db.sv.namespaces.Empty.profiles.Active), nil, "missing namespace source copies empty profile")
    db:ResetProfile(true)
    equal(child.profile.value, 6, "noChildren preserves loaded namespace")
    equal(unloaded.Active.nested.value, 43, "noChildren preserves unloaded namespace")
    db:ResetProfile()
    equal(db.profile.defaultValue, 7, "parent defaults restored")
    equal(child.profile.defaultValue, 9, "loaded namespace defaults restored")
    equal(unloaded.Active, nil, "unloaded namespace reset")
    db.sv.profileKeys["Other - AzerothCore"] = "Source"
    db.sv.profileKeys["Keep - AzerothCore"] = "Active"
    db:DeleteProfile("Source")
    equal(unloaded.Source, nil, "unloaded namespace profile deleted")
    equal(child.profiles.Source, nil, "loaded namespace profile deleted")
    equal(db.sv.profileKeys["Other - AzerothCore"], nil, "deleted profile selection removed")
    equal(db.sv.profileKeys["Keep - AzerothCore"], "Active", "unrelated selection preserved")
    equal(pcall(db.DeleteProfile, db, "Active"), false, "active profile deletion rejected")
    db:ResetDB(true)
    equal(db:GetCurrentProfile(), "Default", "ResetDB accepts New's default-profile flag")
    equal(child.keys.profile, "Default", "ResetDB retains namespace profile selection")
    db.sv.namespaces.EmptySaved = {profiles = {}}
    db.sv.namespaces.KeepSaved = {global = {value = 19}}
    local frame = env.LibStub("AceDB-3.0").frame
    frame:GetScript("OnEvent")(frame, "PLAYER_LOGOUT")
    equal(db.sv.namespaces.EmptySaved, nil, "logout removes empty saved namespace")
    equal(db.sv.namespaces.Loaded, nil, "logout removes loaded namespace after stripping defaults")
    equal(db.sv.namespaces.KeepSaved.global.value, 19, "logout preserves non-default namespace data")
end

do
    local env, loadLibrary = harness()
    loadLibrary("Libs/AceGUI-3.0/AceGUI-3.0.lua")
    local gui = env.LibStub("AceGUI-3.0")
    local released, hidden, callbacks = 0, 0, 0
    gui:RegisterWidgetType("RegressionWidget", function()
        local widget = {type = "RegressionWidget", frame = env.CreateFrame("Frame")}
        function widget:OnAcquire() self.frame:Show() end
        function widget:OnRelease() released = released + 1 end
        return gui:RegisterAsWidget(widget)
    end, 1)
    local widget = gui:Create("RegressionWidget")
    equal(widget:IsReleasing(), false, "widget exposes release state")
    widget:SetCallback("OnProbe", function(_, _, ...)
        equal(select("#", ...), 3, "GUI callback preserves argument count")
        equal(select(2, ...), nil, "GUI callback preserves nil argument")
        equal(select(3, ...), "tail", "GUI callback preserves trailing value")
    end)
    widget:Fire("OnProbe", "first", nil, "tail")
    widget.frame:SetScript("OnHide", function()
        hidden = hidden + 1
        equal(gui:IsReleasing(widget), true, "OnHide sees release in progress")
        gui:Release(widget)
    end)
    widget:SetCallback("OnRelease", function()
        callbacks = callbacks + 1
        equal(widget.frame.shown, false, "frame hidden before release callbacks")
        equal(gui:IsReleasing({parent = widget}), true, "child sees parent release")
        gui:Release(widget)
    end)
    gui:Release(widget)
    equal(hidden, 1, "OnHide runs once")
    equal(callbacks, 1, "release callback runs once")
    equal(released, 1, "widget cleanup runs once")
    equal(gui:IsReleasing(widget), false, "release flag cleared before reuse")
    equal(gui:Create("RegressionWidget"), widget, "released widget reused")
    gui:Release(widget)
    equal(released, 2, "reused widget can be released again")

    loadLibrary("Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
    loadLibrary("Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua")
    local dialog = env.LibStub("AceConfigDialog-3.0")
    assert(gui.tooltip ~= env.GameTooltip, "GUI owns a separate tooltip")
    assert(dialog.tooltip ~= env.GameTooltip, "settings own a separate tooltip")
    local function findUpvalue(func, name, seen)
        seen = seen or {}
        if seen[func] then return end
        seen[func] = true
        local functions = {}
        for i = 1, math.huge do
            local key, value = debug.getupvalue(func, i)
            if not key then break end
            if key == name then return value end
            if type(value) == "function" then functions[#functions + 1] = value end
        end
        for _, value in ipairs(functions) do
            local found = findUpvalue(value, name, seen)
            if found then return found end
        end
    end
    local build = assert(findUpvalue(dialog.FeedGroup, "BuildSortedOptionsTable"))
    local group = {type = "group", name = "Options", args = {
        last = {type = "description", name = "Last", order = -1},
        zero = {type = "description", name = "Zero", order = 0},
        first = {type = "description", name = "First", order = 1},
    }}
    local sorted = {}
    build(group, sorted, {}, group, {}, "Regression")
    equal(table.concat(sorted, ","), "zero,first,last", "zero order precedes positive and negative orders")
    local onHover = assert(findUpvalue(dialog.FeedGroup, "OptionOnMouseOver"))
    local option = {type = "description", name = "Linked", tooltipHyperlink = "item:123"}
    local registry = env.LibStub("AceConfigRegistry-3.0")
    registry:RegisterOptionsTable("HyperlinkRegression", {type = "group", name = "Links", args = {linked = option}})
    assert(registry:GetOptionsTable("HyperlinkRegression", "dialog", "AceConfigDialog-3.0"),
        "registry accepts hyperlink tooltip option")
    local linked = {frame = env.CreateFrame("Frame")}
    function linked:GetUserDataTable()
        return {option = option, options = {args = {linked = option}}, path = {"linked"}, appName = "Regression"}
    end
    onHover(linked, "OnEnter")
    equal(dialog.tooltip.link, "item:123", "option hyperlink uses isolated tooltip")
    equal(env.GameTooltip.link, nil, "gameplay tooltip left unchanged")
    local onClosed = assert(findUpvalue(dialog.FeedGroup, "MultiControlOnClosed"))
    local opened = 0
    local savedOpen = dialog.Open
    dialog.Open = function() opened = opened + 1 end
    local closing = {isQueuedForRelease = true}
    function closing:GetUserDataTable()
        return {valuechanged = true, appName = "Closing", rootframe = {GetUserData = function() end}}
    end
    onClosed(closing)
    equal(opened, 0, "closing widget does not reopen settings during release")
    local releaseCheck = gui.IsReleasing
    gui.IsReleasing = nil
    onClosed(closing)
    equal(opened, 1, "foreign GUI without release helper retains existing close behavior")
    gui.IsReleasing, dialog.Open = releaseCheck, savedOpen

    env.GetBuildInfo = function() return "3.3.5", "12340", "", 30300 end
    loadLibrary("Libs/AceGUI-3.0/widgets/AceGUIContainer-TreeGroup.lua")
    local treeMethods = assert(findUpvalue(gui.WidgetRegistry.TreeGroup, "methods"))
    local treeHover = assert(findUpvalue(treeMethods.CreateButton, "Button_OnEnter"))
    local treeButton = {obj = {enabletooltips = true, Fire = function() end},
        text = {GetText = function() return "Tree tooltip" end}}
    treeHover(treeButton)
    equal(gui.tooltip.text, "Tree tooltip", "tree uses isolated GUI tooltip")
    equal(env.GameTooltip.text, nil, "tree hover leaves gameplay tooltip unchanged")

    loadLibrary("Libs/AceGUI-3.0/widgets/AceGUIWidget-ColorPicker.lua")
    env.ColorPickerFrame = env.CreateFrame("Frame")
    env.OpacitySliderFrame = {GetValue = function() return 0.25 end}
    env.HideUIPanel = function(frame) frame:Hide() end
    env.ShowUIPanel = function(frame) frame:Show() end
    local picker = gui:Create("ColorPicker")
    picker:SetHasAlpha(true)
    picker:SetColor(0.2, 0.3, 0.4, 0.6)
    picker.frame:GetScript("OnClick")(picker.frame)
    near(env.ColorPickerFrame.opacity, 0.4, "3.3.5 opacity slider uses inverted alpha")
    env.ColorPickerFrame:SetColorRGB(0.8, 0.7, 0.6)
    env.ColorPickerFrame.opacityFunc()
    near(picker.a, 0.75, "live picker opacity converted to alpha")
    env.ColorPickerFrame.cancelFunc()
    near(picker.r, 0.2, "picker cancel restores original color")
    near(picker.a, 0.6, "picker cancel restores original alpha")
end

do
    local env, loadLibrary, frames = harness()
    loadLibrary("Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
    local path = "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua"
    loadLibrary(path)
    local lib = env.LibStub("LibDBIcon-1.0")
    local object = env.LibStub("LibDataBroker-1.1"):NewDataObject("Regression", {icon = "icon.blp"})
    local db = {minimapPos = 45}
    lib:Register("Regression", object, db)
    lib:Register("BeforeLogin", object, {hide = true})
    equal(lib:GetMinimapButton("BeforeLogin").shown, false, "hidden button stays hidden before login")
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_LOGIN then frame.scripts.OnEvent(frame, "PLAYER_LOGIN") end
    end
    local button = assert(lib:GetMinimapButton("Regression"))
    near(button.point[4], math.sqrt(0.5)*80, "stock minimap position preserved")
    env.Minimap.width, env.Minimap.height = 250, 150
    env.Minimap.scripts.OnSizeChanged(env.Minimap)
    near(button.point[4], math.sqrt(0.5)*130, "button follows resized minimap width")
    near(button.point[5], math.sqrt(0.5)*80, "button follows resized minimap height")
    button:SetParent(env.UIParent)
    button:SetPoint("CENTER", env.UIParent, "CENTER", 17, 23)
    env.Minimap.scripts.OnSizeChanged(env.Minimap)
    equal(button.point[2], env.UIParent, "resize preserves detached button anchor")
    equal(button.point[4], 17, "resize preserves detached button position")
    button:SetParent(env.Minimap)
    env.shape = "UNKNOWN-CUSTOM-SHAPE"
    lib:Refresh("Regression")
    near(button.point[4], math.sqrt(0.5)*130, "unknown minimap shape falls back to round")
    env.Minimap.width, env.Minimap.height = 150, 150
    env.shape = "SIDE-LEFT"
    db.minimapPos = 45
    lib:Refresh("Regression")
    near(button.point[4], 72.928932188135, "square upper-right quadrant follows straight edge")
    db.minimapPos = 135
    lib:Refresh("Regression")
    near(button.point[4], -math.sqrt(0.5)*80, "round upper-left quadrant follows curve")
    lib:SetButtonRadius(10)
    near(button.point[4], -math.sqrt(0.5)*85, "radius adjustment applied")
    lib:SetButtonRadius(0/0)
    equal(lib.radius, 10, "invalid radius ignored")
    db.hide = true
    lib:Refresh("Regression")
    equal(button.shown, false, "Refresh without db preserves saved hide setting")
    lib:Show("Regression")
    equal(button.shown, true, "explicit Show still overrides saved visibility")
    button.scripts.OnDragStart(button)
    equal(button.isMoving, true, "button can drag")
    button.scripts.OnDragStop(button)
    equal(button.isMoving, nil, "drag stops on release")
    equal(button.scripts.OnUpdate, nil, "drag update removed on release")
    local originalStart, originalStop = button.scripts.OnDragStart, button.scripts.OnDragStop
    local wrappedStart = function(self) originalStart(self) end
    local wrappedStops = 0
    local wrappedStop = function(self) wrappedStops = wrappedStops + 1; originalStop(self) end
    button:SetScript("OnDragStart", wrappedStart)
    button:SetScript("OnDragStop", wrappedStop)
    lib:Refresh("Regression")
    equal(button.scripts.OnDragStart, wrappedStart, "Refresh preserves addon drag wrappers")
    button.scripts.OnDragStart(button)
    button.scripts.OnDragStop(button)
    equal(wrappedStops, 1, "addon drag cleanup runs")
    object.icon = "replacement.blp"
    equal(button.icon.texture, "replacement.blp", "legacy callback dispatcher retains arguments")
    object.iconCoords = {0.2, 0.6, 0.1, 0.9}
    near(button.icon.texCoord[1], 0.22, "broker coordinates crop within source image")
    button:GetScript("OnMouseDown")(button)
    near(button.icon.texCoord[1], 0.2, "pressed icon uses full source coordinates")
    button:GetScript("OnMouseUp")(button)
    near(button.icon.texCoord[1], 0.22, "released icon restores cropped source coordinates")
    object.iconR, object.iconG = 0.25, 0.5
    near(button.icon.vertexColor[1], 0.25, "broker red channel updates")
    near(button.icon.vertexColor[2], 0.5, "broker green channel updates")
    near(button.icon.vertexColor[3], 1, "broker update preserves other channels")
    object.iconR = nil
    near(button.icon.vertexColor[1], 1, "cleared broker channel restores white")
    near(button.icon.vertexColor[2], 0.5, "cleared broker channel preserves other color")
    object.OnTooltipShow = function(tooltip) tooltip:SetText("Minimap tooltip") end
    button:GetScript("OnEnter")(button)
    equal(lib.tooltip.text, "Minimap tooltip", "minimap button uses isolated tooltip")
    equal(env.GameTooltip.text, nil, "minimap tooltip leaves gameplay tooltip unchanged")
    button:GetScript("OnLeave")(button)
    equal(lib.tooltip.shown, false, "minimap tooltip hides on leave")
    lib:Show("Missing")
    lib:Refresh("Missing")
    lib:Register("Hidden", object, {hide = true})
    local hidden = assert(lib:GetMinimapButton("Hidden"))
    equal(hidden.shown, false, "deferred hidden registration stays hidden")
    lib:Register("Disabled", object, {hide = true})
    lib:DisableLibrary()
    equal(lib:GetMinimapButton("Disabled").shown, false, "getter does not show disabled library buttons")
    lib:EnableLibrary()

    -- Exercise a real LibStub upgrade without recreating registered buttons or hooks.
    local sizeHook = env.Minimap.scripts.OnSizeChanged
    env.LibStub.minors["LibDBIcon-1.0"] = 15
    loadLibrary(path)
    equal(button.scripts.OnDragStart, wrappedStart, "upgrade preserves addon drag wrapper")
    button.scripts.OnDragStart(button)
    env.LibStub.minors["LibDBIcon-1.0"] = 15
    loadLibrary(path)
    equal(lib:GetMinimapButton("Regression"), button, "library upgrade preserves button identity")
    equal(button.shown, false, "library upgrade preserves hidden button")
    button.scripts.OnDragStop(button)
    equal(button.isMoving, nil, "addon drag stop survives library upgrade")
    equal(button.scripts.OnUpdate, nil, "addon drag update cleanup survives library upgrade")
    equal(env.Minimap.scripts.OnSizeChanged, sizeHook, "library upgrade does not add duplicate resize hooks")
    env.LibStub.minors["LibDBIcon-1.0"] = 99
    local refresh = lib.Refresh
    loadLibrary(path)
    equal(lib.Refresh, refresh, "newer embedded copies are not overwritten")
end

print("Embedded library regressions passed (profiles, widget release, option ordering, minimap buttons)")
