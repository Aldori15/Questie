---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

local function IsWorldMapFrameDescendant(frame)
    local current = frame

    while current do
        if current == WorldMapButton or current == WorldMapFrame then
            return true
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

-- handle tooltip based on the parent frame
function QuestieCompat.SetupTooltip(frame, OnHide)
    if IsWorldMapFrameDescendant(frame) then
        WorldMapPOIFrame.allowBlobTooltip = OnHide and true or false
        QuestieCompat.Tooltip = WorldMapTooltip
    else
        QuestieCompat.Tooltip = GameTooltip
    end
    return QuestieCompat.Tooltip
end

local wrappedLines = {}
-- tooltip word wrapping looks fine the way it is, leave it for now
function QuestieCompat.TextWrap(self, line, prefix, combineTrailing, desiredWidth)
    QuestieCompat.Tooltip:AddLine(line, 0.86, 0.86, 0.86, 1);
    return wrappedLines
end

local unboundedFS = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
unboundedFS:SetPoint("TOPLEFT", 0, 0)
unboundedFS:Hide()

-- The minimum width necessary to contain the entire text without truncation
-- https://wowpedia.fandom.com/wiki/API_FontString_GetStringWidth
function QuestieCompat.GetUnboundedStringWidth(self)
    unboundedFS:SetWidth(0)
    unboundedFS:SetFont(self:GetFont())
    unboundedFS:SetText(self:GetText())

    return unboundedFS:GetStringWidth()
end

-- Number of lines of wrapped text
-- https://wowpedia.fandom.com/wiki/API_FontString_GetNumLines
function QuestieCompat.GetNumLines(self)
    local fontName, fontHeight, fontFlags = self:GetFont()
    unboundedFS:SetWidth(self:GetWidth())
    unboundedFS:SetFont(fontName, fontHeight, fontFlags)
    unboundedFS:SetText(self:GetText())

	return math.ceil(unboundedFS:GetHeight()/fontHeight)
end

-- texture			- Texture
-- canvasFrame      - Canvas Frame (for anchoring)
-- startX,startY    - Coordinate of start of line
-- endX,endY		- Coordinate of end of line
-- lineWidth        - Width of line
-- relPoint			- Relative point on canvas to interpret coords (Default BOTTOMLEFT)
local function DrawLine(texture, canvasFrame, startX, startY, endX, endY, lineWidth, lineFactor, relPoint)
	if (not relPoint) then relPoint = "BOTTOMLEFT"; end
	lineFactor = lineFactor * .5;

	-- Determine dimensions and center point of line
	local dx,dy = endX - startX, endY - startY;
	local cx,cy = (startX + endX) / 2, (startY + endY) / 2;

	-- Normalize direction if necessary
	if (dx < 0) then
		dx,dy = -dx,-dy;
	end

	-- Calculate actual length of line
	local lineLength = sqrt((dx * dx) + (dy * dy));

	-- Quick escape if it'sin zero length
	if (lineLength == 0) then
        texture:ClearAllPoints();
		texture:SetTexCoord(0,0,0,0,0,0,0,0);
		texture:SetPoint("BOTTOMLEFT", canvasFrame, relPoint, cx,cy);
		texture:SetPoint("TOPRIGHT",   canvasFrame, relPoint, cx,cy);
		return;
	end

	-- Sin and Cosine of rotation, and combination (for later)
	local sin, cos = -dy / lineLength, dx / lineLength;
	local sinCos = sin * cos;

	-- Calculate bounding box size and texture coordinates
	local boundingWidth, boundingHeight, bottomLeftX, bottomLeftY, topLeftX, topLeftY, topRightX, topRightY, bottomRightX, bottomRightY;
	if (dy >= 0) then
		boundingWidth = ((lineLength * cos) - (lineWidth * sin)) * lineFactor;
		boundingHeight = ((lineWidth * cos) - (lineLength * sin)) * lineFactor;

		bottomLeftX = (lineWidth / lineLength) * sinCos;
		bottomLeftY = sin * sin;
		bottomRightY = (lineLength / lineWidth) * sinCos;
		bottomRightX = 1 - bottomLeftY;

		topLeftX = bottomLeftY;
		topLeftY = 1 - bottomRightY;
		topRightX = 1 - bottomLeftX;
		topRightY = bottomRightX;
	else
		boundingWidth = ((lineLength * cos) + (lineWidth * sin)) * lineFactor;
		boundingHeight = ((lineWidth * cos) + (lineLength * sin)) * lineFactor;

		bottomLeftX = sin * sin;
		bottomLeftY = -(lineLength / lineWidth) * sinCos;
		bottomRightX = 1 + (lineWidth / lineLength) * sinCos;
		bottomRightY = bottomLeftX;

		topLeftX = 1 - bottomRightX;
		topLeftY = 1 - bottomLeftX;
		topRightY = 1 - bottomLeftY;
		topRightX = topLeftY;
	end

	-- Set texture coordinates and anchors
	texture:ClearAllPoints();
	texture:SetTexCoord(topLeftX, topLeftY, bottomLeftX, bottomLeftY, topRightX, topRightY, bottomRightX, bottomRightY);
	texture:SetPoint("BOTTOMLEFT", canvasFrame, relPoint, cx - boundingWidth, cy - boundingHeight);
	texture:SetPoint("TOPRIGHT",   canvasFrame, relPoint, cx + boundingWidth, cy + boundingHeight);
end

-- Mix this into a Texture to be able to treat it like a line
local LineMixin = {};

function LineMixin:SetStartPoint(relPoint, x, y)
	self.startX, self.startY = x, y;
end

function LineMixin:SetEndPoint(relPoint, x, y)
	self.endX, self.endY = x, y;
end

function LineMixin:SetThickness(thickness)
	self.thickness = thickness;
end

function LineMixin:Draw()
	local parent = self:GetParent();
	local x, y = parent:GetLeft(), parent:GetBottom();

	self:ClearAllPoints();
	DrawLine(self, parent, self.startX - x, self.startY - y, self.endX - x, self.endY - y, self.thickness or 32, 1);
end

local function drawLineOnShow(self)
    local line = self.line
    if not (line and line.startX and line.startY and line.endX and line.endY and line.thickness) then return end
    DrawLine(line, self, line.startX, line.startY, line.endX, line.endY, line.thickness*15, 1.2, "TOPLEFT");
end

local stub_line = setmetatable({}, QuestieCompat.NOOP_MT)
-- https://wowpedia.fandom.com/wiki/API_Frame_CreateLine
function QuestieCompat.CreateLine(self)
    if self.line then return stub_line end -- stub lineBorder, as our line texture already has border

    local line = self:CreateTexture(nil, "OVERLAY")
    line:SetTexture(QuestieLib.AddonPath.."Compat\\Icons\\Waypoint-Line.blp")
    line.SetColorTexture = line.SetVertexColor

    for k,v in pairs(LineMixin) do
        line[k] = v
    end

    self:SetScript("OnShow", drawLineOnShow)

    return line
end

QuestieCompat.LibUIDropDownMenu = {
	Create_UIDropDownMenu = function(self, name, parent)
		return CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	end,
	EasyMenu = function(self, menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
	end,
	CloseDropDownMenus = function(self, level)
        CloseDropDownMenus(level)
    end,
}

local function RepositionQuestieDropDownSubmenu(level, _, _, _, _, _, _, button)
    if not level or level <= 1 or not button then return end

    local openMenuName = UIDROPDOWNMENU_OPEN_MENU and UIDROPDOWNMENU_OPEN_MENU.GetName and UIDROPDOWNMENU_OPEN_MENU:GetName()
    if not openMenuName or string.sub(openMenuName, 1, 7) ~= "Questie" then return end

    local listFrame = _G["DropDownList" .. level]
    if not listFrame or not listFrame:IsShown() then return end

    local point = "TOPLEFT"
    local relativePoint = "TOPRIGHT"
    local yOffset = 14
    local _, y = listFrame:GetCenter()
    if y and ((y - listFrame:GetHeight() / 2) < 0) then
        point = "BOTTOMLEFT"
        relativePoint = "BOTTOMRIGHT"
        yOffset = -14
    end

    listFrame:ClearAllPoints()
    listFrame:SetPoint(point, button, relativePoint, 0, yOffset)

    if listFrame:GetRight() and (listFrame:GetRight() > GetScreenWidth()) then
        if point == "TOPLEFT" then
            point = "TOPRIGHT"
            relativePoint = "TOPLEFT"
        else
            point = "BOTTOMRIGHT"
            relativePoint = "BOTTOMLEFT"
        end

        listFrame:ClearAllPoints()
        listFrame:SetPoint(point, button, relativePoint, 0, yOffset)
    end
end

if type(ToggleDropDownMenu) == "function" then
    hooksecurefunc("ToggleDropDownMenu", RepositionQuestieDropDownSubmenu)
end

QuestieCompat.KButtons = {
    Add = function(self, templateName, templateType)
        local button = CreateFrame("Button", "Questie_WorldMapButton", WorldMapFrame)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        button:SetPoint("TOPRIGHT", WorldMapButton, "TOPRIGHT", -4, -2);
        button:SetFrameLevel(99)
        button:SetSize(32, 32)
        button:RegisterForClicks("anyUp")
        button:SetScript("OnMouseDown", QuestieWorldMapButtonMixin.OnMouseDown)
        button:SetScript("OnEnter", QuestieWorldMapButtonMixin.OnEnter)
        button:SetScript("OnLeave", function(self)
            GameTooltip_Hide()
            local tooltip = QuestieCompat.SetupTooltip(self, true)
            if tooltip and tooltip ~= GameTooltip then
                tooltip:Hide()
            end
        end)

        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetSize(25, 25)
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        background:SetPoint("TOPLEFT", 2, -4)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetTexture(QuestieLib.AddonPath.."Icons\\complete.blp")
        icon:SetPoint("TOPLEFT", 6, -5)

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetPoint("TOPLEFT")

        return button
    end,
}
