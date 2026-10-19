---@class NPCRuntimeCorrections
local NPCRuntimeCorrections = QuestieLoader:CreateModule("NPCRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local function classicFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.43,50.04}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {
                [zoneIDs.UNDERCITY] = {{86.62,27.05}},
                [zoneIDs.ORGRIMMAR] = {{49.43,50.04}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.UNDERCITY] = {{53.29,74.56},{53.67,76.81},{52.01,75.96},{53.2,71.44}}},
            [npcKeys.zoneID] = zoneIDs.UNDERCITY,
        },
        [12138] = { -- Lunaclaw
            [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.79}}},
            [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [12144] = { -- Lunaclaw Spirit
            [npcKeys.spawns] = {[zoneIDs.THE_BARRENS] = {{41.96,60.79}}},
            [npcKeys.zoneID] = zoneIDs.THE_BARRENS,
        },
        [13778] = { -- PvP Tower Credit Marker
            [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{52.8,44},{50.8,30.8},{45.2,14.6},{44,18.1}}},
            [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{41.27,32.36}},
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
            },
        },
        [16788] = { -- Festival Flamekeeper
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{42.61,34.21}},
                [zoneIDs.UNDERCITY] = {{65.6,35.99}},
                [zoneIDs.THUNDER_BLUFF] = {{21.55,26.18}},
            },
            [npcKeys.zoneID] = zoneIDs.ORGRIMMAR,
        },
    }

    local npcFixesAlliance = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{25.09,77.45}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{25.09,77.45}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{40.87,89.04},{40.75,92.13},{41.27,90.54},{40.26,88.13},{40.89,87.75},{40.47,91.94}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [12138] = { -- Lunaclaw
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.33,45.85}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [12144] = { -- Lunaclaw Spirit
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.33,45.85}}},
            [npcKeys.zoneID] = zoneIDs.DARKSHORE,
        },
        [13778] = { -- PvP Tower Credit Marker
            [npcKeys.spawns] = {[zoneIDs.ALTERAC_VALLEY] = {{48.5,58.3},{50.2,65.3},{49.3,84.4},{48.3,84.3}}},
            [npcKeys.zoneID] = zoneIDs.ALTERAC_VALLEY,
        },
        [15898] = { -- Lunar Festival Vendor
            [npcKeys.spawns] = {
                [zoneIDs.STORMWIND_CITY] = {{22.78,51.19}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.DARNASSUS] = {{31.56,13.69}},
            },
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [16788] = { -- Festival Flamekeeper
            [npcKeys.spawns] = {
                [zoneIDs.TELDRASSIL] = {{56.56,91.94}},
                [zoneIDs.STORMWIND_CITY] = {{38.4,61.29}},
                [zoneIDs.IRONFORGE] = {{63.54,24.67}},
            },
            [npcKeys.zoneID] = zoneIDs.TELDRASSIL,
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end

local function tbcFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [23537] = {
            [npcKeys.spawns] = {
                [zoneIDs.TIRISFAL_GLADES] = {{60.45,53.41},{61.89,52.98},{60.4,52.95},{61.8,52.95},{61.66,52.94},{60.51,53.22},{56.97,53.03},{61.53,52.91},{61.19,52.55},{61.39,52.85},{60.31,52.93},{61.52,52.95},{59.84,52.3},{60.2,52.83},{59.93,52.44},{61.59,53.05},{60.14,52.7},{60.06,52.3},{60.11,52.44},{61.09,52.39},{59.71,52.17},{60.95,51.55},{61.01,52.25},{60.95,51.72},{60.99,51.6},{60.77,51.68},{60.85,51.51},{60.75,51.8},{61.07,51.68},{60.68,51.55},{61.13,51.38},{61.3,51.36},{61.39,51.38},{60.73,51.24},{61.56,51.42},{61.57,51.27},{60.52,51.08},{60.35,50.98},{60.26,50.92},{56.33,53.05},{56.65,53.38}},
                [zoneIDs.DUROTAR] = {{51.93,41.62},{51.94,41.56},{51.88,41.7},{51.97,41.52},{51.98,41.67},{53.14,42.3},{51.63,42.26},{53.11,42.36},{51.67,42.22},{51.63,42.5},{51.76,42.0},{53.15,42.47},{53.12,42.43},{51.59,42.29},{51.73,42.22},{53.05,41.97},{53.17,42.37},{53.06,42.09},{51.75,42.41},{51.57,42.47},{53.06,43.0},{52.12,43.65},{52.2,43.61},{52.02,43.47},{52.11,43.49},{51.79,43.26},{53.22,42.73},{53.22,42.74},{53.17,42.84},{52.08,43.52},{51.94,42.98},{51.89,43.27},{51.78,43.2},{51.95,43.3},{51.75,43.44},{53.17,42.68},{49.11,42.99},{49.15,43.17},{49.23,42.9},{49.28,43.09},{49.29,43.41}},
                [zoneIDs.EVERSONG_WOODS] = {{47.65,47.43},{47.79,47.26},{47.77,47.3},{47.87,47.14},{47.77,47.3},{47.69,47.42},{47.76,47.32},{47.83,47.2},{47.75,47.28},{47.86,47.16},{47.84,47.2},{47.78,47.23},{47.68,47.43},{47.68,47.42},{47.88,47.13},{47.7,47.35},{47.85,47.14},{47.72,47.36},{48.21,46.4},{48.21,46.34},{48.21,46.17},{48.19,46.27},{48.21,46.16},{48.19,46.35},{48.21,46.46},{48.21,46.16},{48.19,46.17},{48.21,46.27},{48.21,46.24},{48.21,46.03},{48.19,45.98},{48.21,45.89},{48.19,46.09},{48.21,46.01},{48.21,46.08},{48.21,45.97},{46.62,55.02},{46.56,55.2},{46.5,55.36},{46.37,55.34},{46.25,55.32}},
            },
        },
    }

    local npcFixesAlliance = {
        [23537] = {
            [npcKeys.spawns] = {
                [zoneIDs.AZUREMYST_ISLE] = {{48.77,49.92},{48.67,48.99},{43.8,51.94},{43.5,51.93},{43.43,51.53},{43.64,52.09},{43.34,51.76},{49.4,52.55},{49.34,52.74},{49.4,52.67},{49.34,52.49},{49.32,52.6},{49.43,52.34},{49.51,52.28},{49.4,52.4},{49.61,52.29},{49.84,52.56},{49.89,52.66},{49.55,52.33},{49.72,52.42},{49.84,52.68},{49.46,52.36},{49.8,52.42},{49.71,52.33},{48.87,49.73},{48.67,49.99},{48.87,49.53},{48.84,49.79},{48.77,49.48},{48.46,49.98},{48.81,49.57},{48.55,50.01},{48.9,49.65},{48.7,49.95},{48.47,49.86},{48.54,49.93},{48.76,49.23},{48.75,49.31},{48.83,49.4},{48.74,49.08}},
                [zoneIDs.ELWYNN_FOREST] = {{42.94,66.17},{41.9,65.92},{43.08,65.55},{43.12,66.49},{43.07,65.82},{42.96,65.71},{42.99,66.5},{41.65,65.23},{42.99,66.53},{41.35,65.23},{41.82,65.31},{43.1,65.75},{41.84,65.76},{43.09,65.61},{41.88,65.4},{43.07,66.22},{43.1,65.36},{43.06,66.13},{41.52,65.1},{41.74,65.29},{43.24,65.55},{41.78,66.06},{43.13,65.33},{42.75,65.28},{41.93,65.65},{41.62,66.03},{43.27,66.51},{43.2,66.51},{43.13,66.53},{43.37,66.51},{41.66,66.11},{43.41,66.59},{41.5,65.99},{41.4,66.12},{41.17,65.77},{41.27,65.99},{42.55,59.35},{42.63,60.0},{42.71,59.37},{42.39,59.7},{42.91,59.38}},
                [zoneIDs.DUN_MOROGH] = {{47.01,52.55},{47.17,51.91},{47.06,51.83},{47.1,52.83},{47.06,51.75},{47.02,52.34},{47.16,51.75},{46.97,51.75},{46.82,52.19},{47.01,52.4},{46.88,52.21},{47.3,51.9},{45.98,51.93},{46.87,51.75},{47.24,51.75},{45.98,51.79},{47.01,52.8},{47.02,52.5},{47.32,51.75},{47.01,52.25},{45.98,52.06},{47.01,52.64},{47.03,52.66},{46.99,52.19},{46.91,52.25},{46.95,51.83},{46.83,51.84},{45.92,51.56},{45.98,51.65},{45.85,52.09},{45.8,51.54},{45.76,52.21},{45.63,51.31},{45.63,51.43},{45.74,51.43},{45.67,52.35},{47.19,57.3},{47.29,57.17},{47.3,56.96},{47.41,57.14},{47.31,57.38}},
            },
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
end

local function wotlkFactionFixes()
    local npcKeys = QuestieDB.npcKeys
    local zoneIDs = ZoneDB.zoneIDs

    local npcFixesHorde = {
        [15898] = {
            [npcKeys.spawns] = {
                [zoneIDs.ORGRIMMAR] = {{41.27,32.36}},
                [zoneIDs.THUNDER_BLUFF] = {{70.56,27.83}},
                [zoneIDs.UNDERCITY] = {{66.45,36.02}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.SILVERMOON_CITY] = {{73.41,82.17}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [24108] = { -- Self-Turning and Oscillating Utility Target
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{45.26,17.79}}},
        },
        [26221] = {
            [npcKeys.spawns] = {[zoneIDs.UNDERCITY] = {{66.9,13.53}},[zoneIDs.ORGRIMMAR] = {{46.44,38.69}},[zoneIDs.THUNDER_BLUFF] = {{22.16,23.98}},[zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},[zoneIDs.SILVERMOON_CITY] = {{68.67,42.94}}},
        },
        [29579] = {
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{36.62,49.27}}},
        },
        [34806] = {
            [npcKeys.name] = "Spirit of Sharing",
            [npcKeys.spawns] = {
                [zoneIDs.STORM_PEAKS] = {{40.38,85.5}},
                [zoneIDs.ZUL_DRAK] = {{41.2,68.25}},
                [zoneIDs.GRIZZLY_HILLS] = {{22.43,65.94}},
                [zoneIDs.HOWLING_FJORD] = {{49.14,13.05}},
                [zoneIDs.DRAGONBLIGHT] = {{37.25,47.11}},
                [zoneIDs.BOREAN_TUNDRA] = {{40.95,52.44},{40.62,52.88}},
                [zoneIDs.SHOLAZAR_BASIN] = {{47.59,60.92}},
                [zoneIDs.SHATTRATH_CITY] = {{43.42,51.93},{43.17,50.29},{42.96,48.61},{42.7,46.84}},
                [zoneIDs.SHADOWMOON_VALLEY] = {{29.97,28.77}},
                [zoneIDs.NAGRAND] = {{56.65,33.94}},
                [zoneIDs.ZANGARMARSH] = {{32.75,51.19}},
                [zoneIDs.BLADES_EDGE_MOUNTAINS] = {{52.28,54.96}},
                [zoneIDs.NETHERSTORM] = {{33.9,64.43}},
                [zoneIDs.HELLFIRE_PENINSULA] = {{56.44,38.39},{56.02,37.74}},
                [zoneIDs.WINTERSPRING] = {{60.26,36.41}},
                [zoneIDs.TANARIS] = {{51.95,25.55}},
                [zoneIDs.SILITHUS] = {{51.89,37.71}},
                [zoneIDs.FERALAS] = {{74.88,43.33}},
                [zoneIDs.THOUSAND_NEEDLES] = {{45.54,51.59}},
                [zoneIDs.STRANGLETHORN_VALE] = {{32.35,28.3}},
                [zoneIDs.SWAMP_OF_SORROWS] = {{46.2,56.66}},
                [zoneIDs.BURNING_STEPPES] = {{63.96,31.66}},
                [zoneIDs.BADLANDS] = {{5.02,48.98}},
                [zoneIDs.ARATHI_HIGHLANDS] = {{74.86,36.88}},
                [zoneIDs.HILLSBRAD_FOOTHILLS] = {{61.03,20.84}},
                [zoneIDs.THE_HINTERLANDS] = {{79,80.76}},
                [zoneIDs.EASTERN_PLAGUELANDS] = {{74.11,52.14}},
                [zoneIDs.DUROTAR] = {{46.32,14.58},{46.37,15.08},{46.66,15.02},{46.64,14.58},{52.98,43.89},{52.99,43.54}},
                [zoneIDs.GHOSTLANDS] = {{44.85,30.98}},
                [zoneIDs.EVERSONG_WOODS] = {{55.65,53.15},{55.61,53.53},{55.3,53.18},{55.29,53.64},{46.52,46.64},{46.5,46.94},{46.46,47.27}},
                [zoneIDs.UNDERCITY] = {{64.1,14.23},{67.82,14.3},{67.98,7.85},{64.37,7.86}},
                [zoneIDs.TIRISFAL_GLADES] = {{58.81,51.17},{59.12,51.21},{59.38,51.26}},
                [zoneIDs.SILVERPINE_FOREST] = {{44.33,42.33}},
                [zoneIDs.THUNDER_BLUFF] = {{29.83,62.24},{31.24,66.99},{30.21,67.43},{28.76,62.4}},
                [zoneIDs.MULGORE] = {{46.43,59.57},{46.23,59.77}},
                [zoneIDs.THE_BARRENS] = {{51.52,29.52},{51.62,29.42},{62.48,38.22}},
                [zoneIDs.STONETALON_MOUNTAINS] = {{46.25,59.98}},
                [zoneIDs.ASHENVALE] = {{73.9,60.47}},
                [zoneIDs.DUSTWALLOW_MARSH] = {{35.68,31.53}},
                [zoneIDs.DESOLACE] = {{25.41,72.09}},
            },
        },
        [34907] = {
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{43.43,53.57},{43.1,53.5},{42.94,53.83},{43.92,54.36},{44.07,54.44},{43.82,54.64},{42.62,53.3},{42.85,53.33},{44.23,54.41},{43.36,53.87}}},
        },
        [34947] = {
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{43.43,53.57},{43.1,53.5},{42.94,53.83},{43.92,54.36},{44.07,54.44},{43.82,54.64},{42.62,53.3},{42.85,53.33},{44.23,54.41},{43.36,53.87}}},
        },
        [35060] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35061] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35071] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{74.14,10.52},{74.7,9.72},{74.15,9.14},{73.76,9.69}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [37214] = {
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{40.3,15.8},{40.1,15.5},{40.5,15.5},{40.5,15.2},{40.3,15.0}}},
        },
        [37715] = {
            [npcKeys.spawns] = {[zoneIDs.DUROTAR] = {{50.63,13.13}}},
        },
        [37917] = {
            [npcKeys.spawns] = {[zoneIDs.SILVERPINE_FOREST] = {{55.2,61.0},{55.3,62.0},{54.9,63.1},{54.6,62.3}}},
        },
        [38340] = {
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{49,68.96}}}
        },
        [38341] = {
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{54.26,63.77}}}
        },
        [38342] = {
            [npcKeys.spawns] = {[zoneIDs.ORGRIMMAR] = {{47.21,54.09}}}
        },
    }

    local npcFixesAlliance = {
        [5676] = { -- Summoned Voidwalker
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
        },
        [5677] = { -- Summoned Succubus
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{39.09,84.36}}},
        },
        [6492] = { -- Rift Spawn
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{51.32,92.34},{50.83,92.63},{51.61,94.5},{51.21,95.73},{50.99,95.58},{51.3,93.34}}},
            [npcKeys.zoneID] = zoneIDs.STORMWIND_CITY,
        },
        [15898] = {
            [npcKeys.spawns] = {
                [zoneIDs.STORMWIND_CITY] = {{37.32,64.04}},
                [zoneIDs.IRONFORGE] = {{29.92,14.21}},
                [zoneIDs.DARNASSUS] = {{34.57,12.8}},
                [zoneIDs.MOONGLADE] = {{36.58,58.1},{36.3,58.53}},
                [zoneIDs.SHATTRATH_CITY] = {{52.63,33.25},{48.64,36.29}},
                [zoneIDs.THE_EXODAR] = {{74.02,58.23}},
                [zoneIDs.DALARAN] = {{47.93,43.32}},
            },
        },
        [24108] = { -- Self-Turning and Oscillating Utility Target
            [npcKeys.spawns] = {[zoneIDs.DUN_MOROGH] = {{47.64,39.3}}},
        },
        [26221] = {
            [npcKeys.spawns] = {[zoneIDs.TELDRASSIL] = {{56.1,92.16}},[zoneIDs.SHATTRATH_CITY] = {{60.68,30.62}},[zoneIDs.IRONFORGE] = {{65.14,27.71}},[zoneIDs.STORMWIND_CITY] = {{49.32,72.3}},[zoneIDs.THE_EXODAR] = {{43.27,26.26}}},
        },
        [29579] = {
            [npcKeys.spawns] = {[zoneIDs.STORM_PEAKS] = {{30.1,73.9}}},
        },
        [34806] = {
            [npcKeys.name] = "Spirit of Sharing",
            [npcKeys.spawns] = {
                [zoneIDs.STORM_PEAKS] = {{40.38,85.5}},
                [zoneIDs.ZUL_DRAK] = {{41.2,68.25}},
                [zoneIDs.GRIZZLY_HILLS] = {{31.3,59.59}},
                [zoneIDs.HOWLING_FJORD] = {{60.45,16.74}},
                [zoneIDs.DRAGONBLIGHT] = {{77.78,50.85}},
                [zoneIDs.BOREAN_TUNDRA] = {{56.93,67.48},{56.92,67.82}},
                [zoneIDs.SHOLAZAR_BASIN] = {{47.59,60.92}},
                [zoneIDs.SHATTRATH_CITY] = {{43.42,51.93},{43.17,50.29},{42.96,48.61},{42.7,46.84}},
                [zoneIDs.SHADOWMOON_VALLEY] = {{37.78,55.62}},
                [zoneIDs.NAGRAND] = {{54.03,75.49}},
                [zoneIDs.ZANGARMARSH] = {{67.72,51.16}},
                [zoneIDs.BLADES_EDGE_MOUNTAINS] = {{37.9,61.97}},
                [zoneIDs.NETHERSTORM] = {{33.9,64.43}},
                [zoneIDs.HELLFIRE_PENINSULA] = {{55.07,63.22},{56.45,63.92}},
                [zoneIDs.THE_EXODAR] = {{75.74,52.29},{75.75,50.51},{76.95,51.26},{77.21,53.08}},
                [zoneIDs.AZUREMYST_ISLE] = {{51.71,52.11},{51.69,51.14}},
                [zoneIDs.BLOODMYST_ISLE] = {{56.03,58.75}},
                [zoneIDs.DARKSHORE] = {{36.91,43.65}},
                [zoneIDs.WINTERSPRING] = {{62.17,37.03}},
                [zoneIDs.DARNASSUS] = {{69.56,38.23},{67.85,38.08},{67.81,36.09},{69.47,36.08}},
                [zoneIDs.TELDRASSIL] = {{56.44,58.4},{56.36,56.92}},
                [zoneIDs.TANARIS] = {{51.2,29.42}},
                [zoneIDs.SILITHUS] = {{51.89,37.71}},
                [zoneIDs.FERALAS] = {{29.96,43.41}},
                [zoneIDs.ELWYNN_FOREST] = {{34.33,51.18},{34.58,50.81},{34.81,50.45},{41.52,64.04},{41.43,64.65},{41.67,64.83}},
                [zoneIDs.DUN_MOROGH] = {{52.77,36.41},{52.76,36.74},{52.76,37.03},{46.69,55.41},{46.66,55.12},{46.64,54.75},{46.19,52.91}},
                [zoneIDs.WESTFALL] = {{53.21,52.61}},
                [zoneIDs.STRANGLETHORN_VALE] = {{37.87,3.78}},
                [zoneIDs.DUSKWOOD] = {{77.64,43.85}},
                [zoneIDs.BLASTED_LANDS] = {{66.54,23.66}},
                [zoneIDs.REDRIDGE_MOUNTAINS] = {{32.23,53.35}},
                [zoneIDs.BURNING_STEPPES] = {{85.83,69.78}},
                [zoneIDs.LOCH_MODAN] = {{32.16,48.4}},
                [zoneIDs.WETLANDS] = {{9.19,60.77},},
                [zoneIDs.ARATHI_HIGHLANDS] = {{46,45.97}},
                [zoneIDs.HILLSBRAD_FOOTHILLS] = {{49.61,61.05}},
                [zoneIDs.THE_HINTERLANDS] = {{13.91,46.87}},
                [zoneIDs.EASTERN_PLAGUELANDS] = {{74.81,54.22}},
                [zoneIDs.WESTERN_PLAGUELANDS] = {{43.73,84.72}},
                [zoneIDs.THE_BARRENS] = {{62.64,38.23}},
                [zoneIDs.DUSTWALLOW_MARSH] = {{68,50.78}},
                [zoneIDs.DESOLACE] = {{65.19,8.73}},
                [zoneIDs.ASHENVALE] = {{35.26,50.41}},
            },
        },
        [34907] = {
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{50.21,49.08},{50.14,49.47},{49.75,49.51},{50.06,49.08},{50.63,48.98},{51.18,48.81},{50.43,49.05},{49.9,49.59},{50.3,49.61},{51,48.53}}},
        },
        [34947] = {
            [npcKeys.spawns] = {[zoneIDs.HROTHGARS_LANDING] = {{50.21,49.08},{50.14,49.47},{49.75,49.51},{50.06,49.08},{50.63,48.98},{51.18,48.81},{50.43,49.05},{49.9,49.59},{50.3,49.61},{51,48.53}}},
        },
        [35060] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35061] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [35071] = {
            [npcKeys.spawns] = {[zoneIDs.ICECROWN] = {{66.87,8.97},{66.36,8.08},{67.31,8.2},{66.92,7.55}}},
            [npcKeys.zoneID] = zoneIDs.ICECROWN,
        },
        [37214] = {
            [npcKeys.spawns] = {[zoneIDs.ELWYNN_FOREST] = {{29.1,66.5},{28.8,66.2},{29.5,65.7},{28.8,65.7},{29.2,65.2}}},
        },
        [37715] = {
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{27.43,34.83}}},
        },
        [37917] = {
            [npcKeys.spawns] = {[zoneIDs.DARKSHORE] = {{43.3,79.9},{43.2,79.9},{43.2,79.5},{42.7,79.5},{43.0,79.4}}},
        },
        [38340] = {
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{63.08,78.86}}},
        },
        [38341] = {
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{60.81,70.03}}},
        },
        [38342] = {
            [npcKeys.spawns] = {[zoneIDs.STORMWIND_CITY] = {{61.33,65.64}}},
        },
    }

    if UnitFactionGroup("Player") == "Horde" then
        return npcFixesHorde
    else
        return npcFixesAlliance
    end
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
    addOverride(overrides, classicFactionFixes())
    addOverride(overrides, tbcFactionFixes())
    addOverride(overrides, wotlkFactionFixes())
end
