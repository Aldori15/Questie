---@class Moonwell
local Moonwell = QuestieLoader:CreateModule("Moonwell")

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")

---@type table<number, boolean>
Moonwell.objectIds = {
    -- Teldrassil Moonwells
    [19549] = true, -- Shadowglen moonwell
    [19550] = true, -- Starbreeze Village moonwell
    [19551] = true, -- Pools of Arlithrien moonwell
    [19552] = true, -- Oracle Glade moonwell
    -- Ashenvale Moonwells
    [20806] = true, -- Central Ashenvale moonwell
    -- Felwood Moonwells
    [148501] = true, -- Felwood cave moonwell
    -- Darkshore Moonwells
    [174795] = true, -- Auberdine (Main moonwell)
    [175337] = true, -- Auberdine (Secondary moonwell)
    -- Shared Moonwells (multiple zones and expansions)
    [177232] = true,
    [177272] = true,
    [177273] = true,
    [177274] = true,
    [177275] = true,
    [177276] = true,
    [177277] = true,
    [177278] = true,
    [177279] = true,
    [177280] = true,
    [177281] = true,
}

function Moonwell:ShowMoonwell(objectID, icon, scale)
    icon = icon or "Interface\\Icons\\inv_fabric_moonrag_01.blp"
    scale = scale or 0.6
    local title = Questie:Colorize(l10n("Moonwell"), "white")
    QuestieMap:ShowObject(objectID, icon, scale, title, nil, true, "moonwell")
end

function Moonwell:ShowAll()
    for objectID in pairs(Moonwell.objectIds) do
        Moonwell:ShowMoonwell(objectID)
    end
end

function Moonwell:HideAll()
    for objectID in pairs(Moonwell.objectIds) do
        QuestieMap:UnloadManualFrames(objectID, "moonwell")
    end
end
