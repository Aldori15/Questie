local QuestieOptionsSearch = QuestieLoader:CreateModule("QuestieOptionsSearch")
local utf8 = QuestieLoader:ImportModule("utf8")
local l10n = QuestieLoader:ImportModule("l10n")

local suppressed = {}

function QuestieOptionsSearch.Clear()
    for _, entry in ipairs(suppressed) do
        entry.option.dialogHidden = entry.dialogHidden
    end
    wipe(suppressed)
end

local function Normalize(text)
    return utf8.lower(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " "))
end

local function Matches(text, words)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

local function GetText(value, info)
    if type(value) == "function" then value = value(info) end
    return type(value) == "string" and Normalize(value) or ""
end

local function IsHidden(option, hidden, info)
    if option.dialogHidden ~= nil then return option.dialogHidden end
    if option.guiHidden ~= nil then return option.guiHidden end
    if type(hidden) == "function" then return hidden(info) end
    if type(hidden) == "string" then return info.handler[hidden](info.handler, info) end
    return hidden
end

local function FilterOption(option, info, context, inheritedHidden, words, visibility)
    info.arg, info.option, info.type = option.arg, option, option.type
    local handler = info.handler
    info.handler = option.handler or handler
    local hidden = option.hidden
    if hidden == nil then hidden = inheritedHidden end
    if IsHidden(option, hidden, info) then
        info.handler = handler
        return false
    end

    local text = context .. " " .. GetText(option.name, info) .. " "
        .. GetText(option.desc, info) .. " " .. GetText(option.usage, info)
    local matches = false
    if option.type == "group" then
        local function Visit(children)
            for key, child in pairs(children) do
                info[#info + 1] = key
                local childMatches = FilterOption(child, info, text, hidden, words, visibility)
                info[#info] = nil
                visibility[child] = childMatches
                matches = matches or childMatches
            end
        end
        Visit(option.args or {})
        for _, children in pairs(option.plugins or {}) do Visit(children) end
    elseif option.type ~= "header" and option.type ~= "description" then
        matches = Matches(text, words)
    elseif option.dialogControl == "InteractiveLabel" then
        -- The two checkboxes in the quest icon grid have empty names.
        matches = Matches(text .. " " .. Normalize(l10n("World Map")) .. " " .. Normalize(l10n("Minimap")), words)
    end
    info.handler = handler
    return matches
end

local function KeepIconGridRows(args, visibility)
    if not args or not args.mapHeader or not args.minimapHeader or not args.iconNameHeader then return end
    local matchingRow = false
    for key, label in pairs(args) do
        local prefix = key:match("^(.-)Label$")
        local worldMap = prefix and args[prefix .. "Map"]
        local minimap = prefix and args[prefix .. "Minimap"]
        if worldMap and minimap and (visibility[label] or visibility[worldMap] or visibility[minimap]) then
            visibility[label], visibility[worldMap], visibility[minimap] = true, true, true
            if args[prefix .. "MinimapRowBreak"] then visibility[args[prefix .. "MinimapRowBreak"]] = true end
            matchingRow = true
        end
    end
    if matchingRow then
        for _, key in ipairs({"quest_options", "iconNameHeader", "mapHeader", "minimapHeader", "surfaceHeaderRowBreak"}) do
            if args[key] then visibility[args[key]] = true end
        end
    end
    if args.worldstate_options and (visibility[args.showScourgeInvasionQuests] or visibility[args.showSunsReachQuests]) then
        visibility[args.worldstate_options] = true
    end
end

-- Apply visibility only to the popup's private AceConfig schema.
function QuestieOptionsSearch.Filter(options, appName, query)
    QuestieOptionsSearch.Clear()
    local words = {}
    for word in Normalize(query):gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return nil end

    local matchingTabs, visibility = {}, {}
    for key, option in pairs(options.args) do
        local info = {key, [0] = appName, appName = appName, options = options,
            uiType = "dialog", uiName = "AceConfigDialog-3.0", handler = options.handler}
        matchingTabs[key] = FilterOption(option, info, "", options.hidden, words, visibility)
        local grid = option.args and option.args.quest_icon_toggles_group
        if grid and visibility[grid] then KeepIconGridRows(grid.args, visibility) end
    end
    for option, visible in pairs(visibility) do
        if not visible then
            suppressed[#suppressed + 1] = {option = option, dialogHidden = option.dialogHidden}
            option.dialogHidden = true
        end
    end
    return matchingTabs
end
