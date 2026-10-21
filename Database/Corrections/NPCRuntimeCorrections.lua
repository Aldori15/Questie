---@class NPCRuntimeCorrections
local NPCRuntimeCorrections = QuestieLoader:CreateModule("NPCRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Faction and event selections use coordinates generated from AzerothCore.
local function factionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs
    local fixes = QuestieDB.npcFactionGeometry
    if type(fixes) ~= "table" then
        error("Missing runtime geometry sources; regenerate acoreNpcDB.lua", 0)
    end

    local result = {}
    for id, fields in pairs(fixes) do
        result[id] = {}
        for key, value in pairs(fields) do
            result[id][key] = value
        end
    end

    result[6492] = { -- Rift Spawn
        [npcKeys.zoneID] = UnitFactionGroup("player") == "Horde" and zoneIDs.UNDERCITY or zoneIDs.STORMWIND_CITY,
    }

    return result
end

function NPCRuntimeCorrections:LoadDarkmoonFixes(eventLocation)
    local sources = QuestieDB.darkmoonGeometry
    local location = eventLocation == 1 and 1 or eventLocation == 3 and 3 or 2

    if type(sources) ~= "table" or type(sources[location]) ~= "table" then
        error("Missing Darkmoon event sources; regenerate acoreNpcDB.lua", 0)
    end

    return sources[location]
end

function NPCRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    local npcKeys = QuestieDB.npcKeys

    addOverride(overrides, factionFixes())

    local sources = QuestieDB.scriptedSpawnSources
    if not sources or type(sources[32823]) ~= "table" then
        error("Missing scripted spawn sources; regenerate acoreNpcDB.lua", 0)
    end

    -- Spell 61849 grants Spirit of Sharing credit at Bountiful Table locations.
    addOverride(overrides, {
        [34806] = { -- Spirit of Sharing
            [npcKeys.name] = "Spirit of Sharing",
            [npcKeys.spawns] = sources[32823],
        },
    })
end
