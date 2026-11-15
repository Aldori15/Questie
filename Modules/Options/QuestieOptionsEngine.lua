---@class QuestieOptionsEngine
local QuestieOptionsEngine = QuestieLoader:CreateModule("QuestieOptionsEngine")
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local l10n = QuestieLoader:ImportModule("l10n")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local APP_NAME = "QuestieSettings"
local PANEL_TYPE = "QuestieSettingsPanel"
local WINDOW_WIDTH, WINDOW_HEIGHT = 820, 680
local frame, panel, eventFrame, options, selectedCategory
local categoryButtons = {}
local ownedColorCallback

local function Invoke(member, info, ...)
    if type(member) == "function" then
        return member(info, ...)
    elseif type(member) == "string" then
        return info.handler[member](info.handler, info, ...)
    end
    return member
end

-- Copy schema nodes only. Handlers, media lists and AceDB must retain their identities.
-- The original table remains available in the legacy options window.
local function CopyOptions(source, inheritedDisabled)
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    local disabled = source.disabled
    if disabled == nil then disabled = inheritedDisabled end
    if source.args then
        copy.args = {}
        for key, child in pairs(source.args) do
            copy.args[key] = CopyOptions(child, disabled)
        end
    end
    if source.plugins then
        copy.plugins = {}
        for plugin, children in pairs(source.plugins) do
            copy.plugins[plugin] = {}
            for key, child in pairs(children) do
                copy.plugins[plugin][key] = CopyOptions(child, disabled)
            end
        end
    end
    if source.type ~= "group" and source.type ~= "description" and source.type ~= "header" then
        local controlDisabled = source.dialogDisabled
        if controlDisabled == nil then controlDisabled = source.guiDisabled end
        if controlDisabled == nil then controlDisabled = disabled end
        copy.dialogDisabled, copy.guiDisabled = nil, nil
        copy.disabled = function(info)
            return InCombatLockdown() or Invoke(controlDisabled, info)
        end
    end
    for _, key in ipairs({"set", "func"}) do
        local member = source[key]
        if member then
            copy[key] = function(info, ...)
                -- Also guard delayed confirmations and already-open color pickers.
                if not InCombatLockdown() then return Invoke(member, info, ...) end
            end
        end
    end
    return copy
end

local function HideHorizontalPadding(args)
    for _, option in pairs(args) do
        if option.type == "description" and option.name == "" and type(option.width) == "number" then
            option.hidden = true
        end
    end
end

local function AddRowBreak(args, key, after)
    args[key] = {type = "description", name = "", fontSize = "small", width = "full", order = after + 0.0001}
end

-- Legacy spacer widths assume a particular window width. Adapt presentation only;
-- leave the original option paths and callbacks intact for both dialogs.
local function AdaptLayouts()
    for _, tab in pairs(options.args) do
        local args = tab.args
        local sound = args and args.sound_options_group
        if sound then
            sound.args.loadCustomSounds.width = "full"
            sound.args.soundLineBreak.name, sound.args.soundLineBreak.width = "", "full"
            for _, key in ipairs({"objectiveCompleteSoundChoice", "objectiveProgressSoundChoice"}) do
                AddRowBreak(sound.args, key .. "RowBreak", sound.args[key].order)
            end
        end
        local icons = args and args.quest_icon_toggles_group
        if icons then
            HideHorizontalPadding(args)
            args.hideMapIconsForUntrackedToggle.width = "full"
            local rows = {}
            for key, option in pairs(icons.args) do
                local prefix = key:match("^(.-)Minimap$")
                if prefix and icons.args[prefix .. "Label"] then
                    rows[#rows + 1] = {key, option.order}
                end
            end
            AddRowBreak(icons.args, "surfaceHeaderRowBreak", icons.args.minimapHeader.order)
            for _, row in ipairs(rows) do AddRowBreak(icons.args, row[1] .. "RowBreak", row[2]) end
            local overrides = args.iconOverrides.args
            HideHorizontalPadding(overrides)
            for _, option in pairs(overrides) do
                if option.type == "select" then option.width = option.width < 1 and 1 or 1.5 end
            end
        end
        if args and args.nameplate_options_group then
            HideHorizontalPadding(args)
            for _, key in ipairs({"nameplate_options_group", "targetframe_options_group"}) do
                local group = args[key].args
                HideHorizontalPadding(group)
                for _, option in pairs(group) do
                    if option.type == "toggle" or (option.type == "range" and type(option.width) == "number" and option.width > 2) then
                        option.width = "full"
                    end
                end
            end
        end
    end
end

local function CloseColorPicker()
    if ownedColorCallback and ColorPickerFrame.func == ownedColorCallback then
        -- Detach callbacks before pooled widgets can be reused for another option.
        local function noop() end
        ColorPickerFrame.func = noop
        ColorPickerFrame.opacityFunc = noop
        ColorPickerFrame.cancelFunc = noop
        HideUIPanel(ColorPickerFrame)
    end
    ownedColorCallback = nil
end

local function IsSettingsWidget(widget)
    while widget do
        if widget:GetUserData("appName") == APP_NAME then return true end
        widget = widget.parent
    end
    return false
end

local function StyleWidget(widget)
    if widget.type == "CheckBox" and widget.highlight then
        local option = widget:GetUserData("option")
        if not option or option.style ~= "radio" then
            if widget.highlight:SetTexture(QuestieLib.AddonPath .. "Icons\\checkbox-minimal-highlight.blp") == false then
                widget.highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            end
        end
    elseif widget.type == "ColorPicker" and not widget.questieSettingsColorHook then
        widget.questieSettingsColorHook = true
        widget.frame:HookScript("OnClick", function()
            if IsSettingsWidget(widget) then ownedColorCallback = ColorPickerFrame.func end
        end)
    end
    if widget.children then
        -- Nested tab/tree groups add children after the initial render too.
        if not widget.questieSettingsAddChild then
            local addChild = widget.AddChild
            widget.questieSettingsAddChild = true
            widget.AddChild = function(self, child, ...)
                addChild(self, child, ...)
                if IsSettingsWidget(self) then StyleWidget(child) end
            end
        end
        for _, child in ipairs(widget.children) do StyleWidget(child) end
    end
end

local function RegisterPanel()
    AceGUI:RegisterWidgetType(PANEL_TYPE, function()
        local widgetFrame = CreateFrame("Frame", nil, UIParent)
        local content = CreateFrame("Frame", nil, widgetFrame)
        content:SetPoint("TOPLEFT")
        content:SetPoint("BOTTOMRIGHT")
        local widget = {
            type = PANEL_TYPE, frame = widgetFrame, content = content,
            OnAcquire = function() end,
            OnWidthSet = function(self, width)
                self.content:SetWidth(width)
                self.content.width = width
            end,
            OnHeightSet = function(self, height)
                self.content:SetHeight(height)
                self.content.height = height
            end,
        }
        AceGUI:RegisterAsContainer(widget)
        local releaseChildren = widget.ReleaseChildren
        widget.ReleaseChildren = function(self)
            CloseColorPicker()
            releaseChildren(self)
        end
        StyleWidget(widget)
        return widget
    end, 1)
end

local function CategoryInfo(key)
    local category = options.args[key]
    return {key, handler = category.handler or options.handler, option = category,
        options = options, appName = APP_NAME, [0] = APP_NAME, type = "group",
        uiType = "dialog", uiName = "AceConfigDialog-3.0", arg = category.arg}
end

local function CategoryValue(key, field)
    local value = options.args[key][field]
    if type(value) == "function" then return value(CategoryInfo(key)) end
    return value
end

local function Backdrop(target, r, g, b)
    target:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}})
    target:SetBackdropColor(r, g, b, 0.98)
    target:SetBackdropBorderColor(0.45, 0.45, 0.45)
end

local function FitToScreen()
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / WINDOW_WIDTH, (UIParent:GetHeight() - 60) / WINDOW_HEIGHT))
end

local function CreateSettingsFrame()
    frame = CreateFrame("Frame", "QuestieSettingsFrame", UIParent)
    frame:Hide()
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    Backdrop(frame, 0.055, 0.055, 0.065)
    tinsert(UISpecialFrames, "QuestieSettingsFrame")

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", -48, -8)
    titleBar:SetHeight(64)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local portrait = titleBar:CreateTexture(nil, "ARTWORK")
    portrait:SetTexture(QuestieLib.AddonPath .. "Icons\\questie_portrait.blp")
    portrait:SetSize(64, 64)
    portrait:SetPoint("LEFT", 4, 0)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", portrait, "RIGHT", 12, 0)
    title:SetText("Questie-335")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", 12, -80)
    sidebar:SetPoint("BOTTOMLEFT", 12, 16)
    sidebar:SetWidth(180)
    Backdrop(sidebar, 0.035, 0.035, 0.045)

    local journey = CreateFrame("Button", nil, sidebar)
    journey:SetSize(162, 40)
    journey:SetPoint("BOTTOMLEFT", 9, 12)
    journey:EnableMouse(true)
    journey:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    journey.text = journey:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    journey.text:SetPoint("LEFT", 12, 0)
    journey.text:SetPoint("RIGHT", -8, 0)
    journey.text:SetJustifyH("LEFT")
    journey.text:SetText(l10n("My Journey"))
    journey:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if not Questie.started then
            Questie:Print(l10n("Please wait a moment for Questie to finish loading"))
            return
        end
        frame:Hide()
        QuestieJourney:BuildMainFrame()
        QuestieJourney.tabGroup:SelectTab("journey")
        if not QuestieJourney:IsShown() then QuestieJourney:ToggleJourneyWindow() end
    end)
    frame.journeyButton = journey

    frame.heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.heading:SetPoint("TOPLEFT", 212, -86)
    frame.heading:SetPoint("TOPRIGHT", -28, -86)
    frame.heading:SetJustifyH("LEFT")
    frame.combatText = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    frame.combatText:SetPoint("BOTTOMLEFT", 212, 18)
    frame.combatText:SetPoint("BOTTOMRIGHT", -28, 18)
    frame.combatText:SetJustifyH("LEFT")
    frame.combatText:SetText(ERR_NOT_IN_COMBAT)

    panel = AceGUI:Create(PANEL_TYPE)
    panel.frame:SetParent(frame)
    panel.frame:SetPoint("TOPLEFT", 208, -118)
    panel.frame:SetPoint("BOTTOMRIGHT", -24, 42)

    local keys = {}
    for key in pairs(options.args) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local first, second = CategoryValue(a, "order") or 100, CategoryValue(b, "order") or 100
        if first ~= second then
            if first < 0 then return second < 0 and first < second end
            return second < 0 or first < second
        end
        return a < b
    end)
    for _, key in ipairs(keys) do
        local button = CreateFrame("Button", nil, sidebar)
        button:SetSize(162, 40)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.selected = button:CreateTexture(nil, "BACKGROUND")
        button.selected:SetTexture("Interface\\Buttons\\WHITE8X8")
        button.selected:SetVertexColor(0.15, 0.33, 0.48, 0.8)
        button.selected:SetAllPoints()
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.text:SetPoint("LEFT", 12, 0)
        button.text:SetPoint("RIGHT", -8, 0)
        button.text:SetJustifyH("LEFT")
        button:SetScript("OnClick", function() QuestieOptionsEngine:SelectCategory(key) end)
        categoryButtons[#categoryButtons + 1] = {key = key, button = button}
    end
    selectedCategory = keys[1]
    frame:SetScript("OnHide", function()
        AceGUI:ClearFocus()
        panel:ReleaseChildren()
    end)
    FitToScreen()
end

function QuestieOptionsEngine:Initialize(source)
    if options then return end
    options = CopyOptions(source)
    AdaptLayouts()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
    RegisterPanel()
    for _, name in ipairs({"QUESTIE_RELOAD", "QUESTIE_LANG_CHANGED_RELOAD", "QUESTIE_RESET_CONFIRM",
        "QUESTIE_JOURNEY_RESET_CONFIRM", "QUESTIE_RECOMPILE_DATABASE_CONFIRM"}) do
        local dialog = StaticPopupDialogs[name]
        if dialog and dialog.OnAccept then
            local accept = dialog.OnAccept
            dialog.OnAccept = function(...)
                if not InCombatLockdown() then return accept(...) end
            end
        end
    end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function() self:RefreshIfShown() end)
    AceConfigRegistry.RegisterCallback(self, "ConfigTableChange", function(_, appName)
        if appName == "Questie" or appName == APP_NAME then self:RefreshIfShown() end
    end)
    for _, event in ipairs({"OnProfileChanged", "OnProfileCopied", "OnProfileReset"}) do
        Questie.db.RegisterCallback(self, event, function() self:RefreshIfShown() end)
    end

    local category = CreateFrame("Frame", "QuestieSettingsCategory", InterfaceOptionsFramePanelContainer)
    category:Hide()
    category.name = "Questie-335"
    local title = category:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Questie-335")
    local open = CreateFrame("Button", nil, category, "UIPanelButtonTemplate")
    open:SetSize(240, 28)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
    open:SetText(l10n("Questie Options"))
    open:SetScript("OnClick", function()
        HideUIPanel(InterfaceOptionsFrame)
        HideUIPanel(GameMenuFrame)
        self:ShowFrame()
    end)
    InterfaceOptions_AddCategory(category)
end

function QuestieOptionsEngine:IsShown()
    return frame and frame:IsShown() or false
end

function QuestieOptionsEngine:RefreshStates()
    if not self:IsShown() then return end
    local visible = {}
    for _, entry in ipairs(categoryButtons) do
        local hidden = CategoryValue(entry.key, "hidden")
        entry.button:Hide()
        if not hidden then visible[#visible + 1] = entry end
    end
    local selectedVisible = false
    for index, entry in ipairs(visible) do
        local button = entry.button
        button:SetPoint("TOPLEFT", 9, -12 - (index - 1) * 44)
        button.text:SetText(CategoryValue(entry.key, "name"))
        button:Show()
        if entry.key == selectedCategory then selectedVisible = true end
    end
    if not selectedVisible then selectedCategory = visible[1] and visible[1].key end
    for _, entry in ipairs(visible) do
        if entry.key == selectedCategory then entry.button.selected:Show() else entry.button.selected:Hide() end
    end
    if InCombatLockdown() then
        frame.combatText:Show()
        frame.journeyButton:Disable()
        frame.journeyButton.text:SetTextColor(0.5, 0.5, 0.5)
    else
        frame.combatText:Hide()
        frame.journeyButton:Enable()
        frame.journeyButton.text:SetTextColor(1, 1, 1)
    end
    if selectedCategory then
        frame.heading:SetText(CategoryValue(selectedCategory, "name"))
        AceConfigDialog:Open(APP_NAME, panel, selectedCategory)
    else
        panel:ReleaseChildren()
    end
end

function QuestieOptionsEngine:RefreshIfShown()
    if not self:IsShown() then return end
    eventFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        QuestieOptionsEngine:RefreshStates()
    end)
end

function QuestieOptionsEngine:SelectCategory(key)
    if not options.args[key] then return end
    AceGUI:ClearFocus()
    selectedCategory = key
    self:RefreshStates()
end

function QuestieOptionsEngine:ShowFrame()
    if not options then return end
    QuestieEventHandler:CancelWindowRestores()
    QuestieOptions:HideFrame()
    if QuestieJourney:IsShown() then QuestieJourney:ToggleJourneyWindow() end
    if not frame then CreateSettingsFrame() end
    FitToScreen()
    frame:Show()
    self:RefreshStates()
end

function QuestieOptionsEngine:HideFrame()
    if frame then frame:Hide() end
end

function QuestieOptionsEngine:ToggleConfigWindow()
    if self:IsShown() then self:HideFrame() else self:ShowFrame() end
end
