-- Native 3.3.5 texture-coordinate drawing; no Line, vertex-offset or mask APIs.
local Renderer = QuestieLoader:CreateModule("WaypointRenderer")
local Lib = QuestieLoader:ImportModule("QuestieLib")
local LINE = Lib.AddonPath .. "Icons\\waypoints\\line.tga"
local CAP = Lib.AddonPath .. "Icons\\waypoints\\cap.tga"

function Renderer.New(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:EnableMouse(false)
    view.lines, view.caps = {}, {}
    return view
end

local function acquire(view, list, index, asset)
    local texture = list[index]
    if not texture then
        texture = view:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(asset)
        list[index] = texture
    end
    texture:Show()
    return texture
end

-- Invert a rotated rectangle at each bounding-box corner. Transparent texture edges
-- keep out-of-range UVs clear on the legacy client's clamped textures.
function Renderer.Segment(texture, parent, a, b, width)
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.001 then texture:Hide(); return end
    local ux, uy = dx / length, dy / length
    local nx, ny = -uy, ux
    local half = width / 2
    local left, right = math.min(a.x, b.x) - math.abs(nx) * half, math.max(a.x, b.x) + math.abs(nx) * half
    local top, bottom = math.min(a.y, b.y) - math.abs(ny) * half, math.max(a.y, b.y) + math.abs(ny) * half
    local function uv(x, y)
        local px, py = x - a.x, y - a.y
        return 1.5 / 1024 + (1021 / 1024) * (px * ux + py * uy) / length,
            0.5 + (px * nx + py * ny) / width
    end
    local ulx, uly = uv(left, top)
    local llx, lly = uv(left, bottom)
    local urx, ury = uv(right, top)
    local lrx, lry = uv(right, bottom)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    texture:SetSize(math.max(0.001, right - left), math.max(0.001, bottom - top))
    texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

function Renderer.Style(view, color, alpha)
    for _, list in ipairs({view.lines, view.caps}) do
        for _, texture in ipairs(list) do texture:SetVertexColor(unpack(color)) end
    end
    view:SetAlpha(alpha)
end

function Renderer.Draw(view, runs, width, color, alpha)
    local lines, caps = 0, 0
    local outer = width * 4 / 3
    for _, points in ipairs(runs) do
        local first, last = points[1], points[#points]
        local closed = (first.x - last.x)^2 + (first.y - last.y)^2 <= 1e-12
        for i, point in ipairs(points) do
            if i > 1 then
                lines = lines + 1
                Renderer.Segment(acquire(view, view.lines, lines, LINE), view, points[i - 1], point, outer)
            end
            -- Interior outlined discs cut black rings across sampled curves.
            -- Only the exposed ends need caps; a closed patrol has neither.
            if not closed and (i == 1 or i == #points) then
                caps = caps + 1
                local texture = acquire(view, view.caps, caps, CAP)
                texture:ClearAllPoints()
                texture:SetPoint("CENTER", view, "TOPLEFT", point.x, -point.y)
                texture:SetSize(outer, outer)
            end
        end
    end
    for i = lines + 1, #view.lines do view.lines[i]:Hide() end
    for i = caps + 1, #view.caps do view.caps[i]:Hide() end
    Renderer.Style(view, color, alpha)
    view:Show()
end
