---@class QuestieIconVisibility
local QuestieIconVisibility = QuestieLoader:CreateModule("QuestieIconVisibility")

local CATEGORY_CONFIG = {
    available = {
        legacy = "enableAvailable",
        map = "enableAvailableMapIcons",
        minimap = "enableAvailableMinimapIcons",
        default = true,
    },
    event = {
        legacy = "showEventQuests",
        map = "showEventQuestMapIcons",
        minimap = "showEventQuestMinimapIcons",
        default = true,
    },
    repeatable = {
        legacy = "showRepeatableQuests",
        map = "showRepeatableQuestMapIcons",
        minimap = "showRepeatableQuestMinimapIcons",
        default = true,
    },
    trivialRepeatable = {
        legacy = "showTrivialRepeatableQuests",
        map = "showTrivialRepeatableQuestMapIcons",
        minimap = "showTrivialRepeatableQuestMinimapIcons",
        default = true,
    },
    pvp = {
        legacy = "showPvPQuests",
        map = "showPvPQuestMapIcons",
        minimap = "showPvPQuestMinimapIcons",
        default = true,
    },
    dungeon = {
        legacy = "showDungeonQuests",
        map = "showDungeonQuestMapIcons",
        minimap = "showDungeonQuestMinimapIcons",
        default = true,
    },
    raid = {
        legacy = "showRaidQuests",
        map = "showRaidQuestMapIcons",
        minimap = "showRaidQuestMinimapIcons",
        default = true,
    },
    turnin = {
        legacy = "enableTurnins",
        map = "enableTurninMapIcons",
        minimap = "enableTurninMinimapIcons",
        default = true,
    },
    objective = {
        legacy = "enableObjectives",
        map = "enableObjectiveMapIcons",
        minimap = "enableObjectiveMinimapIcons",
        default = true,
    },
    itemStart = {
        legacy = "showItemStartQuests",
        map = "showItemStartQuestMapIcons",
        minimap = "showItemStartQuestMinimapIcons",
        default = false,
    },
}

QuestieIconVisibility.CATEGORY_CONFIG = CATEGORY_CONFIG

local function _GetProfileValue(profile, key, legacyKey, defaultValue)
    local value = profile[key]
    if value == nil then
        value = profile[legacyKey]
    end
    if value == nil then
        value = defaultValue
    end

    return value ~= false
end

function QuestieIconVisibility:GetKey(category, isMinimap)
    local config = CATEGORY_CONFIG[category]
    if not config then
        return nil
    end

    return isMinimap and config.minimap or config.map
end

function QuestieIconVisibility:IsEnabled(category, isMinimap)
    local config = CATEGORY_CONFIG[category]
    if not config then
        return true
    end

    local profile = Questie.db.profile
    return _GetProfileValue(profile, self:GetKey(category, isMinimap), config.legacy, config.default)
end

function QuestieIconVisibility:IsEnabledAnywhere(category)
    return self:IsEnabled(category, false) or self:IsEnabled(category, true)
end

function QuestieIconVisibility:SetEnabled(category, isMinimap, value)
    local key = self:GetKey(category, isMinimap)
    if key then
        Questie.db.profile[key] = value
        Questie.db.profile[CATEGORY_CONFIG[category].legacy] = self:IsEnabledAnywhere(category)
    end
end

function QuestieIconVisibility:SetBoth(category, value)
    local config = CATEGORY_CONFIG[category]
    if not config then
        return
    end

    Questie.db.profile[config.map] = value
    Questie.db.profile[config.minimap] = value
    Questie.db.profile[config.legacy] = value
end

function QuestieIconVisibility:MigrateProfile(profile)
    for _, config in pairs(CATEGORY_CONFIG) do
        local legacyValue = profile[config.legacy]
        if legacyValue == nil then
            legacyValue = config.default
        end

        if profile[config.map] == nil then
            profile[config.map] = legacyValue
        end

        if profile[config.minimap] == nil then
            profile[config.minimap] = legacyValue
        end
    end
end
