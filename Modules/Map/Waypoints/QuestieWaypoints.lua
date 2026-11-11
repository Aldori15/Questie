-- Patrol layers adapted from Questie PR #8026 (Logonz) for the native 3.3.5 maps.
local Waypoints = QuestieLoader:CreateModule("QuestieWaypoints")
local Geometry = QuestieLoader:ImportModule("WaypointGeometry")
local Renderer = QuestieLoader:ImportModule("WaypointRenderer")
local Map = QuestieLoader:ImportModule("QuestieMap")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
local Tooltip = QuestieLoader:ImportModule("MapIconTooltip")
local HBD, Pins = QuestieCompat.HBD, QuestieCompat.HBDPins
local paths, owners = {}, {}
Waypoints.paths = paths
local driver, tooltip, hovered, hoveredKind, hoveredRoot, hoverShift, highlightedData, solo
local revision, elapsed = 0, 0
local layers = {world = {views = {}, visible = {}, free = {}}, mini = {views = {}, visible = {}, free = {}}}
local ROUND = {true, true, true, true}
local SHAPES = {
    ROUND = ROUND, SQUARE = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {true, false, false, false}, ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false}, ["CORNER-BOTTOMRIGHT"] = {false, false, false, true},
    ["SIDE-LEFT"] = {true, true, false, false}, ["SIDE-RIGHT"] = {false, false, true, true},
    ["SIDE-TOP"] = {true, false, true, false}, ["SIDE-BOTTOM"] = {false, true, false, true},
    ["TRICORNER-TOPLEFT"] = {true, true, true, false}, ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true}, ["TRICORNER-BOTTOMRIGHT"] = {false, true, true, true},
}

-- DragonUI reports ROUND, but its mask is inset and narrower across the top.
-- This conservative convex outline is sampled from that mask's opaque pixels.
local MASKS = {
    ["interface\\addons\\dragonui\\textures\\minimap\\uiminimapmask.tga"] = {
        {0.89965, 0}, {0.83521, 0.34596}, {0.63815, 0.63815}, {0.34302, 0.82813},
        {0, 0.89749}, {-0.34302, 0.82813}, {-0.63391, 0.63391}, {-0.83304, 0.34506},
        {-0.89749, 0}, {-0.81228, -0.33646}, {-0.60985, -0.60985}, {-0.32536, -0.78550},
        {0, -0.86452}, {0.32536, -0.78550}, {0.60985, -0.60985}, {0.81894, -0.33922},
    },
}
local trackedMasks = setmetatable({}, {__mode = "k"})
local function minimapMask(root)
    local record = trackedMasks[root]
    if not record then
        record = {}
        trackedMasks[root] = record
        if hooksecurefunc and root.SetMaskTexture then
            hooksecurefunc(root, "SetMaskTexture", function(_, path)
                record.path, record.captured = path, true
                Waypoints.Refresh()
            end)
        end
    end
    local path = record.path
    if not record.captured then
        if root.GetMaskTexture then path = root:GetMaskTexture() end
        -- The native client has no getter. DragonUI exposes an already-applied mask.
        if not path and root == Minimap and DragonUI and DragonUI.MinimapModule then
            path = DragonUI.MinimapModule.activeMask
        end
    end
    if type(path) == "string" then return path:lower():gsub("/", "\\") end
end

function Waypoints.Refresh() revision = revision + 1 end
function Waypoints.OwnerChanged(icon)
    if owners[icon] or (icon.waypointOwner and owners[icon.waypointOwner]) then Waypoints.Refresh() end
end
function Waypoints.SetSolo(data) solo = data; Waypoints.Refresh() end
function Waypoints.SetHighlighted(data, enabled)
    if enabled then highlightedData = data elseif highlightedData == data then highlightedData = nil end
    Waypoints.Refresh()
end

function Waypoints.EndHover(nextIcon)
    if not hovered then return end
    local old = hovered
    hovered, hoveredKind, hoveredRoot, hoverShift = nil, nil, nil, nil
    if tooltip then tooltip:Hide(); tooltip._Rebuild = nil; tooltip.ShownAsMapIcon = false end
    if old.owner.data == old.data then
        local leave = old.owner:GetScript("OnLeave")
        if leave then leave(old.owner) end
    end
    Waypoints.Refresh()
end

local function highlighted(path)
    return Questie.db.profile.waypointHighlight ~= false and
        ((hovered and hovered.entity == path.entity) or highlightedData == path.data)
end

function Waypoints.Color(path)
    local p = Questie.db.profile
    local color = highlighted(path) and (p.waypointHighlightColor or {0.93, 0.46, 0.13, 0.8})
        or path.hostile and (p.waypointHostileColor or {1, 0.2, 0, 0.7})
        or p.waypointColor or {1, 0.72, 0, 0.5}
    return {color[1], color[2], color[3], math.min(1, (color[4] or 1) * (p.waypointOpacity or 1))}
end

local function alpha(path, mini)
    local p, owner = Questie.db.profile, path.owner
    if not p.enabled or owner.data ~= path.data or owner._needsUnload or not owner._loaded then return end
    if mini then
        if p.waypointMinimapEnabled == false or not p.enableMiniMapIcons then return end
        owner = owner.minimapTwin
        if not owner or owner.data ~= path.data then return end
    else
        if p.showWaypointLines == false or not p.enableMapIcons or (solo and not solo[path.data]) then return end
    end
    if owner.hidden then return end
    -- Range hiding belongs to the icon, not the entire patrol. A distant icon's
    -- route can still pass the player; use only Questie's explicit fade state.
    return owner.faded and p.iconFadeLevel or 1
end
Waypoints.Alpha = alpha

function Waypoints.RemoveOwner(owner)
    local owned = owners[owner]
    if not owned then return end
    owners[owner] = nil
    for _, path in ipairs(owned) do
        paths[path] = nil
        if hovered == path then Waypoints.EndHover() end
    end
    Waypoints.Refresh()
    if driver and not next(paths) then
        for _, layer in pairs(layers) do
            for _, view in pairs(layer.views) do view:Hide() end
            layer.visible = {}
        end
        driver:Hide()
    end
end

local function cursor(root)
    local scale = root:GetEffectiveScale()
    local left, top = root:GetLeft(), root:GetTop()
    if not left or not top or not scale or scale <= 0 then return end
    local x, y = GetCursorPosition()
    return x / scale - left, top - y / scale
end

local function hover(layer, root, kind, width)
    local focus = GetMouseFocus()
    if focus ~= root then return end
    local x, y = cursor(root)
    if not x or x < 0 or y < 0 or x > root:GetWidth() or y > root:GetHeight() then return end
    if kind == "mini" then
        local cx, cy = root:GetWidth() / 2, root:GetHeight() / 2
        local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
        local rounded = SHAPES[shape] or ROUND
        local q = (x < cx and 1 or 3) + (y < cy and 0 or 1)
        if rounded[q] and ((x - cx) / cx)^2 + ((y - cy) / cy)^2 > 1 then return end
        if not Geometry.InsideMask(layer.mask, x, y) then return end
        local scale = UIParent:GetEffectiveScale() / root:GetEffectiveScale()
        if (x - cx)^2 + (y - cy)^2 < (9 * scale)^2 then return end
    end
    local target = Geometry.Nearest(layer.visible, x, y, width / 2 + 1)
    return target and target.path
end

local function updateHover()
    local world, mini = layers.world, layers.mini
    local path, kind
    if world.root and world.root:IsVisible() then
        path = hover(world, world.root, "world", world.width or 3)
        if path then kind = "world" end
    end
    if not path and mini.root and mini.root:IsVisible() then
        path = hover(mini, mini.root, "mini", mini.width or 3)
        if path then kind = "mini" end
    end
    local shift = IsShiftKeyDown and IsShiftKeyDown() or false
    local root = kind == "mini" and mini.root or world.root
    if path == hovered and kind == hoveredKind and root == hoveredRoot then
        -- This tooltip is independent of GameTooltip, including on replacement minimaps.
        if path and tooltip and tooltip._Rebuild and shift ~= hoverShift then
            hoverShift = shift
            tooltip:ClearLines()
            tooltip:_Rebuild()
            tooltip:Show()
        end
        return
    end
    Waypoints.EndHover()
    if not path then return end
    hovered, hoveredKind, hoveredRoot, hoverShift = path, kind, root, shift
    if not tooltip then tooltip = CreateFrame("GameTooltip", "QuestiePatrolTooltip", UIParent, "GameTooltipTemplate") end
    local icons, seen = {}, {}
    for copy in pairs(paths) do
        if copy.entity == path.entity and alpha(copy, kind == "mini") then
            local icon = kind == "mini" and copy.owner.minimapTwin or copy.owner
            if not seen[icon] then seen[icon] = true; icons[#icons + 1] = icon end
        end
    end
    local icon = kind == "mini" and path.owner.minimapTwin or path.owner
    Tooltip.ShowOnTooltip(icon, tooltip, root, icons)
    Waypoints.Refresh()
end

local function clear(layer)
    for _, view in pairs(layer.views) do view:Hide() end
    layer.visible = {}
end

local function draw(layer, root, mini, playerX, playerY, instance, radius, facing)
    clear(layer)
    layer.root = root
    if not root or not root:IsVisible() then return end
    local w, h = root:GetWidth(), root:GetHeight()
    if w <= 0 or h <= 0 then return end
    local p = Questie.db.profile
    local scale = (UIParent:GetEffectiveScale() or 1) / root:GetEffectiveScale()
    local width = (p.waypointWidth or 3) * scale
    layer.width = width
    local margin = width * 0.8
    local box = {margin, margin, w - margin, h - margin}
    local shape = mini and ((GetMinimapShape and GetMinimapShape()) or "ROUND")
    local rounded = mini and (SHAPES[shape] or ROUND) or nil
    local outline = mini and MASKS[minimapMask(root)] or nil
    layer.mask = Geometry.MaskEdges(outline, w, h, 0)
    local mask = Geometry.MaskEdges(outline, w, h, margin)
    local mapId = not mini and QuestieCompat.WorldMapFrame:GetMapID()
    local selected = {}
    for path in pairs(paths) do
        local opacity = alpha(path, mini)
        if mini and opacity then
            local bounds = path.worldBounds
            local dx = math.max(bounds[1] - playerX, 0, playerX - bounds[3])
            local dy = math.max(bounds[2] - playerY, 0, playerY - bounds[4])
            if dx * dx + dy * dy > 4 * radius * radius then opacity = nil end
        end
        if opacity and opacity > 0 and (mini and path.instanceId == instance or not mini and path.uiMapId == mapId) then
            local old = selected[path.route]
            if not old or (highlighted(path) and not highlighted(old.path)) or
                (highlighted(path) == highlighted(old.path) and (opacity > old.alpha or
                    (opacity == old.alpha and path.hostile and not old.path.hostile))) then
                selected[path.route] = {path = path, alpha = opacity}
            end
        end
    end
    for route, view in pairs(layer.views) do
        if not selected[route] then
            layer.free[#layer.free + 1] = view
            layer.views[route] = nil
        end
    end
    local cos, sin = math.cos(facing or 0), math.sin(facing or 0)
    for route, entry in pairs(selected) do
        local path, points = entry.path, {}
        for _, point in ipairs(mini and path.world or path.points) do
            local x, y
            if mini then
                local dx, dy = playerX - point.x, playerY - point.y
                x, y = (dx * cos - dy * sin) / radius * w / 2 + w / 2,
                    (dx * sin + dy * cos) / radius * h / 2 + h / 2
            else
                x, y = point.x * w / 100, point.y * h / 100
            end
            points[#points + 1] = {x = x, y = y}
        end
        points = Geometry.Smooth(points, (p.waypointSmoothing or 0.75) * width / 2, width * 2 / 3)
        points = Geometry.Trim(points, width / 16)
        local runs = Geometry.Clip(points, box, rounded, mini and (9 * scale + width) or nil, mask)
        if #runs > 0 then
            local view = layer.views[route]
            if not view then view = table.remove(layer.free) or Renderer.New(root); layer.views[route] = view end
            view:SetParent(root)
            if not mini and Map.utils.SetLineDrawOrder then Map.utils.SetLineDrawOrder(view) end
            view:ClearAllPoints(); view:SetAllPoints(root)
            if mini then view:SetFrameLevel(root:GetFrameLevel() + 1) end
            Renderer.Draw(view, runs, width, Waypoints.Color(path), entry.alpha)
            for _, run in ipairs(runs) do
                layer.visible[#layer.visible + 1] = {path = path, points = run, bounds = Geometry.Bounds(run)}
            end
        end
    end
end

function Waypoints.Update()
    local canvas = QuestieCompat.WorldMapFrame:GetCanvas()
    local world = layers.world
    local worldKey = table.concat({revision, QuestieCompat.WorldMapFrame:GetMapID() or 0,
        canvas:GetWidth(), canvas:GetHeight(), canvas:GetEffectiveScale(), tostring(canvas:IsVisible())}, ":")
    if world.root ~= canvas or world.key ~= worldKey then world.key = worldKey; draw(world, canvas, false) end
    local root = Pins.Minimap
    local x, y, instance = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
    local radius, rotating = Pins:GetMinimapView()
    local facing = rotating and GetPlayerFacing() or 0
    local mini = layers.mini
    if not x or not y or not radius or radius <= 0 or facing == nil then
        clear(mini); mini.key = nil
    else
        local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
        local mask = minimapMask(root) or ""
        local key = table.concat({revision, x, y, instance or -1, radius, facing, shape,
            mask, root:GetWidth(), root:GetHeight(), root:GetEffectiveScale(), tostring(root:IsVisible())}, ":")
        if mini.root ~= root or mini.key ~= key then mini.key = key; draw(mini, root, true, x, y, instance, radius, facing) end
    end
    updateHover()
end

function Waypoints.Add(owner, entity, patrols, area, hostile)
    if not owner or not owner.data then return end
    local mapId = ZoneDB:GetUiMapIdByAreaId(area)
    if not mapId then return end
    entity = entity or tostring(owner)
    local owned = owners[owner] or {}
    if owned[1] and owned[1].data ~= owner.data then Waypoints.RemoveOwner(owner); owned = {} end
    for _, path in ipairs(owned) do
        if path.raw == patrols and path.area == area and path.entity == entity then return end
    end
    local built = Geometry.BuildPolylines(patrols, mapId, function(x, y, zone)
        return HBD:GetWorldCoordinatesFromZone(x, y, zone)
    end)
    for i, path in ipairs(built) do
        path.owner, path.data, path.raw, path.area = owner, owner.data, patrols, area
        path.entity, path.hostile, path.route = entity, hostile, entity .. ":" .. area .. ":" .. i
        owned[#owned + 1] = path; paths[path] = true
    end
    owners[owner] = owned
    if not next(paths) then return end
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.05 then elapsed = 0; Waypoints.Update() end
        end)
    end
    Waypoints.Refresh(); driver:Show()
end
