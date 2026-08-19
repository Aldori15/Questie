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
local function UpdateMinimapButtonPosition(button)
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
        if originalOnDragStart then
            originalOnDragStart(self, ...)
        end
        self:SetScript("OnUpdate", DragMinimapButton)
    end)
    minimapButton:SetScript("OnDragStop", function(self, ...)
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
    ConfigureMinimapButtonPositioning()

    -- Normalize icon appearance regardless of which LibDBIcon version was loaded.
    if minimapButton and minimapButton.icon then
        minimapButton.icon:SetWidth(18)
        minimapButton.icon:SetHeight(18)
        minimapButton.icon:ClearAllPoints()
        minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
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
                    Questie.db.profile.minimap.hide = true;
                    Questie.minimapConfigIcon:Hide("Questie");
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
