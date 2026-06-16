---@class WorldMapButton
---@field Initialize function
local WorldMapButton = QuestieLoader:CreateModule("WorldMapButton")

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
---@type QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

local KButtons = QuestieCompat.KButtons or LibStub("Krowi_WorldMapButtons-1.4")

local mapButton
local lastWorldMapButtonEffectiveScale
local lastWorldMapFrameEffectiveScale
local isRefreshingWorldMapButtonLayout
local childScanFailed
local worldMapFrameUpdateHooked

local function _GetChildrenSafely(frame)
    if childScanFailed or not frame or not frame.GetChildren then
        return
    end

    local ok, children = pcall(function()
        return { frame:GetChildren() }
    end)

    if ok then
        return children
    end

    childScanFailed = true
end

local function _GetOccupiedCornerOffset(worldMapButtonFrame, corner)
    local occupiedOffset
    local parentEffectiveScale = worldMapButtonFrame.GetEffectiveScale and worldMapButtonFrame:GetEffectiveScale() or worldMapButtonFrame:GetScale() or 1

    local worldMapButtonChildren = _GetChildrenSafely(worldMapButtonFrame)
    if not worldMapButtonChildren then
        return
    end

    local isRightSide = (corner == "TOPRIGHT" or corner == "BOTTOMRIGHT")
    local sideAnchor = isRightSide and "RIGHT" or "LEFT"

    for _, child in next, worldMapButtonChildren do
        if child ~= mapButton and child.IsShown and child:IsShown() then
            local point, relativeFrame, relativePoint, xOffset = child:GetPoint(1)
            if relativeFrame == worldMapButtonFrame and xOffset ~= nil and
                (point == corner or point == sideAnchor) and
                (relativePoint == corner or relativePoint == sideAnchor or relativePoint == nil) then
                local childWidth = child.GetWidth and child:GetWidth() or 0
                local childHeight = child.GetHeight and child:GetHeight() or 0

                if childWidth > 0 and childHeight > 0 and childWidth <= 64 and childHeight <= 64 then
                    local childEffectiveScale = child.GetEffectiveScale and child:GetEffectiveScale() or child:GetScale() or parentEffectiveScale
                    local scaleRatio = 1
                    if parentEffectiveScale and parentEffectiveScale > 0 then
                        scaleRatio = childEffectiveScale / parentEffectiveScale
                    end

                    if isRightSide then
                        -- Push further left: find the leftmost occupied edge
                        local localOffset = xOffset - (childWidth * scaleRatio)
                        if occupiedOffset == nil or localOffset < occupiedOffset then
                            occupiedOffset = localOffset
                        end
                    else
                        -- Push further right: find the rightmost occupied edge
                        local localOffset = xOffset + (childWidth * scaleRatio)
                        if occupiedOffset == nil or localOffset > occupiedOffset then
                            occupiedOffset = localOffset
                        end
                    end
                end
            end
        end
    end

    return occupiedOffset
end

local function RefreshWorldMapButtonLayout()
    if isRefreshingWorldMapButtonLayout or not mapButton then
        return
    end

    local worldMapButtonFrame = _G.WorldMapButton
    if not worldMapButtonFrame then
        return
    end

    isRefreshingWorldMapButtonLayout = true

    local corner = (Questie.db and Questie.db.profile and Questie.db.profile.worldMapButtonPosition) or "TOPRIGHT"
    local isRightSide = (corner == "TOPRIGHT" or corner == "BOTTOMRIGHT")
    local isTopSide = (corner == "TOPRIGHT" or corner == "TOPLEFT")

    local anchorFrame
    if corner == "TOPRIGHT" then
        anchorFrame = worldMapButtonFrame
    else
        anchorFrame = _G.WorldMapDetailFrame or worldMapButtonFrame
    end

    local buttonScale = 1
    local xOffset = isRightSide and -4 or 4
    local yOffset = isTopSide and -4 or 4
    local occupiedGap = isRightSide and -4 or 4

    if WORLDMAP_SETTINGS and WORLDMAP_WINDOWED_SIZE and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
        buttonScale = 1 + WORLDMAP_SETTINGS.size
        occupiedGap = isRightSide and 15 or -15
    end

    local occupiedOffset = _GetOccupiedCornerOffset(anchorFrame, corner)
    if occupiedOffset ~= nil then
        xOffset = occupiedOffset + occupiedGap
    end

    if mapButton:GetParent() ~= worldMapButtonFrame then
        mapButton:SetParent(worldMapButtonFrame)
    end

    mapButton:ClearAllPoints()
    mapButton:SetFrameStrata(worldMapButtonFrame:GetFrameStrata())
    mapButton:SetFrameLevel(worldMapButtonFrame:GetFrameLevel() + 1)
    mapButton:SetPoint(corner, anchorFrame, corner, xOffset, yOffset)
    mapButton:SetScale(buttonScale)

    lastWorldMapButtonEffectiveScale = worldMapButtonFrame.GetEffectiveScale and worldMapButtonFrame:GetEffectiveScale() or worldMapButtonFrame:GetScale() or 1
    lastWorldMapFrameEffectiveScale = _G.WorldMapFrame and (_G.WorldMapFrame.GetEffectiveScale and _G.WorldMapFrame:GetEffectiveScale() or _G.WorldMapFrame:GetScale() or lastWorldMapButtonEffectiveScale) or lastWorldMapButtonEffectiveScale
    isRefreshingWorldMapButtonLayout = nil
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

    if not worldMapFrameUpdateHooked and type(WorldMapFrame_Update) == "function" then
        worldMapFrameUpdateHooked = true
        hooksecurefunc("WorldMapFrame_Update", RefreshWorldMapButtonLayout)
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

function WorldMapButton.RefreshLayout()
    RefreshWorldMapButtonLayout()
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
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Left Click'), 'lightBlue'), Questie:Colorize(l10n('Toggle My Journey'), 'white'))
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Right Click'), 'lightBlue'), Questie:Colorize(l10n('Toggle Menu'), 'white'))
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Shift') .. ' + ' .. l10n('Left Click'), 'lightBlue'), Questie:Colorize(l10n('Questie Options'), 'white'))
    local toggleLabel = Questie.db.profile.enabled and l10n('Hide Questie') or l10n('Show Questie')
    tooltip:AddDoubleLine(Questie:Colorize(l10n('Ctrl + Shift + Left Click'), 'lightBlue'), Questie:Colorize(toggleLabel, 'white'))
    tooltip:Show()
end

QuestieWorldMapButtonMixin = {
    OnLoad = function() end,
    OnHide = function() end,
    OnMouseDown = function(_, button)
        if button == "LeftButton" then
            if IsControlKeyDown() and IsShiftKeyDown() then
                Questie.db.profile.enabled = (not Questie.db.profile.enabled)
                QuestieQuest:ToggleNotes(Questie.db.profile.enabled)
                if GameTooltip:IsShown() and GameTooltip:GetOwner() == mapButton then
                    UpdateTooltip(mapButton)
                end

                QuestieOptions:HideFrame()
                return
            elseif IsShiftKeyDown() then
                QuestieOptions:HideFrame()
                if InCombatLockdown() then
                    Questie:Print(l10n("Questie will open after combat ends."))
                end
                QuestieCombatQueue:Queue(function()
                    QuestieOptions:OpenConfigWindow()
                end)
                return
            elseif IsModifierKeyDown() then
                return
            end

            QuestieOptions:HideFrame()
            QuestieJourney:ToggleJourneyWindow()
        elseif button == "RightButton" then
            if IsModifierKeyDown() then
                return
            end

            QuestieMenu:Show()
            if QuestieJourney:IsShown() then
                QuestieJourney:ToggleJourneyWindow()
            end
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
