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

    if parentEffectiveScale and parentEffectiveScale > 0 then
        buttonScale = targetEffectiveScale / parentEffectiveScale
    end

    mapButton:SetParent(worldMapButtonFrame)
    mapButton:ClearAllPoints()
    mapButton:SetFrameStrata("TOOLTIP")
    mapButton:SetFrameLevel(worldMapButtonFrame:GetFrameLevel() + 1)
    mapButton:SetPoint("TOPRIGHT", worldMapButtonFrame, "TOPRIGHT", -4, -4)
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
