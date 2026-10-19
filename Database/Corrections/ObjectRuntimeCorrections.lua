---@class ObjectRuntimeCorrections
local ObjectRuntimeCorrections = QuestieLoader:CreateModule("ObjectRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local function classicFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{53.29,74.56},{53.67,76.81},{52.01,75.96},{53.2,71.44}}},
            [objectKeys.zoneID] = zoneIDs.UNDERCITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{85.67,9.91},{85.53,10.03},{85.48,9.9},{85.58,9.95}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.UNDERCITY] = {{85.78,10.05},{85.7,10.11},{85.65,10.18}}},
        },
        [177525] = { -- Moonkin Stone
            [objectKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.81}}},
            [objectKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [180743] = {
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.39,69.52}}},
        },
        [180746] = {
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.33,69.42}}},
        },
        [180747] = {
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.3,69.18}}},
        },
        [180748] = {
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.28,69.29}}},
        },
        [180793] = {
            [objectKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{52.42,69.32}}},
        },
    }

    local objectFixesAlliance = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{40.87,89.04},{40.75,92.13},{41.27,90.54},{40.26,88.13},{40.89,87.75},{40.47,91.94}}},
            [objectKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{38.48,78.89},{38.55,79.04},{38.54,78.97},{38.62,79.02}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{38.68,78.73},{38.69,78.81},{38.73,78.84}}},
        },
        [177525] = { -- Moonkin Stone
            [objectKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.5,45.97}}},
            [objectKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [180743] = {
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.86,65.69}}},
        },
        [180746] = {
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.46,65.57}}},
        },
        [180747] = {
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.78,66.4}}},
        },
        [180748] = {
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.9,66.68}}},
        },
        [180793] = {
            [objectKeys.spawns] = {[zoneIDs.IRONFORGE] = {{33.96,65.86}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end

local function tbcFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [186887] = {
            [objectKeys.spawns] = {
                [zoneIDs.DUROTAR] = {{52.6,42.5}},
                [zoneIDs.TIRISFAL_GLADES] = {{60.9,52.7}},
                [zoneIDs.EVERSONG_WOODS] = {{47.58,46.24}},
            },
        },
        [187236] = {
            [objectKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{52.43,69.27}},
            },
        },
    }

    local objectFixesAlliance = {
        [186887] = {
            [objectKeys.spawns] = {
                [zoneIDs.ELWYNN_FOREST] = {{42.5,65.8}},
                [zoneIDs.DUN_MOROGH] = {{46.4,52.2}},
                [zoneIDs.AZUREMYST_ISLE] = {{48.99,51.02}},
            },
        },
        [187236] = {
            [objectKeys.spawns] = {
                [zoneIDs.IRONFORGE] = {{33.71,65.85}},
            },
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end

local function wotlkFactionFixes()
    local objectKeys = QuestieDB.objectKeys
    local zoneIDs = ZoneDB.zoneIDs

    local objectFixesHorde = {
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUROTAR] = {{45.27,13.53},{45.27,13.54},{45.28,13.55},{45.26,13.53},{45.08,16.66},{45.08,16.68},{45.1,16.68},{45.1,16.65},{45.27,13.53},{45.28,17.47},{45.28,17.45},{44.86,17.42},{44.87,17.41},{45.16,17.52},{45.19,17.51},{45.17,17.49},{45.18,17.48},{45.26,17.46},{45.27,17.48},{44.85,17.4},{44.87,17.43},{44.53,16.53},{44.52,16.56},{44.51,16.53},{44.53,16.56},{43.97,17.98},{44.22,18.01},{43.96,17.98},{44.21,17.99},{43.61,17.3},{43.62,17.32},{43.61,17.28},{43.96,17.94},{43.63,17.3},{44.19,18.01},{44.2,18.0},{43.98,17.95},{43.86,16.83},{43.84,16.84},{43.85,16.8},{43.83,16.82},{43.63,17.3}}},
        },
        [201873] = {
            [objectKeys.spawns] = {[zoneIDs.ICECROWN_CITADEL_RAMPART_OF_SKULLS] = {{47.9,77.3}},[zoneIDs.ICECROWN_CITADEL] = {{-1,-1}}},
        },
    }

    local objectFixesAlliance = {
        [103574] = { -- Filled Containment Coffer
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{51.32,92.34},{50.83,92.63},{51.61,94.5},{51.21,95.73},{50.99,95.58},{51.3,93.34}}},
            [objectKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [105174] = { -- Chest of Containment Coffers
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{49.45,85.48},{49.51,85.6},{49.5,85.55},{49.56,85.58}}},
        },
        [105175] = { -- Cantation of Manifestation
            [objectKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{49.64,85.44},{49.6,85.36},{49.61,85.42}}},
        },
        [186189] = { -- Complimentary Brewfest Sampler
            [objectKeys.spawns] = {[zoneIDs.DUN_MOROGH] = {{46.92,40.66},{46.92,40.69},{46.94,40.65},{47.06,40.06},{47.07,40.08},{47.56,39.68},{47.56,39.66},{47.68,39.65},{47.57,39.66},{47.67,39.66},{47.69,39.66},{47.58,39.69},{47.68,39.67},{47.58,39.67},{47.67,39.65},{48.2,39.01},{48.18,39.03},{47.57,39.66},{48.2,39.05},{47.58,39.69},{47.58,39.67},{47.69,39.66},{47.56,39.66},{48.2,39.05},{47.68,39.67},{48.2,39.03},{47.58,39.69},{48.58,39.91},{48.56,39.92},{48.57,39.91},{49.41,38.44},{49.39,38.45},{48.51,38.24},{48.53,38.24},{49.14,39.69},{49.41,38.47},{49.14,39.72},{49.16,39.68},{48.78,38.19},{48.79,38.16},{48.77,38.16},{49.4,38.48},{49.17,39.71},{48.79,38.18},{48.55,38.25},{47.68,39.67},{48.57,39.91},{46.94,40.65},{48.2,39.03},{48.77,38.16},{48.18,39.03},{48.2,39.05},{48.21,39.04},{49.4,38.48},{48.18,39.03},{47.58,39.69},{48.2,39.03},{47.58,39.67},{47.56,39.68},{48.2,39.05},{48.21,39.04},{49.16,39.68},{52.65,35.28},{52.63,35.29}}},
        },
        [201873] = {
            [objectKeys.spawns] = {[zoneIDs.ICECROWN_CITADEL_RAMPART_OF_SKULLS] = {{42.55,76.8}},[zoneIDs.ICECROWN_CITADEL] = {{-1,-1}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return objectFixesHorde
    else
        return objectFixesAlliance
    end
end

function ObjectRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    addOverride(overrides, classicFactionFixes())
    addOverride(overrides, tbcFactionFixes())
    addOverride(overrides, wotlkFactionFixes())
end
