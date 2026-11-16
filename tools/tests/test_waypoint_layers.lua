-- Run from the addon root with Lua 5.1 or 5.2. Exercise real patrol modules with native 3.3.5 frame APIs.
local unpack = unpack or table.unpack
local function equal(a, b, label) assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function near(a, b, label) assert(math.abs(a - b) < 1e-5, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function harness()
    local env = setmetatable({}, {__index = _G})
    env._G, env.unpack = env, unpack
    local modules, frames = {}, {}
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    local methods = {}
    function methods:SetScript(event, value) self.scripts[event] = value end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:SetParent(parent) self.parent = parent end
    function methods:GetParent() return self.parent end
    function methods:EnableMouse(enabled) self.mouse = enabled end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:GetFrameLevel() return self.level or 1 end
    function methods:SetFrameStrata(strata) self.strata = strata end
    function methods:GetFrameStrata() return self.strata or "MEDIUM" end
    function methods:SetPoint(...) self.point = {...} end
    function methods:ClearAllPoints() self.point = nil end
    function methods:SetSize(w, h) self.w, self.h = w, h end
    function methods:SetAllPoints(root) self.w, self.h = root.w, root.h end
    function methods:GetWidth() return self.w end
    function methods:GetHeight() return self.h end
    function methods:GetLeft() return self.left or 0 end
    function methods:GetTop() return self.top or 200 end
    function methods:GetEffectiveScale() return self.scale or 1 end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:SetOwner(owner) self.owner = owner end
    function methods:ClearLines() self.linesCleared = true end
    function methods:Hide() self.shown = false end
    function methods:Show() self.shown = true end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:IsShown() return self.shown end
    function methods:SetTexture(path) self.asset = path end
    function methods:SetVertexColor(...) self.color = {...} end
    function methods:GetVertexColor() return unpack(self.color or {1, 1, 1, 1}) end
    function methods:SetTexCoord(...)
        local coords = {...}
        for _, v in ipairs(coords) do assert(v == v and math.abs(v) < math.huge, "finite UV coordinates") end
        self.uv = coords
    end
    function methods:GetZoom() return env.zoom or 0 end
    function methods:SetMaskTexture(path) self.mask = path end
    env.hooksecurefunc = function(frame, method, callback)
        local original = frame[method]
        frame[method] = function(self, ...)
            original(self, ...)
            callback(self, ...)
        end
    end
    env.CreateFrame = function(kind, name, parent)
        local frame = setmetatable({kind = kind, scripts = {}, parent = parent, shown = true, w = 200, h = 200},
            {__index = methods})
        frames[#frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    function methods:CreateTexture() return env.CreateFrame("Texture", nil, self) end
    env.UIParent = env.CreateFrame("Frame")
    env.WorldMapButton = env.CreateFrame("Button", nil, env.UIParent)
    env.Minimap = env.CreateFrame("Minimap", nil, env.UIParent)
    env.Minimap.left = 300
    local map = module("QuestieMap")
    map.utils = {SetLineDrawOrder = function(frame) frame:SetFrameLevel(2) end}
    module("ZoneDB").GetUiMapIdByAreaId = function(_, id) return id == 12 and 1 or nil end
    module("QuestieLib").AddonPath = "Interface\\Addons\\Questie-335\\"
    env.mapId, env.playerX, env.playerY, env.instance, env.radius, env.focus = 1, 500, 500, 0, 100, nil
    local positions = 0
    env.QuestieCompat = {WorldMapFrame = {GetCanvas = function() return env.WorldMapButton end,
        GetMapID = function() return env.mapId end},
        HBD = {GetWorldCoordinatesFromZone = function(_, x, y) return 1000 - 1000*x, 1000 - 1000*y, 0 end},
        HBDPins = {Minimap = env.Minimap, GetMinimapView = function() return env.radius, env.rotating end},
        GetCurrentPlayerMinimapWorldPosition = function()
            positions = positions + 1
            return env.playerX, env.playerY, env.instance
        end}
    env.GetMouseFocus = function() return env.focus end
    env.GetCursorPosition = function() return env.cursorX or 0, env.cursorY or 0 end
    env.GetPlayerFacing = function() return env.facing or 0 end
    env.IsShiftKeyDown = function() return env.shift or false end
    env.GetMinimapShape = function() return env.shape or "ROUND" end
    env.Questie = {db = {profile = {enabled = true, enableMapIcons = true, enableMiniMapIcons = true,
        showWaypointLines = true, waypointMinimapEnabled = true, waypointWidth = 3, waypointSmoothing = 0.75,
        waypointOpacity = 1, iconFadeLevel = 0.3, waypointColor = {1, 0.72, 0, 0.5},
        waypointHostileColor = {1, 0.2, 0, 0.7}, waypointHighlightColor = {0.93, 0.46, 0.13, 0.8},
        waypointHighlight = true}}}
    module("MapIconTooltip").ShowOnTooltip = function(icon, tooltip, owner, icons)
        env.tooltipCall = {icon = icon, tooltip = tooltip, owner = owner, icons = icons}
        tooltip:SetOwner(owner)
        tooltip._Rebuild = function(self)
            self.rebuilds = (self.rebuilds or 0) + 1
            self.shift = env.IsShiftKeyDown()
        end
        tooltip:Show()
    end
    local function loadFile(path)
        local chunk
        if setfenv then chunk = setfenv(assert(loadfile(path)), env)
        else chunk = assert(loadfile(path, "t", env)) end
        return chunk()
    end
    loadFile("Modules/Map/Waypoints/WaypointGeometry.lua")
    loadFile("Modules/Map/Waypoints/WaypointRenderer.lua")
    loadFile("Modules/Map/Waypoints/QuestieWaypoints.lua")
    local function icon(id)
        local owner = env.CreateFrame("Button", nil, env.WorldMapButton)
        owner.data, owner._loaded = {Id = id}, true
        owner.texture = owner:CreateTexture()
        local twin = env.CreateFrame("Button", nil, env.Minimap)
        twin.data, twin.texture = owner.data, twin:CreateTexture()
        owner.minimapTwin, twin.waypointOwner = twin, owner
        owner:SetScript("OnLeave", function() env.leaves = (env.leaves or 0) + 1 end)
        return owner
    end
    local function visible(root)
        local result = {}
        for _, frame in ipairs(frames) do
            if frame.lines and frame.parent == root and frame:IsVisible() then result[#result + 1] = frame end
        end
        return result
    end
    return env, modules, frames, icon, visible, loadFile
end

do
    local env, mods = harness()
    local g = mods.WaypointGeometry
    local patrols = {{{10, 20}, {20, 20}, {30, 20}, {-1, -1}, {40, 50}, {50, 50}}}
    local paths = g.BuildPolylines(patrols, 1, function(x, y) return x*1000, y*1000, 0 end)
    equal(#paths, 2, "invalid points split paths")
    equal(#paths[1].points, 2, "collinear subdivision removed")
    equal(paths[1].points[2].x, 30, "real segment end preserved")
    equal(patrols[1][2][1], 20, "source patrol data remains unchanged")
    local corner = {{x = 0, y = 0}, {x = 50, y = 0}, {x = 50, y = 50}}
    equal(#g.Smooth(corner, 0, 2), 3, "zero smoothing keeps original corners")
    assert(#g.Smooth(corner, 1.125, 2) > 3, "default smoothing samples curve")
    local line = {{x = -200, y = 0}, {x = 200, y = 0}}
    local clipped = g.Clip(line, {-100, -100, 100, 100}, {true, true, true, true}, 12)
    equal(#clipped, 2, "player arrow hole splits crossing segment")
    near(clipped[1][1].x, -100, "circle entry")
    near(clipped[1][#clipped[1]].x, -12, "left edge of player hole")
    near(clipped[2][1].x, 12, "right edge of player hole")
    near(clipped[2][#clipped[2]].x, 100, "circle exit")
    local diagonal = {{x = 80, y = 80}, {x = 90, y = 90}}
    equal(#g.Clip(diagonal, {-100, -100, 100, 100}, {true, true, true, true}), 0, "round corners clipped")
    equal(#g.Clip(diagonal, {-100, -100, 100, 100}, {false, false, false, false}), 1, "square corners retained")
    local mask = g.MaskEdges({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}, 200, 100, 5)
    assert(g.InsideMask(mask, 5, 50), "stroke-inset mask boundary included")
    assert(not g.InsideMask(mask, 4, 50), "stroke-inset mask excludes outer stroke margin")
    local masked = g.Clip({{x = -50, y = 50}, {x = 250, y = 50}}, {0, 0, 200, 100}, nil, nil, mask)
    near(masked[1][1].x, 5, "polygon clips entry against inset edge")
    near(masked[1][#masked[1]].x, 195, "polygon clips exit against inset edge")
    local texture = env.CreateFrame("Texture")
    mods.WaypointRenderer.Segment(texture, env.WorldMapButton, {x = 0, y = 0}, {x = 100, y = 0}, 4)
    near(texture.w, 100, "native strip length")
    near(texture.h, 4, "native strip width")
    assert(texture.uv[1] < texture.uv[5], "horizontal strip maps texture along segment")
    mods.WaypointRenderer.Segment(texture, env.WorldMapButton, {x = 0, y = 0}, {x = 0, y = 100}, 4)
    near(texture.w, 4, "vertical strip width")
    near(texture.h, 100, "vertical strip length")
    local renderer = mods.WaypointRenderer
    local view = renderer.New(env.WorldMapButton)
    local curve = g.Smooth(corner, 1.5, 2)
    renderer.Draw(view, {curve}, 3, {1, 0.72, 0, 0.5}, 1)
    equal(#view.caps, 2, "sampled curve has no interior outlined discs")
    renderer.Draw(view, {{{x = 0, y = 0}, {x = 30, y = 0}, {x = 30, y = 30}, {x = 0, y = 0}}},
        3, {1, 0.72, 0, 0.5}, 1)
    for _, cap in ipairs(view.caps) do equal(cap.shown, false, "closed loop seam has no endpoint disc") end
    local clippedLoop = g.Clip({{x = 10.1, y = 10.1}, {x = 100.1, y = 10.1},
        {x = 100.1, y = 100.1}, {x = 10.1, y = 10.1}}, {0, 0, 200, 200})
    renderer.Draw(view, clippedLoop, 3, {1, 0.72, 0, 0.5}, 1)
    for _, cap in ipairs(view.caps) do equal(cap.shown, false, "clipping roundoff does not add closed-loop seam discs") end
end

do
    local env, mods, _, makeIcon, visible = harness()
    local maskPath = "Interface\\AddOns\\DragonUI\\Textures\\Minimap\\uiminimapmask.tga"
    env.DragonUI = {MinimapModule = {activeMask = maskPath}}
    local w = mods.QuestieWaypoints
    w.Add(makeIcon(1), "m_10666", {{{40, 50}, {60, 50}}}, 12, false)
    w.Update()
    local function leftEdge()
        local left = math.huge
        for _, texture in ipairs(visible(env.Minimap)[1].lines) do
            if texture.shown then left = math.min(left, texture.point[4]) end
        end
        return left
    end
    assert(leftEdge() > 10, "already-applied DragonUI mask clips inside inset opaque outline")
    env.focus, env.cursorX, env.cursorY = env.Minimap, 306, 100
    w.Update()
    equal(env.tooltipCall, nil, "outside DragonUI mask cannot hover patrol")
    env.cursorX = 330
    w.Update()
    equal(env.tooltipCall.owner, env.Minimap, "inside DragonUI mask can hover patrol")
    env.focus = nil
    env.Minimap:SetMaskTexture("Textures\\MinimapMask")
    w.Update()
    assert(leftEdge() < 5, "mask hook restores native round clipping without player movement")
    env.Minimap:SetMaskTexture(maskPath:upper():gsub("\\", "/"))
    w.Update()
    assert(leftEdge() > 10, "mask hook recognizes path case and slash changes")
end

do
    local env, mods, frames, icon, visible = harness()
    local w = mods.QuestieWaypoints
    local route = {{{40, 50}, {50, 50}, {60, 50}}}
    local first, second = icon(1), icon(2)
    w.Add(first, "m_10666", route, 12, false)
    w.Add(first, "m_10666", route, 12, false)
    w.Add(second, "m_10666", route, 12, false)
    local count = 0
    for _ in pairs(w.paths) do count = count + 1 end
    equal(count, 2, "repeated owner registration is idempotent")
    w.Update()
    equal(#visible(env.WorldMapButton), 1, "shared NPC route draws once on world map")
    equal(#visible(env.Minimap), 1, "shared NPC route draws once on minimap")
    first.minimapTwin:Hide()
    first.minimapTwin.texture:SetVertexColor(1, 1, 1, 0)
    near(w.Alpha(next(w.paths), true), 1, "range-hidden icon does not hide entire patrol")
    env.focus, env.cursorX, env.cursorY = env.Minimap, 370, 100
    w.Update()
    equal(env.tooltipCall.owner, env.Minimap, "minimap owns path tooltip")
    equal(#env.tooltipCall.icons, 2, "path tooltip includes all route owners, even range-hidden icons")
    env.shift = true
    w.Update()
    equal(env.tooltipCall.tooltip.rebuilds, 1, "Shift rebuilds stationary patrol tooltip")
    equal(env.tooltipCall.tooltip.shift, true, "patrol tooltip sees changed modifier")
    equal(env.tooltipCall.tooltip.owner, env.Minimap, "Shift preserves minimap tooltip ownership")
    env.focus = first.minimapTwin
    w.Update()
    equal(env.tooltipCall.tooltip.shown, false, "icon hover wins over path hover")
    env.focus = nil
    first.hidden, second.hidden = true, true
    w.OwnerChanged(first); w.Update()
    equal(#visible(env.WorldMapButton), 0, "hidden world owners hide world route")
    equal(#visible(env.Minimap), 1, "world hide does not hide independent minimap twin")
    first.hidden, second.hidden = false, false
    first.faded, second.faded = true, false
    w.OwnerChanged(first); w.Update()
    near(visible(env.WorldMapButton)[1].alpha, 1, "most visible owner supplies shared route")
    second.hidden = true
    w.OwnerChanged(second); w.Update()
    near(visible(env.WorldMapButton)[1].alpha, 0.3, "route uses profile fade setting")
    second.hidden = false
    w.SetSolo({[first.data] = true}); w.Update()
    near(visible(env.WorldMapButton)[1].alpha, 0.3, "tracker flash selects flashed owner")
    w.SetSolo({}); w.Update()
    equal(#visible(env.WorldMapButton), 0, "tracker flash hides manual and other routes")
    equal(#visible(env.Minimap), 1, "tracker flash only isolates world paths")
    w.SetSolo(nil)
    env.mapId = 2
    w.Update()
    equal(#visible(env.WorldMapButton), 0, "route never draws on another map")
    env.WorldMapButton:Hide()
    w.Update()
    equal(#visible(env.Minimap), 1, "minimap works while world map is closed")
    env.WorldMapButton:Show(); env.mapId = 1
    env.rotating, env.facing = true, math.pi / 2
    w.Update()
    local view = visible(env.Minimap)[1]
    local vertical = false
    for _, texture in ipairs(view.lines) do if texture.shown and texture.h > texture.w then vertical = true end end
    assert(vertical, "rotating minimap projects horizontal route vertically")
    env.playerX = nil
    w.Update()
    equal(#visible(env.Minimap), 0, "missing player position hides minimap paths")
    env.playerX = 500
    env.focus, env.cursorX, env.cursorY = env.Minimap, 400, 130
    w.Update()
    equal(env.tooltipCall.tooltip.owner, env.Minimap, "hover active before minimap replacement")
    local replacement = env.CreateFrame("Minimap", nil, env.UIParent)
    replacement.left = 300
    env.QuestieCompat.HBDPins.Minimap = replacement
    env.focus = replacement
    w.Update()
    equal(#visible(env.Minimap), 0, "replaced minimap loses old route frames while stationary")
    equal(#visible(replacement), 1, "replacement minimap receives route frames while stationary")
    equal(env.tooltipCall.tooltip.owner, replacement, "hover transfers to replacement minimap at same cursor position")
    env.QuestieCompat.HBDPins.Minimap = env.Minimap
    env.focus = nil
    w.Update()
    env.Questie.db.profile.showWaypointLines = false
    w.Refresh(); w.Update()
    equal(#visible(env.WorldMapButton), 0, "existing map toggle preserved")
    env.Questie.db.profile.waypointMinimapEnabled = false
    w.Refresh(); w.Update()
    equal(#visible(env.Minimap), 0, "independent minimap toggle")
    w.RemoveOwner(first); w.RemoveOwner(second)
    equal(next(w.paths), nil, "owner unload releases registry entries")
end

do
    local env, mods, frames, icon, visible = harness()
    local w = mods.QuestieWaypoints
    local first, second = icon(1), icon(2)
    local route = {{{40, 50}, {60, 50}}}
    w.Add(first, "m_10617", route, 12, false)
    w.Add(second, "m_10617", route, 12, true)
    w.Update()
    near(visible(env.WorldMapButton)[1].lines[1].color[2], 0.2, "hostile owner wins shared color tie")
    env.Questie.db.profile.waypointOpacity = 0.5
    w.Refresh(); w.Update()
    near(visible(env.WorldMapButton)[1].lines[1].color[4], 0.35, "global opacity multiplies color alpha")
    w.RemoveOwner(first)
    w.Update()
    equal(#visible(env.WorldMapButton), 1, "remaining owner retains route")
    w.RemoveOwner(second)
    equal(#visible(env.WorldMapButton), 0, "last owner unload hides route immediately")
    first.data, first._loaded = {Id = 3}, false
    w.Add(first, "m_1721", route, 12, false)
    w.Update()
    equal(#visible(env.WorldMapButton), 0, "queued icon does not draw early")
    w.RemoveOwner(first)
    equal(next(w.paths), nil, "queued unload removes patrol before frame reuse")
    first._loaded = true
    w.Add(first, "m_1721", route, 12, false)
    w.Update()
    local views = 0
    for _, frame in ipairs(frames) do if frame.lines then views = views + 1 end end
    equal(views, 2, "route views reused across NPC identities on both maps")
    for _, frame in ipairs(frames) do if frame.lines then equal(frame.mouse, false, "route views are click-through") end end
end

do
    local env, mods, _, makeIcon, visible, loadFile = harness()
    setmetatable(env.QuestieLoader:ImportModule("l10n"), {__call = function(_, text) return text end})
    local options = env.QuestieLoader:ImportModule("QuestieOptions")
    options.tabs = {}
    options.GetProfileValue = function(_, info) return env.Questie.db.profile[info[#info]] end
    options.SetProfileValue = function(_, info, value) env.Questie.db.profile[info[#info]] = value end
    loadFile("Modules/Options/QuestieOptionsDefaults.lua")
    equal(mods.QuestieOptionsDefaults:Load().profile.waypointSmoothing, 0.75, "new profile smoothing default")
    loadFile("Modules/Options/MapTab/QuestieOptionsMap.lua")
    local settings = options.tabs.map:Initialize().args
    assert(settings.showWaypointLines and settings.worldMapButtonPosition, "existing Map tab controls retained")
    local localization = mods.l10n
    localization.translations = {}
    loadFile("Localization/Translations/Options/Map.lua")
    for key, setting in pairs(settings) do
        if key:lower():find("waypoint", 1, true) then
            for _, field in ipairs({"name", "desc"}) do
                if setting[field] then
                    local text = type(setting[field]) == "function" and setting[field]() or setting[field]
                    local translations = assert(localization.translations[text], "missing waypoint key: " .. text)
                    for _, locale in ipairs({"enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "zhCN", "zhTW", "koKR"}) do
                        assert(translations[locale], text .. " missing " .. locale)
                        if locale ~= "enUS" then
                            assert(type(translations[locale]) == "string" and translations[locale] ~= text,
                                text .. " lacks translated text for " .. locale)
                        end
                    end
                end
            end
        end
    end
    local owner = makeIcon(1)
    mods.QuestieWaypoints.Add(owner, "m_10666", {{{40, 50}, {60, 50}}}, 12, false)
    mods.QuestieWaypoints.Update()
    settings.waypointColor.set({"waypointColor"}, 0.2, 0.4, 0.6, 0.8)
    mods.QuestieWaypoints.Update()
    local texture = visible(env.WorldMapButton)[1].lines[1]
    near(texture.color[2], 0.4, "Map color picker restyles existing path")
    near(texture.color[4], 0.8, "Map color picker preserves opacity")
    settings.waypointMinimapEnabled.set({"waypointMinimapEnabled"}, false)
    mods.QuestieWaypoints.Update()
    equal(#visible(env.Minimap), 0, "Map toggle hides minimap layer live")
    env.Questie.db.profile.showWaypointLines = false
    env.Questie.db.profile.waypointMinimapEnabled = true
    env.Questie.db.profile.migrationVersion = 31
    env.Questie.Debug = function() end
    env.table = setmetatable({getn = function(t) return #t end}, {__index = table})
    loadFile("Modules/Migration.lua")
    mods.Migration:Migrate()
    equal(env.Questie.db.profile.waypointMinimapEnabled, false, "migration preserves previous all-lines-disabled preference")
    equal(env.Questie.db.profile.migrationVersion, 32, "migration advances existing profile")
end

do
    local env, mods, _, _, _, loadFile = harness()
    env.QuestieLoader:ImportModule("QuestieDB").questTagIds = setmetatable({}, {__index = function(_, key) return key end})
    env.QUEST_MONSTERS_KILLED, env.QUEST_ITEMS_NEEDED, env.QUEST_OBJECTS_FOUND = "Slain", "Items", "Found"
    loadFile("Modules/Libs/QuestieLib.lua")
    local lib = mods.QuestieLib
    local levels = {[1] = 20, [2] = 5, [3] = 5}
    lib.GetEffectiveQuestLevel = function(id) return levels[id] end
    lib.GetQuestTypeSuffix = function() return "" end
    local ids = lib:SortQuestIDsByLevel({[1] = true, [2] = true, [3] = true}, true)
    equal(table.concat(ids, ","), "2,3,1", "tooltip order uses level then stable ID")
    local entries = lib:SortQuestIDsByLevel({[1] = true})
    equal(entries[1][2], 1, "existing Journey sorting return format preserved")
end

do
    local env, mods, _, makeIcon, _, loadFile = harness()
    env.GetTime = function() return 100 end
    env.IsShiftKeyDown = function() return false end
    env.GameTooltip = env.CreateFrame("GameTooltip")
    env.Questie.Debug = function() end
    env.tinsert = table.insert
    setmetatable(mods.l10n or env.QuestieLoader:ImportModule("l10n"), {__call = function(_, text) return text end})
    local sentinel = "stop after collecting tooltip entries"
    env.QuestieLoader:ImportModule("TooltipLayout").CreateRows = function() error(sentinel) end
    loadFile("Modules/Tooltips/MapIconTooltip.lua")
    local show = mods.MapIconTooltip.ShowOnTooltip
    local private
    for index = 1, 100 do
        local name, value = debug.getupvalue(show, index)
        if name == "_MapIconTooltip" then private = value; break end
    end
    assert(private, "real tooltip collector found")
    private.IsMinimapInside = function() return false end
    private.GetAvailableOrCompleteTooltip = function(_, icon)
        return {questId = icon.data.Id, title = "Quest " .. icon.data.Id}
    end
    local first, second = makeIcon(1).minimapTwin, makeIcon(2).minimapTwin
    first.miniMapIcon, second.miniMapIcon = true, true
    first.data.Type, second.data.Type = "available", "available"
    first.data.Name, second.data.Name = "Patrol NPC", "Patrol NPC"
    first.AreaID, second.AreaID = 12, 12
    first.x, first.y, second.x, second.y = 40, 50, 60, 50
    first.texture:SetVertexColor(1, 1, 1, 0)
    second.texture:SetVertexColor(1, 1, 1, 0)
    env.QuestieCompat.HBDPins.activeMinimapPins = {[first] = true, [second] = true}
    local tip = env.CreateFrame("GameTooltip")
    local ok, err = pcall(show, first, tip, env.Minimap, {first, second})
    assert(not ok and tostring(err):find(sentinel, 1, true), tostring(err))
    assert(tip.npcAndObjectOrder["Patrol NPC"]["Quest 1"], "faded active icon remains in explicit path tooltip")
    assert(tip.npcAndObjectOrder["Patrol NPC"]["Quest 2"], "distant faded route owner remains in path tooltip")
    equal(tip._owner, env.Minimap, "path tooltip rebuild owner remains map root")

    -- An unloading route can share a tooltip with live routes. Skip its local objective, not the whole cluster.
    local player = env.QuestieLoader:ImportModule("QuestiePlayer")
    local cache = env.QuestieLoader:ImportModule("QuestLogCache")
    player.currentQuestlog = {[2] = {}}
    local cached = {[2] = {}}
    cache.TryGetQuest = function(id) return cached[id] end
    local oldObjectiveTooltip = private.GetObjectiveTooltip
    private.GetObjectiveTooltip = function() return {} end
    first.data.Type, second.data.Type = "monster", "monster"
    first.data.ObjectiveData = {Description = "Removed objective", Update = function() error("removed objective updated") end}
    second.data.ObjectiveData = {Description = "Live objective", Update = function() end}
    local function collect()
        local ok, message = pcall(show, first, tip, env.Minimap, {first, second})
        assert(not ok and tostring(message):find(sentinel, 1, true), tostring(message))
    end
    collect()
    assert(not tip.questOrder[1] and tip.questOrder[2], "retired local objective cannot hide a live cluster member")
    player.currentQuestlog[1] = {}
    collect()
    assert(not tip.questOrder[1], "an objective whose cache was removed stays out of map tooltips")
    player.currentQuestlog[1] = nil
    first.data.ObjectiveData.IsPartyObjective = true
    first.data.ObjectiveData.Update = function() end
    collect()
    assert(tip.questOrder[1] and tip.questOrder[2], "party objectives survive without local quest membership or cache")
    private.GetObjectiveTooltip = oldObjectiveTooltip
    first.data.Type, second.data.Type = "available", "available"
    first.data.ObjectiveData, second.data.ObjectiveData = nil, nil
    collect()

    -- Rebuild the real chain tooltip with only its row/title rendering stubbed.
    local titles, reasons = {}, {}
    local db, lib = mods.QuestieDB, mods.QuestieLib
    db.DoableStates = {WRONG_RACE = 1, WRONG_CLASS = 2, PROFESSION_MISSING = 3, PROFESSION_SPECIALIZATION = 4}
    db.GetQuest = function() end
    db.QueryQuestSingle = function(id, field) if field == "nextQuestInChain" then return id < 3 and id + 1 or 0 end end
    db.IsDoableVerbose = function(id) return "Unavailable", true, reasons[id] end
    mods.QuestieCorrections.hiddenQuests, mods.QuestieCorrections.questTooltipHints = {}, {}
    mods.QuestieReputation.GetReputationReward = function() end
    lib.GetEffectiveQuestLevel = function() return 10 end
    lib.SortQuestIDsByLevel = function(_, entries)
        local ids = {}
        for id in pairs(entries) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end
    private.GetNextQuestInChainLines = function(id) return "Follow-up " .. id, "" end
    mods.TooltipLayout.CreateRows = function()
        return {AddLine = function() end, AddDoubleLine = function(_, title) titles[#titles + 1] = title end}
    end
    mods.TooltipLayout.Render = function() end
    tip.npcAndObjectOrder = {["NPC"] = {{questId = 1, title = "Quest 1", type = ""}}}
    tip.questOrder, tip.manualOrder = {}, {}
    env.IsShiftKeyDown = function() return true end
    env.Questie.db.profile.enableTooltipsNextInChain = true
    local function rebuild(firstReason, secondReason)
        titles, reasons[2], reasons[3] = {}, firstReason, secondReason
        tip:_Rebuild()
        return table.concat(titles, "|")
    end
    for _, reason in pairs(db.DoableStates) do
        assert(not rebuild(reason):find("Follow-up", 1, true), "ineligible profession/race/class stops before the first follow-up")
    end
    local later = rebuild(nil, db.DoableStates.PROFESSION_SPECIALIZATION)
    assert(later:find("Follow-up 2", 1, true) and not later:find("Follow-up 3", 1, true),
        "each hop checks specialization before adding its title")
    local ordinary = rebuild()
    assert(ordinary:find("Follow-up 2", 1, true) and ordinary:find("Follow-up 3", 1, true),
        "ordinary chains retain all follow-ups")
end

do
    local env, mods, _, _, _, loadFile = harness()
    env.bit = bit or bit32 or {band = function() return 0 end}
    env.Questie.Debug = function() end
    env.Questie.Error = error
    env.QuestieCompat.C_QuestLog = {}
    mods.ZoneDB.zoneIDs = {ICECROWN = 210}
    loadFile("Database/QuestieDB.lua")
    loadFile("Database/itemDB.lua")
    local db = mods.QuestieDB
    mods.QuestieCorrections.questItemBlacklist = {}
    db.QueryItem = function()
        return {[db.itemKeys.npcDrops] = {101}, [db.itemKeys.vendors] = {102, 103}}
    end
    db.QueryNPCSingle = function(id) return id == 103 and "opposite" or "friendly" end
    db.IsFriendlyToPlayer = function(faction) return faction == "friendly" end
    local item = db:GetItem(999)
    equal(#item.Sources, 2, "opposite-faction vendor remains excluded")
    equal(item.Sources[1].Vendor, nil, "drop source remains hostile")
    equal(item.Sources[2].Vendor, true, "friendly vendor metadata survives item adapter")
    loadFile("Modules/Quest/QuestieQuestPrivates.lua")
    db.GetItem = function() return item end
    local builders = mods.QuestieQuest.private.objectiveSpawnListCallTable
    builders.monster = function(id)
        return {[id] = {Name = "NPC " .. id, TooltipKey = "m_" .. id,
            Spawns = {[12] = {{50, 50}}}, Waypoints = {[12] = {{{40, 50}, {60, 50}}}}}}
    end
    local sources = builders.item(999, {})
    equal(sources[101].Hostile, true, "item drop patrol uses hostile color")
    equal(sources[102].Hostile, false, "vendor patrol uses normal color")
    assert(sources[102].Waypoints[12], "vendor patrol geometry preserved")
end

print("3.3.5 waypoint regressions passed (geometry, renderer, ownership, minimap, hover, visibility, tooltips and vendors)")
