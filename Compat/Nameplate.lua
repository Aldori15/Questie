---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@class QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@class QuestieNameplate
local QuestieNameplate = QuestieLoader:ImportModule("QuestieNameplate")

local _QuestieNameplate = QuestieNameplate.private
local npFrames = {}
local npActiveQuestNPCs = {}
local npBorderTexture = "Interface\\Tooltips\\Nameplate-Border"

local function isNamePlate(frame)
    if frame.UnitFrame  -- ElvUI
    or frame.extended   -- TidyPlates
    or frame.aloftData  -- Aloft
    or frame.kui  -- Kui_Nameplate
    then return true end

    local _, borderRegion = frame:GetRegions()
    if borderRegion and borderRegion:GetObjectType() == "Texture" then
        return borderRegion:GetTexture() == npBorderTexture
    end

    return false
end

local function scanWorldFrameChildren(...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame and (not npFrames[frame]) and isNamePlate(frame) then
            npFrames[frame] = select(7, frame:GetRegions())

            frame:HookScript("OnShow", QuestieCompat.NameplateCreated)
            frame:HookScript("OnHide", _QuestieNameplate.RemoveFrame)

            if frame:IsShown() then
                QuestieCompat.NameplateCreated(frame)
            end
        end
    end
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

local function isTargetNameplateFrame(frame, forceCheck)
    if (not forceCheck) and (not Questie.db.profile.nameplateObjectiveTextTargetOnly) then
        return true
    end

    local targetGUID = UnitGUID("target")
    local frameGUID = getNameplateFrameGUID(frame)
    if targetGUID and frameGUID then
        return frameGUID == targetGUID
    end

    local targetName = UnitName("target")
    local nameRegion = npFrames[frame]
    if (not targetName) or (not nameRegion) or nameRegion:GetText() ~= targetName then
        return false
    end

    local visibleTargetNameplateCount = 0
    local visibleTargetNameplate
    for nameplateFrame, nameplateNameRegion in pairs(npFrames) do
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

function QuestieCompat.NameplateCreated(frame)
    local nameRegion = npFrames[frame]
    local name = nameRegion and nameRegion:GetText()
    if not name then
        return
    end

    local key = npActiveQuestNPCs[name]
    if key then
        local objectiveInfo = _QuestieNameplate.GetValidObjectiveInfo(QuestieTooltips.lookupByKey[key])

        if objectiveInfo then
            local f = _QuestieNameplate.GetFrame(frame)
            f.Icon:SetTexture(objectiveInfo.icon)
            f.lastIcon = objectiveInfo.icon -- this is used to prevent updating the texture when it's already what it needs to be
            _QuestieNameplate.SetTargetNameplateState(f, isTargetNameplateFrame(frame, true))
            if Questie.db.profile.nameplateObjectiveTextTargetOnly and not f.isTargetNameplate then
                objectiveInfo.text = nil
            end
            _QuestieNameplate.SetObjectiveText(f, objectiveInfo.text)
            f:Show()
        end
    end
end

function QuestieCompat.UpdateNameplate()
    for frame in pairs(npFrames) do
        local nameRegion = npFrames[frame]
        local name = nameRegion and nameRegion:GetText()
        local key = npActiveQuestNPCs[name]

        local objectiveInfo = _QuestieNameplate.GetValidObjectiveInfo(QuestieTooltips.lookupByKey[key])

        if objectiveInfo then
            local f = _QuestieNameplate.GetFrame(frame)
            _QuestieNameplate.SetTargetNameplateState(f, isTargetNameplateFrame(frame, true))
            -- check if the texture needs to be changed
            if f.lastIcon ~= objectiveInfo.icon then
                f.lastIcon = objectiveInfo.icon
                f.Icon:SetTexture(objectiveInfo.icon)
            end

            if Questie.db.profile.nameplateObjectiveTextTargetOnly and not f.isTargetNameplate then
                objectiveInfo.text = nil
            end

            if f.lastText ~= objectiveInfo.text then
                _QuestieNameplate.SetObjectiveText(f, objectiveInfo.text)
            else
                _QuestieNameplate.ApplyFrameLayout(f)
            end
        else
            -- tooltip removed but we still have the frame active, remove it
            _QuestieNameplate.RemoveFrame(frame)
        end
    end
end

function QuestieCompat:QuestieTooltips_RegisterObjectiveTooltip(questId, key, objective)
    if key:find("m_") then
        local name = QuestieDB.QueryNPCSingle(tonumber(key:sub(3)), "name")
        if name then
            npActiveQuestNPCs[name] = key
        end
    end
end

function QuestieCompat.RegisterNameplateCompatibilityEvents()
    -- Nameplate / Target Frame Objective Events
    Questie:UnregisterEvent("NAME_PLATE_UNIT_ADDED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_ADDED
    Questie:UnregisterEvent("NAME_PLATE_UNIT_REMOVED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_REMOVED

    if Questie.db.profile.nameplateEnabled then
        QuestieNameplate.UpdateNameplate = QuestieCompat.UpdateNameplate
        -- GetAllQuestIds can yield, so it refreshes nameplates explicitly when it finishes.
        hooksecurefunc(QuestieTooltips, "RegisterObjectiveTooltip", QuestieCompat.QuestieTooltips_RegisterObjectiveTooltip)

        local lastNumChildren
        QuestieCompat.C_Timer.NewTicker(0.25, function()
            if not next(npActiveQuestNPCs) then
                return
            end

            local numChildren = WorldFrame:GetNumChildren()
            if numChildren ~= lastNumChildren then
                lastNumChildren = numChildren
                scanWorldFrameChildren(WorldFrame:GetChildren())
            end
        end)
    end
end
