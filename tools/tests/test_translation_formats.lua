-- Run from the addon root with Lua 5.1 or 5.2+.
-- Issue #180: validate every UI locale, regardless of the client language.
local env = setmetatable({}, {__index = _G})
env._G, env.unpack = env, unpack or table.unpack
local modules = {}
local function module(name)
    modules[name] = modules[name] or {}
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
env.Questie = {db = {profile = {debugEnabled = false}}}

local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local function load(path)
    if setfenv then return setfenv(assert(loadstring(read(path), "@" .. path)), env)() end
    return assert(_G.load(read(path), "@" .. path, "t", env))()
end
load("Localization/l10n.lua")
local l10n, owners, entries = module("l10n"), {}, {}
for path in read("Localization/Translations/Translations.xml"):gmatch('file="([^"]+%.lua)"') do
    path = "Localization/Translations/" .. path:gsub("\\", "/")
    load(path)
    for key, entry in pairs(l10n.translations) do
        if entries[key] ~= entry then owners[key], entries[key] = path, entry end
    end
end

-- %% consumes no argument, including deliberately deferred placeholders like %%s.
-- Parse first: surplus format arguments would otherwise hide missing placeholders.
local function signature(value)
    local specifiers, position = {}, 1
    while true do
        local first = value:find("%", position, true)
        if not first then return specifiers end
        if value:sub(first + 1, first + 1) == "%" then
            position = first + 2
        else
            local conversion = value:match("^%%[-+ #0]*%d*%.?%d*()[cdiouxXeEfgGqs]", first)
            if not conversion then return nil, "invalid or unescaped percent at byte " .. first end
            specifiers[#specifiers + 1] = value:sub(conversion, conversion)
            position = conversion + 1
        end
    end
end

local locales = {"enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}
local failures, keyCount, translationCount = {}, 0, 0
local function fail(locale, key, reason)
    failures[#failures + 1] = string.format("%s [%s] %q: %s", owners[key], locale, key, reason)
end
for key, entry in pairs(l10n.translations) do
    keyCount = keyCount + 1
    local expected, reason = signature(key)
    if not expected then
        fail("enUS", key, reason)
    else
        local args = {}
        for i, conversion in ipairs(expected) do
            args[i] = (conversion == "s" or conversion == "q") and ("sample" .. i) or "17"
        end
        for _, locale in ipairs(locales) do
            local value = entry[locale]
            if type(value) == "string" then
                translationCount = translationCount + 1
                local actual, errorText = signature(value)
                if not actual then
                    fail(locale, key, errorText)
                elseif table.concat(actual) ~= table.concat(expected) then
                    fail(locale, key, "format arguments differ from the English key")
                end
            end
            -- Use the real translator too, including true/false/missing fallbacks.
            l10n:SetUILocale(locale)
            local ok, errorText = pcall(l10n, key, env.unpack(args))
            if not ok then fail(locale, key, errorText) end
        end
    end
end
assert(keyCount > 0 and translationCount > 0, "No UI translations were loaded")
table.sort(failures)
assert(#failures == 0, "Translation format errors:\n" .. table.concat(failures, "\n"))
print("PASS: " .. keyCount .. " keys and " .. translationCount .. " translations format correctly in all "
    .. #locales .. " UI locales")
