---@class QuestieServerProgress
local Progress = QuestieLoader:CreateModule("QuestieServerProgress")
local Server = QuestieLoader:ImportModule("QuestieServer")
local Integrations = QuestieLoader:ImportModule("QuestieServerIntegrations")
local Blacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
local JourneyUtils = QuestieLoader:ImportModule("QuestieJourneyUtils")
local l10n = QuestieLoader:ImportModule("l10n")

-- AC WorldStateDefines.h / WorldState::FillInitialWorldStates. Project values
-- are percentages of unfinished construction, not character quest objectives.
local phases = {"Staging Area", "Sanctum", "Armory", "Harbor"}
local projects = {
    {3244, "Sanctum reclamation: %s%%"},
    {3233, "Armory reclamation: %s%%"},
    {3238, "Harbor reclamation: %s%%"},
    {3269, "Portal construction: %s%%"},
    {3228, "Anvil construction: %s%%"},
    {3223, "Alchemy Lab construction: %s%%"},
    {3275, "Monument construction: %s%%"},
}
-- Area ID, active-invasion indicator, remaining-necropolis count.
local invasionZones = {
    {16, 2260, 2279}, {4, 2261, 2280}, {46, 2262, 2281},
    {139, 2264, 2282}, {440, 2263, 2283}, {618, 2259, 2284},
}

local function NonnegativeInteger(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local function IsQuelDanasQuest(questId)
    return (Blacklist.SunsReachQuests or {})[questId] or (Integrations.quelDanasQuestEvents or {})[questId]
end

local function IsScourgeQuest(questId)
    return (Blacklist.ScourgeInvasionQuests or {})[questId]
end

---@param questId QuestId
---@return string[] lines Fresh world progress for related quests; empty when unavailable.
function Progress:GetQuestLines(questId)
    local lines = {}
    if IsQuelDanasQuest(questId) then
        local phase = Server:GetProgressValue(3426, "QUELDANAS")
        if phase ~= nil and phases[phase + 1] then
            lines[#lines + 1] = l10n("Sun's Reach: Phase %s (%s)", phase + 1, l10n(phases[phase + 1]))
            for _, project in ipairs(projects) do
                local percent = Server:GetProgressValue(project[1], "QUELDANAS")
                -- AC omits finished projects; omission is not evidence of 0% or 100%.
                if NonnegativeInteger(percent) and percent <= 100 then
                    lines[#lines + 1] = l10n(project[2], percent)
                end
            end
        end
    end
    if IsScourgeQuest(questId) then
        local active = Server:IsScourgeInvasionActive()
        if active ~= nil then
            lines[#lines + 1] = l10n(active and "Scourge Invasion: Active" or "Scourge Invasion: Inactive")
            if active then
                local victories = Server:GetProgressValue(2219, "SCOURGE")
                if NonnegativeInteger(victories) then
                    lines[#lines + 1] = l10n("Battles won: %s", victories)
                end
                local activeZones, knownZones = 0, 0
                for _, zone in ipairs(invasionZones) do
                    local indicator = Server:GetProgressValue(zone[2], "SCOURGE")
                    if indicator == 0 or indicator == 1 then knownZones = knownZones + 1 end
                    if indicator == 1 then
                        activeZones = activeZones + 1
                        local name = JourneyUtils:GetZoneName(zone[1])
                        local remaining = Server:GetProgressValue(zone[3], "SCOURGE")
                        if NonnegativeInteger(remaining) then
                            lines[#lines + 1] = l10n("%s: Necropolises remaining: %s", name, remaining)
                        else
                            lines[#lines + 1] = l10n("%s: Under attack", name)
                        end
                    end
                end
                if activeZones == 0 and knownZones == #invasionZones then
                    lines[#lines + 1] = l10n("No active necropolis invasions reported.")
                end
            end
        end
    end
    return lines
end

function Progress:AddQuestTooltip(tooltip, questId)
    local lines = self:GetQuestLines(questId)
    if #lines == 0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(l10n("World Progress"), 1, 0.82, 0)
    for _, line in ipairs(lines) do tooltip:AddLine(line, 1, 1, 1, true) end
end

-- Poll only the displayed label, using the existing snapshot. No network queries
-- or quest availability recalculation are needed for progress-only changes.
function Progress:AddQuestDetails(container, questId)
    if not IsQuelDanasQuest(questId) and not IsScourgeQuest(questId) then return end
    local function GetText()
        local lines = self:GetQuestLines(questId)
        if #lines == 0 then return "" end
        return Questie:Colorize(l10n("World Progress"), "yellow") .. "\n" .. table.concat(lines, "\n")
    end
    local text = GetText()
    local label = LibStub("AceGUI-3.0"):Create("Label")
    local function SetText(value)
        label:SetFullWidth(value ~= "")
        label:SetText(value)
        -- A zero-width label does not create an extra row in AceGUI's Flow
        -- layout. Keep it alive to discover a connection while details stay open.
        if value == "" then
            label:SetWidth(0)
            label:SetHeight(0)
        end
    end
    SetText(text)
    container:AddChild(label)
    local elapsed = 0
    label.frame:SetScript("OnUpdate", function(_, seconds)
        elapsed = elapsed + seconds
        if elapsed < 1 then return end
        elapsed = 0
        local updated = GetText()
        if updated == text then return end
        text = updated
        SetText(text)
        container:DoLayout()
    end)
    label:SetCallback("OnRelease", function(widget) widget.frame:SetScript("OnUpdate", nil) end)
end
