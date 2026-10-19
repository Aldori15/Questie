---@class ItemRuntimeCorrections
local ItemRuntimeCorrections = QuestieLoader:CreateModule("ItemRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

-- NPC acquisition guides for quest/script interactions, not ordinary loot drops.
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
    if type(QuestieDB.itemFactionSelections) ~= "table" then
        error("Missing generated item faction selections; regenerate acoreItemDB.lua", 0)
    end
    addOverride(overrides, QuestieDB.itemFactionSelections)
end
