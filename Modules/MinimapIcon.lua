---@class MinimapIcon
local MinimapIcon = QuestieLoader:CreateModule("MinimapIcon");
local _MinimapIcon = {}
-------------------------
--Import modules.
-------------------------
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest");
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions");
---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney");
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib");
---@type QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local _LibDBIcon = LibStub("LibDBIcon-1.0");

local minimapButton
local MINIMAP_BUTTON_OFFSET = 10
local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {true, false, false, false},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {false, false, false, true},
    ["SIDE-LEFT"] = {true, true, false, false},
    ["SIDE-RIGHT"] = {false, false, true, true},
    ["SIDE-TOP"] = {true, false, true, false},
    ["SIDE-BOTTOM"] = {false, true, false, true},
    ["TRICORNER-TOPLEFT"] = {true, true, true, false},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {false, true, true, true},
}

---@param button Frame
local function SaveDetachedButtonPosition(button)
    if not button.questieDetached or button:GetParent() ~= UIParent then
        return
    end

    local buttonX, buttonY = button:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not buttonX or not buttonY or not parentX or not parentY then
        return
    end

    Questie.db.profile.minimap.detachedX = buttonX - parentX
    Questie.db.profile.minimap.detachedY = buttonY - parentY
end

---@param button Frame
local function PositionDetachedButton(button)
    if button:GetParent() ~= UIParent then
        return
    end

    local minimapSettings = Questie.db.profile.minimap
    local x = minimapSettings.detachedX
    local y = minimapSettings.detachedY

    -- Preserve the button's current screen position the first time it is detached.
    if x == nil or y == nil then
        local buttonX, buttonY = button:GetCenter()
        local parentX, parentY = UIParent:GetCenter()

        if buttonX and buttonY and parentX and parentY then
            x = buttonX - parentX
            y = buttonY - parentY
        else
            x = 0
            y = 0
        end

        minimapSettings.detachedX = x
        minimapSettings.detachedY = y
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

---@param button Frame
local function UpdateMinimapButtonPosition(button)
    if button:GetParent() ~= Minimap then
        return
    end

    local angle = math.rad(button.db and button.db.minimapPos or button.minimapPos or 225)
    local x, y, quadrant = math.cos(angle), math.sin(angle), 1
    if x < 0 then quadrant = quadrant + 1 end
    if y > 0 then quadrant = quadrant + 2 end

    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local roundQuadrants = minimapShapes[minimapShape] or minimapShapes["ROUND"]
    local minimapWidth = Minimap:GetWidth()
    local minimapHeight = Minimap:GetHeight()
    if not minimapWidth or minimapWidth <= 0 then
        minimapWidth = 140
    end
    if not minimapHeight or minimapHeight <= 0 then
        minimapHeight = 140
    end
    local width = (minimapWidth / 2) + MINIMAP_BUTTON_OFFSET
    local height = (minimapHeight / 2) + MINIMAP_BUTTON_OFFSET
    if roundQuadrants[quadrant] then
        x, y = x * width, y * height
    else
        local diagonalWidth = math.sqrt(2 * width * width) - MINIMAP_BUTTON_OFFSET
        local diagonalHeight = math.sqrt(2 * height * height) - MINIMAP_BUTTON_OFFSET
        x = math.max(-width, math.min(x * diagonalWidth, width))
        y = math.max(-height, math.min(y * diagonalHeight, height))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

---@param button Frame
local function DragMinimapButton(button)
    if button:GetParent() ~= Minimap then
        return
    end

    local minimapX, minimapY = Minimap:GetCenter()
    if not minimapX or not minimapY then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    if scale == 0 then
        scale = 1
    end
    local position = math.deg(math.atan2((cursorY / scale) - minimapY, (cursorX / scale) - minimapX)) % 360
    if button.db then
        button.db.minimapPos = position
    else
        button.minimapPos = position
    end

    UpdateMinimapButtonPosition(button)
end

local function ConfigureMinimapButtonPositioning()
    if not minimapButton or minimapButton.questiePositioningConfigured then
        return
    end

    minimapButton.questiePositioningConfigured = true
    local originalOnDragStart = minimapButton:GetScript("OnDragStart")
    local originalOnDragStop = minimapButton:GetScript("OnDragStop")

    minimapButton:SetScript("OnDragStart", function(self, ...)
        if self.questieDetached and self:GetParent() == UIParent then
            if originalOnDragStart then
                originalOnDragStart(self, ...)
            end

            -- LibDBIcon normally moves the button around the minimap with OnUpdate.
            -- Detached mode uses WoW's normal movable frame behavior instead.
            self:SetScript("OnUpdate", nil)
            self:SetMovable(true)
            self:StartMoving()
            return
        end

        if originalOnDragStart then
            originalOnDragStart(self, ...)
        end
        self:SetScript("OnUpdate", DragMinimapButton)
    end)

    minimapButton:SetScript("OnDragStop", function(self, ...)
        if self.questieDetached and self:GetParent() == UIParent then
            self:StopMovingOrSizing()

            if originalOnDragStop then
                originalOnDragStop(self, ...)
            end

            SaveDetachedButtonPosition(self)
            return
        end

        if originalOnDragStop then
            originalOnDragStop(self, ...)
        end
        DragMinimapButton(self)
    end)
    minimapButton:HookScript("OnShow", UpdateMinimapButtonPosition)

    if not Minimap.questieButtonSizeHooked then
        Minimap.questieButtonSizeHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            UpdateMinimapButtonPosition(minimapButton)
        end)
    end

    UpdateMinimapButtonPosition(minimapButton)
end

local function NormalizeMinimapButtonAppearance()
    if minimapButton and minimapButton.icon then
        minimapButton.icon:SetWidth(18)
        minimapButton.icon:SetHeight(18)
        minimapButton.icon:ClearAllPoints()
        minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    end
end

local function ReleaseFromDragonUICollector(button)
    if not button or not button.DragonUI_CollectorManaged then
        return
    end

    -- DragonUI enforces collector placement from a SetParent hook while this
    -- flag is set. Clear its ownership state before moving the button.
    button.DragonUI_CollectorManaged = nil
    button.DragonUI_ForceCollectorAlpha = nil
    button.DragonUI_CollectorIndex = nil
    button.DragonUI_CollectorStyleKey = nil
    button.DragonUI_CollectorRepositioning = nil
    button.DragonUI_CollectorOrigin = nil
end

function MinimapIcon:ApplyButtonMode()
    if not minimapButton then
        return
    end

    local minimapSettings = Questie.db.profile.minimap
    minimapButton.db = minimapSettings

    if minimapSettings.detached then
        minimapButton.questieDetached = true

        ReleaseFromDragonUICollector(minimapButton)

        if minimapButton:GetParent() ~= UIParent then
            minimapButton:SetParent(UIParent)
        end

        -- Another addon may have taken ownership of the button and immediately
        -- reparented it again. Don't fight external button collectors.
        if minimapButton:GetParent() ~= UIParent then
            return
        end

        minimapButton:SetMovable(true)
        minimapButton:SetClampedToScreen(true)
        PositionDetachedButton(minimapButton)
        return
    end

    -- Only return the button to the Minimap when Questie itself detached it.
    -- Otherwise leave external button collectors alone.
    if minimapButton.questieDetached then
        minimapButton.questieDetached = nil

        if minimapButton:GetParent() == UIParent then
            minimapButton:SetParent(Minimap)
        end
    end

    if minimapButton:GetParent() ~= Minimap then
        return
    end

    minimapButton:SetMovable(false)
    minimapButton:SetClampedToScreen(false)
    UpdateMinimapButtonPosition(minimapButton)
end

function MinimapIcon:SetShown(shown)
    Questie.db.profile.minimap.hide = not shown

    if not shown then
        if minimapButton then
            minimapButton.db = Questie.db.profile.minimap
            minimapButton:Hide()
        else
            _LibDBIcon:Hide("Questie")
        end
        return
    end

    -- LibDBIcon may not have created the button at startup if it was hidden.
    if not minimapButton then
        _LibDBIcon:Show("Questie")
        minimapButton = _LibDBIcon:GetMinimapButton("Questie")

        if not minimapButton then
            return
        end

        ConfigureMinimapButtonPositioning()
        NormalizeMinimapButtonAppearance()
    else
        -- Avoid LibDBIcon:Show() here because it always repositions the button
        -- back onto the Minimap. This matters for detached buttons and external
        -- button collectors.
        minimapButton.db = Questie.db.profile.minimap
        minimapButton:Show()
    end

    minimapButton.db = Questie.db.profile.minimap
    self:ApplyButtonMode()
end

function MinimapIcon:Refresh()
    if not Questie.minimapConfigIcon then
        return
    end

    self:SetShown(not Questie.db.profile.minimap.hide)
end

function MinimapIcon:Init()
    _LibDBIcon:Register("Questie", _MinimapIcon:CreateDataBrokerObject(), Questie.db.profile.minimap);
    Questie.minimapConfigIcon = _LibDBIcon

    if (not _LibDBIcon.GetMinimapButton) then
        -- Compatibility shim for older LibDBIcon versions that don't have this method.
        function _LibDBIcon:GetMinimapButton(name)
            return _G["LibDBIcon10_" .. name] or (self.objects and self.objects[name])
        end
    end
    minimapButton = _LibDBIcon:GetMinimapButton("Questie")

    if minimapButton then
        minimapButton.db = Questie.db.profile.minimap
        ConfigureMinimapButtonPositioning()
        NormalizeMinimapButtonAppearance()
        MinimapIcon:ApplyButtonMode()
    end
end

function _MinimapIcon:CreateDataBrokerObject()
    local LDBDataObject = LibStub("LibDataBroker-1.1"):NewDataObject("Questie", {
        type = "data source",
        text = Questie.db.profile.ldbDisplayText,
        icon = QuestieLib.AddonPath.."Icons\\complete.blp",

        OnClick = function (_, button)
            if (not Questie.started) then
                return
            end

            if button == "LeftButton" then
                if IsControlKeyDown() and IsShiftKeyDown() then
                    Questie.db.profile.enabled = (not Questie.db.profile.enabled)
                    QuestieQuest:ToggleNotes(Questie.db.profile.enabled)

                    if minimapButton and minimapButton:IsMouseOver() then
                        local onEnter = minimapButton:GetScript("OnEnter")
                        if onEnter then
                            GameTooltip:Hide()
                            onEnter(minimapButton)
                        end
                    end

                    -- Close config window if it's open to avoid desyncing the Checkbox
                    QuestieOptions:HideFrame();
                    return;
                elseif IsShiftKeyDown() then
                    QuestieOptions:HideFrame();
                    QuestieJourney:HideJourneyWindow()
                    if InCombatLockdown() then
                        Questie:Print(l10n("Questie will open after combat ends."))
                    end
                    QuestieCombatQueue:Queue(function()
                        QuestieOptions:OpenConfigWindow()
                    end)
                    return;
                elseif IsModifierKeyDown() then
                    return;
                end

                QuestieOptions:HideFrame()
                QuestieJourney:ToggleJourneyWindow()

                return;
            elseif button == "RightButton" then
                if IsControlKeyDown() then
                    MinimapIcon:SetShown(false)
                    return;
                elseif IsModifierKeyDown() then
                    return;
                end

                QuestieMenu:Show()
                if QuestieJourney:IsShown() then
                    QuestieJourney:ToggleJourneyWindow();
                end

                return;
            end
        end,

        OnTooltipShow = function (tooltip)
            tooltip:AddDoubleLine(Questie:Colorize("Questie", 'gold'), Questie:Colorize(QuestieLib:GetAddonVersionString(), 'gray'))
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine(Questie:Colorize(l10n('Left Click'), 'lightBlue'), Questie:Colorize(l10n('Toggle My Journey'), 'white'))
            tooltip:AddDoubleLine(Questie:Colorize(l10n('Right Click'), 'lightBlue'), Questie:Colorize(l10n('Toggle Menu'), 'white'))
            tooltip:AddDoubleLine(Questie:Colorize(l10n('Shift') .. ' + ' .. l10n('Left Click'), 'lightBlue'), Questie:Colorize(l10n('Questie Options'), 'white'))
            local toggleLabel = Questie.db.profile.enabled and l10n('Hide Questie') or l10n('Show Questie')
            tooltip:AddDoubleLine(Questie:Colorize(l10n('Ctrl + Shift + Left Click'), 'lightBlue'), Questie:Colorize(toggleLabel, 'white'))
            tooltip:AddDoubleLine(Questie:Colorize(l10n('Ctrl + Right Click'), 'lightBlue'), Questie:Colorize(l10n('Hide Minimap Button'), 'white'))
        end,
    });

    self.LDBDataObject = LDBDataObject

    return LDBDataObject
end

--- Update the LibDataBroker text
function MinimapIcon:UpdateText(text)
    Questie.db.profile.ldbDisplayText = text
    _MinimapIcon.LDBDataObject.text = text
end
