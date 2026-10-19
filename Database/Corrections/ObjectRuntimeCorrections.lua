---@class ObjectRuntimeCorrections
local ObjectRuntimeCorrections = QuestieLoader:CreateModule("ObjectRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Preferred zones and event guides. Lantern coordinates follow
-- npc_shade_of_the_horseman::GetPosToLand in AC hallows_end.cpp.
local function factionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    if UnitFactionGroup("player") == "Horde" then
        return {
            [103574] = { -- Filled Containment Coffer
                [objectKeys.zoneID] = zoneIDs.UNDERCITY,
            },
            [186887] = { -- Large Jack-o'-Lantern
                [objectKeys.spawns] = {
                    [zoneIDs.DUROTAR] = {{52.44,41.06}},
                    [zoneIDs.TIRISFAL_GLADES] = {{61.31,53.38}},
                    [zoneIDs.EVERSONG_WOODS] = {{47.64,45.95}},
                },
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
        [186887] = { -- Large Jack-o'-Lantern
            [objectKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.41,65.04}},
                [zoneIDs.DUN_MOROGH] = {{46.38,52.97}},
                [zoneIDs.AZUREMYST_ISLE] = {{49.36,51.73}},
            },
        },
    }
end

function ObjectRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    addOverride(overrides, factionFixes())
    local sources = QuestieDB.scriptedSpawnSources
    if not sources or type(sources[6492]) ~= "table" then
        error("Missing scripted spawn sources; regenerate acoreNpcDB.lua", 0)
    end
    -- Rift Spawn casts spell9010 on itself to create the coffer. Its map guide
    -- follows those source placements, including their phase/difficulty data.
    addOverride(overrides, {[103574] = {[QuestieDB.objectKeys.spawns] = sources[6492]}})
end
