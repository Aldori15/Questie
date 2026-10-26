-- Run from the addon root with Lua 5.1 or 5.2+.
-- Generated guide translations must survive compilation and cached startup.
local function loadInEnv(path, env)
    if setfenv then
        return setfenv(assert(loadfile(path)), env)()
    end
    return assert(loadfile(path, "t", env))()
end

local testBit = bit32 or bit or {
    band = function(a, b)
        local result, place = 0, 1
        for _ = 1, 32 do
            if a % 2 == 1 and b % 2 == 1 then result = result + place end
            a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
        end
        return result
    end,
    lshift = function(a, n) return (a * 2 ^ n) % 4294967296 end,
    rshift = function(a, n) return math.floor(a / 2 ^ n) end,
}

local hint = "Speak with Gryphoneer Windbellow"
local untranslated = "Source-only guide with 50% progress"
local locales = {"enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}
local function setup(locale)
    local modules, warnings = {}, {}
    local function module(name)
        if not modules[name] then modules[name] = {} end
        return modules[name]
    end
    local env = setmetatable({
        bit = testBit,
        tremove = table.remove,
        unpack = unpack or table.unpack,
        GetCVar = function() return "" end,
        GetLocale = function() return locale end,
        InCombatLockdown = function() return false end,
        Questie = {
            db = {profile = {debugEnabled = true}},
            Debug = function(_, message) warnings[#warnings + 1] = message end,
            Error = function(message) error(message) end,
        },
    }, {__index = _G})
    env._G = env
    env.QuestieLoader = {
        CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end,
    }
    local db = module("QuestieDB")
    db.itemData, db.npcData, db.objectData = {{"Raw item"}}, {{"Raw NPC"}}, {{"Raw object"}}
    db.itemKeys, db.objectKeys = {name = 1}, {name = 1}
    db.npcKeys = {name = 1, subName = 2}
    db.questKeys = {name = 1, objectivesText = 8, extraObjectives = 29}
    db.questData = {
        [1] = {"Raw quest"},
        [10382] = {[29] = {
            {nil, 3, hint, 0, {{"monster", 20235}}},
            {nil, 3, untranslated, 0, {{"monster", 20235}}},
        }},
        [10394] = {},
    }
    loadInEnv("Localization/l10n.lua", env)
    loadInEnv("Localization/Translations/ExtraObjectives.lua", env)
    local localeModule = module("l10n")
    localeModule.itemLookup[locale] = {[1] = "Localized item"}
    localeModule.npcNameLookup[locale] = {[1] = {"Localized NPC", "Localized title"}}
    localeModule.objectLookup[locale] = {[1] = "Localized object"}
    localeModule.questLookup[locale] = {[1] = {"Localized quest", nil, "Localized objective"}}
    localeModule.questLookupOverrides = {[1] = {"Override quest", nil, {"Override objective"}}}
    local count = 0
    for key, translations in pairs(localeModule.translations) do
        count = count + 1
        assert(translations.enUS == true, "English uses its literal translation key")
        for _, language in ipairs(locales) do
            if language ~= "enUS" then
                assert(type(translations[language]) == "string" and #translations[language] > 0,
                    key .. ": missing translation for " .. language)
            end
        end
    end
    assert(count > 0 and localeModule.translations[hint]
        and localeModule.translations["Speak with Wing Commander Brack"]
        and localeModule.translations["Speak with Ayren Cloudbreaker"], "flight translations are registered")
    local expected = locale == "enUS" and hint or localeModule.translations[hint][locale]
    localeModule:SetUILocale(locale)
    localeModule:CompactTranslations()
    return env, modules, warnings, expected
end

for _, locale in ipairs(locales) do
    local env, modules, warnings, expected = setup(locale)
    local db, l10n = modules.QuestieDB, modules.l10n
    l10n:Initialize()
    assert(db.itemData[1][1] == "Localized item" and db.npcData[1][1] == "Localized NPC"
        and db.npcData[1][2] == "Localized title" and db.objectData[1][1] == "Localized object",
        "materialized item, NPC and object records receive active-locale lookups")
    assert(db.questData[1][1] == "Override quest" and db.questData[1][8][1] == "Override objective",
        "materialized quest lookup and custom override precedence remain intact")
    local guides = db.questData[10382][29]
    assert(guides[1][3] == expected, locale .. ": generated flight hint uses the available translation")
    assert(guides[2][3] == untranslated, locale .. ": unknown descriptions remain unchanged, including percent signs")
    assert(guides[1][2] == 3 and guides[1][4] == 0 and guides[1][5][1][2] == 20235,
        "translation preserves icon, objective association and target identity")
    l10n:Initialize()
    assert(guides[1][3] == expected, "repeated locale initialization preserves the translated description")

    -- Exercise the real guide writer/reader, then remove raw data as on a reload.
    loadInEnv("Modules/QuestieStream.lua", env)
    loadInEnv("Database/compiler.lua", env)
    local compiler = modules.DBCompiler
    -- Lua pairs() may visit numeric keys in any order. Guide indices must stay
    -- aligned with generated optional metadata through compilation.
    env.pairs = function(value)
        if value == guides then
            local index = #guides + 1
            return function()
                index = index - 1
                if index > 0 then return index, guides[index] end
            end
        end
        return pairs(value)
    end
    local stream = modules.QuestieStreamLib:GetStream("raw")
    compiler.writers.extraobjectives(stream, guides)
    local binary = stream:Save()
    stream:finished()
    db.questData = nil
    l10n:Initialize()
    -- A real cached login retains unparsed source strings and a boolean chunk
    -- marker. Neither the marker nor the strings are materialized records.
    local chunk = 'error("cached localization must not execute source chunks")'
    for _, deferred in ipairs({{__questieSourceChunks = true, chunk}, chunk}) do
        db.itemData, db.questData, db.npcData, db.objectData = deferred, deferred, deferred, deferred
        l10n:Initialize()
        assert(db.itemData == deferred and db.questData == deferred
            and db.npcData == deferred and db.objectData == deferred, "cached source containers stay unchanged")
        if type(deferred) == "table" then
            assert(deferred.__questieSourceChunks == true and deferred[1] == chunk,
                "deferred chunk marker and source survive cached localization")
        end
    end
    db.itemData, db.questData, db.npcData, db.objectData = nil, nil, nil, nil
    l10n:Initialize()
    stream = modules.QuestieStreamLib:GetStream("raw")
    stream:Load(binary)
    local restored = compiler.readers.extraobjectives(stream)
    assert(#restored == 2 and restored[1][3] == expected,
        locale .. ": cached guide retains the translated description without raw quest data")
    assert(restored[2][3] == untranslated, "cached unknown description remains unchanged")
    assert(restored[1][5][1][1] == "monster" and restored[1][5][1][2] == 20235,
        "cached translated guide keeps its NPC target")
    assert(stream._pointer == #binary + 1, "guide reader consumes exactly the stored bytes")
    stream:finished()
    assert(#warnings == 0, locale .. ": absent keys and unavailable translations do not produce debug warnings")
end

print("Generated extra objective localization survives compilation and cached startup")
