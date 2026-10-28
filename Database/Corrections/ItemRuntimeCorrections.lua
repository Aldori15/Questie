---@class ItemRuntimeCorrections
local ItemRuntimeCorrections = QuestieLoader:CreateModule("ItemRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

-- Item acquisition sources for faction quest and script interactions.
local function factionFixes()
    local itemKeys = QuestieDB.itemKeys

    if UnitFactionGroup("player") == "Horde" then
        return {
            [20810] = { -- Signed Field Duty Papers
                [itemKeys.npcDrops] = {15612},
            },
            [49698] = { -- Ancient Dragonforged Blades
                [itemKeys.npcDrops] = {36669},
            },
        }
    end

    return {
        [20810] = { -- Signed Field Duty Papers
            [itemKeys.npcDrops] = {15440},
        },
        [49698] = { -- Ancient Dragonforged Blades
            [itemKeys.npcDrops] = {36670},
        },
    }
end

function ItemRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    addOverride(overrides, factionFixes())

    local factionSelections = QuestieDB.itemFactionSelections
    if type(factionSelections) ~= "table" then
        error("Missing generated item faction selections; regenerate acoreItemDB.lua", 0)
    end

    addOverride(overrides, factionSelections)
end
