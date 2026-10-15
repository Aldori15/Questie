---@class QuestieNameplate
local QuestieNameplate = QuestieLoader:CreateModule("QuestieNameplate")
local _QuestieNameplate = QuestieNameplate.private
-------------------------
--Import modules.
-------------------------
---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local UnitGUID = UnitGUID -- Raw GUIDs distinguish individual Wrath nameplates.
local QuestieUnitGUID = QuestieCompat.UnitGUID

local nameplateNameRegions = {}
local objectiveKeysByName = {}
local iconFrames = {}
local unusedIconFrames = {}
local initialized = false

local activeTargetFrame
local NAMEPLATE_BORDER_TEXTURE = "Interface\\Tooltips\\Nameplate-Border"
local NAMEPLATE_TEXT_WIDTH = 260
local NAMEPLATE_TEXT_FONT_SIZE = 10
local NAMEPLATE_DEFAULT_X = -17
local NAMEPLATE_DEFAULT_Y = -7
local NAMEPLATE_DEFAULT_SCALE = 1
local NAMEPLATE_TEXT_DEFAULT_X = 0
local NAMEPLATE_TEXT_DEFAULT_Y = 24
local NAMEPLATE_TEXT_DEFAULT_SCALE = 1

local function getNameplateLayoutAnchor(frame)
    local parent = frame and frame:GetParent()
    if not parent then
        return nil
    end

    local unitFrame = parent.UnitFrame or parent.unitFrame
    local healthBar = unitFrame and (unitFrame.Health or unitFrame.HealthBar or unitFrame.health or unitFrame.healthBar)
    if healthBar and healthBar.GetObjectType then
        return healthBar
    end

    healthBar = parent.Health or parent.HealthBar or parent.health or parent.healthBar
    if healthBar and healthBar.GetObjectType then
        return healthBar
    end

    return parent
end

local function getNameplateLayoutXOffset(frame, layoutAnchor)
    local parent = frame and frame:GetParent()
    if (not parent) or (not layoutAnchor) or parent == layoutAnchor then
        return 0
    end

    local parentLeft = parent:GetLeft()
    local anchorLeft = layoutAnchor:GetLeft()
    if parentLeft and anchorLeft then
        local parentScale = parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
        local anchorScale = layoutAnchor.GetEffectiveScale and layoutAnchor:GetEffectiveScale() or parentScale
        return ((anchorLeft * anchorScale) - (parentLeft * parentScale)) / parentScale
    end

    return 0
end

local function getNameplateLayoutYOffset(frame, layoutAnchor)
    local parent = frame and frame:GetParent()
    if (not parent) or (not layoutAnchor) or parent == layoutAnchor then
        return 0
    end

    local _, parentY = parent:GetCenter()
    local _, anchorY = layoutAnchor:GetCenter()
    if parentY and anchorY then
        local parentScale = parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
        local anchorScale = layoutAnchor.GetEffectiveScale and layoutAnchor:GetEffectiveScale() or parentScale
        return ((parentY * parentScale) - (anchorY * anchorScale)) / parentScale
    end

    return 0
end

local function getNameplateTextYOffset(frame, layoutAnchor, yOffset)
    if Questie.db.profile.nameplateObjectiveTextTargetOnly then
        return yOffset
    end

    return yOffset + getNameplateLayoutYOffset(frame, layoutAnchor)
end

local function setTargetNameplateState(frame, isTargetNameplate)
    frame.isTargetNameplate = isTargetNameplate
    frame.useHealthbarAnchor = isTargetNameplate
end

local function scheduleNameplateLayoutRefresh(frame)
    C_Timer.After(0.1, function()
        if frame and frame:GetParent() then
            _QuestieNameplate.ApplyFrameLayout(frame)
        end
    end)
end

local function isNamePlate(frame)
    if frame.UnitFrame  -- ElvUI
    or frame.extended   -- TidyPlates
    or frame.aloftData  -- Aloft
    or frame.kui  -- Kui_Nameplate
    then return true end

    local _, borderRegion = frame:GetRegions()
    if borderRegion and borderRegion:GetObjectType() == "Texture" then
        return borderRegion:GetTexture() == NAMEPLATE_BORDER_TEXTURE
    end

    return false
end

local function getGUID(unit)
    if type(unit) == "string" then
        return UnitGUID(unit)
    elseif type(unit) == "table" then
        if unit.guid then
            return unit.guid
        elseif type(unit.unit) == "string" then
            return UnitGUID(unit.unit)
        elseif type(unit.unitid) == "string" then
            return UnitGUID(unit.unitid)
        elseif type(unit.unitID) == "string" then
            return UnitGUID(unit.unitID)
        elseif type(unit.unitToken) == "string" then
            return UnitGUID(unit.unitToken)
        elseif unit.isTarget then
            return UnitGUID("target")
        elseif unit.isMouseover then
            return UnitGUID("mouseover")
        elseif type(unit.partyID) == "string" then
            return UnitGUID(unit.partyID)
        end
    end
end

local function getGUIDFromCandidates(...)
    for i = 1, select("#", ...) do
        local guid = getGUID(select(i, ...))
        if guid then return guid end
    end
end

local function getNameplateFrameGUID(frame)
    local guid = getGUIDFromCandidates(frame.unit, frame.unitid, frame.unitID, frame.unitToken, frame.namePlateUnitToken)
    if guid then return guid end

    if frame.UnitFrame then
        guid = getGUIDFromCandidates(frame.UnitFrame.unit, frame.UnitFrame.unitid, frame.UnitFrame.unitID, frame.UnitFrame.unitToken)
        if guid then return guid end
    end

    if frame.unitFrame then
        guid = getGUIDFromCandidates(frame.unitFrame.unit, frame.unitFrame.unitid, frame.unitFrame.unitID, frame.unitFrame.unitToken)
        if guid then return guid end
    end

    if frame.extended then
        guid = getGUIDFromCandidates(frame.extended.unit, frame.extended.unitid, frame.extended.unitID, frame.extended.unitToken)
        if guid then return guid end
    end

    if frame.aloftData then
        guid = getGUIDFromCandidates(frame.aloftData.unit, frame.aloftData.unitid, frame.aloftData.unitID, frame.aloftData.unitToken)
        if guid then return guid end
    end

    if frame.kui then
        return getGUIDFromCandidates(frame.kui.unit, frame.kui.unitid, frame.kui.unitID, frame.kui.unitToken)
    end
end

local function isTargetNameplateFrame(frame)
    local targetGUID = UnitGUID("target")
    local frameGUID = getNameplateFrameGUID(frame)
    if targetGUID and frameGUID then
        return frameGUID == targetGUID
    end

    local targetName = UnitName("target")
    local nameRegion = nameplateNameRegions[frame]
    if (not targetName) or (not nameRegion) or nameRegion:GetText() ~= targetName then
        return false
    end

    local visibleTargetNameplateCount = 0
    local visibleTargetNameplate
    for nameplateFrame, nameplateNameRegion in pairs(nameplateNameRegions) do
        if nameplateFrame:IsShown() and nameplateNameRegion:GetText() == targetName then
            visibleTargetNameplateCount = visibleTargetNameplateCount + 1
            visibleTargetNameplate = nameplateFrame
        end
    end

    if visibleTargetNameplateCount == 1 then
        return frame == visibleTargetNameplate
    end

    -- 3.3.5 exposes no reliable nameplate frame <-> GUID mapping here.
    -- If multiple visible nameplates share the target name, avoid showing text on all of them.
    return false
end

-- Creation and progress updates use the same frame-based rendering path.
local function refreshNameplate(nameplate)
    local nameRegion = nameplateNameRegions[nameplate]
    local name = nameRegion and nameRegion:GetText()
    if not Questie.db.profile.nameplateEnabled or not nameplate:IsShown() or not name then
        _QuestieNameplate.RemoveFrame(nameplate)
        return
    end

    local key = objectiveKeysByName[name]
    local objectiveInfo = key and _QuestieNameplate.GetValidObjectiveInfo(QuestieTooltips.lookupByKey[key])
    if not objectiveInfo then
        _QuestieNameplate.RemoveFrame(nameplate)
        return
    end

    local frame = _QuestieNameplate.GetFrame(nameplate)
    _QuestieNameplate.SetTargetNameplateState(frame, isTargetNameplateFrame(nameplate))
    if frame.lastIcon ~= objectiveInfo.icon then
        frame.Icon:SetTexture(objectiveInfo.icon)
        frame.lastIcon = objectiveInfo.icon
    end
    local text = objectiveInfo.text
    if Questie.db.profile.nameplateObjectiveTextTargetOnly and not frame.isTargetNameplate then
        text = nil
    end
    if frame.lastText ~= text then
        _QuestieNameplate.SetObjectiveText(frame, text)
    else
        _QuestieNameplate.ApplyFrameLayout(frame)
    end
    frame:Show()
end

local function scanWorldFrameChildren(...)
    for index = 1, select("#", ...) do
        local frame = select(index, ...)
        if frame and not nameplateNameRegions[frame] and isNamePlate(frame) then
            local nameRegion = select(7, frame:GetRegions())
            if nameRegion then
                nameplateNameRegions[frame] = nameRegion
                frame:HookScript("OnShow", refreshNameplate)
                -- The frame identity stays valid after its unit disappears or icons are disabled.
                frame:HookScript("OnHide", _QuestieNameplate.RemoveFrame)
                if frame:IsShown() then refreshNameplate(frame) end
            end
        end
    end
end

local function registerObjectiveNPC(_, questId, key)
    if key:find("m_") then
        local name = QuestieDB.QueryNPCSingle(tonumber(key:sub(3)), "name")
        if name then objectiveKeysByName[name] = key end
    end
end

-- Original Wrath discovers WorldFrame children; it has no modern nameplate unit-token events.
function QuestieNameplate:Initialize()
    if initialized then return end
    initialized = true
    if not Questie.db.profile.nameplateEnabled then return end

    hooksecurefunc(QuestieTooltips, "RegisterObjectiveTooltip", registerObjectiveNPC)
    local lastNumChildren
    C_Timer.NewTicker(0.25, function()
        if not next(objectiveKeysByName) then return end
        local numChildren = WorldFrame:GetNumChildren()
        if numChildren ~= lastNumChildren then
            lastNumChildren = numChildren
            scanWorldFrameChildren(WorldFrame:GetChildren())
        end
    end)
end

function QuestieNameplate:UpdateNameplate()
    for frame in pairs(nameplateNameRegions) do
        refreshNameplate(frame)
    end
end

function QuestieNameplate:RedrawIcons()
    for _, frame in pairs(iconFrames) do
        _QuestieNameplate.ApplyFrameLayout(frame)
    end
end

function QuestieNameplate:HideCurrentFrames()
    for nameplate in pairs(iconFrames) do
        _QuestieNameplate.RemoveFrame(nameplate)
    end
end

function QuestieNameplate:DrawTargetFrame()
    Questie.Debug(Questie.DEBUG_SPAM, "[QuestieNameplate:DrawTargetFrame]")

    if (not Questie.db.profile.nameplateTargetFrameEnabled) then
        return
    end

    -- always remove the previous frame if it exists
    if activeTargetFrame ~= nil then
        activeTargetFrame.Icon:SetTexture(nil)
        activeTargetFrame:Hide()
    end

    local unitGUID = QuestieUnitGUID("target")
    local unitName = UnitName("target")

    if (not unitName) or (not unitGUID) then
        -- We need the GUID and name, this should not happen
        return
    end

    local unitType, _, _, _, _, npcId, _ = strsplit("-", unitGUID)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        -- We only draw name plates on NPCs/creatures and Vehicles (oddness with Chillmaw being a Vehicle?!?!) and skip players, pets, etc
        return
    end

    local icon = _QuestieNameplate.GetValidIcon(QuestieTooltips.lookupByKey["m_" .. npcId])
    if (not icon) then
        return
    end

    if not activeTargetFrame then
        activeTargetFrame = _QuestieNameplate.GetTargetFrameIconFrame()
    end

    activeTargetFrame.Icon:SetTexture(icon)
    activeTargetFrame:Show()
end

function QuestieNameplate:HideCurrentTargetFrame()
    if (not activeTargetFrame) then
        return
    end

    activeTargetFrame.Icon:SetTexture(nil)
    activeTargetFrame:Hide()
    activeTargetFrame = nil
end

function QuestieNameplate:RedrawFrameIcon()
    if (not Questie.db.profile.nameplateTargetFrameEnabled) or (not activeTargetFrame) then
        return
    end

    local iconScale = Questie.db.profile.nameplateTargetFrameScale
    activeTargetFrame:SetWidth(16 * iconScale)
    activeTargetFrame:SetHeight(16 * iconScale)
    activeTargetFrame:SetPoint("RIGHT", Questie.db.profile.nameplateTargetFrameX, Questie.db.profile.nameplateTargetFrameY)
end


---@param nameplate Frame
function _QuestieNameplate.GetFrame(nameplate)
    if iconFrames[nameplate] then
        return iconFrames[nameplate]
    end

    local parent = nameplate

    local frame = tremove(unusedIconFrames)

    if (not frame) then
        frame = CreateFrame("Frame")
    end

    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(10)
    frame:EnableMouse(false)
    frame:SetParent(parent)
    frame.isTargetNameplate = false
    frame.useHealthbarAnchor = false

    frame.Icon = frame.Icon or frame:CreateTexture(nil, "ARTWORK")
    frame.TextFrame = frame.TextFrame or CreateFrame("Frame", nil, frame)
    frame.Text = frame.Text or frame.TextFrame:CreateFontString(nil, "OVERLAY")
    if frame.Text.SetWordWrap then
        frame.Text:SetWordWrap(false)
    end
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetShadowOffset(1, -1)

    _QuestieNameplate.ApplyFrameLayout(frame)
    scheduleNameplateLayoutRefresh(frame)

    iconFrames[nameplate] = frame

    return frame
end

function _QuestieNameplate.GetTargetFrameIconFrame()
    local frame = CreateFrame("Frame")

    local iconScale = Questie.db.profile.nameplateTargetFrameScale
    local strata = "MEDIUM"

    local targetFrame = TargetFrame -- Default Blizzard target frame
    if ElvUF_Target then
        targetFrame = ElvUF_Target
        strata = "LOW"
    elseif PitBull4_Frames_Target then
        targetFrame = PitBull4_Frames_Target
    elseif AzeriteUnitFrameTarget then
        targetFrame = AzeriteUnitFrameTarget
        strata = "LOW"
    elseif GwTargetUnitFrame then
        targetFrame = GwTargetUnitFrame
        strata = "LOW"
    elseif SUFUnittarget then
        targetFrame = SUFUnittarget
        frame:SetFrameLevel(SUFUnittarget:GetFrameLevel() + 1)
    end

    frame:SetParent(targetFrame)
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(11)
    frame:SetWidth(16 * iconScale)
    frame:SetHeight(16 * iconScale)
    frame:EnableMouse(false)

    frame:SetPoint("RIGHT", Questie.db.profile.nameplateTargetFrameX, Questie.db.profile.nameplateTargetFrameY)

    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:ClearAllPoints()
    frame.Icon:SetAllPoints(frame)

    return frame
end

---@param nameplate Frame
function _QuestieNameplate.RemoveFrame(nameplate)
    local frame = iconFrames[nameplate]
    if not frame then return end

    iconFrames[nameplate] = nil
    frame.Icon:SetTexture(nil)
    frame.lastIcon = nil
    _QuestieNameplate.SetObjectiveText(frame, nil)
    frame:Hide()
    table.insert(unusedIconFrames, frame)
end

---@param tooltips table<string, table>
function _QuestieNameplate.GetValidIcon(tooltips) -- helper function to get the first valid (incomplete) icon from the specified tooltip, or nil if there is none
    local objectiveInfo = _QuestieNameplate.GetValidObjectiveInfo(tooltips)
    return objectiveInfo and objectiveInfo.icon or nil
end

function _QuestieNameplate.GetValidObjectiveInfo(tooltips) -- helper function to get the first valid (incomplete) objective info from the specified tooltip, or nil if there is none
    if (not tooltips) then
        return
    end

    for _, tooltip in pairs(tooltips) do
        if tooltip.objective and tooltip.objective.Update then
            tooltip.objective:Update() -- get latest qlog data if its outdated
            if (not tooltip.objective.Completed) and tooltip.objective.Icon then
                -- If the tooltip icon is Questie.ICON_TYPE_OBJECT we use Questie.ICON_TYPE_LOOT because NPCs should never show
                -- a cogwheel icon (for pfquest only).
                local iconType = tooltip.objective.Icon
                local icon
                if iconType == Questie.ICON_TYPE_LOOT then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["loot"] or Questie.db.profile.ICON_LOOT or Questie.icons["loot"]
                elseif iconType == Questie.ICON_TYPE_OBJECT then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["loot"] or Questie.db.profile.ICON_LOOT or Questie.icons["loot"]
                elseif iconType == Questie.ICON_TYPE_SLAY then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["slay"] or Questie.db.profile.ICON_SLAY or Questie.icons["slay"]
                elseif iconType == Questie.ICON_TYPE_EVENT then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["event"] or Questie.db.profile.ICON_EVENT or Questie.icons["event"]
                elseif iconType == Questie.ICON_TYPE_TALK then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["talk"] or Questie.db.profile.ICON_TALK or Questie.icons["talk"]
                elseif iconType == Questie.ICON_TYPE_INTERACT then
                    icon = Questie.db.profile.iconTheme == 'pfquest' and Questie.icons["interact"] or Questie.db.profile.ICON_INTERACT or Questie.icons["interact"]
                --? icon types below here are never reached or just not used on nameplates ?
                elseif iconType == Questie.ICON_TYPE_AVAILABLE or iconType == Questie.ICON_TYPE_AVAILABLE_GRAY then
                    icon = Questie.icons["available"]
                elseif iconType == Questie.ICON_TYPE_REPEATABLE then
                    icon = Questie.icons["repeatable"]
                elseif iconType == Questie.ICON_TYPE_COMPLETE then
                    icon = Questie.icons["complete"]
                end

                if icon then
                    return {
                        icon = icon,
                        text = _QuestieNameplate.GetObjectiveText(tooltip.objective),
                    }
                end
            end
        end
    end
end

function _QuestieNameplate.GetObjectiveText(objective)
    if not Questie.db.profile.nameplateShowObjectiveText then
        return nil
    end

    local objectiveText = QuestieLib:GetObjectiveDescription(objective)
    if objectiveText == "" then
        return nil
    end

    local color = QuestieLib:GetRGBForObjective(objective)
    local progress
    if objective.Needed and objective.Collected then
        progress = tostring(objective.Collected) .. "/" .. tostring(objective.Needed)
    end

    if progress then
        if Questie.db.profile.showQuestProgressFirst then
            return color .. "[" .. progress .. " " .. objectiveText .. "]|r"
        else
            return color .. "[" .. objectiveText .. ": " .. progress .. "]|r"
        end
    end

    return color .. "[" .. objectiveText .. "]|r"
end

function _QuestieNameplate.SetObjectiveText(frame, text)
    if not frame.Text then
        return
    end

    frame.lastText = text
    _QuestieNameplate.ApplyFrameLayout(frame)
    if text then
        frame.Text:SetText(text)
        frame.Text:Show()
        if frame.TextFrame then
            frame.TextFrame:Show()
        end
    else
        frame.Text:SetText("")
        frame.Text:Hide()
        if frame.TextFrame then
            frame.TextFrame:Hide()
        end
    end
end

function _QuestieNameplate.SetTargetNameplateState(frame, isTargetNameplate)
    setTargetNameplateState(frame, isTargetNameplate)
end

function _QuestieNameplate.ApplyFrameLayout(frame)
    local iconScale = Questie.db.profile.nameplateScale or NAMEPLATE_DEFAULT_SCALE
    local iconSize = 16 * iconScale
    local showText = Questie.db.profile.nameplateShowObjectiveText and frame.lastText
    local textScale = Questie.db.profile.nameplateTextScale or NAMEPLATE_TEXT_DEFAULT_SCALE
    local textFontSize = NAMEPLATE_TEXT_FONT_SIZE * textScale
    local xOffset = Questie.db.profile.nameplateX or NAMEPLATE_DEFAULT_X
    local yOffset = Questie.db.profile.nameplateY or NAMEPLATE_DEFAULT_Y
    local frameHeight = iconSize

    if showText then
        xOffset = Questie.db.profile.nameplateTextX or NAMEPLATE_TEXT_DEFAULT_X
        yOffset = Questie.db.profile.nameplateTextY or NAMEPLATE_TEXT_DEFAULT_Y
        frameHeight = math.max(iconSize, textFontSize + 8)
    end

    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(showText and 20 or 10)
    frame:ClearAllPoints()
    local layoutAnchor = getNameplateLayoutAnchor(frame)
    local parent = frame:GetParent()
    if showText and frame.useHealthbarAnchor and layoutAnchor and parent and layoutAnchor ~= parent then
        frame:SetPoint("LEFT", layoutAnchor, "LEFT", xOffset, getNameplateTextYOffset(frame, layoutAnchor, yOffset))
    elseif parent then
        frame:SetPoint("LEFT", parent, "LEFT", xOffset + getNameplateLayoutXOffset(frame, layoutAnchor), yOffset)
    else
        frame:SetPoint("LEFT", xOffset, yOffset)
    end
    frame:SetWidth(showText and (iconSize + 4 + NAMEPLATE_TEXT_WIDTH) or iconSize)
    frame:SetHeight(frameHeight)

    frame.Icon:ClearAllPoints()
    frame.Icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Icon:SetWidth(iconSize)
    frame.Icon:SetHeight(iconSize)

    if frame.TextFrame and frame.Text then
        frame.TextFrame:ClearAllPoints()
        frame.TextFrame:SetPoint("LEFT", frame.Icon, "RIGHT", 4, 0)
        frame.TextFrame:SetWidth(NAMEPLATE_TEXT_WIDTH)
        frame.TextFrame:SetHeight(textFontSize + 8)

        frame.Text:ClearAllPoints()
        frame.Text:SetAllPoints(frame.TextFrame)
        frame.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", textFontSize, "OUTLINE")
        if frame.Text.SetTextHeight then
            frame.Text:SetTextHeight(textFontSize)
        end
        if showText and frame.lastText then
            frame.TextFrame:Show()
            frame.Text:Show()
        else
            frame.TextFrame:Hide()
            frame.Text:Hide()
        end
    end
end
