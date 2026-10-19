---@class ItemRuntimeCorrections
local ItemRuntimeCorrections = QuestieLoader:CreateModule("ItemRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local function classicFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [3713] = { -- Soothing Spices
            [itemKeys.relatedQuests] = {7321, 1218},
            [itemKeys.npcDrops] = {2397, 8307},
            [itemKeys.objectDrops] = {},
        },
        [15882] = { -- Half Pendant of Aquatic Endurance
            [itemKeys.objectDrops] = {177790},
        },
        [15883] = { -- Half Pendant of Aquatic Agility
            [itemKeys.objectDrops] = {177794},
        },
        [20810] = { -- Signed Field Duty Papers
            [itemKeys.npcDrops] = {15612},
        },
    }

    local itemFixesAlliance = {
        [3713] = { -- Soothing Spices
            [itemKeys.name] = "Soothing Spices",
            [itemKeys.relatedQuests] = {555, 1218},
            [itemKeys.npcDrops] = {2381, 4897},
            [itemKeys.objectDrops] = {},
        },
        [15882] = { -- Half Pendant of Aquatic Endurance
            [itemKeys.objectDrops] = {177844},
        },
        [15883] = { -- Half Pendant of Aquatic Agility
            [itemKeys.objectDrops] = {177792},
        },
        [20810] = { -- Signed Field Duty Papers
            [itemKeys.npcDrops] = {15440},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end

local function tbcFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [25911] = { -- Salvaged Wood
            [itemKeys.objectDrops] = {182936},
        },
        [25912] = { -- Salvaged Metal
            [itemKeys.objectDrops] = {182937, 182938},
        },
        [30712] = { -- The Doctor's Key
            [itemKeys.npcDrops] = {21779},
        },
        [30713] = { -- The Art of Fel Reaver Maintenance
            [itemKeys.objectDrops] = {185233},
        },
    }

    local itemFixesAlliance = {
        [25911] = { -- Salvaged Wood
            [itemKeys.objectDrops] = {182799},
        },
        [25912] = { -- Salvaged Metal
            [itemKeys.objectDrops] = {182798, 182797},
        },
        [30712] = { -- The Doctor's Key
            [itemKeys.npcDrops] = {21778},
        },
        [30713] = { -- The Art of Fel Reaver Maintenance
            [itemKeys.objectDrops] = {184947},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end

local function wotlkFactionFixes()
    local itemKeys = QuestieDB.itemKeys

    local itemFixesHorde = {
        [49698] = {
            [itemKeys.npcDrops] = {36669},
        },
    }

    local itemFixesAlliance = {
        [49698] = {
            [itemKeys.npcDrops] = {36670},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return itemFixesHorde
    else
        return itemFixesAlliance
    end
end

function ItemRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    addOverride(overrides, classicFactionFixes())
    addOverride(overrides, tbcFactionFixes())
    addOverride(overrides, wotlkFactionFixes())
end
