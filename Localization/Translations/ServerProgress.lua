---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-- English fallback strings; zone names use Questie's existing localized lookup.
local strings = {
    "World Progress", "Staging Area", "Sanctum", "Armory", "Harbor",
    "Sun's Reach: Phase %s (%s)",
    "Sanctum reclamation: %s%%", "Armory reclamation: %s%%", "Harbor reclamation: %s%%",
    "Portal construction: %s%%", "Anvil construction: %s%%",
    "Alchemy Lab construction: %s%%", "Monument construction: %s%%",
    "Scourge Invasion: Active", "Scourge Invasion: Inactive", "Battles won: %s",
    "%s: Necropolises remaining: %s", "%s: Under attack", "No active necropolis invasions reported.",
}
for _, text in ipairs(strings) do
    local translations = l10n.translations[text] or {}
    for _, locale in ipairs({"enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"}) do
        if translations[locale] == nil then translations[locale] = true end
    end
    l10n.translations[text] = translations
end
