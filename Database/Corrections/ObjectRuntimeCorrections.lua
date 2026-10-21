---@class ObjectRuntimeCorrections
local ObjectRuntimeCorrections = QuestieLoader:CreateModule("ObjectRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Preferred display zones; spawn selections come from the generated bases.
local function factionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    if UnitFactionGroup("player") == "Horde" then
        return {
            [103574] = { -- Filled Containment Coffer
                [objectKeys.zoneID] = zoneIDs.UNDERCITY,
            },
        }
    end

    return {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [177525] = { -- Moonkin Stone
            [objectKeys.zoneID] = zoneIDs.DARKSHORE,
        },
    }
end

function ObjectRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    local objectKeys = QuestieDB.objectKeys

    addOverride(overrides, factionFixes())

    local factionGeometry = QuestieDB.objectFactionGeometry
    if type(factionGeometry) ~= "table" then
        error("Missing runtime geometry sources; regenerate acoreObjectDB.lua", 0)
    end

    -- The Lantern uses GetPosToLand's fixed coordinates, not the corpse position.
    addOverride(overrides, factionGeometry)

    local sources = QuestieDB.scriptedSpawnSources
    if not sources or type(sources[6492]) ~= "table" then
        error("Missing scripted spawn sources; regenerate acoreNpcDB.lua", 0)
    end

    -- Spell 9010 creates the coffer at Rift Spawn's source locations.
    addOverride(overrides, {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = sources[6492],
        },
    })
end
