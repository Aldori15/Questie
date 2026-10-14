---@class TrackerObjectiveText
local TrackerObjectiveText = QuestieLoader:CreateModule("TrackerObjectiveText")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

-- Preserve the tracker's existing gradient and rounding independently of the
-- objective palette selected through QuestieLib:GetRGBForObjective().
local function FloatRGBToHex(r, g, b)
    if r > 255 then r = 255 end
    if g > 255 then g = 255 end
    if b > 255 then b = 255 end
    return string.format("|cFF%02x%02x%02x", math.floor(r * 254), math.floor(g * 254), math.floor(b * 254))
end

local white = FloatRGBToHex(0.937, 0.937, 0.937)

local function GetPercentColorHex(float)
    if type(float) ~= "number" then
        return white
    end
    if float <= .50 then
        return FloatRGBToHex(1, 0 + float * 2, 0)
    else
        return FloatRGBToHex(1.843 - float / 0.593, 1, (float * 2 - 1) * 0.157)
    end
end

---@param coloredQuestName string
---@param completionPercent number|nil
---@return string
function TrackerObjectiveText.GetQuestTitleText(coloredQuestName, completionPercent)
    if Questie.db.profile.showQuestPercent and type(completionPercent) == "number" then
        local percent = math.floor(completionPercent * 100)
        return coloredQuestName .. " " .. GetPercentColorHex(completionPercent) .. "(" .. tostring(percent) .. "%)|r"
    end
    return coloredQuestName
end

-- Descriptions are prepared by the renderer (localization, trimming, and hints).
-- Read settings on each call so options/profile changes take effect immediately.
---@param objective QuestObjective
---@param description string
---@return string
function TrackerObjectiveText.GetQuestObjectiveText(objective, description)
    local profile = Questie.db.profile
    local colorObjective = objective
    if objective.NativeOnly and not objective.Completed and objective.Collected >= objective.Needed then
        colorObjective = {Collected = 0, Needed = 1}
    end
    if objective.NativeOnly and (not profile.trimObjectiveText or not objective.HasCounter) then
        local text = objective.NativeText
        if objective.HasCounter then
            text = text:gsub("%d+/%d+", tostring(objective.Collected) .. "/" .. tostring(objective.Needed), 1)
        end
        return QuestieLib:GetRGBForObjective(colorObjective) .. "- " .. text .. "|r"
    end
    local progress = tostring(objective.Collected) .. "/" .. tostring(objective.Needed)
    if profile.showQuestPercent and type(objective.Collected) == "number" and type(objective.Needed) == "number" and objective.Needed > 0 then
        local progressColor = GetPercentColorHex(objective.Collected / objective.Needed)
        if profile.showQuestProgressFirst then
            return white .. "- |r" .. progressColor .. progress .. "|r " .. white .. description .. "|r"
        end
        return white .. "- " .. description .. ": |r" .. progressColor .. progress .. "|r"
    end

    local color = QuestieLib:GetRGBForObjective(colorObjective)
    if profile.showQuestProgressFirst then
        return color .. "- " .. progress .. " " .. description .. "|r"
    end
    return color .. "- " .. description .. ": " .. progress .. "|r"
end

---@param description string
---@param completed boolean
---@return string
function TrackerObjectiveText.GetAchievementLabelText(description, completed)
    if Questie.db.profile.showQuestPercent then
        return white .. "- " .. description .. "|r"
    end
    -- Achievement labels historically inherit the color without a trailing reset.
    return QuestieLib:GetRGBForObjective({Collected = completed and 1 or 0, Needed = 1}) .. "- " .. description
end

---@param description string
---@param collected number
---@param needed number
---@param quantityString string
---@return string fullText
---@return string headingText
---@return string progressText
function TrackerObjectiveText.GetAchievementProgressText(description, collected, needed, quantityString)
    -- Preserve Blizzard's formatted money/time values, including texture escapes.
    if string.find(quantityString, "|") then
        quantityString = quantityString:gsub("/%s?", "/")
    else
        quantityString = collected .. "/" .. needed
    end
    local progress = tostring(quantityString)

    if Questie.db.profile.showQuestPercent then
        local progressColor = GetPercentColorHex(collected / (needed > 0 and needed or 1))
        local heading = white .. "- " .. description .. ": |r"
        local coloredProgress = progressColor .. progress .. "|r"
        return heading .. coloredProgress, heading, white .. "    > |r" .. coloredProgress
    end

    local color = QuestieLib:GetRGBForObjective({Collected = collected, Needed = needed})
    local heading = color .. "- " .. description .. ": "
    return heading .. progress, heading, color .. "    > " .. progress
end
