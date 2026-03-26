---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-- Add custom quest localizations here for quest IDs that do not exist in the
-- generated lookup tables, such as AzerothCore-only quests. English clients
-- usually do not need entries here because the base quest DB already carries
-- English quest text.
--
-- Format:
-- [questId] = {"Localized quest name", nil, {"Localized objective text line 1", "Line 2"}},
local questLookupOverridesByLocale = {
    enUS = {},
    deDE = {},
    esES = {},
    esMX = {},
    frFR = {},
    koKR = {},
    ptBR = {},
    ruRU = {},
    zhCN = {},
    zhTW = {},
}

function l10n.questLookupOverrides()
    return questLookupOverridesByLocale[l10n:GetUILocale()] or {}
end
