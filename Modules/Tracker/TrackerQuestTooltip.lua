---@class TrackerQuestTooltip
local TrackerQuestTooltip = QuestieLoader:CreateModule("TrackerQuestTooltip")
local TrackerData = QuestieLoader:ImportModule("TrackerData")
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
local QuestieComms = QuestieLoader:ImportModule("QuestieComms")
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
local l10n = QuestieLoader:ImportModule("l10n")
local C_Timer = QuestieCompat.C_Timer

local tooltip, hoveredLine, refreshTicker
local layoutInitialized = false

function TrackerQuestTooltip.Hide(line)
    if line and hoveredLine ~= line then return end
    hoveredLine = nil
    if refreshTicker then
        refreshTicker:Cancel()
        refreshTicker = nil
    end
    if tooltip then tooltip:Hide() end
end

local function _GetQuest(line)
    if not line or not line:IsVisible() or not MouseIsOver(line)
        or (line.mode ~= "quest" and line.mode ~= "objective") then return end
    for _, key in ipairs({"statusIcon", "playButton", "expandQuest", "button", "altButton"}) do
        local button = line[key]
        if button and button:GetParent() == line and button:IsVisible() and MouseIsOver(button) then return end
    end
    local quest = line.Quest
    -- Achievement objectives share the row mode and can collide with quest IDs.
    if quest and TrackerData.GetQuest(quest.Id) == quest and TrackerData.ContainsQuest(quest.Id) then
        return quest
    end
end

local function _CanShow()
    return Questie.db.profile.enableTooltips and Questie.db.profile.trackerEnabled
        and (QuestieCompat.IsInGroup() or QuestieCompat.IsInRaid())
end

local function _GetTitleLine(line)
    if line.mode == "quest" then return line end
    for index = 1, TrackerLinePool.GetHighestIndex() do
        local candidate = TrackerLinePool.GetLine(index)
        if candidate and candidate.mode == "quest" and candidate.Quest == line.Quest and candidate:IsVisible() then
            return candidate
        end
    end
    return line
end

local function _SortedIndices(objectives)
    local indices = {}
    for index in pairs(objectives) do
        if type(index) == "number" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    return indices
end

local function _AddPlayer(name, status)
    tooltip:AddLine(" ")
    local player = QuestiePlayer:GetPartyMemberByName(name)
    local text = player and ("|c" .. player.colorHex .. name .. "|r") or name
    if status == -1 or status == "F" then
        text = text .. " |cFFFF4444(" .. l10n("Failed") .. ")|r"
    elseif status == 1 or status == "C" then
        text = text .. " |cFF28FF28" .. l10n("Quest Complete!") .. "|r"
    end
    tooltip:AddLine(text, 1, 1, 1)
end

local function _AddObjective(text, collected, needed, finished)
    local counted = type(collected) == "number" and type(needed) == "number" and needed > 0
    local color = QuestieLib:GetRGBForObjective(counted and {Collected = collected, Needed = needed} or {})
    if counted then
        text = tostring(collected) .. "/" .. tostring(needed) .. " " .. text
    end
    if finished then text = text .. " |cFF28FF28(" .. l10n("Complete") .. ")|r" end
    tooltip:AddLine("  " .. color .. text .. "|r", 1, 1, 1, true)
end

local function _AddShareHint(quest)
    local bind = Questie.db.profile.trackerbindShareQuest
    if not bind or bind == "disabled"
        or (not quest.NativeOnly and bind == Questie.db.profile.trackerbindSetTomTom) then return end
    local modifier, button = bind:match("^(%a-)(left)$")
    if not button then modifier, button = bind:match("^(%a-)(right)$") end
    local modifiers = {shift = "Shift", ctrl = "Control", alt = "Alt"}
    if not button or (modifier ~= "" and not modifiers[modifier]) or not TrackerUtils.CanShareQuest(quest.Id) then return end
    local text = l10n(button == "left" and "Left Click" or "Right Click")
    if modifiers[modifier] then text = l10n(modifiers[modifier]) .. " + " .. text end
    tooltip:AddLine(" ")
    tooltip:AddLine("(" .. text .. l10n(": ") .. l10n("Share Quest") .. ")", 0.6, 0.6, 0.6)
end

local function _Refresh()
    local line = hoveredLine
    local quest = _CanShow() and _GetQuest(line)
    if not quest then
        TrackerQuestTooltip.Hide()
        return
    end
    local cached = QuestLogCache.questLog_DO_NOT_MODIFY[quest.Id]
    if not cached then
        -- Keep the hover timer so a temporarily unavailable snapshot can recover.
        tooltip:Hide()
        return
    end
    local titleLine = _GetTitleLine(line)
    tooltip:SetOwner(titleLine, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", titleLine, "TOPLEFT")
    tooltip:ClearLines()
    tooltip:AddLine(TrackerData.GetColoredQuestName(quest, Questie.db.profile.enableTooltipsQuestLevel, true), 1, 1, 1, true)
    _AddPlayer(UnitName("player"), quest:IsComplete())
    local objectives = cached.objectives or {}
    for _, index in ipairs(_SortedIndices(objectives)) do
        local objective = objectives[index]
        _AddObjective(objective.text or l10n("Unknown"), objective.numFulfilled, objective.numRequired, objective.finished)
    end

    -- Read the existing cache only: hovering never requests or broadcasts progress.
    local remote = QuestieComms:GetQuest(quest.Id) or {}
    local names = {}
    for name in pairs(remote) do
        local unit = QuestieCompat.GetGroupUnitByName(name)
        if unit and unit ~= "player" and UnitIsConnected(unit) then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local progress = remote[name]
        local indices = _SortedIndices(progress)
        local status
        for _, index in ipairs(indices) do
            status = progress[index].status or status
            if status == "F" then break end
        end
        _AddPlayer(name, status)
        for _, index in ipairs(indices) do
            local objective = progress[index]
            local localObjective = objectives[index]
            _AddObjective(localObjective and localObjective.text or l10n("Unknown"),
                objective.fulfilled, objective.required, objective.finished)
        end
    end
    _AddShareHint(quest)
    tooltip:Show()
    if not layoutInitialized then
        -- Settle wrapped-line height on the first display before the next hover refresh.
        tooltip:Show()
        layoutInitialized = true
    end
end

function TrackerQuestTooltip.Show(line)
    TrackerQuestTooltip.Hide()
    if not _CanShow() or not _GetQuest(line) then return end
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "QuestieTrackerQuestTooltip", UIParent, "GameTooltipTemplate")
    end
    hoveredLine = line
    _Refresh()
    if hoveredLine then refreshTicker = C_Timer.NewTicker(0.5, _Refresh) end
end
