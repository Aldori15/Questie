---@class WorldMapButton
---@field Initialize function
local WorldMapButton = QuestieLoader:CreateModule("WorldMapButton")

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")

local KButtons = QuestieCompat.KButtons or LibStub("Krowi_WorldMapButtons-1.4")

local mapButton
local lastWorldMapButtonEffectiveScale
local lastWorldMapFrameEffectiveScale

local function _GetOccupiedTopRightOffset(worldMapButtonFrame, worldMapFrame)
    local occupiedOffset

    local function ConsiderFrame(frame)
        if not frame or frame == mapButton or not frame.IsShown or not frame:IsShown() then
            return
        end

        local point, relativeFrame, relativePoint, xOffset = frame:GetPoint(1)
        if not point or xOffset == nil then
            return
        end

        if (relativeFrame == worldMapButtonFrame or relativeFrame == worldMapFrame) and
            (point == "TOPRIGHT" or point == "RIGHT") and
            (relativePoint == "TOPRIGHT" or relativePoint == "RIGHT" or relativePoint == nil) then
            if occupiedOffset == nil or xOffset < occupiedOffset then
                occupiedOffset = xOffset
            end
        end
    end

    for _, child in next, { worldMapButtonFrame:GetChildren() } do
        ConsiderFrame(child)
    end

    if worldMapFrame and worldMapFrame ~= worldMapButtonFrame then
        for _, child in next, { worldMapFrame:GetChildren() } do
            ConsiderFrame(child)
        end
    end

    return occupiedOffset
end

local function RefreshWorldMapButtonLayout()
    if not mapButton then
        return
    end

    local worldMapButtonFrame = _G.WorldMapButton
    if not worldMapButtonFrame then
        return
    end

    local worldMapFrame = _G.WorldMapFrame or worldMapButtonFrame:GetParent()
    local parentEffectiveScale = worldMapButtonFrame.GetEffectiveScale and worldMapButtonFrame:GetEffectiveScale() or worldMapButtonFrame:GetScale() or 1
    local targetEffectiveScale = worldMapFrame and worldMapFrame.GetEffectiveScale and worldMapFrame:GetEffectiveScale() or parentEffectiveScale
    local buttonScale = 1
    local point, _, relativePoint, xOffset, yOffset = mapButton:GetPoint(1)
    local occupiedOffset = _GetOccupiedTopRightOffset(worldMapButtonFrame, worldMapFrame)
    local buttonWidth = mapButton.GetWidth and mapButton:GetWidth() or 32
    local buttonGap = 4

    if parentEffectiveScale and parentEffectiveScale > 0 then
        buttonScale = targetEffectiveScale / parentEffectiveScale
    end

    if not point then
        point = "TOPRIGHT"
        relativePoint = "TOPRIGHT"
        xOffset = -4
        yOffset = -4
    end

    if occupiedOffset ~= nil then
        local collisionOffset = occupiedOffset - buttonWidth - buttonGap
        if not xOffset or collisionOffset < xOffset then
            xOffset = collisionOffset
        end
    end

    mapButton:SetParent(worldMapButtonFrame)
    mapButton:ClearAllPoints()
    mapButton:SetFrameStrata("TOOLTIP")
    mapButton:SetFrameLevel(worldMapButtonFrame:GetFrameLevel() + 1)
    mapButton:SetPoint(point, worldMapButtonFrame, relativePoint or point, xOffset or -4, yOffset or -4)
    mapButton:SetScale(buttonScale)

    lastWorldMapButtonEffectiveScale = parentEffectiveScale
    lastWorldMapFrameEffectiveScale = targetEffectiveScale
end

local function EnsureWorldMapButtonHooks()
    local worldMapButtonFrame = _G.WorldMapButton
    local worldMapFrame = _G.WorldMapFrame

    if worldMapButtonFrame and not worldMapButtonFrame.questieButtonScaleHooked then
        worldMapButtonFrame.questieButtonScaleHooked = true
        worldMapButtonFrame:HookScript("OnShow", RefreshWorldMapButtonLayout)
        worldMapButtonFrame:HookScript("OnSizeChanged", RefreshWorldMapButtonLayout)
        worldMapButtonFrame:HookScript("OnUpdate", function(self)
            local currentButtonEffectiveScale = self.GetEffectiveScale and self:GetEffectiveScale() or self:GetScale() or 1
            local currentFrameEffectiveScale = worldMapFrame and worldMapFrame.GetEffectiveScale and worldMapFrame:GetEffectiveScale() or currentButtonEffectiveScale

            if currentButtonEffectiveScale ~= lastWorldMapButtonEffectiveScale or currentFrameEffectiveScale ~= lastWorldMapFrameEffectiveScale then
                RefreshWorldMapButtonLayout()
            end
        end)
    end

    if worldMapFrame and not worldMapFrame.questieButtonScaleHooked then
        worldMapFrame.questieButtonScaleHooked = true
        worldMapFrame:HookScript("OnShow", RefreshWorldMapButtonLayout)
        worldMapFrame:HookScript("OnSizeChanged", RefreshWorldMapButtonLayout)
    end
end

function WorldMapButton.Initialize()
    mapButton = KButtons:Add("QuestieWorldMapButtonTemplate", "BUTTON")
	WorldMapButton.Toggle(Questie.db.profile.mapShowHideEnabled)
    EnsureWorldMapButtonHooks()
    RefreshWorldMapButtonLayout()

    Questie.WorldMap = {
        Button = mapButton
    }
end

---@param shouldShow boolean
function WorldMapButton.Toggle(shouldShow)
    if shouldShow then
        mapButton:Show()
    else
        mapButton:Hide()
    end
end

---@param self Frame
---@return nil
local function UpdateTooltip(self)
    local tooltip = GameTooltip
    tooltip:SetOwner(self, "ANCHOR_NONE");
    tooltip:ClearLines()
    tooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 0);
    tooltip:AddDoubleLine(Questie:Colorize("Questie", 'gold'), Questie:Colorize(QuestieLib:GetAddonVersionString(), 'gray'))
    tooltip:AddLine(" ")
    local toggleLabel = Questie.db.profile.enabled and l10n('Hide Questie') or l10n('Show Questie')
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Left Click'), 'lightBlue'), Questie:Colorize(toggleLabel, 'white'))
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Right Click'), 'lightBlue'), Questie:Colorize(l10n('Toggle Menu'), 'white'))
    tooltip:Show()
end

QuestieWorldMapButtonMixin = {
    OnLoad = function() end,
    OnHide = function() end,
    OnMouseDown = function(_, button)
        if button == "LeftButton" then
            Questie.db.profile.enabled = (not Questie.db.profile.enabled)
            QuestieQuest:ToggleNotes(Questie.db.profile.enabled)
            if GameTooltip:IsShown() and GameTooltip:GetOwner() == mapButton then
                UpdateTooltip(mapButton)
            end
        elseif button == "RightButton" then
            QuestieMenu:Show()
        end
    end,
    OnMouseUp = function() end,
    OnEnter = function(self)
        UpdateTooltip(self)
    end,
    OnLeave = function() end,
    OnClick = function() end, -- Only fires on left click
    Refresh = function() end,
}
