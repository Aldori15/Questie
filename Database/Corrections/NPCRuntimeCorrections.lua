---@class NPCRuntimeCorrections
local NPCRuntimeCorrections = QuestieLoader:CreateModule("NPCRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Manual map guides and preferred zones for scripted encounters.
local function factionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    if UnitFactionGroup("player") == "Horde" then
        return {
            [5676] = { -- Summoned Voidwalker
                [npcKeys.spawns] = {
                    [zoneIDs.UNDERCITY] = {{86.65,27.08}},
                    [zoneIDs.ORGRIMMAR] = {{49.34,50.0}},
                    [zoneIDs.GHOSTLANDS] = {{27.0,15.24}},
                },
                [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
            },
            [5677] = { -- Summoned Succubus
                [npcKeys.spawns] = {
                    [zoneIDs.UNDERCITY] = {{86.65,27.08}},
                    [zoneIDs.ORGRIMMAR] = {{49.34,50.0}},
                },
                [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
            },
            [6492] = { -- Rift Spawn
                [npcKeys.zoneID] = zoneIDs.UNDERCITY,
            },
            [12138] = { -- Lunaclaw
                [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.95,60.88}}},
                [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
            },
            [12144] = { -- Lunaclaw Spirit
                [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.95,60.88}}},
                [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
            },
            [13778] = { -- PvP Tower Credit Marker
                [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{52.46,43.82},{50.54,31.23},{45.41,14.56},{43.89,18.82}}},
                [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
            },
        }
    end

    return {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [6492] = { -- Rift Spawn
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [12138] = { -- Lunaclaw
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{42.72,45.21}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [12144] = { -- Lunaclaw Spirit
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{42.72,45.21}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [13778] = { -- PvP Tower Credit Marker
            [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{48.24,58.67},{50.62,65.64},{49.52,84.54},{48.33,84.35}}},
            [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
        },
    }
end

function NPCRuntimeCorrections:LoadDarkmoonFixes(eventLocation)
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs
    local activeZone = zoneIDs.ELWYNN_FOREST
    local darkmoonSpawns = {
        [10445] = {[zoneIDs.ELWYNN_FOREST] = {{41.72,69.22}}},
        [14828] = {[zoneIDs.ELWYNN_FOREST] = {{41.5,68.87}}},
        [14829] = {[zoneIDs.ELWYNN_FOREST] = {{40.17,69.53}}},
        [14832] = {[zoneIDs.ELWYNN_FOREST] = {{40.49,69.93}}},
        [14833] = {[zoneIDs.ELWYNN_FOREST] = {{43.61,70.84}}},
        [14841] = {[zoneIDs.ELWYNN_FOREST] = {{41.71,70.72}}},
        [14844] = {[zoneIDs.ELWYNN_FOREST] = {{42.22,70.06}}},
        [14845] = {[zoneIDs.ELWYNN_FOREST] = {{42.16,70.2}}},
        [14846] = {[zoneIDs.ELWYNN_FOREST] = {{41.2,69.9}}},
        [14847] = {[zoneIDs.ELWYNN_FOREST] = {{41.25,70.05}}},
        [14849] = {[zoneIDs.ELWYNN_FOREST] = {{42.53,70.93},{40.37,69.66},{42.12,69.48},{42.21,69.02},{40.89,69.39},{42.28,68.82},{41.63,70.52},{42.12,69.35},{41.57,68.66},{41.46,68.72},{40.66,69.43}}},
        [14871] = {[zoneIDs.ELWYNN_FOREST] = {{43.34,70.28}}},
    }

    if eventLocation == 1 then
        activeZone = zoneIDs.MULGORE
        darkmoonSpawns = {
            [10445] = {[zoneIDs.MULGORE] = {{36.9,37.66}}},
            [14828] = {[zoneIDs.MULGORE] = {{37.31,37.73}}},
            [14829] = {[zoneIDs.MULGORE] = {{37.54,39.63}}},
            [14832] = {[zoneIDs.MULGORE] = {{37.87,39.83}}},
            [14833] = {[zoneIDs.MULGORE] = {{36.16,35.18}}},
            [14841] = {[zoneIDs.MULGORE] = {{37.12,37.31}}},
            [14844] = {[zoneIDs.MULGORE] = {{36.68,38.32}}},
            [14845] = {[zoneIDs.MULGORE] = {{36.6,38.3}}},
            [14846] = {[zoneIDs.MULGORE] = {{36.4,38.03}}},
            [14847] = {[zoneIDs.MULGORE] = {{36.43,38.13}}},
            [14849] = {[zoneIDs.MULGORE] = {{36.52,36.94},{37.68,38.45}}},
            [14871] = {[zoneIDs.MULGORE] = {{35.87,35.24}}},
        }
    elseif eventLocation == 3 then
        activeZone = zoneIDs.TEROKKAR_FOREST
        darkmoonSpawns = {
            [10445] = {[zoneIDs.TEROKKAR_FOREST] = {{34.57,34.74}}},
            [14828] = {[zoneIDs.TEROKKAR_FOREST] = {{34.68,34.36}}},
            [14829] = {[zoneIDs.TEROKKAR_FOREST] = {{34.33,35.73}}},
            [14832] = {[zoneIDs.TEROKKAR_FOREST] = {{34.84,35.15}}},
            [14833] = {[zoneIDs.TEROKKAR_FOREST] = {{33.82,35.96}}},
            [14841] = {[zoneIDs.TEROKKAR_FOREST] = {{34.04,34.82}}},
            [14844] = {[zoneIDs.TEROKKAR_FOREST] = {{34.79,35.4}}},
            [14845] = {[zoneIDs.TEROKKAR_FOREST] = {{34.73,35.46}}},
            [14846] = {[zoneIDs.TEROKKAR_FOREST] = {{34.32,34.36}}},
            [14847] = {[zoneIDs.TEROKKAR_FOREST] = {{34.27,34.41}}},
            [14849] = {[zoneIDs.TEROKKAR_FOREST] = {{34.47,35.13},{34.7,34.49},{34.04,34.73},{34.23,34.92},{34.58,34.95},{34.52,34.64},{34.68,35.37},{34.84,35.13},{34.44,34.26},{34.64,35.6}}},
            [14871] = {[zoneIDs.TEROKKAR_FOREST] = {{33.67,35.93}}},
        }
    end

    local npcFixes = {}

    for npcId, spawns in pairs(darkmoonSpawns) do
        npcFixes[npcId] = {
            [npcKeys.spawns] = spawns,
            [npcKeys.waypoints] = {},
            [npcKeys.zoneID] = activeZone,
        }
    end

    return npcFixes
end

function NPCRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    addOverride(overrides, factionFixes())
    local sources = QuestieDB.scriptedSpawnSources
    if not sources or type(sources[32823]) ~= "table" then
        error("Missing scripted spawn sources; regenerate acoreNpcDB.lua", 0)
    end
    -- Spell61849 awards credit34806 at Bountiful Tables; the credit bunny has
    -- no static spawns. Use current AC table placements instead of a second list.
    addOverride(overrides, {[34806] = {
        [QuestieDB.npcKeys.name] = "Spirit of Sharing",
        [QuestieDB.npcKeys.spawns] = sources[32823],
    }})
end
