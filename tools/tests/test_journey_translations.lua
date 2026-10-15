-- Run from the addon root with Lua 5.1 or 5.2+.
-- Check the translation keys used by Journey and its shared detail helpers.
local env = setmetatable({}, {__index = _G})
env._G, env.unpack = env, unpack or table.unpack
local modules, warnings = {}, {}
local function module(name)
    if not modules[name] then modules[name] = {private = {}} end
    return modules[name]
end
env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
    ImportModule = function(_, name) return module(name) end}
env.Questie = {db = {profile = {debugEnabled = true}}, Debug = function(_, message)
    warnings[#warnings + 1] = message
end}
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end
local function compile(source, name)
    if setfenv then return setfenv(assert(loadstring(source, name)), env) end
    return assert(load(source, name, "t", env))
end
compile(read("Localization/l10n.lua"), "@Localization/l10n.lua")()
for path in read("Localization/Translations/Translations.xml"):gmatch('file="([^"]+%.lua)"') do
    path = "Localization/Translations/" .. path:gsub("\\", "/")
    compile(read(path), "@" .. path)()
end
local l10n, keys, missing = module("l10n"), {}, {}
local function check(key, path)
    -- The inherited scenario branch is unreachable: 3.3.5 has no SCENARIOS category.
    if key == "Select Scenario" then return end
    keys[key] = true
    if not l10n.translations[key] or not l10n.translations[key].enUS then
        missing[key] = path
    end
end
local paths = {}
for path in read("Questie-335.toc"):gmatch("[^\r\n]+") do
    path = path:gsub("\\", "/")
    if path:match("^Modules/Journey/.*%.lua$") or path == "Database/QuestieDB.lua"
        or path == "Modules/Libs/QuestieLib.lua" or path == "Modules/Tooltips/TooltipHandler.lua" then
        paths[#paths + 1] = path
    end
end
assert(#paths > 10, "TOC should include Journey and its shared helpers")
for _, path in ipairs(paths) do
    local source, position = read(path), 1
    while true do
        local _, first = source:find("l10n%s*%(%s*['\"]", position)
        if not first then break end
        local quote, last = source:sub(first, first), first + 1
        while last <= #source do
            local char = source:sub(last, last)
            if char == "\\" then last = last + 2
            elseif char == quote then break
            else last = last + 1 end
        end
        if source:sub(last + 1):match("^%s*[,%)]") then
            check(compile("return " .. source:sub(first, last), "=translation key")(), path)
        end
        position = last + 1
    end
end
-- These keys are selected dynamically by quest race/faction requirements.
for _, key in ipairs({"Required Race", "Required Faction", "Race requirement", "Faction requirement"}) do
    check(key, "dynamic requirement label")
end
local failures = {}
for key, path in pairs(missing) do failures[#failures + 1] = string.format("%q (%s)", key, path) end
table.sort(failures)
assert(#failures == 0, "Missing translation keys:\n" .. table.concat(failures, "\n"))
l10n:SetUILocale("enUS")
for key in pairs(keys) do l10n(key, 1, 1, 1, 1, 1) end
for _, locale in ipairs({"enUS", "deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}) do
    l10n:SetUILocale(locale)
    for _, key in ipairs({": ", "NPC ID", "Item ID", "Object ID", "Night Elf", "Level too low",
        "Player is on quest", "Requires all of these quests to be finished",
        "Requires one of these quests to be finished"}) do
        l10n(key)
    end
end
assert(#warnings == 0, table.concat(warnings, "\n"))
local count = 0
for _ in pairs(keys) do count = count + 1 end
print("PASS: " .. count .. " Journey/shared translation keys resolve with elevated debug enabled")
