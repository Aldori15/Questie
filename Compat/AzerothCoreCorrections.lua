---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end

-- Generated from tools/reports/acore_relation_suggestions.lua and tools/reports/acore_metadata_suggestions.lua.
-- Regenerate this file from the validators when AzerothCore quest data changes.

QuestieCompat.RegisterCorrection("questData", function()
    local questKeys = QuestieDB.questKeys

    -- AzerothCore quest relation parity.
    local relationCorrections = {
        -- REVIEW BEFORE APPLYING.
        -- Generated from AzerothCore static quest relation tables and item_template.startquest.
        -- Scripted starts, events, phasing, and intentional Questie divergences still need manual review.

        [171] = {
            [questKeys.startedBy] = {},
        },

        [172] = {
            [questKeys.startedBy] = {},
        },

        [176] = {
            [questKeys.startedBy] = {nil,{68}},
        },

        [415] = {
            [questKeys.startedBy] = {{1872}},
        },

        [467] = {
            [questKeys.startedBy] = {{1340}},
        },

        [550] = {
            [questKeys.startedBy] = {{2215}},
        },

        [558] = {
            [questKeys.startedBy] = {},
        },

        [615] = {
            [questKeys.startedBy] = {},
        },

        [781] = {
            [questKeys.startedBy] = {},
        },

        [910] = {
            [questKeys.startedBy] = {},
        },

        [911] = {
            [questKeys.startedBy] = {},
        },

        [915] = {
            [questKeys.startedBy] = {},
        },

        [925] = {
            [questKeys.startedBy] = {},
        },

        [926] = {
            [questKeys.startedBy] = {nil,{5620}},
            [questKeys.finishedBy] = {nil,{5620}},
        },

        [960] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [1133] = {
            [questKeys.startedBy] = {{4456}},
            [questKeys.finishedBy] = {{3845}},
        },

        [1155] = {
            [questKeys.startedBy] = {nil,nil,{17409}},
        },

        [1468] = {
            [questKeys.startedBy] = {},
        },

        [1479] = {
            [questKeys.startedBy] = {},
        },

        [1480] = {
            [questKeys.startedBy] = {nil,nil,{6766,20310}},
        },

        [1505] = {
            [questKeys.startedBy] = {{3063,3169,3354}},
        },

        [1523] = {
            [questKeys.startedBy] = {{3032}},
        },

        [1558] = {
            [questKeys.startedBy] = {},
        },

        [1661] = {
            [questKeys.startedBy] = {{6171}},
            [questKeys.finishedBy] = {{6171}},
        },

        [1684] = {
            [questKeys.startedBy] = {{2151,3598}},
        },

        [1687] = {
            [questKeys.startedBy] = {},
        },

        [1698] = {
            [questKeys.startedBy] = {{5479}},
        },

        [1794] = {
            [questKeys.startedBy] = {{5149}},
        },

        [1800] = {
            [questKeys.startedBy] = {},
        },

        [1883] = {
            [questKeys.startedBy] = {{7311}},
        },

        [1886] = {
            [questKeys.startedBy] = {{6467}},
        },

        [1898] = {
            [questKeys.startedBy] = {{6467}},
        },

        [1899] = {
            [questKeys.startedBy] = {{6522}},
        },

        [1947] = {
            [questKeys.startedBy] = {{5497,5885}},
        },

        [1953] = {
            [questKeys.startedBy] = {{4568,5144,5497,7311}},
        },

        [1962] = {
            [questKeys.startedBy] = {{4576}},
            [questKeys.finishedBy] = {{4576}},
        },

        [1978] = {
            [questKeys.finishedBy] = {{2425,36517}},
        },

        [2383] = {
            [questKeys.startedBy] = {{3143},nil,{6497}},
        },

        [2701] = {
            [questKeys.finishedBy] = {{7750}},
        },

        [2861] = {
            [questKeys.startedBy] = {{3048,4568,5144,5497,5885,16651}},
        },

        [2963] = {
            [questKeys.startedBy] = {{5387}},
        },

        [3111] = {
            [questKeys.startedBy] = {nil,nil,{9572}},
        },

        [3121] = {
            [questKeys.finishedBy] = {{3216}},
        },

        [3122] = {
            [questKeys.startedBy] = {{3216}},
        },

        [3638] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [3640] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [3642] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [3645] = {
            [questKeys.startedBy] = {{7944}},
            [questKeys.finishedBy] = {{7944}},
        },

        [3647] = {
            [questKeys.startedBy] = {{7406}},
            [questKeys.finishedBy] = {{7406}},
        },

        [4108] = {
            [questKeys.startedBy] = {{9528}},
            [questKeys.finishedBy] = {{9528}},
        },

        [4109] = {
            [questKeys.startedBy] = {{9528}},
            [questKeys.finishedBy] = {{9528}},
        },

        [4110] = {
            [questKeys.startedBy] = {{9528}},
            [questKeys.finishedBy] = {{9528}},
        },

        [4111] = {
            [questKeys.startedBy] = {{9528}},
            [questKeys.finishedBy] = {{9528}},
        },

        [4112] = {
            [questKeys.startedBy] = {{9528}},
            [questKeys.finishedBy] = {{9528}},
        },

        [4127] = {
            [questKeys.startedBy] = {nil,{164909}},
        },

        [4182] = {
            [questKeys.startedBy] = {{9562}},
            [questKeys.finishedBy] = {{9562}},
        },

        [4183] = {
            [questKeys.startedBy] = {{9562}},
            [questKeys.finishedBy] = {{344}},
        },

        [4184] = {
            [questKeys.startedBy] = {{344}},
            [questKeys.finishedBy] = {{1748,29611}},
        },

        [4185] = {
            [questKeys.startedBy] = {{1748,29611}},
            [questKeys.finishedBy] = {{1748}},
        },

        [4186] = {
            [questKeys.startedBy] = {{1748}},
            [questKeys.finishedBy] = {{344}},
        },

        [4264] = {
            [questKeys.startedBy] = {nil,nil,{11446}},
        },

        [4738] = {
            [questKeys.startedBy] = {{461}},
        },

        [4742] = {
            [questKeys.startedBy] = {{10296}},
            [questKeys.finishedBy] = {{10296}},
        },

        [4743] = {
            [questKeys.startedBy] = {{10296}},
            [questKeys.finishedBy] = {{10296}},
        },

        [4822] = {
            [questKeys.startedBy] = {},
        },

        [5402] = {
            [questKeys.startedBy] = {{10839}},
            [questKeys.finishedBy] = {{10839}},
        },

        [5403] = {
            [questKeys.startedBy] = {{10839}},
            [questKeys.finishedBy] = {{10839}},
        },

        [5407] = {
            [questKeys.startedBy] = {{10840}},
            [questKeys.finishedBy] = {{10840}},
        },

        [5408] = {
            [questKeys.startedBy] = {{10840}},
            [questKeys.finishedBy] = {{10840}},
        },

        [5502] = {
            [questKeys.startedBy] = {},
        },

        [5511] = {
            [questKeys.startedBy] = {{11057}},
            [questKeys.finishedBy] = {{11057}},
        },

        [5542] = {
            [questKeys.startedBy] = {{1855}},
        },

        [5543] = {
            [questKeys.startedBy] = {{1855}},
        },

        [5544] = {
            [questKeys.startedBy] = {{1855}},
        },

        [5627] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5631] = {
            [questKeys.startedBy] = {},
        },

        [5632] = {
            [questKeys.finishedBy] = {},
        },

        [5633] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5634] = {
            [questKeys.startedBy] = {},
        },

        [5635] = {
            [questKeys.startedBy] = {},
        },

        [5637] = {
            [questKeys.startedBy] = {},
        },

        [5640] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5641] = {
            [questKeys.finishedBy] = {},
        },

        [5645] = {
            [questKeys.finishedBy] = {},
        },

        [5647] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5655] = {
            [questKeys.finishedBy] = {},
        },

        [5672] = {
            [questKeys.startedBy] = {},
        },

        [5674] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5678] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [5882] = {
            [questKeys.startedBy] = {{9529}},
            [questKeys.finishedBy] = {{9529}},
        },

        [5883] = {
            [questKeys.startedBy] = {{9529}},
            [questKeys.finishedBy] = {{9529}},
        },

        [5884] = {
            [questKeys.startedBy] = {{9529}},
            [questKeys.finishedBy] = {{9529}},
        },

        [5885] = {
            [questKeys.startedBy] = {{9529}},
            [questKeys.finishedBy] = {{9529}},
        },

        [5886] = {
            [questKeys.startedBy] = {{9529}},
            [questKeys.finishedBy] = {{9529}},
        },

        [5923] = {
            [questKeys.startedBy] = {{3602}},
        },

        [5925] = {
            [questKeys.startedBy] = {{16721}},
        },

        [5926] = {
            [questKeys.startedBy] = {{3064}},
        },

        [5927] = {
            [questKeys.startedBy] = {{3060}},
        },

        [5928] = {
            [questKeys.startedBy] = {{16655}},
        },

        [6065] = {
            [questKeys.startedBy] = {{3171}},
        },

        [6066] = {
            [questKeys.startedBy] = {{3038}},
        },

        [6067] = {
            [questKeys.startedBy] = {{3061,3154,3407,16271}},
        },

        [6068] = {
            [questKeys.startedBy] = {{3038}},
        },

        [6069] = {
            [questKeys.startedBy] = {{3061,3154,16271}},
        },

        [6070] = {
            [questKeys.startedBy] = {{3407}},
        },

        [6072] = {
            [questKeys.startedBy] = {{895,5117,11807}},
        },

        [6074] = {
            [questKeys.startedBy] = {{3596,4146,4205,5117,16738,17110}},
        },

        [6186] = {
            [questKeys.finishedBy] = {{1748}},
        },

        [6187] = {
            [questKeys.startedBy] = {{1748}},
            [questKeys.finishedBy] = {{1748}},
        },

        [6402] = {
            [questKeys.finishedBy] = {{12580,17804}},
        },

        [6521] = {
            [questKeys.startedBy] = {{2425}},
            [questKeys.finishedBy] = {{2425}},
        },

        [6522] = {
            [questKeys.finishedBy] = {{2425}},
        },

        [6661] = {
            [questKeys.startedBy] = {{12997},nil,{17115}},
        },

        [6662] = {
            [questKeys.startedBy] = {{12997},nil,{17116}},
        },

        [6681] = {
            [questKeys.startedBy] = {nil,nil,{17126}},
        },

        [6721] = {
            [questKeys.startedBy] = {{5117}},
        },

        [6722] = {
            [questKeys.startedBy] = {{5515}},
        },

        [7042] = {
            [questKeys.startedBy] = {{13434}},
        },

        [7122] = {
            [questKeys.startedBy] = {{12096,13777}},
        },

        [7124] = {
            [questKeys.startedBy] = {{12097,13776}},
        },

        [7364] = {
            [questKeys.startedBy] = {{14188}},
            [questKeys.finishedBy] = {{14188}},
        },

        [7365] = {
            [questKeys.startedBy] = {{14187}},
            [questKeys.finishedBy] = {{14187}},
        },

        [7424] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7495] = {
            [questKeys.finishedBy] = {{1748,29611}},
        },

        [7496] = {
            [questKeys.startedBy] = {{1748}},
        },

        [7507] = {
            [questKeys.startedBy] = {nil,nil,{18401}},
        },

        [7561] = {
            [questKeys.startedBy] = {nil,nil,{18589}},
        },

        [7632] = {
            [questKeys.startedBy] = {nil,nil,{18703}},
        },

        [7668] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7669] = {
            [questKeys.startedBy] = {{928}},
            [questKeys.finishedBy] = {{928}},
        },

        [7781] = {
            [questKeys.finishedBy] = {{1748}},
        },

        [7788] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7871] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7872] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7873] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7886] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7887] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7888] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7921] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7922] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7923] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7924] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7925] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [7939] = {
            [questKeys.startedBy] = {{14832}},
        },

        [8080] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8154] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8155] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8156] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8228] = {
            [questKeys.startedBy] = {{15119}},
            [questKeys.finishedBy] = {{15119}},
        },

        [8229] = {
            [questKeys.startedBy] = {{15116}},
            [questKeys.finishedBy] = {{15116}},
        },

        [8233] = {
            [questKeys.startedBy] = {{918,3328,4215,4583,5166,5167,13283,16685}},
        },

        [8250] = {
            [questKeys.startedBy] = {{3047,3049,4567,5145,5498,5883,16652,17513}},
        },

        [8254] = {
            [questKeys.startedBy] = {{376,3045,3046,4090,4091,4606,4608,5141,5142,5489,6014,6018,11401,11406,16658,16659,16756,17511}},
        },

        [8289] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8291] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8292] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8293] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8297] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8356] = {
            [questKeys.startedBy] = {},
        },

        [8367] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [8368] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8369] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8370] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8371] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [8372] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8374] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8375] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8383] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8384] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8385] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [8386] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8387] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8388] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [8389] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8390] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8391] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8392] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8393] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8394] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8395] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8396] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8397] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8398] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8399] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8400] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8401] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8402] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8403] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8404] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8405] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8406] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8407] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8408] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [8415] = {
            [questKeys.startedBy] = {{928}},
        },

        [8426] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8427] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8428] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8429] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8430] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8431] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8432] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8433] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8434] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8435] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8436] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8437] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8438] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8439] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8440] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8441] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8442] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8443] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [8575] = {
            [questKeys.startedBy] = {nil,nil,{20949}},
        },

        [8579] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8746] = {
            [questKeys.startedBy] = {},
        },

        [8762] = {
            [questKeys.startedBy] = {},
        },

        [8763] = {
            [questKeys.startedBy] = {},
        },

        [8767] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8792] = {
            [questKeys.startedBy] = {{15702,15703,15704,21155}},
        },

        [8793] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8794] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8795] = {
            [questKeys.startedBy] = {{15707,15708,15709,21156}},
            [questKeys.finishedBy] = {{15701}},
        },

        [8796] = {
            [questKeys.startedBy] = {},
        },

        [8797] = {
            [questKeys.startedBy] = {},
        },

        [8799] = {
            [questKeys.startedBy] = {},
        },

        [8811] = {
            [questKeys.startedBy] = {{15731}},
            [questKeys.finishedBy] = {{15731}},
        },

        [8817] = {
            [questKeys.startedBy] = {{15767}},
        },

        [8819] = {
            [questKeys.startedBy] = {{15731}},
            [questKeys.finishedBy] = {{15731}},
        },

        [8830] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8831] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8860] = {
            [questKeys.startedBy] = {},
        },

        [8861] = {
            [questKeys.startedBy] = {},
        },

        [8862] = {
            [questKeys.startedBy] = {},
        },

        [8863] = {
            [questKeys.startedBy] = {},
        },

        [8864] = {
            [questKeys.startedBy] = {},
        },

        [8865] = {
            [questKeys.startedBy] = {},
        },

        [8876] = {
            [questKeys.startedBy] = {},
        },

        [8877] = {
            [questKeys.startedBy] = {},
        },

        [8878] = {
            [questKeys.startedBy] = {},
        },

        [8879] = {
            [questKeys.startedBy] = {},
        },

        [8880] = {
            [questKeys.startedBy] = {},
        },

        [8881] = {
            [questKeys.startedBy] = {},
        },

        [8882] = {
            [questKeys.startedBy] = {},
        },

        [8897] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8898] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8899] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8903] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8904] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8979] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8980] = {
            [questKeys.startedBy] = {},
        },

        [8981] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [8983] = {
            [questKeys.startedBy] = {},
        },

        [8993] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9024] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9025] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9027] = {
            [questKeys.startedBy] = {},
        },

        [9029] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9094] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9154] = {
            [questKeys.startedBy] = {{616241,616255}},
            [questKeys.finishedBy] = {{616281}},
        },

        [9177] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9260] = {
            [questKeys.startedBy] = {{16478,616478}},
            [questKeys.finishedBy] = {{16478,616478}},
        },

        [9261] = {
            [questKeys.startedBy] = {{16484,616484}},
            [questKeys.finishedBy] = {{16484,616484}},
        },

        [9262] = {
            [questKeys.startedBy] = {{16495,616495}},
            [questKeys.finishedBy] = {{16495,616495}},
        },

        [9263] = {
            [questKeys.startedBy] = {{16493,616493}},
            [questKeys.finishedBy] = {{16493,616493}},
        },

        [9264] = {
            [questKeys.startedBy] = {{16490,616490}},
            [questKeys.finishedBy] = {{16490,616490}},
        },

        [9265] = {
            [questKeys.startedBy] = {{16494,616494}},
            [questKeys.finishedBy] = {{16494,616494}},
        },

        [9292] = {
            [questKeys.finishedBy] = {{16478,616478}},
        },

        [9295] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9299] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9300] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9301] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9302] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9304] = {
            [questKeys.finishedBy] = {{16281,616281}},
        },

        [9310] = {
            [questKeys.finishedBy] = {{16494,616494}},
        },

        [9317] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9318] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9319] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9320] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9321] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9322] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9323] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9333] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9334] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9335] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9336] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9337] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9339] = {
            [questKeys.startedBy] = {},
        },

        [9341] = {
            [questKeys.startedBy] = {{616786}},
            [questKeys.finishedBy] = {{616786}},
        },

        [9343] = {
            [questKeys.startedBy] = {{616787}},
            [questKeys.finishedBy] = {{616787}},
        },

        [9365] = {
            [questKeys.startedBy] = {},
        },

        [9386] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [9500] = {
            [questKeys.startedBy] = {{17219}},
        },

        [9502] = {
            [questKeys.startedBy] = {{23127}},
        },

        [9547] = {
            [questKeys.startedBy] = {{23127}},
        },

        [9551] = {
            [questKeys.startedBy] = {{17219}},
        },

        [9617] = {
            [questKeys.startedBy] = {{3038,3061,3154,3171,3407,16271}},
        },

        [9681] = {
            [questKeys.startedBy] = {{17717}},
        },

        [9712] = {
            [questKeys.startedBy] = {{17717}},
            [questKeys.finishedBy] = {{17717}},
        },

        [10169] = {
            [questKeys.startedBy] = {},
        },

        [10445] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10460] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10461] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10462] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10463] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10464] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10465] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10466] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10467] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10468] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10469] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10470] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10471] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10472] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10473] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10474] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10475] = {
            [questKeys.startedBy] = {{19935}},
        },

        [10500] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [10501] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [10530] = {
            [questKeys.startedBy] = {},
        },

        [10754] = {
            [questKeys.startedBy] = {nil,nil,{31239}},
        },

        [10755] = {
            [questKeys.startedBy] = {nil,nil,{31241}},
        },

        [10797] = {
            [questKeys.startedBy] = {nil,nil,{31363}},
        },

        [10872] = {
            [questKeys.finishedBy] = {},
        },

        [10888] = {
            [questKeys.startedBy] = {{18481}},
        },

        [10901] = {
            [questKeys.startedBy] = {{22421}},
            [questKeys.finishedBy] = {{22421}},
        },

        [10942] = {
            [questKeys.startedBy] = {},
        },

        [10943] = {
            [questKeys.startedBy] = {},
        },

        [10945] = {
            [questKeys.startedBy] = {},
        },

        [10950] = {
            [questKeys.startedBy] = {},
        },

        [10951] = {
            [questKeys.startedBy] = {},
        },

        [10952] = {
            [questKeys.startedBy] = {},
        },

        [10953] = {
            [questKeys.startedBy] = {},
        },

        [10954] = {
            [questKeys.startedBy] = {},
        },

        [10956] = {
            [questKeys.startedBy] = {},
        },

        [10960] = {
            [questKeys.startedBy] = {},
        },

        [10962] = {
            [questKeys.startedBy] = {},
        },

        [10963] = {
            [questKeys.startedBy] = {},
        },

        [10966] = {
            [questKeys.startedBy] = {},
        },

        [10967] = {
            [questKeys.startedBy] = {},
        },

        [10968] = {
            [questKeys.startedBy] = {},
        },

        [11052] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11103] = {
            [questKeys.startedBy] = {{19935}},
            [questKeys.finishedBy] = {{19935}},
        },

        [11104] = {
            [questKeys.startedBy] = {{19935}},
            [questKeys.finishedBy] = {{19935}},
        },

        [11105] = {
            [questKeys.startedBy] = {{19935}},
            [questKeys.finishedBy] = {{19935}},
        },

        [11106] = {
            [questKeys.startedBy] = {{19935}},
            [questKeys.finishedBy] = {{19935}},
        },

        [11185] = {
            [questKeys.startedBy] = {nil,nil,{33114}},
        },

        [11186] = {
            [questKeys.startedBy] = {nil,nil,{33115}},
        },

        [11189] = {
            [questKeys.startedBy] = {nil,nil,{33121}},
        },

        [11222] = {
            [questKeys.startedBy] = {{4968}},
            [questKeys.finishedBy] = {{1748}},
        },

        [11223] = {
            [questKeys.startedBy] = {{1748}},
            [questKeys.finishedBy] = {{4968}},
        },

        [11335] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [11336] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [11337] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [11338] = {
            [questKeys.startedBy] = {{215351}},
            [questKeys.finishedBy] = {{215351}},
        },

        [11339] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [11340] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [11341] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [11342] = {
            [questKeys.startedBy] = {{215350}},
            [questKeys.finishedBy] = {{215350}},
        },

        [11356] = {
            [questKeys.startedBy] = {},
        },

        [11357] = {
            [questKeys.startedBy] = {},
        },

        [11392] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11401] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11405] = {
            [questKeys.startedBy] = {},
        },

        [11441] = {
            [questKeys.startedBy] = {},
        },

        [11446] = {
            [questKeys.startedBy] = {},
        },

        [11528] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11534] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11551] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11552] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11553] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [11580] = {
            [questKeys.startedBy] = {},
        },

        [11581] = {
            [questKeys.startedBy] = {},
        },

        [11583] = {
            [questKeys.startedBy] = {},
        },

        [11584] = {
            [questKeys.startedBy] = {},
        },

        [11657] = {
            [questKeys.startedBy] = {},
        },

        [11691] = {
            [questKeys.startedBy] = {},
        },

        [11696] = {
            [questKeys.startedBy] = {},
        },

        [11731] = {
            [questKeys.startedBy] = {},
        },

        [11732] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187914}},
        },

        [11734] = {
            [questKeys.startedBy] = {},
        },

        [11735] = {
            [questKeys.startedBy] = {},
        },

        [11736] = {
            [questKeys.startedBy] = {},
        },

        [11737] = {
            [questKeys.startedBy] = {},
        },

        [11738] = {
            [questKeys.startedBy] = {},
        },

        [11739] = {
            [questKeys.startedBy] = {},
        },

        [11740] = {
            [questKeys.startedBy] = {},
        },

        [11741] = {
            [questKeys.startedBy] = {},
        },

        [11742] = {
            [questKeys.startedBy] = {},
        },

        [11743] = {
            [questKeys.startedBy] = {},
        },

        [11744] = {
            [questKeys.startedBy] = {},
        },

        [11745] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187928}},
        },

        [11746] = {
            [questKeys.startedBy] = {},
        },

        [11747] = {
            [questKeys.startedBy] = {},
        },

        [11748] = {
            [questKeys.startedBy] = {},
        },

        [11749] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187932}},
        },

        [11750] = {
            [questKeys.startedBy] = {},
        },

        [11751] = {
            [questKeys.startedBy] = {},
        },

        [11752] = {
            [questKeys.startedBy] = {},
        },

        [11753] = {
            [questKeys.startedBy] = {},
        },

        [11754] = {
            [questKeys.startedBy] = {},
        },

        [11755] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187938}},
        },

        [11756] = {
            [questKeys.startedBy] = {},
        },

        [11757] = {
            [questKeys.startedBy] = {},
        },

        [11758] = {
            [questKeys.startedBy] = {},
        },

        [11759] = {
            [questKeys.startedBy] = {},
        },

        [11760] = {
            [questKeys.startedBy] = {},
        },

        [11761] = {
            [questKeys.startedBy] = {},
        },

        [11762] = {
            [questKeys.startedBy] = {},
        },

        [11763] = {
            [questKeys.startedBy] = {},
        },

        [11764] = {
            [questKeys.startedBy] = {},
        },

        [11765] = {
            [questKeys.startedBy] = {},
        },

        [11766] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187954}},
        },

        [11767] = {
            [questKeys.startedBy] = {},
        },

        [11768] = {
            [questKeys.startedBy] = {},
        },

        [11769] = {
            [questKeys.startedBy] = {},
        },

        [11770] = {
            [questKeys.startedBy] = {},
        },

        [11771] = {
            [questKeys.startedBy] = {},
        },

        [11772] = {
            [questKeys.startedBy] = {},
        },

        [11773] = {
            [questKeys.startedBy] = {},
        },

        [11774] = {
            [questKeys.startedBy] = {},
        },

        [11775] = {
            [questKeys.startedBy] = {},
        },

        [11776] = {
            [questKeys.startedBy] = {},
        },

        [11777] = {
            [questKeys.startedBy] = {},
        },

        [11778] = {
            [questKeys.startedBy] = {},
        },

        [11779] = {
            [questKeys.startedBy] = {},
        },

        [11780] = {
            [questKeys.startedBy] = {},
        },

        [11781] = {
            [questKeys.startedBy] = {},
        },

        [11782] = {
            [questKeys.startedBy] = {},
        },

        [11783] = {
            [questKeys.startedBy] = {},
        },

        [11784] = {
            [questKeys.startedBy] = {},
        },

        [11785] = {
            [questKeys.startedBy] = {},
        },

        [11786] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {nil,{187974}},
        },

        [11787] = {
            [questKeys.startedBy] = {},
        },

        [11799] = {
            [questKeys.startedBy] = {},
        },

        [11800] = {
            [questKeys.startedBy] = {},
        },

        [11801] = {
            [questKeys.startedBy] = {},
        },

        [11802] = {
            [questKeys.startedBy] = {},
        },

        [11803] = {
            [questKeys.startedBy] = {},
        },

        [11804] = {
            [questKeys.startedBy] = {},
        },

        [11805] = {
            [questKeys.startedBy] = {},
        },

        [11806] = {
            [questKeys.startedBy] = {},
        },

        [11807] = {
            [questKeys.startedBy] = {},
        },

        [11808] = {
            [questKeys.startedBy] = {},
        },

        [11809] = {
            [questKeys.startedBy] = {},
        },

        [11810] = {
            [questKeys.startedBy] = {},
        },

        [11811] = {
            [questKeys.startedBy] = {},
        },

        [11812] = {
            [questKeys.startedBy] = {},
        },

        [11813] = {
            [questKeys.startedBy] = {},
        },

        [11814] = {
            [questKeys.startedBy] = {},
        },

        [11815] = {
            [questKeys.startedBy] = {},
        },

        [11816] = {
            [questKeys.startedBy] = {},
        },

        [11817] = {
            [questKeys.startedBy] = {},
        },

        [11818] = {
            [questKeys.startedBy] = {},
        },

        [11819] = {
            [questKeys.startedBy] = {},
        },

        [11820] = {
            [questKeys.startedBy] = {},
        },

        [11821] = {
            [questKeys.startedBy] = {},
        },

        [11822] = {
            [questKeys.startedBy] = {},
        },

        [11823] = {
            [questKeys.startedBy] = {},
        },

        [11824] = {
            [questKeys.startedBy] = {},
        },

        [11825] = {
            [questKeys.startedBy] = {},
        },

        [11826] = {
            [questKeys.startedBy] = {},
        },

        [11827] = {
            [questKeys.startedBy] = {},
        },

        [11828] = {
            [questKeys.startedBy] = {},
        },

        [11829] = {
            [questKeys.startedBy] = {},
        },

        [11830] = {
            [questKeys.startedBy] = {},
        },

        [11831] = {
            [questKeys.startedBy] = {},
        },

        [11832] = {
            [questKeys.startedBy] = {},
        },

        [11833] = {
            [questKeys.startedBy] = {},
        },

        [11834] = {
            [questKeys.startedBy] = {},
        },

        [11835] = {
            [questKeys.startedBy] = {},
        },

        [11836] = {
            [questKeys.startedBy] = {},
        },

        [11837] = {
            [questKeys.startedBy] = {},
        },

        [11838] = {
            [questKeys.startedBy] = {},
        },

        [11839] = {
            [questKeys.startedBy] = {},
        },

        [11840] = {
            [questKeys.startedBy] = {},
        },

        [11841] = {
            [questKeys.startedBy] = {},
        },

        [11842] = {
            [questKeys.startedBy] = {},
        },

        [11843] = {
            [questKeys.startedBy] = {},
        },

        [11844] = {
            [questKeys.startedBy] = {},
        },

        [11845] = {
            [questKeys.startedBy] = {},
        },

        [11846] = {
            [questKeys.startedBy] = {},
        },

        [11847] = {
            [questKeys.startedBy] = {},
        },

        [11848] = {
            [questKeys.startedBy] = {},
        },

        [11849] = {
            [questKeys.startedBy] = {},
        },

        [11850] = {
            [questKeys.startedBy] = {},
        },

        [11851] = {
            [questKeys.startedBy] = {},
        },

        [11852] = {
            [questKeys.startedBy] = {},
        },

        [11853] = {
            [questKeys.startedBy] = {},
        },

        [11854] = {
            [questKeys.startedBy] = {},
        },

        [11855] = {
            [questKeys.startedBy] = {},
        },

        [11856] = {
            [questKeys.startedBy] = {},
        },

        [11857] = {
            [questKeys.startedBy] = {},
        },

        [11858] = {
            [questKeys.startedBy] = {},
        },

        [11859] = {
            [questKeys.startedBy] = {},
        },

        [11860] = {
            [questKeys.startedBy] = {},
        },

        [11861] = {
            [questKeys.startedBy] = {},
        },

        [11862] = {
            [questKeys.startedBy] = {},
        },

        [11863] = {
            [questKeys.startedBy] = {},
        },

        [11886] = {
            [questKeys.startedBy] = {},
        },

        [11891] = {
            [questKeys.startedBy] = {},
        },

        [11921] = {
            [questKeys.startedBy] = {},
        },

        [11922] = {
            [questKeys.startedBy] = {},
        },

        [11923] = {
            [questKeys.startedBy] = {},
        },

        [11924] = {
            [questKeys.startedBy] = {},
        },

        [11925] = {
            [questKeys.startedBy] = {},
        },

        [11926] = {
            [questKeys.startedBy] = {},
        },

        [11954] = {
            [questKeys.startedBy] = {},
        },

        [11955] = {
            [questKeys.startedBy] = {},
        },

        [11964] = {
            [questKeys.startedBy] = {},
        },

        [11966] = {
            [questKeys.startedBy] = {},
        },

        [11970] = {
            [questKeys.startedBy] = {},
        },

        [11971] = {
            [questKeys.startedBy] = {},
        },

        [11972] = {
            [questKeys.startedBy] = {nil,nil,{35723}},
        },

        [11975] = {
            [questKeys.startedBy] = {},
        },

        [12012] = {
            [questKeys.startedBy] = {},
        },

        [12019] = {
            [questKeys.finishedBy] = {{26170}},
        },

        [12193] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12194] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12318] = {
            [questKeys.startedBy] = {{27584}},
        },

        [12484] = {
            [questKeys.startedBy] = {{26519}},
        },

        [12515] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12752] = {
            [questKeys.startedBy] = {},
        },

        [12753] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12771] = {
            [questKeys.startedBy] = {},
        },

        [12772] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12773] = {
            [questKeys.startedBy] = {},
        },

        [12774] = {
            [questKeys.startedBy] = {},
        },

        [12775] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12776] = {
            [questKeys.startedBy] = {},
        },

        [12777] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12782] = {
            [questKeys.startedBy] = {},
        },

        [12783] = {
            [questKeys.startedBy] = {},
        },

        [12784] = {
            [questKeys.startedBy] = {},
        },

        [12785] = {
            [questKeys.startedBy] = {},
        },

        [12786] = {
            [questKeys.startedBy] = {},
        },

        [12787] = {
            [questKeys.startedBy] = {},
        },

        [12788] = {
            [questKeys.startedBy] = {},
        },

        [12808] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [12809] = {
            [questKeys.startedBy] = {},
        },

        [12811] = {
            [questKeys.startedBy] = {},
        },

        [12812] = {
            [questKeys.startedBy] = {},
        },

        [12881] = {
            [questKeys.startedBy] = {},
        },

        [12944] = {
            [questKeys.startedBy] = {nil,{191880}},
            [questKeys.finishedBy] = {nil,{191880}},
        },

        [12945] = {
            [questKeys.startedBy] = {nil,{191881}},
            [questKeys.finishedBy] = {nil,{191881}},
        },

        [12946] = {
            [questKeys.startedBy] = {nil,{191882}},
            [questKeys.finishedBy] = {nil,{191882}},
        },

        [12947] = {
            [questKeys.startedBy] = {nil,{191883}},
            [questKeys.finishedBy] = {nil,{191883}},
        },

        [12954] = {
            [questKeys.finishedBy] = {{30007}},
        },

        [13191] = {
            [questKeys.finishedBy] = {{31091}},
        },

        [13200] = {
            [questKeys.finishedBy] = {{31091}},
        },

        [13267] = {
            [questKeys.finishedBy] = {{32518}},
        },

        [13317] = {
            [questKeys.startedBy] = {},
        },

        [13390] = {
            [questKeys.startedBy] = {nil,{193195}},
        },

        [13405] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13407] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13427] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13428] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13429] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13430] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13431] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13432] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13440] = {
            [questKeys.startedBy] = {},
        },

        [13441] = {
            [questKeys.startedBy] = {},
        },

        [13442] = {
            [questKeys.startedBy] = {},
        },

        [13443] = {
            [questKeys.startedBy] = {},
        },

        [13444] = {
            [questKeys.startedBy] = {},
        },

        [13445] = {
            [questKeys.startedBy] = {},
        },

        [13446] = {
            [questKeys.startedBy] = {},
        },

        [13447] = {
            [questKeys.startedBy] = {},
        },

        [13449] = {
            [questKeys.startedBy] = {},
        },

        [13450] = {
            [questKeys.startedBy] = {},
        },

        [13451] = {
            [questKeys.startedBy] = {},
        },

        [13452] = {
            [questKeys.startedBy] = {nil,{194064}},
            [questKeys.finishedBy] = {nil,{194064}},
        },

        [13453] = {
            [questKeys.startedBy] = {},
        },

        [13454] = {
            [questKeys.startedBy] = {},
        },

        [13455] = {
            [questKeys.startedBy] = {},
        },

        [13456] = {
            [questKeys.startedBy] = {nil,{194065}},
            [questKeys.finishedBy] = {nil,{194065}},
        },

        [13457] = {
            [questKeys.startedBy] = {},
        },

        [13458] = {
            [questKeys.startedBy] = {},
        },

        [13459] = {
            [questKeys.startedBy] = {nil,{194066}},
            [questKeys.finishedBy] = {nil,{194066}},
        },

        [13460] = {
            [questKeys.startedBy] = {nil,{194067}},
            [questKeys.finishedBy] = {nil,{194067}},
        },

        [13461] = {
            [questKeys.startedBy] = {nil,{194068}},
            [questKeys.finishedBy] = {nil,{194068}},
        },

        [13462] = {
            [questKeys.startedBy] = {nil,{194069}},
            [questKeys.finishedBy] = {nil,{194069}},
        },

        [13463] = {
            [questKeys.startedBy] = {nil,{194070}},
            [questKeys.finishedBy] = {nil,{194070}},
        },

        [13464] = {
            [questKeys.startedBy] = {nil,{194071}},
            [questKeys.finishedBy] = {nil,{194071}},
        },

        [13465] = {
            [questKeys.startedBy] = {nil,{194072}},
            [questKeys.finishedBy] = {nil,{194072}},
        },

        [13466] = {
            [questKeys.startedBy] = {nil,{194073}},
            [questKeys.finishedBy] = {nil,{194073}},
        },

        [13467] = {
            [questKeys.startedBy] = {nil,{194074}},
            [questKeys.finishedBy] = {nil,{194074}},
        },

        [13468] = {
            [questKeys.startedBy] = {nil,{194075}},
            [questKeys.finishedBy] = {nil,{194075}},
        },

        [13469] = {
            [questKeys.startedBy] = {nil,{194076}},
            [questKeys.finishedBy] = {nil,{194076}},
        },

        [13470] = {
            [questKeys.startedBy] = {nil,{194077}},
            [questKeys.finishedBy] = {nil,{194077}},
        },

        [13471] = {
            [questKeys.startedBy] = {nil,{194078}},
            [questKeys.finishedBy] = {nil,{194078}},
        },

        [13472] = {
            [questKeys.startedBy] = {nil,{194079}},
            [questKeys.finishedBy] = {nil,{194079}},
        },

        [13473] = {
            [questKeys.startedBy] = {nil,{194080}},
            [questKeys.finishedBy] = {nil,{194080}},
        },

        [13475] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [13476] = {
            [questKeys.startedBy] = {{115350}},
            [questKeys.finishedBy] = {{115350}},
        },

        [13477] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [13478] = {
            [questKeys.startedBy] = {{115351}},
            [questKeys.finishedBy] = {{115351}},
        },

        [13483] = {
            [questKeys.startedBy] = {},
        },

        [13484] = {
            [questKeys.startedBy] = {},
        },

        [13485] = {
            [questKeys.startedBy] = {},
        },

        [13486] = {
            [questKeys.startedBy] = {},
        },

        [13487] = {
            [questKeys.startedBy] = {},
        },

        [13488] = {
            [questKeys.startedBy] = {},
        },

        [13489] = {
            [questKeys.startedBy] = {},
        },

        [13490] = {
            [questKeys.startedBy] = {},
        },

        [13491] = {
            [questKeys.startedBy] = {},
        },

        [13492] = {
            [questKeys.startedBy] = {},
        },

        [13493] = {
            [questKeys.startedBy] = {},
        },

        [13494] = {
            [questKeys.startedBy] = {},
        },

        [13495] = {
            [questKeys.startedBy] = {},
        },

        [13496] = {
            [questKeys.startedBy] = {},
        },

        [13497] = {
            [questKeys.startedBy] = {},
        },

        [13498] = {
            [questKeys.startedBy] = {},
        },

        [13499] = {
            [questKeys.startedBy] = {},
        },

        [13500] = {
            [questKeys.startedBy] = {},
        },

        [13820] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13825] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13826] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13843] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [13926] = {
            [questKeys.startedBy] = {},
        },

        [13927] = {
            [questKeys.startedBy] = {},
        },

        [13929] = {
            [questKeys.startedBy] = {},
        },

        [13930] = {
            [questKeys.startedBy] = {},
        },

        [13933] = {
            [questKeys.startedBy] = {},
        },

        [13934] = {
            [questKeys.startedBy] = {},
        },

        [13937] = {
            [questKeys.startedBy] = {},
        },

        [13950] = {
            [questKeys.startedBy] = {},
        },

        [13951] = {
            [questKeys.startedBy] = {},
        },

        [13954] = {
            [questKeys.startedBy] = {},
        },

        [13955] = {
            [questKeys.startedBy] = {},
        },

        [13956] = {
            [questKeys.startedBy] = {},
        },

        [13957] = {
            [questKeys.startedBy] = {},
        },

        [13959] = {
            [questKeys.startedBy] = {},
        },

        [13960] = {
            [questKeys.startedBy] = {},
        },

        [13966] = {
            [questKeys.startedBy] = {nil, nil, {46740}},
        },

        [14022] = {
            [questKeys.startedBy] = {},
        },

        [14036] = {
            [questKeys.startedBy] = {},
        },

        [14037] = {
            [questKeys.startedBy] = {{34768}},
        },

        [14103] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14163] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14164] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14178] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14179] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14180] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14181] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14182] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14183] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14351] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {{2425,36273}},
        },

        [14352] = {
            [questKeys.finishedBy] = {{2425,36273}},
        },

        [14353] = {
            [questKeys.finishedBy] = {{2425,36273}},
        },

        [14355] = {
            [questKeys.finishedBy] = {{2425,36273}},
        },

        [14356] = {
            [questKeys.finishedBy] = {{2425,36273}},
        },

        [14418] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14419] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14420] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [14421] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24216] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24217] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24218] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24219] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24220] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24221] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24223] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24224] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24225] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24226] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24426] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [24427] = {
            [questKeys.startedBy] = {},
        },

        [24800] = {
            [questKeys.finishedBy] = {{30116}},
        },

        [24801] = {
            [questKeys.finishedBy] = {{30116}},
        },

        [24819] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24820] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24821] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24822] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24836] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24837] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24838] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24839] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24840] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24841] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24842] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24843] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24844] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24845] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24846] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24847] = {
            [questKeys.startedBy] = {{39509}},
            [questKeys.finishedBy] = {{39509}},
        },

        [24874] = {
            [questKeys.finishedBy] = {{38551}},
        },

        [24879] = {
            [questKeys.finishedBy] = {{38551}},
        },

        [25229] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25285] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25287] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25289] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25295] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25393] = {
            [questKeys.startedBy] = {},
            [questKeys.finishedBy] = {},
        },

        [25444] = {
            [questKeys.startedBy] = {},
        },

        [25445] = {
            [questKeys.startedBy] = {},
        },

        [25446] = {
            [questKeys.startedBy] = {},
        },

        [25461] = {
            [questKeys.startedBy] = {},
        },

        [25470] = {
            [questKeys.startedBy] = {},
        },

        [25480] = {
            [questKeys.startedBy] = {},
        },

        [25495] = {
            [questKeys.startedBy] = {},
        },
    }

    -- AzerothCore quest metadata parity.
    local metadataCorrections = {
        -- REVIEW BEFORE APPLYING.
        -- Generated from AzerothCore quest_template and quest_template_addon metadata.
        -- This fragment should be wrapped by the metadata generator into a QuestieCompat.RegisterCorrection module.

        [1] = {
            [questKeys.objectives] = {{{20000}}},
            [questKeys.preQuestSingle] = {13929,13933,13950},
        },

        [2] = {
            [questKeys.objectives] = {nil,nil,{{16305}}},
        },

        [5] = {
            [questKeys.preQuestSingle] = {163},
        },

        [6] = {
            [questKeys.questFlags] = 8,
        },

        [7] = {
            [questKeys.objectivesText] = {"Kill 10 Kobold Vermin, then return to Marshal McBride."},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.questFlags] = 8,
        },

        [8] = {
            [questKeys.objectives] = {nil,nil,{{7628}}},
            [questKeys.questFlags] = 0,
        },

        [11] = {
            [questKeys.preQuestSingle] = {239},
        },

        [15] = {
            [questKeys.objectivesText] = {"Kill 10 Kobold Workers, then report back to Marshal McBride."},
            [questKeys.questFlags] = 8,
        },

        [18] = {
            [questKeys.objectivesText] = {"Bring 12 Red Burlap Bandanas to Deputy Willem outside the Northshire Abbey."},
            [questKeys.questFlags] = 8,
        },

        [21] = {
            [questKeys.objectivesText] = {"Kill 12 Kobold Laborers, then return to Marshal McBride at Northshire Abbey."},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.questFlags] = 8,
        },

        [23] = {
            [questKeys.objectives] = {nil,nil,{{16303}}},
        },

        [24] = {
            [questKeys.objectives] = {nil,nil,{{16304}}},
        },

        [28] = {
            [questKeys.objectivesText] = {"Find a Shrine Bauble in Lake Elune'ara, and take it to the Shrine of Remulos in northwestern Moonglade.  Once there, use the Shrine Bauble.","","You must speak with Tajarri at the shrine afterwards in order to complete the trial."},
            [questKeys.objectives] = nil,
            [questKeys.specialFlags] = 34,
        },

        [29] = {
            [questKeys.objectivesText] = {"Find a Shrine Bauble in Lake Elune'ara, and take it to the Shrine of Remulos in northwestern Moonglade.  Once there, use the Shrine Bauble.","","You must speak with Tajarri at the shrine afterwards in order to complete the trial."},
            [questKeys.objectives] = nil,
            [questKeys.specialFlags] = 34,
        },

        [30] = {
            [questKeys.objectivesText] = {"Find the Half Pendant of Aquatic Agility and the Half Pendant of Aquatic Endurance.  Speak with the residents of Moonglade to learn clues as to where these items may be located.","","Form the Pendant of the Sea Lion from the two pendant halves.  You need to be in proximity of the Shrine of Remulos to do this.","","Bring the joined pendant to Dendrite Starblaze in the village of Nighthaven, Moonglade."},
        },

        [31] = {
            [questKeys.objectives] = {nil,nil,{{15885}}},
        },

        [32] = {
            [questKeys.objectives] = {nil,nil,{{8594}}},
        },

        [33] = {
            [questKeys.objectivesText] = {"Bring 8 pieces of Tough Wolf Meat to Eagan Peltskinner outside Northshire Abbey."},
            [questKeys.objectives] = {nil,nil,{{750}}},
            [questKeys.questFlags] = 8,
        },

        [34] = {
            [questKeys.objectivesText] = {"Martie Jainrose of Lakeshire wants you to kill Bellygrub.  Bring her his tusk as proof."},
        },

        [36] = {
            [questKeys.objectives] = {nil,nil,{{2832}}},
        },

        [46] = {
            [questKeys.preQuestSingle] = {},
        },

        [47] = {
            [questKeys.objectivesText] = {"Bring 10 Gold Dust to Remy \"Two Times\" in Goldshire.  Gold Dust is gathered from Kobolds in Elwynn Forest."},
        },

        [54] = {
            [questKeys.objectives] = {nil,nil,{{745}}},
            [questKeys.questFlags] = 0,
        },

        [55] = {
            [questKeys.objectives] = {{{24782}},nil,{{7297}}},
        },

        [59] = {
            [questKeys.objectives] = {nil,nil,{{748}}},
        },

        [61] = {
            [questKeys.objectives] = {nil,nil,{{957}}},
        },

        [63] = {
            [questKeys.objectives] = {nil,nil,{{7812},{7811}}},
            [questKeys.requiredSourceItems] = {},
        },

        [68] = {
            [questKeys.objectives] = {nil,nil,{{889}}},
        },

        [71] = {
            [questKeys.objectives] = {nil,nil,{{735}}},
        },

        [73] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [74] = {
            [questKeys.objectives] = {nil,nil,{{916}}},
        },

        [76] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [77] = {
            [questKeys.requiredRaces] = 0,
        },

        [78] = {
            [questKeys.objectives] = {nil,nil,{{921}}},
        },

        [79] = {
            [questKeys.objectives] = {nil,nil,{{938}}},
        },

        [80] = {
            [questKeys.objectives] = {nil,nil,{{939}}},
        },

        [81] = {
            [questKeys.objectives] = {nil,nil,{{8685}}},
        },

        [84] = {
            [questKeys.objectives] = {nil,nil,{{962}}},
        },

        [90] = {
            [questKeys.requiredSkill] = {},
        },

        [94] = {
            [questKeys.objectives] = {nil,nil,{{1083}}},
        },

        [96] = {
            [questKeys.objectivesText] = {"Bring the Shard of Water to Islen Waterseer in the Barrens."},
            [questKeys.objectives] = {nil,nil,{{7813}}},
        },

        [98] = {
            [questKeys.questLevel] = 35,
        },

        [100] = {
            [questKeys.objectivesText] = {"Speak to the Minor Manifestation of Water in Silverpine Forest."},
        },

        [106] = {
            [questKeys.objectives] = {nil,nil,{{1208}}},
        },

        [107] = {
            [questKeys.objectives] = {nil,nil,{{1252}}},
        },

        [108] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [109] = {
            [questKeys.objectivesText] = {"Talk to Gryan Stoutmantle.  He usually can be found in the stone tower on Sentinel Hill, just off the road, in the middle of Westfall."},
        },

        [112] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [113] = {
            [questKeys.objectivesText] = {"Deliver the report to Senior Surveyor Fizzledowser in Gadgetzan.  Be sure he gives you a copy of the report, as Alchemist Pestlezugg has requested."},
            [questKeys.objectives] = {nil,nil,{{8594}}},
        },

        [114] = {
            [questKeys.objectives] = {nil,nil,{{1257}}},
        },

        [118] = {
            [questKeys.objectives] = {nil,nil,{{1283}}},
        },

        [119] = {
            [questKeys.objectivesText] = {"Return to Verner Osgood at Lakeshire in Redridge.  Give him the Crate of Horseshoes."},
            [questKeys.objectives] = {nil,nil,{{1284}}},
        },

        [120] = {
            [questKeys.objectivesText] = {"Magistrate Solomon has given you a report which must be delivered to General Marcus Jonathan in Stormwind.  The judge wants you to return to him as soon as the delivery has been made."},
            [questKeys.objectives] = {nil,nil,{{1293}}},
        },

        [121] = {
            [questKeys.objectives] = {nil,nil,{{1294}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [123] = {
            [questKeys.objectives] = {nil,nil,{{2223}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [125] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [126] = {
            [questKeys.questLevel] = 25,
        },

        [129] = {
            [questKeys.objectivesText] = {"Bring Parker's lunch to Guard Parker.  He patrols the road leading to Darkshire."},
            [questKeys.objectives] = {nil,nil,{{5534}}},
        },

        [131] = {
            [questKeys.objectives] = {nil,nil,{{1325}}},
        },

        [132] = {
            [questKeys.objectives] = {nil,nil,{{1327}}},
        },

        [135] = {
            [questKeys.objectives] = {nil,nil,{{1327}}},
        },

        [137] = {
            [questKeys.questLevel] = 8,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"General Marcus Jonathan in Stormwind will accept a commendation from Elwynn Forest.  Bringing him such a document will reward you with a choice of armor."},
            [questKeys.objectives] = {nil,nil,{{1356}}},
            [questKeys.questFlags] = 8,
        },

        [141] = {
            [questKeys.objectives] = {nil,nil,{{1353}}},
        },

        [142] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [143] = {
            [questKeys.objectives] = {nil,nil,{{1407}}},
        },

        [144] = {
            [questKeys.objectives] = {nil,nil,{{1408}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [145] = {
            [questKeys.objectives] = {nil,nil,{{1409}}},
        },

        [146] = {
            [questKeys.objectives] = {nil,nil,{{1410}}},
        },

        [147] = {
            [questKeys.objectivesText] = {"Find and kill \"the Collector\"  then return to Marshal Dughan with The Collector's Ring."},
        },

        [148] = {
            [questKeys.preQuestSingle] = {165},
        },

        [149] = {
            [questKeys.objectives] = {nil,nil,{{1453}}},
        },

        [154] = {
            [questKeys.objectives] = {nil,nil,{{1518}}},
        },

        [155] = {
            [questKeys.objectivesText] = {"Escort the Defias Traitor to the secret hideout of the Defias Brotherhood.  Once the Defias Traitor shows you where VanCleef and his men are hiding out, return to Gryan Stoutmantle with the information."},
        },

        [157] = {
            [questKeys.objectives] = {nil,nil,{{1596}}},
        },

        [159] = {
            [questKeys.objectives] = {nil,nil,{{1451}}},
        },

        [160] = {
            [questKeys.objectives] = {nil,nil,{{1637}}},
        },

        [161] = {
            [questKeys.objectives] = {nil,nil,{{2563}}},
        },

        [162] = {
            [questKeys.objectives] = {nil,nil,{{8594}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [163] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [164] = {
            [questKeys.objectives] = {nil,nil,{{1922}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [165] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [169] = {
            [questKeys.requiredLevel] = 15,
        },

        [170] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [171] = {
            [questKeys.preQuestSingle] = {558},
        },

        [178] = {
            [questKeys.objectivesText] = {"Bring the Faded Shadowhide Pendant to Theocritus the Mage at the Tower of Azora in Elwynn Forest."},
            [questKeys.objectives] = {nil,nil,{{1956}}},
        },

        [179] = {
            [questKeys.specialFlags] = 4,
        },

        [180] = {
            [questKeys.requiredLevel] = 15,
        },

        [182] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [183] = {
            [questKeys.objectivesText] = {"Talin Keeneye would like you to kill 12 Small Crag Boars."},
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [184] = {
            [questKeys.objectives] = {nil,nil,{{1971}}},
        },

        [198] = {
            [questKeys.objectives] = {nil,nil,{{2252}}},
        },

        [199] = {
            [questKeys.objectives] = {nil,nil,{{2563}}},
        },

        [206] = {
            [questKeys.preQuestSingle] = {205},
        },

        [207] = {
            [questKeys.preQuestSingle] = {204},
        },

        [208] = {
            [questKeys.preQuestSingle] = {188,193,197},
        },

        [210] = {
            [questKeys.objectives] = {nil,nil,{{4085}}},
        },

        [212] = {
            [questKeys.objectivesText] = {"Kill a Cold Eye Basilisk, get a Chilled Basilisk Haunch, and return it to Angus Stern in the Blue Recluse.","","<You must not release your spirit to succeed in this quest.>"},
            [questKeys.questFlags] = 9,
        },

        [216] = {
            [questKeys.objectivesText] = {"Take down 12 Thistlefur Avengers and 12 Thistlefur Shaman; most are located east of Zoram Strand in Thistlefur Village.  Once completed, return to Karang Amakkar at Zoram'gar Outpost, Ashenvale."},
        },

        [217] = {
            [questKeys.preQuestSingle] = {263},
        },

        [218] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [220] = {
            [questKeys.objectivesText] = {"Bring the Vial of Purest Water to Islen Waterseer in the Barrens."},
            [questKeys.objectives] = {nil,nil,{{7810}}},
        },

        [223] = {
            [questKeys.objectives] = {nil,nil,{{2113}}},
        },

        [224] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [225] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 28,
        },

        [227] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 28,
        },

        [228] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 28,
        },

        [229] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 28,
        },

        [230] = {
            [questKeys.objectives] = {nil,nil,{{2161}}},
        },

        [231] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 28,
            [questKeys.objectives] = {nil,nil,{{2162}}},
        },

        [232] = {
            [questKeys.objectives] = {nil,nil,{{8525}}},
        },

        [233] = {
            [questKeys.objectives] = {nil,nil,{{2187}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [234] = {
            [questKeys.objectives] = {nil,nil,{{2188}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [235] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [236] = {
            [questKeys.exclusiveTo] = {13197},
        },

        [237] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [238] = {
            [questKeys.objectives] = {nil,nil,{{8523}}},
        },

        [240] = {
            [questKeys.objectives] = {nil,nil,{{2250}}},
        },

        [241] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Log"},
        },

        [242] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 25,
            [questKeys.objectivesText] = {"Kill 8 Dragonmaw Raiders,3 Dragonmaw Bonewarders,and a Dragonmaw Battlemaster."},
            [questKeys.objectives] = {{{1034},{1057},{1037}}},
            [questKeys.questFlags] = 8,
        },

        [247] = {
            [questKeys.preQuestSingle] = {2,23,24},
        },

        [248] = {
            [questKeys.objectives] = {nil,nil,{{1083}}},
        },

        [249] = {
            [questKeys.questLevel] = 27,
        },

        [251] = {
            [questKeys.objectives] = {nil,nil,{{1637}}},
        },

        [252] = {
            [questKeys.objectives] = {nil,nil,{{1656}}},
        },

        [253] = {
            [questKeys.objectivesText] = {"Find Eliza's grave.  Retrieve the Embalmer's Heart from her, then return to Ello Ebonlocke."},
        },

        [254] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [256] = {
            [questKeys.requiredLevel] = 17,
        },

        [258] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [259] = {
            [questKeys.objectivesText] = {"Talk to Kelt Thomasin."},
            [questKeys.nextQuestInChain] = 260,
            [questKeys.questFlags] = 8,
        },

        [260] = {
            [questKeys.questLevel] = 20,
            [questKeys.requiredLevel] = 15,
            [questKeys.objectivesText] = {"Collect 5 Threshadon Teeth and 5 Threshadon Claws, then bring them to Kelt Thomasin."},
            [questKeys.objectives] = {nil,nil,{{2668},{2669}}},
            [questKeys.questFlags] = 8,
        },

        [262] = {
            [questKeys.objectives] = {nil,nil,{{2161}}},
        },

        [263] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [264] = {
            [questKeys.objectives] = {nil,nil,{{6145}}},
        },

        [265] = {
            [questKeys.objectives] = {nil,nil,{{2161}}},
        },

        [266] = {
            [questKeys.objectives] = {nil,nil,{{2161}}},
        },

        [268] = {
            [questKeys.objectives] = {nil,nil,{{2560}}},
        },

        [269] = {
            [questKeys.objectives] = {nil,nil,{{2560}}},
        },

        [272] = {
            [questKeys.objectivesText] = {"Find the Half Pendant of Aquatic Agility and the Half Pendant of Aquatic Endurance.  Speak with the residents of Moonglade to learn clues as to where these items may be located.","","Form the Pendant of the Sea Lion from the two pendant halves.  You need to be in proximity of the Shrine of Remulos to do this.","","Bring the joined pendant to Dendrite Starblaze in the village of Nighthaven, Moonglade."},
        },

        [274] = {
            [questKeys.objectives] = {nil,nil,{{2609}}},
        },

        [275] = {
            [questKeys.objectivesText] = {"Kill 12 Fen Creepers, then return to Rethiel the Greenwarden in the Wetlands."},
        },

        [280] = {
            [questKeys.objectives] = {nil,nil,{{2610}}},
        },

        [282] = {
            [questKeys.objectives] = {nil,nil,{{2619}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [283] = {
            [questKeys.objectivesText] = {"The Disarming Mixture seemed to take effect.  Return to Chief Engineer Hinderweir to report the good news."},
        },

        [286] = {
            [questKeys.objectives] = {nil,nil,{{2625}}},
        },

        [287] = {
            [questKeys.preQuestSingle] = {420},
        },

        [289] = {
            [questKeys.objectivesText] = {"Kill 13 Cursed Sailors, 5 Cursed Marines and First Mate Snellig.  Bring Snellig's Snuffbox to First Mate Fitzsimmons in Menethil Harbor."},
        },

        [291] = {
            [questKeys.objectives] = {nil,nil,{{2628}}},
        },

        [292] = {
            [questKeys.objectives] = {nil,nil,{{2944}}},
        },

        [293] = {
            [questKeys.objectivesText] = {"Bring Archbishop Benedictus the Cursed Eye of Paleth.  Benedictus is in the Cathedral of Light, in the city of Stormwind."},
            [questKeys.objectives] = {nil,nil,{{2944}}},
        },

        [297] = {
            [questKeys.preQuestSingle] = {436},
        },

        [298] = {
            [questKeys.objectives] = {nil,nil,{{2637}}},
        },

        [301] = {
            [questKeys.objectives] = {nil,nil,{{2637}}},
        },

        [303] = {
            [questKeys.objectivesText] = {"Motley Garmason at Dun Modr wants you to kill 15 Dark Iron Dwarves,  5 Dark Iron Tunnelers, 5 Dark Iron Saboteurs and 5 Dark Iron Demolitionists."},
        },

        [304] = {
            [questKeys.questLevel] = 34,
        },

        [306] = {
            [questKeys.objectives] = {nil,nil,{{2639}}},
        },

        [310] = {
            [questKeys.objectives] = {nil,nil,{{2548}}},
        },

        [311] = {
            [questKeys.objectives] = {nil,nil,{{2666}}},
        },

        [315] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [316] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{2688}}},
            [questKeys.questFlags] = 8,
        },

        [320] = {
            [questKeys.objectives] = {nil,nil,{{2696}}},
        },

        [322] = {
            [questKeys.objectives] = {nil,nil,{{2712}}},
        },

        [325] = {
            [questKeys.objectives] = {nil,nil,{{7297}}},
        },

        [326] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 50,
            [questKeys.objectivesText] = {"x"},
            [questKeys.objectives] = {nil,nil,{{17114}}},
            [questKeys.questFlags] = 8,
        },

        [327] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [328] = {
            [questKeys.objectives] = {nil,nil,{{2719}}},
        },

        [329] = {
            [questKeys.objectives] = {nil,nil,{{2720}}},
        },

        [332] = {
            [questKeys.objectives] = {nil,nil,{{2722}}},
        },

        [333] = {
            [questKeys.objectives] = {nil,nil,{{2724}}},
        },

        [334] = {
            [questKeys.objectives] = {nil,nil,{{2760}}},
        },

        [336] = {
            [questKeys.objectives] = {nil,nil,{{2788}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [337] = {
            [questKeys.objectives] = {nil,nil,{{2794}}},
        },

        [338] = {
            [questKeys.objectivesText] = {"Collect the missing pages from The Green Hills of Stranglethorn manuscript.  Once all four chapters are complete, return them to Barnil."},
        },

        [343] = {
            [questKeys.objectivesText] = {"Go to the Royal Library in Stormwind Keep and speak with Milton Sheaf.  He can find for you the book on metallurgy that Brother Kristoff needs for his speech."},
        },

        [346] = {
            [questKeys.objectivesText] = {"Return to Brother Kristoff in the Cathedral Square.  Give him the book The Stresses of Iron."},
            [questKeys.objectives] = {nil,nil,{{2795}}},
        },

        [348] = {
            [questKeys.objectivesText] = {"Seek out Witch Doctor Unbagwa and have him summon Mokk the Savage.  Bring the Heart of Mokk to Fin Fizracket."},
        },

        [349] = {
            [questKeys.objectivesText] = {"temp text 02 - log"},
        },

        [351] = {
            [questKeys.objectives] = {nil,nil,{{8623}}},
        },

        [352] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [353] = {
            [questKeys.objectives] = {nil,nil,{{2806}}},
        },

        [355] = {
            [questKeys.preQuestSingle] = {354},
        },

        [358] = {
            [questKeys.objectivesText] = {"Kill Rot Hide Graverobbers and Rot Hide Mongrels.  ","","Bring 8 Embalming Ichors to Magistrate Sevren in Brill."},
        },

        [361] = {
            [questKeys.objectives] = {nil,nil,{{2837}}},
        },

        [363] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 8,
        },

        [364] = {
            [questKeys.objectivesText] = {"Shadow Priest Sarvis wants you to kill 8 Mindless Zombies and 8 Wretched Zombies."},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 8,
        },

        [366] = {
            [questKeys.objectives] = {nil,nil,{{3016}}},
        },

        [373] = {
            [questKeys.objectives] = {nil,nil,{{2874}}},
        },

        [376] = {
            [questKeys.questFlags] = 8,
        },

        [380] = {
            [questKeys.objectivesText] = {"Executor Arren wants you to kill 10 Young Night Web Spiders and 8 Night Web Spiders."},
            [questKeys.questFlags] = 8,
        },

        [381] = {
            [questKeys.questFlags] = 8,
        },

        [382] = {
            [questKeys.questFlags] = 8,
        },

        [383] = {
            [questKeys.objectives] = {nil,nil,{{2885}}},
            [questKeys.questFlags] = 0,
        },

        [384] = {
            [questKeys.requiredSkill] = {185,1},
            [questKeys.questFlags] = 8,
        },

        [390] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [392] = {
            [questKeys.objectives] = {nil,nil,{{8687}}},
        },

        [393] = {
            [questKeys.objectives] = {nil,nil,{{8687}}},
        },

        [396] = {
            [questKeys.objectives] = {nil,nil,{{2956}}},
        },

        [398] = {
            [questKeys.requiredLevel] = 6,
        },

        [400] = {
            [questKeys.objectives] = {nil,nil,{{2999}}},
        },

        [403] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.specialFlags] = 0,
        },

        [405] = {
            [questKeys.objectives] = {nil,nil,{{3017}}},
        },

        [406] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [407] = {
            [questKeys.objectives] = {nil,nil,{{3035}}},
        },

        [409] = {
            [questKeys.requiredSourceItems] = {},
        },

        [410] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [411] = {
            [questKeys.objectives] = {nil,nil,{{3081}}},
        },

        [413] = {
            [questKeys.objectives] = {nil,nil,{{3085}}},
        },

        [414] = {
            [questKeys.objectives] = {nil,nil,{{3086}}},
        },

        [417] = {
            [questKeys.objectives] = {nil,nil,{{3183},{3117}}},
        },

        [420] = {
            [questKeys.objectives] = {nil,nil,{{2619}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [430] = {
            [questKeys.objectives] = {nil,nil,{{3165}}},
        },

        [431] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [439] = {
            [questKeys.objectives] = {nil,nil,{{3234}}},
        },

        [440] = {
            [questKeys.objectives] = {nil,nil,{{3234}}},
        },

        [441] = {
            [questKeys.objectives] = {nil,nil,{{3234}}},
        },

        [442] = {
            [questKeys.questLevel] = 24,
        },

        [443] = {
            [questKeys.preQuestSingle] = {438},
        },

        [444] = {
            [questKeys.objectives] = {nil,nil,{{3237}}},
        },

        [445] = {
            [questKeys.objectives] = {nil,nil,{{3238}}},
        },

        [446] = {
            [questKeys.objectives] = {nil,nil,{{3250}}},
        },

        [449] = {
            [questKeys.objectives] = {nil,nil,{{3252}}},
        },

        [452] = {
            [questKeys.requiredRaces] = 0,
        },

        [453] = {
            [questKeys.objectivesText] = {"Find the Shadowy Figure.  Your clues:","","He is not native to Darkshire.","","He is a nervous, jittery person.","","He left Darkshire and headed west."},
            [questKeys.objectives] = {nil,nil,{{2161}}},
        },

        [456] = {
            [questKeys.objectivesText] = {"Kill 7 Young Nightsabers and 7 Young Thistle Boars and return to Conservator Ilthalaine."},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 4,
        },

        [457] = {
            [questKeys.objectivesText] = {"Conservator Ilthalaine needs you to kill 7 Mangy Nightsabers and 7 Thistle Boars."},
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [458] = {
            [questKeys.specialFlags] = 4,
        },

        [459] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [460] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{3317}}},
        },

        [461] = {
            [questKeys.objectives] = {nil,nil,{{3318}}},
        },

        [462] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Kill Maruk Wyrmscale","","Report to Valstag Ironjaw in Menethil Harbor."},
            [questKeys.objectives] = {{{2090}}},
            [questKeys.questFlags] = 8,
        },

        [464] = {
            [questKeys.questLevel] = 28,
            [questKeys.preQuestSingle] = {473},
            [questKeys.breadcrumbs] = {},
        },

        [465] = {
            [questKeys.questLevel] = 31,
            [questKeys.objectives] = {nil,nil,{{3339}}},
        },

        [466] = {
            [questKeys.preQuestSingle] = {467},
        },

        [469] = {
            [questKeys.objectives] = {nil,nil,{{3347}}},
        },

        [473] = {
            [questKeys.questLevel] = 28,
            [questKeys.preQuestSingle] = {},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [474] = {
            [questKeys.questLevel] = 32,
        },

        [478] = {
            [questKeys.objectives] = {nil,nil,{{3353}}},
        },

        [481] = {
            [questKeys.objectives] = {nil,nil,{{3353}}},
        },

        [484] = {
            [questKeys.requiredMinRep] = false,
        },

        [485] = {
            [questKeys.objectives] = {nil,nil,{{8704}}},
        },

        [490] = {
            [questKeys.questLevel] = 7,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Shayla Nightbreeze outside of Darnassus wants you to bring her 20 Gnarlpine Fangs."},
            [questKeys.objectives] = {nil,nil,{{5220}}},
            [questKeys.questFlags] = 8,
        },

        [491] = {
            [questKeys.objectives] = {nil,nil,{{3425}}},
        },

        [492] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{3460}}},
        },

        [493] = {
            [questKeys.objectives] = {nil,nil,{{3468}}},
        },

        [497] = {
            [questKeys.questLevel] = 22,
            [questKeys.requiredLevel] = 19,
            [questKeys.objectivesText] = {"Go to Tarren Mill and find out the status of the party sent by Thrall."},
            [questKeys.questFlags] = 8,
        },

        [498] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [499] = {
            [questKeys.objectives] = {nil,nil,{{3495}}},
        },

        [500] = {
            [questKeys.objectivesText] = {"Gather 9 Dirty Knucklebones from Crushridge ogres in the Alterac Mountains.  Bring them to Marshal Redpath in Southshore."},
        },

        [502] = {
            [questKeys.objectives] = {nil,nil,{{3497}}},
        },

        [503] = {
            [questKeys.objectives] = {nil,nil,{{3704}}},
        },

        [504] = {
            [questKeys.objectivesText] = {"Slay 15 Crushridge Warmongers, then return to Marshal Redpath in Southshore."},
        },

        [507] = {
            [questKeys.questFlags] = 8,
        },

        [508] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{3498}}},
        },

        [510] = {
            [questKeys.objectives] = {nil,nil,{{3718}}},
        },

        [511] = {
            [questKeys.objectives] = {nil,nil,{{3521}}},
        },

        [513] = {
            [questKeys.objectives] = {nil,nil,{{3506}}},
        },

        [514] = {
            [questKeys.objectives] = {nil,nil,{{3521}}},
        },

        [515] = {
            [questKeys.objectives] = {nil,nil,{{3508},{3388},{3509},{3510}}},
        },

        [518] = {
            [questKeys.objectivesText] = {"Kill 14 Crushridge Maulers for Melisara in Tarren Mill."},
        },

        [521] = {
            [questKeys.objectives] = {nil,nil,{{3554}}},
        },

        [522] = {
            [questKeys.objectives] = {nil,nil,{{3668}}},
        },

        [524] = {
            [questKeys.objectives] = {nil,nil,{{3520}}},
        },

        [525] = {
            [questKeys.objectives] = {nil,nil,{{3518}}},
        },

        [526] = {
            [questKeys.exclusiveTo] = {},
        },

        [529] = {
            [questKeys.objectivesText] = {"Kill Blacksmith Verringtan and 4 Hillsbrad Apprentice Blacksmiths.$b$bRetrieve a shipment of iron and report back to Darthalia in Tarren Mill."},
        },

        [531] = {
            [questKeys.objectives] = {nil,nil,{{2713}}},
        },

        [532] = {
            [questKeys.objectivesText] = {"Kill Magistrate Burnside and 5 Hillsbrad Councilmen.  Destroy the Hillsbrad Proclamation.  Steal the Hillsbrad Town Registry.  Report back to Darthalia in Tarren Mill afterwards."},
            [questKeys.specialFlags] = 32,
        },

        [533] = {
            [questKeys.preQuestSingle] = {},
        },

        [534] = {
            [questKeys.questLevel] = 34,
            [questKeys.requiredLevel] = 29,
            [questKeys.questFlags] = 8,
        },

        [535] = {
            [questKeys.parentQuest] = 0,
        },

        [541] = {
            [questKeys.objectivesText] = {"Travel to Dun Garok and kill 10 Mountaineers, 4 Riflemen, 2 Priests and Captain Ironhill and report back to Darthalia in Tarren Mill."},
            [questKeys.nextQuestInChain] = 550,
        },

        [542] = {
            [questKeys.objectives] = {nil,nil,{{3660}}},
        },

        [548] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 20,
            [questKeys.questFlags] = 8,
        },

        [549] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [550] = {
            [questKeys.objectivesText] = {"Take Darthalia's Sealed Commendation to Varimathras in the Undercity."},
            [questKeys.objectives] = {nil,nil,{{3701}}},
            [questKeys.preQuestSingle] = {541},
        },

        [551] = {
            [questKeys.objectives] = {nil,nil,{{3706}}},
        },

        [553] = {
            [questKeys.objectivesText] = {"Charge the Rod of Helcular with the powers of the Flame of Azel, Flame of Veraz and the Flame of Uzel.$b$bDrive the charged rod into Helcular's grave in Southshore."},
            [questKeys.objectives] = {nil,{{1768},{1769},{1770}},{{3710}}},
            [questKeys.specialFlags] = 32,
        },

        [554] = {
            [questKeys.objectives] = {nil,nil,{{3706}}},
        },

        [555] = {
            [questKeys.objectives] = {nil,nil,{{3712},{3713}}},
        },

        [558] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {1479},
        },

        [560] = {
            [questKeys.objectives] = {nil,nil,{{3717}}},
        },

        [563] = {
            [questKeys.objectives] = {nil,nil,{{3721}}},
        },

        [566] = {
            [questKeys.requiredLevel] = 35,
            [questKeys.preQuestSingle] = {},
        },

        [567] = {
            [questKeys.requiredLevel] = 19,
        },

        [573] = {
            [questKeys.objectivesText] = {"Far Seer Mok'thardin of Grom'gol needs Holy Spring Water.  He also wants you to kill 10 Naga Explorers."},
        },

        [574] = {
            [questKeys.preQuestSingle] = {203,204},
        },

        [575] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [576] = {
            [questKeys.preQuestSingle] = {595},
        },

        [587] = {
            [questKeys.preQuestSingle] = {595},
        },

        [588] = {
            [questKeys.preQuestSingle] = {585,586},
        },

        [594] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 45,
        },

        [598] = {
            [questKeys.preQuestSingle] = {596},
        },

        [602] = {
            [questKeys.objectives] = {nil,nil,{{3960}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [604] = {
            [questKeys.questLevel] = 43,
        },

        [607] = {
            [questKeys.objectives] = {nil,nil,{{3922}}},
        },

        [608] = {
            [questKeys.questLevel] = 45,
        },

        [611] = {
            [questKeys.objectives] = {nil,nil,{{4034},{4027}}},
        },

        [612] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 32,
            [questKeys.objectivesText] = {"Return Catelyn's blade."},
            [questKeys.objectives] = {nil,nil,{{4027}}},
            [questKeys.questFlags] = 8,
        },

        [614] = {
            [questKeys.questLevel] = 47,
        },

        [615] = {
            [questKeys.questLevel] = 50,
        },

        [618] = {
            [questKeys.questLevel] = 50,
        },

        [619] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 1,
            [questKeys.parentQuest] = 0,
        },

        [620] = {
            [questKeys.objectives] = {nil,nil,{{3985}}},
        },

        [622] = {
            [questKeys.objectives] = {nil,nil,{{1987}}},
        },

        [623] = {
            [questKeys.objectives] = {nil,nil,{{4028}}},
        },

        [630] = {
            [questKeys.questLevel] = 51,
            [questKeys.requiredLevel] = 45,
        },

        [632] = {
            [questKeys.objectives] = {nil,nil,{{4429}}},
        },

        [637] = {
            [questKeys.objectives] = {nil,nil,{{4432}}},
        },

        [639] = {
            [questKeys.preQuestSingle] = {638},
        },

        [641] = {
            [questKeys.objectives] = {nil,nil,{{4453}}},
        },

        [645] = {
            [questKeys.objectives] = {nil,nil,{{4467}}},
        },

        [646] = {
            [questKeys.objectives] = {nil,nil,{{4468}}},
        },

        [647] = {
            [questKeys.objectives] = {nil,nil,{{4441}}},
        },

        [652] = {
            [questKeys.objectivesText] = {"Find and kill Fozruk.  Bring the Rod of Order to the Keystone in the Arathi Highlands."},
        },

        [654] = {
            [questKeys.objectivesText] = {"Acquire untested samples for 8 basilisks, 8 hyenas, and 8 scorpions.  Bring the testing kit back to Chief Engineer Bilgewhizzle in Gadgetzan before the power source runs out."},
            [questKeys.objectives] = {nil,nil,{{9440},{9441},{9438},{8523}}},
            [questKeys.requiredSourceItems] = {9437,9439,9442},
        },

        [666] = {
            [questKeys.objectives] = {nil,nil,{{4492},{4491}}},
        },

        [668] = {
            [questKeys.objectives] = {nil,nil,{{4493}}},
        },

        [669] = {
            [questKeys.objectives] = {nil,nil,{{4502}}},
        },

        [670] = {
            [questKeys.objectives] = {nil,nil,{{4494}}},
        },

        [674] = {
            [questKeys.objectives] = {nil,nil,{{4526}}},
        },

        [676] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [677] = {
            [questKeys.preQuestSingle] = {676},
            [questKeys.breadcrumbs] = {},
        },

        [679] = {
            [questKeys.objectivesText] = {"Kill 15 Boulderfist Shaman and 3 Boulderfist Lords and return to Drum Fel in the Hammerfall outpost."},
        },

        [680] = {
            [questKeys.preQuestSingle] = {},
        },

        [682] = {
            [questKeys.objectivesText] = {"Bring 15 Stromgarde Badges to Captain Nials at Refuge Pointe."},
        },

        [683] = {
            [questKeys.objectives] = {nil,nil,{{4514}}},
        },

        [684] = {
            [questKeys.requiredLevel] = 30,
        },

        [685] = {
            [questKeys.requiredLevel] = 30,
        },

        [690] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [691] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [692] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [693] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [697] = {
            [questKeys.objectives] = {nil,nil,{{4533}}},
        },

        [702] = {
            [questKeys.objectives] = {nil,nil,{{4528}}},
        },

        [707] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [708] = {
            [questKeys.objectives] = {nil,nil,{{4613}}},
            [questKeys.specialFlags] = 0,
        },

        [715] = {
            [questKeys.requiredSkill] = {171,0},
        },

        [717] = {
            [questKeys.objectivesText] = {"Use the Sign of the Earth to activate the Pillars of Amethyst, Opal, and Diamond and obtain the Runestones.$b$bPlace the runestones in the Seal of the Earth to free Blacklash and Hematus.$b$bSlay them and return Blacklash's Bindings, the Chains of Hematus, and the Sign of the Earth to Garek."},
            [questKeys.objectives] = {nil,nil,{{4615},{4645},{4640}}},
            [questKeys.requiredSourceItems] = {},
        },

        [723] = {
            [questKeys.objectives] = {nil,nil,{{4635}}},
        },

        [724] = {
            [questKeys.objectives] = {nil,nil,{{4635}}},
        },

        [725] = {
            [questKeys.objectives] = {nil,nil,{{4622}}},
        },

        [727] = {
            [questKeys.objectives] = {nil,nil,{{4648}}},
        },

        [728] = {
            [questKeys.objectives] = {nil,nil,{{4648}}},
        },

        [729] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [734] = {
            [questKeys.preQuestSingle] = {712,714},
        },

        [735] = {
            [questKeys.requiredSourceItems] = {},
        },

        [736] = {
            [questKeys.requiredSourceItems] = {},
        },

        [737] = {
            [questKeys.objectives] = {nil,nil,{{4647}}},
        },

        [738] = {
            [questKeys.preQuestSingle] = {707},
            [questKeys.breadcrumbs] = {},
        },

        [740] = {
            [questKeys.questFlags] = 8,
        },

        [741] = {
            [questKeys.objectives] = {nil,nil,{{4654}}},
        },

        [742] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [747] = {
            [questKeys.questFlags] = 8,
        },

        [748] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.nextQuestInChain] = 0,
        },

        [750] = {
            [questKeys.questFlags] = 8,
        },

        [751] = {
            [questKeys.objectives] = {nil,nil,{{4834}}},
        },

        [752] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 8,
        },

        [753] = {
            [questKeys.objectivesText] = {"Take a Water Pitcher from the water well.$b$bReturn the pitcher to Chief Hawkwind in Camp Narache which is northwest from the water well."},
            [questKeys.preQuestSingle] = {752},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 0,
        },

        [754] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [755] = {
            [questKeys.questFlags] = 8,
        },

        [756] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.nextQuestInChain] = 0,
        },

        [757] = {
            [questKeys.objectivesText] = {"Kill Bristlebacks in Brambleblade Ravine and bring 12 Bristleback Belts to Chief Hawkwind in Camp Narache."},
            [questKeys.questFlags] = 8,
        },

        [758] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [759] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.nextQuestInChain] = 0,
        },

        [763] = {
            [questKeys.objectives] = {nil,nil,{{4783}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 0,
        },

        [767] = {
            [questKeys.preQuestSingle] = {763},
            [questKeys.breadcrumbs] = {},
        },

        [769] = {
            [questKeys.requiredSkill] = {},
            [questKeys.preQuestSingle] = {768},
        },

        [770] = {
            [questKeys.requiredRaces] = 0,
        },

        [771] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [774] = {
            [questKeys.questLevel] = 4,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [777] = {
            [questKeys.objectives] = {nil,nil,{{4846}}},
        },

        [780] = {
            [questKeys.questFlags] = 8,
        },

        [781] = {
            [questKeys.objectives] = {nil,nil,{{4850}}},
            [questKeys.questFlags] = 16384,
            [questKeys.specialFlags] = 4,
        },

        [783] = {
            [questKeys.questFlags] = 8,
        },

        [787] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [788] = {
            [questKeys.objectivesText] = {"Kill 10 Mottled Boars then return to Gornek at the Den."},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 8,
        },

        [789] = {
            [questKeys.objectivesText] = {"Get 10 Scorpid Worker Tails for Gornek in the Den."},
            [questKeys.questFlags] = 8,
        },

        [790] = {
            [questKeys.questFlags] = 8,
        },

        [792] = {
            [questKeys.requiredClasses] = 1279,
            [questKeys.objectivesText] = {"Kill 12 Vile Familiars.$b$bReturn to Zureetha Fargaze outside the Den."},
            [questKeys.questFlags] = 8,
        },

        [793] = {
            [questKeys.objectivesText] = {"Use the Sign of the Earth to activate the Pillars of Diamond, Opal, and Amethyst and obtain the Runestones.$b$bPlace the runestones in the Seal of the Earth to free Blacklash and Hematus.$b$bSlay them and return Blacklash's Bindings, the Chains of Hematus, and the Sign of the Earth to Gorn."},
            [questKeys.objectives] = {nil,nil,{{4615},{4645},{4640}}},
            [questKeys.requiredSourceItems] = {},
        },

        [794] = {
            [questKeys.questFlags] = 8,
        },

        [796] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [797] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [798] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [799] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [800] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [801] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [802] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [803] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [804] = {
            [questKeys.questFlags] = 0,
        },

        [805] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.questFlags] = 8,
        },

        [807] = {
            [questKeys.questLevel] = 11,
            [questKeys.requiredLevel] = 4,
            [questKeys.objectivesText] = {"Bring 5 Scorched Hearts to Orgnil Soulscar in Razor Hill."},
            [questKeys.objectives] = {nil,nil,{{4868}}},
            [questKeys.questFlags] = 8,
        },

        [810] = {
            [questKeys.questLevel] = 5,
            [questKeys.requiredLevel] = 4,
            [questKeys.objectivesText] = {"Bring 6 Small Scorpid Carapaces to Kor'ghan in Sen'jin Village."},
            [questKeys.nextQuestInChain] = 811,
            [questKeys.questFlags] = 8,
        },

        [811] = {
            [questKeys.questLevel] = 7,
            [questKeys.requiredLevel] = 4,
            [questKeys.objectivesText] = {"Bring 8 Large Scorpid Carapaces to Kor'ghan in Sen'jin Village."},
            [questKeys.questFlags] = 8,
        },

        [814] = {
            [questKeys.questLevel] = 6,
            [questKeys.requiredLevel] = 4,
            [questKeys.objectivesText] = {"Bring 10 Chunks of Boar Meat to Cook Torka in Razor Hill."},
            [questKeys.questFlags] = 8,
        },

        [819] = {
            [questKeys.objectives] = {nil,nil,{{4926}}},
        },

        [820] = {
            [questKeys.questLevel] = 9,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Bring 8 Shimmerweed to Master Vornal in Sen'jin Village."},
            [questKeys.questFlags] = 8,
        },

        [823] = {
            [questKeys.preQuestSingle] = {805},
        },

        [824] = {
            [questKeys.objectives] = {nil,nil,{{16408}}},
        },

        [829] = {
            [questKeys.objectives] = {nil,nil,{{6658}}},
        },

        [830] = {
            [questKeys.objectives] = {nil,nil,{{4883}}},
        },

        [831] = {
            [questKeys.objectives] = {nil,nil,{{4883}}},
        },

        [832] = {
            [questKeys.objectives] = {nil,nil,{{4903}}},
        },

        [839] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [840] = {
            [questKeys.objectives] = {nil,nil,{{4992}}},
        },

        [841] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.specialFlags] = 0,
        },

        [842] = {
            [questKeys.objectives] = {nil,nil,{{4995}}},
        },

        [843] = {
            [questKeys.objectivesText] = {"Gann Stonespire wants you to kill 15 Bael'dun Excavators and 5 Bael'dun Foremen.$b$bBring Khazgorm's Journal to Gann Stonespire."},
        },

        [844] = {
            [questKeys.breadcrumbs] = {},
        },

        [849] = {
            [questKeys.specialFlags] = 32,
        },

        [853] = {
            [questKeys.objectives] = {nil,nil,{{5027}}},
            [questKeys.specialFlags] = 128,
        },

        [854] = {
            [questKeys.exclusiveTo] = {},
        },

        [856] = {
            [questKeys.questLevel] = 12,
            [questKeys.requiredLevel] = 9,
            [questKeys.objectivesText] = {"Continue down the road from Camp Taurajo.","","Turn left at the T intersection and continue North.","","Follow the path to the Ancestral Sage outside the Crossroads."},
            [questKeys.questFlags] = 8,
        },

        [858] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [859] = {
            [questKeys.questLevel] = 18,
            [questKeys.requiredLevel] = 13,
            [questKeys.questFlags] = 8,
        },

        [860] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [861] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [864] = {
            [questKeys.objectives] = {nil,nil,{{8527}}},
        },

        [865] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [868] = {
            [questKeys.objectives] = {nil,nil,{{5058},{5059}}},
        },

        [870] = {
            [questKeys.breadcrumbs] = {},
        },

        [877] = {
            [questKeys.specialFlags] = 32,
        },

        [883] = {
            [questKeys.objectives] = {nil,nil,{{5099}}},
        },

        [884] = {
            [questKeys.objectives] = {nil,nil,{{5102}}},
        },

        [885] = {
            [questKeys.objectives] = {nil,nil,{{5103}}},
        },

        [886] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [890] = {
            [questKeys.objectives] = {nil,nil,{{5080}}},
        },

        [892] = {
            [questKeys.objectives] = {nil,nil,{{5080}}},
        },

        [895] = {
            [questKeys.requiredLevel] = 11,
        },

        [897] = {
            [questKeys.objectives] = {nil,nil,{{5138}}},
        },

        [902] = {
            [questKeys.objectives] = {nil,nil,{{5054}}},
        },

        [904] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [905] = {
            [questKeys.specialFlags] = 32,
        },

        [906] = {
            [questKeys.objectives] = {nil,nil,{{5072}}},
        },

        [908] = {
            [questKeys.preQuestSingle] = {6563},
        },

        [909] = {
            [questKeys.objectives] = {nil,nil,{{16782}}},
        },

        [912] = {
            [questKeys.questLevel] = 12,
            [questKeys.requiredLevel] = 10,
            [questKeys.questFlags] = 8,
        },

        [915] = {
            [questKeys.objectivesText] = {"Get some Strawberry Ice Cream for your ward.  The lad seems to prefer Tigule and Foror's brand ice cream."},
            [questKeys.preQuestSingle] = {910},
        },

        [916] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [917] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [918] = {
            [questKeys.preQuestSingle] = {997},
        },

        [920] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [921] = {
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [922] = {
            [questKeys.objectives] = {nil,nil,{{5168}}},
        },

        [923] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [924] = {
            [questKeys.objectivesText] = {"Grab a Flawed Power Stone.  Bring it to the Altar of Fire before the stone expires, then return to Ak'Zeloth."},
            [questKeys.requiredSourceItems] = {},
        },

        [925] = {
            [questKeys.preQuestSingle] = {910},
        },

        [927] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{5179}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [928] = {
            [questKeys.objectives] = {nil,nil,{{5186}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [930] = {
            [questKeys.objectives] = {nil,nil,{{5189}}},
            [questKeys.preQuestSingle] = {},
        },

        [931] = {
            [questKeys.objectives] = {nil,nil,{{5190}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [934] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {933},
        },

        [935] = {
            [questKeys.objectives] = {nil,nil,{{5188}}},
        },

        [936] = {
            [questKeys.exclusiveTo] = {},
        },

        [937] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [938] = {
            [questKeys.questFlags] = 2,
        },

        [939] = {
            [questKeys.objectives] = {nil,nil,{{11668},{11674}}},
        },

        [940] = {
            [questKeys.objectives] = {nil,nil,{{5219}}},
        },

        [941] = {
            [questKeys.objectives] = {nil,nil,{{5217}}},
        },

        [942] = {
            [questKeys.objectives] = {nil,nil,{{4654}}},
        },

        [944] = {
            [questKeys.objectivesText] = {"Gather information, then use the Phial of Scrying to create a Scrying Bowl.  Use the bowl to speak with Onu."},
        },

        [946] = {
            [questKeys.questFlags] = 8,
        },

        [949] = {
            [questKeys.requiredRaces] = 0,
        },

        [950] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{5272}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [952] = {
            [questKeys.objectives] = {nil,nil,{{5390}}},
        },

        [960] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 944,
            [questKeys.specialFlags] = 0,
        },

        [961] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 944,
            [questKeys.questFlags] = 65544,
            [questKeys.specialFlags] = 0,
        },

        [967] = {
            [questKeys.objectives] = {nil,nil,{{5354}}},
        },

        [968] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{5352}}},
        },

        [969] = {
            [questKeys.objectivesText] = {"Collect 10 Frostmaul Shards for Witch Doctor Mau'ari in Everlook."},
        },

        [971] = {
            [questKeys.requiredLevel] = 10,
            [questKeys.questFlags] = 8,
        },

        [974] = {
            [questKeys.objectives] = {{{10541}},nil,{{12472}}},
            [questKeys.specialFlags] = 32,
        },

        [979] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [982] = {
            [questKeys.objectivesText] = {"Recover the Silver Dawning's Lockbox and the Mist Veil's Lockbox for Gorbold Steelhand in Auberdine.  Both items should be found aboard the wreckage of the ships to the north of the village."},
        },

        [985] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [986] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [987] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 64,
            [questKeys.questFlags] = 8,
        },

        [988] = {
            [questKeys.questLevel] = 20,
            [questKeys.requiredLevel] = 10,
            [questKeys.objectivesText] = {"Speak to Volcor."},
            [questKeys.objectives] = {nil,nil,{{5387}}},
            [questKeys.nextQuestInChain] = 995,
            [questKeys.questFlags] = 8,
        },

        [989] = {
            [questKeys.questLevel] = 22,
            [questKeys.requiredLevel] = 10,
            [questKeys.objectivesText] = {"Speak to Volcor."},
            [questKeys.nextQuestInChain] = 994,
            [questKeys.questFlags] = 8,
        },

        [990] = {
            [questKeys.preQuestSingle] = {},
        },

        [992] = {
            [questKeys.objectivesText] = {"Use the untapped dowsing widget near the pool of water by Sandsorrow Watch.  Once you have collected the sample, return the tapped dowsing widget to Senior Surveyor Fizzledowser in Gadgetzan."},
        },

        [993] = {
            [questKeys.objectives] = {nil,nil,{{5387}}},
        },

        [994] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [995] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [996] = {
            [questKeys.specialFlags] = 257,
        },

        [997] = {
            [questKeys.objectives] = {nil,nil,{{5391}}},
        },

        [998] = {
            [questKeys.specialFlags] = 257,
        },

        [1001] = {
            [questKeys.requiredRaces] = 0,
        },

        [1002] = {
            [questKeys.requiredRaces] = 0,
        },

        [1003] = {
            [questKeys.requiredRaces] = 0,
        },

        [1007] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1008] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1010] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1011] = {
            [questKeys.preQuestSingle] = {4581},
            [questKeys.breadcrumbs] = {4581},
        },

        [1014] = {
            [questKeys.requiredRaces] = 690,
        },

        [1020] = {
            [questKeys.objectives] = {nil,nil,{{5460}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [1023] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1024] = {
            [questKeys.objectives] = {nil,nil,{{5463}}},
        },

        [1028] = {
            [questKeys.objectives] = {nil,nil,{{5547}}},
        },

        [1033] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1034] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1036] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.requiredMaxRep] = {21,1},
        },

        [1038] = {
            [questKeys.objectives] = {nil,nil,{{5520},{5521}}},
        },

        [1045] = {
            [questKeys.objectives] = {{{3696},{3932}}},
        },

        [1048] = {
            [questKeys.requiredLevel] = 33,
        },

        [1052] = {
            [questKeys.objectives] = {nil,nil,{{5539}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [1053] = {
            [questKeys.objectivesText] = {"Kill High Inquisitor Whitemane, Scarlet Commander Mograine,  Herod, the Scarlet Champion and Houndmaster Loksey and then report back to Raleigh the Devout in Southshore."},
        },

        [1056] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1060] = {
            [questKeys.objectives] = {nil,nil,{{5594}}},
        },

        [1061] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1062] = {
            [questKeys.breadcrumbs] = {},
        },

        [1065] = {
            [questKeys.objectives] = {nil,nil,{{5628}}},
        },

        [1067] = {
            [questKeys.objectives] = {nil,nil,{{5588}}},
        },

        [1074] = {
            [questKeys.objectives] = {nil,nil,{{5732}}},
        },

        [1076] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1077] = {
            [questKeys.objectives] = {nil,nil,{{5731}}},
        },

        [1079] = {
            [questKeys.preQuestSingle] = {1074,1077},
        },

        [1080] = {
            [questKeys.preQuestSingle] = {1074,1077},
        },

        [1082] = {
            [questKeys.preQuestSingle] = {1083,1084},
        },

        [1089] = {
            [questKeys.objectivesText] = {"Travel to the Den on Stonetalon Peak. Using the Gatekeeper's Key, obtain the druids' hidden items. Use these items to open the Talon Den Hoard. "},
        },

        [1090] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 3,
        },

        [1091] = {
            [questKeys.objectives] = {nil,nil,{{5717}}},
            [questKeys.preQuestSingle] = {1079,1080},
        },

        [1092] = {
            [questKeys.objectives] = {nil,nil,{{5733}}},
        },

        [1093] = {
            [questKeys.breadcrumbs] = {},
        },

        [1094] = {
            [questKeys.objectives] = {nil,nil,{{5735}}},
        },

        [1098] = {
            [questKeys.requiredRaces] = 690,
        },

        [1100] = {
            [questKeys.questLevel] = 34,
            [questKeys.requiredLevel] = 29,
            [questKeys.objectives] = {nil,nil,{{5790}}},
        },

        [1101] = {
            [questKeys.questLevel] = 34,
            [questKeys.requiredLevel] = 29,
        },

        [1102] = {
            [questKeys.questLevel] = 34,
            [questKeys.requiredLevel] = 29,
            [questKeys.requiredRaces] = 690,
        },

        [1103] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 100,
            [questKeys.specialFlags] = 0,
        },

        [1106] = {
            [questKeys.objectives] = {nil,nil,{{5827}}},
            [questKeys.preQuestSingle] = {1104,1105},
        },

        [1107] = {
            [questKeys.preQuestSingle] = {1105},
        },

        [1109] = {
            [questKeys.questLevel] = 33,
            [questKeys.requiredLevel] = 30,
        },

        [1111] = {
            [questKeys.objectives] = {nil,nil,{{5799}}},
        },

        [1112] = {
            [questKeys.objectives] = {nil,nil,{{5800}}},
        },

        [1114] = {
            [questKeys.objectives] = {nil,nil,{{5802}}},
        },

        [1116] = {
            [questKeys.objectivesText] = {"Bring 10 Specks of Dream Dust to Krazek in Booty Bay.  Dream Dust is gathered from the dragon whelps of the Swamp of Sorrows."},
        },

        [1117] = {
            [questKeys.objectives] = {nil,nil,{{5804}}},
        },

        [1118] = {
            [questKeys.objectives] = {nil,nil,{{5826}}},
        },

        [1119] = {
            [questKeys.objectives] = {nil,nil,{{5806}}},
            [questKeys.preQuestSingle] = {621,1118},
        },

        [1120] = {
            [questKeys.objectives] = {nil,nil,{{5806}}},
        },

        [1121] = {
            [questKeys.objectives] = {nil,nil,{{5806}}},
        },

        [1122] = {
            [questKeys.objectives] = {nil,nil,{{5807}}},
        },

        [1123] = {
            [questKeys.objectivesText] = {"Speak with Rabine Saturna in the village of Nighthaven, Moonglade.  Moonglade lies between Felwood and Winterspring, accessible through a path out of Timbermaw Hold."},
        },

        [1124] = {
            [questKeys.objectives] = {nil,nil,{{17355}}},
        },

        [1126] = {
            [questKeys.objectivesText] = {"Scale the tower of Southwind Village and locate a means to stir the silithid hive into activity.  Bring back anything unusual you may uncover when doing so to Layo Starstrike at the Valor's Rest graveyard of Silithus."},
        },

        [1127] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.parentQuest] = 0,
            [questKeys.specialFlags] = 0,
        },

        [1128] = {
            [questKeys.questLevel] = 44,
            [questKeys.requiredLevel] = 35,
            [questKeys.objectives] = {nil,nil,{{5806}}},
            [questKeys.questFlags] = 8,
        },

        [1129] = {
            [questKeys.questLevel] = 44,
            [questKeys.requiredLevel] = 35,
            [questKeys.objectives] = {nil,nil,{{5806}}},
            [questKeys.questFlags] = 8,
        },

        [1130] = {
            [questKeys.preQuestSingle] = {882},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1131] = {
            [questKeys.preQuestSingle] = {1130},
            [questKeys.breadcrumbs] = {},
        },

        [1132] = {
            [questKeys.objectivesText] = {"Speak with Fiora Longears in Theramore."},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1133] = {
            [questKeys.preQuestSingle] = {1132},
            [questKeys.breadcrumbs] = {},
        },

        [1142] = {
            [questKeys.requiredRaces] = 1101,
        },

        [1145] = {
            [questKeys.objectives] = {nil,nil,{{5846}}},
        },

        [1146] = {
            [questKeys.objectives] = {nil,nil,{{5850}}},
        },

        [1148] = {
            [questKeys.preQuestSingle] = {},
        },

        [1150] = {
            [questKeys.requiredSourceItems] = {5845},
        },

        [1155] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 54,
            [questKeys.objectivesText] = {"x"},
        },

        [1156] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 25,
            [questKeys.objectivesText] = {"x"},
            [questKeys.nextQuestInChain] = 1159,
            [questKeys.questFlags] = 8,
        },

        [1157] = {
            [questKeys.questLevel] = 57,
            [questKeys.requiredLevel] = 54,
            [questKeys.questFlags] = 8,
        },

        [1158] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 54,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [1161] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [1162] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [1163] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [1165] = {
            [questKeys.questLevel] = 42,
            [questKeys.requiredLevel] = 30,
            [questKeys.objectives] = {nil,nil,{{5833}}},
            [questKeys.questFlags] = 8,
        },

        [1166] = {
            [questKeys.questLevel] = 43,
            [questKeys.requiredLevel] = 38,
        },

        [1168] = {
            [questKeys.questLevel] = 43,
            [questKeys.requiredLevel] = 38,
            [questKeys.objectivesText] = {"Tharg in Brackenwall Village wants you to kill 15 Firemane Scouts, 15 Firemane Ash Tails, and 5 Firemane Scalebanes."},
        },

        [1169] = {
            [questKeys.questLevel] = 43,
            [questKeys.requiredLevel] = 38,
            [questKeys.objectivesText] = {"Draz'Zilb in Brackenwall Village would like you to bring him 15 Searing Tongues and 15 Searing Hearts."},
        },

        [1170] = {
            [questKeys.questLevel] = 43,
            [questKeys.requiredLevel] = 38,
        },

        [1171] = {
            [questKeys.questLevel] = 43,
            [questKeys.requiredLevel] = 38,
        },

        [1172] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 38,
        },

        [1174] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{5768}}},
            [questKeys.questFlags] = 8,
        },

        [1177] = {
            [questKeys.objectivesText] = {"Mudcrush Durtfeet in northern Dustwallow wants 12 Mirefin Heads."},
        },

        [1179] = {
            [questKeys.objectives] = {nil,nil,{{5849}}},
        },

        [1183] = {
            [questKeys.objectives] = {nil,nil,{{5852}}},
        },

        [1188] = {
            [questKeys.objectives] = {nil,nil,{{5862}}},
        },

        [1189] = {
            [questKeys.objectives] = {nil,nil,{{5865}}},
        },

        [1190] = {
            [questKeys.questFlags] = 8,
        },

        [1191] = {
            [questKeys.parentQuest] = 0,
        },

        [1196] = {
            [questKeys.objectives] = {nil,nil,{{5868}}},
        },

        [1200] = {
            [questKeys.preQuestSingle] = {1198},
            [questKeys.breadcrumbs] = {},
        },

        [1203] = {
            [questKeys.objectivesText] = {"Bring a Moonsteel Broadsword to Jarl in Dustwallow Marsh."},
            [questKeys.objectives] = {nil,nil,{{3853}}},
        },

        [1205] = {
            [questKeys.questLevel] = 45,
        },

        [1206] = {
            [questKeys.objectivesText] = {"Bring 40 Unpopped Darkmist Eyes to \"Swamp Eye\" Jarl at the Swamplight Manor."},
        },

        [1218] = {
            [questKeys.breadcrumbs] = {11177,11225},
        },

        [1219] = {
            [questKeys.objectives] = {nil,nil,{{5917}}},
        },

        [1220] = {
            [questKeys.objectives] = {nil,nil,{{5917}}},
        },

        [1221] = {
            [questKeys.sourceItemId] = 0,
        },

        [1238] = {
            [questKeys.objectives] = {nil,nil,{{5917}}},
        },

        [1239] = {
            [questKeys.objectives] = {nil,nil,{{5918}}},
        },

        [1240] = {
            [questKeys.objectives] = {nil,nil,{{5918}}},
        },

        [1241] = {
            [questKeys.objectives] = {nil,nil,{{5948}}},
        },

        [1242] = {
            [questKeys.objectives] = {nil,nil,{{5946}}},
        },

        [1243] = {
            [questKeys.objectives] = {nil,nil,{{5960}}},
        },

        [1245] = {
            [questKeys.objectives] = {nil,nil,{{5947}}},
        },

        [1249] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
        },

        [1251] = {
            [questKeys.objectives] = {nil,nil,{{5919}}},
        },

        [1252] = {
            [questKeys.questLevel] = 40,
            [questKeys.objectives] = {nil,nil,{{5950}}},
            [questKeys.preQuestSingle] = {},
        },

        [1253] = {
            [questKeys.objectives] = {nil,nil,{{5919}}},
            [questKeys.preQuestSingle] = {},
        },

        [1262] = {
            [questKeys.objectives] = {nil,nil,{{5942}}},
        },

        [1269] = {
            [questKeys.objectives] = {nil,nil,{{5950}}},
        },

        [1271] = {
            [questKeys.preQuestSingle] = {1222,1258},
        },

        [1275] = {
            [questKeys.preQuestSingle] = {3765},
            [questKeys.breadcrumbs] = {},
        },

        [1276] = {
            [questKeys.objectives] = {nil,nil,{{5919}}},
            [questKeys.preQuestSingle] = {1323},
        },

        [1277] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 30,
            [questKeys.objectivesText] = {"Beat down."},
            [questKeys.questFlags] = 8,
        },

        [1278] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [1279] = {
            [questKeys.questFlags] = 8,
        },

        [1280] = {
            [questKeys.questFlags] = 8,
        },

        [1282] = {
            [questKeys.exclusiveTo] = {1302},
        },

        [1283] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [1284] = {
            [questKeys.preQuestSingle] = {},
        },

        [1287] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1288] = {
            [questKeys.objectives] = {nil,nil,{{6075}}},
        },

        [1289] = {
            [questKeys.preQuestSingle] = {1288},
        },

        [1290] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Talkie."},
            [questKeys.questFlags] = 8,
        },

        [1291] = {
            [questKeys.questFlags] = 8,
        },

        [1292] = {
            [questKeys.questFlags] = 8,
        },

        [1293] = {
            [questKeys.questFlags] = 8,
        },

        [1294] = {
            [questKeys.questFlags] = 8,
        },

        [1295] = {
            [questKeys.questFlags] = 8,
        },

        [1296] = {
            [questKeys.questFlags] = 8,
        },

        [1297] = {
            [questKeys.questFlags] = 8,
        },

        [1298] = {
            [questKeys.questFlags] = 8,
        },

        [1299] = {
            [questKeys.questFlags] = 8,
        },

        [1300] = {
            [questKeys.questFlags] = 8,
        },

        [1302] = {
            [questKeys.exclusiveTo] = {1282},
        },

        [1318] = {
            [questKeys.requiredLevel] = 60,
        },

        [1319] = {
            [questKeys.objectives] = {nil,nil,{{5919}}},
        },

        [1321] = {
            [questKeys.objectives] = {nil,nil,{{5919}}},
        },

        [1322] = {
            [questKeys.objectivesText] = {"Acquire 6 Acidic Venom Sacs for Do'gol in Brackenwall Village."},
        },

        [1324] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
        },

        [1338] = {
            [questKeys.objectives] = {nil,nil,{{5998}}},
        },

        [1358] = {
            [questKeys.objectives] = {nil,nil,{{6016}}},
        },

        [1359] = {
            [questKeys.objectives] = {nil,nil,{{10283}}},
        },

        [1361] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1362] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1365] = {
            [questKeys.breadcrumbs] = {},
        },

        [1371] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1383] = {
            [questKeys.objectivesText] = {"Apothecary Faustin at Beggar's Haunt needs 5 Shadow Panther Hearts, Mire Lord Fungus and a Deepstrider Tumor."},
        },

        [1388] = {
            [questKeys.objectives] = {nil,nil,{{6086}}},
        },

        [1390] = {
            [questKeys.nextQuestInChain] = 1397,
        },

        [1391] = {
            [questKeys.objectives] = {nil,nil,{{6089}}},
        },

        [1392] = {
            [questKeys.objectives] = {nil,nil,{{6196}}},
        },

        [1395] = {
            [questKeys.objectives] = {nil,nil,{{6091}}},
        },

        [1396] = {
            [questKeys.breadcrumbs] = {9609},
        },

        [1397] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [1420] = {
            [questKeys.objectives] = {nil,nil,{{6167}}},
            [questKeys.preQuestSingle] = {1418},
        },

        [1423] = {
            [questKeys.objectives] = {nil,nil,{{6172}}},
            [questKeys.specialFlags] = 0,
        },

        [1424] = {
            [questKeys.objectivesText] = {"Fel'zerul in Stonard wants you to gather 10 Atal'ai Artifacts."},
        },

        [1425] = {
            [questKeys.objectives] = {nil,nil,{{6178}}},
        },

        [1427] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1429] = {
            [questKeys.objectives] = {nil,nil,{{6193}}},
        },

        [1432] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1434] = {
            [questKeys.preQuestSingle] = {},
        },

        [1435] = {
            [questKeys.objectives] = {nil,nil,{{6436},{6435}}},
        },

        [1436] = {
            [questKeys.preQuestSingle] = {1435},
        },

        [1441] = {
            [questKeys.questLevel] = 33,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [1442] = {
            [questKeys.parentQuest] = 0,
            [questKeys.specialFlags] = 0,
        },

        [1443] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [1447] = {
            [questKeys.objectives] = nil,
        },

        [1452] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1457] = {
            [questKeys.objectives] = {nil,nil,{{6245}}},
        },

        [1460] = {
            [questKeys.questLevel] = 37,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [1461] = {
            [questKeys.questLevel] = 37,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [1462] = {
            [questKeys.objectivesText] = {"Speak to Seer Ravenfeather for another Earth Sapta."},
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 1520,
            [questKeys.questFlags] = 65536,
            [questKeys.specialFlags] = 5,
        },

        [1463] = {
            [questKeys.objectivesText] = {"Speak to Canaga Earthcaller for another Earth Sapta."},
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 1517,
            [questKeys.questFlags] = 65536,
            [questKeys.specialFlags] = 5,
        },

        [1464] = {
            [questKeys.objectivesText] = {"Speak to Telf Joolam for another Fire Sapta."},
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 1526,
        },

        [1465] = {
            [questKeys.objectives] = {nil,nil,{{6479}}},
        },

        [1467] = {
            [questKeys.objectives] = {nil,nil,{{6253}}},
        },

        [1469] = {
            [questKeys.objectives] = {nil,nil,{{6287}}},
        },

        [1470] = {
            [questKeys.exclusiveTo] = {},
        },

        [1471] = {
            [questKeys.objectives] = {{{5676}},nil,{{6284}}},
        },

        [1472] = {
            [questKeys.breadcrumbs] = {10605},
        },

        [1474] = {
            [questKeys.objectives] = {{{5677}},nil,{{6286}}},
            [questKeys.exclusiveTo] = {},
        },

        [1476] = {
            [questKeys.exclusiveTo] = {},
        },

        [1478] = {
            [questKeys.requiredRaces] = 16,
        },

        [1479] = {
            [questKeys.objectivesText] = {"Take the orphan to the bank of Darnassus.  The bank itself is hollowed out of a tree known as the Bough of the Eternals."},
        },

        [1480] = {
            [questKeys.objectives] = {nil,nil,{{20310}}},
        },

        [1483] = {
            [questKeys.objectivesText] = {"Speak with Ziz Fizziks in Windshear Crag."},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1485] = {
            [questKeys.exclusiveTo] = {},
        },

        [1492] = {
            [questKeys.objectives] = {nil,nil,{{6462}}},
        },

        [1498] = {
            [questKeys.preQuestSingle] = {1505},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbs] = {},
        },

        [1499] = {
            [questKeys.requiredRaces] = 130,
            [questKeys.preQuestSingle] = {1485},
        },

        [1502] = {
            [questKeys.preQuestSingle] = {1498},
        },

        [1504] = {
            [questKeys.objectives] = {{{5676}},nil,{{7464}}},
        },

        [1505] = {
            [questKeys.exclusiveTo] = {1818},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1506] = {
            [questKeys.requiredRaces] = 2,
        },

        [1508] = {
            [questKeys.exclusiveTo] = {},
        },

        [1509] = {
            [questKeys.exclusiveTo] = {},
        },

        [1510] = {
            [questKeys.exclusiveTo] = {},
        },

        [1511] = {
            [questKeys.objectives] = {nil,nil,{{6624}}},
            [questKeys.exclusiveTo] = {},
        },

        [1512] = {
            [questKeys.objectives] = {nil,nil,{{6625}}},
            [questKeys.exclusiveTo] = {},
        },

        [1513] = {
            [questKeys.objectives] = {{{5677}},nil,{{6626}}},
            [questKeys.exclusiveTo] = {},
        },

        [1514] = {
            [questKeys.specialFlags] = 257,
        },

        [1515] = {
            [questKeys.objectives] = {nil,nil,{{6624}}},
            [questKeys.exclusiveTo] = {},
        },

        [1516] = {
            [questKeys.requiredRaces] = 130,
            [questKeys.nextQuestInChain] = 1517,
            [questKeys.questFlags] = 8,
        },

        [1517] = {
            [questKeys.requiredRaces] = 130,
            [questKeys.preQuestSingle] = {1516},
            [questKeys.nextQuestInChain] = 1518,
            [questKeys.questFlags] = 0,
        },

        [1518] = {
            [questKeys.requiredRaces] = 130,
            [questKeys.objectives] = {nil,nil,{{6656}}},
            [questKeys.requiredSourceItems] = {},
            [questKeys.questFlags] = 0,
        },

        [1519] = {
            [questKeys.requiredRaces] = 32,
            [questKeys.nextQuestInChain] = 1520,
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [1520] = {
            [questKeys.requiredRaces] = 32,
            [questKeys.preQuestSingle] = {1519},
            [questKeys.nextQuestInChain] = 1521,
            [questKeys.questFlags] = 0,
        },

        [1521] = {
            [questKeys.requiredRaces] = 32,
            [questKeys.objectives] = {nil,nil,{{6656}}},
            [questKeys.requiredSourceItems] = {},
            [questKeys.questFlags] = 0,
        },

        [1522] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1523] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1524] = {
            [questKeys.objectives] = {nil,nil,{{6653}}},
            [questKeys.breadcrumbs] = {},
        },

        [1526] = {
            [questKeys.objectives] = {nil,nil,{{6653},{6655}}},
            [questKeys.requiredSourceItems] = {},
        },

        [1527] = {
            [questKeys.objectives] = {nil,nil,{{6654}}},
        },

        [1528] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1529] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1530] = {
            [questKeys.objectivesText] = {"Find Brine in Southern Barrens."},
            [questKeys.breadcrumbs] = {},
        },

        [1533] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 64,
            [questKeys.questFlags] = 8,
        },

        [1537] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 64,
            [questKeys.questFlags] = 8,
        },

        [1538] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 64,
            [questKeys.questFlags] = 8,
        },

        [1558] = {
            [questKeys.objectivesText] = {"Take the orphan to the Stonewrought Dam in Loch Modan.  You should take him to the middle of the dam so he can see out over the giant waterfall."},
        },

        [1578] = {
            [questKeys.questFlags] = 8,
        },

        [1580] = {
            [questKeys.requiredSkill] = {356,1},
        },

        [1582] = {
            [questKeys.requiredSkill] = {165,70},
        },

        [1598] = {
            [questKeys.requiredRaces] = 1,
            [questKeys.exclusiveTo] = {},
        },

        [1599] = {
            [questKeys.requiredRaces] = 64,
            [questKeys.exclusiveTo] = {},
            [questKeys.questFlags] = 8,
        },

        [1618] = {
            [questKeys.requiredSkill] = {164,70},
        },

        [1638] = {
            [questKeys.exclusiveTo] = {1679,1684,9582},
            [questKeys.nextQuestInChain] = 1639,
        },

        [1639] = {
            [questKeys.preQuestSingle] = {1638},
            [questKeys.exclusiveTo] = {},
        },

        [1640] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {1639},
        },

        [1641] = {
            [questKeys.exclusiveTo] = {},
        },

        [1643] = {
            [questKeys.preQuestSingle] = {1642,2998,3681},
        },

        [1645] = {
            [questKeys.exclusiveTo] = {},
        },

        [1647] = {
            [questKeys.preQuestSingle] = {1646,2997,2999,3000},
        },

        [1655] = {
            [questKeys.preQuestSingle] = {1653},
            [questKeys.parentQuest] = 0,
            [questKeys.specialFlags] = 0,
        },

        [1656] = {
            [questKeys.objectives] = {nil,nil,{{7626}}},
            [questKeys.questFlags] = 0,
        },

        [1657] = {
            [questKeys.specialFlags] = 0,
        },

        [1658] = {
            [questKeys.objectivesText] = {"Locate the Forsaken's Wickerman Festival in Tirisfal Glades.  Return to Sergeant Hartman in Southshore once you've done so."},
        },

        [1659] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [1660] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [1661] = {
            [questKeys.exclusiveTo] = {},
        },

        [1662] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 40,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [1663] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 40,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [1664] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 40,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [1665] = {
            [questKeys.objectives] = {nil,nil,{{6781}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [1678] = {
            [questKeys.requiredRaces] = 68,
            [questKeys.preQuestSingle] = {1679},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbs] = {},
        },

        [1679] = {
            [questKeys.requiredRaces] = 68,
            [questKeys.exclusiveTo] = {1638,1684,9582},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1680] = {
            [questKeys.preQuestSingle] = {1678},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1681] = {
            [questKeys.preQuestSingle] = {1680},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1683] = {
            [questKeys.preQuestSingle] = {1684},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [1684] = {
            [questKeys.exclusiveTo] = {1638,1679,9582},
            [questKeys.nextQuestInChain] = 1683,
        },

        [1686] = {
            [questKeys.preQuestSingle] = {1683},
        },

        [1688] = {
            [questKeys.breadcrumbs] = {1685,1715},
        },

        [1689] = {
            [questKeys.objectives] = {{{5676}},nil,{{6928}}},
        },

        [1692] = {
            [questKeys.objectivesText] = {"Bring the Case of Elunite to Smith Mathiel. "},
            [questKeys.objectives] = {nil,nil,{{6812}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [1698] = {
            [questKeys.exclusiveTo] = {},
        },

        [1700] = {
            [questKeys.objectives] = {nil,nil,{{6926}}},
            [questKeys.preQuestSingle] = {1701},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1701] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1702] = {
            [questKeys.objectives] = {nil,nil,{{6843}}},
        },

        [1703] = {
            [questKeys.objectives] = {nil,nil,{{6926}}},
            [questKeys.preQuestSingle] = {1701},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1704] = {
            [questKeys.objectives] = {nil,nil,{{6926}}},
            [questKeys.preQuestSingle] = {1701},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1705] = {
            [questKeys.preQuestSingle] = {1701},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1708] = {
            [questKeys.preQuestSingle] = {1701},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1710] = {
            [questKeys.preQuestSingle] = {1701},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1712] = {
            [questKeys.requiredSourceItems] = {},
        },

        [1715] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 1688,
        },

        [1716] = {
            [questKeys.breadcrumbs] = {1717},
        },

        [1717] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 1716,
            [questKeys.breadcrumbForQuestId] = 1716,
        },

        [1739] = {
            [questKeys.objectives] = {{{5677}},nil,{{6913}}},
        },

        [1758] = {
            [questKeys.preQuestSingle] = {1798},
        },

        [1782] = {
            [questKeys.requiredClasses] = 0,
        },

        [1789] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [1790] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [1793] = {
            [questKeys.exclusiveTo] = {1794},
            [questKeys.specialFlags] = 0,
        },

        [1794] = {
            [questKeys.exclusiveTo] = {1793},
            [questKeys.specialFlags] = 0,
        },

        [1795] = {
            [questKeys.objectives] = {{{6268}},nil,{{6999}}},
        },

        [1801] = {
            [questKeys.requiredRaces] = 690,
        },

        [1802] = {
            [questKeys.questFlags] = 8,
        },

        [1803] = {
            [questKeys.requiredRaces] = 690,
        },

        [1804] = {
            [questKeys.objectives] = {nil,nil,{{7006},{6930}}},
            [questKeys.exclusiveTo] = {1805},
        },

        [1805] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{7006},{6930}}},
            [questKeys.exclusiveTo] = {1804},
        },

        [1818] = {
            [questKeys.exclusiveTo] = {1505},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1819] = {
            [questKeys.preQuestSingle] = {1818},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbs] = {},
        },

        [1820] = {
            [questKeys.preQuestSingle] = {1819},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1821] = {
            [questKeys.preQuestSingle] = {1820},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1825] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1838] = {
            [questKeys.preQuestSingle] = {1825},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1839] = {
            [questKeys.preQuestSingle] = {1838},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1840] = {
            [questKeys.preQuestSingle] = {1838},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1841] = {
            [questKeys.preQuestSingle] = {1838},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1842] = {
            [questKeys.preQuestSingle] = {1839},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1844] = {
            [questKeys.preQuestSingle] = {1840},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1846] = {
            [questKeys.preQuestSingle] = {1841},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [1858] = {
            [questKeys.requiredRaces] = 690,
        },

        [1859] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {1885,9532},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1860] = {
            [questKeys.exclusiveTo] = {},
        },

        [1861] = {
            [questKeys.requiredRaces] = 1,
            [questKeys.preQuestSingle] = {1860},
        },

        [1879] = {
            [questKeys.exclusiveTo] = {},
        },

        [1881] = {
            [questKeys.exclusiveTo] = {},
        },

        [1882] = {
            [questKeys.preQuestSingle] = {1881},
        },

        [1883] = {
            [questKeys.exclusiveTo] = {},
        },

        [1885] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {1859,9532},
            [questKeys.nextQuestInChain] = 1886,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1886] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {1885},
            [questKeys.nextQuestInChain] = 1898,
            [questKeys.breadcrumbs] = {},
        },

        [1898] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{7231}}},
            [questKeys.preQuestSingle] = {1886},
            [questKeys.nextQuestInChain] = 1899,
        },

        [1899] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {1898},
            [questKeys.nextQuestInChain] = 1978,
        },

        [1918] = {
            [questKeys.objectives] = {nil,nil,{{16408}}},
        },

        [1920] = {
            [questKeys.objectivesText] = {"Obtain a Cantation of Manifestation and a Chest of Containment coffers from behind Jennea Cannon.  Bring 3 Filled Containment Coffers to Jennea at the Wizard's Sanctum."},
        },

        [1921] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1940] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1945] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1950] = {
            [questKeys.objectives] = nil,
        },

        [1952] = {
            [questKeys.preQuestSingle] = {1951},
        },

        [1953] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [1954] = {
            [questKeys.preQuestSingle] = {1953},
            [questKeys.breadcrumbs] = {},
        },

        [1957] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1960] = {
            [questKeys.objectivesText] = {"Obtain a Cantation of Manifestation and a Chest of Containment Coffers from behind Anastasia Hartwell.  Bring 3 Filled Containment Coffers, the Chest of Containment Coffers and the Cantation of Manifestation to Anastasia in the Undercity."},
        },

        [1961] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [1963] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {1859},
            [questKeys.breadcrumbs] = {},
        },

        [1978] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{7294}}},
            [questKeys.preQuestSingle] = {1899},
        },

        [1998] = {
            [questKeys.requiredRaces] = 690,
        },

        [1999] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.requiredSourceItems] = {},
        },

        [2018] = {
            [questKeys.preQuestSingle] = {2000},
        },

        [2019] = {
            [questKeys.nextQuestInChain] = 2020,
        },

        [2020] = {
            [questKeys.requiredClasses] = 8,
            [questKeys.objectives] = {nil,nil,{{7389}}},
            [questKeys.questFlags] = 8,
        },

        [2038] = {
            [questKeys.preQuestSingle] = {2039},
        },

        [2058] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectives] = {nil,nil,{{7425}}},
            [questKeys.questFlags] = 8,
        },

        [2059] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectives] = {nil,nil,{{7425}}},
            [questKeys.questFlags] = 8,
        },

        [2118] = {
            [questKeys.objectives] = {{{11836}}},
            [questKeys.specialFlags] = 32,
        },

        [2138] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2158] = {
            [questKeys.questFlags] = 8,
        },

        [2159] = {
            [questKeys.objectives] = {nil,nil,{{7627}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [2160] = {
            [questKeys.objectives] = {nil,nil,{{7646}}},
            [questKeys.specialFlags] = 4,
        },

        [2161] = {
            [questKeys.objectives] = {nil,nil,{{7629}}},
            [questKeys.questFlags] = 0,
        },

        [2198] = {
            [questKeys.objectives] = {nil,nil,{{7666}}},
        },

        [2199] = {
            [questKeys.questFlags] = 8,
        },

        [2200] = {
            [questKeys.objectivesText] = {"Search for clues as to the current disposition of Talvash's necklace within Uldaman.  The slain paladin he mentioned was the person who had it last."},
        },

        [2201] = {
            [questKeys.objectivesText] = {"Find the ruby, sapphire, and topaz that are scattered throughout Uldaman.  Once acquired, contact Talvash del Kissel remotely by using the Phial of Scrying he previously gave you.","","From the journal, you know...","* The ruby has been stashed in a barricaded Shadowforge area.","* The topaz has been hidden in an urn in one of the Trogg areas, near some Alliance dwarves.","","* The sapphire has been claimed by Grimlok, the trogg leader."},
        },

        [2203] = {
            [questKeys.objectivesText] = {"Use the empty thaumaturgy vessels on scorched guardian dragons found in the Badlands.  Once you have them filled, bring them to Jarkal Mossmeld in Kargath."},
        },

        [2205] = {
            [questKeys.objectives] = {nil,nil,{{7674}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 2206,
        },

        [2206] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {2238,2242},
            [questKeys.breadcrumbs] = {2205},
        },

        [2218] = {
            [questKeys.breadcrumbForQuestId] = 2238,
        },

        [2238] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {2206,2242},
            [questKeys.breadcrumbs] = {2218},
        },

        [2239] = {
            [questKeys.objectives] = {nil,nil,{{7715}}},
        },

        [2241] = {
            [questKeys.objectives] = {nil,nil,{{7735}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 2242,
        },

        [2242] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {2206,2238},
            [questKeys.breadcrumbs] = {2241},
        },

        [2258] = {
            [questKeys.objectivesText] = {"Bring 5 Buzzard Gizzards, 10 Crag Coyote Fangs, and  5 Rock Elemental Shards to Jarkal Mossmeld in Kargath, Badlands."},
        },

        [2259] = {
            [questKeys.exclusiveTo] = {},
        },

        [2260] = {
            [questKeys.preQuestSingle] = {2259},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 2281,
        },

        [2278] = {
            [questKeys.objectivesText] = {"Speak with stone watcher and learn what ancient lore it keeps.  Once you have learned what lore it has to offer, activate the Discs of Norgannon."},
            [questKeys.objectives] = nil,
        },

        [2279] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
        },

        [2280] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
        },

        [2281] = {
            [questKeys.breadcrumbs] = {2260,2298,2300},
        },

        [2283] = {
            [questKeys.objectivesText] = {"Look for a valuable necklace within the Uldaman dig site and bring it back to Dran Droffers in Orgrimmar.  The necklace may be damaged."},
        },

        [2298] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 2281,
        },

        [2299] = {
            [questKeys.exclusiveTo] = {},
        },

        [2300] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 2281,
            [questKeys.breadcrumbForQuestId] = 2281,
        },

        [2318] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Find someone who can translate the paladin's journal.  The closest location that might have someone is Kargath, in the Badlands."},
        },

        [2338] = {
            [questKeys.objectivesText] = {"Let Jarkal borrow the necklace.  In exchange, he will translate the journal for you."},
            [questKeys.objectives] = {nil,nil,{{7886}}},
        },

        [2339] = {
            [questKeys.objectivesText] = {"Recover all three gems and a power source for the necklace from Uldaman, and then bring them to Jarkal Mossmeld in Kargath.  Jarkal believes a power source might be found on the strongest construct present in Uldaman.","","From the journal, you know...","* The ruby has been stashed in a barricaded Shadowforge area.","* The topaz has been hidden in an urn in one of the Trogg areas, near some Alliance dwarves.","* The sapphire has been claimed by Grimlok, the trogg leader."},
        },

        [2340] = {
            [questKeys.objectives] = {nil,nil,{{7887}}},
        },

        [2358] = {
            [questKeys.requiredRaces] = 0,
        },

        [2378] = {
            [questKeys.nextQuestInChain] = 2379,
        },

        [2379] = {
            [questKeys.exclusiveTo] = {10372},
        },

        [2380] = {
            [questKeys.nextQuestInChain] = 2379,
        },

        [2381] = {
            [questKeys.objectivesText] = {"Bring the Southsea Treasure back to Wrenix the Wretched in Ratchet. Do not forget to get an E.C.A.C. and Thieves' Tools from Wrenix's Gizmotronic Apparatus. You will need both of these items to complete your mission.","","Should you be attacked by any unusually hostile parrots, use your E.C.A.C.!",""},
        },

        [2382] = {
            [questKeys.preQuestSingle] = {2379},
        },

        [2383] = {
            [questKeys.objectives] = {nil,nil,{{12635}}},
            [questKeys.questFlags] = 0,
        },

        [2399] = {
            [questKeys.requiredRaces] = 0,
        },

        [2439] = {
            [questKeys.objectives] = {nil,nil,{{8070}}},
        },

        [2440] = {
            [questKeys.objectives] = {nil,nil,{{8070}}},
        },

        [2460] = {
            [questKeys.objectives] = nil,
            [questKeys.breadcrumbs] = {},
        },

        [2478] = {
            [questKeys.requiredSourceItems] = {},
        },

        [2479] = {
            [questKeys.objectivesText] = {"Travel to Tarren Mill in Hillsbrad Foothills and deliver the Sample of Zanzil's Mixture to Serge Hinott.","","To get to Tarren Mill, take the Zeppelin to the Undercity and follow the road south through Silverpine and towards Hillsbrad. Follow the signs!",""},
            [questKeys.objectives] = {nil,nil,{{8087}}},
        },

        [2501] = {
            [questKeys.objectivesText] = {"Use the empty thaumaturgy vessels on scorched guardian dragons found in the Badlands.  Once you have them filled, bring them to Ghak Healtouch in Thelsamar."},
            [questKeys.preQuestSingle] = {2500},
        },

        [2518] = {
            [questKeys.breadcrumbs] = {},
        },

        [2519] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2520] = {
            [questKeys.objectives] = nil,
        },

        [2521] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2523] = {
            [questKeys.specialFlags] = 257,
        },

        [2561] = {
            [questKeys.objectives] = nil,
        },

        [2581] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2583] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2585] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2601] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2603] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2606] = {
            [questKeys.objectives] = {nil,nil,{{8603}}},
        },

        [2609] = {
            [questKeys.objectivesText] = {"Bring Doc Mixilpixil one bundle of Simple Wildflowers, one Leaded Vial, one Bronze Tube, and one Spool of Light Chartreuse Silk Thread. The 'itis' doesn't cure itself, young $g fella:lady;. "},
        },

        [2641] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2661] = {
            [questKeys.objectives] = {nil,nil,{{8528}}},
        },

        [2701] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2744] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 10,
        },

        [2746] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2755] = {
            [questKeys.objectives] = nil,
        },

        [2757] = {
            [questKeys.objectives] = {nil,nil,{{8663}}},
        },

        [2759] = {
            [questKeys.objectives] = {nil,nil,{{8663}}},
        },

        [2760] = {
            [questKeys.objectives] = {nil,nil,{{8686}}},
        },

        [2765] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {2761,2762,2763},
        },

        [2766] = {
            [questKeys.objectives] = {nil,nil,{{8705}}},
        },

        [2769] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2770] = {
            [questKeys.breadcrumbs] = {},
        },

        [2771] = {
            [questKeys.preQuestSingle] = {2760},
        },

        [2772] = {
            [questKeys.preQuestSingle] = {2760},
        },

        [2773] = {
            [questKeys.preQuestSingle] = {2760},
        },

        [2781] = {
            [questKeys.requiredLevel] = 39,
        },

        [2782] = {
            [questKeys.objectives] = {nil,nil,{{8724}}},
        },

        [2784] = {
            [questKeys.objectives] = nil,
        },

        [2801] = {
            [questKeys.objectives] = nil,
        },

        [2841] = {
            [questKeys.exclusiveTo] = {},
        },

        [2842] = {
            [questKeys.parentQuest] = 2841,
        },

        [2843] = {
            [questKeys.objectives] = nil,
        },

        [2847] = {
            [questKeys.requiredSkill] = {165,225},
        },

        [2851] = {
            [questKeys.preQuestSingle] = {2847,2848,2849},
        },

        [2852] = {
            [questKeys.preQuestSingle] = {2847,2850},
        },

        [2853] = {
            [questKeys.objectives] = {nil,nil,{{9235}}},
            [questKeys.preQuestSingle] = {2851,2852},
        },

        [2854] = {
            [questKeys.requiredSkill] = {165,225},
        },

        [2858] = {
            [questKeys.preQuestSingle] = {2854},
        },

        [2859] = {
            [questKeys.preQuestSingle] = {2854},
        },

        [2860] = {
            [questKeys.objectives] = {nil,nil,{{9236}}},
            [questKeys.preQuestSingle] = {2855,2856,2857,2858,2859},
        },

        [2864] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2865] = {
            [questKeys.breadcrumbs] = {},
        },

        [2868] = {
            [questKeys.questLevel] = 50,
            [questKeys.requiredLevel] = 40,
            [questKeys.objectives] = {nil,nil,{{9243}}},
            [questKeys.sourceItemId] = 9243,
        },

        [2871] = {
            [questKeys.objectives] = {nil,nil,{{9248}}},
        },

        [2872] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2873] = {
            [questKeys.breadcrumbs] = {},
        },

        [2874] = {
            [questKeys.objectives] = {nil,nil,{{9245}}},
        },

        [2875] = {
            [questKeys.requiredLevel] = 40,
        },

        [2876] = {
            [questKeys.objectives] = {nil,nil,{{9250}}},
        },

        [2878] = {
            [questKeys.specialFlags] = 257,
        },

        [2879] = {
            [questKeys.requiredSourceItems] = {},
        },

        [2880] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2881] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.specialFlags] = 0,
        },

        [2882] = {
            [questKeys.specialFlags] = 0,
        },

        [2903] = {
            [questKeys.objectives] = {nil,nil,{{9266}}},
        },

        [2922] = {
            [questKeys.preQuestSingle] = {2923},
        },

        [2926] = {
            [questKeys.preQuestSingle] = {2927},
            [questKeys.breadcrumbs] = {},
        },

        [2927] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2930] = {
            [questKeys.requiredSourceItems] = {},
        },

        [2932] = {
            [questKeys.objectivesText] = {"Gather Witherbark Skulls and place on Nimboya's Pike.  Place Nimboya's Laden Pike at one of the Witherbark Villages in the Hinterlands, then return to Nimboya in Stranglethorn."},
            [questKeys.specialFlags] = 34,
        },

        [2933] = {
            [questKeys.objectives] = {nil,nil,{{9321}}},
        },

        [2938] = {
            [questKeys.objectives] = {nil,nil,{{9436}}},
        },

        [2941] = {
            [questKeys.objectives] = {nil,nil,{{9329}}},
        },

        [2942] = {
            [questKeys.objectivesText] = {"Return the Sparkling Stone and the Stave of Equinex to Troyas Moonbreeze in Feathermoon Stronghold. "},
            [questKeys.objectives] = {nil,nil,{{9307},{9306}}},
        },

        [2943] = {
            [questKeys.objectives] = {nil,nil,{{9331}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [2944] = {
            [questKeys.objectives] = {nil,nil,{{9330},{9328}}},
        },

        [2945] = {
            [questKeys.objectives] = {nil,nil,{{9326}}},
        },

        [2946] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [2947] = {
            [questKeys.objectives] = {nil,nil,{{9362}}},
        },

        [2948] = {
            [questKeys.objectives] = {nil,nil,{{9362},{2842},{1206}}},
        },

        [2949] = {
            [questKeys.objectives] = {nil,nil,{{9362}}},
        },

        [2950] = {
            [questKeys.objectives] = {nil,nil,{{9362},{2842},{1206}}},
        },

        [2951] = {
            [questKeys.exclusiveTo] = {},
        },

        [2952] = {
            [questKeys.preQuestSingle] = {2951},
            [questKeys.exclusiveTo] = {},
        },

        [2953] = {
            [questKeys.preQuestSingle] = {2952},
            [questKeys.exclusiveTo] = {},
        },

        [2962] = {
            [questKeys.objectives] = {nil,nil,{{9365},{9364}}},
        },

        [2966] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [2967] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
        },

        [2969] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2970] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [2971] = {
            [questKeys.questLevel] = 32,
            [questKeys.requiredLevel] = 23,
            [questKeys.objectivesText] = {"[PH] Log Description"},
            [questKeys.questFlags] = 2,
        },

        [2972] = {
            [questKeys.objectives] = {nil,nil,{{9368}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [2975] = {
            [questKeys.breadcrumbs] = {},
        },

        [2976] = {
            [questKeys.objectives] = {nil,nil,{{9462}}},
        },

        [2977] = {
            [questKeys.objectives] = {nil,nil,{{6064}}},
        },

        [2978] = {
            [questKeys.objectives] = {nil,nil,{{9370}}},
        },

        [2981] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2983] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2984] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2985] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2986] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [2987] = {
            [questKeys.objectives] = {nil,nil,{{9463},{9466}}},
        },

        [2988] = {
            [questKeys.objectivesText] = {"Check the cages at the two Witherbark villages, then return to Gryphon  Master Talonaxe."},
        },

        [2990] = {
            [questKeys.objectives] = {nil,nil,{{9468}}},
        },

        [2992] = {
            [questKeys.specialFlags] = 0,
        },

        [2994] = {
            [questKeys.specialFlags] = 32,
        },

        [2996] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.nextQuestInChain] = 0,
        },

        [2997] = {
            [questKeys.exclusiveTo] = {2999,3000},
        },

        [2998] = {
            [questKeys.exclusiveTo] = {3681},
        },

        [2999] = {
            [questKeys.exclusiveTo] = {2997,3000},
        },

        [3000] = {
            [questKeys.exclusiveTo] = {2997,2999},
        },

        [3001] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.nextQuestInChain] = 0,
        },

        [3002] = {
            [questKeys.objectives] = {nil,nil,{{9371}}},
        },

        [3022] = {
            [questKeys.objectives] = {nil,nil,{{9507}}},
        },

        [3023] = {
            [questKeys.questLevel] = 30,
            [questKeys.requiredLevel] = 30,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 8,
        },

        [3064] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 40,
            [questKeys.objectivesText] = {"Bring 20 Untorn Pirate Hats to Yorba Screwspigot."},
            [questKeys.questFlags] = 8,
        },

        [3065] = {
            [questKeys.objectives] = {nil,nil,{{6488}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3082] = {
            [questKeys.objectives] = {nil,nil,{{9564}}},
            [questKeys.specialFlags] = 4,
        },

        [3083] = {
            [questKeys.objectives] = {nil,nil,{{9554}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3084] = {
            [questKeys.objectives] = {nil,nil,{{9562}}},
            [questKeys.specialFlags] = 4,
        },

        [3085] = {
            [questKeys.objectives] = {nil,nil,{{9561}}},
            [questKeys.specialFlags] = 4,
        },

        [3086] = {
            [questKeys.objectives] = {nil,nil,{{9575}}},
            [questKeys.specialFlags] = 4,
        },

        [3087] = {
            [questKeys.objectives] = {nil,nil,{{9553}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3088] = {
            [questKeys.objectives] = {nil,nil,{{9560}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3089] = {
            [questKeys.objectives] = {nil,nil,{{9568}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3090] = {
            [questKeys.objectives] = {nil,nil,{{9579}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3091] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{9547}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3092] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{9565}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3093] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{9552}}},
            [questKeys.questFlags] = 0,
        },

        [3094] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{9581}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3095] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{9546}}},
            [questKeys.questFlags] = 0,
        },

        [3096] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{9559}}},
            [questKeys.preQuestSingle] = {364},
            [questKeys.questFlags] = 0,
        },

        [3097] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{9569}}},
            [questKeys.preQuestSingle] = {364},
            [questKeys.questFlags] = 0,
        },

        [3098] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{9574}}},
            [questKeys.preQuestSingle] = {364},
            [questKeys.questFlags] = 0,
        },

        [3099] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{9578}}},
            [questKeys.questFlags] = 0,
        },

        [3100] = {
            [questKeys.objectives] = {nil,nil,{{9542}}},
            [questKeys.questFlags] = 0,
        },

        [3101] = {
            [questKeys.objectives] = {nil,nil,{{9570}}},
            [questKeys.questFlags] = 0,
        },

        [3102] = {
            [questKeys.objectives] = {nil,nil,{{9555}}},
            [questKeys.questFlags] = 0,
        },

        [3103] = {
            [questKeys.objectives] = {nil,nil,{{9548}}},
            [questKeys.questFlags] = 0,
        },

        [3104] = {
            [questKeys.objectives] = {nil,nil,{{9571}}},
            [questKeys.questFlags] = 0,
        },

        [3105] = {
            [questKeys.objectives] = {nil,nil,{{9576}}},
            [questKeys.questFlags] = 0,
        },

        [3106] = {
            [questKeys.objectives] = {nil,nil,{{9543}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3107] = {
            [questKeys.objectives] = {nil,nil,{{9563}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3108] = {
            [questKeys.objectives] = {nil,nil,{{9566}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3109] = {
            [questKeys.objectives] = {nil,nil,{{9550}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3110] = {
            [questKeys.objectives] = {nil,nil,{{9556}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3111] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 128,
            [questKeys.objectivesText] = {"Speak to Marrek Stromnur inside Anvilmar."},
            [questKeys.objectives] = {nil,nil,{{9572}}},
            [questKeys.sourceItemId] = 9572,
        },

        [3112] = {
            [questKeys.objectives] = {nil,nil,{{9544}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3113] = {
            [questKeys.objectives] = {nil,nil,{{9558}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3114] = {
            [questKeys.objectives] = {nil,nil,{{9573}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3115] = {
            [questKeys.objectives] = {nil,nil,{{9577}}},
            [questKeys.questFlags] = 0,
        },

        [3116] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{9545}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3117] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{9567}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3118] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{9551}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3119] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{9557}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3120] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{9580}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3121] = {
            [questKeys.objectivesText] = {"Take the Shrunken Head to Neeru Fireblade in Orgrimmar."},
            [questKeys.objectives] = {nil,nil,{{9629}}},
        },

        [3122] = {
            [questKeys.objectivesText] = {"Deliver Neeru's Herb Pouch to Witch Doctor Uzer'i in Feralas."},
            [questKeys.objectives] = {nil,nil,{{9628}}},
        },

        [3123] = {
            [questKeys.objectivesText] = {"This will be a test; both of the ritual I performed, and of your abilities. Take this vessel, $N. With it, you will have the power to shrink and capture a creature inside of it.","","Travel to the Hinterlands and look for creatures known as Wildkin that were once pets of the night elf goddess Elune. The vicious, primitive, or savage owlbeasts are your targets, $N. Kill 10, and use the muisek vessel to shrink and capture them before their spirits can escape."},
            [questKeys.objectives] = {nil,nil,{{9594},{9618}}},
        },

        [3124] = {
            [questKeys.objectives] = {nil,nil,{{9595},{9619}}},
        },

        [3125] = {
            [questKeys.objectives] = {nil,nil,{{9596},{9620}}},
        },

        [3126] = {
            [questKeys.objectives] = {nil,nil,{{9593},{9606}}},
        },

        [3127] = {
            [questKeys.objectives] = {nil,nil,{{9597},{9621}}},
        },

        [3128] = {
            [questKeys.preQuestSingle] = {},
        },

        [3129] = {
            [questKeys.preQuestSingle] = {3127,3128},
        },

        [3141] = {
            [questKeys.objectives] = nil,
        },

        [3161] = {
            [questKeys.objectives] = {nil,nil,{{8443},{9978}}},
            [questKeys.requiredSourceItems] = {9978},
        },

        [3181] = {
            [questKeys.questLevel] = 48,
            [questKeys.objectives] = {nil,nil,{{10005}}},
        },

        [3182] = {
            [questKeys.questLevel] = 48,
            [questKeys.objectives] = {nil,nil,{{10005}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [3201] = {
            [questKeys.questLevel] = 48,
            [questKeys.objectives] = {nil,nil,{{10022}}},
        },

        [3241] = {
            [questKeys.questLevel] = 11,
            [questKeys.requiredLevel] = 8,
            [questKeys.objectivesText] = {"Bring them to Tonga Runetotem."},
            [questKeys.questFlags] = 8,
        },

        [3301] = {
            [questKeys.objectivesText] = {"Speak with Mura Runetotem in the Sepulcher."},
            [questKeys.objectives] = {nil,nil,{{10414}}},
        },

        [3321] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {2771,2772,2773},
        },

        [3341] = {
            [questKeys.questLevel] = 42,
            [questKeys.requiredLevel] = 37,
        },

        [3361] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [3363] = {
            [questKeys.specialFlags] = 257,
        },

        [3364] = {
            [questKeys.objectives] = {nil,nil,{{10439}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3365] = {
            [questKeys.objectives] = {nil,nil,{{10440}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3366] = {
            [questKeys.objectives] = {nil,nil,{{10441}}},
        },

        [3367] = {
            [questKeys.questLevel] = 48,
        },

        [3368] = {
            [questKeys.questLevel] = 48,
            [questKeys.objectives] = {nil,nil,{{10443}}},
        },

        [3369] = {
            [questKeys.objectives] = {nil,nil,{{10649}}},
        },

        [3370] = {
            [questKeys.objectives] = {nil,nil,{{10649}}},
        },

        [3371] = {
            [questKeys.questLevel] = 55,
            [questKeys.objectivesText] = {"Return to the Searing Gorge and find Dorius's archaeology unit. "},
        },

        [3372] = {
            [questKeys.questLevel] = 52,
        },

        [3373] = {
            [questKeys.objectives] = {nil,nil,{{10454}}},
        },

        [3374] = {
            [questKeys.objectivesText] = {"Bring the Oathstone of Ysera's Dragonflight and the Chained Essence of Eranikus to Itharius in the Swamp of Sorrows.  It is there that you will make your choice to aid Ysera's Dragonflight or not."},
            [questKeys.objectives] = {nil,nil,{{10589},{10455}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [3375] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [3376] = {
            [questKeys.questFlags] = 8,
        },

        [3377] = {
            [questKeys.objectives] = nil,
        },

        [3383] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 48,
            [questKeys.objectives] = {{{8394},{8387},{8389},{8388}}},
            [questKeys.questFlags] = 8,
        },

        [3384] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 48,
            [questKeys.objectives] = {nil,nil,{{10478}}},
            [questKeys.questFlags] = 8,
        },

        [3385] = {
            [questKeys.requiredSkill] = {197,250},
        },

        [3401] = {
            [questKeys.questLevel] = 48,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [3402] = {
            [questKeys.requiredSkill] = {197,1},
        },

        [3403] = {
            [questKeys.questLevel] = 48,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [3404] = {
            [questKeys.questLevel] = 48,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [3405] = {
            [questKeys.questLevel] = 48,
            [questKeys.requiredLevel] = 55,
            [questKeys.questFlags] = 8,
        },

        [3422] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3423] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3424] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3425] = {
            [questKeys.questLevel] = 48,
            [questKeys.requiredLevel] = 48,
            [questKeys.questFlags] = 8,
        },

        [3441] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
        },

        [3446] = {
            [questKeys.objectives] = {nil,nil,{{10466}}},
        },

        [3453] = {
            [questKeys.objectives] = nil,
        },

        [3454] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3461] = {
            [questKeys.objectives] = {nil,nil,{{10445}}},
        },

        [3463] = {
            [questKeys.objectivesText] = {"Set the North, South, East, and West Sentry Towers on fire by using the Torch of Retribution inside each of the buildings. "},
            [questKeys.nextQuestInChain] = 0,
        },

        [3481] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3482] = {
            [questKeys.objectives] = {nil,nil,{{10590}}},
        },

        [3483] = {
            [questKeys.preQuestSingle] = {3451},
            [questKeys.parentQuest] = 0,
            [questKeys.specialFlags] = 0,
        },

        [3504] = {
            [questKeys.objectivesText] = {"Deliver the Sealed Letter to Ag'tor to Ag'tor Bloodfist in Azshara."},
            [questKeys.objectives] = {nil,nil,{{10643}}},
        },

        [3507] = {
            [questKeys.objectives] = {nil,nil,{{10597}}},
        },

        [3511] = {
            [questKeys.objectives] = {nil,nil,{{10610}}},
        },

        [3512] = {
            [questKeys.requiredRaces] = 1791,
        },

        [3513] = {
            [questKeys.objectives] = {nil,nil,{{10621}}},
        },

        [3515] = {
            [questKeys.questLevel] = 42,
            [questKeys.requiredLevel] = 45,
            [questKeys.nextQuestInChain] = 3516,
            [questKeys.questFlags] = 8,
        },

        [3516] = {
            [questKeys.questLevel] = 42,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3518] = {
            [questKeys.objectives] = {nil,nil,{{10538}}},
        },

        [3519] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [3520] = {
            [questKeys.objectives] = {{{8612}},nil,{{10699}}},
        },

        [3521] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [3522] = {
            [questKeys.objectives] = {nil,nil,{{10642}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [3523] = {
            [questKeys.objectives] = {nil,nil,{{10682}}},
        },

        [3526] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3629,3630,3632,3633,3634,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3639,
        },

        [3529] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3530] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3531] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 45,
            [questKeys.questFlags] = 8,
        },

        [3541] = {
            [questKeys.objectives] = {nil,nil,{{10539}}},
        },

        [3542] = {
            [questKeys.objectives] = {nil,nil,{{10540}}},
        },

        [3561] = {
            [questKeys.objectives] = {nil,nil,{{10541}}},
        },

        [3562] = {
            [questKeys.objectives] = {nil,nil,{{10678}}},
        },

        [3563] = {
            [questKeys.objectives] = {nil,nil,{{10680}}},
        },

        [3564] = {
            [questKeys.objectives] = {nil,nil,{{10679}}},
        },

        [3565] = {
            [questKeys.objectives] = {nil,nil,{{10681}}},
        },

        [3566] = {
            [questKeys.questLevel] = 52,
            [questKeys.objectivesText] = {"Slay Lathoric the Black and Obsidion, and return to Thorius in Ironforge with the Head of Lathoric the Black and the Heart of Obsidion. "},
        },

        [3569] = {
            [questKeys.objectives] = {nil,nil,{{10712}}},
        },

        [3581] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 40,
            [questKeys.objectivesText] = {"Speak to Saern Priderunner again to learn the Plainsrunning skill."},
            [questKeys.questFlags] = 8,
        },

        [3601] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3602] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3621] = {
            [questKeys.objectives] = {nil,nil,{{10738}}},
        },

        [3622] = {
            [questKeys.questLevel] = 41,
            [questKeys.requiredLevel] = 41,
            [questKeys.questFlags] = 8,
        },

        [3623] = {
            [questKeys.questLevel] = 41,
            [questKeys.requiredLevel] = 41,
            [questKeys.questFlags] = 8,
        },

        [3624] = {
            [questKeys.questLevel] = 41,
            [questKeys.requiredLevel] = 41,
            [questKeys.questFlags] = 8,
        },

        [3625] = {
            [questKeys.objectives] = nil,
        },

        [3628] = {
            [questKeys.objectives] = {nil,nil,{{10759},{10757}}},
        },

        [3629] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3630,3632,3633,3634,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3639,
        },

        [3630] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3632,3633,3634,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3641,
        },

        [3631] = {
            [questKeys.requiredRaces] = 690,
        },

        [3632] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3633,3634,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3641,
        },

        [3633] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3632,3634,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3639,
        },

        [3634] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3632,3633,3635,3637,4181},
            [questKeys.nextQuestInChain] = 3641,
        },

        [3635] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3632,3633,3634,3637,4181},
            [questKeys.nextQuestInChain] = 3643,
        },

        [3636] = {
            [questKeys.questLevel] = 42,
            [questKeys.requiredLevel] = 39,
        },

        [3637] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3632,3633,3634,3635,4181},
            [questKeys.nextQuestInChain] = 3643,
        },

        [3638] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [3639] = {
            [questKeys.preQuestSingle] = {3526,3629,3633,4181},
            [questKeys.exclusiveTo] = {},
        },

        [3640] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [3641] = {
            [questKeys.preQuestSingle] = {3630,3632,3634},
            [questKeys.exclusiveTo] = {},
        },

        [3642] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [3643] = {
            [questKeys.preQuestSingle] = {3635,3637},
            [questKeys.exclusiveTo] = {},
        },

        [3644] = {
            [questKeys.preQuestSingle] = {3639},
        },

        [3645] = {
            [questKeys.preQuestSingle] = {3641},
        },

        [3646] = {
            [questKeys.preQuestSingle] = {3639},
        },

        [3647] = {
            [questKeys.preQuestSingle] = {3643},
        },

        [3661] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3681] = {
            [questKeys.exclusiveTo] = {2998},
        },

        [3701] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3702] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 10,
        },

        [3721] = {
            [questKeys.preQuestSingle] = {648,836,2767},
        },

        [3761] = {
            [questKeys.preQuestSingle] = {936},
            [questKeys.nextQuestInChain] = 0,
        },

        [3762] = {
            [questKeys.exclusiveTo] = {},
        },

        [3763] = {
            [questKeys.exclusiveTo] = {},
        },

        [3764] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3765] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [3781] = {
            [questKeys.objectives] = {nil,nil,{{11103}}},
        },

        [3782] = {
            [questKeys.objectives] = {nil,nil,{{11103}}},
        },

        [3784] = {
            [questKeys.exclusiveTo] = {},
        },

        [3785] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 1,
        },

        [3786] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [3787] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [3788] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [3789] = {
            [questKeys.exclusiveTo] = {},
        },

        [3790] = {
            [questKeys.exclusiveTo] = {},
        },

        [3791] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {3785},
        },

        [3825] = {
            [questKeys.specialFlags] = 32,
        },

        [3841] = {
            [questKeys.objectives] = {nil,nil,{{11102}}},
        },

        [3842] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [3843] = {
            [questKeys.objectives] = {nil,nil,{{11471}}},
        },

        [3883] = {
            [questKeys.objectivesText] = {"Use the Scraping Vial to collect a Hive Wall Sample from one of the Gorishi hive hatcheries in Un'Goro Crater.  Look for the chambers with the hanging larval spawns.","","Bring the Hive Wall Sample to Hol'anyee Marshal in Un'Goro Crater."},
        },

        [3884] = {
            [questKeys.objectives] = {nil,nil,{{11116}}},
        },

        [3885] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 50,
            [questKeys.objectivesText] = {"Escort Petra and Dadanga!"},
            [questKeys.questFlags] = 2,
        },

        [3901] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectivesText] = {"Kill 12 Rattlecage Skeletons, and then return to Shadow Priest Sarvis in Deathknell when you are done."},
            [questKeys.questFlags] = 8,
        },

        [3902] = {
            [questKeys.questFlags] = 8,
        },

        [3903] = {
            [questKeys.preQuestSingle] = {33},
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 8,
        },

        [3904] = {
            [questKeys.preQuestSingle] = {3903},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 8,
        },

        [3905] = {
            [questKeys.objectives] = {nil,nil,{{11125}}},
            [questKeys.questFlags] = 0,
        },

        [3908] = {
            [questKeys.objectives] = {nil,nil,{{11133}}},
        },

        [3909] = {
            [questKeys.requiredSourceItems] = {11242},
        },

        [3910] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 50,
            [questKeys.objectivesText] = {"Escort Petra and Dadanga back to Un'Goro."},
            [questKeys.questFlags] = 2,
        },

        [3913] = {
            [questKeys.objectives] = {nil,nil,{{11136}}},
        },

        [3914] = {
            [questKeys.objectives] = {nil,nil,{{11162}}},
        },

        [3921] = {
            [questKeys.objectives] = {nil,nil,{{11142}}},
        },

        [3923] = {
            [questKeys.objectives] = {nil,nil,{{11146}}},
        },

        [3961] = {
            [questKeys.objectives] = {nil,nil,{{11522}}},
        },

        [3962] = {
            [questKeys.objectives] = {{{9376}},nil,{{11179},{11522}}},
        },

        [3982] = {
            [questKeys.objectives] = nil,
        },

        [4001] = {
            [questKeys.objectives] = nil,
        },

        [4003] = {
            [questKeys.objectivesText] = {"Slay Emperor Dagran Thaurissan and free Princess Moira Bronzebeard from his evil spell. "},
        },

        [4022] = {
            [questKeys.specialFlags] = 2,
        },

        [4023] = {
            [questKeys.exclusiveTo] = {4022},
        },

        [4024] = {
            [questKeys.preQuestSingle] = {4022,4023},
        },

        [4062] = {
            [questKeys.objectives] = {nil,nil,{{11267}}},
        },

        [4063] = {
            [questKeys.objectivesText] = {"Find and slay Golem Lord Argelmach. Return his head to Lotwil. You will also need to collect 10 Intact Elemental Cores from the Ragereaver Golems and Warbringer Constructs protecting Argelmach. You know this because you are psychic. "},
        },

        [4082] = {
            [questKeys.requiredLevel] = 50,
        },

        [4103] = {
            [questKeys.preQuestSingle] = {4101},
            [questKeys.specialFlags] = 0,
        },

        [4104] = {
            [questKeys.preQuestSingle] = {4101},
            [questKeys.specialFlags] = 0,
        },

        [4105] = {
            [questKeys.preQuestSingle] = {4101},
            [questKeys.specialFlags] = 0,
        },

        [4106] = {
            [questKeys.preQuestSingle] = {4101},
            [questKeys.specialFlags] = 0,
        },

        [4107] = {
            [questKeys.preQuestSingle] = {4101},
            [questKeys.specialFlags] = 0,
        },

        [4108] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {4103},
        },

        [4109] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {4104},
        },

        [4110] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {4105},
        },

        [4111] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {4106},
        },

        [4112] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {4107},
        },

        [4113] = {
            [questKeys.specialFlags] = 257,
        },

        [4114] = {
            [questKeys.specialFlags] = 257,
        },

        [4115] = {
            [questKeys.specialFlags] = 257,
        },

        [4116] = {
            [questKeys.specialFlags] = 257,
        },

        [4117] = {
            [questKeys.specialFlags] = 257,
        },

        [4118] = {
            [questKeys.specialFlags] = 257,
        },

        [4119] = {
            [questKeys.specialFlags] = 257,
        },

        [4123] = {
            [questKeys.requiredSourceItems] = {},
        },

        [4126] = {
            [questKeys.preQuestSingle] = {4128},
            [questKeys.breadcrumbs] = {},
        },

        [4127] = {
            [questKeys.objectives] = {nil,nil,{{11462}}},
        },

        [4128] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [4129] = {
            [questKeys.objectives] = {nil,nil,{{11462}}},
        },

        [4134] = {
            [questKeys.preQuestSingle] = {4133},
        },

        [4135] = {
            [questKeys.objectivesText] = {"Now that Raschal's last known whereabouts have been discovered, continue your search for him or his remains in the Writhing Deep.  According to the note, it is located to the south of the Woodpaw gnoll camps."},
        },

        [4136] = {
            [questKeys.preQuestSingle] = {4324},
        },

        [4142] = {
            [questKeys.objectives] = {nil,nil,{{11316}}},
        },

        [4144] = {
            [questKeys.specialFlags] = 0,
        },

        [4146] = {
            [questKeys.objectives] = {nil,nil,{{11319},{11318}}},
        },

        [4181] = {
            [questKeys.objectives] = {nil,nil,{{10789}}},
            [questKeys.exclusiveTo] = {3526,3629,3630,3632,3633,3634,3635,3637},
            [questKeys.nextQuestInChain] = 3639,
        },

        [4183] = {
            [questKeys.objectivesText] = {"Travel to Lakeshire in Redridge Mountains and deliver Helendis Riverhorn's Letter to Magistrate Solomon. "},
            [questKeys.objectives] = {nil,nil,{{11366}}},
            [questKeys.preQuestSingle] = {4182},
        },

        [4184] = {
            [questKeys.objectives] = {nil,nil,{{11367}}},
            [questKeys.preQuestSingle] = {4183},
        },

        [4185] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {4184},
        },

        [4186] = {
            [questKeys.objectives] = {nil,nil,{{11368}}},
            [questKeys.preQuestSingle] = {4185},
        },

        [4221] = {
            [questKeys.specialFlags] = 257,
        },

        [4222] = {
            [questKeys.specialFlags] = 257,
        },

        [4224] = {
            [questKeys.objectives] = nil,
        },

        [4242] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4244] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4264] = {
            [questKeys.objectives] = {nil,nil,{{11446}}},
            [questKeys.preQuestSingle] = {4242},
        },

        [4267] = {
            [questKeys.objectives] = {nil,nil,{{11466}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [4281] = {
            [questKeys.objectives] = {nil,nil,{{11463}}},
        },

        [4282] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4289] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4295] = {
            [questKeys.requiredLevel] = 1,
        },

        [4299] = {
            [questKeys.questLevel] = 50,
            [questKeys.requiredLevel] = 50,
            [questKeys.objectivesText] = {"Place the PX83-Enigmatron in the Tomb of the Seven,then return to Maxwort Uberglint."},
            [questKeys.sourceItemId] = 11473,
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [4321] = {
            [questKeys.preQuestSingle] = {4285,4287,4288},
        },

        [4323] = {
            [questKeys.questLevel] = 26,
            [questKeys.requiredLevel] = 24,
            [questKeys.objectivesText] = {"Bring 7 Spotted Hyena Pelts to TESTTAUREN at Freewind Post."},
            [questKeys.objectives] = {nil,nil,{{11507}}},
            [questKeys.questFlags] = 8,
        },

        [4341] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4342] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 10,
        },

        [4343] = {
            [questKeys.specialFlags] = 257,
        },

        [4362] = {
            [questKeys.requiredRaces] = 1101,
        },

        [4401] = {
            [questKeys.specialFlags] = 257,
        },

        [4402] = {
            [questKeys.objectivesText] = {"Bring Galgar 10 Cactus Apples. You remember him saying that they could be found near cactuses."},
            [questKeys.questFlags] = 8,
        },

        [4403] = {
            [questKeys.specialFlags] = 257,
        },

        [4443] = {
            [questKeys.specialFlags] = 257,
        },

        [4444] = {
            [questKeys.specialFlags] = 257,
        },

        [4445] = {
            [questKeys.specialFlags] = 257,
        },

        [4446] = {
            [questKeys.specialFlags] = 257,
        },

        [4447] = {
            [questKeys.specialFlags] = 257,
        },

        [4448] = {
            [questKeys.specialFlags] = 257,
        },

        [4451] = {
            [questKeys.objectives] = {nil,nil,{{11818}}},
        },

        [4461] = {
            [questKeys.specialFlags] = 257,
        },

        [4462] = {
            [questKeys.specialFlags] = 257,
        },

        [4464] = {
            [questKeys.specialFlags] = 257,
        },

        [4465] = {
            [questKeys.specialFlags] = 257,
        },

        [4466] = {
            [questKeys.specialFlags] = 257,
        },

        [4467] = {
            [questKeys.specialFlags] = 257,
        },

        [4485] = {
            [questKeys.exclusiveTo] = {4486},
        },

        [4486] = {
            [questKeys.exclusiveTo] = {4485},
        },

        [4489] = {
            [questKeys.requiredRaces] = 690,
        },

        [4490] = {
            [questKeys.preQuestSingle] = {},
        },

        [4491] = {
            [questKeys.requiredSourceItems] = {11804},
        },

        [4492] = {
            [questKeys.objectives] = {nil,nil,{{15722}}},
        },

        [4493] = {
            [questKeys.exclusiveTo] = {4494},
        },

        [4494] = {
            [questKeys.preQuestSingle] = {32},
            [questKeys.exclusiveTo] = {4493},
        },

        [4495] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 4,
        },

        [4501] = {
            [questKeys.requiredLevel] = 49,
            [questKeys.objectivesText] = {"Kill 10 Pterrordax and 15 Frenzied Pterrordax, then speak to Spraggle Frock at Marshal's Refuge."},
            [questKeys.objectives] = {{{9166},{9167}}},
        },

        [4508] = {
            [questKeys.objectives] = {nil,nil,{{11844}}},
        },

        [4509] = {
            [questKeys.objectives] = {nil,nil,{{11844}}},
        },

        [4510] = {
            [questKeys.objectives] = {nil,nil,{{11843}}},
        },

        [4511] = {
            [questKeys.objectives] = {nil,nil,{{11843}}},
        },

        [4512] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [4513] = {
            [questKeys.requiredSourceItems] = {},
        },

        [4541] = {
            [questKeys.questFlags] = 8,
        },

        [4542] = {
            [questKeys.objectives] = {nil,nil,{{11886}}},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [4561] = {
            [questKeys.parentQuest] = 0,
        },

        [4581] = {
            [questKeys.objectives] = {nil,nil,{{12060}}},
            [questKeys.breadcrumbForQuestId] = 1011,
        },

        [4601] = {
            [questKeys.exclusiveTo] = {},
        },

        [4602] = {
            [questKeys.exclusiveTo] = {},
        },

        [4603] = {
            [questKeys.preQuestSingle] = {4605},
            [questKeys.exclusiveTo] = {},
        },

        [4604] = {
            [questKeys.preQuestSingle] = {4606},
            [questKeys.exclusiveTo] = {},
        },

        [4605] = {
            [questKeys.preQuestSingle] = {4601},
            [questKeys.exclusiveTo] = {},
        },

        [4606] = {
            [questKeys.preQuestSingle] = {4602},
            [questKeys.exclusiveTo] = {},
        },

        [4621] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.requiredMaxRep] = {21,1},
            [questKeys.preQuestSingle] = {},
        },

        [4641] = {
            [questKeys.objectivesText] = {"Speak with Gornek. You recall Kaltunk marking your map with his location and mentioning that Gornek resided in the Den, a building to the west. ",""},
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 8,
        },

        [4642] = {
            [questKeys.preQuestSingle] = {4293,4294},
        },

        [4661] = {
            [questKeys.parentQuest] = 0,
        },

        [4722] = {
            [questKeys.objectives] = {nil,nil,{{12289}}},
        },

        [4723] = {
            [questKeys.objectives] = {nil,nil,{{12242}}},
        },

        [4725] = {
            [questKeys.objectives] = {nil,nil,{{12292}}},
        },

        [4726] = {
            [questKeys.objectives] = {nil,nil,{{12283},{12284}}},
        },

        [4727] = {
            [questKeys.objectives] = {nil,nil,{{12289}}},
        },

        [4728] = {
            [questKeys.objectives] = {nil,nil,{{12242}}},
        },

        [4730] = {
            [questKeys.objectives] = {nil,nil,{{12242}}},
        },

        [4731] = {
            [questKeys.objectives] = {nil,nil,{{12292}}},
        },

        [4732] = {
            [questKeys.objectives] = {nil,nil,{{12289}}},
        },

        [4733] = {
            [questKeys.objectives] = {nil,nil,{{12242}}},
        },

        [4734] = {
            [questKeys.objectives] = {nil,nil,{{12286}}},
        },

        [4735] = {
            [questKeys.objectives] = {nil,nil,{{12241},{12287}}},
        },

        [4736] = {
            [questKeys.exclusiveTo] = {},
        },

        [4737] = {
            [questKeys.exclusiveTo] = {},
        },

        [4738] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.exclusiveTo] = {},
        },

        [4739] = {
            [questKeys.exclusiveTo] = {},
        },

        [4740] = {
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Find and slay the murloc known as Murkdeep.  The creature is thought to be defending the murloc huts south of Auberdine along the water.","","Report the death of Murkdeep to Sentinel Glynda Nal'Shea in Auberdine."},
        },

        [4742] = {
            [questKeys.objectivesText] = {"Find the three gemstones of command: The Gemstone of Smolderthorn, Gemstone of Spirestone, and Gemstone of Bloodaxe. Return them, along with the Unadorned Seal of Ascension, to Vaelan.","","The Generals, as told to you by Vaelan, are: War Master Voone of the Smolderthorn; Highlord Omokk of the Spirestone; and Overlord Wyrmthalak  of the Bloodaxe."},
        },

        [4743] = {
            [questKeys.requiredSourceItems] = {},
        },

        [4762] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4764] = {
            [questKeys.preQuestSingle] = {4766},
        },

        [4765] = {
            [questKeys.objectives] = {nil,nil,{{12437}}},
        },

        [4768] = {
            [questKeys.preQuestSingle] = {4769},
        },

        [4771] = {
            [questKeys.objectivesText] = {"Place Dawn's Gambit in the Viewing Room of the Scholomance.  Defeat Vectus, then return to Betina Bigglezink."},
            [questKeys.preQuestSingle] = {5531},
        },

        [4786] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 2,
        },

        [4808] = {
            [questKeys.objectives] = {nil,nil,{{12438}}},
        },

        [4810] = {
            [questKeys.objectives] = {nil,nil,{{12445}}},
        },

        [4811] = {
            [questKeys.objectivesText] = {"Travel east of Auberdine and look for a large, red crystal along Darkshore's eastern mountain range.  Report back what you find to Sentinel Glynda Nal'Shea in Auberdine."},
        },

        [4813] = {
            [questKeys.requiredRaces] = 0,
        },

        [4822] = {
            [questKeys.objectivesText] = {"Get some Strawberry Ice Cream for your ward.  The lad seems to prefer Tigule and Foror's brand ice cream."},
            [questKeys.preQuestSingle] = {1479},
        },

        [4841] = {
            [questKeys.preQuestSingle] = {4542},
            [questKeys.breadcrumbs] = {},
        },

        [4866] = {
            [questKeys.objectives] = nil,
        },

        [4867] = {
            [questKeys.objectivesText] = {"Read Warosh's Scroll.  Bring Warosh's Mojo to Warosh."},
            [questKeys.requiredSourceItems] = {},
        },

        [4882] = {
            [questKeys.objectives] = {nil,nil,{{12558}}},
            [questKeys.preQuestSingle] = {},
        },

        [4883] = {
            [questKeys.objectives] = {nil,nil,{{12558}}},
        },

        [4901] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [4905] = {
            [questKeys.objectivesText] = {"Defend Kanati Greycloud"},
            [questKeys.questFlags] = 8,
        },

        [4961] = {
            [questKeys.preQuestSingle] = {1799},
        },

        [4962] = {
            [questKeys.objectives] = {nil,nil,{{12647},{12648}}},
            [questKeys.preQuestSingle] = {1799},
        },

        [4963] = {
            [questKeys.objectives] = {nil,nil,{{12646},{12649}}},
            [questKeys.preQuestSingle] = {1799},
        },

        [4964] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {4962},
            [questKeys.exclusiveTo] = {4975},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [4965] = {
            [questKeys.exclusiveTo] = {},
        },

        [4966] = {
            [questKeys.objectives] = nil,
        },

        [4967] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.exclusiveTo] = {},
        },

        [4968] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [4969] = {
            [questKeys.exclusiveTo] = {},
        },

        [4971] = {
            [questKeys.objectivesText] = {"Use the Temporal Displacer near one of Andorhal's silos and uncover Temporal Parasites.","","Slay 15 Temporal Parasites, and then return the Temporal Displacer to Chromie in the Andorhal Inn, Western Plaguelands."},
            [questKeys.objectives] = {{{10717}},nil,{{12627}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [4972] = {
            [questKeys.objectivesText] = {"Locate 5 Andorhal Watches, found in lockboxes amongst the rubble of the city.  Return with them to Chromie in the Andorhal Inn, Western Plaguelands."},
            [questKeys.nextQuestInChain] = 0,
        },

        [4975] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {4963},
            [questKeys.exclusiveTo] = {4964},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [4976] = {
            [questKeys.objectives] = {nil,nil,{{12642}}},
        },

        [4983] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{12652}}},
        },

        [4984] = {
            [questKeys.objectivesText] = {"Destroy 8 Diseased Wolves, and then return to Mulgris Deepriver at the Writhing Haunt, Western Plaguelands.",""},
        },

        [4986] = {
            [questKeys.objectivesText] = {"Based on the magic enchanted within the Glyphed Oaken Branch, its delivery to the Cenarion Circle in Darnassus is the next step the tauren druid sought.  Seek one of the druids there for assistance."},
            [questKeys.objectives] = {nil,nil,{{12663}}},
        },

        [4987] = {
            [questKeys.objectivesText] = {"Based on the magic enchanted within the Glyphed Oaken Branch, its delivery to the Cenarion Circle in Thunder Bluff is the next step the tauren druid sought.  Seek one of the druids there for assistance."},
            [questKeys.objectives] = {nil,nil,{{12663}}},
        },

        [5002] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{12770}}},
        },

        [5021] = {
            [questKeys.objectivesText] = {"The ramblings of the ghostly woman indicated that she needed a package delivered.  She claimed that it was where her horse was.  As to where the horse is or where the package was to be delivered - the ghost remains incomprehensible."},
        },

        [5022] = {
            [questKeys.objectivesText] = {"Check with the Royal Factors of Stormwind to learn the whereabouts of an Emma Felstone.  There is usually a census officer located in City Hall."},
            [questKeys.objectives] = {nil,nil,{{12724}}},
        },

        [5023] = {
            [questKeys.objectivesText] = {"Check with the Royal Overseers of the Undercity to learn the whereabouts of a Jeremiah Felstone.  There is usually a census officer located near guild and tabard registration."},
            [questKeys.objectives] = {nil,nil,{{12724}}},
        },

        [5041] = {
            [questKeys.preQuestSingle] = {871},
        },

        [5047] = {
            [questKeys.objectives] = {nil,nil,{{12710}}},
        },

        [5048] = {
            [questKeys.objectivesText] = {"Find Ol' Emma in Stormwind and see if she is in fact Emma Felstone.  If she is, then perhaps she'd like the package Janice Felstone made for her."},
            [questKeys.objectives] = {nil,nil,{{12724}}},
        },

        [5049] = {
            [questKeys.objectivesText] = {"Find Jeremiah Payson in the Undercity and see if he is in fact Jeremiah Felstone.  If he is, then perhaps he'd like the package Janice Felstone made for him."},
            [questKeys.objectives] = {nil,nil,{{12724}}},
        },

        [5050] = {
            [questKeys.objectives] = {nil,nil,{{12721}}},
        },

        [5053] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Test quest to see if mail is sent to your mailbox. Just hit complete,then go check your mail.","","Have a nice day."},
            [questKeys.questFlags] = 8,
        },

        [5056] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [5057] = {
            [questKeys.objectivesText] = {"Bring Storm Shadowhoof's Marker to Melor Stonehoof in Thunder Bluff."},
        },

        [5061] = {
            [questKeys.objectives] = {nil,nil,{{15885}}},
        },

        [5063] = {
            [questKeys.specialFlags] = 0,
        },

        [5066] = {
            [questKeys.objectivesText] = {"Seek out Commander Ashlam Valorfist.  His base camp is located at Chillwind Camp, north of the Alterac Mountains."},
            [questKeys.exclusiveTo] = {},
        },

        [5067] = {
            [questKeys.specialFlags] = 0,
        },

        [5068] = {
            [questKeys.specialFlags] = 0,
        },

        [5083] = {
            [questKeys.objectives] = {nil,nil,{{12771}}},
        },

        [5085] = {
            [questKeys.objectives] = {nil,nil,{{12813}}},
        },

        [5088] = {
            [questKeys.objectives] = {nil,nil,{{12785},{12925}}},
        },

        [5089] = {
            [questKeys.objectives] = {nil,nil,{{12780}}},
        },

        [5090] = {
            [questKeys.objectivesText] = {"Seek out Commander Ashlam Valorfist.  His base camp is located at Chillwind Camp, north of the Alterac Mountains."},
            [questKeys.exclusiveTo] = {},
        },

        [5091] = {
            [questKeys.objectivesText] = {"Seek out Commander Ashlam Valorfist.  His base camp is located at Chillwind Camp, north of the Alterac Mountains."},
            [questKeys.exclusiveTo] = {},
        },

        [5092] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [5093] = {
            [questKeys.objectivesText] = {"Seek out High Executor Derrington.  His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity."},
            [questKeys.exclusiveTo] = {},
        },

        [5094] = {
            [questKeys.objectivesText] = {"Seek out High Executor Derrington.  His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity."},
            [questKeys.exclusiveTo] = {},
        },

        [5095] = {
            [questKeys.objectivesText] = {"Seek out High Executor Derrington.  His base camp is located at the Bulwark, east of Tirisfal Glades and the Undercity."},
            [questKeys.exclusiveTo] = {},
        },

        [5096] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 34,
        },

        [5097] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [5098] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [5103] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.requiredSkill] = {164,275},
        },

        [5122] = {
            [questKeys.specialFlags] = 0,
        },

        [5123] = {
            [questKeys.objectives] = {nil,nil,{{12842}}},
        },

        [5124] = {
            [questKeys.requiredSkill] = {},
        },

        [5126] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = nil,
            [questKeys.requiredSkill] = {164,285},
        },

        [5127] = {
            [questKeys.requiredSkill] = {164,285},
        },

        [5128] = {
            [questKeys.objectives] = {nil,nil,{{12842}}},
        },

        [5142] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5143] = {
            [questKeys.preQuestSingle] = {},
        },

        [5147] = {
            [questKeys.requiredLevel] = 25,
        },

        [5148] = {
            [questKeys.preQuestSingle] = {},
        },

        [5149] = {
            [questKeys.breadcrumbs] = {},
        },

        [5151] = {
            [questKeys.objectives] = {nil,nil,{{12942},{12946}}},
        },

        [5158] = {
            [questKeys.objectives] = {nil,nil,{{12907}}},
        },

        [5159] = {
            [questKeys.objectives] = {nil,nil,{{12906}}},
        },

        [5160] = {
            [questKeys.objectives] = {nil,nil,{{12923}}},
        },

        [5163] = {
            [questKeys.objectives] = {{{10978},{7583},{10977}},nil,{{12928}}},
            [questKeys.specialFlags] = 32,
        },

        [5165] = {
            [questKeys.specialFlags] = 32,
        },

        [5202] = {
            [questKeys.objectives] = {nil,nil,{{13140}}},
        },

        [5205] = {
            [questKeys.questLevel] = 49,
            [questKeys.requiredLevel] = 49,
            [questKeys.questFlags] = 8,
        },

        [5206] = {
            [questKeys.objectives] = {nil,nil,{{13155},{13156}}},
            [questKeys.preQuestSingle] = {5168,5181},
        },

        [5207] = {
            [questKeys.questLevel] = 49,
            [questKeys.requiredLevel] = 49,
            [questKeys.questFlags] = 8,
        },

        [5208] = {
            [questKeys.questLevel] = 49,
            [questKeys.requiredLevel] = 49,
            [questKeys.questFlags] = 8,
        },

        [5209] = {
            [questKeys.questLevel] = 49,
            [questKeys.requiredLevel] = 49,
            [questKeys.questFlags] = 8,
        },

        [5210] = {
            [questKeys.objectives] = {nil,nil,{{13202}}},
        },

        [5212] = {
            [questKeys.objectivesText] = {"Recover 20 Plagued Flesh Samples from Stratholme and return them to Betina Bigglezink. You suspect that any creature in Stratholme would have said flesh sample."},
        },

        [5216] = {
            [questKeys.objectivesText] = {"Go to Felstone Field in Western Plaguelands to locate and defeat the Cauldron Lord present there.  It may have a key that will allow access to the cauldron.  You must have the Empty Felstone Field Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13194},{13186}}},
        },

        [5217] = {
            [questKeys.objectives] = {nil,nil,{{13190}}},
        },

        [5218] = {
            [questKeys.preQuestSingle] = {5216,5229},
        },

        [5219] = {
            [questKeys.objectivesText] = {"Go to Dalson's Tears in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Dalson's Tears Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13195},{13187}}},
        },

        [5220] = {
            [questKeys.objectives] = {nil,nil,{{13191}}},
        },

        [5221] = {
            [questKeys.preQuestSingle] = {5219,5231},
        },

        [5222] = {
            [questKeys.objectivesText] = {"Go to the Writhing Haunt in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Writhing Haunt Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13197},{13188}}},
        },

        [5223] = {
            [questKeys.objectives] = {nil,nil,{{13192}}},
        },

        [5224] = {
            [questKeys.preQuestSingle] = {5222,5233},
        },

        [5225] = {
            [questKeys.objectivesText] = {"Go to Gahrron's Withering in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Gahrron's Withering Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13196},{13189}}},
        },

        [5226] = {
            [questKeys.objectives] = {nil,nil,{{13193}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [5227] = {
            [questKeys.preQuestSingle] = {5225,5235},
        },

        [5229] = {
            [questKeys.objectivesText] = {"Go to Felstone Field in Western Plaguelands to locate and defeat the Cauldron Lord present there.  It may have a key that will allow access to the cauldron.  You must have the Empty Felstone Field Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13194},{13186}}},
        },

        [5230] = {
            [questKeys.objectives] = {nil,nil,{{13190}}},
        },

        [5231] = {
            [questKeys.objectivesText] = {"Go to Dalson's Tears in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Dalson's Tears Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13195},{13187}}},
        },

        [5232] = {
            [questKeys.objectives] = {nil,nil,{{13191}}},
        },

        [5233] = {
            [questKeys.objectivesText] = {"Go to the Writhing Haunt in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Writhing Haunt Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13197},{13188}}},
        },

        [5234] = {
            [questKeys.objectives] = {nil,nil,{{13192}}},
        },

        [5235] = {
            [questKeys.objectivesText] = {"Go to Gahrron's Withering in Western Plaguelands to locate and defeat the Cauldron Lord present there, and use its key to gain access to the cauldron.  You must have the Empty Gahrron's Withering Bottle with you to secure a sample of the poisons used inside the cauldron."},
            [questKeys.objectives] = {nil,nil,{{13196},{13189}}},
        },

        [5236] = {
            [questKeys.objectives] = {nil,nil,{{13193}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [5248] = {
            [questKeys.objectives] = {nil,nil,{{13347}}},
        },

        [5249] = {
            [questKeys.exclusiveTo] = {},
        },

        [5250] = {
            [questKeys.exclusiveTo] = {},
        },

        [5252] = {
            [questKeys.objectives] = {nil,nil,{{13347}}},
        },

        [5253] = {
            [questKeys.objectives] = {nil,nil,{{13347}}},
        },

        [5261] = {
            [questKeys.questFlags] = 8,
        },

        [5262] = {
            [questKeys.objectives] = {nil,nil,{{13250}}},
        },

        [5303] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.questFlags] = 8,
        },

        [5304] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.questFlags] = 8,
        },

        [5305] = {
            [questKeys.exclusiveTo] = {},
        },

        [5361] = {
            [questKeys.objectives] = {nil,nil,{{13507}}},
        },

        [5381] = {
            [questKeys.objectives] = {nil,nil,{{13542},{14523}}},
        },

        [5383] = {
            [questKeys.sourceItemId] = 13543,
        },

        [5384] = {
            [questKeys.preQuestSingle] = {5383,5515},
            [questKeys.nextQuestInChain] = 0,
        },

        [5385] = {
            [questKeys.objectives] = {nil,nil,{{13562}}},
        },

        [5401] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.exclusiveTo] = {},
        },

        [5402] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {},
        },

        [5403] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {},
        },

        [5404] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {},
        },

        [5405] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {},
        },

        [5406] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {},
        },

        [5407] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {},
        },

        [5408] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {},
        },

        [5421] = {
            [questKeys.parentQuest] = 5386,
        },

        [5441] = {
            [questKeys.objectivesText] = {"Use the Foreman's Blackjack on Lazy Peons when they're sleeping.  Wake up 5 peons, then return the Foreman's Blackjack to Foreman Thazz'ril in the Valley of Trials."},
            [questKeys.objectives] = {{{10556}},nil,{{16114}}},
            [questKeys.questFlags] = 0,
        },

        [5462] = {
            [questKeys.objectives] = {nil,nil,{{13585}}},
        },

        [5463] = {
            [questKeys.objectivesText] = {"Travel to Stratholme and find Menethil's Gift. Place the Keepsake of Remembrance upon the unholy ground. "},
            [questKeys.objectives] = {nil,nil,{{13585}}},
        },

        [5464] = {
            [questKeys.objectives] = {nil,nil,{{13624}}},
        },

        [5465] = {
            [questKeys.objectives] = {nil,nil,{{13624}}},
        },

        [5501] = {
            [questKeys.questLevel] = 39,
            [questKeys.requiredLevel] = 33,
        },

        [5502] = {
            [questKeys.preQuestSingle] = {915},
        },

        [5503] = {
            [questKeys.exclusiveTo] = {},
        },

        [5506] = {
            [questKeys.questLevel] = 56,
            [questKeys.requiredLevel] = 50,
            [questKeys.questFlags] = 264,
        },

        [5508] = {
            [questKeys.preQuestSingle] = {},
        },

        [5509] = {
            [questKeys.preQuestSingle] = {},
        },

        [5510] = {
            [questKeys.preQuestSingle] = {},
        },

        [5512] = {
            [questKeys.questLevel] = 56,
            [questKeys.requiredLevel] = 50,
            [questKeys.questFlags] = 8,
        },

        [5514] = {
            [questKeys.objectives] = {nil,nil,{{14628}}},
        },

        [5516] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [5518] = {
            [questKeys.objectivesText] = {"Bring 4 Bolts of Runecloth, 8 Rugged Leather, 2 Rune Threads, and Ogre Tannin to Knot Thimblejack.  He is currently chained inside the Gordok wing of Dire Maul."},
        },

        [5520] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [5522] = {
            [questKeys.objectives] = {nil,nil,{{13761}}},
            [questKeys.preQuestSingle] = {4734,4735},
        },

        [5523] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 53,
            [questKeys.questFlags] = 8,
        },

        [5526] = {
            [questKeys.objectivesText] = {"Find the Felvine in Dire Maul and acquire a shard from it.  Chances are you'll only be able to procure one with the demise of Alzzin the Wildshaper.  Use the Reliquary of Purity to securely seal the shard inside, and return it to Rabine Saturna in Nighthaven, Moonglade."},
        },

        [5527] = {
            [questKeys.objectivesText] = {"Travel to Silithus and search for a Reliquary of Purity within the ruins of Southwind Village.  If you are able to find it, return with it to Rabine Saturna in Nighthaven, Moonglade."},
        },

        [5530] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectives] = {nil,nil,{{12844}}},
            [questKeys.questFlags] = 8,
        },

        [5531] = {
            [questKeys.objectives] = {nil,nil,{{13761}}},
            [questKeys.nextQuestInChain] = 4771,
        },

        [5532] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 53,
            [questKeys.objectives] = {nil,nil,{{12844}}},
            [questKeys.questFlags] = 8,
        },

        [5538] = {
            [questKeys.objectives] = {nil,nil,{{14628}}},
        },

        [5561] = {
            [questKeys.objectives] = {{{11627}},nil,{{13892}}},
        },

        [5581] = {
            [questKeys.objectives] = {{{11937}},nil,{{14547}}},
        },

        [5582] = {
            [questKeys.objectives] = {nil,nil,{{13920}}},
        },

        [5601] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5621] = {
            [questKeys.preQuestSingle] = {5622},
            [questKeys.breadcrumbs] = {},
        },

        [5622] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5623] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.exclusiveTo] = {5626,9586},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5624] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {5623},
            [questKeys.breadcrumbs] = {},
        },

        [5625] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.preQuestSingle] = {5626},
            [questKeys.breadcrumbs] = {},
        },

        [5626] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.exclusiveTo] = {5623,9586},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5627] = {
            [questKeys.exclusiveTo] = {},
        },

        [5628] = {
            [questKeys.exclusiveTo] = {5629,5631},
        },

        [5629] = {
            [questKeys.exclusiveTo] = {5628,5631},
        },

        [5630] = {
            [questKeys.exclusiveTo] = {},
        },

        [5631] = {
            [questKeys.exclusiveTo] = {5628,5629},
        },

        [5632] = {
            [questKeys.exclusiveTo] = {},
        },

        [5633] = {
            [questKeys.exclusiveTo] = {},
        },

        [5634] = {
            [questKeys.exclusiveTo] = {5635,5636,5637,5638,5639},
        },

        [5635] = {
            [questKeys.exclusiveTo] = {5634,5636,5637,5638,5639},
        },

        [5636] = {
            [questKeys.exclusiveTo] = {5634,5635,5637,5638,5639},
        },

        [5637] = {
            [questKeys.exclusiveTo] = {5634,5635,5636,5638,5639},
        },

        [5638] = {
            [questKeys.exclusiveTo] = {5634,5635,5636,5637,5639},
        },

        [5639] = {
            [questKeys.exclusiveTo] = {5634,5635,5636,5637,5638},
        },

        [5640] = {
            [questKeys.exclusiveTo] = {},
        },

        [5641] = {
            [questKeys.requiredRaces] = 1028,
        },

        [5645] = {
            [questKeys.requiredRaces] = 1028,
        },

        [5647] = {
            [questKeys.requiredRaces] = 1028,
        },

        [5648] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {5649},
            [questKeys.breadcrumbs] = {},
        },

        [5649] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {5651,9489},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5650] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {5651},
            [questKeys.breadcrumbs] = {},
        },

        [5651] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {5649,9489},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5653] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 10,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5652,
            [questKeys.questFlags] = 8,
        },

        [5658] = {
            [questKeys.exclusiveTo] = {5659,5660,5661,5662,5663},
        },

        [5659] = {
            [questKeys.exclusiveTo] = {5658,5660,5661,5662,5663},
        },

        [5660] = {
            [questKeys.exclusiveTo] = {5658,5659,5661,5662,5663},
        },

        [5661] = {
            [questKeys.exclusiveTo] = {5658,5659,5660,5662,5663},
        },

        [5662] = {
            [questKeys.exclusiveTo] = {5658,5659,5660,5661,5663},
        },

        [5663] = {
            [questKeys.exclusiveTo] = {5658,5659,5660,5661,5662},
        },

        [5664] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5665] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5664,
            [questKeys.questFlags] = 8,
        },

        [5666] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5664,
            [questKeys.questFlags] = 8,
        },

        [5667] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5664,
            [questKeys.questFlags] = 8,
        },

        [5668] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5669] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5668,
            [questKeys.questFlags] = 8,
        },

        [5670] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5668,
            [questKeys.questFlags] = 8,
        },

        [5671] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5668,
            [questKeys.questFlags] = 8,
        },

        [5681] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5682] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak with High Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5681,
            [questKeys.questFlags] = 8,
        },

        [5683] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5681,
            [questKeys.questFlags] = 8,
        },

        [5684] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5681,
            [questKeys.questFlags] = 8,
        },

        [5685] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5686] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5685,
            [questKeys.questFlags] = 8,
        },

        [5687] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5685,
            [questKeys.questFlags] = 8,
        },

        [5688] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5689] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5688,
            [questKeys.questFlags] = 8,
        },

        [5690] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.nextQuestInChain] = 5688,
            [questKeys.questFlags] = 8,
        },

        [5691] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5692] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5691,
            [questKeys.questFlags] = 8,
        },

        [5693] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5691,
            [questKeys.questFlags] = 8,
        },

        [5694] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5695] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Priestesss Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5694,
            [questKeys.questFlags] = 8,
        },

        [5696] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Prietess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5694,
            [questKeys.questFlags] = 8,
        },

        [5697] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Priestess Alathea in Darnassus."},
            [questKeys.nextQuestInChain] = 5694,
            [questKeys.questFlags] = 8,
        },

        [5698] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5699] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5698,
            [questKeys.questFlags] = 8,
        },

        [5700] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to High Priestess Laurena in Stormwind."},
            [questKeys.nextQuestInChain] = 5698,
            [questKeys.questFlags] = 8,
        },

        [5701] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5702] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5701,
            [questKeys.questFlags] = 8,
        },

        [5703] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5701,
            [questKeys.questFlags] = 8,
        },

        [5704] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5705] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5704,
            [questKeys.questFlags] = 8,
        },

        [5706] = {
            [questKeys.questLevel] = 25,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5704,
            [questKeys.questFlags] = 8,
        },

        [5707] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5708] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5707,
            [questKeys.questFlags] = 8,
        },

        [5709] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Aelthalyste in the Undercity."},
            [questKeys.nextQuestInChain] = 5707,
            [questKeys.questFlags] = 8,
        },

        [5710] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.questFlags] = 8,
        },

        [5711] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5710,
            [questKeys.questFlags] = 8,
        },

        [5712] = {
            [questKeys.questLevel] = 35,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 16,
            [questKeys.objectivesText] = {"Speak to Ur'kyo in Orgrimmar."},
            [questKeys.nextQuestInChain] = 5710,
            [questKeys.questFlags] = 8,
        },

        [5721] = {
            [questKeys.objectives] = nil,
        },

        [5724] = {
            [questKeys.objectives] = {nil,nil,{{14381}}},
        },

        [5726] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.nextQuestInChain] = 0,
        },

        [5727] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = nil,
        },

        [5728] = {
            [questKeys.requiredRaces] = 690,
        },

        [5729] = {
            [questKeys.requiredRaces] = 690,
        },

        [5730] = {
            [questKeys.requiredRaces] = 690,
        },

        [5742] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {5542,5543,5544},
        },

        [5761] = {
            [questKeys.requiredRaces] = 690,
        },

        [5762] = {
            [questKeys.objectives] = {nil,nil,{{14542}}},
        },

        [5763] = {
            [questKeys.objectives] = {nil,nil,{{14546}}},
        },

        [5801] = {
            [questKeys.objectivesText] = {"Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater.  Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.","","Bring the Unfinished Skeleton Key to Alchemist Arbington at Chillwind Point, Western Plaguelands."},
        },

        [5802] = {
            [questKeys.objectivesText] = {"Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater.  Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.","","Bring the Unfinished Skeleton Key to Apothecary Dithers at the Bulwark, Western Plaguelands."},
        },

        [5805] = {
            [questKeys.objectives] = {nil,nil,{{14646}}},
        },

        [5841] = {
            [questKeys.objectives] = {nil,nil,{{14647}}},
        },

        [5842] = {
            [questKeys.objectives] = {nil,nil,{{14648}}},
        },

        [5843] = {
            [questKeys.objectives] = {nil,nil,{{14649}}},
        },

        [5844] = {
            [questKeys.objectives] = {nil,nil,{{14650}}},
        },

        [5847] = {
            [questKeys.objectives] = {nil,nil,{{14651}}},
        },

        [5861] = {
            [questKeys.objectives] = {nil,nil,{{14872}}},
        },

        [5862] = {
            [questKeys.objectives] = {nil,nil,{{14872}}},
        },

        [5881] = {
            [questKeys.objectives] = {nil,nil,{{16189}}},
        },

        [5882] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {4102},
        },

        [5883] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {4102},
        },

        [5884] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {4102},
        },

        [5885] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {4102},
        },

        [5886] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {4102},
        },

        [5887] = {
            [questKeys.preQuestSingle] = {5882},
            [questKeys.specialFlags] = 1,
        },

        [5888] = {
            [questKeys.preQuestSingle] = {5883},
            [questKeys.specialFlags] = 1,
        },

        [5889] = {
            [questKeys.preQuestSingle] = {5884},
            [questKeys.specialFlags] = 1,
        },

        [5890] = {
            [questKeys.preQuestSingle] = {5885},
            [questKeys.specialFlags] = 1,
        },

        [5891] = {
            [questKeys.preQuestSingle] = {5886},
            [questKeys.specialFlags] = 1,
        },

        [5892] = {
            [questKeys.questLevel] = -1,
        },

        [5893] = {
            [questKeys.questLevel] = -1,
        },

        [5901] = {
            [questKeys.objectives] = {nil,nil,{{15042},{15043}}},
        },

        [5903] = {
            [questKeys.objectives] = {nil,nil,{{15042},{15043}}},
        },

        [5921] = {
            [questKeys.objectivesText] = {"Use the spell \"Teleport: Moonglade\" to travel to Moonglade.  When you arrive, speak with Dendrite Starblaze in the village of Nighthaven."},
            [questKeys.breadcrumbs] = {},
        },

        [5922] = {
            [questKeys.objectivesText] = {"Use the spell \"Teleport: Moonglade\" to travel to Moonglade.  When you arrive, speak with Dendrite Starblaze in the village of Nighthaven."},
            [questKeys.breadcrumbs] = {},
        },

        [5923] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5924] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5925] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5926] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5927] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5928] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [5929] = {
            [questKeys.objectivesText] = {"Seek out the Great Bear Spirit in northwestern Moonglade and learn what it has to share with you about the nature of the bear.  When finished, return to Dendrite Starblaze in Nighthaven, Moonglade."},
            [questKeys.objectives] = nil,
        },

        [5930] = {
            [questKeys.objectivesText] = {"Seek out the Great Bear Spirit in northwestern Moonglade and learn what it has to share with you about the nature of the bear.  When finished, return to Dendrite Starblaze in Nighthaven, Moonglade."},
            [questKeys.objectives] = nil,
        },

        [5941] = {
            [questKeys.objectives] = {nil,nil,{{15314}}},
        },

        [5942] = {
            [questKeys.objectives] = {nil,nil,{{15328}}},
        },

        [5961] = {
            [questKeys.requiredRaces] = 690,
        },

        [6001] = {
            [questKeys.objectivesText] = {"Use the Cenarion Moondust on the Moonkin Stone of Auberdine to bring forth Lunaclaw.  From there, you must face Lunaclaw and earn the strength of body and heart it possesses.","","Speak with Mathrengyl Bearwalker in Darnassus when you are done."},
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 0,
        },

        [6002] = {
            [questKeys.objectivesText] = {"Use the Cenarion Lunardust on the Moonkin Stone between Mulgore and the Barrens to bring forth Lunaclaw.  From there, you must face Lunaclaw and earn the strength of body and heart it possesses.","","Speak with Turak Runetotem in Thunder Bluff when you are done."},
            [questKeys.objectives] = nil,
        },

        [6003] = {
            [questKeys.questLevel] = 39,
            [questKeys.requiredLevel] = 30,
            [questKeys.questFlags] = 8,
        },

        [6024] = {
            [questKeys.objectivesText] = {"Kill Infiltrator Hameya.  Use his key on the Mound of Dirt behind the Undercroft."},
        },

        [6027] = {
            [questKeys.objectives] = {nil,nil,{{15803},{15766}}},
        },

        [6028] = {
            [questKeys.objectives] = {nil,nil,{{15788}}},
        },

        [6029] = {
            [questKeys.objectives] = {nil,nil,{{15788}}},
        },

        [6030] = {
            [questKeys.objectives] = {nil,nil,{{15790}}},
        },

        [6061] = {
            [questKeys.objectives] = {nil,nil,{{15914}}},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6062] = {
            [questKeys.objectives] = {nil,nil,{{15917}}},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6063] = {
            [questKeys.objectives] = {nil,nil,{{15921}}},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6064] = {
            [questKeys.objectives] = {nil,nil,{{15911}}},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6065] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6066] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6067] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6068] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6069] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6070] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6071] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6072] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6073] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6074] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6075] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6076] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6082] = {
            [questKeys.objectives] = {nil,nil,{{15920}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6083] = {
            [questKeys.objectives] = {nil,nil,{{15919}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6084] = {
            [questKeys.objectives] = {nil,nil,{{15913}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6085] = {
            [questKeys.objectives] = {nil,nil,{{15908}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6087] = {
            [questKeys.objectives] = {nil,nil,{{15915}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6088] = {
            [questKeys.objectives] = {nil,nil,{{15916}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6101] = {
            [questKeys.objectives] = {nil,nil,{{15922}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6102] = {
            [questKeys.objectives] = {nil,nil,{{15923}}},
            [questKeys.questFlags] = 2,
            [questKeys.specialFlags] = 2,
        },

        [6124] = {
            [questKeys.objectivesText] = {"Use the Curative Animal Salve on 10 Sickly Deer that are located throughout Darkshore; doing so should cure them.  Sickly Deer have been reported starting south of the Cliffspring River to the north of Auberdine and extending all the way into southern Darkshore where the edge of Ashenvale begins."},
            [questKeys.objectives] = {{{12299}}},
            [questKeys.specialFlags] = 32,
        },

        [6129] = {
            [questKeys.objectivesText] = {"Use the Curative Animal Salve on 10 Sickly Gazelles that are located throughout the northern part of the Barrens; doing so should cure them.  Sickly Gazelles have been reported north of the east-west road that runs through the Crossroads."},
            [questKeys.objectives] = {{{12297}}},
            [questKeys.specialFlags] = 32,
        },

        [6131] = {
            [questKeys.preQuestSingle] = {8460},
        },

        [6132] = {
            [questKeys.questFlags] = 2,
        },

        [6134] = {
            [questKeys.objectives] = {nil,nil,{{15848},{15849}}},
        },

        [6135] = {
            [questKeys.preQuestSingle] = {6133},
        },

        [6144] = {
            [questKeys.exclusiveTo] = {14349},
        },

        [6145] = {
            [questKeys.exclusiveTo] = {14350},
        },

        [6146] = {
            [questKeys.preQuestSingle] = {},
        },

        [6161] = {
            [questKeys.objectivesText] = {"Find Rackmore's Silver Key.  Find Rackmore's Golden Key.  Find and open Rackmore's Chest."},
        },

        [6163] = {
            [questKeys.preQuestSingle] = {6135},
        },

        [6165] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 50,
            [questKeys.questFlags] = 8,
        },

        [6181] = {
            [questKeys.objectives] = {nil,nil,{{15998}}},
        },

        [6187] = {
            [questKeys.objectivesText] = {"Assemble an army and travel to the Eastern Plaguelands. Launch a full assault on Nathanos Blightcaller and any Horde filth that may attempt to protect him.","","Keep your wits about you, $N. The Horde will defend the ranger lord with their very lives."},
        },

        [6201] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{159},{2070}}},
        },

        [6202] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{6292},{13917}}},
        },

        [6261] = {
            [questKeys.objectives] = {nil,nil,{{16115}}},
        },

        [6281] = {
            [questKeys.objectives] = {nil,nil,{{15998}}},
        },

        [6284] = {
            [questKeys.requiredLevel] = 15,
        },

        [6285] = {
            [questKeys.objectives] = {nil,nil,{{16115}}},
        },

        [6321] = {
            [questKeys.objectives] = {nil,nil,{{16209}}},
        },

        [6322] = {
            [questKeys.objectives] = {nil,nil,{{16210}}},
        },

        [6323] = {
            [questKeys.objectives] = {nil,nil,{{16209}}},
        },

        [6324] = {
            [questKeys.objectives] = {nil,nil,{{16210}}},
        },

        [6341] = {
            [questKeys.objectives] = {nil,nil,{{16262}}},
            [questKeys.preQuestSingle] = {6344},
            [questKeys.breadcrumbs] = {},
        },

        [6342] = {
            [questKeys.objectives] = {nil,nil,{{16262}}},
        },

        [6343] = {
            [questKeys.objectives] = {nil,nil,{{16263}}},
        },

        [6344] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6361] = {
            [questKeys.objectives] = {nil,nil,{{16282}}},
        },

        [6362] = {
            [questKeys.objectives] = {nil,nil,{{16282}}},
        },

        [6363] = {
            [questKeys.objectives] = {nil,nil,{{16283}}},
        },

        [6364] = {
            [questKeys.objectives] = {nil,nil,{{16283}}},
        },

        [6365] = {
            [questKeys.objectives] = {nil,nil,{{16306}}},
        },

        [6381] = {
            [questKeys.objectives] = {nil,{{177929}},{{16208}}},
            [questKeys.specialFlags] = 32,
        },

        [6382] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6383] = {
            [questKeys.breadcrumbs] = {},
        },

        [6384] = {
            [questKeys.objectives] = {nil,nil,{{16306}}},
        },

        [6385] = {
            [questKeys.objectives] = {nil,nil,{{16307}}},
        },

        [6386] = {
            [questKeys.objectives] = {nil,nil,{{16307}}},
        },

        [6387] = {
            [questKeys.objectives] = {nil,nil,{{16310}}},
        },

        [6388] = {
            [questKeys.objectives] = {nil,nil,{{16311}}},
        },

        [6389] = {
            [questKeys.objectives] = {nil,nil,{{15044}}},
        },

        [6390] = {
            [questKeys.objectives] = {nil,nil,{{15044}}},
        },

        [6391] = {
            [questKeys.objectives] = {nil,nil,{{16310}}},
        },

        [6392] = {
            [questKeys.objectives] = {nil,nil,{{16311}}},
        },

        [6394] = {
            [questKeys.questFlags] = 8,
        },

        [6395] = {
            [questKeys.questFlags] = 8,
        },

        [6403] = {
            [questKeys.questFlags] = 74,
        },

        [6501] = {
            [questKeys.objectives] = {nil,nil,{{16662}}},
        },

        [6504] = {
            [questKeys.requiredSourceItems] = {},
        },

        [6521] = {
            [questKeys.objectivesText] = {"Bring Ambassador Malcin's Head to Varimathras in the Undercity."},
        },

        [6522] = {
            [questKeys.objectivesText] = {"Take the Small Scroll to Varimathras in the Undercity."},
            [questKeys.objectives] = {nil,nil,{{17008}}},
        },

        [6541] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6542] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6543] = {
            [questKeys.objectivesText] = {"Open the Bundle of Reports.  Take the Warsong Reports to the Warsong Scout, Warsong Runner, and Warsong Outrider. Bring back the updates they give you to Kadrak at the northern watch tower in the barrens."},
            [questKeys.breadcrumbs] = {},
        },

        [6562] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6563] = {
            [questKeys.preQuestSingle] = {6562},
            [questKeys.breadcrumbs] = {},
        },

        [6564] = {
            [questKeys.objectives] = {nil,nil,{{16790}}},
            [questKeys.preQuestSingle] = {},
        },

        [6566] = {
            [questKeys.questFlags] = 10,
        },

        [6567] = {
            [questKeys.objectivesText] = {"Seek out Rexxar. The Warchief has instructed you as to his whereabouts. Search the paths of Desolace, between the Stonetalon Mountains and Feralas."},
        },

        [6568] = {
            [questKeys.objectivesText] = {"Deliver Rexxar's Testament to Myranda the Hag in the Western Plaguelands."},
            [questKeys.objectives] = {nil,nil,{{16785}}},
        },

        [6585] = {
            [questKeys.preQuestSingle] = {6582,6583,6584},
        },

        [6601] = {
            [questKeys.objectivesText] = {"It would appear as if the charade is over. ","You know that the Amulet of Draconic Subversion that Myranda the Hag created for you will not function inside Blackrock Spire. ","Perhaps you should find Rexxar and explain your predicament. Show him the Dull Drakefire Amulet. Hopefully he will know what to do next."},
            [questKeys.objectives] = {nil,nil,{{16888}}},
        },

        [6602] = {
            [questKeys.objectivesText] = {"Travel to Blackrock Spire and slay General Drakkisath. Gather his blood and return it to Rexxar."},
        },

        [6607] = {
            [questKeys.breadcrumbs] = {6609},
        },

        [6608] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6609] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [6621] = {
            [questKeys.objectivesText] = {"Place Karang's Banner on the Foulweald Totem Mound.  Do not let the furbolgs destroy the banner.  Defeat Chief Murgut and bring Murgut's Totem to Karang Amakkar at Zoram'gar."},
        },

        [6622] = {
            [questKeys.requiredSourceItems] = {16991},
        },

        [6624] = {
            [questKeys.requiredSourceItems] = {16991},
        },

        [6627] = {
            [questKeys.questFlags] = 10,
        },

        [6628] = {
            [questKeys.questFlags] = 10,
        },

        [6661] = {
            [questKeys.objectives] = {{{13017}},nil,{{17117}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 32,
        },

        [6662] = {
            [questKeys.objectives] = {nil,nil,{{17118}}},
        },

        [6681] = {
            [questKeys.objectives] = {{{13936}},nil,{{17125}}},
            [questKeys.questFlags] = 0,
        },

        [6702] = {
            [questKeys.questLevel] = 33,
            [questKeys.requiredLevel] = 100,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"TXT"},
            [questKeys.questFlags] = 8,
        },

        [6703] = {
            [questKeys.questLevel] = 33,
            [questKeys.requiredLevel] = 25,
            [questKeys.requiredClasses] = 8,
            [questKeys.questFlags] = 8,
        },

        [6704] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 100,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"TXT"},
            [questKeys.questFlags] = 8,
        },

        [6705] = {
            [questKeys.questLevel] = 45,
            [questKeys.requiredLevel] = 35,
            [questKeys.requiredClasses] = 8,
            [questKeys.questFlags] = 8,
        },

        [6706] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 100,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"TXT"},
            [questKeys.questFlags] = 8,
        },

        [6707] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 45,
            [questKeys.requiredClasses] = 8,
            [questKeys.questFlags] = 8,
        },

        [6708] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 100,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"TXT"},
            [questKeys.questFlags] = 8,
        },

        [6709] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.requiredClasses] = 8,
            [questKeys.questFlags] = 8,
        },

        [6710] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"TXT"},
            [questKeys.questFlags] = 8,
        },

        [6711] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 8,
            [questKeys.questFlags] = 8,
        },

        [6721] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6722] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6762] = {
            [questKeys.objectivesText] = {"Speak with Rabine Saturna in the village of Nighthaven, Moonglade.  Moonglade lies between Felwood and Winterspring, accessible through a path out of Timbermaw Hold."},
            [questKeys.preQuestSingle] = {6761},
        },

        [6804] = {
            [questKeys.objectivesText] = {"Use the Aspect of Neptulon on poisoned elementals of Eastern Plaguelands.  Bring 12 Discordant Bracers and the Aspect of Neptulon to Duke Hydraxis in Azshara."},
            [questKeys.objectives] = {nil,nil,{{17309},{17310}}},
        },

        [6821] = {
            [questKeys.preQuestSingle] = {6805},
        },

        [6822] = {
            [questKeys.preQuestSingle] = {6021,6821},
        },

        [6823] = {
            [questKeys.preQuestSingle] = {6022,6822},
        },

        [6824] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [6841] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 54,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [6842] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 54,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [6844] = {
            [questKeys.objectives] = {nil,nil,{{17346}}},
        },

        [6846] = {
            [questKeys.requiredLevel] = 1,
        },

        [6848] = {
            [questKeys.requiredLevel] = 51,
        },

        [6861] = {
            [questKeys.objectivesText] = {"Master Engineer Zinfizzlex wants you to bring him the following:","","*30 Thorium Bars.","","*50 Mithril Bars.","","*75 Iron bars.","","*1 Steamsaw."},
        },

        [6862] = {
            [questKeys.objectivesText] = {"Master Engineer Zinfizzlex wants you to bring him the following:","","*30 Thorium Bars.","","*50 Mithril Bars.","","*75 Iron bars.","","*1 Steamsaw."},
        },

        [6922] = {
            [questKeys.objectives] = {nil,nil,{{16782}}},
        },

        [6961] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [6962] = {
            [questKeys.breadcrumbs] = {},
        },

        [6981] = {
            [questKeys.objectives] = {nil,nil,{{10441}}},
        },

        [6982] = {
            [questKeys.questLevel] = -1,
        },

        [6983] = {
            [questKeys.objectivesText] = {"Locate and return the Stolen Treats to Kaymard Copperpinch in Orgrimmar.  It was last thought to be in the possession of the Abominable Greench, found somewhere in the snowy regions of the Alterac Mountains."},
            [questKeys.specialFlags] = 0,
        },

        [6985] = {
            [questKeys.questLevel] = -1,
        },

        [7001] = {
            [questKeys.objectives] = nil,
        },

        [7003] = {
            [questKeys.objectivesText] = {"Use Zorbin's Ultra-Shrinker to zap any kind of giant found in Feralas into a more manageable form.  Bring 15 Miniaturization Residues found on the zapped versions of these giants to Zorbin Fandazzle at the docks of the Forgotten Coast, Feralas."},
        },

        [7021] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [7024] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [7027] = {
            [questKeys.objectives] = nil,
        },

        [7028] = {
            [questKeys.objectivesText] = {"Collect 25 Theradric Crystal Carvings for Willow in Desolace."},
        },

        [7043] = {
            [questKeys.objectivesText] = {"Locate and return the Stolen Treats to Wulmort Jinglepocket in Ironforge.  It was last thought to be in the possession of the Abominable Greench, found somewhere in the snowy regions of the Alterac Mountains."},
        },

        [7061] = {
            [questKeys.objectivesText] = {"Feel free to read the book, \"The Feast of Winter Veil\", to learn more about the holiday.  When you are finished with the book, deliver it to Cairne Bloodhoof in Thunder Bluff."},
            [questKeys.objectives] = {nil,nil,{{17735}}},
        },

        [7063] = {
            [questKeys.objectivesText] = {"Feel free to read the book, \"The Feast of Winter Veil\", to learn more about the holiday.  When you are finished with the book, deliver it to King Magni Bronzebeard in Ironforge."},
            [questKeys.objectives] = {nil,nil,{{17735}}},
        },

        [7066] = {
            [questKeys.objectives] = {nil,nil,{{17760}}},
        },

        [7067] = {
            [questKeys.requiredSourceItems] = {17757},
        },

        [7069] = {
            [questKeys.questFlags] = 8,
        },

        [7121] = {
            [questKeys.exclusiveTo] = {},
        },

        [7123] = {
            [questKeys.exclusiveTo] = {},
        },

        [7142] = {
            [questKeys.objectivesText] = {"Enter Alterac Valley and defeat the dwarven general, Vanndar Stormpike.  Then, return to Voggah Deathgrip in the Alterac Mountains."},
        },

        [7161] = {
            [questKeys.objectivesText] = {"Travel to the Wildpaw cavern located southeast of the main base in Alterac Valley and find the Frostwolf Banner. Return the Frostwolf Banner to Warmaster Laggrond. "},
            [questKeys.requiredMinRep] = false,
            [questKeys.breadcrumbs] = {},
        },

        [7162] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.requiredMinRep] = false,
            [questKeys.breadcrumbs] = {},
        },

        [7181] = {
            [questKeys.objectives] = {{{12159}}},
            [questKeys.specialFlags] = 0,
        },

        [7202] = {
            [questKeys.objectives] = {{{12159}}},
            [questKeys.specialFlags] = 0,
        },

        [7223] = {
            [questKeys.specialFlags] = 0,
        },

        [7224] = {
            [questKeys.specialFlags] = 0,
        },

        [7241] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [7261] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [7301] = {
            [questKeys.specialFlags] = 2,
        },

        [7302] = {
            [questKeys.specialFlags] = 2,
        },

        [7321] = {
            [questKeys.objectives] = {nil,nil,{{3712},{3713}}},
        },

        [7361] = {
            [questKeys.requiredLevel] = 51,
        },

        [7362] = {
            [questKeys.requiredLevel] = 51,
        },

        [7363] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectivesText] = {"You have been tasked with slaying opposing human players in Alterac Valley.","","Kill a human and return to Commander Louis Philips (who wanders between the front lines and Frostwolf keep) with a  Human Bone Chip.","","A cure for the human condition is close at hand!"},
        },

        [7364] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectivesText] = {"You have been tasked with slaying opposing tauren players in Alterac Valley.","","Kill a tauren and return to Dirk Swindle at Dun'Baldar with a  Tauren Hoof."},
        },

        [7365] = {
            [questKeys.requiredLevel] = 51,
        },

        [7366] = {
            [questKeys.requiredLevel] = 51,
        },

        [7367] = {
            [questKeys.specialFlags] = 0,
        },

        [7368] = {
            [questKeys.specialFlags] = 0,
        },

        [7381] = {
            [questKeys.preQuestSingle] = {7181},
            [questKeys.specialFlags] = 0,
        },

        [7382] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.preQuestSingle] = {7202},
            [questKeys.specialFlags] = 0,
        },

        [7384] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Collect some scales for Karana in the Harborage in Swamp of Sorrows."},
            [questKeys.objectives] = {nil,nil,{{15416}}},
            [questKeys.questFlags] = 8,
        },

        [7401] = {
            [questKeys.requiredLevel] = 51,
        },

        [7402] = {
            [questKeys.requiredLevel] = 51,
        },

        [7421] = {
            [questKeys.requiredLevel] = 51,
        },

        [7422] = {
            [questKeys.requiredLevel] = 51,
        },

        [7423] = {
            [questKeys.requiredLevel] = 51,
        },

        [7424] = {
            [questKeys.requiredLevel] = 51,
        },

        [7425] = {
            [questKeys.requiredLevel] = 51,
        },

        [7426] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.requiredRaces] = 0,
        },

        [7427] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {7401},
        },

        [7428] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {7402},
        },

        [7462] = {
            [questKeys.requiredLevel] = 57,
        },

        [7481] = {
            [questKeys.objectivesText] = {"Search Dire Maul for Kariel Winthalus. Report back to Sage Korolusk at Camp Mojache with whatever information that you may find."},
            [questKeys.objectives] = nil,
        },

        [7482] = {
            [questKeys.objectivesText] = {"Search Dire Maul for Kariel Winthalus. Report back to Scholar Runethorn at Feathermoon with whatever information that you may find."},
            [questKeys.objectives] = nil,
        },

        [7483] = {
            [questKeys.requiredLevel] = 57,
            [questKeys.preQuestSingle] = {},
        },

        [7484] = {
            [questKeys.requiredLevel] = 57,
            [questKeys.preQuestSingle] = {},
        },

        [7485] = {
            [questKeys.requiredLevel] = 57,
            [questKeys.preQuestSingle] = {},
        },

        [7488] = {
            [questKeys.preQuestSingle] = {7494},
        },

        [7489] = {
            [questKeys.preQuestSingle] = {7492},
        },

        [7490] = {
            [questKeys.objectives] = {nil,nil,{{18422}}},
        },

        [7493] = {
            [questKeys.preQuestSingle] = {7490},
        },

        [7495] = {
            [questKeys.objectives] = {nil,nil,{{18423}}},
        },

        [7498] = {
            [questKeys.objectives] = {nil,nil,{{18356}}},
        },

        [7499] = {
            [questKeys.objectives] = {nil,nil,{{18357}}},
        },

        [7500] = {
            [questKeys.objectives] = {nil,nil,{{18358}}},
        },

        [7501] = {
            [questKeys.objectives] = {nil,nil,{{18359}}},
        },

        [7502] = {
            [questKeys.objectives] = {nil,nil,{{18360}}},
        },

        [7503] = {
            [questKeys.objectives] = {nil,nil,{{18361}}},
        },

        [7504] = {
            [questKeys.objectives] = {nil,nil,{{18362}}},
        },

        [7505] = {
            [questKeys.objectives] = {nil,nil,{{18363}}},
        },

        [7506] = {
            [questKeys.objectives] = {nil,nil,{{18364}}},
        },

        [7507] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectivesText] = {"Return Foror's Compendium of Dragon Slaying to the Athenaeum."},
            [questKeys.objectives] = {nil,nil,{{18401}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.questFlags] = 0,
        },

        [7508] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {nil,nil,{{18513}}},
            [questKeys.questFlags] = 0,
        },

        [7509] = {
            [questKeys.questFlags] = 64,
            [questKeys.specialFlags] = 0,
        },

        [7521] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"To free Thunderaan the Windseeker from his prison, you must present the right and left halves of the Bindings of the Wind Seeker, 10 bars of Elementium, and the Essence of the Firelord to Highlord Demitrian. "},
            [questKeys.preQuestSingle] = {7522},
        },

        [7522] = {
            [questKeys.objectives] = {nil,nil,{{18565}}},
        },

        [7561] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 100,
            [questKeys.objectivesText] = {"Present the Dormant Wind Kissed Blade to Highlord Demitrian."},
            [questKeys.objectives] = {nil,nil,{{18589}}},
            [questKeys.sourceItemId] = 18589,
        },

        [7562] = {
            [questKeys.requiredRaces] = 595,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [7563] = {
            [questKeys.preQuestSingle] = {7562},
            [questKeys.breadcrumbs] = {},
        },

        [7564] = {
            [questKeys.objectives] = {nil,nil,{{18591}}},
        },

        [7581] = {
            [questKeys.nextQuestInChain] = 7582,
        },

        [7582] = {
            [questKeys.preQuestSingle] = {7581},
            [questKeys.nextQuestInChain] = 7583,
        },

        [7583] = {
            [questKeys.objectives] = {nil,nil,{{18605},{18601}}},
            [questKeys.preQuestSingle] = {7582},
        },

        [7602] = {
            [questKeys.objectivesText] = {"Impsy in Felwood has asked that you bring him three Flawless Fel Essences originating from three distinct locations.","","The Legashi Satyrs of Azshara hold the Flawless Fel Essence of their region. The Jaedenar Legionnaires of Jaedenar hold the Flawless Fel Essence of their region. The Felguard Sentries of the Blasted Lands hold the Flawless Fel Essence of their region.","","Recover the Flawless Fel Essences and return  to Impsy in Felwood."},
        },

        [7604] = {
            [questKeys.objectives] = {nil,nil,{{18628},{17203}}},
            [questKeys.specialFlags] = 1,
        },

        [7623] = {
            [questKeys.preQuestSingle] = {7564},
        },

        [7625] = {
            [questKeys.objectivesText] = {"Purchase Xorothian Stardust from Ur'dan inside the Shadow Hold at Jaedenar in Felwood.  Bring it to Gorzeeki Wildeyes in the Burning Steppes."},
        },

        [7626] = {
            [questKeys.objectivesText] = {"Bring 10 Elixirs of Shadow Power to Gorzeeki Wildeyes in the Burning Steppes."},
        },

        [7628] = {
            [questKeys.objectivesText] = {"Bring 35 Black Dragonscales to Gorzeeki Wildeyes in the Burning Steppes."},
        },

        [7629] = {
            [questKeys.objectivesText] = {"Bring the Imp in a Jar to the alchemy lab in the Scholomance.  After the parchment is created, return the jar to Gorzeeki Wildeyes."},
            [questKeys.objectives] = {{{14500}},nil,{{18688}}},
            [questKeys.preQuestSingle] = {7625,7630},
        },

        [7630] = {
            [questKeys.objectivesText] = {"Bring 3 Arcanite Bars to Gorzeeki in the Burning Steppes."},
            [questKeys.preQuestSingle] = {7626,7627,7628},
        },

        [7631] = {
            [questKeys.objectivesText] = {"Read Mor'zul's Instructions.  Summon a Xorothian Dreadsteed, defeat it, then bind its spirit to you."},
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {7629},
        },

        [7632] = {
            [questKeys.objectivesText] = {"Find the owner of the Ancient Petrified Leaf. Good luck, $N; It's a big world."},
            [questKeys.objectives] = {nil,nil,{{18703}}},
        },

        [7633] = {
            [questKeys.preQuestSingle] = {},
        },

        [7637] = {
            [questKeys.objectivesText] = {"Travel to Ironforge and get High Priest Rohan's Exorcism Censer.  You will need to make a donation of 150 gold in order to secure it."},
        },

        [7639] = {
            [questKeys.objectives] = {nil,nil,{{18819}}},
        },

        [7640] = {
            [questKeys.objectivesText] = {"Use the Exorcism Censer to drive out the spirits that torment Terrordale.  When you have slain 25 Terrordale Spirits, return to Lord Grayson Shadowbreaker in the Cathedral District of Stormwind."},
            [questKeys.objectives] = {{{14564}},nil,{{18752}}},
        },

        [7641] = {
            [questKeys.preQuestSingle] = {7640},
        },

        [7643] = {
            [questKeys.objectivesText] = {"Acquire special horse feed used for feeding a spirit horse.  Merideth Carlson in Southshore apparently is the source for such food.","","Travel to the Dire Maul dungeon in Feralas and slay Tendris Warpwood.  Doing so will free the Ancient Equine Spirit.  Feed it the special horse feed, thereby soothing the spirit.  Finally, give it the Arcanite Barding so it may bless it."},
            [questKeys.objectives] = {nil,nil,{{18753},{18775}}},
            [questKeys.preQuestSingle] = {7642,7648},
        },

        [7644] = {
            [questKeys.objectives] = {nil,nil,{{18792}}},
        },

        [7645] = {
            [questKeys.objectivesText] = {"Retrieve 20 Enriched Manna Biscuits - the key ingredient in making Manna-Enriched Horse Feed - for Merideth Carlson at Southshore in the Hillsbrad Foothills.  The Argent Dawn is known as the sole purveyor of the biscuits.","","You also need to give her 50 gold to soothe her ruffled sensibilities."},
        },

        [7647] = {
            [questKeys.objectivesText] = {"Use the Divination Scryer in the heart of the Great Ossuary's basement in the Scholomance.  Doing so will bring forth the spirits you must judge.  Defeating these spirits will summon forth Death Knight Darkreaver.  Defeat him and reclaim the lost soul of the fallen charger.","","Give the Charger's Redeemed Soul and the Blessed Enchanted Barding to Darkreaver's Fallen Charger."},
        },

        [7648] = {
            [questKeys.objectives] = {nil,nil,{{18753}}},
        },

        [7649] = {
            [questKeys.objectives] = {nil,nil,{{18769}}},
        },

        [7650] = {
            [questKeys.objectives] = {nil,nil,{{18770}}},
        },

        [7651] = {
            [questKeys.objectives] = {nil,nil,{{18771}}},
            [questKeys.specialFlags] = 1,
        },

        [7652] = {
            [questKeys.breadcrumbs] = {10891,10892},
        },

        [7668] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Use the Divination Scryer in the heart of the Great Ossuary's basement in the Scholomance.  Doing so will bring forth spirits you must fight.  Defeating these spirits will summon forth Death Knight Darkreaver; defeat him.","","Bring Darkreaver's Head to Sagorne Creststrider in the Valley of Wisdom, Orgrimmar."},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [7669] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [7670] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredRaces] = 1029,
            [questKeys.nextQuestInChain] = 0,
        },

        [7675] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 60,
        },

        [7676] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 60,
        },

        [7703] = {
            [questKeys.requiredLevel] = 60,
        },

        [7704] = {
            [questKeys.questLevel] = 50,
            [questKeys.objectives] = {nil,nil,{{18950}}},
        },

        [7725] = {
            [questKeys.objectivesText] = {"Use Zorbin's Ultra-Shrinker to zap any kind of giant found in Feralas into a more manageable form.  Bring 10 Miniaturization Residues found on the zapped versions of these giants to Zorbin Fandazzle at the docks of the Forgotten Coast, Feralas."},
        },

        [7728] = {
            [questKeys.objectivesText] = {"Find and return the Smithing Tuyere and Lookout's Spyglass to Taskmaster Scrange in the Searing Gorge.","","The only information you have about these items is the following: They were definitely stolen by Dark Iron dwarves. The Smithing Tuyere is a blacksmithing tool used by blacksmiths and the Lookout's Spyglass is an invaluable monitoring tool to lookouts. "},
        },

        [7732] = {
            [questKeys.objectivesText] = {"Deliver the Camp Mojache Zukk'ash Report to Zilzibin Drumlore.  He resides in the Drag of Orgrimmar."},
            [questKeys.objectives] = {nil,nil,{{19020}}},
            [questKeys.preQuestSingle] = {7730,7731},
        },

        [7735] = {
            [questKeys.objectives] = {nil,nil,{{18969}}},
            [questKeys.preQuestSingle] = {},
        },

        [7738] = {
            [questKeys.objectives] = {nil,nil,{{18972}}},
            [questKeys.preQuestSingle] = {},
        },

        [7781] = {
            [questKeys.objectives] = {nil,nil,{{19003}}},
        },

        [7783] = {
            [questKeys.objectives] = {nil,nil,{{19002}}},
        },

        [7785] = {
            [questKeys.objectives] = {nil,nil,{{19016}}},
        },

        [7787] = {
            [questKeys.objectives] = {nil,nil,{{19018}}},
        },

        [7788] = {
            [questKeys.questLevel] = 29,
        },

        [7789] = {
            [questKeys.questLevel] = 29,
            [questKeys.exclusiveTo] = {7874,7875,7876,7922,7923,7924,7925,8293,8294},
        },

        [7790] = {
            [questKeys.objectives] = {{{14732}}},
            [questKeys.questFlags] = 8,
        },

        [7791] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7792] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7793] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7794] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7795] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7796] = {
            [questKeys.questLevel] = 60,
        },

        [7798] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7799] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7800] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7801] = {
            [questKeys.questLevel] = 60,
        },

        [7802] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7803] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7804] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7805] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7806] = {
            [questKeys.questLevel] = 60,
        },

        [7807] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7808] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7809] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7811] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7812] = {
            [questKeys.questLevel] = 60,
        },

        [7813] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7814] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7815] = {
            [questKeys.objectivesText] = {"Katoom the Angler at Revantusk Village in the Hinterlands wants you to kill 15 Saltwater Snapjaw turtles. Return to him when you have completed this task."},
        },

        [7817] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7818] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7819] = {
            [questKeys.questLevel] = 60,
        },

        [7820] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7821] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7822] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7823] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7824] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7825] = {
            [questKeys.questLevel] = 60,
        },

        [7826] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7827] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7828] = {
            [questKeys.objectivesText] = {"Huntsman Markhor at Revantusk Village in the Hinterlands wants you to kill 15 Silvermane Stalkers and 15 Silvermane Howlers. Return to him once the task is complete.","","Markhor mentioned that the wolves hide in the wilds of the Hinterlands."},
        },

        [7829] = {
            [questKeys.objectivesText] = {"Huntsman Markhor at Revantusk Village in the Hinterlands wants you to kill 20 Savage Owlbeasts. Return to him once the task is complete.","","Markhor mentioned that the Savage Owlbeasts occupy the wilds of the Hinterlands."},
        },

        [7831] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7832] = {
            [questKeys.questLevel] = 60,
        },

        [7833] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7834] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7835] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [7836] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [7837] = {
            [questKeys.questLevel] = 60,
        },

        [7841] = {
            [questKeys.objectivesText] = {"Otho Moji'ko at Revantusk Village in the Hinterlands wants you to slaughter 15 Highvale Scouts, 5 Highvale Outrunners, 5 Highvale Rangers and 2 Highvale Marksman. Return to him when this task is complete.","","You can find the Highvale high elves at the Quel'Danil Lodge in the northwestern region of the Hinterlands."},
        },

        [7842] = {
            [questKeys.objectivesText] = {"Otho Moji'ko at Revantusk Village in the Hinterlands wants you to bring him 10 Long Elegant Feather from the gryphons that inhabit the Hinterlands. Return to him once this task is complete.","","Gryphons are known to inhabit every region of the Hinterlands."},
        },

        [7844] = {
            [questKeys.objectivesText] = {"Mystic Yayo'jin at Revantusk Village in the Hinterlands wants you to kill 30 Vilebranch Scalpers and 15 Vilebranch Soothsayers. Return to her when this task is complete.","","Yayo'jin indicated that these trolls could be found near the Shaol'watha and Agol'watha temples in the north by northeastern region of the Hinterlands."},
        },

        [7846] = {
            [questKeys.specialFlags] = 1,
        },

        [7848] = {
            [questKeys.requiredRaces] = 1101,
        },

        [7850] = {
            [questKeys.objectivesText] = {"Primal Torntusk at Revantusk Village in the Hinterlands wants you to recover 10 Vessels of Tainted Blood from Jintha'alor. Return to Primal Torntusk when this task is complete."},
        },

        [7861] = {
            [questKeys.requiredLevel] = 46,
            [questKeys.objectivesText] = {"You have been ordered to slay Vile Priestess Hexx and 20 Vilebranch Aman'zasi Guards. See Primal Torntusk at Revantusk Village in the Hinterlands once this task is complete.","","Vile Priestess Hexx and the Aman'zasi Guards can be found atop Jintha'alor in the Hinterlands."},
        },

        [7862] = {
            [questKeys.requiredLevel] = 46,
            [questKeys.objectivesText] = {"You have been tasked with the decimation of 20 Vilebranch Berserkers, 3 Vilebranch Shadow Hunters, 3 Vilebranch Blood Drinkers, and 2 Vilebranch Soul Eaters.","","Should you complete this task, return to Primal Torntusk at Revantusk Village in the Hinterlands."},
        },

        [7865] = {
            [questKeys.questLevel] = 60,
        },

        [7868] = {
            [questKeys.questLevel] = 60,
        },

        [7869] = {
            [questKeys.questFlags] = 8,
        },

        [7870] = {
            [questKeys.questFlags] = 8,
        },

        [7871] = {
            [questKeys.questLevel] = 39,
        },

        [7872] = {
            [questKeys.questLevel] = 49,
        },

        [7873] = {
            [questKeys.questLevel] = 59,
        },

        [7874] = {
            [questKeys.questLevel] = 39,
            [questKeys.exclusiveTo] = {7789,7875,7876,7922,7923,7924,7925,8293,8294},
        },

        [7875] = {
            [questKeys.questLevel] = 49,
            [questKeys.exclusiveTo] = {7789,7874,7876,7922,7923,7924,7925,8293,8294},
        },

        [7876] = {
            [questKeys.questLevel] = 59,
            [questKeys.exclusiveTo] = {7789,7874,7875,7922,7923,7924,7925,8293,8294},
        },

        [7877] = {
            [questKeys.requiredLevel] = 57,
        },

        [7885] = {
            [questKeys.requiredMaxRep] = {909,5000},
        },

        [7893] = {
            [questKeys.requiredMaxRep] = {909,5000},
        },

        [7898] = {
            [questKeys.requiredMaxRep] = {909,5000},
        },

        [7903] = {
            [questKeys.requiredMaxRep] = {909,5000},
        },

        [7904] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 6,
            [questKeys.objectives] = {nil,nil,{{19182}}},
            [questKeys.questFlags] = 8,
        },

        [7905] = {
            [questKeys.objectives] = {nil,nil,{{19338}}},
        },

        [7907] = {
            [questKeys.sourceItemId] = 19228,
        },

        [7922] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7923,7924,7925,8293,8294},
        },

        [7923] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7922,7924,7925,8293,8294},
        },

        [7924] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7922,7923,7925,8293,8294},
        },

        [7925] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7922,7923,7924,8293,8294},
        },

        [7926] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{19338}}},
        },

        [7927] = {
            [questKeys.sourceItemId] = 19277,
        },

        [7928] = {
            [questKeys.sourceItemId] = 19257,
        },

        [7929] = {
            [questKeys.sourceItemId] = 19267,
        },

        [7937] = {
            [questKeys.objectives] = {nil,nil,{{19423}}},
            [questKeys.specialFlags] = 0,
        },

        [7938] = {
            [questKeys.objectives] = {nil,nil,{{19424}}},
            [questKeys.specialFlags] = 0,
        },

        [7939] = {
            [questKeys.requiredMinRep] = {909,5000},
        },

        [7941] = {
            [questKeys.requiredMinRep] = {909,5000},
        },

        [7942] = {
            [questKeys.requiredMinRep] = {909,5000},
        },

        [7943] = {
            [questKeys.requiredMinRep] = {909,5000},
        },

        [7944] = {
            [questKeys.objectives] = {nil,nil,{{19443}}},
        },

        [7945] = {
            [questKeys.objectives] = {nil,nil,{{19452}}},
            [questKeys.specialFlags] = 0,
        },

        [7946] = {
            [questKeys.questLevel] = -1,
            [questKeys.specialFlags] = 0,
        },

        [7961] = {
            [questKeys.objectivesText] = {"Collect 160 Unlucky Wabbit Feet from the Waskily Wabbits."},
            [questKeys.objectives] = {nil,nil,{{46395}}},
        },

        [7962] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Bring 3 LeCrafty Rabbit Pelts to Jon LeCraft."},
            [questKeys.objectives] = {nil,nil,{{19482}}},
            [questKeys.questFlags] = 8,
        },

        [8022] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{19642}}},
            [questKeys.questFlags] = 8,
        },

        [8024] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{19642}}},
            [questKeys.questFlags] = 8,
        },

        [8025] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{19642}}},
            [questKeys.questFlags] = 8,
        },

        [8041] = {
            [questKeys.requiredLevel] = 60,
        },

        [8042] = {
            [questKeys.requiredLevel] = 60,
        },

        [8043] = {
            [questKeys.requiredLevel] = 60,
        },

        [8045] = {
            [questKeys.requiredLevel] = 60,
        },

        [8046] = {
            [questKeys.requiredLevel] = 60,
        },

        [8047] = {
            [questKeys.requiredLevel] = 60,
        },

        [8048] = {
            [questKeys.requiredLevel] = 60,
        },

        [8049] = {
            [questKeys.requiredLevel] = 60,
        },

        [8050] = {
            [questKeys.requiredLevel] = 60,
        },

        [8051] = {
            [questKeys.requiredLevel] = 60,
        },

        [8052] = {
            [questKeys.requiredLevel] = 60,
        },

        [8053] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker Primal Hakkari Bindings.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8054] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker a Primal Hakkari Shawl.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8055] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker a Primal Hakkari Tabard.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8056] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Armsplint.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8057] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Stanchion.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8058] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker a Primal Hakkari Armsplint.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8059] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Stanchion.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8060] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing Primal Hakkari Bindings.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8061] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Stanchion.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8062] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring the following Paragons of Power from Zul'Gurub to Falthir the Sightless: A Primal Hakkari Bindings.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8063] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Falthir the Sightless a Primal Hakkari Armsplint.  You must also have a reputation equal to or greater than Friendly with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8064] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Sash.  Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale. You must also be Honored with Zandalar."},
        },

        [8065] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Tabard.  Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale. You must also be Revered with Zandalar."},
        },

        [8066] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring the following Paragons of Power from Zul'Gurub to Falthir the Sightless: A Primal Hakkari Shawl.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8067] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring the following Paragons of Power from Zul'Gurub to Falthir the Sightless: A Primal Hakkari Aegis.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8068] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Shawl.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8069] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Kossack.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8070] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Sash.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8071] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Aegis.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8072] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Falthir the Sightless a Primal Hakkari Girdle.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8073] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Falthir the Sightless a Primal Hakkari Aegis.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Falthir the Sightless is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8074] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Girdle.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8075] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Maywiki of Zuldazar a Primal Hakkari Tabard.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Maywiki of Zuldazar is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8076] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Sash.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8077] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Al'tabim the All-Seeing a Primal Hakkari Kossack.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Al'tabim the All-Seeing is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8078] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker a Primal Hakkari Girdle.  You must also have a reputation equal to or greater than Honored with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8079] = {
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Bring Jin'rokh the Breaker a Primal Hakkari Kossack.  You must also have a reputation equal to or greater than Revered with the Zandalar Tribe.","","Jin'rokh the Breaker is located on Yojamba Isle, Stranglethorn Vale."},
        },

        [8101] = {
            [questKeys.requiredLevel] = 60,
        },

        [8102] = {
            [questKeys.requiredLevel] = 60,
        },

        [8103] = {
            [questKeys.requiredLevel] = 60,
        },

        [8104] = {
            [questKeys.requiredLevel] = 60,
        },

        [8106] = {
            [questKeys.requiredLevel] = 60,
        },

        [8107] = {
            [questKeys.requiredLevel] = 60,
        },

        [8108] = {
            [questKeys.requiredLevel] = 60,
        },

        [8109] = {
            [questKeys.requiredLevel] = 60,
        },

        [8110] = {
            [questKeys.requiredLevel] = 60,
        },

        [8111] = {
            [questKeys.requiredLevel] = 60,
        },

        [8112] = {
            [questKeys.requiredLevel] = 60,
        },

        [8113] = {
            [questKeys.requiredLevel] = 60,
        },

        [8114] = {
            [questKeys.preQuestSingle] = {8105},
        },

        [8116] = {
            [questKeys.requiredLevel] = 60,
        },

        [8117] = {
            [questKeys.requiredLevel] = 60,
        },

        [8118] = {
            [questKeys.requiredLevel] = 60,
        },

        [8119] = {
            [questKeys.requiredLevel] = 60,
        },

        [8121] = {
            [questKeys.preQuestSingle] = {8120},
        },

        [8123] = {
            [questKeys.questLevel] = 59,
            [questKeys.exclusiveTo] = {8124,8160,8161,8162,8163,8164,8165,8299,8300},
        },

        [8124] = {
            [questKeys.exclusiveTo] = {8123,8160,8161,8162,8163,8164,8165,8299,8300},
        },

        [8145] = {
            [questKeys.requiredLevel] = 60,
        },

        [8146] = {
            [questKeys.requiredLevel] = 60,
        },

        [8147] = {
            [questKeys.requiredLevel] = 60,
        },

        [8149] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = nil,
        },

        [8150] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Travel to Grom's Monument in the Demon Fall Canyon of Ashenvale and use Grom's Tribute at the base of the monument.  Return to Javnir Nashak outside Orgrimmar before the Harvest Festival is over."},
            [questKeys.objectives] = nil,
        },

        [8152] = {
            [questKeys.questLevel] = 52,
            [questKeys.requiredLevel] = 50,
            [questKeys.requiredClasses] = 4,
            [questKeys.objectivesText] = {"Speak with Ogtinc in Azshara."},
            [questKeys.nextQuestInChain] = 8151,
        },

        [8153] = {
            [questKeys.objectivesText] = {"Bring a pair of Perfect Courser Antlers to Ogtinc in Azshara.  Ogtinc resides atop the cliffs northeast of the Ruins of Eldarath."},
        },

        [8160] = {
            [questKeys.questLevel] = 49,
            [questKeys.exclusiveTo] = {8123,8124,8161,8162,8163,8164,8165,8299,8300},
        },

        [8161] = {
            [questKeys.questLevel] = 39,
            [questKeys.exclusiveTo] = {8123,8124,8160,8162,8163,8164,8165,8299,8300},
        },

        [8162] = {
            [questKeys.questLevel] = 29,
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8163,8164,8165,8299,8300},
        },

        [8163] = {
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8162,8164,8165,8299,8300},
        },

        [8164] = {
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8162,8163,8165,8299,8300},
        },

        [8165] = {
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8162,8163,8164,8299,8300},
        },

        [8183] = {
            [questKeys.objectives] = {nil,nil,{{19802}}},
        },

        [8193] = {
            [questKeys.requiredSkill] = {356,150},
        },

        [8194] = {
            [questKeys.requiredSkill] = {356,150},
        },

        [8221] = {
            [questKeys.requiredSkill] = {356,150},
        },

        [8222] = {
            [questKeys.requiredMaxRep] = {909,5000},
        },

        [8223] = {
            [questKeys.requiredMinRep] = {909,5000},
        },

        [8224] = {
            [questKeys.requiredSkill] = {356,150},
        },

        [8225] = {
            [questKeys.requiredSkill] = {356,150},
        },

        [8226] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{19804}}},
        },

        [8227] = {
            [questKeys.objectives] = {nil,nil,{{19973}}},
        },

        [8228] = {
            [questKeys.requiredSkill] = {356,150},
            [questKeys.questFlags] = 0,
        },

        [8229] = {
            [questKeys.requiredSkill] = {356,150},
            [questKeys.questFlags] = 0,
        },

        [8231] = {
            [questKeys.objectivesText] = {"Bring 6 Wavethrasher Scales to Ogtinc in Azshara.  Ogtinc resides atop the cliffs northeast the Ruins of Eldarath."},
        },

        [8232] = {
            [questKeys.objectivesText] = {"Bring the Tooth of Morphaz to Ogtinc in Azshara.  Ogtinc resides atop the cliffs northeast the Ruins of Eldarath."},
        },

        [8234] = {
            [questKeys.objectivesText] = {"Retrieve the Sealed Azure Bag from the Timbermaw Shaman in Azshara.  Then take the bag to Archmage Xylem, also found in Azshara."},
        },

        [8237] = {
            [questKeys.questLevel] = 50,
            [questKeys.requiredLevel] = 50,
            [questKeys.questFlags] = 8,
        },

        [8240] = {
            [questKeys.objectivesText] = {"Destroy any one of the Hakkari Bijous found in Zul'Gurub at the Altar of Zanza on Yojamba Isle.  When done, speak with Vinchaxa nearby."},
        },

        [8244] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectives] = {nil,nil,{{19858}}},
        },

        [8245] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectives] = {nil,nil,{{19858}}},
        },

        [8247] = {
            [questKeys.questFlags] = 8,
        },

        [8248] = {
            [questKeys.questFlags] = 8,
        },

        [8251] = {
            [questKeys.preQuestSingle] = {8250},
        },

        [8255] = {
            [questKeys.objectivesText] = {"Acquire 4 Healthy Courser Glands and bring them to Ogtinc in Azshara.  Ogtinc resides atop the cliffs northeast the Ruins of Eldarath."},
        },

        [8256] = {
            [questKeys.objectivesText] = {"Acquire an Ichor of Undeath for Ogtinc in Azshara.  Ogtinc resides atop the cliffs northeast the Ruins of Eldarath."},
        },

        [8257] = {
            [questKeys.objectivesText] = {"Kill Morphaz in the sunken temple of Atal'Hakkar, and return his blood to Greta Mosshoof in Felwood.  The entrance to the sunken temple can be found in the Swamp of Sorrows."},
        },

        [8258] = {
            [questKeys.objectivesText] = {"Use the Divination Scryer in the heart of the Great Ossuary's basement in the Scholomance.  Doing so will bring forth spirits you must fight.  Defeating these spirits will summon forth Death Knight Darkreaver; defeat him.","","Bring Darkreaver's Head to Sagorne Creststrider in the Valley of Wisdom, Orgrimmar."},
            [questKeys.exclusiveTo] = {},
        },

        [8259] = {
            [questKeys.requiredRaces] = 0,
        },

        [8261] = {
            [questKeys.requiredMinRep] = {509,9000},
        },

        [8262] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredMinRep] = {509,21000},
        },

        [8264] = {
            [questKeys.requiredMinRep] = {510,9000},
        },

        [8265] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredMinRep] = {510,21000},
        },

        [8266] = {
            [questKeys.questLevel] = 39,
            [questKeys.exclusiveTo] = {8267},
        },

        [8267] = {
            [questKeys.requiredLevel] = 40,
            [questKeys.exclusiveTo] = {8266},
        },

        [8268] = {
            [questKeys.questLevel] = 39,
            [questKeys.exclusiveTo] = {8269},
        },

        [8269] = {
            [questKeys.requiredLevel] = 40,
            [questKeys.exclusiveTo] = {8268},
        },

        [8270] = {
            [questKeys.questFlags] = 8,
        },

        [8271] = {
            [questKeys.requiredRaces] = 0,
        },

        [8272] = {
            [questKeys.requiredRaces] = 0,
        },

        [8274] = {
            [questKeys.questLevel] = 5,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Kill 5 Murlocs and come back to the test character."},
            [questKeys.objectives] = {{{126}}},
            [questKeys.questFlags] = 8,
        },

        [8279] = {
            [questKeys.objectivesText] = {"Bring the three chapters of the Twilight Lexicon to Hermit Ortell in Silithus.  "},
        },

        [8280] = {
            [questKeys.preQuestSingle] = {},
        },

        [8285] = {
            [questKeys.objectives] = {nil,nil,{{20401}}},
        },

        [8287] = {
            [questKeys.objectives] = {nil,nil,{{20405}}},
        },

        [8289] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.specialFlags] = 0,
        },

        [8293] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7922,7923,7924,7925,8294},
        },

        [8294] = {
            [questKeys.exclusiveTo] = {7789,7874,7875,7876,7922,7923,7924,7925,8293},
        },

        [8296] = {
            [questKeys.requiredRaces] = 0,
        },

        [8299] = {
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8162,8163,8164,8165,8300},
        },

        [8300] = {
            [questKeys.exclusiveTo] = {8123,8124,8160,8161,8162,8163,8164,8165,8299},
        },

        [8301] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8304] = {
            [questKeys.objectives] = {{{15221},{15222}}},
        },

        [8306] = {
            [questKeys.objectivesText] = {"Commander Mar'alith at Cenarion Hold in Silithus wants you to find his beloved Natalia. The information that you gathered points to Hive'Regal in the south as being the area in which you may find Mistress Natalia Mar'alith.","","Do not forget to visit the dwarves at Bronzebeard's camp before venturing into the hive. They might have some additional work and advice for you.","","And $N, remember the Commander's words: \"Do what you must...\""},
        },

        [8308] = {
            [questKeys.objectives] = {nil,nil,{{20461}}},
        },

        [8309] = {
            [questKeys.objectives] = {nil,nil,{{20455},{20454},{20456},{20453}}},
        },

        [8311] = {
            [questKeys.objectivesText] = {"Speak with the innkeepers of Stormwind, Ironforge, and Darnassus, as well as Talvash del Kissel in Ironforge.  Perform the tricks they ask of you in exchange for the treats they offer.","","Return to Jesper at the Stormwind Orphanage with a Darnassus Marzipan, Gnomeregan Gumdrop, Stormwind Nougat, and Ironforge Mint."},
        },

        [8312] = {
            [questKeys.objectivesText] = {"Speak with the innkeepers of Orgrimmar, Undercity, and Thunder Bluff, as well as Kali Remik in Sen'jin Village.  Perform the tricks they ask of you in exchange for the treats they offer.","","Return to Spoops at the Orgrimmar Orphanage with a Thunder Bluff Marzipan, Darkspear Gumdrop, Orgrimmar Nougat, and Undercity Mint."},
            [questKeys.specialFlags] = 0,
        },

        [8313] = {
            [questKeys.objectives] = {nil,nil,{{20467}}},
        },

        [8314] = {
            [questKeys.objectives] = {nil,nil,{{20463}}},
            [questKeys.preQuestSingle] = {8309,8310},
        },

        [8315] = {
            [questKeys.objectivesText] = {"Geologist Larksbane at Cenarion Hold in Silithus wants you to recover the Crystal Unlocking Mechanism from the Qiraji Emissary.","","You have been instructed to take the Glyphs of Calling to the Bones of Grakkarond, south of Cenarion Hold, and draw them in the sand. Should the Qiraji Emissary appear, slay it and recover the Crystal Unlocking Mechanism. Return to Geologist Larksbane if you succeed.","","Assemble an army for this task, $N!"},
        },

        [8317] = {
            [questKeys.requiredSourceItems] = {},
        },

        [8322] = {
            [questKeys.objectives] = {nil,nil,{{20605}}},
        },

        [8325] = {
            [questKeys.specialFlags] = 4,
        },

        [8326] = {
            [questKeys.objectivesText] = {"Collect 8 Lynx Collars from slain Springpaw Lynxes and Springpaw Cubs.  Return to Magistrix Erona on Sunstrider Isle when you are done."},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8327] = {
            [questKeys.nextQuestInChain] = 8334,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8328] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8330] = {
            [questKeys.objectivesText] = {"Collect Well Watcher Solanian's Scrying Orb, his Scroll of Scourge Magic, and his Journal.  They are found on Sunstrider Isle by the pond, the fountain, and one of the Burning Crystals.  Return them to the Well Watcher at the Sunspire on Sunstrider Isle when you've collected them all."},
            [questKeys.breadcrumbs] = {},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [8331] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8332] = {
            [questKeys.preQuestSingle] = {8331},
            [questKeys.breadcrumbs] = {},
        },

        [8334] = {
            [questKeys.preQuestSingle] = {8327},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8335] = {
            [questKeys.objectivesText] = {"Kill 8 Arcane Wraiths and 2 Tainted Arcane Wraiths, as well as Felendren the Banished; they are located in the Falthrien Academy.  Bring Felendren's Head to Lanthan Perilon on Sunstrider Isle."},
            [questKeys.nextQuestInChain] = 8347,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8336] = {
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [8337] = {
            [questKeys.questLevel] = 2,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{20482}}},
        },

        [8338] = {
            [questKeys.objectives] = {nil,nil,{{20483}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [8341] = {
            [questKeys.preQuestSingle] = {8343},
            [questKeys.breadcrumbs] = {},
        },

        [8343] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8344] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {},
        },

        [8345] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8346] = {
            [questKeys.objectives] = {{{15468}}},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 36,
        },

        [8347] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [8348] = {
            [questKeys.preQuestSingle] = {8349},
            [questKeys.breadcrumbs] = {},
        },

        [8349] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8350] = {
            [questKeys.objectives] = {nil,nil,{{20804}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [8351] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8352] = {
            [questKeys.preQuestSingle] = {8351},
            [questKeys.breadcrumbs] = {},
        },

        [8354] = {
            [questKeys.specialFlags] = 3,
        },

        [8368] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8369] = {
            [questKeys.specialFlags] = 0,
        },

        [8370] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8372] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8373] = {
            [questKeys.objectivesText] = {"Use a Stink Bomb Cleaner to remove any Forsaken Stink Bomb that's been dropped on Southshore.  Return to Sergeant Hartman in Southshore when you're done."},
            [questKeys.objectives] = nil,
        },

        [8374] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8375] = {
            [questKeys.specialFlags] = 0,
        },

        [8381] = {
            [questKeys.requiredClasses] = 384,
        },

        [8383] = {
            [questKeys.preQuestSingle] = {8375},
        },

        [8384] = {
            [questKeys.preQuestSingle] = {8374},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8386] = {
            [questKeys.preQuestSingle] = {8372},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8387] = {
            [questKeys.preQuestSingle] = {8369},
        },

        [8389] = {
            [questKeys.preQuestSingle] = {8368},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8390] = {
            [questKeys.preQuestSingle] = {8370},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8391] = {
            [questKeys.preQuestSingle] = {8393},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8392] = {
            [questKeys.preQuestSingle] = {8394},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8393] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8394] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8395] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8396] = {
            [questKeys.exclusiveTo] = {},
        },

        [8397] = {
            [questKeys.preQuestSingle] = {8395},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8398] = {
            [questKeys.preQuestSingle] = {8396},
        },

        [8399] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8400] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8401] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8402] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8403] = {
            [questKeys.exclusiveTo] = {},
        },

        [8404] = {
            [questKeys.preQuestSingle] = {8399},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8405] = {
            [questKeys.preQuestSingle] = {8400},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8406] = {
            [questKeys.preQuestSingle] = {8401},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8407] = {
            [questKeys.preQuestSingle] = {8402},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8408] = {
            [questKeys.preQuestSingle] = {8403},
        },

        [8410] = {
            [questKeys.questLevel] = 50,
            [questKeys.exclusiveTo] = {},
        },

        [8411] = {
            [questKeys.questLevel] = 50,
            [questKeys.exclusiveTo] = {},
        },

        [8412] = {
            [questKeys.preQuestSingle] = {8410},
        },

        [8414] = {
            [questKeys.breadcrumbs] = {8415},
        },

        [8415] = {
            [questKeys.questLevel] = 50,
        },

        [8416] = {
            [questKeys.objectives] = {nil,nil,{{20612}}},
        },

        [8417] = {
            [questKeys.questLevel] = 50,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8423] = {
            [questKeys.breadcrumbs] = {},
        },

        [8424] = {
            [questKeys.questLevel] = 53,
        },

        [8426] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8427] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8428] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8429] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8430] = {
            [questKeys.exclusiveTo] = {},
        },

        [8431] = {
            [questKeys.preQuestSingle] = {8426},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8432] = {
            [questKeys.preQuestSingle] = {8427},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8433] = {
            [questKeys.preQuestSingle] = {8428},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8434] = {
            [questKeys.preQuestSingle] = {8429},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8435] = {
            [questKeys.preQuestSingle] = {8430},
        },

        [8436] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8437] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8438] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8439] = {
            [questKeys.exclusiveTo] = {},
        },

        [8440] = {
            [questKeys.preQuestSingle] = {8436},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8441] = {
            [questKeys.preQuestSingle] = {8437},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8442] = {
            [questKeys.preQuestSingle] = {8438},
            [questKeys.requiredMaxLevel] = 0,
        },

        [8443] = {
            [questKeys.preQuestSingle] = {8439},
        },

        [8444] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [8445] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"x"},
            [questKeys.questFlags] = 8,
        },

        [8446] = {
            [questKeys.objectives] = {nil,nil,{{20644}}},
        },

        [8448] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8449] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8450] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8451] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8452] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8453] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8454] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [8458] = {
            [questKeys.questLevel] = 33,
            [questKeys.requiredLevel] = 25,
            [questKeys.objectivesText] = {"Bring a Shadowstalker Scalp to Maurin Bonesplitter in Desolace."},
            [questKeys.objectives] = {nil,nil,{{6441}}},
            [questKeys.nextQuestInChain] = 1482,
            [questKeys.questFlags] = 8,
        },

        [8459] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Log"},
        },

        [8460] = {
            [questKeys.objectivesText] = {"Grazle wants you to prove yourself by killing 6 Deadwood Warriors, 6 Deadwood Pathfinders, and 6 Deadwood Gardeners.  Return to him in southern Felwood near the Emerald Sanctuary when you are done."},
        },

        [8461] = {
            [questKeys.objectivesText] = {"Nafien would like you to kill 6 Deadwood Den Watchers, 6 Deadwood Avengers, and 6 Deadwood Shamans.  Return to him in northern Felwood near the entrance to Timbermaw Hold."},
        },

        [8462] = {
            [questKeys.objectivesText] = {"Travel north along the main road in Felwood and speak with the furbolg named Nafien.  He stands guard outside the entrance to Timbermaw Hold."},
        },

        [8464] = {
            [questKeys.objectivesText] = {"Salfa wants you to kill 8 Winterfall Shaman, 8 Winterfall Den Watchers, and 8 Winterfall Ursa.  Salfa is located just outside the entrance to Timbermaw Hold in Winterspring."},
        },

        [8465] = {
            [questKeys.objectivesText] = {"Travel through Timbermaw Hold and exit into Winterspring.  Speak with Salfa, who stands guard outside the entrance to Timbermaw Hold."},
            [questKeys.preQuestSingle] = {},
        },

        [8467] = {
            [questKeys.preQuestSingle] = {8460},
        },

        [8470] = {
            [questKeys.objectivesText] = {"Take the Deadwood Ritual Totem inside Timbermaw Hold and see if one of the furbolgs there will find a use for the item.  The Timbermaw will not speak with you unless you are of Neutral reputation or greater with them."},
            [questKeys.objectives] = {nil,nil,{{20741}}},
        },

        [8471] = {
            [questKeys.objectivesText] = {"Take the Winterfall Ritual Totem inside Timbermaw Hold and see if one of the furbolgs there will find a use for the item.  The Timbermaw will not speak with you unless you are of Neutral reputation or greater with them."},
            [questKeys.objectives] = {nil,nil,{{20742}}},
        },

        [8473] = {
            [questKeys.objectivesText] = {"Slay 10 Withered Green Keepers at the Scorched Grove.  Then report back to Larianna Riverwind inside the tower just to the northwest of the Scorched Grove in Eversong Woods."},
            [questKeys.preQuestSingle] = {9258},
            [questKeys.breadcrumbs] = {},
        },

        [8474] = {
            [questKeys.objectivesText] = {"Find the person who might have made Old Whitebark's Pendant.  They might provide some insight on the item."},
            [questKeys.objectives] = {nil,nil,{{23228}}},
        },

        [8476] = {
            [questKeys.preQuestSingle] = {9359},
            [questKeys.breadcrumbs] = {},
        },

        [8479] = {
            [questKeys.objectivesText] = {"Ven'jashi, the troll prisoner at Tor'Watha, wants you to bring him Chieftain Zul'Marosh's Head.  Chieftain Zul'Marosh can be found in Zeb'Watha, across Lake Elrendar."},
        },

        [8481] = {
            [questKeys.objectivesText] = {"Plant the Demon Summoning Torch in the mouth of High Chief Winterfall's cave in the Winterfall furbolg village.  Defeat the demon and retrieve the Essence of Xandivious for Gorn One Eye in Timbermaw Hold."},
            [questKeys.objectives] = {nil,nil,{{21144},{21145}}},
        },

        [8482] = {
            [questKeys.objectives] = {nil,nil,{{20765}}},
        },

        [8484] = {
            [questKeys.objectives] = {nil,nil,{{21155}}},
        },

        [8485] = {
            [questKeys.objectives] = {nil,nil,{{21155}}},
        },

        [8487] = {
            [questKeys.preQuestSingle] = {9254},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
        },

        [8488] = {
            [questKeys.objectives] = nil,
        },

        [8490] = {
            [questKeys.objectivesText] = {"Place the Infused Crystal at the Eastern Runestone and protect it from the Scourge for 1 minute.  Return the Infused Crystal to Runewarden Deryan in Eversong Woods for a reward."},
            [questKeys.objectives] = {{{16364}},nil,{{22693}}},
            [questKeys.preQuestSingle] = {9253},
            [questKeys.breadcrumbs] = {},
        },

        [8492] = {
            [questKeys.requiredRaces] = 0,
        },

        [8493] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Copper Bars to Sergeant Stonebrow in Ironforge."},
        },

        [8494] = {
            [questKeys.requiredRaces] = 0,
        },

        [8495] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Iron Bars to Corporal Carnes in Ironforge."},
        },

        [8496] = {
            [questKeys.objectivesText] = {"Bring 30 Heavy Runecloth Bandages, 30 Heavy Silk Bandages and 30 Heavy Mageweave Bandages to Windcaller Proudhorn at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing X in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14530},{8545},{6451},{20806}}},
        },

        [8497] = {
            [questKeys.objectivesText] = {"Bring 4 Globes of Water, 4 Powerful Anti-Venom and 4 Smoked Desert Dumplings to Calandrath at the inn in Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing I in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{7079},{19440},{20452},{20807}}},
        },

        [8498] = {
            [questKeys.objectivesText] = {"Obtain the Twilight Battle Orders and bring them Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Tactical Task Briefing X in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{20803},{20943}}},
            [questKeys.specialFlags] = 0,
        },

        [8499] = {
            [questKeys.requiredRaces] = 0,
        },

        [8500] = {
            [questKeys.objectivesText] = {"Bring 20 Thorium Bars to Dame Twinbraid in Ironforge."},
        },

        [8501] = {
            [questKeys.objectivesText] = {"Kill 30 Hive'Ashi Stingers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing XII in order to complete this quest."},
            [questKeys.objectives] = {{{11698}},nil,{{20941}}},
        },

        [8502] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Ashi Workers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing III in order to complete this quest."},
            [questKeys.objectives] = {{{11721}},nil,{{20942}}},
        },

        [8503] = {
            [questKeys.requiredRaces] = 0,
        },

        [8504] = {
            [questKeys.objectivesText] = {"Bring 20 Stranglekelp to Private Draxlegauge in Ironforge."},
        },

        [8505] = {
            [questKeys.requiredRaces] = 0,
        },

        [8506] = {
            [questKeys.objectivesText] = {"Bring 20 Purple Lotus to Master Nightsong in Ironforge."},
        },

        [8507] = {
            [questKeys.objectivesText] = {"Report for duty at the Ironforge Brigade post near Hive'Zora.  Prepare your Unsigned Field Duty Papers and obtain Signed Field Duty Papers from Captain Blackanvil and return to Windcaller Kaldon at Cenarion Hold in Silithus.","","Note: Healing or casting beneficial spells on a member of the Ironforge Brigade will flag you for PvP."},
        },

        [8509] = {
            [questKeys.requiredRaces] = 0,
        },

        [8510] = {
            [questKeys.objectivesText] = {"Bring 20 Arthas' Tears to Sergeant Major Germaine in Ironforge."},
        },

        [8511] = {
            [questKeys.requiredRaces] = 0,
        },

        [8512] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Light Leather to Bonnie Stoneflayer in Ironforge."},
        },

        [8513] = {
            [questKeys.requiredRaces] = 0,
        },

        [8514] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Medium Leather to Private Porter in Ironforge."},
        },

        [8515] = {
            [questKeys.requiredRaces] = 0,
        },

        [8516] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Thick Leather to Marta Finespindle in Ironforge."},
        },

        [8517] = {
            [questKeys.requiredRaces] = 0,
        },

        [8518] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Linen Bandages to Sentinel Silversky in Ironforge."},
        },

        [8520] = {
            [questKeys.requiredRaces] = 0,
        },

        [8521] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Silk Bandages to Nurse Stonefield in Ironforge."},
        },

        [8522] = {
            [questKeys.requiredRaces] = 0,
        },

        [8523] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Runecloth Bandages to Keeper Moonshade in Ironforge."},
        },

        [8524] = {
            [questKeys.requiredRaces] = 0,
        },

        [8525] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Rainbow Fin Albacore to Slicky Gastronome in Ironforge."},
        },

        [8526] = {
            [questKeys.requiredRaces] = 0,
        },

        [8527] = {
            [questKeys.objectivesText] = {"Bring 20 Roast Raptor to Sarah Sadwhistle in Ironforge."},
        },

        [8528] = {
            [questKeys.requiredRaces] = 0,
        },

        [8529] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Spotted Yellowtail to Huntress Swiftriver in Ironforge."},
        },

        [8530] = {
            [questKeys.objectives] = {nil,nil,{{20737}}},
        },

        [8531] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Bring 50 singed corestones to Commander Stronghammer at the airfield in Dun Morogh."},
            [questKeys.objectives] = {nil,nil,{{20737}}},
        },

        [8532] = {
            [questKeys.requiredRaces] = 0,
        },

        [8533] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 copper bars to Miner Cromwell in Orgrimmar."},
        },

        [8534] = {
            [questKeys.objectivesText] = {"Contact Cenarion Scout Azenel inside Hive'Zora and return the Hive'Zora Scout Report to Windcaller Proudhorn at Cenarion Hold.  You must also bring Tactical Task Briefing VI in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{21158},{21165}}},
        },

        [8535] = {
            [questKeys.objectivesText] = {"Summon and slay a Hoary Templar and report back to Bor Wildmane in Cenarion Hold.  You must also bring Tactical Task Briefing IV in order to complete this quest."},
            [questKeys.objectives] = {{{15212}},nil,{{20947}}},
        },

        [8536] = {
            [questKeys.objectivesText] = {"Summon and slay an Earthen Templar and report back to Bor Wildmane in Cenarion Hold.  You must also bring Tactical Task Briefing III in order to complete this quest."},
            [questKeys.objectives] = {{{15307}},nil,{{21751}}},
            [questKeys.specialFlags] = 0,
        },

        [8537] = {
            [questKeys.objectivesText] = {"Summon and slay a Crimson Templar and report back to Bor Wildmane in Cenarion Hold.  You must also bring Tactical Task Briefing II in order to complete this quest."},
            [questKeys.objectives] = {{{15209}},nil,{{20945}}},
        },

        [8538] = {
            [questKeys.objectivesText] = {"Find a way to summon and slay the Duke of Cynders, the Duke of Fathoms, the Duke of Zephyrs and the Duke of Shards and report back to Commander Mar'alith in Cenarion Hold.  You must also bring Tactical Task Briefing V in order to complete this quest."},
            [questKeys.objectives] = {{{15206},{15207},{15220},{15208}},nil,{{20948}}},
        },

        [8539] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Zora Hive Sisters and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing V in order to complete this quest."},
            [questKeys.objectives] = {{{11729}},nil,{{21249}}},
        },

        [8540] = {
            [questKeys.objectivesText] = {"Bring 3 Ornate Mithril Boots to Vish Kozus, Captain of the Guard at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing II in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{7936},{20939}}},
        },

        [8541] = {
            [questKeys.objectivesText] = {"Bring 10 Dense Grinding Stones, 10 Solid Grinding Stones and 10 Heavy Grinding Stones to Vish Kozus, Captain of the Guard at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing III in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{12644},{7966},{3486},{20940}}},
        },

        [8542] = {
            [questKeys.requiredRaces] = 0,
        },

        [8543] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 tin bars to Grunt Maug in Orgrimmar."},
        },

        [8544] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of Night, 5 Stone Scarabs and 5 Clay Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8545] = {
            [questKeys.requiredRaces] = 0,
        },

        [8546] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Mithril Bars to Senior Sergeant T'kelah in Orgrimmar."},
        },

        [8547] = {
            [questKeys.objectives] = {nil,nil,{{20938}}},
        },

        [8548] = {
            [questKeys.objectivesText] = {"Bring 5 Cenarion Combat Badges, 3 Cenarion Logistics Badges and 7 Cenarion Tactical Badges to Vargus at Cenarion Hold in Silithus.  You must also attain Friendly reputation with Cenarion Circle to be able to complete this quest."},
        },

        [8549] = {
            [questKeys.requiredRaces] = 0,
        },

        [8550] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Peacebloom to Herbalist Proudfeather in Orgrimmar."},
        },

        [8551] = {
            [questKeys.questLevel] = 47,
            [questKeys.requiredRaces] = 690,
        },

        [8552] = {
            [questKeys.objectives] = {nil,nil,{{3985}}},
            [questKeys.specialFlags] = 1,
        },

        [8553] = {
            [questKeys.questLevel] = 50,
        },

        [8554] = {
            [questKeys.questLevel] = 50,
        },

        [8555] = {
            [questKeys.objectivesText] = {"Speak with Anachronos."},
        },

        [8556] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Magisterial Ring, 2 Lambent Idols, 5 Bronze Scarabs and 5 Ivory Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8557] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Martial Drape, 2 Onyx Idols, 5 Silver Scarabs and 5 Bone Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8558] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Spiked Hilt, 2  Alabaster Idols, 5 Crystal Scarabs and 5 Stone Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8559] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of War, 5 Ivory Scarabs and 5 Gold Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8560] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8561] = {
            [questKeys.objectivesText] = {"Bring Vek'nilash's Circlet, 2 Idols of the Sun, 5 Stone Scarabs and 5 Crystal Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8562] = {
            [questKeys.objectivesText] = {"Bring the the Carapace of the Old God, 2 Idols of War, 5 Silver Scarabs and 5 Bone Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8563] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8564] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [8571] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 40,
            [questKeys.objectives] = {nil,nil,{{15564}}},
            [questKeys.questFlags] = 8,
        },

        [8572] = {
            [questKeys.objectivesText] = {"Bring 7 Cenarion Combat Badges, 4 Cenarion Logistics Badges and 4 Cenarion Tactical Badges to Vargus at Cenarion Hold in Silithus.  You must also attain Honored reputation with Cenarion Circle to be able to complete this quest."},
        },

        [8573] = {
            [questKeys.objectivesText] = {"Bring 15 Cenarion Combat Badges, 20 Cenarion Logistics Badges, 20 Cenarion Tactical Badges and 1 Mark of Cenarius to Vargus at Cenarion Hold in Silithus.  You must also attain Exalted reputation with Cenarion Circle to be able to complete this quest."},
        },

        [8574] = {
            [questKeys.objectivesText] = {"Bring 15 Cenarion Combat Badges, 20 Cenarion Logistics Badges, 17 Cenarion Tactical Badges and 1 Mark of Remulos to Vargus at Cenarion Hold in Silithus.  You must also attain Revered reputation with Cenarion Circle to be able to complete this quest."},
        },

        [8575] = {
            [questKeys.objectives] = {nil,nil,{{20949}}},
        },

        [8576] = {
            [questKeys.objectivesText] = {"We need to figure out what Azuregos wrote in this ledger."},
        },

        [8577] = {
            [questKeys.objectivesText] = {"Narain Soothfancy wants you to find his ex-best friend forever (BFF),"," Stewvul, and take back the scrying goggles that Stewvul stole from him."},
        },

        [8579] = {
            [questKeys.preQuestSingle] = {8595},
        },

        [8580] = {
            [questKeys.requiredRaces] = 0,
        },

        [8581] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Firebloom to Batrider Pele'keiki in Orgrimmar."},
        },

        [8582] = {
            [questKeys.requiredRaces] = 0,
        },

        [8583] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Purple Lotus to Apothecary Jezel in Orgrimmar."},
        },

        [8587] = {
            [questKeys.objectives] = {nil,nil,{{21028}}},
        },

        [8588] = {
            [questKeys.requiredRaces] = 0,
        },

        [8589] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Heavy Leather to Skinner Jamani in Orgrimmar."},
        },

        [8590] = {
            [questKeys.requiredRaces] = 0,
        },

        [8591] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Thick Leather to Sergeant Umala in Orgrimmar."},
        },

        [8592] = {
            [questKeys.objectivesText] = {"Bring Vek'nilash's Circlet, 2 Idols of the Sage, 5 Silver Scarabs and 5 Bone Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8593] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8594] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of Rebirth, 5 Silver Scarabs and 5 Ivory Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8596] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of Death, 5 Bronze Scarabs and 5 Gold Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8598] = {
            [questKeys.objectives] = {nil,nil,{{21029}}},
        },

        [8599] = {
            [questKeys.objectives] = {nil,nil,{{21032}}},
        },

        [8600] = {
            [questKeys.requiredRaces] = 0,
        },

        [8601] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 10 Rugged Leather to Doctor Serratus in Orgrimmar."},
        },

        [8602] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Life, 5 Gold Scarabs and 5 Crystal Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8603] = {
            [questKeys.objectivesText] = {"Bring the the Husk of the Old God, 2 Idols of Death, 5 Stone Scarabs and 5 Crystal Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8604] = {
            [questKeys.requiredRaces] = 0,
        },

        [8605] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Wool Bandages to Healer Longrunner in Orgrimmar."},
        },

        [8607] = {
            [questKeys.requiredRaces] = 0,
        },

        [8608] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Mageweave Bandages to Lady Callow in Orgrimmar."},
        },

        [8609] = {
            [questKeys.requiredRaces] = 0,
        },

        [8610] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Runecloth Bandages to Stoneguard Clayhoof in Orgrimmar."},
        },

        [8611] = {
            [questKeys.requiredRaces] = 0,
        },

        [8612] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Lean Wolf Steaks to Bloodguard Rawtar in Orgrimmar."},
        },

        [8613] = {
            [questKeys.requiredRaces] = 0,
        },

        [8614] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Spotted Yellowtail to Fisherman Lin'do in Orgrimmar."},
        },

        [8615] = {
            [questKeys.requiredRaces] = 0,
        },

        [8616] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Bring 20 Baked Salmon to Chief Sharpclaw in Orgrimmar."},
            [questKeys.preQuestSingle] = {8615},
        },

        [8617] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Bring 50 singed corestones to General Zog in Durotar."},
            [questKeys.objectives] = {nil,nil,{{20737}}},
            [questKeys.questFlags] = 8,
        },

        [8618] = {
            [questKeys.objectives] = {nil,nil,{{20737}}},
        },

        [8620] = {
            [questKeys.requiredSourceItems] = {},
        },

        [8621] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of the Sage, 5 Bronze Scarabs and 5 Clay Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8622] = {
            [questKeys.objectivesText] = {"Bring the Carapace of the Old God, 2 Idols of the Sage, 5 Silver Scarabs and 5 Bone Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8623] = {
            [questKeys.objectivesText] = {"Bring Vek'lor's Diadem, 2 Idols of Rebirth, 5 Stone Scarabs and 5 Crystal Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8624] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8625] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Death, 5 Stone Scarabs and 5 Bronze Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8626] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of Life, 5 Stone Scarabs and 5 Bone Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8627] = {
            [questKeys.objectivesText] = {"Bring the the Carapace of the Old God, 2 Idols of the Sage, 5 Silver Scarabs and 5 Bone Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8628] = {
            [questKeys.objectivesText] = {"Bring Vek'lor's Diadem, 2 Idols of Rebirth, 5 Stone Scarabs and 5 Crystal Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8629] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8630] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Life, 5 Crystal Scarabs and 5 Gold Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8631] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8632] = {
            [questKeys.objectivesText] = {"Bring Vek'nilash's Circlet, 2 Idols of Night, 5 Bronze Scarabs and 5 Ivory Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8633] = {
            [questKeys.objectivesText] = {"Bring the Husk of the Old God, 2 Idols of the Sun, 5 Gold Scarabs and 5 Clay Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8634] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of the Sun, 5 Silver Scarabs and 5 Crystal Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8637] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of Strife, 5 Crystal Scarabs and 5 Bone Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8638] = {
            [questKeys.objectivesText] = {"Bring the the Carapace of the Old God, 2 Idols of Strife, 5 Bronze Scarabs and 5 Ivory Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8639] = {
            [questKeys.objectivesText] = {"Bring Vek'lor's Diadem, 2 Idols of the War, 5 Gold Scarabs and 5 Clay Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8640] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8641] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of the Sun, 5 Silver Scarabs and 5 Clay Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8655] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of the Sage, 5 Bronze Scarabs and 5 Clay Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8656] = {
            [questKeys.objectivesText] = {"Bring the the Carapace of the Old God, 2 Idols of Life, 5 Gold Scarabs and 5 Clay Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8657] = {
            [questKeys.objectivesText] = {"Bring Vek'lor's Diadem, 2 Idols of Strife, 5 Bronze Scarabs and 5 Ivory Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8658] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8659] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Command, 2 Idols of War, 5 Crystal Scarabs and 5 Ivory Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8660] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Night, 5 Clay Scarabs and 5 Ivory Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8661] = {
            [questKeys.objectivesText] = {"Bring the the Husk of the Old God, 2 Idols of Night, 5 Stone Scarabs and 5 Crystal Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8662] = {
            [questKeys.objectivesText] = {"Bring Vek'nilash's Circlet, 2 Idols of Death, 5 Silver Scarabs and 5 Bone Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8663] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8664] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of the Sage, 5 Bronze Scarabs and 5 Bone Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8665] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Rebirth, 5 Stone Scarabs and 5 Silver Scarabs to Kandrostrasz in Ahn'Qiraj.  This quest also requires Neutral faction with the Brood of Nozdormu."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8666] = {
            [questKeys.objectivesText] = {"Bring the the Husk of the Old God, 2 Idols of Rebirth, 5 Bronze Scarabs and 5 Ivory Scarabs to Vethsera inside Ahn'Qiraj.  You must also attain Honored reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8667] = {
            [questKeys.objectivesText] = {"Bring Vek'lor's Diadem, 2 Idols of Life, 5 Gold Scarabs and 5 Clay Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Friendly reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8668] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8669] = {
            [questKeys.objectivesText] = {"Bring the Qiraji Bindings of Dominance, 2 Idols of Strife, 5 Gold Scarabs and 5 Bone Scarabs to Andorgos in Ahn'Qiraj.  You must also attain Neutral reputation with the Brood of Nozdormu to complete this quest."},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [8687] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Zora Tunnelers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing VII in order to complete this quest."},
            [questKeys.objectives] = {{{11726}},nil,{{21251}}},
        },

        [8689] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Martial Drape, 2 Jasper Idols, 5 Gold Scarabs and 5 Clay Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8690] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Regal Drape, 2 Obsidian Idols, 5 Clay Scarabs and 5 Gold Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8691] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Martial Drape, 2 Alabaster Idols, 5 Stone Scarabs and 5 Crystal Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8692] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Regal Drape, 2 Vermillion Idols, 5 Silver Scarabs and 5 Bone Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8693] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Martial Drape, 2 Azure Idols, 5 Bronze Scarabs and 5 Ivory Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8694] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Regal Drape, 2 Amber Idols, 5 Ivory Scarabs and 5 Bronze Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8695] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Regal Drape, 2 Obsidian Idols, 5 Gold Scarabs and 5 Clay Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8696] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Regal Drape, 2 Lambent Idols, 5 Stone Scarabs and 5 Crystal Scarabs to Keyl Swiftclaw in Silithus.  You must also obtain Revered reputation with Cenarion Circle to complete this quest."},
        },

        [8697] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ceremonial Ring, 2 Obsidian Idols, 5 Silver Scarabs and 5 Bone Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8698] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Magisterial Ring, 2 Vermillion Idols, 5 Silver Scarabs and 5 Bone Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8699] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Magisterial Ring, 2 Azure Idols, 5 Gold Scarabs and 5 Clay Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8700] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Magisterial Ring, 2 Alabaster Idols, 5 Bronze Scarabs and 5 Ivory Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8701] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ceremonial Ring, 2 Onyx Idols, 5 Stone Scarabs and 5 Crystal Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8702] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ceremonial Ring, 2 Jasper Idols, 5 Stone Scarabs and 5 Crystal Scarabs to Windcaller Yessendra  in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8703] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Magisterial Ring, 2 Vermillion Idols, 5 Silver Scarabs and 5 Bone Scarabs to Windcaller Yessendra  in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8704] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ceremonial Ring, 2 Amber Idols, 5 Gold Scarabs and 5 Clay Scarabs to Windcaller Yessendra in Silithus.  You must also attain Honored reputation with Cenarion Circle to complete this quest."},
        },

        [8705] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ornate Hilt, 2  Lambent Idols, 5 Bronze Scarabs and 5 Ivory Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8706] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Spiked Hilt, 2  Amber Idols, 5 Ivory Scarabs and 5 Bronze Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8707] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ornate Hilt, 2  Obsidian Idols, 5 Silver Scarabs and 5 Bone Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8708] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ornate Hilt, 2  Jasper Idols, 5 Crystal Scarabs and 5 Stone Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8709] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Spiked Hilt, 2  Vermillion Idols, 5 Gold Scarabs and 5 Clay Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8710] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Ornate Hilt, 2  Onyx Idols, 5 Gold Scarabs and 5 Clay Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8711] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Spiked Hilt, 2  Amber Idols, 5 Bronze Scarabs and 5 Ivory Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8712] = {
            [questKeys.objectivesText] = {"Bring 1 Qiraji Spiked Hilt, 2 Azure Idols, 5 Silver Scarabs and 5 Bone Scarabs to Warden Haro in Silithus.  You must also attain Exalted reputation with Cenarion Circle to complete this quest."},
        },

        [8728] = {
            [questKeys.preQuestSingle] = {8578,8587,8620},
        },

        [8731] = {
            [questKeys.objectivesText] = {"Report to Krug Skullsplit at the Orgrimmar Legion post in front of Hive'Regal.  Prepare your Unsigned Field Duty Papers, obtain Signed Field Duty Papers and bring them to Windcaller Kaldon in Cenarion Hold.","","Note: Healing or casting beneficial spells on a member of the Orgrimmar Legion will flag you for PvP."},
        },

        [8734] = {
            [questKeys.objectivesText] = {"Travel to the Moonglade and speak to Keeper Remulos. "},
        },

        [8737] = {
            [questKeys.objectivesText] = {"Summon and slay an Azure Templar and report back to Bor Wildmane in Cenarion Hold.  You must also bring Tactical Task Briefing I in order to complete this quest."},
            [questKeys.objectives] = {{{15211}},nil,{{21245}}},
        },

        [8738] = {
            [questKeys.objectivesText] = {"Contact Cenarion Scout Landion inside Hive'Regal and return the Hive'Regal Scout Report to Windcaller Proudhorn at Cenarion Hold.  You must also bring Tactical Task Briefing VII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{21160},{21166}}},
        },

        [8739] = {
            [questKeys.objectivesText] = {"Contact Cenarion Scout Jalia inside Hive'Ashi and return the Hive'Ashi Scout Report to Windcaller Proudhorn at Cenarion Hold.  You must also bring Tactical Task Briefing VIII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{21161},{21167}}},
        },

        [8740] = {
            [questKeys.objectivesText] = {"Slay Twilight Marauder Morna and 5 Twilight Marauders.  Report to Windcaller Proudhorn when your task is finished.  You must also bring Tactical Task Briefing IX in order to complete this quest."},
            [questKeys.objectives] = {{{15541},{15542}},nil,{{20944}}},
        },

        [8741] = {
            [questKeys.objectives] = {nil,nil,{{21139}}},
        },

        [8742] = {
            [questKeys.preQuestSingle] = {8729,8730,8741},
        },

        [8746] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectivesText] = {"Find Metzen the Reindeer.  Use the notes provided to you for clues as to where he is being held.","","When you find Metzen, have the Pouch of Reindeer Dust in your possession so you can sprinkle some of the dust on him; this should free Metzen from his bonds of captivity.","","Return the Pouch of Reindeer Dust to Kaymard Copperpinch in Orgrimmar once Metzen is freed."},
            [questKeys.requiredSourceItems] = {},
        },

        [8747] = {
            [questKeys.exclusiveTo] = {8752,8757},
        },

        [8748] = {
            [questKeys.exclusiveTo] = {},
        },

        [8749] = {
            [questKeys.exclusiveTo] = {},
        },

        [8750] = {
            [questKeys.exclusiveTo] = {},
        },

        [8751] = {
            [questKeys.exclusiveTo] = {},
        },

        [8752] = {
            [questKeys.exclusiveTo] = {8747,8757},
        },

        [8753] = {
            [questKeys.exclusiveTo] = {},
        },

        [8754] = {
            [questKeys.exclusiveTo] = {},
        },

        [8755] = {
            [questKeys.exclusiveTo] = {},
        },

        [8756] = {
            [questKeys.exclusiveTo] = {},
        },

        [8757] = {
            [questKeys.exclusiveTo] = {8747,8752},
        },

        [8758] = {
            [questKeys.exclusiveTo] = {},
        },

        [8759] = {
            [questKeys.exclusiveTo] = {},
        },

        [8760] = {
            [questKeys.exclusiveTo] = {},
        },

        [8761] = {
            [questKeys.exclusiveTo] = {},
        },

        [8762] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectivesText] = {"Find Metzen the Reindeer.  Use the notes provided to you for clues as to where he is being held.","","When you find Metzen, have the Pouch of Reindeer Dust in your possession so you can sprinkle some of the dust on him; this should free Metzen from his bonds of captivity.","","Return the Pouch of Reindeer Dust to Wulmort Jinglepocket in Ironforge once Metzen is freed."},
            [questKeys.requiredSourceItems] = {},
        },

        [8767] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [8770] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Ashi Defenders and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing I in order to complete this quest."},
            [questKeys.objectives] = {{{11722}},nil,{{21749}}},
        },

        [8771] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Ashi Sandstalkers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing II in order to complete this quest."},
            [questKeys.objectives] = {{{11723}},nil,{{21750}}},
        },

        [8772] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Zora Waywatchers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing VI in order to complete this quest."},
            [questKeys.objectives] = {{{11725}},nil,{{21250}}},
        },

        [8773] = {
            [questKeys.objectivesText] = {"Slay 30 Hive'Zora Reavers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing IV in order to complete this quest."},
            [questKeys.objectives] = {{{11728}},nil,{{21248}}},
        },

        [8774] = {
            [questKeys.objectivesText] = {"Kill 30 Hive'Regal Ambushers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing VIII in order to complete this quest."},
            [questKeys.objectives] = {{{11730}},nil,{{21252}}},
        },

        [8775] = {
            [questKeys.objectivesText] = {"Kill 30 Hive'Regal Spitfires and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing IX in order to complete this quest."},
            [questKeys.objectives] = {{{11732}},nil,{{21253}}},
        },

        [8776] = {
            [questKeys.objectivesText] = {"Kill 30 Hive'Regal Slavemakers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing X in order to complete this quest."},
            [questKeys.objectives] = {{{11733}},nil,{{21255}}},
        },

        [8777] = {
            [questKeys.objectivesText] = {"Kill 30 Hive'Regal Burrowers and report back to Commander Mar'alith at Cenarion Hold in Silithus.  You must also bring Combat Task Briefing XI in order to complete this quest."},
            [questKeys.objectives] = {{{11731}},nil,{{21256}}},
        },

        [8778] = {
            [questKeys.objectivesText] = {"Bring 6 Oils of Immolation, 5 Goblin Rocket Fuel and 10 Dense Blasting Powder to Arcanist Nozzlespring near Hive'Zora in Silithus.  You must also bring Logistics Task Briefing IV in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{8956},{9061},{15992},{21257}}},
        },

        [8779] = {
            [questKeys.objectivesText] = {"Bring 1 Large Brilliant Shard, 1 Large Radiant Shard and 1 Huge Emerald to Geologist Larksbane at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing V in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14344},{11178},{12364},{21259}}},
        },

        [8780] = {
            [questKeys.objectivesText] = {"Bring 8 Rugged Armor Kits and 8 Heavy Armor Kits to Janela Stouthammer at the Ironforge Brigade Outpost near Hive'Zora in Silithus.  You must also bring Logistics Task Briefing VII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{15564},{4265},{21263}}},
        },

        [8781] = {
            [questKeys.objectivesText] = {"Bring 2 Moonsteel Broadswords to Janela Stouthammer at the Ironforge Brigade Outpost outside of Hive'Zora.  You must also bring Logistics Task Briefing VI in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{3853},{21260}}},
        },

        [8782] = {
            [questKeys.objectivesText] = {"Bring 1 Mooncloth, 2 Bolts of Runecloth and 1 Ironweb Spider Silk to Windcaller Proudhorn at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing VIII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14342},{14048},{14227},{21262}}},
        },

        [8783] = {
            [questKeys.objectivesText] = {"Bring 2 Enchanted Thorium Bars and 2 Enchanted Leather to Vargus at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing IX in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{12655},{12810},{21265}}},
        },

        [8784] = {
            [questKeys.objectives] = {nil,nil,{{21230}}},
        },

        [8785] = {
            [questKeys.objectivesText] = {"Bring 6 Powerful Mojo, 6 Flasks of Big Mojo and 8 Oils of Immolation to Shadow Priestess Shai near Hive'Regal in Silithus.  You must also bring Logistics Task Briefing IV in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{8956},{8152},{12804},{21258}}},
        },

        [8786] = {
            [questKeys.objectivesText] = {"Bring 3 Massive Iron Axes to Merok Longstride at the Orgrimmar Legion camp outside of Hive'Regal.  You must also bring Logistics Task Briefing VI in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{3855},{21261}}},
        },

        [8787] = {
            [questKeys.objectivesText] = {"Bring 8 Rugged Armor Kits and 8 Heavy Armor Kits to Merok Longstride near Hive'Regal.  You must also bring Logistics Task Briefing VII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{15564},{4265},{21264}}},
        },

        [8788] = {
            [questKeys.requiredLevel] = 1,
            [questKeys.requiredClasses] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [8791] = {
            [questKeys.objectives] = {nil,nil,{{21220}}},
        },

        [8795] = {
            [questKeys.exclusiveTo] = {},
        },

        [8796] = {
            [questKeys.exclusiveTo] = {},
        },

        [8797] = {
            [questKeys.exclusiveTo] = {},
        },

        [8798] = {
            [questKeys.requiredSkill] = {202,1},
        },

        [8799] = {
            [questKeys.questFlags] = 0,
        },

        [8801] = {
            [questKeys.objectives] = {nil,nil,{{21221}}},
        },

        [8802] = {
            [questKeys.objectives] = {nil,nil,{{21221}}},
        },

        [8804] = {
            [questKeys.objectivesText] = {"Bring 4 Globes of Water, 4 Powerful Anti-Venom and 4 Smoked Desert Dumplings to Calandrath at the inn in Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing I in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{7079},{19440},{20452},{21378}}},
            [questKeys.specialFlags] = 0,
        },

        [8805] = {
            [questKeys.objectivesText] = {"Bring 3 Ornate Mithril Boots to Vish Kozus, Captain of the Guard at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing II in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{7936},{21379}}},
        },

        [8806] = {
            [questKeys.objectivesText] = {"Bring 10 Dense Grinding Stones, 10 Solid Grinding Stones and 10 Heavy Grinding Stones to Vish Kozus, Captain of the Guard at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing III in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{12644},{7966},{3486},{21380}}},
            [questKeys.specialFlags] = 0,
        },

        [8807] = {
            [questKeys.objectivesText] = {"Bring 1 Large Brilliant Shard, 1 Large Radiant Shard and 1 Huge Emerald to Geologist Larksbane at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing V in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14344},{11178},{12364},{21382}}},
        },

        [8808] = {
            [questKeys.objectivesText] = {"Bring 1 Mooncloth, 2 Bolts of Runecloth and 1 Ironweb Spider Silk to Windcaller Proudhorn at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing VIII in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14342},{14048},{14227},{21384}}},
        },

        [8809] = {
            [questKeys.objectivesText] = {"Bring 2 Enchanted Thorium Bars and 2 Enchanted Leather to Vargus at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing IX in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{12655},{12810},{21381}}},
        },

        [8810] = {
            [questKeys.objectivesText] = {"Bring 30 Heavy Runecloth Bandages, 30 Heavy Silk Bandages and 30 Heavy Mageweave Bandages to Windcaller Proudhorn at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing X in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{14530},{8545},{6451},{21385}}},
        },

        [8829] = {
            [questKeys.objectivesText] = {"Bring a Skin of Shadow, 3 Frayed Abomination Stitchings and 1 Twilight Cultist Robe to Aurel Goldleaf at Cenarion Hold in Silithus.  You must also bring Logistics Task Briefing XI in order to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{12753},{12735},{20407},{21514}}},
            [questKeys.specialFlags] = 0,
        },

        [8856] = {
            [questKeys.objectives] = {nil,nil,{{7079},{19440},{20452},{20807}}},
        },

        [8857] = {
            [questKeys.objectives] = {nil,nil,{{21534}}},
        },

        [8858] = {
            [questKeys.objectives] = {nil,nil,{{21535}}},
        },

        [8859] = {
            [questKeys.objectives] = {nil,nil,{{21533}}},
        },

        [8860] = {
            [questKeys.objectives] = {nil,nil,{{21545}}},
        },

        [8861] = {
            [questKeys.objectives] = {nil,nil,{{21545}}},
        },

        [8863] = {
            [questKeys.specialFlags] = 0,
        },

        [8864] = {
            [questKeys.specialFlags] = 0,
        },

        [8865] = {
            [questKeys.specialFlags] = 0,
        },

        [8867] = {
            [questKeys.objectives] = {{{15893},{15894}}},
            [questKeys.requiredSourceItems] = {},
            [questKeys.breadcrumbs] = {},
        },

        [8868] = {
            [questKeys.objectivesText] = {"Summon Omen, defeat him and gain Elune's Blessing.  Return to Valadar Starsong in Nighthaven"},
        },

        [8869] = {
            [questKeys.exclusiveTo] = {},
        },

        [8870] = {
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger in the Mystic Ward of Ironforge.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8871,8872,8873,8874,8875},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8871] = {
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger in the Park District in Stormwind.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8870,8872,8873,8874,8875},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8872] = {
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger at the Cenarion Enclave in Darnassus.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8870,8871,8873,8874,8875},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8873] = {
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger in the Valley of Wisdom in Orgrimmar.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8870,8871,8872,8874,8875},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8874] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger in the entrance to the Undercity.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8870,8871,8872,8873,8875},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8875] = {
            [questKeys.objectivesText] = {"Talk to the Lunar Festival Harbinger at the Elder Rise in Thunder Bluff.  You can also talk to Lunar Festival Harbingers in other capital cities."},
            [questKeys.exclusiveTo] = {8870,8871,8872,8873,8874},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8876] = {
            [questKeys.specialFlags] = 0,
        },

        [8877] = {
            [questKeys.specialFlags] = 0,
        },

        [8878] = {
            [questKeys.specialFlags] = 0,
        },

        [8879] = {
            [questKeys.specialFlags] = 0,
        },

        [8880] = {
            [questKeys.specialFlags] = 0,
        },

        [8881] = {
            [questKeys.specialFlags] = 0,
        },

        [8882] = {
            [questKeys.specialFlags] = 0,
        },

        [8883] = {
            [questKeys.requiredSourceItems] = {},
        },

        [8884] = {
            [questKeys.objectivesText] = {"Collect 8 Grimscale Murloc Heads.  Return them to Hathvelion Sungaze in the Eversong Woods on the bluff overlooking the Tranquil Shore."},
        },

        [8885] = {
            [questKeys.objectivesText] = {"Retrieve the Ring of Mmmrrrggglll from the Grimscale chieftain's dead clutches.  Return it to Hathvelion Sungaze in the Eversong Woods on the bluff overlooking the Tranquil Shore."},
        },

        [8887] = {
            [questKeys.objectives] = {nil,nil,{{21776}}},
        },

        [8888] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8889] = {
            [questKeys.objectives] = {nil,{{180916},{180919},{180920}},{{24337}}},
            [questKeys.breadcrumbs] = {},
            [questKeys.specialFlags] = 32,
        },

        [8891] = {
            [questKeys.objectives] = {nil,nil,{{21783}}},
        },

        [8892] = {
            [questKeys.preQuestSingle] = {9256},
            [questKeys.breadcrumbs] = {},
        },

        [8894] = {
            [questKeys.preQuestSingle] = {9394},
            [questKeys.breadcrumbs] = {},
        },

        [8895] = {
            [questKeys.objectives] = {nil,nil,{{21807}}},
        },

        [8897] = {
            [questKeys.objectives] = {nil,nil,{{21921}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8898] = {
            [questKeys.objectives] = {nil,nil,{{21920}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8899] = {
            [questKeys.objectives] = {nil,nil,{{21925}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [8900] = {
            [questKeys.objectives] = {nil,nil,{{21926}}},
            [questKeys.exclusiveTo] = {},
        },

        [8901] = {
            [questKeys.objectives] = {nil,nil,{{22264}}},
            [questKeys.exclusiveTo] = {},
        },

        [8902] = {
            [questKeys.objectives] = {nil,nil,{{22265}}},
            [questKeys.exclusiveTo] = {},
        },

        [8903] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.breadcrumbs] = {},
        },

        [8904] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 8979,
        },

        [8905] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8906] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8907] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8908] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8909] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8910] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8911] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8912] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8913] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8914] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8915] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8916] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8917] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8918] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8919] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8920] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8922] = {
            [questKeys.objectives] = {nil,nil,{{21985}}},
        },

        [8923] = {
            [questKeys.objectives] = {nil,nil,{{22382}}},
        },

        [8924] = {
            [questKeys.objectivesText] = {"Use the Ectoplasmic Distiller near incorporeal undead to collect 12 Scorched Ectoplasms in Silithus, 12 Frozen Ectoplasms in Winterspring and 12 Stable Ectoplasms in the Eastern Plaguelands.  Bring them along with the Ectoplasmic Distiller back to Mux Manascrambler in Gadgetzan."},
            [questKeys.objectives] = {nil,nil,{{21937},{21936},{21935},{21946}}},
        },

        [8945] = {
            [questKeys.objectives] = nil,
            [questKeys.specialFlags] = 2,
        },

        [8946] = {
            [questKeys.objectives] = {nil,nil,{{22139}}},
        },

        [8948] = {
            [questKeys.objectives] = {nil,nil,{{21983}}},
        },

        [8950] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [8962] = {
            [questKeys.nextQuestInChain] = 8966,
        },

        [8963] = {
            [questKeys.nextQuestInChain] = 8967,
        },

        [8964] = {
            [questKeys.nextQuestInChain] = 8968,
        },

        [8965] = {
            [questKeys.nextQuestInChain] = 8969,
        },

        [8966] = {
            [questKeys.objectives] = {{{16080}},nil,{{21984},{22049}}},
            [questKeys.preQuestSingle] = {8962},
            [questKeys.exclusiveTo] = {},
        },

        [8967] = {
            [questKeys.objectives] = {{{16097}},nil,{{21984},{22050}}},
            [questKeys.preQuestSingle] = {8963},
            [questKeys.exclusiveTo] = {},
        },

        [8968] = {
            [questKeys.objectives] = {{{16101},{16102}},nil,{{21984},{22051}}},
            [questKeys.preQuestSingle] = {8964},
            [questKeys.exclusiveTo] = {},
        },

        [8969] = {
            [questKeys.objectives] = {{{16118}},nil,{{21984},{22052}}},
            [questKeys.preQuestSingle] = {8965},
            [questKeys.exclusiveTo] = {},
        },

        [8971] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22117},{22143},{22176}}},
            [questKeys.questFlags] = 8,
        },

        [8972] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22123},{22142},{22175}}},
            [questKeys.questFlags] = 8,
        },

        [8973] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22120},{22140},{21960}}},
            [questKeys.questFlags] = 8,
        },

        [8974] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22121},{22145},{22174}}},
            [questKeys.questFlags] = 8,
        },

        [8975] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22122},{22144},{22177}}},
            [questKeys.questFlags] = 8,
        },

        [8976] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22119},{22141},{22173}}},
            [questKeys.questFlags] = 8,
        },

        [8977] = {
            [questKeys.objectivesText] = {"Bring the Extra-Dimensional Ghost Revealer  to Deliana in Ironforge."},
            [questKeys.objectives] = {nil,nil,{{22115}}},
        },

        [8978] = {
            [questKeys.objectives] = {nil,nil,{{22115}}},
        },

        [8981] = {
            [questKeys.requiredRaces] = 0,
        },

        [8982] = {
            [questKeys.preQuestSingle] = {8980},
        },

        [8985] = {
            [questKeys.preQuestSingle] = {8964,8970},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 8990,
        },

        [8986] = {
            [questKeys.preQuestSingle] = {8965,8970},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 8989,
        },

        [8987] = {
            [questKeys.preQuestSingle] = {8962,8970},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 8991,
        },

        [8988] = {
            [questKeys.preQuestSingle] = {8963,8970},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 8992,
        },

        [8989] = {
            [questKeys.objectives] = {{{16080}},nil,{{22048},{22049}}},
            [questKeys.preQuestSingle] = {8986},
            [questKeys.exclusiveTo] = {},
        },

        [8990] = {
            [questKeys.objectives] = {{{16097}},nil,{{22048},{22050}}},
            [questKeys.preQuestSingle] = {8985},
            [questKeys.exclusiveTo] = {},
        },

        [8991] = {
            [questKeys.objectives] = {{{16101},{16102}},nil,{{22048},{22051}}},
            [questKeys.preQuestSingle] = {8987},
            [questKeys.exclusiveTo] = {},
        },

        [8992] = {
            [questKeys.objectives] = {{{16118}},nil,{{22048},{22052}}},
            [questKeys.preQuestSingle] = {8988},
            [questKeys.exclusiveTo] = {},
        },

        [8993] = {
            [questKeys.requiredRaces] = 0,
        },

        [9015] = {
            [questKeys.objectivesText] = {"Travel to the Ring of the Law in Blackrock Depths and place the Banner of Provocation in its center as you are sentenced by High Justice Grimstone.  Slay Theldren and his gladiators and return to Anthion Harmon in the Eastern Plaguelands with the first piece of Lord Valthalak's amulet."},
            [questKeys.objectives] = {nil,nil,{{22047}}},
        },

        [9020] = {
            [questKeys.objectivesText] = {"Return to Mokvar in Orgimmar with a set of  Shadowcraft Boots, Shadowcraft Pants and Shadowcraft Spaulders."},
        },

        [9024] = {
            [questKeys.preQuestSingle] = {8903},
        },

        [9026] = {
            [questKeys.preQuestSingle] = {9025},
        },

        [9029] = {
            [questKeys.preQuestSingle] = {},
        },

        [9031] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectivesText] = {"Speak to Mokvar in Orgrimmar."},
        },

        [9033] = {
            [questKeys.objectives] = {{{351048},{351012},{351024},{351059}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [9034] = {
            [questKeys.specialFlags] = 0,
        },

        [9035] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9036] = {
            [questKeys.specialFlags] = 0,
        },

        [9037] = {
            [questKeys.specialFlags] = 0,
        },

        [9038] = {
            [questKeys.specialFlags] = 0,
        },

        [9039] = {
            [questKeys.specialFlags] = 0,
        },

        [9040] = {
            [questKeys.specialFlags] = 0,
        },

        [9041] = {
            [questKeys.specialFlags] = 0,
        },

        [9042] = {
            [questKeys.specialFlags] = 0,
        },

        [9043] = {
            [questKeys.specialFlags] = 0,
        },

        [9044] = {
            [questKeys.specialFlags] = 0,
        },

        [9045] = {
            [questKeys.specialFlags] = 0,
        },

        [9046] = {
            [questKeys.specialFlags] = 0,
        },

        [9047] = {
            [questKeys.specialFlags] = 0,
        },

        [9048] = {
            [questKeys.specialFlags] = 0,
        },

        [9049] = {
            [questKeys.specialFlags] = 0,
        },

        [9050] = {
            [questKeys.specialFlags] = 0,
        },

        [9054] = {
            [questKeys.specialFlags] = 0,
        },

        [9055] = {
            [questKeys.specialFlags] = 0,
        },

        [9056] = {
            [questKeys.specialFlags] = 0,
        },

        [9057] = {
            [questKeys.specialFlags] = 0,
        },

        [9058] = {
            [questKeys.specialFlags] = 0,
        },

        [9059] = {
            [questKeys.specialFlags] = 0,
        },

        [9060] = {
            [questKeys.specialFlags] = 0,
        },

        [9061] = {
            [questKeys.specialFlags] = 0,
        },

        [9062] = {
            [questKeys.breadcrumbs] = {},
        },

        [9064] = {
            [questKeys.objectives] = {nil,nil,{{22414}}},
        },

        [9065] = {
            [questKeys.objectives] = {{{25499}}},
        },

        [9066] = {
            [questKeys.objectivesText] = {"Use Antheol's Disciplinary Rod on his two students: Apprentice Ralen and Apprentice Meledor.  Return to Antheol at Stillwhisper Pond in Eversong Woods with the rod after this."},
            [questKeys.objectives] = {{{15945},{15941}},nil,{{22473}}},
            [questKeys.specialFlags] = 32,
        },

        [9067] = {
            [questKeys.preQuestSingle] = {9395},
            [questKeys.breadcrumbs] = {},
        },

        [9068] = {
            [questKeys.specialFlags] = 0,
        },

        [9069] = {
            [questKeys.specialFlags] = 0,
        },

        [9070] = {
            [questKeys.specialFlags] = 0,
        },

        [9071] = {
            [questKeys.specialFlags] = 0,
        },

        [9072] = {
            [questKeys.specialFlags] = 0,
        },

        [9073] = {
            [questKeys.specialFlags] = 0,
        },

        [9074] = {
            [questKeys.specialFlags] = 0,
        },

        [9075] = {
            [questKeys.specialFlags] = 0,
        },

        [9077] = {
            [questKeys.specialFlags] = 0,
        },

        [9078] = {
            [questKeys.specialFlags] = 0,
        },

        [9079] = {
            [questKeys.specialFlags] = 0,
        },

        [9080] = {
            [questKeys.objectivesText] = {"Rohan the Assassin at Light's Hope Chapel in the Eastern Plaguelands will make Bonescythe Pauldrons if you bring him the following: 1 Desecrated Pauldrons, 12 Wartorn Leather Scraps, 5 Cured Rugged Hides, 1 Nexus Crystal and 50 gold pieces. "},
            [questKeys.specialFlags] = 0,
        },

        [9081] = {
            [questKeys.objectivesText] = {"Rohan the Assassin at Light's Hope Chapel in the Eastern Plaguelands will make Bonescythe Sabatons if you bring him the following: 1 Desecrated Sabatons, 12 Wartorn Leather Scraps, 3 Cured Rugged Hides, 2 Nexus Crystals and 25 gold pieces. "},
            [questKeys.specialFlags] = 0,
        },

        [9082] = {
            [questKeys.objectivesText] = {"Rohan the Assassin at Light's Hope Chapel in the Eastern Plaguelands will make Bonescythe Gauntlets if you bring him the following: 1 Desecrated Gauntlets, 8 Wartorn Leather Scraps, 1 Arcanite Bar and 5 Cured Rugged Hides. "},
            [questKeys.specialFlags] = 0,
        },

        [9083] = {
            [questKeys.specialFlags] = 0,
        },

        [9084] = {
            [questKeys.specialFlags] = 0,
        },

        [9086] = {
            [questKeys.specialFlags] = 0,
        },

        [9087] = {
            [questKeys.specialFlags] = 0,
        },

        [9088] = {
            [questKeys.specialFlags] = 0,
        },

        [9089] = {
            [questKeys.specialFlags] = 0,
        },

        [9090] = {
            [questKeys.specialFlags] = 0,
        },

        [9091] = {
            [questKeys.specialFlags] = 0,
        },

        [9092] = {
            [questKeys.specialFlags] = 0,
        },

        [9093] = {
            [questKeys.specialFlags] = 0,
        },

        [9094] = {
            [questKeys.objectivesText] = {"Collect 30 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9095] = {
            [questKeys.specialFlags] = 0,
        },

        [9096] = {
            [questKeys.specialFlags] = 0,
        },

        [9097] = {
            [questKeys.specialFlags] = 0,
        },

        [9098] = {
            [questKeys.specialFlags] = 0,
        },

        [9099] = {
            [questKeys.specialFlags] = 0,
        },

        [9100] = {
            [questKeys.specialFlags] = 0,
        },

        [9101] = {
            [questKeys.specialFlags] = 0,
        },

        [9102] = {
            [questKeys.specialFlags] = 0,
        },

        [9103] = {
            [questKeys.specialFlags] = 0,
        },

        [9104] = {
            [questKeys.specialFlags] = 0,
        },

        [9105] = {
            [questKeys.specialFlags] = 0,
        },

        [9106] = {
            [questKeys.specialFlags] = 0,
        },

        [9107] = {
            [questKeys.specialFlags] = 0,
        },

        [9108] = {
            [questKeys.specialFlags] = 0,
        },

        [9109] = {
            [questKeys.specialFlags] = 0,
        },

        [9110] = {
            [questKeys.specialFlags] = 0,
        },

        [9111] = {
            [questKeys.specialFlags] = 0,
        },

        [9112] = {
            [questKeys.specialFlags] = 0,
        },

        [9113] = {
            [questKeys.specialFlags] = 0,
        },

        [9114] = {
            [questKeys.specialFlags] = 0,
        },

        [9115] = {
            [questKeys.specialFlags] = 0,
        },

        [9116] = {
            [questKeys.specialFlags] = 0,
        },

        [9117] = {
            [questKeys.specialFlags] = 0,
        },

        [9118] = {
            [questKeys.specialFlags] = 0,
        },

        [9120] = {
            [questKeys.objectives] = {nil,nil,{{22520}}},
            [questKeys.preQuestSingle] = {},
        },

        [9121] = {
            [questKeys.requiredMinRep] = {529,9000},
            [questKeys.nextQuestInChain] = 0,
        },

        [9122] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9123] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9124] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9125] = {
            [questKeys.requiredMinRep] = false,
        },

        [9126] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9127] = {
            [questKeys.requiredMinRep] = false,
        },

        [9128] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9129] = {
            [questKeys.requiredMinRep] = false,
        },

        [9130] = {
            [questKeys.objectives] = {nil,nil,{{22549}}},
        },

        [9131] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9132] = {
            [questKeys.requiredMinRep] = false,
        },

        [9133] = {
            [questKeys.objectives] = {nil,nil,{{22549}}},
        },

        [9134] = {
            [questKeys.objectives] = {nil,nil,{{22550}}},
        },

        [9135] = {
            [questKeys.objectives] = {nil,nil,{{22550}}},
        },

        [9136] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9137] = {
            [questKeys.requiredMinRep] = false,
        },

        [9140] = {
            [questKeys.objectivesText] = {"Gather 6 Phantasmal Substance and 4 Gargoyle Fragments.  Return them to Arcanist Vandril at Tranquillien in the Ghostlands."},
        },

        [9141] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.nextQuestInChain] = 0,
        },

        [9142] = {
            [questKeys.requiredMinRep] = false,
        },

        [9143] = {
            [questKeys.preQuestSingle] = {9145},
            [questKeys.breadcrumbs] = {},
        },

        [9144] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9145] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9147] = {
            [questKeys.preQuestSingle] = {9144},
            [questKeys.breadcrumbs] = {},
        },

        [9148] = {
            [questKeys.objectives] = {nil,nil,{{22717}}},
        },

        [9151] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9154] = {
            [questKeys.objectives] = {nil,nil,{{22595}}},
        },

        [9155] = {
            [questKeys.objectivesText] = {"Slay 10 Risen Hungerers and 10 Gangled Cannibals on the Dead Scar.  Return to Deathstalker Rathiel in Tranquillien for a reward."},
        },

        [9156] = {
            [questKeys.objectivesText] = {"Search the Ghostlands for Knucklerot and Luzran.  Bring their heads to Deathstalker Rathiel in Tranquillien for a reward."},
        },

        [9161] = {
            [questKeys.breadcrumbs] = {},
        },

        [9162] = {
            [questKeys.objectives] = {nil,nil,{{22706}}},
        },

        [9164] = {
            [questKeys.objectivesText] = {"Take Renzithen's Restorative Draught to Deatholme and rescue Apprentice Varnis,  Apothecary Enith and Ranger Vedoran.  Return to Arcanist Janeda at the Sanctum of the Sun for a reward."},
            [questKeys.objectives] = {{{16208},{16206},{16209}},nil,{{22628}}},
        },

        [9165] = {
            [questKeys.objectives] = {{{16254}},nil,{{22593}}},
            [questKeys.questFlags] = 64,
            [questKeys.specialFlags] = 0,
        },

        [9166] = {
            [questKeys.objectives] = {nil,nil,{{22594}}},
        },

        [9169] = {
            [questKeys.specialFlags] = 32,
        },

        [9170] = {
            [questKeys.objectivesText] = {"Magister Idonis wants you to venture into Deatholme to slay Masophet the Black, Jurion the Deceiver, Borgoth the Bloodletter and Mirdoran the Fallen.  Report back to him in the Sanctum of the Sun in the Ghostlands after you've completed this task."},
        },

        [9172] = {
            [questKeys.objectives] = {nil,nil,{{22706}}},
        },

        [9174] = {
            [questKeys.objectivesText] = {"Geranis Whitemorn wants you to swim to the bottom of the lake east of Suncrown Village and use the Bundle of Medallions on the Altar of Tidal Mastery.  Summon and slay the elemental known as Aquantion and return to Geranis."},
            [questKeys.objectives] = {{{16292}},nil,{{22675}}},
        },

        [9175] = {
            [questKeys.objectives] = {nil,nil,{{22597}}},
        },

        [9176] = {
            [questKeys.objectivesText] = {"Travel to the Bleeding Ziggurat and the Howling Ziggurat and recover the Stone of Light and the Stone of Flame.  Return to Magister Kaendris at the Sanctum of the Sun after recovering the items."},
        },

        [9177] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{22627}}},
            [questKeys.preQuestSingle] = {},
        },

        [9178] = {
            [questKeys.objectives] = {nil,nil,{{22600},{12643}}},
        },

        [9179] = {
            [questKeys.objectives] = {nil,nil,{{22601},{12422}}},
        },

        [9180] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{22627}}},
        },

        [9181] = {
            [questKeys.objectives] = {nil,nil,{{22602},{12792}}},
        },

        [9182] = {
            [questKeys.objectives] = {nil,nil,{{22603},{12775}}},
        },

        [9183] = {
            [questKeys.objectives] = {nil,nil,{{22604},{12417}}},
        },

        [9184] = {
            [questKeys.objectives] = {nil,nil,{{22605},{15086}}},
        },

        [9185] = {
            [questKeys.objectives] = {nil,nil,{{22606},{15564}}},
        },

        [9186] = {
            [questKeys.objectives] = {nil,nil,{{22607},{15088}}},
        },

        [9187] = {
            [questKeys.objectives] = {nil,nil,{{22608},{15095}}},
        },

        [9188] = {
            [questKeys.objectives] = {nil,nil,{{22609},{14104}}},
        },

        [9189] = {
            [questKeys.objectives] = {nil,nil,{{22629}}},
        },

        [9190] = {
            [questKeys.objectives] = {nil,nil,{{22610},{13864}}},
        },

        [9191] = {
            [questKeys.objectives] = {nil,nil,{{22611},{14046}}},
        },

        [9193] = {
            [questKeys.objectives] = {nil,{{181148}},{{22755}}},
            [questKeys.specialFlags] = 34,
        },

        [9194] = {
            [questKeys.objectives] = {nil,nil,{{22612},{13858}}},
        },

        [9195] = {
            [questKeys.objectives] = {nil,nil,{{22613},{10646}}},
        },

        [9196] = {
            [questKeys.objectives] = {nil,nil,{{22614},{15993}}},
        },

        [9197] = {
            [questKeys.objectives] = {nil,nil,{{22615},{10725}}},
        },

        [9198] = {
            [questKeys.objectives] = {nil,nil,{{22616},{16000}}},
        },

        [9200] = {
            [questKeys.objectives] = {nil,nil,{{22617},{13444}}},
        },

        [9201] = {
            [questKeys.objectives] = {nil,nil,{{22620},{13461}}},
        },

        [9202] = {
            [questKeys.objectives] = {nil,nil,{{22618},{13446}}},
        },

        [9203] = {
            [questKeys.objectives] = {nil,nil,{{22621},{13506}}},
        },

        [9204] = {
            [questKeys.objectives] = {nil,nil,{{22622},{13422}}},
        },

        [9205] = {
            [questKeys.objectives] = {nil,nil,{{22623},{13890}}},
        },

        [9206] = {
            [questKeys.objectives] = {nil,nil,{{22624},{13757}}},
        },

        [9208] = {
            [questKeys.requiredLevel] = 60,
        },

        [9209] = {
            [questKeys.requiredLevel] = 60,
        },

        [9210] = {
            [questKeys.requiredLevel] = 60,
        },

        [9211] = {
            [questKeys.requiredMinRep] = false,
        },

        [9213] = {
            [questKeys.requiredMinRep] = false,
        },

        [9220] = {
            [questKeys.preQuestSingle] = {9151},
            [questKeys.breadcrumbs] = {},
        },

        [9229] = {
            [questKeys.preQuestSingle] = {},
        },

        [9231] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.questFlags] = 8,
        },

        [9233] = {
            [questKeys.objectives] = {nil,nil,{{22719}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.preQuestSingle] = {},
        },

        [9234] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9235] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9236] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9237] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9238] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9239] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9240] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9241] = {
            [questKeys.objectivesText] = {"Craftsman Wilhelm at Light's Hope Chapel in the Eastern Plaguelands wants 4 Frozen Runes, 12 Enchanted Leather, 3 Essence of Water, 3 Cured Rugged Hides and 200 gold. "},
            [questKeys.preQuestSingle] = {9233},
        },

        [9242] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9243] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9244] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9245] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9246] = {
            [questKeys.preQuestSingle] = {9233},
        },

        [9247] = {
            [questKeys.objectives] = {nil,nil,{{22723}}},
        },

        [9248] = {
            [questKeys.requiredMinRep] = {609,9000},
        },

        [9250] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {nil,nil,{{22727}}},
        },

        [9251] = {
            [questKeys.requiredClasses] = 0,
        },

        [9252] = {
            [questKeys.breadcrumbs] = {},
        },

        [9253] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9254] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9255] = {
            [questKeys.objectives] = {nil,nil,{{22735}}},
        },

        [9256] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9257] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {{{16387}},nil,{{22737}}},
        },

        [9258] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9259] = {
            [questKeys.questFlags] = 0,
        },

        [9260] = {
            [questKeys.questLevel] = 10,
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9261] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9262] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9263] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9264] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9265] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 0,
        },

        [9266] = {
            [questKeys.questFlags] = 0,
        },

        [9268] = {
            [questKeys.questFlags] = 0,
        },

        [9269] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {{{16387}},nil,{{22737}}},
        },

        [9270] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {{{16387}},nil,{{22737}}},
        },

        [9271] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.objectives] = {{{16387}},nil,{{22737}}},
        },

        [9273] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{22822}}},
            [questKeys.questFlags] = 8,
        },

        [9275] = {
            [questKeys.specialFlags] = 32,
        },

        [9278] = {
            [questKeys.objectives] = {nil,nil,{{22888}}},
        },

        [9279] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.specialFlags] = 4,
        },

        [9280] = {
            [questKeys.preQuestSingle] = {9279},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbs] = {},
            [questKeys.specialFlags] = 4,
        },

        [9282] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9283] = {
            [questKeys.specialFlags] = 4,
        },

        [9287] = {
            [questKeys.questFlags] = 65664,
            [questKeys.specialFlags] = 4,
        },

        [9288] = {
            [questKeys.questFlags] = 65664,
            [questKeys.specialFlags] = 4,
        },

        [9289] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 4,
        },

        [9290] = {
            [questKeys.questFlags] = 65664,
            [questKeys.specialFlags] = 4,
        },

        [9291] = {
            [questKeys.questFlags] = 65664,
            [questKeys.specialFlags] = 4,
        },

        [9292] = {
            [questKeys.objectives] = {nil,nil,{{22949}}},
        },

        [9293] = {
            [questKeys.specialFlags] = 4,
        },

        [9294] = {
            [questKeys.specialFlags] = 36,
        },

        [9295] = {
            [questKeys.objectives] = {nil,nil,{{22932}}},
        },

        [9296] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Deliver the Dim Necrotic Stone to SOMEONE."},
            [questKeys.objectives] = {nil,nil,{{22949}}},
            [questKeys.sourceItemId] = 22949,
            [questKeys.questFlags] = 8,
        },

        [9297] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Deliver the Dim Necrotic Stone to SOMEONE."},
            [questKeys.objectives] = {nil,nil,{{22949}}},
            [questKeys.sourceItemId] = 22949,
            [questKeys.questFlags] = 8,
        },

        [9298] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Deliver the Dim Necrotic Stone to SOMEONE."},
            [questKeys.objectives] = {nil,nil,{{22949}}},
            [questKeys.sourceItemId] = 22949,
            [questKeys.questFlags] = 8,
        },

        [9299] = {
            [questKeys.objectives] = {nil,nil,{{22945}}},
        },

        [9300] = {
            [questKeys.objectives] = {nil,nil,{{22946}}},
        },

        [9301] = {
            [questKeys.objectives] = {nil,nil,{{22930}}},
        },

        [9302] = {
            [questKeys.objectives] = {nil,nil,{{22944}}},
        },

        [9303] = {
            [questKeys.objectives] = {{{16534}},nil,{{22962}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbs] = {},
            [questKeys.specialFlags] = 4,
        },

        [9304] = {
            [questKeys.objectives] = {nil,nil,{{22948}}},
        },

        [9305] = {
            [questKeys.specialFlags] = 4,
        },

        [9306] = {
            [questKeys.questLevel] = 4,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Speak with Vindicator Aldar at the Crash Site in Ammen Vale."},
            [questKeys.nextQuestInChain] = 9307,
            [questKeys.questFlags] = 136,
        },

        [9307] = {
            [questKeys.questLevel] = 4,
            [questKeys.requiredLevel] = 2,
            [questKeys.objectivesText] = {"Kill 14 Mutated Owlkin and then return to Vindicator Aldar at the Crash Site in Ammen Vale."},
            [questKeys.objectives] = {{{16537}}},
            [questKeys.questFlags] = 136,
        },

        [9308] = {
            [questKeys.questLevel] = 4,
            [questKeys.requiredLevel] = 3,
            [questKeys.objectivesText] = {"Take the Blood Elf Amulet to Vindicator Aldar at the Crash Site in Ammen Vale."},
            [questKeys.objectives] = {nil,nil,{{22989}}},
            [questKeys.sourceItemId] = 22989,
            [questKeys.questFlags] = 128,
        },

        [9309] = {
            [questKeys.specialFlags] = 4,
        },

        [9310] = {
            [questKeys.objectives] = {nil,nil,{{22950}}},
        },

        [9311] = {
            [questKeys.specialFlags] = 4,
        },

        [9312] = {
            [questKeys.preQuestSingle] = {9311},
            [questKeys.specialFlags] = 4,
        },

        [9313] = {
            [questKeys.specialFlags] = 4,
        },

        [9314] = {
            [questKeys.specialFlags] = 4,
        },

        [9316] = {
            [questKeys.questLevel] = 50,
            [questKeys.requiredLevel] = 50,
            [questKeys.objectivesText] = {"Brianna Schneider on Designer Island wants 10 Goblin Teeth."},
            [questKeys.objectives] = {nil,nil,{{23074}}},
            [questKeys.questFlags] = 8,
        },

        [9317] = {
            [questKeys.objectivesText] = {"Collect 8 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9318] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 8 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9320] = {
            [questKeys.objectivesText] = {"Collect 15 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9321] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 15 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9324] = {
            [questKeys.objectives] = {nil,nil,{{23179}}},
        },

        [9325] = {
            [questKeys.objectives] = {nil,nil,{{23180}}},
        },

        [9326] = {
            [questKeys.objectives] = {nil,nil,{{23181}}},
        },

        [9328] = {
            [questKeys.objectives] = {nil,nil,{{22653}}},
        },

        [9330] = {
            [questKeys.objectives] = {nil,nil,{{23182}}},
        },

        [9331] = {
            [questKeys.objectives] = {nil,nil,{{23183}}},
        },

        [9332] = {
            [questKeys.objectives] = {nil,nil,{{23184}}},
        },

        [9333] = {
            [questKeys.objectivesText] = {"Collect 30 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9334] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 8 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9335] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 8 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9336] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 15 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9337] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 15 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9339] = {
            [questKeys.objectivesText] = {"Return the Flame of Stormwind to (NAME)."},
            [questKeys.preQuestSingle] = {9330,9331,9332,11933},
        },

        [9341] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 10 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9343] = {
            [questKeys.questLevel] = -1,
            [questKeys.objectivesText] = {"Collect 10 Necrotic Runes."},
            [questKeys.preQuestSingle] = {},
        },

        [9344] = {
            [questKeys.objectivesText] = {"Far Seer Regulkut wants you to track down her student Grelag.  "},
        },

        [9347] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Bring the Pulsating Voidwalker Essence to Mahuram Stouthoof in Thrallmar."},
            [questKeys.objectives] = {nil,nil,{{23216}}},
            [questKeys.sourceItemId] = 23216,
            [questKeys.questFlags] = 128,
        },

        [9348] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Slay 10 Captive Ravager Hatchlings and retrieve 12 Ravager Eggs for Mahuram Stouthoof in Thrallmar."},
            [questKeys.objectives] = {{{16900}},nil,{{23217}}},
            [questKeys.questFlags] = 136,
        },

        [9350] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectivesText] = {"Gather 8 Clefthoof Hides and 8 sets of Clefthoof Bones from the Raging Clefthoof. Return to Watch Commander Krunk in Thrallmar once you have all the materials."},
            [questKeys.objectives] = {nil,nil,{{23223},{23222}}},
            [questKeys.questFlags] = 136,
        },

        [9352] = {
            [questKeys.objectivesText] = {"Travel to the West Sanctum, southwest of Falconwing Square and defeat any intruders present there.  Report your findings to Ley-Keeper Velania."},
        },

        [9353] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23227}}},
            [questKeys.questFlags] = 8,
        },

        [9354] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectivesText] = {"Gather 8 Clefthoof Hides and 8 Clefthoof Sinews from the Raging Clefthoof. When you have the materials,bring them to Humphry in Honor Hold."},
            [questKeys.objectives] = {nil,nil,{{23222},{23231}}},
            [questKeys.questFlags] = 136,
        },

        [9355] = {
            [questKeys.preQuestSingle] = {10142},
        },

        [9358] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9359] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9360] = {
            [questKeys.objectives] = {nil,nil,{{23249}}},
        },

        [9361] = {
            [questKeys.objectives] = {nil,nil,{{23248},{23268}}},
        },

        [9362] = {
            [questKeys.objectivesText] = {"Retrieve the Prismatic Shell for Archmage Xylem.  The Archmage resides in a tower atop the cliffs of Azshara."},
        },

        [9364] = {
            [questKeys.objectivesText] = {"Polymorph the Spitelash of Azshara and kill the clones that appear several seconds later.  When you have slain 50 Polymorph Clones, return to Archmage Xylem in Azshara."},
            [questKeys.objectives] = {{{16479}},nil,{{23250}}},
        },

        [9365] = {
            [questKeys.objectivesText] = {"Return the Flame of Stormwind to (NAME)."},
            [questKeys.preQuestSingle] = {9324,9325,9326,11935},
        },

        [9369] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9370] = {
            [questKeys.objectivesText] = {"Place the Signaling Gem near the Altar of Aggonar at the Pools of Aggonar and defeat any Draenei Anchorites that respond to your summons.  Return to Ryathen the Somber at Falcon Watch with the Signaling Gem after completing this task."},
            [questKeys.objectives] = {{{16994}},nil,{{23358}}},
        },

        [9371] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9373] = {
            [questKeys.objectives] = {nil,nil,{{23338}}},
        },

        [9377] = {
            [questKeys.questLevel] = 63,
            [questKeys.requiredLevel] = 61,
            [questKeys.objectivesText] = {"Retrieve a Potent Voidwalker Essence from the Vengeful Voidwalkers and return to Taleris Dawngazer at Falcon Watch."},
            [questKeys.objectives] = {nil,nil,{{23352}}},
            [questKeys.questFlags] = 136,
        },

        [9379] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 58,
            [questKeys.objectivesText] = {"Gather 6 Warp Hound Blood and bring them to Angela \"The Claw\" Kestrel in Thrallmar."},
            [questKeys.objectives] = {nil,nil,{{23374}}},
            [questKeys.questFlags] = 136,
        },

        [9380] = {
            [questKeys.objectives] = {nil,nil,{{23378}}},
        },

        [9384] = {
            [questKeys.questLevel] = 63,
            [questKeys.requiredLevel] = 61,
            [questKeys.objectivesText] = {"Take the Glowing Sanctified Crystal to Rumatu at the Temple of Sha'naar,who will invoke the Light to smite the demon within."},
            [questKeys.objectives] = {{{17014}}},
            [questKeys.sourceItemId] = 23442,
            [questKeys.questFlags] = 128,
        },

        [9385] = {
            [questKeys.objectives] = {{{16934}}},
        },

        [9387] = {
            [questKeys.objectivesText] = {"Travel to the Ruins of Sha'naar in Hellfire Peninsula and obtain 5 Demonic Essences from the Illidari Taskmasters.  Return to Apothecary Azethen at Falcon Watch after you've completed the task."},
        },

        [9391] = {
            [questKeys.objectivesText] = {"Ranger Captain Venn'ren at Falcon Watch wants you to go to the Great Fissure in Hellfire Peninsula and light the Southern Beacon, Western Beacon and Central Beacon.  Return to him with the Lit Torch after you've completed this task."},
            [questKeys.objectives] = {nil,{{181581},{181580},{181579}},{{23480}}},
            [questKeys.specialFlags] = 32,
        },

        [9392] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9393] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9394] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9395] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9397] = {
            [questKeys.objectivesText] = {"Travel to the Den of Haal'esh in Hellfire Peninsula and search the Kaliri Nests for a Female Kaliri Hatchling.  Use the Empty Birdcage to capture it and bring it to Falconer Drenna Riverwind at Falcon Watch."},
        },

        [9400] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {10388},
        },

        [9401] = {
            [questKeys.objectives] = {nil,nil,{{23550}}},
        },

        [9403] = {
            [questKeys.preQuestSingle] = {9402},
        },

        [9405] = {
            [questKeys.objectives] = {nil,nil,{{23550}}},
        },

        [9406] = {
            [questKeys.objectives] = {nil,nil,{{23569}}},
        },

        [9409] = {
            [questKeys.objectives] = {nil,nil,{{23568}}},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 4,
        },

        [9410] = {
            [questKeys.objectives] = {nil,nil,{{23669}}},
        },

        [9411] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9412] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9413] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9414] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9415] = {
            [questKeys.requiredLevel] = 1,
        },

        [9416] = {
            [questKeys.requiredLevel] = 1,
        },

        [9417] = {
            [questKeys.preQuestSingle] = {9558},
        },

        [9418] = {
            [questKeys.objectives] = {nil,nil,{{23580}}},
        },

        [9419] = {
            [questKeys.requiredLevel] = 1,
            [questKeys.preQuestSingle] = {9415},
        },

        [9421] = {
            [questKeys.requiredRaces] = 1024,
            [questKeys.preQuestSingle] = {9280},
            [questKeys.questFlags] = 65664,
            [questKeys.specialFlags] = 4,
        },

        [9427] = {
            [questKeys.objectivesText] = {"Amaan the Wise wants you to travel to the Pools of Aggonar and use the Cleansing Vial at Aggonar's corpse.  Return to him when Aggonar's essence is cleansed from the water."},
            [questKeys.objectives] = {{{17000}},nil,{{23361}}},
        },

        [9433] = {
            [questKeys.objectives] = {nil,nil,{{23670},{23675}}},
        },

        [9434] = {
            [questKeys.objectives] = {nil,nil,{{23644}}},
        },

        [9438] = {
            [questKeys.objectives] = {nil,nil,{{23662}}},
        },

        [9440] = {
            [questKeys.objectivesText] = {"Feed the Fel-Tainted Morsels to the Lost Ones' captured animals.  Then return the leftovers to Cersei Dusksinger at Stonard in the Swamp of Sorrows."},
            [questKeys.objectives] = {{{17113},{17111},{17112}},nil,{{23659}}},
            [questKeys.specialFlags] = 32,
        },

        [9443] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9444] = {
            [questKeys.objectives] = {nil,{{181653}},{{23691}}},
            [questKeys.specialFlags] = 32,
        },

        [9445] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"Obtain Uther's Blessing from the top of the guard tower near the entrance to Hearthglen and return it to <NPC> at Chillwind Point."},
            [questKeys.objectives] = {nil,nil,{{23661}}},
            [questKeys.nextQuestInChain] = 9446,
            [questKeys.questFlags] = 8,
        },

        [9446] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectivesText] = {"Escort Anchorite Truuen to Uther's Tomb in the Western Plaguelands.  Afterward, speak with High Priestess MacDonnell at Chillwind Camp in the Western Plaguelands."},
        },

        [9447] = {
            [questKeys.objectives] = {{{16847}},nil,{{23394}}},
            [questKeys.specialFlags] = 32,
        },

        [9449] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9451] = {
            [questKeys.objectives] = {nil,nil,{{23671}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 4,
        },

        [9452] = {
            [questKeys.objectives] = {nil,nil,{{23614},{23654}}},
        },

        [9453] = {
            [questKeys.objectives] = {nil,nil,{{23672}}},
        },

        [9455] = {
            [questKeys.objectives] = {nil,nil,{{23678}}},
        },

        [9457] = {
            [questKeys.objectives] = {nil,nil,{{23681},{23680}}},
        },

        [9458] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9459] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9460] = {
            [questKeys.requiredRaces] = 690,
        },

        [9461] = {
            [questKeys.requiredRaces] = 0,
        },

        [9462] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9464] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.breadcrumbs] = {},
        },

        [9465] = {
            [questKeys.requiredRaces] = 1101,
        },

        [9467] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectivesText] = {"Retrieve Hauteur's Ashes and then return them and the Ritual Torch to Temper at Emberglade on Azuremyst Isle.  Remember that you can use the Orb of Returning to teleport back to Temper once you have the ashes."},
            [questKeys.requiredSourceItems] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [9468] = {
            [questKeys.requiredRaces] = 1101,
            [questKeys.objectives] = {nil,nil,{{23688}}},
        },

        [9472] = {
            [questKeys.requiredSourceItems] = {},
        },

        [9474] = {
            [questKeys.requiredRaces] = 1101,
        },

        [9477] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9478] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9479] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9480] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9481] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9482] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {nil,nil,{{23567}}},
            [questKeys.questFlags] = 8,
        },

        [9484] = {
            [questKeys.objectives] = {nil,nil,{{23697}}},
            [questKeys.breadcrumbs] = {},
        },

        [9485] = {
            [questKeys.objectives] = {nil,nil,{{23703}}},
        },

        [9486] = {
            [questKeys.objectives] = {nil,nil,{{23702}}},
        },

        [9487] = {
            [questKeys.requiredRaces] = 0,
        },

        [9488] = {
            [questKeys.requiredRaces] = 690,
        },

        [9489] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {5649,5651},
            [questKeys.specialFlags] = 32,
        },

        [9491] = {
            [questKeys.preQuestSingle] = {10372},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbs] = {},
        },

        [9495] = {
            [questKeys.requiredRaces] = 690,
        },

        [9497] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 67,
            [questKeys.objectivesText] = {"Slay Warbringer O'mrogg and capture the Fel Horde Banner,then return it to Overlord Hun Maimfist at Thrallmar."},
            [questKeys.objectives] = {{{16809}},nil,{{23729}}},
            [questKeys.questFlags] = 136,
        },

        [9498] = {
            [questKeys.preQuestSingle] = {},
        },

        [9499] = {
            [questKeys.preQuestSingle] = {},
        },

        [9500] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9501] = {
            [questKeys.breadcrumbs] = {},
        },

        [9502] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9505] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9506] = {
            [questKeys.breadcrumbs] = {},
        },

        [9507] = {
            [questKeys.questLevel] = 8,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Take the Top Secret Venture Co. Plans to Admiral Odesyus at Odesyus' Landing."},
            [questKeys.objectives] = {nil,nil,{{23740}}},
            [questKeys.sourceItemId] = 23740,
            [questKeys.questFlags] = 128,
        },

        [9508] = {
            [questKeys.objectives] = {nil,nil,{{23997},{23751}}},
        },

        [9509] = {
            [questKeys.objectives] = {nil,nil,{{23752}}},
        },

        [9510] = {
            [questKeys.objectives] = {nil,nil,{{23754}}},
        },

        [9513] = {
            [questKeys.preQuestSingle] = {},
        },

        [9514] = {
            [questKeys.objectives] = {nil,nil,{{23759}}},
            [questKeys.preQuestSingle] = {},
        },

        [9517] = {
            [questKeys.breadcrumbs] = {9533},
        },

        [9520] = {
            [questKeys.objectives] = {nil,nil,{{23780}}},
        },

        [9521] = {
            [questKeys.objectives] = {nil,nil,{{23778}}},
        },

        [9523] = {
            [questKeys.preQuestSingle] = {},
        },

        [9524] = {
            [questKeys.questFlags] = 200,
        },

        [9525] = {
            [questKeys.questFlags] = 200,
        },

        [9526] = {
            [questKeys.specialFlags] = 32,
        },

        [9527] = {
            [questKeys.preQuestSingle] = {10428},
            [questKeys.breadcrumbs] = {},
        },

        [9531] = {
            [questKeys.objectives] = {{{17243}},nil,{{23792}}},
        },

        [9532] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {1859,1885},
        },

        [9533] = {
            [questKeys.breadcrumbForQuestId] = 9517,
        },

        [9535] = {
            [questKeys.objectives] = {nil,nil,{{23798}}},
        },

        [9538] = {
            [questKeys.questFlags] = 130,
        },

        [9545] = {
            [questKeys.objectivesText] = {"Amaan the Wise at the Temple of Telhamat in Hellfire Peninsula wants you to return to Sedai's Corpse, northeast of the Temple of Telhamat, and use the Seer's Relic at that location.  Return to him after you've completed this task."},
            [questKeys.objectives] = {{{17413}},nil,{{23645}}},
        },

        [9546] = {
            [questKeys.questLevel] = 8,
            [questKeys.requiredLevel] = 7,
            [questKeys.objectivesText] = {"Arugoo of the Stillpine has asked that you free 8 Stillpine Captives from cages found in Bristlelimb Village."},
            [questKeys.objectives] = {{{17375}}},
            [questKeys.nextQuestInChain] = 9559,
            [questKeys.questFlags] = 136,
        },

        [9547] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9549] = {
            [questKeys.preQuestSingle] = {9548},
            [questKeys.breadcrumbs] = {},
        },

        [9550] = {
            [questKeys.objectives] = {nil,nil,{{23837}}},
        },

        [9551] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9552] = {
            [questKeys.breadcrumbs] = {},
        },

        [9554] = {
            [questKeys.objectives] = {nil,nil,{{23843}}},
        },

        [9555] = {
            [questKeys.requiredRaces] = 1101,
        },

        [9557] = {
            [questKeys.objectives] = {nil,nil,{{23851}}},
        },

        [9558] = {
            [questKeys.preQuestSingle] = {},
        },

        [9560] = {
            [questKeys.objectivesText] = {"Moordo at Stillpine Hold on Azuremyst Isle wants you to bring him 8 Ravager Hides. "},
            [questKeys.preQuestSingle] = {9559},
        },

        [9562] = {
            [questKeys.preQuestSingle] = {9559},
        },

        [9563] = {
            [questKeys.objectivesText] = {"Mirren Longbeard wants you to bring him 1 Nethergarde Bitter.  You must also attain Friendly reputation with Honor Hold to complete this quest."},
        },

        [9564] = {
            [questKeys.objectives] = {nil,nil,{{23850}}},
            [questKeys.preQuestSingle] = {},
        },

        [9565] = {
            [questKeys.preQuestSingle] = {9559,9560},
        },

        [9570] = {
            [questKeys.preQuestSingle] = {9565},
        },

        [9571] = {
            [questKeys.objectives] = {nil,nil,{{23860}}},
        },

        [9572] = {
            [questKeys.objectivesText] = {"Slay Watchkeeper Gargolmar, Omor the Unscarred and the drake, Nazan.  Return Gargolmar's Hand, Omor's Hoof and Nazan's Head to Caza'rez at Thrallmar in Hellfire Peninsula."},
        },

        [9573] = {
            [questKeys.preQuestSingle] = {9562},
        },

        [9575] = {
            [questKeys.objectivesText] = {"Slay Watchkeeper Gargolmar, Omor the Unscarred and the drake, Nazan.  Return Gargolmar's Hand, Omor's Hoof and Nazan's Head to Gunny at Honor Hold in Hellfire Peninsula."},
            [questKeys.preQuestSingle] = {10142},
        },

        [9576] = {
            [questKeys.objectives] = {nil,nil,{{23870}}},
        },

        [9577] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Speak with <QUESTGIVER> in the <AREA>."},
            [questKeys.questFlags] = 136,
        },

        [9581] = {
            [questKeys.objectives] = {nil,nil,{{23878},{23875}}},
        },

        [9582] = {
            [questKeys.objectives] = {{{17556}},nil,{{23925}}},
            [questKeys.exclusiveTo] = {1638,1679,1684},
        },

        [9583] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Get Omar some cloth"},
            [questKeys.objectives] = {{{16089}}},
            [questKeys.questFlags] = 128,
        },

        [9584] = {
            [questKeys.objectives] = {nil,nil,{{23879},{23876}}},
        },

        [9585] = {
            [questKeys.objectives] = {nil,nil,{{23880},{23877}}},
        },

        [9586] = {
            [questKeys.exclusiveTo] = {5623,5626},
        },

        [9587] = {
            [questKeys.objectives] = {nil,nil,{{23891}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [9588] = {
            [questKeys.objectives] = {nil,nil,{{23893}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [9591] = {
            [questKeys.objectives] = {nil,nil,{{23896}}},
            [questKeys.breadcrumbs] = {},
        },

        [9592] = {
            [questKeys.objectives] = {nil,nil,{{23897}}},
        },

        [9593] = {
            [questKeys.objectives] = {nil,nil,{{23898}}},
        },

        [9594] = {
            [questKeys.objectives] = {{{17337},{17339}},nil,{{23900}}},
        },

        [9596] = {
            [questKeys.questLevel] = 10,
            [questKeys.requiredLevel] = 10,
            [questKeys.requiredClasses] = 128,
            [questKeys.objectivesText] = {"<NYI>Log description."},
            [questKeys.objectives] = {{{14885}}},
            [questKeys.questFlags] = 136,
        },

        [9597] = {
            [questKeys.questLevel] = 12,
            [questKeys.requiredLevel] = 12,
            [questKeys.requiredClasses] = 2,
            [questKeys.objectivesText] = {"<NYI>Log description."},
            [questKeys.questFlags] = 128,
        },

        [9598] = {
            [questKeys.objectives] = {nil,nil,{{23926}}},
            [questKeys.breadcrumbs] = {},
        },

        [9599] = {
            [questKeys.preQuestSingle] = {9600},
        },

        [9600] = {
            [questKeys.specialFlags] = 32,
        },

        [9602] = {
            [questKeys.objectives] = {nil,nil,{{23899}}},
        },

        [9603] = {
            [questKeys.objectives] = {nil,nil,{{23902}}},
        },

        [9604] = {
            [questKeys.objectives] = {nil,nil,{{23902}}},
        },

        [9605] = {
            [questKeys.objectives] = {nil,nil,{{23903}}},
        },

        [9606] = {
            [questKeys.objectives] = {nil,nil,{{23903}}},
        },

        [9609] = {
            [questKeys.breadcrumbForQuestId] = 1396,
        },

        [9611] = {
            [questKeys.questLevel] = 8,
            [questKeys.requiredLevel] = 5,
            [questKeys.questFlags] = 1152,
            [questKeys.specialFlags] = 2,
        },

        [9613] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Shattered Blade you found in Karazhan wants you to ask Koren to repair it.  You'll also need to attain Honored reputation with the Violet Eye to complete this quest."},
            [questKeys.objectives] = {nil,nil,{{23904}}},
            [questKeys.sourceItemId] = 23904,
            [questKeys.questFlags] = 200,
        },

        [9614] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Bring 40 Khorium Bars,1 Void Crystal and 8 Primal Fires to Koren inside Karazhan."},
            [questKeys.objectives] = {nil,nil,{{23449},{22450},{21884}}},
            [questKeys.questFlags] = 136,
        },

        [9615] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Bring 40 Khorium Bars,1 Void Crystal and 8 Primal Fires to Koren inside Karazhan."},
            [questKeys.objectives] = {nil,nil,{{23449},{22450},{21884}}},
            [questKeys.questFlags] = 136,
        },

        [9616] = {
            [questKeys.objectives] = {nil,nil,{{23910}}},
        },

        [9617] = {
            [questKeys.exclusiveTo] = {10529,10530},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9618] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{23919}}},
        },

        [9619] = {
            [questKeys.objectives] = {{{5676}},nil,{{23732}}},
        },

        [9621] = {
            [questKeys.objectives] = {nil,nil,{{23929}}},
        },

        [9622] = {
            [questKeys.preQuestSingle] = {9570},
        },

        [9623] = {
            [questKeys.objectives] = {nil,nil,{{23928}}},
        },

        [9625] = {
            [questKeys.specialFlags] = 2,
        },

        [9626] = {
            [questKeys.objectives] = {nil,nil,{{23930}}},
        },

        [9629] = {
            [questKeys.objectivesText] = {"Morae at Blood Watch wants you to 'mark' 6 Blacksilt Scouts using the Murloc Tagger. "},
            [questKeys.objectives] = {{{17654}},nil,{{23995}}},
            [questKeys.specialFlags] = 32,
        },

        [9631] = {
            [questKeys.objectives] = {nil,nil,{{24152}}},
        },

        [9632] = {
            [questKeys.objectives] = {nil,nil,{{23937}}},
        },

        [9633] = {
            [questKeys.objectives] = {nil,nil,{{23937}}},
        },

        [9634] = {
            [questKeys.preQuestSingle] = {9625},
        },

        [9635] = {
            [questKeys.requiredSkill] = {202,300},
        },

        [9636] = {
            [questKeys.requiredSkill] = {202,300},
        },

        [9644] = {
            [questKeys.objectivesText] = {"Go to the Master's Terrace in Karazhan and touch the Blackened Urn to summon Nightbane.  Retrieve the Faint Arcane Essence from Nightbane's corpse and bring it to Archmage Alturus."},
            [questKeys.sourceItemId] = 24140,
        },

        [9645] = {
            [questKeys.objectivesText] = {"Go to the Master's Terrace in Karazhan and read Medivh's Journal.  Return to Archmage Alturus with Medivh's Journal after completing this task."},
            [questKeys.objectives] = {nil,nil,{{23934}}},
        },

        [9647] = {
            [questKeys.preQuestSingle] = {9643},
        },

        [9648] = {
            [questKeys.objectivesText] = {"Jessera of Mac'Aree at Blood Watch wants 1 Aquatic Stinkhorn, 1 Blood Mushroom, 1 Ruinous Polyspore, and 1 Fel Cone Fungus."},
        },

        [9649] = {
            [questKeys.objectivesText] = {"Jessera of Mac'Aree at Blood Watch wants 2 Ysera's Tears."},
        },

        [9650] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"<TXT>"},
            [questKeys.questFlags] = 136,
        },

        [9651] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"<TXT>"},
            [questKeys.questFlags] = 136,
        },

        [9652] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectives] = {nil,nil,{{23905}}},
            [questKeys.questFlags] = 136,
        },

        [9653] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectives] = {nil,nil,{{23647}}},
            [questKeys.questFlags] = 136,
        },

        [9654] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23916}}},
            [questKeys.questFlags] = 128,
        },

        [9655] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23911}}},
            [questKeys.questFlags] = 128,
        },

        [9656] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23916}}},
            [questKeys.questFlags] = 128,
        },

        [9657] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23911}}},
            [questKeys.questFlags] = 128,
        },

        [9658] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23649}}},
            [questKeys.questFlags] = 128,
        },

        [9659] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23649}}},
            [questKeys.questFlags] = 128,
        },

        [9660] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23648}}},
            [questKeys.questFlags] = 128,
        },

        [9661] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"The Facet of Keanna stored inside Keanna's Will wants you to gather 20 Arcane Residues from the Arcane Anomalies in Karazhan."},
            [questKeys.objectives] = {nil,nil,{{24068},{23648}}},
            [questKeys.questFlags] = 128,
        },

        [9662] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Defeat Malchezar in Karazhan while equipped with Keanna's Will.  Facet of Keanna must survive."},
            [questKeys.objectives] = {{{15690}}},
            [questKeys.questFlags] = 200,
        },

        [9666] = {
            [questKeys.objectives] = {{{17701}}},
        },

        [9667] = {
            [questKeys.preQuestSingle] = {9538},
            [questKeys.specialFlags] = 32,
        },

        [9670] = {
            [questKeys.objectives] = {{{17681}}},
        },

        [9676] = {
            [questKeys.requiredRaces] = 512,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9678] = {
            [questKeys.specialFlags] = 2,
        },

        [9679] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 12,
            [questKeys.requiredClasses] = 2,
            [questKeys.objectivesText] = {"Report to Knight-Lord Bloodvalor in Silvermoon City."},
            [questKeys.nextQuestInChain] = 9679,
            [questKeys.questFlags] = 136,
        },

        [9684] = {
            [questKeys.objectivesText] = {"Use the Shimmering Vessel on M'uru to fill it and return to Knight-Lord Bloodvalor in Silvermoon City."},
        },

        [9685] = {
            [questKeys.preQuestSingle] = {9684},
            [questKeys.specialFlags] = 32,
        },

        [9695] = {
            [questKeys.questLevel] = 16,
            [questKeys.requiredLevel] = 14,
            [questKeys.objectivesText] = {"Take the Sun King's Command to Vindicator Boros at Blood Watch."},
            [questKeys.objectives] = {nil,nil,{{24228}}},
            [questKeys.sourceItemId] = 24228,
            [questKeys.nextQuestInChain] = 9696,
            [questKeys.questFlags] = 128,
        },

        [9696] = {
            [questKeys.objectives] = {nil,nil,{{24399}}},
        },

        [9698] = {
            [questKeys.objectives] = {nil,nil,{{24323}}},
        },

        [9699] = {
            [questKeys.objectives] = {nil,nil,{{24230}}},
        },

        [9704] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [9705] = {
            [questKeys.objectives] = {nil,nil,{{20804}}},
            [questKeys.nextQuestInChain] = 8350,
        },

        [9706] = {
            [questKeys.objectives] = {nil,nil,{{24237}}},
            [questKeys.preQuestSingle] = {9578},
        },

        [9707] = {
            [questKeys.objectives] = {nil,nil,{{24239}}},
        },

        [9711] = {
            [questKeys.objectives] = nil,
        },

        [9713] = {
            [questKeys.specialFlags] = 2,
        },

        [9716] = {
            [questKeys.objectivesText] = {"Investigate the cause of the water depletion at Umbrafen Lake.  Then return to Ysiel Windsinger at the Cenarion Refuge in Zangarmarsh."},
        },

        [9718] = {
            [questKeys.objectives] = {nil,nil,{{25465}}},
        },

        [9720] = {
            [questKeys.objectivesText] = {"Ysiel Windsinger wants you to use the Ironvine Seeds on the Steam Pump Controls at Serpent Lake, Umbrafen Lake, Marshlight Lake and the Lagoon.  Then return to her at the Cenarion Refuge in Zangarmarsh with any leftover seeds you have."},
            [questKeys.objectives] = {{{17998},{18002},{18000},{17999}},nil,{{24355}}},
            [questKeys.specialFlags] = 32,
        },

        [9728] = {
            [questKeys.preQuestSingle] = {9778},
        },

        [9729] = {
            [questKeys.objectivesText] = {"Escort Fhwoor into the area of the Marshlight steam pump to retrieve the Ark of Ssslith.  Bring Fhwoor and the ark back safely and then report back to Gzhun'tt at Sporeggar in Zangarmarsh."},
        },

        [9731] = {
            [questKeys.objectivesText] = {"Search Serpent Lake for signs of a drain.  Return to Ysiel Windsinger at the Cenarion Refuge with news of your discovery."},
            [questKeys.objectives] = {nil,nil,{{24330}}},
            [questKeys.preQuestSingle] = {},
        },

        [9734] = {
            [questKeys.preQuestSingle] = {9733},
        },

        [9737] = {
            [questKeys.objectives] = {{{17915}},nil,{{24287}}},
        },

        [9738] = {
            [questKeys.objectivesText] = {"Discover what happened to Earthbinder Rayge, Naturalist Bite, Weeder Greenthumb, and Windcaller Claw.  Then, return to Watcher Jhang at Coilfang Reservoir in Zangarmarsh."},
            [questKeys.objectives] = {{{17885},{17893},{17890},{17894}}},
        },

        [9739] = {
            [questKeys.requiredMaxRep] = {970,3000},
        },

        [9743] = {
            [questKeys.requiredMaxRep] = {970,3000},
        },

        [9745] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 60,
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 136,
        },

        [9751] = {
            [questKeys.preQuestSingle] = {},
        },

        [9752] = {
            [questKeys.objectivesText] = {"Escort Kayra Longmane to the Cenarion Refuge in Zangarmarsh.  Report to Ysiel Windsinger when you've completed this task."},
        },

        [9753] = {
            [questKeys.preQuestSingle] = {9740},
        },

        [9754] = {
            [questKeys.questLevel] = 20,
            [questKeys.requiredLevel] = 18,
            [questKeys.questFlags] = 136,
        },

        [9755] = {
            [questKeys.objectivesText] = {"Speak to a Captured Sunhawk Agent at Blood Watch and recover Sunhawk Information. Return to Exarch Admetius when you have completed this task."},
            [questKeys.questFlags] = 136,
        },

        [9756] = {
            [questKeys.objectives] = {{{17974}}},
        },

        [9757] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [9758] = {
            [questKeys.preQuestSingle] = {9327,9329},
        },

        [9760] = {
            [questKeys.exclusiveTo] = {},
        },

        [9764] = {
            [questKeys.objectives] = {nil,nil,{{24367}}},
        },

        [9767] = {
            [questKeys.objectives] = {nil,nil,{{24369}}},
        },

        [9768] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 67,
            [questKeys.objectives] = {nil,nil,{{24369}}},
            [questKeys.questFlags] = 136,
        },

        [9773] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9775] = {
            [questKeys.objectives] = {nil,nil,{{24382}}},
        },

        [9788] = {
            [questKeys.objectivesText] = {"Look for Ikeyen's Belongings inside a cave south of Umbrafen.  Return them to Ikeyen at Cenarion Refuge in Zangarmarsh."},
        },

        [9793] = {
            [questKeys.objectives] = {nil,nil,{{24415}}},
        },

        [9794] = {
            [questKeys.objectives] = {nil,nil,{{26048}}},
        },

        [9798] = {
            [questKeys.objectives] = {nil,nil,{{24414}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 4,
        },

        [9799] = {
            [questKeys.specialFlags] = 4,
        },

        [9802] = {
            [questKeys.requiredMaxRep] = {942,8999},
        },

        [9803] = {
            [questKeys.objectives] = {nil,nil,{{24573},{24428}}},
        },

        [9805] = {
            [questKeys.objectives] = {{{18110},{18142},{18143},{18144}},nil,{{24467}}},
            [questKeys.specialFlags] = 32,
        },

        [9806] = {
            [questKeys.objectivesText] = {"Gshaff wants you to gather 6 Fertile Spores from the various Zangarmarsh Spore Bats and Marsh Walkers.  Return to Ghsaff at Sporeggar when you've completed this task."},
        },

        [9808] = {
            [questKeys.requiredMinRep] = false,
        },

        [9811] = {
            [questKeys.objectives] = {nil,nil,{{22653}}},
        },

        [9812] = {
            [questKeys.objectives] = {nil,nil,{{23929}}},
        },

        [9813] = {
            [questKeys.objectives] = {nil,nil,{{23930}}},
        },

        [9816] = {
            [questKeys.objectives] = {{{18152}}},
        },

        [9821] = {
            [questKeys.objectivesText] = {"Gordawg at the Throne of the Elements in Nagrand has asked that you bring him 10 Enraged Crusher Cores. "},
        },

        [9824] = {
            [questKeys.objectives] = {{{18161},{18162}},nil,{{24474}}},
            [questKeys.specialFlags] = 32,
        },

        [9826] = {
            [questKeys.objectives] = {nil,nil,{{24482}}},
            [questKeys.preQuestSingle] = {9824,9825},
        },

        [9827] = {
            [questKeys.objectives] = {nil,nil,{{24483}}},
        },

        [9828] = {
            [questKeys.objectives] = {nil,nil,{{24484}}},
        },

        [9830] = {
            [questKeys.requiredMinRep] = false,
        },

        [9832] = {
            [questKeys.objectivesText] = {"Obtain the Second Key Fragment from an Arcane Container inside Coilfang Reservoir and the Third Key Fragment from an Arcane Container inside Tempest Keep.  Return to Khadgar in Shattrath City after you've completed this task."},
        },

        [9833] = {
            [questKeys.requiredMinRep] = false,
        },

        [9834] = {
            [questKeys.requiredMinRep] = false,
        },

        [9836] = {
            [questKeys.objectives] = {nil,nil,{{24489}}},
        },

        [9837] = {
            [questKeys.preQuestSingle] = {9836,10737},
        },

        [9846] = {
            [questKeys.requiredRaces] = 690,
        },

        [9847] = {
            [questKeys.objectives] = {{{18185}},nil,{{24498}}},
        },

        [9849] = {
            [questKeys.objectives] = {{{18181}},nil,{{24501}}},
        },

        [9851] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9852] = {
            [questKeys.preQuestSingle] = {9851},
        },

        [9856] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9859] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9861] = {
            [questKeys.objectives] = {nil,nil,{{24504}}},
        },

        [9863] = {
            [questKeys.requiredMinRep] = false,
        },

        [9864] = {
            [questKeys.requiredMinRep] = false,
        },

        [9867] = {
            [questKeys.objectivesText] = {"Farseer Margadesh at Garadar in Nagrand wants you to bring him the Head of Ortor of Murkblood. "},
            [questKeys.requiredMinRep] = false,
        },

        [9868] = {
            [questKeys.requiredMinRep] = false,
        },

        [9869] = {
            [questKeys.requiredMinRep] = false,
        },

        [9870] = {
            [questKeys.requiredMinRep] = false,
        },

        [9871] = {
            [questKeys.objectives] = {nil,nil,{{24559}}},
        },

        [9872] = {
            [questKeys.objectives] = {nil,nil,{{24558}}},
        },

        [9874] = {
            [questKeys.objectives] = {{{18240}},nil,{{24560}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.specialFlags] = 32,
        },

        [9875] = {
            [questKeys.objectives] = {nil,nil,{{24407}}},
        },

        [9876] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [9878] = {
            [questKeys.requiredMinRep] = false,
        },

        [9879] = {
            [questKeys.requiredMinRep] = false,
        },

        [9880] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectives] = {nil,nil,{{24579}}},
            [questKeys.questFlags] = 128,
        },

        [9881] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectives] = {nil,nil,{{24581}}},
            [questKeys.questFlags] = 128,
        },

        [9884] = {
            [questKeys.exclusiveTo] = {9885,9886,9887},
            [questKeys.specialFlags] = 17,
        },

        [9885] = {
            [questKeys.exclusiveTo] = {9884,9886,9887},
            [questKeys.specialFlags] = 17,
        },

        [9886] = {
            [questKeys.exclusiveTo] = {9884,9885,9887},
            [questKeys.specialFlags] = 17,
        },

        [9887] = {
            [questKeys.exclusiveTo] = {9884,9885,9886},
            [questKeys.specialFlags] = 17,
        },

        [9889] = {
            [questKeys.objectives] = {{{18260}}},
        },

        [9897] = {
            [questKeys.objectives] = {nil,nil,{{25449}}},
        },

        [9902] = {
            [questKeys.requiredMinRep] = false,
        },

        [9905] = {
            [questKeys.requiredMinRep] = false,
        },

        [9908] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectives] = {nil,nil,{{24579}}},
            [questKeys.questFlags] = 128,
        },

        [9909] = {
            [questKeys.questLevel] = 60,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectives] = {nil,nil,{{24581}}},
            [questKeys.questFlags] = 128,
        },

        [9910] = {
            [questKeys.objectives] = {{{18305},{18306},{18307}},nil,{{25458}}},
            [questKeys.specialFlags] = 32,
        },

        [9911] = {
            [questKeys.objectives] = {nil,nil,{{25459}}},
        },

        [9913] = {
            [questKeys.exclusiveTo] = {},
        },

        [9918] = {
            [questKeys.objectives] = {{{18354}}},
        },

        [9919] = {
            [questKeys.objectives] = {nil,nil,{{25491}}},
        },

        [9923] = {
            [questKeys.requiredMinRep] = false,
        },

        [9926] = {
            [questKeys.specialFlags] = 2,
        },

        [9927] = {
            [questKeys.objectives] = {{{18388}},nil,{{25552}}},
        },

        [9931] = {
            [questKeys.objectives] = {{{18393}},nil,{{25555}}},
            [questKeys.preQuestSingle] = {9927},
        },

        [9932] = {
            [questKeys.objectives] = {{{18395}},nil,{{25658}}},
            [questKeys.preQuestSingle] = {9927},
        },

        [9933] = {
            [questKeys.objectives] = {nil,nil,{{25586}}},
            [questKeys.preQuestSingle] = {9931},
        },

        [9934] = {
            [questKeys.objectives] = {nil,nil,{{25586}}},
            [questKeys.preQuestSingle] = {9931},
        },

        [9935] = {
            [questKeys.objectives] = {{{18391},{21276}}},
            [questKeys.requiredMinRep] = false,
        },

        [9936] = {
            [questKeys.objectives] = {{{18391},{21276}}},
            [questKeys.requiredMinRep] = false,
        },

        [9937] = {
            [questKeys.preQuestSingle] = {9935,9939},
        },

        [9938] = {
            [questKeys.preQuestSingle] = {9936,9940},
        },

        [9939] = {
            [questKeys.requiredMinRep] = false,
        },

        [9940] = {
            [questKeys.requiredMinRep] = false,
        },

        [9942] = {
            [questKeys.preQuestSingle] = {9929},
        },

        [9944] = {
            [questKeys.requiredMinRep] = false,
        },

        [9945] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.preQuestSingle] = {9944},
        },

        [9947] = {
            [questKeys.preQuestSingle] = {9942},
        },

        [9948] = {
            [questKeys.requiredMinRep] = false,
        },

        [9950] = {
            [questKeys.preQuestSingle] = {9947},
        },

        [9955] = {
            [questKeys.objectives] = {{{18444}}},
        },

        [9956] = {
            [questKeys.requiredMinRep] = false,
        },

        [9957] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [9959] = {
            [questKeys.preQuestSingle] = {9953},
        },

        [9960] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [9961] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [9962] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [9964] = {
            [questKeys.preQuestSingle] = {9959},
        },

        [9966] = {
            [questKeys.preQuestSingle] = {9964},
        },

        [9967] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [9968] = {
            [questKeys.objectivesText] = {"Collect 4 Teromoth Samples and 4 Vicious Teromoth Samples.  Then return to Earthbinder Tavgren just outside of the Cenarion Thicket in Terokkar Forest."},
        },

        [9970] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [9971] = {
            [questKeys.objectivesText] = {"Investigate the Strange Object next to the Broken Corpse to determine what might have befallen the Cenarion Thicket.  Then return to Earthbinder Tavgren just outside the thicket in Terokkar Forest."},
        },

        [9972] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [9973] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 2,
        },

        [9974] = {
            [questKeys.preQuestSingle] = {9966},
        },

        [9976] = {
            [questKeys.preQuestSingle] = {9974},
        },

        [9977] = {
            [questKeys.objectives] = nil,
            [questKeys.specialFlags] = 2,
        },

        [9978] = {
            [questKeys.preQuestSingle] = {9968},
            [questKeys.nextQuestInChain] = 9979,
            [questKeys.specialFlags] = 2,
        },

        [9981] = {
            [questKeys.preQuestSingle] = {9976},
        },

        [9982] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [9983] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [9984] = {
            [questKeys.objectives] = {nil,nil,{{25705}}},
        },

        [9985] = {
            [questKeys.objectives] = {nil,nil,{{25706}}},
        },

        [9991] = {
            [questKeys.preQuestSingle] = {9982,9983},
        },

        [9994] = {
            [questKeys.objectives] = {nil,nil,{{25746}}},
        },

        [9995] = {
            [questKeys.objectives] = {nil,nil,{{25746}}},
        },

        [9996] = {
            [questKeys.objectivesText] = {"Kill 10 Firewing Defenders, 10 Firewing Bloodwarders, and 10 Firewing Warlocks.  Then report back to Lieutenant Meridian at the Allerian Post in Terokkar Forest."},
        },

        [9997] = {
            [questKeys.objectivesText] = {"Kill 10 Firewing Defenders, 10 Firewing Bloodwarders, and 10 Firewing Warlocks.  Then report back to Sergeant Chawni at Stonebreaker Camp in Terokkar Forest."},
        },

        [10004] = {
            [questKeys.objectives] = {nil,nil,{{25751}}},
        },

        [10008] = {
            [questKeys.preQuestSingle] = {10000},
        },

        [10011] = {
            [questKeys.specialFlags] = 32,
        },

        [10012] = {
            [questKeys.objectives] = {nil,nil,{{25765}}},
            [questKeys.preQuestSingle] = {},
        },

        [10013] = {
            [questKeys.objectives] = {nil,nil,{{25765}}},
            [questKeys.preQuestSingle] = {},
        },

        [10017] = {
            [questKeys.preQuestSingle] = {},
        },

        [10018] = {
            [questKeys.objectivesText] = {"Bring 12 Timber Worg Pelts to Malukaz at Stonebreaker Hold. "},
        },

        [10019] = {
            [questKeys.preQuestSingle] = {10017},
        },

        [10020] = {
            [questKeys.preQuestSingle] = {},
        },

        [10021] = {
            [questKeys.requiredMinRep] = {932,3000},
            [questKeys.preQuestSingle] = {},
        },

        [10024] = {
            [questKeys.preQuestSingle] = {},
        },

        [10025] = {
            [questKeys.preQuestSingle] = {10024},
        },

        [10030] = {
            [questKeys.objectivesText] = {"Collect 10 Restless Bones.  Deliver them to Ramdor the Mad, just off the western side of the Ring of Observance in Auchindoun, which is in the middle of the Bone Wastes of Terokkar Forest."},
        },

        [10032] = {
            [questKeys.questLevel] = 63,
            [questKeys.requiredLevel] = 62,
            [questKeys.objectivesText] = {"Gather 6 Tuurem Artifacts from Tuurem Scavengers and Tuurem Hunters and bring them to Rakoria at Stonebreaker Hold."},
            [questKeys.objectives] = {nil,nil,{{25850}}},
            [questKeys.questFlags] = 136,
        },

        [10035] = {
            [questKeys.objectivesText] = {"Call down Torgos with Trachela's Carcass.  Acquire a Tail Feather of Torgos and return it to Taela Everstride at the Allerian Stronghold in Terokkar Forest."},
        },

        [10036] = {
            [questKeys.objectivesText] = {"Call down Torgos with Trachela's Carcass.  Acquire a Tail Feather of Torgos and return it to Mawg Grimshot at Stonebreaker Hold in Terokkar Forest."},
        },

        [10040] = {
            [questKeys.objectivesText] = {"While in disguise, speak with the Shadowy Initiate, the Shadowy Laborer and the Shadowy Advisor.  Then return to Private Weeks at Grangol'var Village in Terokkar Forest."},
            [questKeys.objectives] = {{{26464},{26465},{26466}}},
        },

        [10041] = {
            [questKeys.objectivesText] = {"While in disguise, speak with the Shadowy Initiate, the Shadowy Laborer and the Shadowy Advisor.  Then return to Scout Neftis at Grangol'var Village in Terokkar Forest."},
            [questKeys.objectives] = {{{26464},{26465},{26466}}},
        },

        [10044] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {9868,9934,10011},
        },

        [10047] = {
            [questKeys.objectives] = {nil,{{182789}},{{25889}}},
            [questKeys.preQuestSingle] = {},
        },

        [10049] = {
            [questKeys.preQuestSingle] = {9950},
        },

        [10050] = {
            [questKeys.preQuestSingle] = {},
        },

        [10058] = {
            [questKeys.preQuestSingle] = {},
        },

        [10059] = {
            [questKeys.preQuestSingle] = {10155},
        },

        [10062] = {
            [questKeys.preQuestSingle] = {10061},
        },

        [10063] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10068] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10069] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10070] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10071] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10072] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10073] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10074] = {
            [questKeys.requiredRaces] = 0,
        },

        [10075] = {
            [questKeys.requiredRaces] = 0,
        },

        [10076] = {
            [questKeys.requiredRaces] = 0,
        },

        [10077] = {
            [questKeys.requiredRaces] = 0,
        },

        [10078] = {
            [questKeys.objectivesText] = {"Use the Flaming Torch to burn the Horde Blade Throwers overlooking the Path of Glory.  Then, bring the Flaming Torch to Dumphry in Honor Hold."},
            [questKeys.objectives] = {{{18818},{21237},{19009},{21236}},nil,{{26002}}},
            [questKeys.specialFlags] = 32,
        },

        [10079] = {
            [questKeys.preQuestSingle] = {10142},
        },

        [10080] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Kill 10 Gan'arg Servants,5 Forge Camp Legionnaires,and 5 Sisters of Grief,then search Forge Camp: Rage for evidence of the Legion's intentions."},
            [questKeys.objectives] = {{{16947},{16954},{16960}}},
            [questKeys.nextQuestInChain] = 10083,
            [questKeys.questFlags] = 136,
        },

        [10083] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Retrieve the Forge Camp: Spite Plans and return them to Field Marshal Rohamus at Expedition Point."},
            [questKeys.objectives] = {nil,nil,{{27419}}},
            [questKeys.nextQuestInChain] = 10084,
            [questKeys.questFlags] = 128,
        },

        [10087] = {
            [questKeys.objectives] = {{{18849},{19008}},nil,{{27479}}},
            [questKeys.specialFlags] = 32,
        },

        [10089] = {
            [questKeys.preQuestSingle] = {10386,10387},
        },

        [10090] = {
            [questKeys.objectives] = {nil,nil,{{27419}}},
            [questKeys.preQuestSingle] = {10089},
        },

        [10092] = {
            [questKeys.preQuestSingle] = {10090},
        },

        [10100] = {
            [questKeys.preQuestSingle] = {10088},
        },

        [10106] = {
            [questKeys.questLevel] = 60,
        },

        [10107] = {
            [questKeys.objectives] = nil,
        },

        [10108] = {
            [questKeys.objectives] = nil,
        },

        [10110] = {
            [questKeys.questLevel] = 60,
        },

        [10112] = {
            [questKeys.objectivesText] = {"Retrieve 5 of Lathrai's Stolen Goods.  Return them to Wind Trader Lathrai near the World's End Tavern in the Lower City section of Shattrath City."},
        },

        [10113] = {
            [questKeys.exclusiveTo] = {},
        },

        [10114] = {
            [questKeys.exclusiveTo] = {},
        },

        [10119] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10120] = {
            [questKeys.objectives] = {nil,nil,{{28024}}},
            [questKeys.preQuestSingle] = {9407},
        },

        [10121] = {
            [questKeys.preQuestSingle] = {10291},
        },

        [10125] = {
            [questKeys.objectives] = {{{19276},{19277},{19278},{19279}},nil,{{28478}}},
        },

        [10128] = {
            [questKeys.preQuestSingle] = {10126},
        },

        [10129] = {
            [questKeys.objectives] = {{{19291},{19292}},nil,{{28038}}},
            [questKeys.specialFlags] = 32,
        },

        [10131] = {
            [questKeys.preQuestSingle] = {10128},
        },

        [10134] = {
            [questKeys.objectives] = {nil,nil,{{29476}}},
        },

        [10135] = {
            [questKeys.objectives] = {nil,nil,{{28046}}},
            [questKeys.preQuestSingle] = {10133},
        },

        [10136] = {
            [questKeys.preQuestSingle] = {10135,10392},
        },

        [10137] = {
            [questKeys.objectives] = {{{19266}},nil,{{28048},{28047}}},
            [questKeys.requiredSourceItems] = {28047},
            [questKeys.preQuestSingle] = {10131},
        },

        [10139] = {
            [questKeys.preQuestSingle] = {10138},
        },

        [10140] = {
            [questKeys.objectives] = {nil,nil,{{28105}}},
        },

        [10144] = {
            [questKeys.objectives] = {nil,{{184414},{184415}},{{28106}}},
            [questKeys.specialFlags] = 32,
        },

        [10146] = {
            [questKeys.objectives] = {{{19291},{19292}},nil,{{28038}}},
            [questKeys.specialFlags] = 32,
        },

        [10148] = {
            [questKeys.objectives] = {nil,nil,{{28107}}},
            [questKeys.preQuestSingle] = {10147},
        },

        [10149] = {
            [questKeys.preQuestSingle] = {10148},
        },

        [10153] = {
            [questKeys.preQuestSingle] = {10151},
        },

        [10154] = {
            [questKeys.preQuestSingle] = {10153},
        },

        [10155] = {
            [questKeys.objectives] = {{{19265}},nil,{{28048},{28047}}},
            [questKeys.requiredSourceItems] = {28047},
            [questKeys.preQuestSingle] = {10154},
        },

        [10160] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10162] = {
            [questKeys.objectives] = {{{19398},{19397},{19399}},nil,{{28132}}},
            [questKeys.specialFlags] = 2,
        },

        [10163] = {
            [questKeys.objectives] = {{{19398},{19397},{19399}},nil,{{28132}}},
            [questKeys.preQuestSingle] = {10344},
        },

        [10164] = {
            [questKeys.preQuestSingle] = {},
        },

        [10166] = {
            [questKeys.objectives] = {nil,nil,{{28209}}},
        },

        [10167] = {
            [questKeys.questFlags] = 136,
        },

        [10169] = {
            [questKeys.objectives] = {nil,nil,{{28287}}},
        },

        [10172] = {
            [questKeys.objectives] = nil,
        },

        [10173] = {
            [questKeys.objectives] = {nil,nil,{{28292},{29207}}},
            [questKeys.requiredSourceItems] = {29205,29206},
        },

        [10180] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10181] = {
            [questKeys.questLevel] = 1,
            [questKeys.questFlags] = 1152,
        },

        [10182] = {
            [questKeys.objectives] = {{{19549}}},
            [questKeys.specialFlags] = 32,
        },

        [10183] = {
            [questKeys.objectives] = {nil,nil,{{28359}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10186,
        },

        [10184] = {
            [questKeys.objectives] = {{{19881}}},
            [questKeys.preQuestSingle] = {10174},
        },

        [10186] = {
            [questKeys.breadcrumbs] = {10183,11036,11037,11040,11042},
        },

        [10190] = {
            [questKeys.objectivesText] = {"Use the Battery Recharging Blaster on enough Phase Hunters to get the Battery Recharge Level to 10.  Then return it to Bot-Specialist Alley at the Ruins of Enkaat in the Netherstorm."},
            [questKeys.objectives] = {{{19595}},nil,{{28369}}},
        },

        [10191] = {
            [questKeys.objectivesText] = {"Escort the Maxx A. Million Mk. V through the Ruins of Enkaat and back out to safety.  Then speak with Bot-Specialist Alley just outside the Ruins of Enkaat in the Netherstorm."},
        },

        [10192] = {
            [questKeys.objectivesText] = {"Reclaim Krasus's Compendium - Chapter 1, Krasus's Compendium - Chapter 2, and Krasus's Compendium - Chapter 3 from Kirin'Var Village's Town Square. "},
        },

        [10198] = {
            [questKeys.objectivesText] = {"Use the Sunfury Disguise, go into Manaforge Coruu and listen to the conversation between Commander Dawnforge and Arcanist Ardonis.  Report back to Caledis Brightdawn at Manaforge Coruu after completing this task.","","Completing tasks for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.objectives] = {nil,nil,{{28607}}},
        },

        [10200] = {
            [questKeys.requiredMinRep] = false,
        },

        [10203] = {
            [questKeys.objectivesText] = {"Use the Ultra Deconsolodation Zapper to beam the Hyper Rotational Dig-A-Matic, Servo-Pneumatic Dredging Claw, Multi-Spectrum Terrain Analyzer, and the Big Wagon Full of Explosives back to Area 52.  Then report to Lead Sapper Blastfizzle at the eastern end of the fissure that runs through Area 52 in the Netherstorm."},
            [questKeys.objectives] = {nil,{{183805},{183806},{183807},{183808}},{{30354}}},
        },

        [10204] = {
            [questKeys.objectivesText] = {"Magistrix Larynna wants you to go to Manaforge B'naar and obtain a Bloodgem Shard from a Sunfury Magister.  Use this shard near the larger Bloodgem crystals and return to her at Area 52.","","Completing quests for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.requiredSourceItems] = {},
        },

        [10208] = {
            [questKeys.objectives] = {nil,{{184290},{184289}},{{28478}}},
            [questKeys.specialFlags] = 32,
        },

        [10210] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10211] = {
            [questKeys.objectivesText] = {"Follow Khadgar's servant and listen to its story.  Return to Khadgar after completing this task."},
        },

        [10213] = {
            [questKeys.objectivesText] = {"Search for crash survivors.  "},
        },

        [10215] = {
            [questKeys.questFlags] = 8,
        },

        [10217] = {
            [questKeys.questLevel] = 255,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Test"},
            [questKeys.objectives] = {nil,nil,{{28500}}},
            [questKeys.questFlags] = 136,
        },

        [10221] = {
            [questKeys.objectives] = {{{20284}},nil,{{29429}}},
        },

        [10222] = {
            [questKeys.preQuestSingle] = {},
        },

        [10225] = {
            [questKeys.objectives] = {nil,nil,{{28526}}},
        },

        [10226] = {
            [questKeys.objectives] = {nil,nil,{{28548},{28547}}},
        },

        [10229] = {
            [questKeys.objectivesText] = {"Take the Mysterious Tome to Althen the Historian in Spinebreaker Post.  "},
            [questKeys.objectives] = {nil,nil,{{28552}}},
        },

        [10231] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 138,
        },

        [10232] = {
            [questKeys.objectivesText] = {"Kill 5 Mo'arg Doomsmiths and 15 Gan'arg Engineers.  Then return to Papa Wheeler at Area 52 in the Netherstorm."},
        },

        [10233] = {
            [questKeys.specialFlags] = 32,
        },

        [10240] = {
            [questKeys.objectives] = {{{19866},{19867},{19868}},nil,{{28725}}},
            [questKeys.specialFlags] = 32,
        },

        [10241] = {
            [questKeys.breadcrumbs] = {11038},
        },

        [10242] = {
            [questKeys.objectivesText] = {"Apothecary Zelana at Reaver's Fall wants you to speak with Wing Commander Brack to take a wyvern to Spinebreaker Post, and then bring the Bleeding Hollow Blood Sample to Apothecary Albreck at Spinebreaker Post.  "},
            [questKeys.objectives] = {nil,nil,{{30404}}},
        },

        [10243] = {
            [questKeys.objectives] = {nil,nil,{{28571}}},
        },

        [10244] = {
            [questKeys.objectives] = {nil,nil,{{28598}}},
        },

        [10245] = {
            [questKeys.objectives] = {nil,nil,{{28580}}},
        },

        [10246] = {
            [questKeys.objectivesText] = {"Travel to Manaforge Coruu and slay 8 Sunfury Arcanists and 5 Sunfury Researchers.  Return to Exarch Orelis when you've completed this task.","","Performing quests for the Aldor will cause your Scryers reputation level to decrease."},
        },

        [10248] = {
            [questKeys.objectivesText] = {"Activate the Scrap Reaver X6000 Controller and test out its capabilities.  Then give your feedback to Doctor Vomisa, Ph.T at the Proving Grounds in the Netherstorm.  Deal with any problems that arise."},
            [questKeys.objectives] = {{{19851}},nil,{{28634}}},
        },

        [10250] = {
            [questKeys.objectivesText] = {"Blow the Unyielding Battle Horn near the Alliance Banner.  Kill Urtrak and then return to Althen the Historian at Spinebreaker Post."},
            [questKeys.objectives] = {{{19862}},nil,{{28651}}},
        },

        [10255] = {
            [questKeys.objectives] = {{{16992}},nil,{{23337}}},
        },

        [10258] = {
            [questKeys.objectivesText] = {"Report to Commander Hogarth in the Expedition Armory.  "},
        },

        [10265] = {
            [questKeys.preQuestSingle] = {10263,10264},
        },

        [10266] = {
            [questKeys.objectivesText] = {"Seek out and offer your services to Gahruj.  He is located at the Midrealm Post inside Eco-Dome Midrealm in the Netherstorm."},
        },

        [10268] = {
            [questKeys.objectives] = {nil,nil,{{28934}}},
        },

        [10269] = {
            [questKeys.objectivesText] = {"Use the Triangulation Device to point your way toward the first triangulation point.  Once you have found it, report the location to Dealer Hazzin at the Protectorate Watchpost on the Manaforge Ultris island in the Netherstorm."},
            [questKeys.objectives] = {nil,nil,{{28962}}},
        },

        [10274] = {
            [questKeys.objectives] = {{{18544}},nil,{{29101}}},
        },

        [10275] = {
            [questKeys.objectivesText] = {"Use the Triangulation Device to point your way toward the second triangulation point.  Once you have found it, report the location to Wind Trader Tuluman at Tuluman's Landing, just on the other side of the bridge from the Manaforge Ara island in the Netherstorm."},
            [questKeys.objectives] = {nil,nil,{{29018}}},
        },

        [10277] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10278] = {
            [questKeys.objectivesText] = {"Use the Unstable Warp Rift Generator in the Warp Fields.  Gather 3 Warp Nethers from Unstable Voidwalkers and return them to Ogath the Mad in Spinebreaker Post.  "},
            [questKeys.objectives] = {nil,nil,{{29051},{29027}}},
        },

        [10279] = {
            [questKeys.requiredRaces] = 1791,
        },

        [10280] = {
            [questKeys.objectives] = {nil,nil,{{29106}}},
        },

        [10283] = {
            [questKeys.objectives] = {{{20155}}},
        },

        [10288] = {
            [questKeys.objectives] = {nil,nil,{{28105}}},
            [questKeys.preQuestSingle] = {10119},
            [questKeys.breadcrumbs] = {},
        },

        [10289] = {
            [questKeys.objectivesText] = {"Take Vlagga Freyfeather's Wind Rider to Thrallmar.  Bring Orion's Report to General Krakork."},
            [questKeys.objectives] = {nil,nil,{{28024}}},
        },

        [10291] = {
            [questKeys.preQuestSingle] = {10289},
        },

        [10294] = {
            [questKeys.objectivesText] = {"Go to Void Ridge and kill the creatures you find.  Collect 40 Void Ridge Soul Shards and return them to Ogath the Mad in Spinebreaker Post."},
        },

        [10295] = {
            [questKeys.objectivesText] = {"Kill Void Baron Galaxis and collect his soul shard.  Take the shard to Ogath the Mad in Spinebreaker Post."},
            [questKeys.objectives] = {nil,nil,{{29162},{29226}}},
        },

        [10297] = {
            [questKeys.objectives] = nil,
        },

        [10299] = {
            [questKeys.objectivesText] = {"Return to Manaforge B'naar and obtain the B'naar Access Crystal from Overseer Theredis.  Use it at the Manaforge B'naar console to shut it down and report back to Anchorite Karja.","","Performing quests for the Aldor will cause your Scryers reputation level to decrease."},
            [questKeys.objectives] = {{{20209}},nil,{{29366}}},
            [questKeys.specialFlags] = 2,
        },

        [10301] = {
            [questKeys.objectivesText] = {"Obtain the Heliotrope Oculus from Spellreaver Marathelle at Sunfury Hold. "},
        },

        [10302] = {
            [questKeys.breadcrumbs] = {},
            [questKeys.specialFlags] = 4,
        },

        [10303] = {
            [questKeys.specialFlags] = 4,
        },

        [10304] = {
            [questKeys.breadcrumbForQuestId] = 0,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 4,
        },

        [10305] = {
            [questKeys.objectives] = {{{19547}}},
            [questKeys.specialFlags] = 32,
        },

        [10306] = {
            [questKeys.objectives] = {{{19548}}},
            [questKeys.specialFlags] = 32,
        },

        [10307] = {
            [questKeys.objectives] = {{{19550}}},
            [questKeys.specialFlags] = 32,
        },

        [10308] = {
            [questKeys.requiredMinRep] = {933,3000},
        },

        [10309] = {
            [questKeys.objectives] = {nil,nil,{{29260},{29447}}},
        },

        [10310] = {
            [questKeys.objectivesText] = {"Escort Drijya to the warp-gate at Invasion Point: Destroyer, and see to it that he is kept safe while he attempts to sabotage it.  Then speak to Gahruj at the Midrealm Post inside Eco-Dome Midrealm in the Netherstorm."},
            [questKeys.preQuestSingle] = {10311},
        },

        [10313] = {
            [questKeys.objectives] = {{{20333},{20336},{20337},{20338}},nil,{{29324}}},
            [questKeys.specialFlags] = 32,
        },

        [10318] = {
            [questKeys.objectivesText] = {"Slay Overmaster Grindgarr.  Then return to Wind Trader Tuluman at Tuluman's Landing in the Netherstorm."},
        },

        [10321] = {
            [questKeys.objectivesText] = {"Travel to Manaforge Coruu, east of Area 52, and obtain the Coruu Access Crystal from Overseer Seylanna.  Use it at the Manaforge Coruu Console to shut it down and return to Anchorite Karja.","","Performing quests for the Aldor will cause your Scryers reputation level to decrease."},
            [questKeys.objectives] = {{{20417}},nil,{{29396}}},
            [questKeys.specialFlags] = 2,
        },

        [10322] = {
            [questKeys.objectivesText] = {"Anchorite Karja wants you to go Manaforge Duro and obtain the Duro Access Crystal from Overseer Athanel.  Use it at the Manaforge Duro Console to shut it down.","","Performing quests for the Aldor will cause your Scryers reputation level to decrease."},
            [questKeys.objectives] = {{{20418}},nil,{{29397}}},
            [questKeys.specialFlags] = 2,
        },

        [10323] = {
            [questKeys.objectivesText] = {"Travel to Manaforge Ara and obtain the Ara Access Crystal from Overseer Azarad.  Use it at the Manaforge Ara console to shut it down.","","Performing quests for the Aldor will cause your Scryers reputation level to decrease."},
            [questKeys.objectives] = {{{20440}},nil,{{29411}}},
            [questKeys.specialFlags] = 2,
        },

        [10325] = {
            [questKeys.preQuestSingle] = {},
        },

        [10326] = {
            [questKeys.preQuestSingle] = {10325},
        },

        [10327] = {
            [questKeys.preQuestSingle] = {10325},
        },

        [10328] = {
            [questKeys.objectivesText] = {"Go to Manaforge Duro and retrieve the Sunfury Military Briefing and the Sunfury Arcane Briefing from the Sunfury units stationed there.  Return to Exarch Orellis when you've completed this task.","","Completing quests for the Aldor will cause your Scryers reputation level to decrease."},
            [questKeys.preQuestSingle] = {10313,10321},
        },

        [10329] = {
            [questKeys.objectivesText] = {"Return to Manaforge B'naar and obtain the B'naar Access Crystal from Overseer Theredis.  Use it at the B'naar Control Console to shut it down, then report back to Spymaster Thalodien.","","Performing quests for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.objectives] = {{{20209}},nil,{{29366}}},
            [questKeys.specialFlags] = 2,
        },

        [10330] = {
            [questKeys.objectivesText] = {"Obtain the Coruu Access Crystal from Overseer Seylanna.  Use it at the Coruu Control Console to shut down the manaforge and return to Caledis Brightdawn.","","Performing quests for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.objectives] = {{{20417}},nil,{{29396}}},
            [questKeys.specialFlags] = 2,
        },

        [10334] = {
            [questKeys.objectives] = {nil,nil,{{29428}}},
        },

        [10335] = {
            [questKeys.objectives] = {{{20473},{20475},{20476}},nil,{{29445}}},
            [questKeys.specialFlags] = 32,
        },

        [10336] = {
            [questKeys.objectivesText] = {"Slay 10 Hounds of Culuthas and 5 Eyes of Culuthas.  Then return to Nether-Stalker Nauthis at the Stormspire in the Netherstorm."},
        },

        [10338] = {
            [questKeys.objectivesText] = {"Return to Manaforge Duro and obtain the Duro Access Crystal from Overseer Athanel.  Use it at the Duro Control Console to shut it down and report back to Spymaster Thalodien.","","Performing quests for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.objectives] = {{{20418}},nil,{{29397}}},
            [questKeys.specialFlags] = 2,
        },

        [10341] = {
            [questKeys.objectivesText] = {"Slay 8 Sunfury Conjurers, 6 Sunfury Bowmen and 4 Sunfury Centurions.  Return to Magistrix Larynna at Area 52 after completing this task.","","Completing tasks for the Scryers will cause your Aldor reputation to decrease."},
        },

        [10344] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.specialFlags] = 2,
        },

        [10345] = {
            [questKeys.objectives] = {{{20561}},nil,{{29473}}},
            [questKeys.specialFlags] = 32,
        },

        [10346] = {
            [questKeys.objectives] = {{{19398},{19397},{19399}},nil,{{28132}}},
        },

        [10347] = {
            [questKeys.objectives] = {{{19398},{19397},{19399}},nil,{{28132}}},
        },

        [10349] = {
            [questKeys.objectives] = {nil,nil,{{29477}}},
        },

        [10350] = {
            [questKeys.preQuestSingle] = {9582},
        },

        [10351] = {
            [questKeys.objectivesText] = {"Use the Seed of Revitalization at the Earthbinder's Circle to heal the land around the crystal.  Then, return to Earthbinder Galandria Nightbreeze at the Cenarion Post in Hellfire Peninsula with any information that you gain."},
            [questKeys.objectives] = {{{19305}},nil,{{29478}}},
        },

        [10352] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10354] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10356] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10357] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [10358] = {
            [questKeys.questLevel] = 60,
        },

        [10359] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10360] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10361] = {
            [questKeys.questLevel] = 60,
            [questKeys.specialFlags] = 64,
        },

        [10362] = {
            [questKeys.questLevel] = 60,
            [questKeys.nextQuestInChain] = 0,
            [questKeys.specialFlags] = 64,
        },

        [10363] = {
            [questKeys.questLevel] = 60,
        },

        [10365] = {
            [questKeys.objectivesText] = {"Travel to Manaforge Ara and obtain the Ara Access Crystal from Overseer Azarad.  Use it at the Manaforge Ara console to shut it down.","","Performing quests for the Scryers will cause your Aldor reputation level to decrease."},
            [questKeys.objectives] = {{{20440}},nil,{{29411}}},
            [questKeys.specialFlags] = 2,
        },

        [10366] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10367] = {
            [questKeys.preQuestSingle] = {10403},
        },

        [10368] = {
            [questKeys.objectivesText] = {"Free Morod the Windstirrer, Akoru the Firecaller and Aylaan the Waterwaker at the Ruins of Sha'naar.  Return to Naladu after completing this task."},
            [questKeys.objectives] = {{{20677},{20678},{20679}},nil,{{29501}}},
        },

        [10369] = {
            [questKeys.objectivesText] = {"Use the Staff of Dreghood Elders on Arzeth the Merciless and slay him after he's lost his powers.  Return to Naladu at the Ruins of Sha'naar after completing this task."},
            [questKeys.objectives] = {{{20680}},nil,{{29513}}},
        },

        [10371] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [10372] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.exclusiveTo] = {2379},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10373] = {
            [questKeys.objectivesText] = {"Seek out Commander Ashlam Valorfist.  His base camp is located at Chillwind Camp, north of the Alterac Mountains."},
            [questKeys.exclusiveTo] = {},
        },

        [10374] = {
            [questKeys.objectivesText] = {"Seek out High Executor Derrington.  His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity."},
            [questKeys.exclusiveTo] = {},
        },

        [10379] = {
            [questKeys.preQuestSingle] = {10638},
        },

        [10389] = {
            [questKeys.preQuestSingle] = {10392,10393},
        },

        [10392] = {
            [questKeys.objectivesText] = {"Slay Arix'Amal to get the Burning Legion Gate Key.  Use the Burning Legion Gate Key on the Rune of Spite, then return to Nazgrel in Thrallmar."},
            [questKeys.specialFlags] = 32,
        },

        [10393] = {
            [questKeys.objectivesText] = {"Take the Burning Legion Missive to Magister Bloodhawk in Thrallmar. "},
            [questKeys.objectives] = {nil,nil,{{29589}}},
        },

        [10395] = {
            [questKeys.objectives] = {nil,nil,{{29589}}},
        },

        [10397] = {
            [questKeys.objectivesText] = {"Slay Arix'Amal.  Take the Burning Legion Gate Key.  Use the Burning Legion Gate Key on the Rune of Spite."},
        },

        [10398] = {
            [questKeys.objectivesText] = {"PH:  Go to Honor Hold."},
        },

        [10402] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 67,
            [questKeys.questFlags] = 136,
        },

        [10404] = {
            [questKeys.preQuestSingle] = {10381},
        },

        [10408] = {
            [questKeys.objectives] = {{{20454}},nil,{{29618}}},
        },

        [10409] = {
            [questKeys.objectivesText] = {"High Priestess Ishanah wants you to go to the Legion Teleporter at the northwestern corner of Netherstorm and use it to teleport to Socrethar's Seat.  Once there, defeat Socrethar.","","Performing quests for the Aldor will cause your Scryers reputation to decrease."},
        },

        [10410] = {
            [questKeys.objectives] = {nil,nil,{{29699}}},
        },

        [10411] = {
            [questKeys.objectives] = {{{20806},{20805}},nil,{{29737}}},
        },

        [10413] = {
            [questKeys.objectives] = {nil,nil,{{29738}}},
        },

        [10422] = {
            [questKeys.objectives] = {{{20787}}},
        },

        [10424] = {
            [questKeys.objectives] = {nil,nil,{{29769},{29803}}},
        },

        [10425] = {
            [questKeys.questFlags] = 130,
        },

        [10426] = {
            [questKeys.objectives] = {{{20983}},nil,{{29818}}},
            [questKeys.specialFlags] = 32,
        },

        [10427] = {
            [questKeys.objectives] = {{{20982}},nil,{{29817}}},
        },

        [10428] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10430] = {
            [questKeys.objectives] = {nil,nil,{{29770}}},
        },

        [10445] = {
            [questKeys.exclusiveTo] = {},
        },

        [10446] = {
            [questKeys.objectivesText] = {"Lieutenant Meridian wants you to use The Final Code to set off the Mana Bomb.  Then report back to Jenai Starwhisper at the Allerian Stronghold in Terokkar Forest."},
            [questKeys.objectives] = {{{21039}}},
            [questKeys.specialFlags] = 32,
        },

        [10447] = {
            [questKeys.objectivesText] = {"Sergeant Chawni wants you to use the Final Code Sheet to set off the Mana Bomb.  Then report back to Tooki at Stonebreaker Hold in Terokkar Forest."},
            [questKeys.objectives] = {{{21039}}},
            [questKeys.specialFlags] = 32,
        },

        [10449] = {
            [questKeys.objectives] = {nil,nil,{{30326}}},
        },

        [10452] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"[PH Fel Orc 1."},
            [questKeys.questFlags] = 136,
        },

        [10453] = {
            [questKeys.questLevel] = 58,
            [questKeys.requiredLevel] = 55,
            [questKeys.objectivesText] = {"[PH Fel Orc bread"},
            [questKeys.questFlags] = 136,
        },

        [10457] = {
            [questKeys.objectives] = {nil,{{184631}},{{29952}}},
        },

        [10458] = {
            [questKeys.objectives] = {{{21092},{21094}},nil,{{30094}}},
            [questKeys.preQuestSingle] = {10680,10681},
        },

        [10460] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10461] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10462] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10463] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10464] = {
            [questKeys.objectives] = {nil,nil,{{29302}}},
            [questKeys.sourceItemId] = 29302,
            [questKeys.exclusiveTo] = {},
        },

        [10465] = {
            [questKeys.objectives] = {nil,nil,{{29307}}},
            [questKeys.sourceItemId] = 29307,
            [questKeys.requiredMinRep] = {990,9000},
            [questKeys.exclusiveTo] = {},
        },

        [10466] = {
            [questKeys.objectives] = {nil,nil,{{29298}}},
            [questKeys.sourceItemId] = 29298,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [10467] = {
            [questKeys.objectives] = {nil,nil,{{29294}}},
            [questKeys.sourceItemId] = 29294,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [10468] = {
            [questKeys.objectives] = {nil,nil,{{29303}}},
            [questKeys.sourceItemId] = 29303,
            [questKeys.exclusiveTo] = {},
        },

        [10469] = {
            [questKeys.objectives] = {nil,nil,{{29306}}},
            [questKeys.sourceItemId] = 29306,
            [questKeys.exclusiveTo] = {},
        },

        [10470] = {
            [questKeys.objectives] = {nil,nil,{{29299}}},
            [questKeys.sourceItemId] = 29299,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [10471] = {
            [questKeys.objectives] = {nil,nil,{{29295}}},
            [questKeys.sourceItemId] = 29295,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [10472] = {
            [questKeys.objectives] = {nil,nil,{{29304}}},
            [questKeys.sourceItemId] = 29304,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10473] = {
            [questKeys.objectives] = {nil,nil,{{29308}}},
            [questKeys.sourceItemId] = 29308,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10474] = {
            [questKeys.objectives] = {nil,nil,{{29300}}},
            [questKeys.sourceItemId] = 29300,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10475] = {
            [questKeys.objectives] = {nil,nil,{{29296}}},
            [questKeys.sourceItemId] = 29296,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10476] = {
            [questKeys.requiredMinRep] = false,
        },

        [10479] = {
            [questKeys.requiredMinRep] = false,
        },

        [10480] = {
            [questKeys.objectives] = {{{21095}},nil,{{30094}}},
        },

        [10481] = {
            [questKeys.objectives] = {{{21096}},nil,{{30094}}},
        },

        [10482] = {
            [questKeys.objectives] = {{{21161}}},
            [questKeys.breadcrumbs] = {},
        },

        [10483] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10488] = {
            [questKeys.objectives] = {{{21142}},nil,{{30175}}},
            [questKeys.specialFlags] = 32,
        },

        [10490] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10491] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10492] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10493] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10502] = {
            [questKeys.objectives] = {{{19991}}},
        },

        [10503] = {
            [questKeys.objectives] = {{{19995},{20728}}},
        },

        [10504] = {
            [questKeys.objectives] = {{{19995}}},
        },

        [10505] = {
            [questKeys.objectives] = {{{19991}}},
        },

        [10506] = {
            [questKeys.objectives] = {{{20058}},nil,{{30251}}},
        },

        [10507] = {
            [questKeys.objectivesText] = {"Use Socrethar's Teleportation's Stone at Invasion Point: Overlord, north of Forge Base: Oblivion to transport your party to Socrethar's Landing.  Once there, use Voren'thal's Presence to defeat Socrethar.","","Performing quests for the Scryers will cause your Aldor reputation to decrease."},
        },

        [10512] = {
            [questKeys.objectives] = {{{21241}},nil,{{30353}}},
        },

        [10514] = {
            [questKeys.objectives] = {nil,nil,{{30356},{30462}}},
        },

        [10518] = {
            [questKeys.objectivesText] = {"Use the Bladespire Banner atop the Northmaul Tower to lure Gurn Grubnosh.  Collect the Bladespire Clan Banner and the Helm of Gurn Grubnosh."},
        },

        [10519] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 138,
        },

        [10520] = {
            [questKeys.exclusiveTo] = {},
        },

        [10523] = {
            [questKeys.objectives] = {nil,nil,{{30429}}},
        },

        [10524] = {
            [questKeys.objectives] = {nil,nil,{{30431},{30433},{30432},{30434}}},
        },

        [10525] = {
            [questKeys.objectives] = {nil,nil,{{30481}}},
        },

        [10529] = {
            [questKeys.exclusiveTo] = {9617,10530},
        },

        [10530] = {
            [questKeys.exclusiveTo] = {9617,10529},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10538] = {
            [questKeys.objectivesText] = {"Use Bleeding Hollow Blood at the Cursed Cauldron to make Boiled Blood.  Bring 12 Boiled Blood to Apothecary Albreck at Spinebreaker Post."},
        },

        [10541] = {
            [questKeys.objectives] = {nil,nil,{{30454}}},
        },

        [10544] = {
            [questKeys.objectives] = {{{21446},{21452}},nil,{{30479}}},
        },

        [10545] = {
            [questKeys.objectives] = {{{21241}},nil,{{30353}}},
            [questKeys.specialFlags] = 32,
        },

        [10548] = {
            [questKeys.preQuestSingle] = {9491},
        },

        [10549] = {
            [questKeys.questLevel] = 18,
            [questKeys.requiredLevel] = 16,
            [questKeys.requiredClasses] = 8,
            [questKeys.objectivesText] = {"Eralan in Tranquillien wants you to retrieve the Archeologist's Shrunken Head from one of the chests in Zeb'Tela or Zeb'Nowa."},
            [questKeys.objectives] = {nil,nil,{{30503}}},
            [questKeys.questFlags] = 136,
        },

        [10550] = {
            [questKeys.objectives] = {nil,nil,{{30501}}},
        },

        [10554] = {
            [questKeys.requiredMinRep] = {932,3000},
        },

        [10556] = {
            [questKeys.objectives] = {{{21511}},nil,{{30530}}},
        },

        [10562] = {
            [questKeys.objectives] = {{{21419}}},
        },

        [10563] = {
            [questKeys.objectives] = {{{21502}},nil,{{30638}}},
        },

        [10564] = {
            [questKeys.objectives] = {{{21512}},nil,{{30614}}},
            [questKeys.specialFlags] = 32,
        },

        [10566] = {
            [questKeys.objectives] = {{{21713},{21714},{21715},{21716}}},
            [questKeys.requiredSourceItems] = {30655},
        },

        [10577] = {
            [questKeys.objectives] = nil,
        },

        [10579] = {
            [questKeys.objectives] = {nil,nil,{{30646}}},
        },

        [10580] = {
            [questKeys.exclusiveTo] = {},
        },

        [10581] = {
            [questKeys.exclusiveTo] = {},
        },

        [10584] = {
            [questKeys.objectives] = {{{21731}},nil,{{30656}}},
            [questKeys.preQuestSingle] = {10581},
        },

        [10585] = {
            [questKeys.objectivesText] = {"Obtain an Elemental Displacer from a Deathforge Smith or Deathforge Tinkerer and use it to disrupt the ritual in the summoning  chamber. Report to Stormer Ewan Wildwing at the Deathforge Tower when you've completed your task."},
            [questKeys.sourceItemId] = 0,
        },

        [10586] = {
            [questKeys.preQuestSingle] = {10583,10585},
        },

        [10588] = {
            [questKeys.objectives] = {{{21181}},nil,{{30657}}},
            [questKeys.preQuestSingle] = {10523,10541,10579},
        },

        [10591] = {
            [questKeys.requiredClasses] = 2,
            [questKeys.questFlags] = 136,
        },

        [10592] = {
            [questKeys.objectives] = {nil,nil,{{30700}}},
        },

        [10593] = {
            [questKeys.objectivesText] = {"Unlock the secrets of the Temple of Atal'Hakkar to release Atal'alarion and recover the Putrid Vine from his flesh.  Return to Mehlar at the Bulwark when you have done this."},
        },

        [10594] = {
            [questKeys.objectives] = {nil,nil,{{30701}}},
        },

        [10595] = {
            [questKeys.objectives] = {{{21419}}},
        },

        [10596] = {
            [questKeys.objectives] = {{{21502}},nil,{{30638}}},
        },

        [10598] = {
            [questKeys.objectives] = {{{21512}},nil,{{30614}}},
            [questKeys.specialFlags] = 32,
        },

        [10603] = {
            [questKeys.preQuestSingle] = {10601,10602},
        },

        [10605] = {
            [questKeys.nextQuestInChain] = 1472,
            [questKeys.breadcrumbForQuestId] = 1472,
        },

        [10606] = {
            [questKeys.objectives] = {nil,nil,{{30713}}},
            [questKeys.requiredSourceItems] = {30712},
        },

        [10607] = {
            [questKeys.objectives] = {{{22798},{22799},{22800},{22801}}},
        },

        [10609] = {
            [questKeys.objectives] = {nil,nil,{{30743},{30782},{30783},{30742}}},
        },

        [10611] = {
            [questKeys.objectives] = {nil,nil,{{30713}}},
            [questKeys.requiredSourceItems] = {30712},
        },

        [10612] = {
            [questKeys.objectives] = {{{21959}}},
        },

        [10613] = {
            [questKeys.objectives] = {{{21959}}},
        },

        [10616] = {
            [questKeys.questLevel] = 66,
            [questKeys.requiredLevel] = 61,
            [questKeys.questFlags] = 136,
        },

        [10617] = {
            [questKeys.objectivesText] = {"Collect 8 Silkwing Cocoons from Silkwing Larva.$b$bKill the Larva quickly or they will turn into Silkwings, ruining their cocoons."},
        },

        [10621] = {
            [questKeys.objectives] = {nil,nil,{{30756}}},
        },

        [10623] = {
            [questKeys.objectives] = {nil,nil,{{30579}}},
        },

        [10625] = {
            [questKeys.objectives] = {{{21788}},nil,{{30719}}},
        },

        [10629] = {
            [questKeys.objectivesText] = {"Use the Felhound Whistle to summon a Fel Guard Hound.  Take the Fel Guard Hound for a walk and kill some Deranged Helboars.  Search for the Shredder Keys in the Fel Guard Hound's \"leavings.\"  Return the Shredder Keys to Foreman Razelcraz by the mine northwest of Thrallmar."},
            [questKeys.objectives] = {nil,nil,{{30794},{30803}}},
        },

        [10631] = {
            [questKeys.questLevel] = 61,
            [questKeys.requiredLevel] = 255,
            [questKeys.objectivesText] = {"Get some ore."},
            [questKeys.objectives] = {nil,nil,{{30796}}},
            [questKeys.questFlags] = 128,
        },

        [10634] = {
            [questKeys.preQuestSingle] = {},
        },

        [10635] = {
            [questKeys.preQuestSingle] = {},
        },

        [10636] = {
            [questKeys.preQuestSingle] = {},
        },

        [10637] = {
            [questKeys.objectives] = {{{21892}}},
            [questKeys.specialFlags] = 32,
        },

        [10641] = {
            [questKeys.objectivesText] = {"Altruis the Sufferer wants you to obtain Freshly Drawn Blood from a Wrath Priestess at Forge Base: Gehenna in Netherstorm.  Spill it on the ground and slay the Avatar of Sathal.  Return to Altruis when you've completed this task."},
            [questKeys.preQuestSingle] = {},
        },

        [10643] = {
            [questKeys.objectives] = {{{21795}},nil,{{30719}}},
        },

        [10646] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {10641,10668,10669},
            [questKeys.questFlags] = 138,
        },

        [10649] = {
            [questKeys.objectivesText] = {"Venture inside the Shadow Labyrinth in Auchindoun and obtain the Book of Fel Names from Blackheart the Inciter.  Return to Altruis in Nagrand once you've completed this task."},
        },

        [10651] = {
            [questKeys.objectivesText] = {"Exarch Onaala wants you to go to the ruins of Karabor and slay Alandien, Theras, Netharel and Varedis.  Use the Book of Fel Names when Varedis uses Metamorphosis to weaken him.  Return to Exarch Onaala with the Book of Fel Names after you've completed this task.","","Completing quests for the Aldor will cause your Scryers reputation to decrease."},
            [questKeys.objectives] = {{{21178},{21164},{21168},{21171}},nil,{{30854}}},
        },

        [10652] = {
            [questKeys.objectivesText] = {"Speak to Veronia when you're ready to depart to Manaforge Coruu.  Once there, speak to Caledis Brightdawn.","","Completing quests for the Scryers will cause your Aldor reputation level to decrease."},
        },

        [10653] = {
            [questKeys.preQuestSingle] = {},
        },

        [10654] = {
            [questKeys.preQuestSingle] = {10653},
        },

        [10655] = {
            [questKeys.preQuestSingle] = {10653},
        },

        [10657] = {
            [questKeys.objectivesText] = {"Use the Repolarized Magneto Sphere to absorb 25 lightning strikes from the Scalewing Serpents.  Also, collect 5 Scalewing Lightning Glands."},
            [questKeys.objectives] = {{{21910}},nil,{{30849},{30818}}},
        },

        [10662] = {
            [questKeys.objectives] = {nil,nil,{{30822}}},
        },

        [10663] = {
            [questKeys.objectives] = {nil,nil,{{30822}}},
        },

        [10667] = {
            [questKeys.preQuestSingle] = {10665,10666},
        },

        [10668] = {
            [questKeys.preQuestSingle] = {},
        },

        [10669] = {
            [questKeys.objectivesText] = {"Altruis the Sufferer wants you to take the Imbued Silver Spear and use it at Portal Clearing near Marshlight Lake in Zangarmarsh to awake Xeleth.  Return to Altruis after you've slain the demon."},
            [questKeys.objectives] = {{{21894}},nil,{{30853}}},
            [questKeys.preQuestSingle] = {},
        },

        [10670] = {
            [questKeys.preQuestSingle] = {10665,10666},
        },

        [10672] = {
            [questKeys.objectives] = {{{21924}}},
        },

        [10674] = {
            [questKeys.objectives] = {{{21929}},nil,{{30852}}},
        },

        [10676] = {
            [questKeys.preQuestSingle] = {10667,10670},
        },

        [10682] = {
            [questKeys.objectives] = nil,
        },

        [10683] = {
            [questKeys.preQuestSingle] = {},
        },

        [10687] = {
            [questKeys.preQuestSingle] = {},
        },

        [10688] = {
            [questKeys.specialFlags] = 32,
        },

        [10692] = {
            [questKeys.objectivesText] = {"Larissa Sunstrike wants you to go to the ruins of Karabor and slay Alandien, Theras, Netharel and Varedis.  Use the Book of Fel Names when Varedis uses Metamorphosis to weaken him.  Return to Larissa Sunstrike with the Book of Fel Names after completing this task.","","Completing quests for the Scryers will cause your Aldor reputation to decrease."},
            [questKeys.objectives] = {{{21178},{21164},{21168},{21171}},nil,{{30854}}},
        },

        [10702] = {
            [questKeys.objectives] = {{{21978}}},
        },

        [10703] = {
            [questKeys.objectives] = {{{21978}}},
        },

        [10704] = {
            [questKeys.objectivesText] = {"A'dal has tasked you with the recovery of the Top and Bottom Shards of the Arcatraz Key.  Return them to him, and he will fashion them into the Key to the Arcatraz for you."},
        },

        [10707] = {
            [questKeys.objectivesText] = {"Go to the top of the Ata'mal Terrace in Shadowmoon Valley and obtain the Heart of Fury.  Return to Akama at the Warden's Cage in Shadowmoon Valley when you've completed this task."},
        },

        [10708] = {
            [questKeys.exclusiveTo] = {},
        },

        [10711] = {
            [questKeys.preQuestSingle] = {10710},
        },

        [10712] = {
            [questKeys.objectivesText] = {"Speak with Rally Zapnabber to use the Zephyrium Capacitorium.  While flying to Ruuan Weald, spin the Nether-weather Vane.  Deliver the Spinning Nether-weather Vane to O'Mally Zapnabber in Evergrove."},
            [questKeys.preQuestSingle] = {10711},
        },

        [10714] = {
            [questKeys.objectives] = {{{22383}},nil,{{31128}}},
            [questKeys.specialFlags] = 32,
        },

        [10716] = {
            [questKeys.objectivesText] = {"Speak with Rally Zapnabber to use the Zephyrium Capacitorium.  Return to Tally Zapnabber at Toshley's Station."},
        },

        [10719] = {
            [questKeys.objectives] = {nil,nil,{{31120}}},
            [questKeys.preQuestSingle] = {},
        },

        [10720] = {
            [questKeys.objectives] = {{{22356},{22367},{22368}},nil,{{31141}}},
        },

        [10722] = {
            [questKeys.objectivesText] = {"Collect enough Costume Scraps from wyrmcultists to create an Overseer Disguise.  Use the disguise to attend the meeting with Kolphis Darkscale."},
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {},
        },

        [10723] = {
            [questKeys.objectivesText] = {"Collect 3 Grisly Totems from the Boulder'mok ogres. Then, use Sablemane's Trap at Gorgrom's Altar to set the trap and summon and kill Gorgrom the Dragon-Eater.$b$bWhen Gorgrom is dead, place the 3 Grisly Totems near his corpse."},
            [questKeys.objectives] = {{{22434}},nil,{{31752}}},
        },

        [10724] = {
            [questKeys.objectives] = {{{22435}},nil,{{31144}}},
        },

        [10725] = {
            [questKeys.objectives] = {nil,nil,{{29286}}},
            [questKeys.sourceItemId] = 29286,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10726] = {
            [questKeys.objectives] = {nil,nil,{{29291}}},
            [questKeys.sourceItemId] = 29291,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10727] = {
            [questKeys.objectives] = {nil,nil,{{29282}}},
            [questKeys.sourceItemId] = 29282,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10728] = {
            [questKeys.objectives] = {nil,nil,{{29278}}},
            [questKeys.sourceItemId] = 29278,
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [10729] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10730] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10731] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10732] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10733] = {
            [questKeys.sourceItemId] = 29284,
            [questKeys.exclusiveTo] = {},
        },

        [10734] = {
            [questKeys.sourceItemId] = 29288,
            [questKeys.exclusiveTo] = {},
        },

        [10735] = {
            [questKeys.sourceItemId] = 29280,
            [questKeys.exclusiveTo] = {},
        },

        [10736] = {
            [questKeys.sourceItemId] = 29276,
            [questKeys.exclusiveTo] = {},
        },

        [10737] = {
            [questKeys.objectives] = {nil,nil,{{24489}}},
        },

        [10738] = {
            [questKeys.sourceItemId] = 29285,
            [questKeys.exclusiveTo] = {},
        },

        [10739] = {
            [questKeys.sourceItemId] = 29289,
            [questKeys.exclusiveTo] = {},
        },

        [10740] = {
            [questKeys.sourceItemId] = 29281,
            [questKeys.exclusiveTo] = {},
        },

        [10741] = {
            [questKeys.sourceItemId] = 29277,
            [questKeys.exclusiveTo] = {},
        },

        [10742] = {
            [questKeys.objectives] = {{{20555}},nil,{{31146}}},
        },

        [10743] = {
            [questKeys.questLevel] = 67,
            [questKeys.requiredLevel] = 65,
            [questKeys.questFlags] = 136,
        },

        [10746] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Bring your Band of Eternity to Soridormi at the Caverns of Time after obtaining Exalted reputation with the Scale of the Sands."},
            [questKeys.objectives] = {nil,nil,{{29304}}},
            [questKeys.sourceItemId] = 29304,
            [questKeys.questFlags] = 136,
        },

        [10747] = {
            [questKeys.objectives] = {nil,nil,{{31130},{31129}}},
        },

        [10749] = {
            [questKeys.objectives] = {nil,nil,{{31135}}},
        },

        [10750] = {
            [questKeys.objectivesText] = {"Travel to the Path of Conquest in Shadowmoon Valley. "},
        },

        [10754] = {
            [questKeys.objectives] = {nil,nil,{{31239}}},
        },

        [10755] = {
            [questKeys.objectives] = {nil,nil,{{31241}}},
        },

        [10756] = {
            [questKeys.objectives] = {nil,nil,{{31245}}},
        },

        [10758] = {
            [questKeys.objectivesText] = {"Destroy a Fel Reaver in Hellfire Peninsula and plunge the Unfired Key Mold into its remains.  Bring the Charred Key Mold to Rohok in Thrallmar."},
        },

        [10762] = {
            [questKeys.objectives] = {nil,nil,{{31245}}},
        },

        [10764] = {
            [questKeys.objectivesText] = {"Destroy a Fel Reaver in Hellfire Peninsula and plunge the Unfired Key Mold into its remains.  Bring the Charred Key Mold to Dumphry in Honor Hold."},
        },

        [10769] = {
            [questKeys.objectives] = {{{22051}},nil,{{31108}}},
        },

        [10770] = {
            [questKeys.objectivesText] = {"Mosswood the Ancient wants you to kill 8 Scorch Imps and then return to him in Ruuan Weald. "},
        },

        [10771] = {
            [questKeys.objectives] = {nil,{{185124},{185147},{185148}},{{31300}}},
            [questKeys.specialFlags] = 32,
        },

        [10776] = {
            [questKeys.objectives] = {{{22051}},nil,{{31310}}},
        },

        [10779] = {
            [questKeys.requiredRaces] = 1024,
        },

        [10785] = {
            [questKeys.objectives] = {nil,nil,{{31351}}},
        },

        [10787] = {
            [questKeys.questLevel] = 67,
            [questKeys.requiredLevel] = 65,
            [questKeys.objectivesText] = {"Rexxar has asked you to speak to him about riding &&& out to Dragons' End to recover a Black Dragon Corpse.  Return to him at Thunderlord Stronghold in the Blade's Edge Mountains when you have it."},
            [questKeys.objectives] = {nil,nil,{{31469}}},
            [questKeys.questFlags] = 136,
        },

        [10789] = {
            [questKeys.exclusiveTo] = {},
        },

        [10790] = {
            [questKeys.exclusiveTo] = {},
        },

        [10791] = {
            [questKeys.objectives] = {{{18384}},nil,{{31344}}},
        },

        [10792] = {
            [questKeys.requiredSourceItems] = {31347},
            [questKeys.specialFlags] = 32,
        },

        [10793] = {
            [questKeys.objectives] = {nil,nil,{{31345}}},
        },

        [10794] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [10797] = {
            [questKeys.objectives] = {nil,nil,{{31363}}},
            [questKeys.preQuestSingle] = {10795},
        },

        [10800] = {
            [questKeys.objectives] = {nil,nil,{{31349},{31403}}},
        },

        [10801] = {
            [questKeys.objectives] = {nil,nil,{{31351}}},
        },

        [10802] = {
            [questKeys.objectivesText] = {"Collect 3 Grisly Totems from Boulder'mok ogres. Then, use Sablemane's Trap at Gorgrom's Altar to summon and kill Gorgrom the Dragon-Eater.$b$bWhen Gorgrom is dead, place the 3 Grisly Totems near his corpse."},
            [questKeys.objectives] = {{{22434}},nil,{{31827}}},
            [questKeys.specialFlags] = 32,
        },

        [10804] = {
            [questKeys.objectives] = {{{22131}}},
        },

        [10806] = {
            [questKeys.objectives] = {{{20555}},nil,{{31808}}},
        },

        [10807] = {
            [questKeys.preQuestSingle] = {},
        },

        [10808] = {
            [questKeys.objectives] = {{{22137}},nil,{{31386}}},
            [questKeys.specialFlags] = 32,
        },

        [10810] = {
            [questKeys.objectives] = {nil,nil,{{31384}}},
        },

        [10812] = {
            [questKeys.objectives] = {nil,nil,{{31387}}},
        },

        [10813] = {
            [questKeys.objectivesText] = {"Use Zezzak's Shard to capture an Eye of Grillok, then approach Zezzak's cauldron to extract it.  After it is removed, return Zezzak's Shard to him."},
            [questKeys.objectives] = {{{22177}},nil,{{31463}}},
            [questKeys.specialFlags] = 32,
        },

        [10814] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 130,
        },

        [10815] = {
            [questKeys.objectives] = {nil,nil,{{31345}}},
        },

        [10822] = {
            [questKeys.preQuestSingle] = {10824},
        },

        [10823] = {
            [questKeys.preQuestSingle] = {10824},
        },

        [10824] = {
            [questKeys.preQuestSingle] = {},
        },

        [10825] = {
            [questKeys.objectives] = {nil,nil,{{31489}}},
        },

        [10826] = {
            [questKeys.preQuestSingle] = {},
        },

        [10827] = {
            [questKeys.preQuestSingle] = {10826},
        },

        [10828] = {
            [questKeys.preQuestSingle] = {10826},
        },

        [10830] = {
            [questKeys.objectivesText] = {"Collect 5 Grishnath Orbs and 5 Dire Pinfeathers and then combine them into Exorcism Feathers.  Use these feathers to exorcise and slay 5 Koi-Koi Spirits from the Raven's Wood Leafbeards."},
            [questKeys.requiredSourceItems] = {},
        },

        [10831] = {
            [questKeys.requiredSkill] = {197,325},
        },

        [10832] = {
            [questKeys.objectives] = {nil,nil,{{31741},{31742}}},
            [questKeys.requiredSkill] = {197,325},
        },

        [10833] = {
            [questKeys.requiredSkill] = {197,325},
            [questKeys.specialFlags] = 32,
        },

        [10835] = {
            [questKeys.objectives] = {nil,nil,{{31550}}},
        },

        [10836] = {
            [questKeys.objectives] = {{{22197}}},
        },

        [10838] = {
            [questKeys.objectives] = {nil,nil,{{31607},{31606}}},
        },

        [10839] = {
            [questKeys.objectives] = {nil,nil,{{31610}}},
        },

        [10840] = {
            [questKeys.preQuestSingle] = {10849},
        },

        [10841] = {
            [questKeys.objectivesText] = {"[PH]  Activate the thingy."},
        },

        [10842] = {
            [questKeys.objectives] = {{{21636}}},
            [questKeys.sourceItemId] = 0,
            [questKeys.preQuestSingle] = {10849},
        },

        [10847] = {
            [questKeys.preQuestSingle] = {10862,10863,10908},
        },

        [10849] = {
            [questKeys.objectives] = {nil,nil,{{31662}}},
        },

        [10854] = {
            [questKeys.objectives] = {{{22316}},nil,{{31652}}},
        },

        [10855] = {
            [questKeys.objectivesText] = {"Obtain 5 Condensed Nether Gas from Gan'arg Mekgineers at Forge Base: Oblivion, northwest of the Stormspire, and load them into a nearby Inactive Fel Reaver.  Return to Nether-Stalker Nauthis after you've completed this task."},
            [questKeys.specialFlags] = 2,
        },

        [10857] = {
            [questKeys.objectives] = {{{22348},{22350},{22351}},nil,{{31678}}},
        },

        [10859] = {
            [questKeys.objectives] = {{{21929}},nil,{{31668}}},
            [questKeys.specialFlags] = 32,
        },

        [10861] = {
            [questKeys.objectives] = {{{22337}},{{185211}}},
        },

        [10862] = {
            [questKeys.exclusiveTo] = {10863,10908},
        },

        [10863] = {
            [questKeys.exclusiveTo] = {10862,10908},
        },

        [10864] = {
            [questKeys.objectives] = {{{22334}}},
        },

        [10865] = {
            [questKeys.objectivesText] = {"Speak with Leoroxx about what the Razaani ethereal are up to.  He can be found at Mok'Nathal Village in the Blade's Edge Mountains."},
        },

        [10866] = {
            [questKeys.objectives] = {{{11980}},{{185156}}},
            [questKeys.specialFlags] = 32,
        },

        [10873] = {
            [questKeys.objectives] = {{{22459}}},
        },

        [10877] = {
            [questKeys.objectivesText] = {"Oakun wants you to travel east to the Derelict Caravan to recover the Dread Relic.  Return to Oakun when the task is complete."},
            [questKeys.objectives] = {nil,nil,{{31697},{31705}}},
        },

        [10879] = {
            [questKeys.objectives] = {{{22375}}},
        },

        [10880] = {
            [questKeys.objectives] = {nil,nil,{{31707}}},
        },

        [10881] = {
            [questKeys.objectivesText] = {"Go into the Shadow Tomb, west of the Refugee Caravan and retrieve the Drape of Arunen, the Gavel of K'alen and the Scroll of Atalor.  Return to Mekeda at the Refugee Caravan after you've completed this task."},
        },

        [10882] = {
            [questKeys.objectivesText] = {"You have been tasked to go to Tempest Keep's Arcatraz satellite and slay Harbinger Skyriss.  Return to A'dal at the Terrace of Light in Shattrath City after you have done so."},
        },

        [10887] = {
            [questKeys.objectivesText] = {"Help Akuno find his way to the Refugee Caravan.  Speak to Mekeda after you've completed this quest."},
        },

        [10888] = {
            [questKeys.preQuestSingle] = {10884,10885,10886},
        },

        [10890] = {
            [questKeys.questFlags] = 136,
        },

        [10891] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 7652,
        },

        [10892] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 7652,
        },

        [10894] = {
            [questKeys.objectives] = {nil,nil,{{31740}}},
        },

        [10895] = {
            [questKeys.specialFlags] = 32,
        },

        [10896] = {
            [questKeys.objectivesText] = {"Lakotae wants you to kill 25 Wood Mites and then return to him at the Refugee Caravan.  The mites can be found living inside the bodies of Rotting Forest-Ragers and Infested Root-Walkers.  "},
        },

        [10897] = {
            [questKeys.objectivesText] = {"Lauranna Thar'well wants you to go to the Botanica in Tempest Keep and retrieve the Botanist's Field Guide from High Botanist Freywinn.  In addition she also wants you to bring her 5 Super Healing Potions, 5 Super Mana Potions and 5 Major Dreamless Sleep Potions.","","*WARNING!* You can only select one alchemy specialization."},
            [questKeys.preQuestSingle] = {10905},
        },

        [10899] = {
            [questKeys.preQuestSingle] = {10907},
        },

        [10900] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [10901] = {
            [questKeys.preQuestSingle] = {10900},
            [questKeys.exclusiveTo] = {},
        },

        [10902] = {
            [questKeys.objectivesText] = {"Go to the Black Morass in the Caverns of Time and obtain 10 Essences of Infinity from Rift Lords and Rift Keepers.  Bring these along with  5 Elixirs of Major Defense, 5 Elixirs of Mastery and 5 Elixirs of Major Agility to Lorokeem in Shattrath's Lower City.","","*WARNING!* You can only select one alchemy specialization."},
            [questKeys.preQuestSingle] = {10906},
        },

        [10905] = {
            [questKeys.exclusiveTo] = {10906,10907},
        },

        [10906] = {
            [questKeys.exclusiveTo] = {10905,10907},
        },

        [10907] = {
            [questKeys.exclusiveTo] = {10905,10906},
        },

        [10909] = {
            [questKeys.objectives] = {{{22454}},nil,{{31772}}},
        },

        [10911] = {
            [questKeys.objectivesText] = {"Use the Naturalized Ammunition to take control of the Death's Door Fel Cannons.  Use the cannons to destroy both the South Warp-Gate and the North Warp-Gate."},
            [questKeys.objectives] = {{{22504},{22503}},nil,{{31807}}},
        },

        [10912] = {
            [questKeys.objectives] = {{{19747}},nil,{{31763},{31809}}},
        },

        [10913] = {
            [questKeys.objectives] = {{{21859},{21846}},nil,{{31769}}},
            [questKeys.specialFlags] = 32,
        },

        [10917] = {
            [questKeys.requiredMaxRep] = {1011,8999},
        },

        [10923] = {
            [questKeys.objectivesText] = {"Oakun wants you to take the Dread Relic to the Writhing Mound.  Once there, kill Auchenai Death-Speakers and Auchenai Doomsayers to collect 20 Doom Skulls.  Then find the Writhing Mound Summoning Circle and use the Dread Relic to summon and destroy Teribus the Cursed.  Return to Oakun when the deed is done."},
            [questKeys.objectives] = {{{22441}},nil,{{31811}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 0,
        },

        [10924] = {
            [questKeys.objectives] = {nil,nil,{{31813},{31815}}},
        },

        [10925] = {
            [questKeys.objectives] = {{{22441}},nil,{{31811}}},
        },

        [10929] = {
            [questKeys.objectives] = {nil,nil,{{31814},{31810}}},
        },

        [10930] = {
            [questKeys.objectives] = {nil,nil,{{31826},{31825}}},
        },

        [10935] = {
            [questKeys.objectivesText] = {"Speak with Anchorite Barada.  Use the prayer beads to help with the ritual, and then speak with Colonel Jules when he is saved.  Finally, return to Assistant Klatu."},
            [questKeys.objectives] = {{{22432}},nil,{{31828}}},
            [questKeys.specialFlags] = 32,
        },

        [10936] = {
            [questKeys.objectivesText] = {"Assistant Klatu has informed you that Force Commander Danath Trollbane has been seeking you.  Speak to him in the barracks at Honor Hold in Hellfire Peninsula."},
        },

        [10937] = {
            [questKeys.objectivesText] = {"Force Commander Danath Trollbane has ordered you to kill Drillmaster Zurok with all due haste.  Return to the force commander at Honor Hold in the Hellfire Peninsula once the drillmaster is dead."},
        },

        [10938] = {
            [questKeys.sourceItemId] = 31890,
        },

        [10939] = {
            [questKeys.sourceItemId] = 31891,
        },

        [10940] = {
            [questKeys.sourceItemId] = 31907,
        },

        [10941] = {
            [questKeys.sourceItemId] = 31914,
        },

        [10945] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to Sporeggar in Zangarmarsh.  Make sure to call for her if she is not present when you arrive.  Then, speak with Hch'uu."},
            [questKeys.questFlags] = 138,
        },

        [10946] = {
            [questKeys.objectivesText] = {"Travel into Tempest Keep and slay Al'ar while wearing the Ashtongue Cowl.  Return to Akama in Shadowmoon Valley once you've completed this task."},
            [questKeys.objectives] = {nil,nil,{{31946}}},
        },

        [10947] = {
            [questKeys.objectivesText] = {"Go to the Caverns of Time in Tanaris and gain access to the Battle of Mount Hyjal.  Once inside, defeat Rage Winterchill and bring the Time-Phased Phylactery to Akama in Shadowmoon Valley."},
        },

        [10949] = {
            [questKeys.nextQuestInChain] = 10985,
        },

        [10950] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, to the Meeting Stone at the Ring of Observance in the middle of Auchindoun.  Auchindoun, in turn, is in the middle of Terokkar Forest's Bone Wastes.  Make sure to call for her if she is not present when you arrive."},
        },

        [10951] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Salandria, up the steps of the Stair of Destiny to stand before the Dark Portal in Hellfire Peninsula.  Make sure to call for her if she is not present when you arrive."},
        },

        [10952] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, up the steps of the Stair of Destiny to stand before the Dark Portal in Hellfire Peninsula.  Make sure to call for her if she is not present when you arrive."},
        },

        [10953] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to the Throne of the Elements in Nagrand.  Make sure to call for her if she is not present when you arrive.  Then, speak with Elementalist Sharvak."},
        },

        [10954] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, to Aeris Landing in Nagrand.  Make sure to call for her if she is not present when you arrive.  Then, speak with Jheel."},
        },

        [10956] = {
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, to stand before O'ros at the bottom of the Seat of the Naaru inside of the Exodar, which is on Azuremyst Isle.  Make sure to call for her if she is not present when you arrive.","","Remember that you can use your map inside the city."},
            [questKeys.preQuestSingle] = {10950},
        },

        [10957] = {
            [questKeys.objectivesText] = {"Help Akama wrest control back of his soul by defeating the Shade of Akama inside the Black Temple.  Return to Seer Kanai when you've completed this task."},
        },

        [10958] = {
            [questKeys.preQuestSingle] = {10985},
        },

        [10960] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to the paladin trainers in Silvermoon City's Farstriders' Square.  Make sure to call for her if she is not present when you arrive.  Then, speak with Lady Liadrin, the Blood Knight Matriarch.","","Remember that you can use your map inside the city, and speak to the guards to find the paladin trainers."},
            [questKeys.preQuestSingle] = {10945},
            [questKeys.specialFlags] = 0,
        },

        [10961] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [10962] = {
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, to stand before Zaladormu, the dragon on the dais in the middle of the Caverns of Time.  Make sure to call for her if she is not present when you arrive.","","Then, purchase a Toy Dragon for her from the Keepers of Time Quartermaster, Alurmi, near the bottom of the entrance tunnel."},
            [questKeys.preQuestSingle] = {10950},
        },

        [10963] = {
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to stand before Zaladormu, the dragon on the dais in the middle of the Caverns of Time.  Make sure to call for her if she is not present when you arrive.","","Then, purchase a Toy Dragon for her from the Keepers of Time Quartermaster, Alurmi, near the bottom of the entrance tunnel."},
            [questKeys.preQuestSingle] = {10945},
        },

        [10964] = {
            [questKeys.objectives] = {nil,nil,{{31953}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [10966] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {10968},
        },

        [10967] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {11975},
        },

        [10968] = {
            [questKeys.objectivesText] = {"Take your orphan, Dornaa, to visit Farseer Nobundo at the Crystal Hall inside of the Exodar, which is on Azuremyst Isle.  Make sure to call for her if she is not present when you arrive.","","Remember that you can use your map inside the city."},
            [questKeys.objectives] = nil,
        },

        [10971] = {
            [questKeys.requiredSourceItems] = {},
        },

        [10974] = {
            [questKeys.objectives] = {nil,nil,{{32061},{31994}}},
            [questKeys.requiredMinRep] = false,
        },

        [10975] = {
            [questKeys.requiredMinRep] = false,
        },

        [10976] = {
            [questKeys.requiredMinRep] = false,
        },

        [10977] = {
            [questKeys.objectives] = {nil,nil,{{32069}}},
            [questKeys.requiredMinRep] = false,
        },

        [10978] = {
            [questKeys.objectives] = {nil,nil,{{32074}}},
        },

        [10980] = {
            [questKeys.objectives] = {{{22932}},nil,{{32244}}},
        },

        [10981] = {
            [questKeys.requiredMaxRep] = {933,42000},
            [questKeys.exclusiveTo] = {},
        },

        [10983] = {
            [questKeys.preQuestSingle] = {10984},
            [questKeys.exclusiveTo] = {10989},
        },

        [10984] = {
            [questKeys.exclusiveTo] = {},
        },

        [10985] = {
            [questKeys.exclusiveTo] = {},
        },

        [10987] = {
            [questKeys.objectives] = {nil,nil,{{32320},{32321}}},
        },

        [10988] = {
            [questKeys.objectives] = {nil,nil,{{32313},{32315}}},
        },

        [10989] = {
            [questKeys.exclusiveTo] = {10983},
        },

        [10990] = {
            [questKeys.objectives] = {nil,nil,{{32355},{32657}}},
        },

        [10991] = {
            [questKeys.objectives] = {nil,nil,{{32357},{32657}}},
        },

        [10992] = {
            [questKeys.objectives] = {nil,nil,{{32356},{32657}}},
        },

        [10993] = {
            [questKeys.objectives] = {nil,nil,{{32359}}},
        },

        [10995] = {
            [questKeys.preQuestSingle] = {},
        },

        [10996] = {
            [questKeys.preQuestSingle] = {},
        },

        [10997] = {
            [questKeys.preQuestSingle] = {},
        },

        [10998] = {
            [questKeys.preQuestSingle] = {10995,10996,10997},
        },

        [10999] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Bring me 8 trogg stone teeth."},
            [questKeys.objectives] = {nil,nil,{{2536}}},
            [questKeys.questFlags] = 4224,
            [questKeys.specialFlags] = 1,
        },

        [11000] = {
            [questKeys.objectives] = {nil,nil,{{32383},{32467}}},
        },

        [11002] = {
            [questKeys.objectives] = {nil,nil,{{32385}}},
        },

        [11003] = {
            [questKeys.objectives] = {nil,nil,{{32386}}},
        },

        [11005] = {
            [questKeys.objectivesText] = {"Obtain an Elixir of Shadows from Severin and use it to find and slay Talonpriest Ishaal, Talonpriest Skizzik and Talonpriest Zellek in Skettis.  Return to Commander Adaris after completing this task."},
        },

        [11007] = {
            [questKeys.objectives] = {nil,nil,{{32405}}},
        },

        [11008] = {
            [questKeys.objectivesText] = {"Seek out Monstrous Kaliri Eggs on the tops of Skettis dwellings and use the Skyguard Blasting Charges on them.  Return to Sky Sergeant Doryn."},
            [questKeys.objectives] = {{{22991}},nil,{{32406}}},
        },

        [11009] = {
            [questKeys.breadcrumbs] = {},
        },

        [11010] = {
            [questKeys.objectives] = {{{23118}},nil,{{32456}}},
            [questKeys.preQuestSingle] = {11030,11058},
            [questKeys.exclusiveTo] = {11102},
        },

        [11013] = {
            [questKeys.objectives] = {nil,nil,{{32469}}},
        },

        [11019] = {
            [questKeys.preQuestSingle] = {11014},
        },

        [11020] = {
            [questKeys.objectives] = {{{23209}},nil,{{32503}}},
            [questKeys.requiredSourceItems] = {32502},
        },

        [11021] = {
            [questKeys.objectives] = {nil,nil,{{32523}}},
            [questKeys.preQuestSingle] = {},
        },

        [11022] = {
            [questKeys.objectivesText] = {"Speak with Mog'dorg the Wizened.  He stands atop the tower on the east side of the Circle of Blood in the Blade's Edge Mountains."},
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [11023] = {
            [questKeys.objectives] = {{{23118}},nil,{{32456}}},
        },

        [11024] = {
            [questKeys.objectives] = {nil,nil,{{32564}}},
        },

        [11025] = {
            [questKeys.preQuestSingle] = {},
        },

        [11026] = {
            [questKeys.objectives] = {{{23327}},nil,{{32696}}},
            [questKeys.preQuestSingle] = {},
        },

        [11027] = {
            [questKeys.preQuestSingle] = {11060},
        },

        [11029] = {
            [questKeys.objectives] = {nil,nil,{{32742},{32741}}},
        },

        [11031] = {
            [questKeys.exclusiveTo] = {11032,11033,11034},
        },

        [11032] = {
            [questKeys.exclusiveTo] = {11031,11033,11034},
        },

        [11033] = {
            [questKeys.exclusiveTo] = {11031,11032,11034},
        },

        [11034] = {
            [questKeys.exclusiveTo] = {11031,11032,11033},
        },

        [11036] = {
            [questKeys.objectives] = {nil,nil,{{32619}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10186,
        },

        [11037] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10186,
        },

        [11038] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10241,
        },

        [11039] = {
            [questKeys.exclusiveTo] = {},
        },

        [11040] = {
            [questKeys.objectives] = {nil,nil,{{32623}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10186,
        },

        [11041] = {
            [questKeys.objectives] = {{{23264},{23269}},nil,{{32621}}},
        },

        [11042] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 10186,
        },

        [11043] = {
            [questKeys.exclusiveTo] = {},
        },

        [11044] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [11045] = {
            [questKeys.exclusiveTo] = {},
        },

        [11046] = {
            [questKeys.exclusiveTo] = {},
        },

        [11047] = {
            [questKeys.exclusiveTo] = {},
        },

        [11048] = {
            [questKeys.exclusiveTo] = {},
        },

        [11051] = {
            [questKeys.objectives] = {{{23327}},nil,{{32696}}},
        },

        [11052] = {
            [questKeys.objectives] = {nil,nil,{{32646}}},
            [questKeys.exclusiveTo] = {},
        },

        [11053] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11054] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11055] = {
            [questKeys.requiredRaces] = 1791,
            [questKeys.objectives] = {{{23311}},nil,{{32680}}},
            [questKeys.specialFlags] = 33,
        },

        [11057] = {
            [questKeys.exclusiveTo] = {},
        },

        [11058] = {
            [questKeys.objectives] = nil,
        },

        [11059] = {
            [questKeys.preQuestSingle] = {11025},
        },

        [11060] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 0,
        },

        [11064] = {
            [questKeys.objectives] = nil,
        },

        [11065] = {
            [questKeys.objectives] = {{{23343}},nil,{{32698}}},
            [questKeys.preQuestSingle] = {11025},
        },

        [11066] = {
            [questKeys.objectives] = {{{23343}},nil,{{32698}}},
        },

        [11067] = {
            [questKeys.objectives] = nil,
        },

        [11068] = {
            [questKeys.objectives] = nil,
        },

        [11069] = {
            [questKeys.objectives] = nil,
        },

        [11070] = {
            [questKeys.objectives] = nil,
        },

        [11071] = {
            [questKeys.objectives] = nil,
        },

        [11072] = {
            [questKeys.objectivesText] = {"Find the Skull Piles in the middle of the summoning circles of Skettis. Summon and defeat each of the descendants by using 10 Time-Lost Scrolls at the Skull Pile.  Return to Hazzik at Blackwind Landing with a token from each."},
            [questKeys.preQuestSingle] = {11029},
        },

        [11073] = {
            [questKeys.objectivesText] = {"Take the Time-Lost Offering prepared by Hazzik to the Skull Pile at the center of Skettis and summon and defeat Terokk.  Return to Sky Commander Adaris when you've completed this task."},
        },

        [11074] = {
            [questKeys.objectivesText] = {"Collect Time-Lost Scrolls from the time-lost arakkoa in Skettis and bring them to a Skull Pile inside a summoning circle in Skettis.  Summon and defeat the descendants of Terokk's adversaries and return to Hakkiz with Akkarai's Talon, Garokk's Spine, Vekkaz's Scale and Gezzarak's Claw."},
        },

        [11075] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11076] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11078] = {
            [questKeys.preQuestSingle] = {11010,11065},
        },

        [11080] = {
            [questKeys.objectives] = nil,
        },

        [11081] = {
            [questKeys.objectives] = {nil,nil,{{32726}}},
        },

        [11084] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11086] = {
            [questKeys.objectives] = {{{23393}}},
        },

        [11087] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Soridormi at Caverns of Time wants you to retrieve Vashj's Vial Remnant from Lady Vashj at Coilfang Reservoir and Kael's Vial Remnant from Kael'thas Sunstrider at Tempest Keep."},
            [questKeys.objectives] = {nil,nil,{{29906},{29905}}},
            [questKeys.questFlags] = 1224,
            [questKeys.specialFlags] = 2,
        },

        [11088] = {
            [questKeys.questLevel] = 70,
            [questKeys.objectivesText] = {"Bring Jonathan LeCraft 10 pieces of Spellfire cloth."},
            [questKeys.objectives] = {nil,nil,{{23855}}},
            [questKeys.questFlags] = 128,
        },

        [11090] = {
            [questKeys.objectives] = {nil,nil,{{32825}}},
        },

        [11092] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11093] = {
            [questKeys.objectivesText] = {"Use the Nether Ray Cage in the woods south of Blackwind Landing and slay Blackwind Warp Chasers near the Hungry Nether Ray.  Return to Skyguard Handler Deesak when you've completed your task."},
            [questKeys.objectives] = {{{23438}},nil,{{32834}}},
        },

        [11094] = {
            [questKeys.objectives] = {nil,nil,{{32842}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11092},
        },

        [11095] = {
            [questKeys.objectives] = {nil,nil,{{32842}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11094},
        },

        [11096] = {
            [questKeys.objectives] = {{{23450}}},
        },

        [11097] = {
            [questKeys.objectives] = {nil,nil,{{32843}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11095},
        },

        [11098] = {
            [questKeys.requiredRaces] = 1791,
            [questKeys.objectives] = {nil,nil,{{32848}}},
        },

        [11099] = {
            [questKeys.objectives] = {nil,nil,{{32842}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11092},
        },

        [11100] = {
            [questKeys.objectives] = {nil,nil,{{32842}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11099},
        },

        [11101] = {
            [questKeys.objectives] = {nil,nil,{{32853}}},
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {11100},
        },

        [11102] = {
            [questKeys.objectives] = {{{23118}},nil,{{32456}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {11010},
        },

        [11103] = {
            [questKeys.exclusiveTo] = {},
        },

        [11104] = {
            [questKeys.exclusiveTo] = {},
        },

        [11105] = {
            [questKeys.exclusiveTo] = {},
        },

        [11106] = {
            [questKeys.exclusiveTo] = {},
        },

        [11107] = {
            [questKeys.requiredRaces] = 1791,
        },

        [11115] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.questFlags] = 1152,
            [questKeys.specialFlags] = 2,
        },

        [11117] = {
            [questKeys.objectives] = {nil,nil,{{32906},{32907}}},
        },

        [11118] = {
            [questKeys.objectives] = {{{23528},{23507},{23527}},nil,{{32960}}},
        },

        [11119] = {
            [questKeys.preQuestSingle] = {},
        },

        [11120] = {
            [questKeys.objectives] = {{{23531},{23529},{23530}},nil,{{32960}}},
        },

        [11121] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Speak with <QUESTGIVER> in the <AREA>."},
            [questKeys.questFlags] = 4296,
            [questKeys.specialFlags] = 1,
        },

        [11122] = {
            [questKeys.objectivesText] = {"Get a keg from Flynn Firebrew in Kharanos and return it to Pol Amberstill.  Do this 3 times before your ram goes away."},
            [questKeys.objectives] = {{{24337}}},
        },

        [11123] = {
            [questKeys.preQuestSingle] = {1282,1302},
        },

        [11125] = {
            [questKeys.questLevel] = 40,
            [questKeys.requiredLevel] = 39,
            [questKeys.questFlags] = 8,
        },

        [11127] = {
            [questKeys.questLevel] = 20,
            [questKeys.requiredLevel] = 15,
            [questKeys.objectivesText] = {"Steal Grimbooze's Secret Recipe from Grimbooze's camp in Westfall and return to <NAME> Barleybrew in the Brewfest Grounds."},
            [questKeys.objectives] = {nil,nil,{{33007}}},
            [questKeys.questFlags] = 8,
        },

        [11130] = {
            [questKeys.objectives] = {nil,nil,{{33010}}},
        },

        [11131] = {
            [questKeys.objectivesText] = {"The Costumed Orphan Matron wants you to help put out all the village fires.  When they are out, speak again to the Costumed Orphan Matron."},
            [questKeys.requiredSourceItems] = {},
            [questKeys.exclusiveTo] = {12135},
        },

        [11133] = {
            [questKeys.objectives] = {{{4979}},nil,{{33015}}},
        },

        [11134] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [11137] = {
            [questKeys.preQuestSingle] = {11136},
        },

        [11138] = {
            [questKeys.objectives] = {nil,nil,{{33037}}},
        },

        [11140] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [11142] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 11222,
        },

        [11146] = {
            [questKeys.objectives] = {{{23727}},nil,{{33069}}},
        },

        [11150] = {
            [questKeys.objectives] = {{{23751},{23752},{23753}},nil,{{33072}}},
            [questKeys.specialFlags] = 32,
        },

        [11152] = {
            [questKeys.objectivesText] = {"Captain Garran Vimes at Foothold Citadel wants you to lay the Wreath at the Hyal Family Monument. "},
            [questKeys.objectives] = {{{23768}}},
            [questKeys.requiredSourceItems] = {33082},
        },

        [11153] = {
            [questKeys.objectivesText] = {"Take Petrov's Cluster Bombs and drop them on enough pirates to kill or destroy 25 Blockade Pirates and 10 Blockade Cannons.  Once you've accomplished that, return to Bombardier Petrov at Westguard Keep."},
            [questKeys.objectives] = {{{23755},{23771}}},
            [questKeys.requiredSourceItems] = {33098},
        },

        [11154] = {
            [questKeys.requiredSourceItems] = {33129},
        },

        [11156] = {
            [questKeys.objectives] = {{{23594}}},
        },

        [11157] = {
            [questKeys.objectives] = {{{23777},{23688}}},
            [questKeys.preQuestSingle] = {11501},
        },

        [11159] = {
            [questKeys.objectives] = {{{23786}},nil,{{33091}}},
            [questKeys.preQuestSingle] = {11160,11161},
        },

        [11161] = {
            [questKeys.objectives] = {nil,nil,{{33087},{33088}}},
        },

        [11162] = {
            [questKeys.objectives] = {{{23789}},nil,{{33095}}},
        },

        [11164] = {
            [questKeys.preQuestSingle] = {},
        },

        [11169] = {
            [questKeys.objectives] = {{{23811}},nil,{{33101}}},
        },

        [11170] = {
            [questKeys.objectivesText] = {"Speak to Bat Handler Camille and take a riding bat to intercept the Alliance reinforcements.  Once above their fleet, use the Plague Vials to infect 16 North Fleet reservists."},
            [questKeys.objectives] = {{{24121}}},
            [questKeys.requiredSourceItems] = {33349},
        },

        [11172] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [11174] = {
            [questKeys.objectives] = {{{23797}},nil,{{33108}}},
            [questKeys.preQuestSingle] = {11172},
            [questKeys.breadcrumbs] = {},
        },

        [11175] = {
            [questKeys.exclusiveTo] = {},
        },

        [11176] = {
            [questKeys.preQuestSingle] = {11240},
        },

        [11177] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 1218,
        },

        [11178] = {
            [questKeys.objectives] = {nil,nil,{{33102}}},
        },

        [11180] = {
            [questKeys.objectives] = {{{23861}}},
        },

        [11182] = {
            [questKeys.objectivesText] = {"Slay 5 Dragonflayer Handlers and Skeld Drakeson.  If you manage to do so, return to an Ember Clutch Ancient in the Ember Clutch."},
        },

        [11183] = {
            [questKeys.objectives] = {{{23864}},nil,{{33113}}},
        },

        [11185] = {
            [questKeys.objectives] = {nil,nil,{{33114}}},
        },

        [11186] = {
            [questKeys.objectives] = {nil,nil,{{33115}}},
            [questKeys.questFlags] = 0,
        },

        [11188] = {
            [questKeys.requiredSourceItems] = {33119},
        },

        [11189] = {
            [questKeys.specialFlags] = 0,
        },

        [11193] = {
            [questKeys.objectives] = {nil,nil,{{33127}}},
            [questKeys.questFlags] = 0,
        },

        [11195] = {
            [questKeys.objectives] = {nil,nil,{{33107}}},
        },

        [11197] = {
            [questKeys.questFlags] = 1032,
        },

        [11198] = {
            [questKeys.objectives] = nil,
        },

        [11202] = {
            [questKeys.requiredSourceItems] = {33164},
        },

        [11203] = {
            [questKeys.preQuestSingle] = {11201},
        },

        [11204] = {
            [questKeys.preQuestSingle] = {1273,1276},
        },

        [11205] = {
            [questKeys.objectives] = {{{23751},{23752},{23753}},nil,{{33072}}},
            [questKeys.specialFlags] = 32,
        },

        [11208] = {
            [questKeys.objectives] = {nil,nil,{{33163}}},
            [questKeys.exclusiveTo] = {},
        },

        [11209] = {
            [questKeys.objectives] = {{{23928}},nil,{{33166}}},
        },

        [11211] = {
            [questKeys.exclusiveTo] = {},
        },

        [11214] = {
            [questKeys.exclusiveTo] = {},
        },

        [11215] = {
            [questKeys.exclusiveTo] = {},
        },

        [11216] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [11218] = {
            [questKeys.requiredSourceItems] = {33190},
        },

        [11219] = {
            [questKeys.objectivesText] = {"The Masked Orphan Matron wants you to help put out all the village fires.  When they are out, speak again to the Masked Orphan Matron in town."},
            [questKeys.requiredSourceItems] = {},
            [questKeys.exclusiveTo] = {12139},
        },

        [11221] = {
            [questKeys.objectivesText] = {"Speak to Dark Ranger Lyana and Deathstalker Razael in the battlefield at the Bleeding Vale south of Vengeance Landing.  Return to High Executor Anselm when you've completed this task."},
        },

        [11222] = {
            [questKeys.objectivesText] = {"Speak to Highlord Bolvar Fordragon in Stormwind Keep."},
            [questKeys.preQuestSingle] = {11142},
        },

        [11223] = {
            [questKeys.preQuestSingle] = {11222},
        },

        [11225] = {
            [questKeys.breadcrumbForQuestId] = 1218,
        },

        [11226] = {
            [questKeys.questFlags] = 1032,
            [questKeys.specialFlags] = 2,
        },

        [11227] = {
            [questKeys.requiredSourceItems] = {33221,33238},
        },

        [11229] = {
            [questKeys.objectivesText] = {"Speak to Bat Handler Camille at Vengeance Landing and obtain passage to the Windrunner.  Report to Captain Harker aboard the ship."},
        },

        [11232] = {
            [questKeys.objectivesText] = {"Use the Smoke Flares at the location of the Alliance Cannons on the northern wall of the Derelict Strand.  Report to Dark Ranger Lyana at the Bleeding Vale after you've completed this task."},
            [questKeys.requiredSourceItems] = {33335},
            [questKeys.specialFlags] = 32,
        },

        [11237] = {
            [questKeys.objectives] = {nil,nil,{{33289}}},
            [questKeys.preQuestSingle] = {11250},
        },

        [11238] = {
            [questKeys.sourceItemId] = 0,
        },

        [11241] = {
            [questKeys.objectivesText] = {"Escort Apothecary Hanes out of the Derelict Strand.  Report to Apothecary Lysander at Vengeance Landing in Howling Fjord when you've completed this task."},
        },

        [11242] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{33277}}},
            [questKeys.preQuestSingle] = {},
        },

        [11243] = {
            [questKeys.objectives] = {{{24051}}},
        },

        [11245] = {
            [questKeys.requiredSourceItems] = {33323},
            [questKeys.specialFlags] = 32,
        },

        [11246] = {
            [questKeys.objectives] = {{{24095}}},
            [questKeys.requiredSourceItems] = {33310},
        },

        [11247] = {
            [questKeys.requiredSourceItems] = {33321},
            [questKeys.specialFlags] = 32,
        },

        [11249] = {
            [questKeys.objectives] = {{{23671}},nil,{{33339}}},
        },

        [11250] = {
            [questKeys.preQuestSingle] = {11245,11246,11247},
        },

        [11251] = {
            [questKeys.preQuestSingle] = {11244},
        },

        [11252] = {
            [questKeys.objectivesText] = {"Defender Mordun has tasked you with the execution of Ingvar the Plunderer who resides deep in Utgarde.$b$bYou are then to bring his head to Vice Admiral Keller."},
            [questKeys.preQuestSingle] = {11244},
        },

        [11253] = {
            [questKeys.requiredSourceItems] = {33486},
        },

        [11254] = {
            [questKeys.objectives] = {nil,nil,{{33411}}},
        },

        [11255] = {
            [questKeys.objectives] = {{{24124}}},
        },

        [11257] = {
            [questKeys.objectives] = {{{24095}}},
            [questKeys.requiredSourceItems] = {33342},
            [questKeys.nextQuestInChain] = 11261,
        },

        [11258] = {
            [questKeys.requiredSourceItems] = {33343},
            [questKeys.nextQuestInChain] = 11261,
            [questKeys.specialFlags] = 32,
        },

        [11259] = {
            [questKeys.requiredSourceItems] = {33344},
            [questKeys.nextQuestInChain] = 11261,
            [questKeys.specialFlags] = 32,
        },

        [11260] = {
            [questKeys.objectives] = {{{23671}},nil,{{33346}}},
        },

        [11261] = {
            [questKeys.preQuestSingle] = {11257,11258,11259},
        },

        [11265] = {
            [questKeys.preQuestSingle] = {11260},
        },

        [11266] = {
            [questKeys.objectives] = {nil,nil,{{33347}}},
            [questKeys.preQuestSingle] = {11261},
        },

        [11267] = {
            [questKeys.sourceItemId] = 0,
        },

        [11269] = {
            [questKeys.preQuestSingle] = {11250},
        },

        [11270] = {
            [questKeys.objectives] = {{{24008}}},
            [questKeys.requiredSourceItems] = {33278},
        },

        [11278] = {
            [questKeys.objectives] = {nil,nil,{{33387}}},
        },

        [11279] = {
            [questKeys.requiredSourceItems] = {33418},
        },

        [11280] = {
            [questKeys.requiredSourceItems] = {33441},
        },

        [11281] = {
            [questKeys.requiredSourceItems] = {33450},
        },

        [11282] = {
            [questKeys.objectivesText] = {"Gorth wants you to kill Ulf the Bloodletter, Oric the Baleful and Gunnar Thorvardsson and drive the Forsaken Banner through their corpses.  Slay Vrykul across the Forsaken blockade until they appear."},
            [questKeys.objectives] = {{{24166},{24165},{24167}}},
            [questKeys.requiredSourceItems] = {33563},
        },

        [11283] = {
            [questKeys.objectives] = {{{24231}}},
        },

        [11285] = {
            [questKeys.requiredSourceItems] = {33472},
            [questKeys.specialFlags] = 32,
        },

        [11286] = {
            [questKeys.breadcrumbs] = {11287},
        },

        [11287] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 11286,
        },

        [11289] = {
            [questKeys.objectives] = {nil,nil,{{33485}}},
        },

        [11291] = {
            [questKeys.objectives] = {nil,nil,{{33488}}},
        },

        [11292] = {
            [questKeys.preQuestSingle] = {11406},
        },

        [11297] = {
            [questKeys.preQuestSingle] = {11311},
        },

        [11301] = {
            [questKeys.requiredSourceItems] = {33554},
        },

        [11302] = {
            [questKeys.exclusiveTo] = {11312},
        },

        [11303] = {
            [questKeys.preQuestSingle] = {11283,11285},
        },

        [11304] = {
            [questKeys.objectives] = {nil,nil,{{33619}}},
        },

        [11307] = {
            [questKeys.objectivesText] = {"Venture into Halgrind and use the Plague Spray on 10 Plagued Dragonflayer Vrykul.  Return to Chief Plaguebringer Harris to report the results."},
            [questKeys.objectives] = {{{24281}}},
            [questKeys.requiredSourceItems] = {33621},
        },

        [11310] = {
            [questKeys.objectivesText] = {"Use the Abomination Assembly Kit in Halgrind and round up plagued Vrykul with your Mindless Abomination.  Slay at least 20 and return to \"Hacksaw\" Jenny in New Agamand when you're done."},
            [questKeys.objectives] = {{{24274}}},
            [questKeys.requiredSourceItems] = {33613},
        },

        [11311] = {
            [questKeys.objectives] = {{{24228}}},
        },

        [11312] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {11302},
        },

        [11313] = {
            [questKeys.preQuestSingle] = {11302,11312},
        },

        [11314] = {
            [questKeys.objectives] = {{{24117}}},
            [questKeys.requiredSourceItems] = {33606},
        },

        [11318] = {
            [questKeys.objectives] = {{{24263},{24264},{24265}}},
        },

        [11319] = {
            [questKeys.objectives] = {{{24235}}},
            [questKeys.requiredSourceItems] = {33607},
        },

        [11320] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 2,
            [questKeys.objectivesText] = {"Log Descritpion "},
            [questKeys.objectives] = {{{24263},{24264},{24265}}},
            [questKeys.sourceItemId] = 33306,
        },

        [11321] = {
            [questKeys.objectives] = {nil,nil,{{33955}}},
            [questKeys.preQuestSingle] = {11318},
        },

        [11328] = {
            [questKeys.objectives] = {nil,nil,{{33620}}},
        },

        [11329] = {
            [questKeys.preQuestSingle] = {11250},
        },

        [11330] = {
            [questKeys.requiredSourceItems] = {33627},
            [questKeys.specialFlags] = 32,
        },

        [11332] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.specialFlags] = 32,
        },

        [11334] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Rinling wants you to shoot a marked target and then return the Target Rifle to him."},
            [questKeys.objectives] = {nil,nil,{{33442}}},
            [questKeys.sourceItemId] = 33442,
            [questKeys.questFlags] = 10,
            [questKeys.specialFlags] = 2,
        },

        [11335] = {
            [questKeys.requiredLevel] = 61,
            [questKeys.questFlags] = 4098,
        },

        [11336] = {
            [questKeys.requiredLevel] = 61,
        },

        [11337] = {
            [questKeys.requiredLevel] = 61,
        },

        [11338] = {
            [questKeys.requiredLevel] = 61,
        },

        [11339] = {
            [questKeys.requiredLevel] = 61,
        },

        [11340] = {
            [questKeys.requiredLevel] = 61,
        },

        [11341] = {
            [questKeys.requiredLevel] = 61,
            [questKeys.objectivesText] = {"Win an Eye of the Storm battleground match and return to a Horde Warbringer at any Horde capital city, Wintergrasp, Dalaran,  or Shattrath."},
        },

        [11342] = {
            [questKeys.requiredLevel] = 61,
        },

        [11343] = {
            [questKeys.requiredSourceItems] = {33637},
        },

        [11344] = {
            [questKeys.requiredSourceItems] = {33774},
        },

        [11345] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Rinling wants you to shoot a marked target and then return the Target Rifle to him."},
            [questKeys.objectives] = {nil,nil,{{33442}}},
            [questKeys.sourceItemId] = 33442,
            [questKeys.questFlags] = 10,
            [questKeys.specialFlags] = 2,
        },

        [11347] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Deliver the package to Kharanos at least once.  Deliver multiple packages for a greater reward."},
            [questKeys.objectives] = {nil,nil,{{33797}}},
            [questKeys.sourceItemId] = 33306,
        },

        [11348] = {
            [questKeys.objectives] = {{{24345},{24334}}},
            [questKeys.requiredSourceItems] = {33796},
        },

        [11352] = {
            [questKeys.objectives] = {{{24345},{24334}}},
            [questKeys.requiredSourceItems] = {33796},
        },

        [11353] = {
            [questKeys.questFlags] = 5128,
            [questKeys.specialFlags] = 1,
        },

        [11355] = {
            [questKeys.objectives] = {{{27802}}},
            [questKeys.requiredSourceItems] = {33806},
        },

        [11356] = {
            [questKeys.exclusiveTo] = {},
        },

        [11357] = {
            [questKeys.exclusiveTo] = {},
        },

        [11358] = {
            [questKeys.requiredSourceItems] = {33819},
        },

        [11360] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11361] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11365] = {
            [questKeys.objectives] = {{{27802}}},
            [questKeys.requiredSourceItems] = {33806},
        },

        [11366] = {
            [questKeys.requiredSourceItems] = {33819},
        },

        [11377] = {
            [questKeys.objectivesText] = {"The Rokk in Lower City has asked you to cook up some Kaliri Stew using his cooking pot.  Return to him when it's done."},
        },

        [11379] = {
            [questKeys.objectivesText] = {"The Rokk in Lower City has asked you to cook up some Demon Broiled Surprise using his cooking pot, two Mok'Nathal Shortribs and a Crunchy Serpent.  Return to him when it's done."},
        },

        [11381] = {
            [questKeys.objectivesText] = {"The Rokk in Lower City has asked you to cook up some Spiritual Soup using his cooking pot.  Return to him when it's done."},
        },

        [11392] = {
            [questKeys.objectives] = {nil,nil,{{33985}}},
        },

        [11393] = {
            [questKeys.exclusiveTo] = {},
        },

        [11394] = {
            [questKeys.objectives] = {{{23645}}},
        },

        [11395] = {
            [questKeys.objectives] = {nil,nil,{{33961}}},
            [questKeys.questFlags] = 128,
        },

        [11396] = {
            [questKeys.requiredSourceItems] = {33960},
        },

        [11397] = {
            [questKeys.objectives] = {{{23645}}},
        },

        [11398] = {
            [questKeys.objectives] = {nil,nil,{{33962}}},
        },

        [11399] = {
            [questKeys.requiredSourceItems] = {33960},
        },

        [11400] = {
            [questKeys.objectives] = {nil,nil,{{33978}}},
        },

        [11401] = {
            [questKeys.objectives] = {nil,nil,{{33985}}},
        },

        [11403] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{33277}}},
            [questKeys.preQuestSingle] = {},
        },

        [11404] = {
            [questKeys.objectives] = {nil,nil,{{33985}}},
        },

        [11405] = {
            [questKeys.objectives] = {nil,nil,{{33985}}},
        },

        [11406] = {
            [questKeys.preQuestSingle] = {11250},
        },

        [11409] = {
            [questKeys.objectives] = {{{24263},{24264},{24265}}},
        },

        [11410] = {
            [questKeys.requiredSourceItems] = {34013},
        },

        [11412] = {
            [questKeys.objectivesText] = {"Get a keg from the Goblin stranded on the road to Razor Hill and return it to Ram Master Ray's assistant.  Do this 3 times before your ram goes away."},
            [questKeys.objectives] = {{{24337}}},
        },

        [11413] = {
            [questKeys.objectives] = {nil,nil,{{33955}}},
            [questKeys.preQuestSingle] = {11409},
        },

        [11414] = {
            [questKeys.sourceItemId] = 0,
        },

        [11415] = {
            [questKeys.sourceItemId] = 0,
        },

        [11416] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11417] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11418] = {
            [questKeys.requiredSourceItems] = {34026},
        },

        [11419] = {
            [questKeys.objectives] = {nil,nil,{{34028}}},
        },

        [11421] = {
            [questKeys.objectives] = {{{24533},{24538},{24646},{24647}},nil,{{34032}}},
            [questKeys.specialFlags] = 32,
        },

        [11427] = {
            [questKeys.objectives] = {nil,nil,{{34032}}},
        },

        [11429] = {
            [questKeys.objectives] = {{{24641}},nil,{{34051}}},
        },

        [11431] = {
            [questKeys.objectives] = {nil,nil,{{32906},{32907}}},
        },

        [11432] = {
            [questKeys.preQuestSingle] = {11239},
        },

        [11435] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Take the bunch of jack-o'-lanterns to the Costumed Orphan Matron."},
            [questKeys.objectives] = {nil,nil,{{34071}}},
            [questKeys.sourceItemId] = 34071,
            [questKeys.questFlags] = 4104,
            [questKeys.specialFlags] = 1,
        },

        [11437] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Speak to a Brewfest Barker in any Beer Garden and receive a free pretzel."},
            [questKeys.questFlags] = 8,
        },

        [11438] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Speak to a Brewfest Barker in any Beer Garden and receive a free pretzel."},
            [questKeys.questFlags] = 8,
        },

        [11439] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11440] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11442] = {
            [questKeys.objectivesText] = {"[PH] Speak to the Brewfest Organizer and receive a free beer."},
        },

        [11443] = {
            [questKeys.requiredSourceItems] = {34082},
        },

        [11444] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Speak to a Brewfest Barker in any Beer Garden and receive a free pretzel."},
            [questKeys.questFlags] = 8,
        },

        [11445] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"[PH] Speak to a Brewfest Barker in any Beer Garden and receive a free pretzel."},
            [questKeys.questFlags] = 8,
        },

        [11447] = {
            [questKeys.objectivesText] = {"[PH] Speak to the Brewfest Organizer and receive a free beer."},
        },

        [11448] = {
            [questKeys.objectives] = {nil,nil,{{34088}}},
        },

        [11449] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11450] = {
            [questKeys.requiredSourceItems] = {},
        },

        [11451] = {
            [questKeys.objectives] = {nil,nil,{{34089}}},
        },

        [11452] = {
            [questKeys.requiredSourceItems] = {34090},
        },

        [11453] = {
            [questKeys.requiredSourceItems] = {34091},
        },

        [11458] = {
            [questKeys.objectivesText] = {"Elder Atuik wants you to go to Iskaal and slay 8 Northsea Slavers.  Use the Horn of Kamagua should you need assistance."},
            [questKeys.requiredSourceItems] = {36777},
        },

        [11460] = {
            [questKeys.objectives] = nil,
        },

        [11462] = {
            [questKeys.questLevel] = 71,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Don the Pirate Disguise and speak to Handsome Terry inside Scalawag point."},
            [questKeys.sourceItemId] = 34108,
            [questKeys.nextQuestInChain] = 11434,
            [questKeys.questFlags] = 128,
        },

        [11463] = {
            [questKeys.questLevel] = 71,
            [questKeys.requiredLevel] = 69,
            [questKeys.objectivesText] = {"Find Grezzix Spindlesnap on the northern end of Garvan's Reef off of the Southwestern coast of Howling Fjord."},
            [questKeys.nextQuestInChain] = 11462,
            [questKeys.questFlags] = 136,
        },

        [11465] = {
            [questKeys.objectives] = {nil,nil,{{34112},{34111}}},
        },

        [11466] = {
            [questKeys.requiredSourceItems] = {34117},
        },

        [11468] = {
            [questKeys.objectives] = {nil,nil,{{34120},{34121}}},
        },

        [11470] = {
            [questKeys.objectives] = {nil,nil,{{34123},{34124}}},
        },

        [11472] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {34127,40946},
        },

        [11475] = {
            [questKeys.preQuestSingle] = {11474},
        },

        [11476] = {
            [questKeys.objectivesText] = {"Get a Shiny Knife from \"Silvermoon\" Harry and capture a Scalawag Frog.  Bring these to Zeh'Gehn at Scalawag Point."},
        },

        [11478] = {
            [questKeys.objectives] = {nil,nil,{{34132}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.questFlags] = 128,
        },

        [11481] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [11482] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [11485] = {
            [questKeys.preQuestSingle] = {11483,11484},
        },

        [11486] = {
            [questKeys.objectives] = {nil,nil,{{34141}}},
        },

        [11487] = {
            [questKeys.objectives] = {nil,nil,{{34141}}},
        },

        [11490] = {
            [questKeys.objectives] = {{{25042}}},
        },

        [11491] = {
            [questKeys.objectives] = nil,
        },

        [11493] = {
            [questKeys.questFlags] = 136,
        },

        [11495] = {
            [questKeys.objectives] = nil,
        },

        [11496] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 138,
            [questKeys.specialFlags] = 34,
        },

        [11501] = {
            [questKeys.preQuestSingle] = {11494,11495},
        },

        [11502] = {
            [questKeys.requiredMinRep] = false,
        },

        [11503] = {
            [questKeys.requiredMinRep] = false,
        },

        [11507] = {
            [questKeys.objectives] = {nil,nil,{{34226}}},
        },

        [11513] = {
            [questKeys.preQuestSingle] = {11517},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11514] = {
            [questKeys.preQuestSingle] = {11513},
        },

        [11515] = {
            [questKeys.objectivesText] = {"Magistrix Seyla at the Throne of Kil'jaeden wants you to kill 4 Emaciated Felbloods by using the Fel Siphon on them.  You will need Demonic Blood from nearby Wrath Heralds to power the Fel Siphon."},
            [questKeys.objectives] = {{{24955}},nil,{{34257}}},
            [questKeys.specialFlags] = 33,
        },

        [11516] = {
            [questKeys.objectivesText] = {"Magistrix Seyla at the Throne of Kil'jaeden wants you to use the Sizzling Embers to summon a Living Flare and slay Incandescent Fel Sparks near it until it becomes an Unstable Living Flare.  Return to the Legion Gateway with the Unstable Living Flare to destroy it."},
            [questKeys.objectives] = {nil,nil,{{34253}}},
        },

        [11517] = {
            [questKeys.exclusiveTo] = {},
        },

        [11520] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11521] = {
            [questKeys.preQuestSingle] = {11520},
        },

        [11522] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectives] = {nil,nil,{{34254}}},
            [questKeys.questFlags] = 136,
        },

        [11523] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {11496},
            [questKeys.specialFlags] = 35,
        },

        [11524] = {
            [questKeys.objectives] = {{{24991}},nil,{{34368}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 0,
        },

        [11525] = {
            [questKeys.objectives] = {{{24991}},nil,{{34368}}},
            [questKeys.preQuestSingle] = {11524},
        },

        [11526] = {
            [questKeys.objectivesText] = {"Use the Captured Legion Scroll near the portal at Dawning Square.  Once you've gone through the portal, find Magistrix Seyla."},
            [questKeys.objectives] = {nil,nil,{{34420}}},
            [questKeys.preQuestSingle] = {11550},
        },

        [11528] = {
            [questKeys.exclusiveTo] = {},
        },

        [11530] = {
            [questKeys.objectives] = {nil,nil,{{34238}}},
        },

        [11531] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{34474}}},
        },

        [11532] = {
            [questKeys.objectivesText] = {"Battlemage Arynna wants you to speak to Ayren Cloudbreaker when you're ready to fly over the Dead Scar.  Once there, use the Arcane Charges to kill 2 Pit Overlords, 3 Eredar Sorcerers and 12 Wrath Enforcers."},
            [questKeys.objectives] = {{{25031},{25033},{25030}},nil,{{34475}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 0,
        },

        [11533] = {
            [questKeys.objectivesText] = {"Battlemage Arynna wants you to speak to Ayren Cloudbreaker when you're ready to fly over the Dead Scar.  Once there, use the Arcane Charges to kill 2 Pit Overlords, 3 Eredar Sorcerers and 12 Wrath Enforcers."},
            [questKeys.objectives] = {{{25031},{25033},{25030}},nil,{{34475}}},
            [questKeys.preQuestSingle] = {11532},
        },

        [11534] = {
            [questKeys.exclusiveTo] = {},
        },

        [11535] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11536] = {
            [questKeys.preQuestSingle] = {11544},
        },

        [11537] = {
            [questKeys.objectivesText] = {"Harbinger Inuuro wants you to slay 6 Burning Legion Demons and the Emissary of Hate in Dawning Square.  Use the Shattered Sun Banner to impale the Emissary of Hate's corpse."},
            [questKeys.objectives] = {{{25065},{25068}},nil,{{34414}}},
            [questKeys.preQuestSingle] = {11538},
        },

        [11538] = {
            [questKeys.objectivesText] = {"Harbinger Inuuro wants you to slay 6 Burning Legion Demons and the Emissary of Hate in Dawning Square or the Sun's Reach Armory.  Use the Shattered Sun Banner to impale the Emissary of Hate's corpse."},
            [questKeys.objectives] = {{{25065},{25068}},nil,{{34414}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 0,
        },

        [11539] = {
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11540] = {
            [questKeys.preQuestSingle] = {11539},
        },

        [11541] = {
            [questKeys.objectives] = {{{25086}}},
            [questKeys.preQuestSingle] = {11520},
        },

        [11542] = {
            [questKeys.objectivesText] = {"Vindicator Kaalan at the Sun's Reach Armory wants you to speak to Ayren Cloudbreaker and fly over the Dawnblade reinforcement fleet.  Use the Flaming Oil to set the ship sails on fire as you fly and once you land, slay 6 Dawnblade Reservists."},
            [questKeys.objectives] = {{{25090},{25091},{25092},{25087}},nil,{{34489}}},
            [questKeys.questFlags] = 128,
            [questKeys.specialFlags] = 32,
        },

        [11543] = {
            [questKeys.objectivesText] = {"Vindicator Kaalan at the Sun's Reach Armory wants you to speak to Ayren Cloudbreaker and fly over the Dawnblade reinforcement fleet.  Use the Flaming Oil to set the ship sails on fire as you fly and once you land, slay 6 Dawnblade Reservists."},
            [questKeys.objectives] = {{{25090},{25091},{25092},{25087}},nil,{{34489}}},
            [questKeys.preQuestSingle] = {11542},
            [questKeys.specialFlags] = 33,
        },

        [11544] = {
            [questKeys.preQuestSingle] = {11535},
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11545] = {
            [questKeys.requiredMaxRep] = false,
            [questKeys.questFlags] = 136,
            [questKeys.specialFlags] = 0,
        },

        [11546] = {
            [questKeys.preQuestSingle] = {11521},
        },

        [11547] = {
            [questKeys.objectives] = {{{25156},{25154},{25157}},nil,{{34533}}},
            [questKeys.preQuestSingle] = {11513},
            [questKeys.specialFlags] = 33,
        },

        [11548] = {
            [questKeys.preQuestSingle] = {11545},
        },

        [11549] = {
            [questKeys.objectivesText] = {"Anchorite Kairthos wants you to donate 1000 gold to aid in Anchorite Ayuri's efforts.  You will be known as $N of the Shattered Sun if you complete this quest."},
        },

        [11551] = {
            [questKeys.objectivesText] = {},
            [questKeys.specialFlags] = 0,
        },

        [11552] = {
            [questKeys.objectivesText] = {},
            [questKeys.specialFlags] = 0,
        },

        [11553] = {
            [questKeys.objectivesText] = {},
            [questKeys.specialFlags] = 0,
        },

        [11558] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.requiredSourceItems] = {},
        },

        [11561] = {
            [questKeys.objectives] = {{{25217}}},
        },

        [11564] = {
            [questKeys.preQuestSingle] = {},
        },

        [11565] = {
            [questKeys.objectives] = {nil,nil,{{34619}}},
        },

        [11566] = {
            [questKeys.requiredSourceItems] = {34620},
        },

        [11568] = {
            [questKeys.requiredSourceItems] = {34624},
            [questKeys.preQuestSingle] = {11511,11512,11530,11567},
            [questKeys.specialFlags] = 32,
        },

        [11569] = {
            [questKeys.preQuestSingle] = {},
        },

        [11571] = {
            [questKeys.nextQuestInChain] = 11559,
        },

        [11574] = {
            [questKeys.preQuestSingle] = {11598},
            [questKeys.exclusiveTo] = {},
        },

        [11575] = {
            [questKeys.exclusiveTo] = {},
        },

        [11576] = {
            [questKeys.requiredSourceItems] = {34669},
            [questKeys.specialFlags] = 32,
        },

        [11582] = {
            [questKeys.requiredSourceItems] = {34669},
            [questKeys.specialFlags] = 32,
        },

        [11585] = {
            [questKeys.exclusiveTo] = {11586},
        },

        [11586] = {
            [questKeys.preQuestSingle] = {},
        },

        [11587] = {
            [questKeys.objectives] = {{{25318}}},
            [questKeys.preQuestSingle] = {11574,11575},
        },

        [11588] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 65,
            [questKeys.objectivesText] = {"Destroy the elemental Ahune within Blackfathom Deeps."},
            [questKeys.questFlags] = 8,
        },

        [11589] = {
            [questKeys.questLevel] = 70,
            [questKeys.requiredLevel] = 65,
            [questKeys.objectivesText] = {"Destroy the elemental Ahune within Blackfathom Deeps."},
            [questKeys.questFlags] = 8,
        },

        [11590] = {
            [questKeys.objectives] = {{{25474}}},
            [questKeys.requiredSourceItems] = {34691},
        },

        [11591] = {
            [questKeys.exclusiveTo] = {},
        },

        [11593] = {
            [questKeys.objectives] = {{{25342}}},
            [questKeys.requiredSourceItems] = {34692},
        },

        [11594] = {
            [questKeys.objectives] = {{{25351}}},
        },

        [11595] = {
            [questKeys.exclusiveTo] = {11596,11597},
        },

        [11596] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {11595,11597},
        },

        [11598] = {
            [questKeys.objectives] = {{{25382}}},
        },

        [11600] = {
            [questKeys.objectives] = {nil,nil,{{34695}}},
        },

        [11603] = {
            [questKeys.questFlags] = 136,
        },

        [11606] = {
            [questKeys.preQuestSingle] = {},
        },

        [11608] = {
            [questKeys.requiredSourceItems] = {34710},
        },

        [11610] = {
            [questKeys.objectives] = {{{25397},{25398},{25399}}},
            [questKeys.requiredSourceItems] = {34715},
            [questKeys.specialFlags] = 32,
        },

        [11611] = {
            [questKeys.objectives] = {{{25270}}},
            [questKeys.preQuestSingle] = {},
        },

        [11613] = {
            [questKeys.preQuestSingle] = {11662,12141},
        },

        [11615] = {
            [questKeys.objectives] = {nil,nil,{{34719}}},
            [questKeys.questFlags] = 128,
        },

        [11616] = {
            [questKeys.objectives] = {nil,nil,{{34720}}},
        },

        [11617] = {
            [questKeys.specialFlags] = 32,
        },

        [11625] = {
            [questKeys.objectivesText] = {"Veehja in Riplash wants you to go to the far northeastern end of the Riplash Ruins.  Once there slay Ragnar Drakkarlund and obtain the Trident of Naz'jan from him."},
        },

        [11626] = {
            [questKeys.objectivesText] = {"Find Leviroth in the waters below the iceberg floating among the northern edge of Riplash Ruins.  Use the Trident of Naz'jan to slay him and return to Karuk to the north of Riplash Strand."},
            [questKeys.requiredSourceItems] = {35850},
        },

        [11627] = {
            [questKeys.objectivesText] = {"Imperean wants you to beat Simmer and Churn into submission.  Return to her at the Ruins of Eldra'nath when they have submitted."},
        },

        [11629] = {
            [questKeys.objectives] = {nil,nil,{{34778}}},
        },

        [11631] = {
            [questKeys.requiredSourceItems] = {34779},
        },

        [11632] = {
            [questKeys.objectives] = {nil,nil,{{34777}}},
        },

        [11633] = {
            [questKeys.requiredSourceItems] = {34782},
        },

        [11636] = {
            [questKeys.specialFlags] = 2,
        },

        [11637] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.specialFlags] = 32,
        },

        [11647] = {
            [questKeys.requiredSourceItems] = {34806},
        },

        [11648] = {
            [questKeys.requiredSourceItems] = {34811},
        },

        [11650] = {
            [questKeys.requiredSourceItems] = {34801},
        },

        [11651] = {
            [questKeys.preQuestSingle] = {11643,11644},
        },

        [11652] = {
            [questKeys.objectives] = {{{25495},{27109}}},
        },

        [11653] = {
            [questKeys.objectives] = {{{25505}}},
            [questKeys.requiredSourceItems] = {34812},
        },

        [11654] = {
            [questKeys.objectives] = {nil,nil,{{34815}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.questFlags] = 128,
        },

        [11656] = {
            [questKeys.objectives] = {{{25510},{25511},{25512},{25513}}},
            [questKeys.requiredSourceItems] = {34830},
            [questKeys.specialFlags] = 32,
        },

        [11661] = {
            [questKeys.requiredSourceItems] = {34844},
        },

        [11665] = {
            [questKeys.objectivesText] = {"Bring a Baby Crocolisk to Old Man Barlo.  You can find him fishing northeast of Shattrath City by Silmyr Lake."},
        },

        [11666] = {
            [questKeys.objectivesText] = {"Bring a Blackfin Darter to Old Man Barlo.  You can find him fishing northeast of Shattrath City by Silmyr Lake."},
        },

        [11667] = {
            [questKeys.objectivesText] = {"Catch the World's Largest Mudfish and bring it to Old Man Barlo.  You can find him fishing northeast of Shattrath City by Silmyr Lake."},
        },

        [11668] = {
            [questKeys.objectivesText] = {"Bring 10 Giant Freshwater Shrimp to Old Man Barlo.  You can find him fishing northeast of Shattrath City by Silmyr Lake."},
        },

        [11669] = {
            [questKeys.objectivesText] = {"Bring a Monstrous Felblood Snapper to Old Man Barlo.  You can find him fishing northeast of Shattrath City by Silmyr Lake."},
        },

        [11670] = {
            [questKeys.objectives] = {{{25581}},nil,{{34870}}},
            [questKeys.requiredSourceItems] = {},
        },

        [11671] = {
            [questKeys.requiredSourceItems] = {34897},
        },

        [11675] = {
            [questKeys.objectives] = {{{25615}}},
        },

        [11677] = {
            [questKeys.objectives] = {{{25654}}},
            [questKeys.requiredSourceItems] = {34913},
            [questKeys.specialFlags] = 32,
        },

        [11679] = {
            [questKeys.objectives] = {nil,nil,{{34909}}},
        },

        [11680] = {
            [questKeys.requiredSourceItems] = {34948},
        },

        [11683] = {
            [questKeys.objectives] = {{{25660}}},
        },

        [11684] = {
            [questKeys.objectives] = {{{25664},{25665},{25666}},nil,{{34920}}},
            [questKeys.specialFlags] = 32,
        },

        [11686] = {
            [questKeys.objectives] = {{{25669},{25671},{25672}}},
        },

        [11688] = {
            [questKeys.preQuestSingle] = {11618},
        },

        [11690] = {
            [questKeys.objectives] = {{{25698}}},
            [questKeys.requiredSourceItems] = {34954},
        },

        [11691] = {
            [questKeys.questFlags] = 5120,
            [questKeys.specialFlags] = 3,
        },

        [11693] = {
            [questKeys.objectives] = {{{25615}}},
        },

        [11694] = {
            [questKeys.objectives] = {{{25654}}},
            [questKeys.requiredSourceItems] = {34915},
            [questKeys.specialFlags] = 32,
        },

        [11696] = {
            [questKeys.preQuestSingle] = {11955},
        },

        [11698] = {
            [questKeys.objectives] = {{{25660}}},
        },

        [11704] = {
            [questKeys.preQuestSingle] = {},
        },

        [11705] = {
            [questKeys.objectives] = nil,
        },

        [11706] = {
            [questKeys.objectives] = {{{25629},{25742}},nil,{{34968}}},
        },

        [11708] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {11707},
        },

        [11711] = {
            [questKeys.requiredSourceItems] = {34971},
        },

        [11712] = {
            [questKeys.objectives] = {{{25773}}},
            [questKeys.requiredSourceItems] = {34973},
        },

        [11713] = {
            [questKeys.objectives] = {{{25664},{25665},{25666}},nil,{{34920}}},
            [questKeys.preQuestSingle] = {11873},
            [questKeys.specialFlags] = 32,
        },

        [11715] = {
            [questKeys.objectives] = {{{25781}},nil,{{34975}}},
        },

        [11721] = {
            [questKeys.requiredSourceItems] = {34979},
        },

        [11722] = {
            [questKeys.objectives] = {nil,nil,{{34980}}},
        },

        [11723] = {
            [questKeys.objectives] = {{{25629},{25794}}},
            [questKeys.requiredSourceItems] = {34981},
        },

        [11724] = {
            [questKeys.objectives] = {nil,nil,{{34982}}},
        },

        [11728] = {
            [questKeys.requiredSourceItems] = {35121},
        },

        [11729] = {
            [questKeys.objectives] = {nil,nil,{{34984}}},
        },

        [11730] = {
            [questKeys.objectives] = {{{25815}}},
            [questKeys.requiredSourceItems] = {35116},
        },

        [11793] = {
            [questKeys.objectives] = {nil,nil,{{35122}}},
        },

        [11794] = {
            [questKeys.requiredSourceItems] = {35125},
        },

        [11796] = {
            [questKeys.requiredSourceItems] = {35224},
        },

        [11865] = {
            [questKeys.requiredSourceItems] = {35127},
        },

        [11875] = {
            [questKeys.preQuestSingle] = {11550},
        },

        [11876] = {
            [questKeys.requiredSourceItems] = {35228},
        },

        [11877] = {
            [questKeys.preQuestSingle] = {11550},
        },

        [11878] = {
            [questKeys.objectives] = nil,
        },

        [11880] = {
            [questKeys.objectives] = {{{25882}},nil,{{35233}}},
            [questKeys.specialFlags] = 33,
        },

        [11881] = {
            [questKeys.requiredSourceItems] = {35272},
        },

        [11885] = {
            [questKeys.objectivesText] = {"Find the Skull Piles in the middle of the summoning circles of Skettis. Summon and defeat each of the descendants by using 10 Time-Lost Scrolls at the Skull Pile.  Return to Hazzik at Blackwind Landing."},
            [questKeys.requiredSourceItems] = {},
        },

        [11888] = {
            [questKeys.preQuestSingle] = {11598},
        },

        [11889] = {
            [questKeys.requiredSourceItems] = {35278},
        },

        [11891] = {
            [questKeys.objectives] = {nil,nil,{{35237}}},
            [questKeys.requiredSourceItems] = {},
        },

        [11892] = {
            [questKeys.requiredSourceItems] = {35293},
            [questKeys.preQuestSingle] = {11866,11868,11872,11879,11884},
        },

        [11893] = {
            [questKeys.objectives] = {{{25987}}},
            [questKeys.requiredSourceItems] = {35281},
        },

        [11896] = {
            [questKeys.objectives] = {{{26082}}},
            [questKeys.requiredSourceItems] = {35352},
        },

        [11897] = {
            [questKeys.requiredSourceItems] = {35704},
        },

        [11899] = {
            [questKeys.objectives] = {{{26096}}},
            [questKeys.requiredSourceItems] = {35401},
            [questKeys.preQuestSingle] = {},
        },

        [11904] = {
            [questKeys.objectivesText] = {"Go to the mine in Farshire, obtain the Cart Release Key from Captain Jacobs and use it to release the ore cart.  Return to Gerald Green in Farshire when you've completed this task."},
        },

        [11905] = {
            [questKeys.objectives] = {{{26105}},nil,{{35479}}},
        },

        [11906] = {
            [questKeys.preQuestSingle] = {},
        },

        [11908] = {
            [questKeys.preQuestSingle] = {11901},
        },

        [11913] = {
            [questKeys.objectives] = {{{26161}}},
            [questKeys.requiredSourceItems] = {35491},
        },

        [11917] = {
            [questKeys.requiredMaxLevel] = 31,
            [questKeys.specialFlags] = 1,
        },

        [11919] = {
            [questKeys.objectives] = {{{26175}}},
            [questKeys.requiredSourceItems] = {35506},
        },

        [11921] = {
            [questKeys.preQuestSingle] = {11731},
            [questKeys.specialFlags] = 3,
        },

        [11924] = {
            [questKeys.specialFlags] = 3,
        },

        [11925] = {
            [questKeys.specialFlags] = 3,
        },

        [11926] = {
            [questKeys.preQuestSingle] = {11922},
            [questKeys.specialFlags] = 3,
        },

        [11933] = {
            [questKeys.objectives] = {nil,nil,{{35569}}},
        },

        [11934] = {
            [questKeys.questLevel] = 15,
            [questKeys.requiredLevel] = 15,
            [questKeys.objectivesText] = {"Bring this dude some stuff."},
            [questKeys.objectives] = {nil,nil,{{37103}}},
            [questKeys.questFlags] = 128,
        },

        [11935] = {
            [questKeys.objectives] = {nil,nil,{{35568}}},
        },

        [11938] = {
            [questKeys.objectivesText] = {"Thassarian at the Wailing Ziggurat in Borean Tundra wants you to inflict 20 casualties against the Scourge inside the Temple City of En'kilah.  Use Lurid's Bones if you need assistance."},
            [questKeys.objectives] = {{{26195}}},
            [questKeys.requiredSourceItems] = {35944},
        },

        [11940] = {
            [questKeys.objectives] = {{{26175}}},
            [questKeys.requiredSourceItems] = {35506},
        },

        [11941] = {
            [questKeys.objectives] = {nil,nil,{{35648}}},
        },

        [11946] = {
            [questKeys.objectivesText] = {"Keristrasza wants you to speak to her when you are ready to prepare for a confrontation with Malygos.$b$bIf you lose your Augmented Arcane Prison, speak to Raelorasz at the Transitus Shield."},
            [questKeys.sourceItemId] = 0,
        },

        [11947] = {
            [questKeys.requiredMaxLevel] = 42,
            [questKeys.specialFlags] = 1,
        },

        [11948] = {
            [questKeys.requiredMaxLevel] = 50,
            [questKeys.specialFlags] = 1,
        },

        [11951] = {
            [questKeys.objectivesText] = {"Keristrasza has asked you to collect 10 Crystalized Mana Shards from around Coldarra.$b$bIf you lose your Augmented Arcane Prison, speak to Raelorasz at the Transitus Shield."},
            [questKeys.requiredSourceItems] = {},
        },

        [11952] = {
            [questKeys.requiredMaxLevel] = 59,
            [questKeys.specialFlags] = 1,
        },

        [11953] = {
            [questKeys.requiredMaxLevel] = 66,
            [questKeys.specialFlags] = 1,
        },

        [11954] = {
            [questKeys.specialFlags] = 1,
        },

        [11955] = {
            [questKeys.requiredLevel] = 75,
        },

        [11956] = {
            [questKeys.objectivesText] = {"Go to Death's Stand and ride Dusk to the location of Tanathal's Phylactery.  Obtain it and bring it back to Thassarian inside the Wailing Ziggurat."},
        },

        [11957] = {
            [questKeys.requiredSourceItems] = {35690},
        },

        [11959] = {
            [questKeys.objectives] = {{{26227}}},
        },

        [11962] = {
            [questKeys.objectives] = {nil,nil,{{35706}}},
        },

        [11964] = {
            [questKeys.objectives] = {nil,nil,{{35725}}},
            [questKeys.specialFlags] = 2,
        },

        [11966] = {
            [questKeys.objectives] = {nil,nil,{{35725}}},
            [questKeys.specialFlags] = 2,
        },

        [11969] = {
            [questKeys.requiredSourceItems] = {44950},
        },

        [11972] = {
            [questKeys.objectives] = {nil,nil,{{35723}}},
        },

        [11974] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 60,
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to see L70ETC in Silvermoon City's Walk of Elder's.  Make sure to call for her if she is not present when you arrive."},
            [questKeys.questFlags] = 138,
        },

        [11975] = {
            [questKeys.objectivesText] = {"Take your orphan, Salandria, to see the Elite Tauren Chieftain in Silvermoon City's Walk of Elders.  Make sure to call for her if she is not present when you arrive. "},
            [questKeys.preQuestSingle] = {10945},
        },

        [11976] = {
            [questKeys.objectives] = {nil,nil,{{35723}}},
        },

        [11977] = {
            [questKeys.exclusiveTo] = {},
        },

        [11978] = {
            [questKeys.preQuestSingle] = {},
        },

        [11979] = {
            [questKeys.exclusiveTo] = {},
        },

        [11982] = {
            [questKeys.objectives] = {{{26264}}},
            [questKeys.preQuestSingle] = {11981,12074},
        },

        [11983] = {
            [questKeys.objectives] = {{{26179}},nil,{{35784}}},
        },

        [11984] = {
            [questKeys.requiredSourceItems] = {35736},
            [questKeys.preQuestSingle] = {12208,12210},
            [questKeys.nextQuestInChain] = 11989,
        },

        [11987] = {
            [questKeys.questLevel] = 1,
            [questKeys.questFlags] = 128,
        },

        [11991] = {
            [questKeys.specialFlags] = 2,
        },

        [11992] = {
            [questKeys.questLevel] = 71,
            [questKeys.requiredLevel] = 68,
            [questKeys.objectivesText] = {"Obtain the missing parts of the Skadir Navigational Chart and bring it to Karuk in Riplash Stand."},
            [questKeys.objectives] = {nil,nil,{{35775},{35776},{35777},{35778}}},
            [questKeys.questFlags] = 136,
        },

        [11993] = {
            [questKeys.requiredSourceItems] = {35746},
        },

        [11995] = {
            [questKeys.exclusiveTo] = {12440},
        },

        [11999] = {
            [questKeys.preQuestSingle] = {11996},
        },

        [12001] = {
            [questKeys.questLevel] = 5,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Collect 12 Torn Hides and then summon the Huntsman with the Hunting Tarot.  The Torn Hides can only be gathered from beasts of level 5 or higher."},
            [questKeys.objectives] = {nil,nil,{{11407},{35789}}},
            [questKeys.sourceItemId] = 35789,
            [questKeys.questFlags] = 4224,
            [questKeys.specialFlags] = 1,
        },

        [12006] = {
            [questKeys.objectives] = {{{26280}}},
        },

        [12007] = {
            [questKeys.objectivesText] = {"Drakuru wants you to bring the Eye of the Prophets to him at Drakuru's Brazier in Zeb'Halak.$b$bYou will need to collect Zim'bo's Mojo to use Drakuru's Elixir there."},
            [questKeys.requiredSourceItems] = {35836},
        },

        [12008] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [12012] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {35828},
        },

        [12014] = {
            [questKeys.sourceItemId] = 0,
        },

        [12017] = {
            [questKeys.requiredSourceItems] = {35838},
        },

        [12018] = {
            [questKeys.questLevel] = 73,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Obtain 2 Stone Hunks O' Gargoyle from Carrion Gargoyles in the Eastern Carrion Fields.  Return to Lord Bevis when the task is complete."},
            [questKeys.objectives] = {nil,nil,{{35840}}},
            [questKeys.questFlags] = 136,
        },

        [12019] = {
            [questKeys.objectivesText] = {"Go to the Temple City of En'kilah and find the teleportation orb beneath the floating Scourge citadel of Naxxanar.  Use it to reach the top and help Thassarian there."},
        },

        [12022] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12023] = {
            [questKeys.objectivesText] = {"Kill the Abomination on the hillside in Eastern Carrion Fields.  Return to Lord Bevis once the slaughter is complete."},
        },

        [12024] = {
            [questKeys.questLevel] = 73,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Search the skeletons in the Carrion Fields for Alliance Settlement Documents."},
            [questKeys.objectives] = {nil,nil,{{35853}}},
            [questKeys.questFlags] = 136,
        },

        [12025] = {
            [questKeys.questLevel] = 73,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectivesText] = {"Search for evidence of the Scarlet Crusade on the freshly risen Carrion Ghouls in the Eastern Carrion Fields.  Return to Lady Alustra with anything you find."},
            [questKeys.objectives] = {nil,nil,{{35854}}},
            [questKeys.questFlags] = 136,
        },

        [12028] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {35907},
        },

        [12029] = {
            [questKeys.objectives] = {{{26612}}},
            [questKeys.requiredSourceItems] = {35908},
        },

        [12031] = {
            [questKeys.objectives] = {{{26343}}},
        },

        [12032] = {
            [questKeys.objectives] = nil,
        },

        [12033] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {},
        },

        [12034] = {
            [questKeys.preQuestSingle] = {},
        },

        [12035] = {
            [questKeys.objectives] = {{{25993}}},
            [questKeys.requiredSourceItems] = {35943},
        },

        [12038] = {
            [questKeys.objectives] = {{{26612}}},
            [questKeys.requiredSourceItems] = {35908},
            [questKeys.preQuestSingle] = {},
        },

        [12039] = {
            [questKeys.requiredSourceItems] = {36726},
            [questKeys.preQuestSingle] = {},
        },

        [12041] = {
            [questKeys.objectives] = {nil,nil,{{36735}}},
        },

        [12043] = {
            [questKeys.objectivesText] = {"Kill 12 Wastes Diggers and 1 Wastes Taskmaster at the digs surrounding Galakrond's Rest.  Return to Narf at Nozzlerust Post when the task is complete."},
        },

        [12044] = {
            [questKeys.preQuestSingle] = {12469},
        },

        [12046] = {
            [questKeys.objectivesText] = {"Collect 12 Thin Animal Hides from the Jormungar Tunnelers or the Dragonbone Condors near Nozzlerust Post.  Once you've located the hides, return them to Zivlix."},
        },

        [12049] = {
            [questKeys.requiredSourceItems] = {36732},
            [questKeys.preQuestSingle] = {},
        },

        [12050] = {
            [questKeys.objectivesText] = {"Use Xink's Shredder Control Device to call a Shredder once you reach the Harpy Nesting Grounds in the North.  Gather 50 Bundles of Lumber from the trees in the area, and then return to Xink at Nozzlerust Post.","","Should you lose Xink's Shredder Control Device, speak to Xink at Nozzlerust Post to obtain a new one."},
            [questKeys.requiredSourceItems] = {36734},
        },

        [12051] = {
            [questKeys.objectives] = {{{26577}}},
        },

        [12052] = {
            [questKeys.objectives] = {{{26578},{26577}}},
            [questKeys.requiredSourceItems] = {36734},
        },

        [12053] = {
            [questKeys.objectives] = {nil,nil,{{36738}}},
        },

        [12055] = {
            [questKeys.objectives] = {nil,nil,{{36742}}},
            [questKeys.preQuestSingle] = {},
        },

        [12056] = {
            [questKeys.preQuestSingle] = {},
        },

        [12057] = {
            [questKeys.objectives] = {nil,nil,{{36744}}},
        },

        [12058] = {
            [questKeys.requiredSourceItems] = {35746},
            [questKeys.nextQuestInChain] = 12204,
        },

        [12059] = {
            [questKeys.objectives] = {nil,nil,{{36746}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.questFlags] = 128,
        },

        [12060] = {
            [questKeys.requiredSourceItems] = {36747},
        },

        [12061] = {
            [questKeys.requiredSourceItems] = {36747},
        },

        [12062] = {
            [questKeys.preQuestSingle] = {12318},
        },

        [12063] = {
            [questKeys.preQuestSingle] = {},
        },

        [12067] = {
            [questKeys.objectives] = {nil,nil,{{36756}}},
            [questKeys.questFlags] = 128,
        },

        [12068] = {
            [questKeys.requiredSourceItems] = {36758},
        },

        [12069] = {
            [questKeys.requiredSourceItems] = {36760},
        },

        [12070] = {
            [questKeys.requiredSourceItems] = {36764},
        },

        [12072] = {
            [questKeys.requiredSourceItems] = {36774},
        },

        [12073] = {
            [questKeys.objectives] = {{{26270}}},
            [questKeys.nextQuestInChain] = 12204,
        },

        [12074] = {
            [questKeys.nextQuestInChain] = 11982,
        },

        [12075] = {
            [questKeys.preQuestSingle] = {12112},
        },

        [12076] = {
            [questKeys.objectivesText] = {"Collect 2 Vials of Corrosive Spit from the Jormungar by using the scraper on yourself.  Bring the vials back to Zort in the Crystal Vice when your task is complete."},
            [questKeys.requiredSourceItems] = {36775},
        },

        [12077] = {
            [questKeys.objectives] = {nil,nil,{{36769}}},
            [questKeys.questFlags] = 128,
        },

        [12078] = {
            [questKeys.objectivesText] = {"Enter the caverns in Crystal Vice and trap 3 Jormungar Spawn inside sturdy crates.  Be sure to pick the crates up after the Jormungar Spawn are trapped inside!","","Bring the captured Jormungar Spawn back to Zort in the Crystal Vice."},
            [questKeys.requiredSourceItems] = {36771},
            [questKeys.preQuestSingle] = {},
        },

        [12079] = {
            [questKeys.preQuestSingle] = {},
        },

        [12080] = {
            [questKeys.objectivesText] = {"Enter the Ice Heart Cavern and slay Rattlebore.  If it is still in your possession, be sure to use Zort's Protective Elixir to protect you from the Jormungar's corrosive spit.","","Return to Ko'char the Unbreakable in the Crystal Vice when the task is complete."},
            [questKeys.preQuestSingle] = {},
        },

        [12085] = {
            [questKeys.objectives] = {nil,nil,{{36780}}},
        },

        [12092] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 32,
        },

        [12094] = {
            [questKeys.objectives] = {{{26856},{26855},{26857}},nil,{{36787}}},
            [questKeys.specialFlags] = 32,
        },

        [12096] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 32,
        },

        [12099] = {
            [questKeys.objectives] = {{{26783}}},
            [questKeys.requiredSourceItems] = {36796},
        },

        [12100] = {
            [questKeys.objectives] = {{{26874}},nil,{{36800}}},
            [questKeys.preQuestSingle] = {},
        },

        [12101] = {
            [questKeys.objectives] = {nil,nil,{{36800}}},
        },

        [12104] = {
            [questKeys.objectives] = {nil,nil,{{36807}}},
        },

        [12105] = {
            [questKeys.objectives] = {nil,nil,{{36940}}},
        },

        [12107] = {
            [questKeys.requiredSourceItems] = {36815},
        },

        [12110] = {
            [questKeys.requiredSourceItems] = {36815},
        },

        [12111] = {
            [questKeys.objectives] = {{{26895},{26882}}},
            [questKeys.requiredSourceItems] = {36818},
        },

        [12115] = {
            [questKeys.objectives] = {nil,nil,{{36820}}},
        },

        [12117] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [12118] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [12119] = {
            [questKeys.objectives] = {nil,nil,{{36832}}},
            [questKeys.questFlags] = 128,
        },

        [12121] = {
            [questKeys.objectives] = {{{26902}}},
        },

        [12122] = {
            [questKeys.objectives] = {nil,nil,{{36833}}},
        },

        [12123] = {
            [questKeys.objectives] = {nil,nil,{{36832}}},
        },

        [12124] = {
            [questKeys.objectives] = {nil,nil,{{36833}}},
        },

        [12125] = {
            [questKeys.objectives] = {nil,nil,{{36828}}},
        },

        [12126] = {
            [questKeys.objectives] = {nil,nil,{{36836}}},
        },

        [12127] = {
            [questKeys.objectives] = {nil,nil,{{36846}}},
        },

        [12132] = {
            [questKeys.preQuestSingle] = {12125,12126,12127},
        },

        [12133] = {
            [questKeys.objectives] = {nil,nil,{{36876}}},
            [questKeys.questFlags] = 4608,
        },

        [12135] = {
            [questKeys.objectivesText] = {"The Costumed Orphan Matron wants you to help put out all the village fires after the Headless Horseman lights them.  When they are out, speak again to the Costumed Orphan Matron."},
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {11131},
            [questKeys.questFlags] = 4170,
            [questKeys.specialFlags] = 3,
        },

        [12136] = {
            [questKeys.objectives] = {nil,nil,{{36861}}},
        },

        [12137] = {
            [questKeys.objectivesText] = {"Gan'jo wants you to collect the Snow of Eternal Slumber from his chest in the Drakil'jin Ruins.$b$bYou are to use the Snow on the Ancient Drakkari Spirits there and take their Drakkari Spirit Particles back to Kraz at Harkor's Camp."},
            [questKeys.sourceItemId] = 0,
        },

        [12138] = {
            [questKeys.objectives] = {{{27017}}},
            [questKeys.requiredSourceItems] = {36936},
        },

        [12139] = {
            [questKeys.objectivesText] = {"The Masked Orphan Matron wants you to help put out all the village fires.  When they are out, speak again to the Masked Orphan Matron in town."},
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {11219},
            [questKeys.questFlags] = 4170,
            [questKeys.specialFlags] = 3,
        },

        [12140] = {
            [questKeys.requiredSourceItems] = {35784},
        },

        [12142] = {
            [questKeys.objectives] = {{{26705},{26481}}},
        },

        [12144] = {
            [questKeys.objectives] = {{{26705},{26481}}},
        },

        [12146] = {
            [questKeys.objectives] = {nil,nil,{{36855}}},
            [questKeys.questFlags] = 128,
        },

        [12147] = {
            [questKeys.objectives] = {nil,nil,{{36856}}},
            [questKeys.questFlags] = 128,
        },

        [12150] = {
            [questKeys.objectives] = nil,
        },

        [12151] = {
            [questKeys.requiredSourceItems] = {36864},
        },

        [12152] = {
            [questKeys.requiredSourceItems] = {36870,36873},
        },

        [12153] = {
            [questKeys.requiredSourceItems] = {36865},
        },

        [12154] = {
            [questKeys.requiredSourceItems] = {36935},
            [questKeys.specialFlags] = 32,
        },

        [12155] = {
            [questKeys.objectives] = {nil,nil,{{36876}}},
            [questKeys.questFlags] = 4608,
        },

        [12156] = {
            [questKeys.objectivesText] = {"Escort the Alliance Envoy to the town of Silverbrook.  Report to Lieutenant Dumont at the Amberpine Lodge when you've completed this task."},
        },

        [12157] = {
            [questKeys.exclusiveTo] = {},
        },

        [12159] = {
            [questKeys.objectives] = {{{27561}}},
            [questKeys.requiredSourceItems] = {37932},
        },

        [12161] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {12425},
        },

        [12164] = {
            [questKeys.objectivesText] = {"Sasha at the White Pine Trading Post wants you to go to  Bloodmoon Isle and slay Selas, Varlam, Goremaw and the Shade of Arugal."},
        },

        [12166] = {
            [questKeys.objectives] = {{{27111},{27112}}},
            [questKeys.requiredSourceItems] = {36956},
        },

        [12168] = {
            [questKeys.objectives] = {nil,nil,{{36958}}},
        },

        [12170] = {
            [questKeys.objectives] = {{{27121}}},
        },

        [12171] = {
            [questKeys.objectives] = {nil,nil,{{37003}}},
            [questKeys.exclusiveTo] = {12297},
        },

        [12172] = {
            [questKeys.requiredSourceItems] = {37006},
            [questKeys.specialFlags] = 32,
        },

        [12173] = {
            [questKeys.requiredSourceItems] = {37006},
            [questKeys.specialFlags] = 32,
        },

        [12174] = {
            [questKeys.objectivesText] = {"Deliver the Alliance Missive to High Commander Halford Wyrmbane at Wintergarde Keep in eastern Dragonblight. "},
            [questKeys.objectives] = {nil,nil,{{37003}}},
            [questKeys.exclusiveTo] = {12298},
        },

        [12178] = {
            [questKeys.objectives] = {nil,nil,{{39665}}},
            [questKeys.nextQuestInChain] = 12427,
        },

        [12180] = {
            [questKeys.preQuestSingle] = {11993},
            [questKeys.specialFlags] = 32,
        },

        [12181] = {
            [questKeys.objectives] = {nil,nil,{{37027}}},
            [questKeys.exclusiveTo] = {},
        },

        [12182] = {
            [questKeys.objectives] = {nil,nil,{{37027}}},
            [questKeys.questFlags] = 128,
        },

        [12184] = {
            [questKeys.objectives] = {{{26885}},nil,{{37045}}},
        },

        [12185] = {
            [questKeys.requiredSourceItems] = {37071},
        },

        [12188] = {
            [questKeys.preQuestSingle] = {12182,12189},
        },

        [12189] = {
            [questKeys.exclusiveTo] = {},
        },

        [12190] = {
            [questKeys.objectives] = {nil,nil,{{38144}}},
            [questKeys.questFlags] = 128,
        },

        [12191] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12193] = {
            [questKeys.objectives] = {nil,nil,{{33955}}},
        },

        [12194] = {
            [questKeys.objectives] = {nil,nil,{{33955}}},
            [questKeys.preQuestSingle] = {},
        },

        [12196] = {
            [questKeys.preQuestSingle] = {12195},
        },

        [12198] = {
            [questKeys.objectives] = {{{27017}}},
            [questKeys.requiredSourceItems] = {36936},
        },

        [12199] = {
            [questKeys.requiredSourceItems] = {36865},
        },

        [12202] = {
            [questKeys.objectives] = {{{26885}},nil,{{37125}}},
        },

        [12203] = {
            [questKeys.requiredSourceItems] = {37071},
        },

        [12204] = {
            [questKeys.preQuestSingle] = {12058,12073},
        },

        [12205] = {
            [questKeys.objectives] = {{{27203}}},
        },

        [12206] = {
            [questKeys.objectives] = {{{27253}}},
            [questKeys.nextQuestInChain] = 12211,
        },

        [12208] = {
            [questKeys.preQuestSingle] = {},
        },

        [12210] = {
            [questKeys.preQuestSingle] = {},
        },

        [12211] = {
            [questKeys.objectives] = {{{27280}}},
            [questKeys.requiredSourceItems] = {37187},
        },

        [12213] = {
            [questKeys.requiredSourceItems] = {37173},
            [questKeys.specialFlags] = 32,
        },

        [12214] = {
            [questKeys.objectives] = {{{27296}}},
        },

        [12220] = {
            [questKeys.requiredSourceItems] = {37173},
        },

        [12221] = {
            [questKeys.objectives] = {nil,nil,{{37233}}},
        },

        [12222] = {
            [questKeys.nextQuestInChain] = 12255,
        },

        [12223] = {
            [questKeys.nextQuestInChain] = 12255,
        },

        [12225] = {
            [questKeys.preQuestSingle] = {12222,12223},
        },

        [12231] = {
            [questKeys.objectives] = {{{27322},{27321}}},
        },

        [12232] = {
            [questKeys.objectives] = {{{27331}}},
            [questKeys.requiredSourceItems] = {37259},
            [questKeys.specialFlags] = 32,
        },

        [12236] = {
            [questKeys.objectivesText] = {"Windseer Grayhorn in Conquest Hold wants you to find Tur Ragepaw near Ursoc's Den and defeat Ursoc with his help.  Use the Purified Ashes of Vordrassil on Ursoc's Corpse when you've accomplished this."},
            [questKeys.objectives] = {{{27372}}},
            [questKeys.requiredSourceItems] = {37307},
            [questKeys.preQuestSingle] = {12241,12242},
        },

        [12237] = {
            [questKeys.objectives] = {{{27341}}},
            [questKeys.requiredSourceItems] = {37287},
        },

        [12238] = {
            [questKeys.requiredSourceItems] = {35797},
        },

        [12239] = {
            [questKeys.objectives] = {nil,nil,{{37299}}},
        },

        [12240] = {
            [questKeys.requiredSourceItems] = {37300},
        },

        [12241] = {
            [questKeys.objectivesText] = {"Windseer Grayhorn in Conquest Hold wants you to take the Verdant Torch and use it to burn Vordrassil's Sapling.  Bring Vordrassil's Ashes back to Windseer Grayhorn."},
            [questKeys.requiredSourceItems] = {37306},
            [questKeys.nextQuestInChain] = 12236,
        },

        [12242] = {
            [questKeys.nextQuestInChain] = 12236,
        },

        [12243] = {
            [questKeys.requiredSourceItems] = {37304},
        },

        [12244] = {
            [questKeys.objectives] = {{{27396}}},
        },

        [12245] = {
            [questKeys.preQuestSingle] = {},
        },

        [12246] = {
            [questKeys.preQuestSingle] = {12220},
        },

        [12247] = {
            [questKeys.objectives] = {{{27322},{27321}}},
            [questKeys.preQuestSingle] = {12219},
        },

        [12248] = {
            [questKeys.objectivesText] = {"Hierophant Thayreen in Amberpine Lodge wants you to take the Verdant Torch and use it to burn Vordrassil's Sapling.  Bring Vordrassil's Ashes back to Hierophant Thayreen."},
            [questKeys.requiredSourceItems] = {37306},
            [questKeys.preQuestSingle] = {12246},
            [questKeys.nextQuestInChain] = 12249,
        },

        [12249] = {
            [questKeys.objectivesText] = {"Hierophant Thayreen at Amberpine Lodge wants you to find Tur Ragepaw near Ursoc's Den and defeat Ursoc with his help.  Use the Purified Ashes of Vordrassil on Ursoc's Corpse when you've accomplished this."},
            [questKeys.objectives] = {{{27372}}},
            [questKeys.requiredSourceItems] = {37307},
            [questKeys.preQuestSingle] = {12248,12250},
        },

        [12250] = {
            [questKeys.preQuestSingle] = {12247},
            [questKeys.nextQuestInChain] = 12249,
        },

        [12252] = {
            [questKeys.objectives] = {{{27394},{27209}}},
            [questKeys.requiredSourceItems] = {37314},
        },

        [12255] = {
            [questKeys.preQuestSingle] = {12222},
        },

        [12256] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 12259,
        },

        [12257] = {
            [questKeys.nextQuestInChain] = 12259,
        },

        [12258] = {
            [questKeys.preQuestSingle] = {},
        },

        [12259] = {
            [questKeys.preQuestSingle] = {12256,12257},
            [questKeys.nextQuestInChain] = 12412,
        },

        [12260] = {
            [questKeys.objectives] = {{{27419}},nil,{{37381}}},
        },

        [12261] = {
            [questKeys.objectives] = {{{28820}}},
            [questKeys.requiredSourceItems] = {37445},
        },

        [12262] = {
            [questKeys.objectives] = {{{27356},{27360}}},
        },

        [12267] = {
            [questKeys.requiredSourceItems] = {37539},
            [questKeys.specialFlags] = 32,
        },

        [12269] = {
            [questKeys.preQuestSingle] = {12251},
        },

        [12270] = {
            [questKeys.objectives] = {{{27396}}},
        },

        [12271] = {
            [questKeys.objectives] = {nil,nil,{{37432}}},
            [questKeys.preQuestSingle] = {},
        },

        [12272] = {
            [questKeys.requiredSourceItems] = {37358},
            [questKeys.preQuestSingle] = {12251},
        },

        [12273] = {
            [questKeys.objectives] = {{{27426},{27427},{27428},{27429}}},
            [questKeys.requiredSourceItems] = {37438},
        },

        [12274] = {
            [questKeys.objectives] = {{{27445},{27444}}},
        },

        [12276] = {
            [questKeys.requiredSourceItems] = {37459},
        },

        [12278] = {
            [questKeys.objectives] = {nil,nil,{{37571}}},
        },

        [12279] = {
            [questKeys.requiredSourceItems] = {37542},
        },

        [12281] = {
            [questKeys.objectives] = {nil,nil,{{37502}}},
            [questKeys.preQuestSingle] = {12272,12277},
        },

        [12284] = {
            [questKeys.objectives] = {{{27453}}},
        },

        [12286] = {
            [questKeys.questFlags] = 65536,
        },

        [12288] = {
            [questKeys.objectives] = {{{27466}}},
            [questKeys.requiredSourceItems] = {37568},
        },

        [12289] = {
            [questKeys.objectives] = {{{27453}}},
        },

        [12291] = {
            [questKeys.objectives] = {{{27472},{27471},{27473},{27474}}},
            [questKeys.requiredSourceItems] = {37570},
        },

        [12293] = {
            [questKeys.objectives] = {nil,nil,{{37572}}},
            [questKeys.questFlags] = 128,
        },

        [12296] = {
            [questKeys.objectives] = {{{27466}}},
            [questKeys.requiredSourceItems] = {37576},
        },

        [12297] = {
            [questKeys.objectives] = {nil,nil,{{37003}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {12171},
            [questKeys.questFlags] = 128,
        },

        [12298] = {
            [questKeys.objectivesText] = {"Deliver the Alliance Missive to High Commander Halford Wyrmbane at Wintergarde Keep in eastern Dragonblight. "},
            [questKeys.objectives] = {nil,nil,{{37003}}},
            [questKeys.exclusiveTo] = {12174},
        },

        [12300] = {
            [questKeys.requiredSourceItems] = {37581},
            [questKeys.preQuestSingle] = {12299,12307},
        },

        [12301] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {37577},
        },

        [12304] = {
            [questKeys.objectives] = {{{27220}}},
        },

        [12306] = {
            [questKeys.objectives] = {nil,nil,{{37599}}},
        },

        [12307] = {
            [questKeys.preQuestSingle] = {12295},
        },

        [12308] = {
            [questKeys.objectivesText] = {"Open the Wooden Cage and help the Freed Alliance Scout escape from Silverbrook.  Report to Lieutenant Dumont when you reach Amberpine Lodge."},
            [questKeys.objectives] = {{{28019}}},
            [questKeys.exclusiveTo] = {13524},
        },

        [12310] = {
            [questKeys.preQuestSingle] = {12308,13524},
        },

        [12312] = {
            [questKeys.objectives] = {nil,nil,{{37601}}},
            [questKeys.preQuestSingle] = {},
        },

        [12316] = {
            [questKeys.objectives] = {{{28190}}},
        },

        [12317] = {
            [questKeys.objectives] = {{{28190}}},
        },

        [12318] = {
            [questKeys.preQuestSingle] = {11446,11447},
        },

        [12319] = {
            [questKeys.objectives] = {nil,nil,{{37607}}},
        },

        [12320] = {
            [questKeys.objectives] = {nil,nil,{{37607}}},
            [questKeys.questFlags] = 128,
        },

        [12321] = {
            [questKeys.objectives] = nil,
        },

        [12323] = {
            [questKeys.objectives] = {{{27568}}},
            [questKeys.requiredSourceItems] = {37621},
        },

        [12324] = {
            [questKeys.objectives] = {{{27568}}},
            [questKeys.requiredSourceItems] = {37621},
        },

        [12325] = {
            [questKeys.preQuestSingle] = {12281,12321},
        },

        [12326] = {
            [questKeys.objectives] = {{{27625},{27588}}},
        },

        [12327] = {
            [questKeys.requiredSourceItems] = {37661},
        },

        [12330] = {
            [questKeys.objectivesText] = {"Sasha at the White Pine Trading Post wants you to take the Tranquilizer Dart and use it on Tatjana in Solstice Village.  Bring Tatjana back to the White Pine Trading Post."},
            [questKeys.requiredSourceItems] = {37665},
        },

        [12331] = {
            [questKeys.questFlags] = 65536,
        },

        [12332] = {
            [questKeys.questFlags] = 65536,
        },

        [12333] = {
            [questKeys.questFlags] = 65536,
        },

        [12334] = {
            [questKeys.questFlags] = 65536,
        },

        [12335] = {
            [questKeys.questFlags] = 65536,
        },

        [12336] = {
            [questKeys.questFlags] = 65536,
        },

        [12337] = {
            [questKeys.questFlags] = 65536,
        },

        [12338] = {
            [questKeys.questFlags] = 65536,
        },

        [12339] = {
            [questKeys.questFlags] = 65536,
        },

        [12340] = {
            [questKeys.questFlags] = 65536,
        },

        [12341] = {
            [questKeys.questFlags] = 65536,
        },

        [12342] = {
            [questKeys.questFlags] = 65536,
        },

        [12343] = {
            [questKeys.questFlags] = 65536,
        },

        [12344] = {
            [questKeys.questFlags] = 65536,
        },

        [12345] = {
            [questKeys.questFlags] = 65536,
        },

        [12346] = {
            [questKeys.questFlags] = 65536,
        },

        [12347] = {
            [questKeys.questFlags] = 65536,
        },

        [12348] = {
            [questKeys.questFlags] = 65536,
        },

        [12349] = {
            [questKeys.questFlags] = 65536,
        },

        [12350] = {
            [questKeys.questFlags] = 65536,
        },

        [12351] = {
            [questKeys.questFlags] = 65536,
        },

        [12352] = {
            [questKeys.questFlags] = 65536,
        },

        [12353] = {
            [questKeys.questFlags] = 65536,
        },

        [12354] = {
            [questKeys.questFlags] = 65536,
        },

        [12355] = {
            [questKeys.questFlags] = 65536,
        },

        [12356] = {
            [questKeys.questFlags] = 65536,
        },

        [12357] = {
            [questKeys.questFlags] = 65536,
        },

        [12358] = {
            [questKeys.questFlags] = 65536,
        },

        [12359] = {
            [questKeys.questFlags] = 65536,
        },

        [12360] = {
            [questKeys.questFlags] = 65536,
        },

        [12361] = {
            [questKeys.questFlags] = 65536,
        },

        [12362] = {
            [questKeys.questFlags] = 65536,
        },

        [12363] = {
            [questKeys.questFlags] = 65536,
        },

        [12364] = {
            [questKeys.questFlags] = 65536,
        },

        [12365] = {
            [questKeys.questFlags] = 65536,
        },

        [12366] = {
            [questKeys.questFlags] = 65536,
        },

        [12367] = {
            [questKeys.questFlags] = 65536,
        },

        [12368] = {
            [questKeys.questFlags] = 65536,
        },

        [12369] = {
            [questKeys.questFlags] = 65536,
        },

        [12370] = {
            [questKeys.questFlags] = 65536,
        },

        [12371] = {
            [questKeys.questFlags] = 65536,
        },

        [12372] = {
            [questKeys.objectivesText] = {"Afrasastrasz at Wyrmrest Temple has asked you to slay 3 Azure Dragons, slay 5 Azure Drakes, and to destabilize the Azure Dragonshrine while riding a Wyrmrest Defender into battle."},
        },

        [12373] = {
            [questKeys.questFlags] = 65536,
        },

        [12374] = {
            [questKeys.questFlags] = 65536,
        },

        [12375] = {
            [questKeys.questFlags] = 65536,
        },

        [12376] = {
            [questKeys.questFlags] = 65536,
        },

        [12377] = {
            [questKeys.questFlags] = 65536,
        },

        [12378] = {
            [questKeys.questFlags] = 65536,
        },

        [12379] = {
            [questKeys.questFlags] = 65536,
        },

        [12380] = {
            [questKeys.questFlags] = 65536,
        },

        [12381] = {
            [questKeys.questFlags] = 65536,
        },

        [12382] = {
            [questKeys.questFlags] = 65536,
        },

        [12383] = {
            [questKeys.questFlags] = 65536,
        },

        [12384] = {
            [questKeys.questFlags] = 65536,
        },

        [12385] = {
            [questKeys.questFlags] = 65536,
        },

        [12386] = {
            [questKeys.questFlags] = 65536,
        },

        [12387] = {
            [questKeys.questFlags] = 65536,
        },

        [12388] = {
            [questKeys.questFlags] = 65536,
        },

        [12389] = {
            [questKeys.questFlags] = 65536,
        },

        [12390] = {
            [questKeys.questFlags] = 65536,
        },

        [12391] = {
            [questKeys.questFlags] = 65536,
        },

        [12392] = {
            [questKeys.questFlags] = 65536,
        },

        [12393] = {
            [questKeys.questFlags] = 65536,
        },

        [12394] = {
            [questKeys.questFlags] = 65536,
        },

        [12395] = {
            [questKeys.questFlags] = 65536,
        },

        [12396] = {
            [questKeys.questFlags] = 65536,
        },

        [12397] = {
            [questKeys.questFlags] = 65536,
        },

        [12398] = {
            [questKeys.questFlags] = 65536,
        },

        [12399] = {
            [questKeys.questFlags] = 65536,
        },

        [12400] = {
            [questKeys.questFlags] = 65536,
        },

        [12401] = {
            [questKeys.questFlags] = 65536,
        },

        [12402] = {
            [questKeys.questFlags] = 65536,
        },

        [12403] = {
            [questKeys.questFlags] = 65536,
        },

        [12404] = {
            [questKeys.questFlags] = 65536,
        },

        [12405] = {
            [questKeys.questFlags] = 65536,
        },

        [12406] = {
            [questKeys.questFlags] = 65536,
        },

        [12407] = {
            [questKeys.questFlags] = 65536,
        },

        [12408] = {
            [questKeys.questFlags] = 65536,
        },

        [12409] = {
            [questKeys.questFlags] = 65536,
        },

        [12410] = {
            [questKeys.questFlags] = 65536,
        },

        [12413] = {
            [questKeys.nextQuestInChain] = 12427,
        },

        [12414] = {
            [questKeys.objectives] = {{{26212}}},
            [questKeys.requiredSourceItems] = {37707,37708},
        },

        [12415] = {
            [questKeys.objectives] = {{{27221}}},
            [questKeys.requiredSourceItems] = {37716},
        },

        [12417] = {
            [questKeys.objectivesText] = {"Enter the Ruby Dragonshrine through one of the northern or southern passes and search for Ruby Acorns.  Use the Ruby Acorns on the fallen red dragons to return their bodies to the earth.  Return to Ceristrasz once the task is complete."},
            [questKeys.specialFlags] = 32,
        },

        [12419] = {
            [questKeys.objectives] = {nil,nil,{{37833}}},
        },

        [12420] = {
            [questKeys.objectives] = {nil,nil,{{37736}}},
        },

        [12421] = {
            [questKeys.objectives] = {nil,nil,{{37737}}},
        },

        [12422] = {
            [questKeys.objectives] = {nil,nil,{{37741}}},
            [questKeys.nextQuestInChain] = 12427,
        },

        [12423] = {
            [questKeys.objectives] = {nil,nil,{{37830}}},
        },

        [12424] = {
            [questKeys.objectives] = {nil,nil,{{37831}}},
        },

        [12425] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {12161},
        },

        [12427] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {12178,12413,12422},
            [questKeys.nextQuestInChain] = 12428,
        },

        [12428] = {
            [questKeys.objectives] = nil,
        },

        [12429] = {
            [questKeys.objectives] = nil,
        },

        [12430] = {
            [questKeys.objectives] = nil,
        },

        [12431] = {
            [questKeys.objectives] = nil,
        },

        [12432] = {
            [questKeys.objectivesText] = {"General Gorlok at the lighthouse in Venture Bay wants you to destroy the Alliance Lumber Boat.$b$bGeneral Gorlok will only be present at the lighthouse when the Horde has it in their possession."},
            [questKeys.requiredSourceItems] = {},
        },

        [12434] = {
            [questKeys.specialFlags] = 0,
        },

        [12435] = {
            [questKeys.objectivesText] = {"Speak with Lord Afrasastrasz at Wyrmrest Temple."},
        },

        [12436] = {
            [questKeys.objectivesText] = {"Provisioner Lorkran at Conquest Hold wants you to obtain 5 Succulent Venison from  the nearby Tallhorn Stag."},
        },

        [12437] = {
            [questKeys.objectivesText] = {"Commander Howser at the lighthouse in Venture Bay wants you to destroy the Horde lumber shipment.$b$bCommander Howser will only be present at the lighthouse when the Alliance has it in their possession."},
            [questKeys.requiredSourceItems] = {},
        },

        [12439] = {
            [questKeys.exclusiveTo] = {},
        },

        [12440] = {
            [questKeys.exclusiveTo] = {11995},
        },

        [12444] = {
            [questKeys.objectives] = {{{27121}}},
        },

        [12445] = {
            [questKeys.questFlags] = 136,
        },

        [12446] = {
            [questKeys.specialFlags] = 0,
        },

        [12449] = {
            [questKeys.objectivesText] = {"Enter the Ruby Dragonshrine through the southern pass and search for Ruby Acorns.  Use the Ruby Acorns on the fallen red dragons to return their bodies to the earth.  Return to Vargastrasz once the task is complete."},
            [questKeys.specialFlags] = 32,
        },

        [12451] = {
            [questKeys.preQuestSingle] = {},
        },

        [12453] = {
            [questKeys.objectives] = {{{27786}}},
            [questKeys.requiredSourceItems] = {37877},
            [questKeys.preQuestSingle] = {},
        },

        [12456] = {
            [questKeys.requiredSourceItems] = {37881},
        },

        [12459] = {
            [questKeys.objectives] = {{{27821},{27809},{27807}}},
            [questKeys.requiredSourceItems] = {37887},
        },

        [12462] = {
            [questKeys.objectives] = {{{27805},{27826},{27825}}},
            [questKeys.preQuestSingle] = {},
        },

        [12464] = {
            [questKeys.preQuestSingle] = {12251},
        },

        [12468] = {
            [questKeys.preQuestSingle] = {12487},
        },

        [12469] = {
            [questKeys.objectives] = {nil,nil,{{37922}}},
            [questKeys.questFlags] = 128,
        },

        [12470] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {37923},
        },

        [12472] = {
            [questKeys.objectives] = {nil,nil,{{37920}}},
            [questKeys.questFlags] = 128,
        },

        [12473] = {
            [questKeys.objectives] = nil,
        },

        [12476] = {
            [questKeys.objectives] = {{{27875}}},
        },

        [12478] = {
            [questKeys.objectives] = {{{27879}}},
            [questKeys.requiredSourceItems] = {37933},
        },

        [12481] = {
            [questKeys.objectives] = {{{24276},{24275}}},
            [questKeys.requiredSourceItems] = {33581},
        },

        [12483] = {
            [questKeys.preQuestSingle] = {},
        },

        [12486] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 11598,
        },

        [12491] = {
            [questKeys.objectives] = {nil,nil,{{38280}}},
        },

        [12492] = {
            [questKeys.objectives] = {nil,nil,{{38281}}},
        },

        [12498] = {
            [questKeys.requiredSourceItems] = {38302},
        },

        [12501] = {
            [questKeys.objectivesText] = {"Commander Kunz at the Argent Stand wants you to visit the four Argent Crusade posts, follow their captain's orders, and then return and report to him.$b$bCaptain Brandon and Captain Rupert are posted at Drak'Sotra, Captain Grondel is posted in Drak'Agal, and Alchemist Finklestein is posted in Heb'Valok."},
            [questKeys.preQuestSingle] = {12596},
            [questKeys.exclusiveTo] = {},
        },

        [12502] = {
            [questKeys.requiredSourceItems] = {38544},
            [questKeys.exclusiveTo] = {},
            [questKeys.specialFlags] = 33,
        },

        [12503] = {
            [questKeys.objectives] = {{{28022}}},
            [questKeys.nextQuestInChain] = 12596,
            [questKeys.breadcrumbs] = {12795},
        },

        [12505] = {
            [questKeys.objectives] = {nil,nil,{{38319}}},
            [questKeys.questFlags] = 128,
        },

        [12507] = {
            [questKeys.objectives] = {nil,nil,{{38321}}},
            [questKeys.questFlags] = 128,
        },

        [12508] = {
            [questKeys.objectives] = {{{28036}}},
        },

        [12509] = {
            [questKeys.exclusiveTo] = {},
        },

        [12512] = {
            [questKeys.objectives] = {{{28136},{28142},{28148}}},
            [questKeys.requiredSourceItems] = {38330},
        },

        [12513] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [12515] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [12516] = {
            [questKeys.objectives] = {{{28151}}},
            [questKeys.requiredSourceItems] = {38332},
        },

        [12517] = {
            [questKeys.objectives] = {nil,nil,{{43039}}},
        },

        [12518] = {
            [questKeys.objectives] = {nil,nil,{{44184}}},
        },

        [12519] = {
            [questKeys.exclusiveTo] = {},
        },

        [12520] = {
            [questKeys.preQuestSingle] = {12525},
        },

        [12524] = {
            [questKeys.objectives] = {{{28123}}},
        },

        [12527] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.questFlags] = 136,
        },

        [12529] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12530] = {
            [questKeys.requiredSourceItems] = {38467},
        },

        [12531] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12532] = {
            [questKeys.requiredSourceItems] = {38689},
            [questKeys.preQuestSingle] = {12533,12534},
        },

        [12533] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {12529,12530},
        },

        [12534] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {12529,12530},
        },

        [12536] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {12531,12535},
        },

        [12537] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {38510},
        },

        [12538] = {
            [questKeys.objectives] = {{{28109}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12539] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {12537,12538},
        },

        [12541] = {
            [questKeys.objectivesText] = {"Alchemist Finklestein at Heb'Valok wants you to assist him in the creation of a truth serum.$b$bWhen you are ready to begin, you are to speak to him and follow his instructions."},
            [questKeys.objectives] = {{{28248}}},
            [questKeys.preQuestSingle] = {12596},
            [questKeys.parentQuest] = 0,
        },

        [12544] = {
            [questKeys.requiredSourceItems] = {38519},
        },

        [12545] = {
            [questKeys.objectives] = {{{28270}}},
            [questKeys.preQuestSingle] = {12542},
        },

        [12546] = {
            [questKeys.objectivesText] = {"Go to the Avalanche in Sholazar Basin and use the Omega Rune to deploy Etymidian.  Use him to slay 200 Scourge Minions, Bythius the Flesh-Shaper, Urgreth of the Thousand Tombs and Hailscorn.","","Speak to the Avatar of Freya in Sholazar Basin when you've completed this task."},
            [questKeys.objectives] = {{{28271},{28212},{28103},{28208}}},
            [questKeys.requiredSourceItems] = {38709},
        },

        [12549] = {
            [questKeys.preQuestSingle] = {12525},
        },

        [12551] = {
            [questKeys.preQuestSingle] = {12520,12549},
        },

        [12553] = {
            [questKeys.nextQuestInChain] = 12555,
        },

        [12555] = {
            [questKeys.objectives] = {{{28289}}},
            [questKeys.requiredSourceItems] = {38515},
        },

        [12557] = {
            [questKeys.objectives] = {{{28293},{28294},{28295},{28296}}},
        },

        [12561] = {
            [questKeys.objectives] = {{{28101},{28108}}},
            [questKeys.preQuestSingle] = {12803},
        },

        [12562] = {
            [questKeys.preQuestSingle] = {},
        },

        [12563] = {
            [questKeys.objectivesText] = {"Commander Kunz at the Argent Stand wants you to visit the four Argent Crusade posts, follow their captain's orders, and then return and report to him.$b$bCaptain Brandon and Captain Rupert are posted at Drak'Sotra, Captain Grondel is posted in Drak'Agal, and Alchemist Finklestein is posted in Heb'Valok."},
            [questKeys.preQuestSingle] = {12596},
            [questKeys.exclusiveTo] = {},
        },

        [12564] = {
            [questKeys.exclusiveTo] = {},
        },

        [12568] = {
            [questKeys.objectives] = {{{28316}}},
            [questKeys.requiredSourceItems] = {38556},
            [questKeys.exclusiveTo] = {},
        },

        [12569] = {
            [questKeys.requiredSourceItems] = {38564},
        },

        [12571] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12572] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12573] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {40364},
            [questKeys.preQuestSingle] = {12571,12572},
        },

        [12574] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {12573},
        },

        [12575] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.specialFlags] = 2,
        },

        [12576] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12577] = {
            [questKeys.preQuestSingle] = {12575,12576},
        },

        [12578] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12579] = {
            [questKeys.requiredSourceItems] = {},
        },

        [12580] = {
            [questKeys.objectives] = {{{28644}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12581] = {
            [questKeys.preQuestSingle] = {12580},
        },

        [12583] = {
            [questKeys.nextQuestInChain] = 12555,
        },

        [12585] = {
            [questKeys.exclusiveTo] = {},
        },

        [12587] = {
            [questKeys.objectivesText] = {"Commander Kunz at the Argent Stand wants you to visit the four Argent Crusade posts, follow their captain's orders, and then return and report to him.$b$bCaptain Brandon and Captain Rupert are posted at Drak'Sotra, Captain Grondel is posted in Drak'Agal, and Alchemist Finklestein is posted in Heb'valok."},
            [questKeys.exclusiveTo] = {},
        },

        [12588] = {
            [questKeys.objectives] = {{{28330}}},
            [questKeys.requiredSourceItems] = {38566},
            [questKeys.exclusiveTo] = {},
            [questKeys.specialFlags] = 33,
        },

        [12589] = {
            [questKeys.objectives] = {{{28053}}},
            [questKeys.requiredSourceItems] = {38573},
            [questKeys.preQuestSingle] = {12525},
        },

        [12591] = {
            [questKeys.objectives] = {{{28352}}},
            [questKeys.requiredSourceItems] = {38574},
            [questKeys.exclusiveTo] = {},
            [questKeys.specialFlags] = 33,
        },

        [12592] = {
            [questKeys.objectives] = {{{28566}}},
        },

        [12594] = {
            [questKeys.exclusiveTo] = {},
        },

        [12595] = {
            [questKeys.preQuestSingle] = {12556},
        },

        [12596] = {
            [questKeys.objectivesText] = {"Commander Kunz at The Argent Stand wants you to visit the four Argent Crusade posts, follow their leaders' orders, and then return and report to him.$b$bCaptain Brandon and Captain Rupert are posted at Drak'Sotra, Southeast of here.$b$bCaptain Grondel is posted in Drak'Agal, due east.$b$bAlchemist Finklestein is posted in Heb'Valok, to the north."},
            [questKeys.preQuestSingle] = {12503,12740},
        },

        [12598] = {
            [questKeys.objectives] = {{{28352}}},
            [questKeys.requiredSourceItems] = {38574},
            [questKeys.nextQuestInChain] = 12555,
        },

        [12601] = {
            [questKeys.objectivesText] = {"Alchemist Finklestein at Heb'valok wants you to assist him in the creation of a truth serum.$b$bWhen you are ready to begin, you are to speak to him and follow his instructions."},
            [questKeys.objectives] = {{{28248}}},
        },

        [12602] = {
            [questKeys.objectivesText] = {"Alchemist Finklestein at Heb'valok wants you to assist him in the creation of a truth serum.$b$bWhen you are ready to begin, you are to speak to him and follow his instructions."},
            [questKeys.objectives] = {{{28248}}},
        },

        [12603] = {
            [questKeys.preQuestSingle] = {12595},
        },

        [12604] = {
            [questKeys.preQuestSingle] = {},
        },

        [12605] = {
            [questKeys.preQuestSingle] = {12595},
        },

        [12606] = {
            [questKeys.objectives] = {{{28415}}},
        },

        [12607] = {
            [questKeys.requiredSourceItems] = {38627},
        },

        [12611] = {
            [questKeys.requiredSourceItems] = {38657},
        },

        [12616] = {
            [questKeys.requiredSourceItems] = {38629},
        },

        [12620] = {
            [questKeys.requiredSourceItems] = {38684},
            [questKeys.preQuestSingle] = {12617},
        },

        [12622] = {
            [questKeys.preQuestSingle] = {},
        },

        [12626] = {
            [questKeys.questLevel] = 55,
            [questKeys.requiredLevel] = 55,
            [questKeys.requiredClasses] = 32,
            [questKeys.objectivesText] = {"Deliver Corvus' Report to Scourge Commander Thalanor at the garrison floor of Ebon Hold."},
            [questKeys.objectives] = {nil,nil,{{38654}}},
            [questKeys.sourceItemId] = 38654,
            [questKeys.questFlags] = 128,
        },

        [12629] = {
            [questKeys.exclusiveTo] = {},
        },

        [12630] = {
            [questKeys.objectivesText] = {"Stefan in Ebon Watch wants you to use Nass to collect 10 hair samples from Withered Trolls.$b$bIf you lose Nass, return to Stefan to recover him."},
            [questKeys.objectives] = {{{28523}}},
            [questKeys.requiredSourceItems] = {38659},
        },

        [12631] = {
            [questKeys.requiredSourceItems] = {38660},
            [questKeys.exclusiveTo] = {},
        },

        [12632] = {
            [questKeys.objectives] = {{{28526}}},
            [questKeys.requiredSourceItems] = {38676},
        },

        [12633] = {
            [questKeys.requiredSourceItems] = {38673},
            [questKeys.exclusiveTo] = {},
        },

        [12635] = {
            [questKeys.preQuestSingle] = {},
        },

        [12637] = {
            [questKeys.requiredSourceItems] = {38678},
            [questKeys.exclusiveTo] = {},
        },

        [12638] = {
            [questKeys.requiredSourceItems] = {38680},
            [questKeys.preQuestSingle] = {12633},
            [questKeys.exclusiveTo] = {},
        },

        [12641] = {
            [questKeys.specialFlags] = 32,
        },

        [12643] = {
            [questKeys.preQuestSingle] = {12638},
            [questKeys.exclusiveTo] = {},
        },

        [12645] = {
            [questKeys.requiredSourceItems] = {38697},
        },

        [12648] = {
            [questKeys.objectivesText] = {"Stefan at Ebon Watch wants you to use the Ensorceled Choker to apply the Scourge disguise.$b$bWhile in Scourge form, you are to purchase Bitter Plasma from Gristlegut.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
        },

        [12649] = {
            [questKeys.objectivesText] = {"Stefan at Ebon Watch wants you to use the Ensorcelled Choker to apply the Scourge disguise.$b$bWhile in Scourge form, you are to purchase Bitter Plasma from Gristlegut.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.preQuestSingle] = {12643},
        },

        [12651] = {
            [questKeys.preQuestSingle] = {12592},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [12652] = {
            [questKeys.requiredRaces] = 1791,
            [questKeys.objectives] = {{{28591}}},
            [questKeys.requiredSourceItems] = {38701},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [12659] = {
            [questKeys.objectives] = {{{28622}}},
            [questKeys.requiredSourceItems] = {38731},
        },

        [12661] = {
            [questKeys.objectivesText] = {"Stefan wants you to use your Ensorcelled Choker to get into Voltarus and do whatever the Scourge leader there asks of you.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.objectives] = {{{28738}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12662] = {
            [questKeys.requiredSourceItems] = {39041},
            [questKeys.preQuestSingle] = {},
        },

        [12663] = {
            [questKeys.objectives] = {{{28663}}},
            [questKeys.preQuestSingle] = {12238,12649},
            [questKeys.parentQuest] = 0,
            [questKeys.exclusiveTo] = {12664},
        },

        [12664] = {
            [questKeys.objectives] = {{{28663}}},
            [questKeys.parentQuest] = 0,
            [questKeys.exclusiveTo] = {12663},
        },

        [12665] = {
            [questKeys.objectives] = nil,
        },

        [12668] = {
            [questKeys.objectives] = {{{28713}}},
        },

        [12669] = {
            [questKeys.objectivesText] = {"Stefan at Ebon Watch wants you to return to Drakuru and complete any tasks he has for you.$b$bWhile at the Reliquary of Pain, you are to use the Diluting Additive on 5 Blight Cauldrons.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.objectives] = {{{28631},{28739}}},
            [questKeys.requiredSourceItems] = {39154},
            [questKeys.specialFlags] = 32,
        },

        [12673] = {
            [questKeys.objectives] = {{{28740}},nil,{{39157}}},
        },

        [12674] = {
            [questKeys.objectives] = {{{28753},{28755},{28757}}},
            [questKeys.requiredSourceItems] = {39158},
        },

        [12675] = {
            [questKeys.objectives] = {nil,nil,{{39166}}},
            [questKeys.questFlags] = 128,
        },

        [12676] = {
            [questKeys.objectivesText] = {"Stefan at Ebon Watch wants you to perform another task for Drakuru.$b$bAdditionally, you are to use the Explosive Charges on 5 Scourgewagons at the  Reliquary of Pain.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.objectives] = {{{28777},{28786},{28928}}},
            [questKeys.requiredSourceItems] = {39165,39319},
        },

        [12677] = {
            [questKeys.objectivesText] = {"Stefan at Ebon Watch wants you to go to Voltarus and complete any tasks Drakuru has for you. While there, you are to steal 5 Harvested Blight Crystals.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.objectives] = {{{28762}},nil,{{39159}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12678] = {
            [questKeys.objectives] = {{{28763},{28764}}},
        },

        [12680] = {
            [questKeys.objectives] = {{{28767}}},
        },

        [12683] = {
            [questKeys.objectives] = {{{28771},{28003}},nil,{{39164}}},
        },

        [12685] = {
            [questKeys.objectives] = {{{28795}}},
            [questKeys.requiredSourceItems] = {39187},
        },

        [12686] = {
            [questKeys.objectives] = {{{28793}},nil,{{39206}}},
        },

        [12687] = {
            [questKeys.objectives] = nil,
        },

        [12690] = {
            [questKeys.objectivesText] = {"Drakuru in Voltarus wants you to use the Scepter of Command on Bloated Abominations and then use their abilities at the Frigid Breach to kill 60 Drakkari Skullcrushers and lure out 3 Drakkari Chieftains.$b$bChieftains will appear when enough Skullcrushers have been slain."},
            [questKeys.objectives] = {{{29099},{28873}},nil,{{39238}}},
            [questKeys.requiredSourceItems] = {},
            [questKeys.exclusiveTo] = {},
        },

        [12692] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.preQuestSingle] = {},
        },

        [12695] = {
            [questKeys.requiredMinRep] = false,
            [questKeys.preQuestSingle] = {},
        },

        [12697] = {
            [questKeys.preQuestSingle] = {12679,12687,12733},
        },

        [12698] = {
            [questKeys.requiredSourceItems] = {39253},
        },

        [12699] = {
            [questKeys.requiredSourceItems] = {40390},
            [questKeys.preQuestSingle] = {},
        },

        [12701] = {
            [questKeys.objectives] = {{{28849}}},
        },

        [12702] = {
            [questKeys.requiredSourceItems] = {38689},
            [questKeys.requiredMinRep] = false,
        },

        [12703] = {
            [questKeys.objectives] = {{{28111}}},
            [questKeys.requiredMinRep] = false,
        },

        [12704] = {
            [questKeys.requiredSourceItems] = {},
            [questKeys.requiredMinRep] = false,
        },

        [12705] = {
            [questKeys.objectives] = {{{28078}}},
            [questKeys.requiredMinRep] = false,
        },

        [12706] = {
            [questKeys.objectives] = {nil,nil,{{39269}}},
        },

        [12707] = {
            [questKeys.objectives] = {{{28876}}},
            [questKeys.requiredSourceItems] = {39268},
        },

        [12710] = {
            [questKeys.objectives] = {{{28929}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12712] = {
            [questKeys.requiredSourceItems] = {39313,39315,39316},
        },

        [12713] = {
            [questKeys.objectivesText] = {"Stefan in Ebon Watch wants you to defeat Drakuru.$b$bIf you lose your Ensorcelled Choker, return to Stefan at Ebon Watch to get another."},
            [questKeys.requiredSourceItems] = {38699,39664,41390,43059},
        },

        [12716] = {
            [questKeys.preQuestSingle] = {},
        },

        [12717] = {
            [questKeys.objectives] = {nil,nil,{{39329}}},
            [questKeys.questFlags] = 128,
        },

        [12719] = {
            [questKeys.objectivesText] = {"Prince Keleseth at the Crypt of Remembrance has ordered you to kill Mayor Quimby and recover the New Avalon Registry. "},
        },

        [12720] = {
            [questKeys.requiredSourceItems] = {39371,39418},
        },

        [12721] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {39434},
        },

        [12722] = {
            [questKeys.objectives] = {{{28984},{28986}}},
        },

        [12723] = {
            [questKeys.preQuestSingle] = {12720},
        },

        [12726] = {
            [questKeys.objectives] = {{{29008},{29009}}},
            [questKeys.requiredSourceItems] = {39571},
            [questKeys.requiredMinRep] = false,
        },

        [12728] = {
            [questKeys.requiredSourceItems] = {34669},
            [questKeys.specialFlags] = 32,
        },

        [12730] = {
            [questKeys.requiredSourceItems] = {39566},
        },

        [12731] = {
            [questKeys.questFlags] = 8328,
        },

        [12732] = {
            [questKeys.requiredSourceItems] = {39573,39574,39576},
            [questKeys.requiredMinRep] = false,
        },

        [12733] = {
            [questKeys.objectives] = {{{29025}}},
        },

        [12734] = {
            [questKeys.objectives] = {{{28040},{36189},{29043}},nil,{{39577}}},
            [questKeys.requiredMinRep] = false,
        },

        [12735] = {
            [questKeys.requiredSourceItems] = {39572},
            [questKeys.requiredMinRep] = false,
        },

        [12736] = {
            [questKeys.requiredSourceItems] = {39598},
            [questKeys.requiredMinRep] = false,
        },

        [12737] = {
            [questKeys.objectives] = {{{29055}}},
            [questKeys.requiredSourceItems] = {39599},
            [questKeys.requiredMinRep] = false,
        },

        [12740] = {
            [questKeys.objectives] = {{{29060}}},
            [questKeys.requiredSourceItems] = {39615},
            [questKeys.nextQuestInChain] = 12596,
        },

        [12741] = {
            [questKeys.requiredMinRep] = false,
        },

        [12754] = {
            [questKeys.requiredSourceItems] = {39645},
        },

        [12755] = {
            [questKeys.objectives] = {nil,nil,{{39647}}},
        },

        [12756] = {
            [questKeys.objectives] = {nil,nil,{{39654}}},
        },

        [12757] = {
            [questKeys.objectivesText] = {"Deliver The Path of Redemption to Highlord Darion Mograine at Acherus: The Ebon Hold. "},
            [questKeys.objectives] = {nil,nil,{{39654}}},
        },

        [12758] = {
            [questKeys.requiredMinRep] = false,
        },

        [12759] = {
            [questKeys.objectivesText] = {"Retrieve some of Zepik's traps from his stash in Kartak's Hold.  Using the traps, slaughter 50 of the nearby Sparktouched Gorlocs, and then return to Shaman Jakjek in Kartak's Hold."},
            [questKeys.objectives] = {{{28111}}},
            [questKeys.requiredMinRep] = false,
        },

        [12760] = {
            [questKeys.objectives] = {{{28111}}},
            [questKeys.requiredSourceItems] = {39737},
            [questKeys.requiredMinRep] = false,
        },

        [12761] = {
            [questKeys.objectives] = {{{28078}}},
            [questKeys.requiredMinRep] = false,
        },

        [12762] = {
            [questKeys.objectives] = {{{28078}},nil,{{39748}}},
            [questKeys.requiredSourceItems] = {39747},
            [questKeys.requiredMinRep] = false,
        },

        [12763] = {
            [questKeys.objectivesText] = {"Scout Vor'takh wants you to travel to Zul'Drak and report to Sergeant Riannah at Light's Breach.$b$bMakki Wintergale in Camp Onequah will provide you transportation."},
        },

        [12770] = {
            [questKeys.objectivesText] = {"Gryan Stoutmantle wants you to report to Sergeant Riannah at Light's Breach in Zul'Drak.$b$bYou may speak to Samuel Clearbook for transportation to Light's Breach."},
        },

        [12771] = {
            [questKeys.objectives] = {nil,nil,{{39698}}},
            [questKeys.preQuestSingle] = {},
        },

        [12773] = {
            [questKeys.objectives] = {nil,nil,{{39698}}},
            [questKeys.preQuestSingle] = {},
        },

        [12774] = {
            [questKeys.objectives] = {nil,nil,{{39698}}},
            [questKeys.preQuestSingle] = {},
        },

        [12776] = {
            [questKeys.objectives] = {nil,nil,{{39698}}},
            [questKeys.preQuestSingle] = {},
        },

        [12779] = {
            [questKeys.objectives] = {{{29150},{29104}}},
            [questKeys.requiredSourceItems] = {39700},
        },

        [12781] = {
            [questKeys.objectives] = {nil,nil,{{39713}}},
        },

        [12785] = {
            [questKeys.objectives] = {nil,nil,{{40482}}},
            [questKeys.preQuestSingle] = {},
        },

        [12786] = {
            [questKeys.objectives] = {nil,nil,{{40482}}},
            [questKeys.preQuestSingle] = {},
        },

        [12787] = {
            [questKeys.objectives] = {nil,nil,{{40482}}},
            [questKeys.preQuestSingle] = {},
        },

        [12788] = {
            [questKeys.objectives] = {nil,nil,{{40482}}},
            [questKeys.preQuestSingle] = {},
        },

        [12791] = {
            [questKeys.objectives] = {nil,nil,{{39740}}},
        },

        [12793] = {
            [questKeys.objectivesText] = {"Khufu in Zim'Torga wants you to travel to Light's Breach and report to Sergeant Riannah there.$b$bMaaka will provide you with transportation there."},
        },

        [12794] = {
            [questKeys.objectives] = {nil,nil,{{39740}}},
        },

        [12795] = {
            [questKeys.breadcrumbForQuestId] = 12503,
        },

        [12796] = {
            [questKeys.objectives] = {nil,nil,{{39740}}},
        },

        [12797] = {
            [questKeys.objectives] = {nil,nil,{{38708}}},
        },

        [12798] = {
            [questKeys.objectives] = {nil,nil,{{42922}}},
        },

        [12801] = {
            [questKeys.objectives] = {{{29245}}},
        },

        [12802] = {
            [questKeys.objectivesText] = {"Drakuru wants you to bring the Heart of the Ancients to him at Drak'atal Passage.$b$bYou will need to collect 5 Desperate Mojo to use the elixir there."},
            [questKeys.requiredSourceItems] = {36739},
            [questKeys.specialFlags] = 2,
        },

        [12804] = {
            [questKeys.preQuestSingle] = {},
        },

        [12805] = {
            [questKeys.objectives] = {{{29303}}},
            [questKeys.requiredSourceItems] = {40397},
        },

        [12806] = {
            [questKeys.preQuestSingle] = {},
        },

        [12807] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {12806},
        },

        [12809] = {
            [questKeys.objectives] = {nil,nil,{{39698}}},
            [questKeys.preQuestSingle] = {},
        },

        [12810] = {
            [questKeys.objectives] = {{{29391}}},
            [questKeys.requiredSourceItems] = {40551},
        },

        [12812] = {
            [questKeys.objectives] = {nil,nil,{{40482}}},
            [questKeys.preQuestSingle] = {},
        },

        [12813] = {
            [questKeys.objectives] = {{{29398}}},
            [questKeys.requiredSourceItems] = {40587},
        },

        [12814] = {
            [questKeys.objectives] = {{{29406}}},
        },

        [12815] = {
            [questKeys.requiredSourceItems] = {40600},
        },

        [12817] = {
            [questKeys.objectivesText] = {"Collect three Dim Necrotic Stones from the Scourge outside the Exodar and investigate the glowing runic circles near their encampment.  Then return to Lieutenant Kregor."},
        },

        [12820] = {
            [questKeys.objectives] = {{{29618}}},
            [questKeys.requiredSourceItems] = {40676},
        },

        [12821] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.preQuestSingle] = {12828},
            [questKeys.questFlags] = 138,
        },

        [12822] = {
            [questKeys.objectives] = {{{29553},{29554}}},
        },

        [12823] = {
            [questKeys.requiredSourceItems] = {41431},
        },

        [12826] = {
            [questKeys.objectives] = {nil,nil,{{40969}}},
        },

        [12828] = {
            [questKeys.preQuestSingle] = {12836},
        },

        [12829] = {
            [questKeys.objectives] = {{{29412}}},
            [questKeys.preQuestSingle] = {},
        },

        [12830] = {
            [questKeys.preQuestSingle] = {},
        },

        [12833] = {
            [questKeys.objectives] = {{{29618}}},
            [questKeys.requiredSourceItems] = {40676},
        },

        [12835] = {
            [questKeys.objectives] = {{{29553},{29554}}},
        },

        [12839] = {
            [questKeys.objectives] = {nil,nil,{{40666}}},
            [questKeys.preQuestSingle] = {},
        },

        [12842] = {
            [questKeys.objectives] = nil,
        },

        [12847] = {
            [questKeys.requiredSourceItems] = {40730},
        },

        [12848] = {
            [questKeys.objectives] = {{{29519}}},
            [questKeys.requiredSourceItems] = {40732},
        },

        [12851] = {
            [questKeys.objectives] = {{{29595},{29597}}},
        },

        [12852] = {
            [questKeys.objectives] = {{{29627}}},
            [questKeys.requiredSourceItems] = {40917},
        },

        [12855] = {
            [questKeys.requiredSourceItems] = {41430},
        },

        [12856] = {
            [questKeys.objectives] = {{{29734},{29709}}},
        },

        [12858] = {
            [questKeys.sourceItemId] = 0,
        },

        [12859] = {
            [questKeys.requiredSourceItems] = {41131},
            [questKeys.specialFlags] = 32,
        },

        [12860] = {
            [questKeys.objectives] = {{{29752}},nil,{{41179}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12863] = {
            [questKeys.objectives] = {nil,nil,{{41336}}},
        },

        [12864] = {
            [questKeys.objectives] = nil,
        },

        [12865] = {
            [questKeys.objectives] = {{{29816}}},
        },

        [12869] = {
            [questKeys.objectives] = {{{29753}},nil,{{42159}}},
            [questKeys.preQuestSingle] = {12867},
        },

        [12871] = {
            [questKeys.objectives] = {nil,nil,{{41258}}},
        },

        [12872] = {
            [questKeys.requiredSourceItems] = {44704},
        },

        [12876] = {
            [questKeys.objectives] = {{{29586}}},
        },

        [12879] = {
            [questKeys.objectives] = {nil,nil,{{41260}}},
        },

        [12880] = {
            [questKeys.objectives] = {nil,nil,{{41260}}},
        },

        [12883] = {
            [questKeys.objectives] = {nil,nil,{{41262}}},
        },

        [12884] = {
            [questKeys.objectives] = {nil,nil,{{41262}}},
        },

        [12885] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.exclusiveTo] = {},
            [questKeys.breadcrumbForQuestId] = 12930,
        },

        [12886] = {
            [questKeys.objectivesText] = {"Use the Hyldnir Harpoon to defeat 10 Hyldsmeet Drakeriders at the Temple of Storms.  Use the Hyldnir Harpoon on a Column Ornament to exit the Drakkensryd and speak to Thorim when you've succeeded."},
            [questKeys.objectives] = {{{29800}}},
            [questKeys.requiredSourceItems] = {41058},
        },

        [12887] = {
            [questKeys.objectives] = {{{29803}}},
            [questKeys.requiredSourceItems] = {41265},
            [questKeys.questFlags] = 128,
        },

        [12888] = {
            [questKeys.objectives] = {nil,nil,{{39681},{39682},{41267}}},
        },

        [12889] = {
            [questKeys.requiredSkill] = {},
        },

        [12892] = {
            [questKeys.objectives] = {{{29803}}},
            [questKeys.requiredSourceItems] = {41265},
        },

        [12893] = {
            [questKeys.objectives] = {{{29845},{29846},{29847}}},
            [questKeys.requiredSourceItems] = {41366},
        },

        [12904] = {
            [questKeys.objectives] = {{{29882}}},
        },

        [12906] = {
            [questKeys.objectives] = {{{29886}}},
            [questKeys.requiredSourceItems] = {42837},
        },

        [12908] = {
            [questKeys.objectives] = {nil,nil,{{41428}}},
        },

        [12910] = {
            [questKeys.sourceItemId] = 0,
        },

        [12913] = {
            [questKeys.sourceItemId] = 0,
        },

        [12915] = {
            [questKeys.objectivesText] = {"Thorim at the Temple of Storms wants you to Kill Fjorn and 5 Stormforged Iron Giants at Fjorn's Anvil, east of Dun Niffelem.$b$bUsing Thorim's Charm of Earth will summon his Earthen to fight by your side. The charm requires a Granite Boulder from nearby Fjorn's Anvil."},
            [questKeys.requiredSourceItems] = {41505,41506},
        },

        [12916] = {
            [questKeys.objectives] = {{{29928}}},
            [questKeys.requiredSourceItems] = {41507},
            [questKeys.questFlags] = 128,
        },

        [12919] = {
            [questKeys.objectives] = {{{29943},{29872},{29895},{29821}}},
        },

        [12922] = {
            [questKeys.objectives] = {nil,nil,{{41556},{41558}}},
        },

        [12923] = {
            [questKeys.questLevel] = 79,
            [questKeys.requiredLevel] = 77,
            [questKeys.questFlags] = 136,
        },

        [12924] = {
            [questKeys.objectives] = {{{30126}}},
            [questKeys.requiredSourceItems] = {41557},
        },

        [12925] = {
            [questKeys.objectivesText] = {"Thyra Kvinnshal in Brunnhildar Village wants you to go to Valkyrion and obtain Vials of Frost Oil from the Valkyrion Aspirants.  Use the Vials of Frost Oil to destroy 30 Plagued Proto-Drake Eggs."},
            [questKeys.preQuestSingle] = {},
        },

        [12926] = {
            [questKeys.sourceItemId] = 0,
        },

        [12927] = {
            [questKeys.objectivesText] = {"Use the Inventor's Disk to retrieve 7 pieces of Hidden Data from the Databanks. "},
            [questKeys.objectives] = {{{29752}},nil,{{41179}}},
            [questKeys.requiredSourceItems] = {},
        },

        [12928] = {
            [questKeys.requiredSourceItems] = {44704},
        },

        [12929] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [12930] = {
            [questKeys.requiredSourceItems] = {41615},
            [questKeys.nextQuestInChain] = 12931,
            [questKeys.breadcrumbs] = {12885},
        },

        [12931] = {
            [questKeys.objectives] = {{{29377}}},
        },

        [12932] = {
            [questKeys.objectives] = nil,
            [questKeys.exclusiveTo] = {12954},
            [questKeys.nextQuestInChain] = 0,
        },

        [12933] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {},
        },

        [12935] = {
            [questKeys.objectives] = nil,
        },

        [12936] = {
            [questKeys.objectives] = nil,
        },

        [12937] = {
            [questKeys.requiredSourceItems] = {41988},
        },

        [12939] = {
            [questKeys.objectives] = {{{30038}}},
            [questKeys.requiredSourceItems] = {41372},
        },

        [12940] = {
            [questKeys.questFlags] = 65536,
        },

        [12941] = {
            [questKeys.questFlags] = 65536,
        },

        [12942] = {
            [questKeys.preQuestSingle] = {},
        },

        [12943] = {
            [questKeys.requiredSourceItems] = {41776},
        },

        [12944] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [12945] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [12946] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [12947] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [12948] = {
            [questKeys.objectives] = nil,
        },

        [12950] = {
            [questKeys.questFlags] = 65536,
        },

        [12953] = {
            [questKeys.requiredSourceItems] = {42160},
            [questKeys.preQuestSingle] = {},
        },

        [12954] = {
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
        },

        [12956] = {
            [questKeys.objectives] = {nil,nil,{{41557}}},
        },

        [12957] = {
            [questKeys.objectives] = {{{29962},{29369}}},
        },

        [12966] = {
            [questKeys.requiredMinRep] = false,
        },

        [12967] = {
            [questKeys.objectives] = {{{30125}}},
        },

        [12968] = {
            [questKeys.preQuestSingle] = {},
        },

        [12969] = {
            [questKeys.objectivesText] = {"Challenge Agnetta Tyrsdottar in order to save Zeev Fizzlespark.  Return to Lok'lira the Crone in Brunnhildar Village after you've succeeded."},
        },

        [12973] = {
            [questKeys.objectives] = nil,
        },

        [12974] = {
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 12932,
        },

        [12975] = {
            [questKeys.requiredMinRep] = {1119,3000},
            [questKeys.preQuestSingle] = {},
        },

        [12976] = {
            [questKeys.objectives] = {nil,nil,{{42163}}},
        },

        [12977] = {
            [questKeys.objectives] = {{{30138},{30139}}},
            [questKeys.requiredSourceItems] = {42164},
            [questKeys.requiredMinRep] = {1119,0},
        },

        [12978] = {
            [questKeys.objectives] = {{{30152}}},
        },

        [12980] = {
            [questKeys.objectives] = {{{30190}},nil,{{42394}}},
        },

        [12981] = {
            [questKeys.requiredMinRep] = {1119,0},
        },

        [12982] = {
            [questKeys.objectives] = {{{30186}}},
        },

        [12983] = {
            [questKeys.requiredSourceItems] = {42838},
        },

        [12984] = {
            [questKeys.requiredSourceItems] = {42419},
        },

        [12985] = {
            [questKeys.requiredSourceItems] = {42424},
        },

        [12986] = {
            [questKeys.requiredSourceItems] = {42679},
        },

        [12987] = {
            [questKeys.requiredSourceItems] = {42442},
        },

        [12988] = {
            [questKeys.requiredSourceItems] = {42441},
        },

        [12989] = {
            [questKeys.objectives] = {{{29605}}},
        },

        [12992] = {
            [questKeys.objectives] = {{{29880}}},
            [questKeys.preQuestSingle] = {},
        },

        [12994] = {
            [questKeys.objectivesText] = {"You must defeat 3 Stormforged Spies in the Valley of Ancient Winters.$b$bUsing the Ethereal Worg's Fang at the Corpse of the Fallen Worg will summon an Ethereal Frostworg, which will expose hidden enemies. You are to return to the Frostworg Denmother in Dun Niffelem when the valley has been cleansed of spies."},
            [questKeys.requiredSourceItems] = {42479},
        },

        [12995] = {
            [questKeys.objectives] = {{{30220}}},
            [questKeys.requiredSourceItems] = {42480},
            [questKeys.preQuestSingle] = {13084},
        },

        [12996] = {
            [questKeys.objectives] = {{{30221}}},
            [questKeys.requiredSourceItems] = {42481},
        },

        [12997] = {
            [questKeys.requiredSourceItems] = {42499},
        },

        [12998] = {
            [questKeys.objectives] = {{{30299}}},
        },

        [13000] = {
            [questKeys.requiredSourceItems] = {44576},
        },

        [13003] = {
            [questKeys.objectives] = {{{30415}}},
            [questKeys.requiredSourceItems] = {42769},
            [questKeys.requiredMinRep] = {1119,9000},
        },

        [13005] = {
            [questKeys.objectives] = {{{30296},{30297}}},
        },

        [13006] = {
            [questKeys.objectivesText] = {"You are to enter Hibernal Cavern west of Dun Niffelem and collect 5 units of Viscous Oil from the Viscous Oils there.$b$bYou are then to return to Dun Niffelem and apply the oil to Hodir's Helm."},
        },

        [13008] = {
            [questKeys.objectives] = {{{30274}}},
        },

        [13009] = {
            [questKeys.objectives] = {nil,nil,{{42700}}},
        },

        [13010] = {
            [questKeys.objectives] = {{{30327}}},
        },

        [13011] = {
            [questKeys.objectivesText] = {"King Jokkum in Dun Niffelem wants you to slay Jormuttar in Hibernal Cavern."},
            [questKeys.requiredSourceItems] = {42732},
        },

        [13034] = {
            [questKeys.preQuestSingle] = {13426},
            [questKeys.nextQuestInChain] = 0,
        },

        [13035] = {
            [questKeys.nextQuestInChain] = 13047,
        },

        [13036] = {
            [questKeys.breadcrumbs] = {13226,13227},
        },

        [13037] = {
            [questKeys.objectives] = {{{30381}}},
            [questKeys.preQuestSingle] = {},
        },

        [13038] = {
            [questKeys.objectives] = {{{30444}},nil,{{42781}}},
            [questKeys.preQuestSingle] = {},
        },

        [13039] = {
            [questKeys.objectives] = {{{30402}}},
        },

        [13042] = {
            [questKeys.objectives] = {{{30412},{30409}}},
        },

        [13043] = {
            [questKeys.requiredSourceItems] = {42772},
            [questKeys.preQuestSingle] = {},
        },

        [13044] = {
            [questKeys.preQuestSingle] = {13008,13039,13040},
        },

        [13046] = {
            [questKeys.objectivesText] = {"You are to feed Arngrim 5 Disembodied Jormungar, then return to Arngrim's frozen image in Dun Niffelem.$b$bYou must go to the Valley of Ancient Winters and use Arngrim's Tooth on the Roaming Jormungar there. Once they have become disembodied, you must fight them until they are weakened."},
            [questKeys.objectives] = {{{30421}}},
            [questKeys.requiredSourceItems] = {42774},
        },

        [13047] = {
            [questKeys.objectivesText] = {"Meet Thorim near the Temple of Wisdom.  Report the outcome of the fight to King Jokkum in Dun Niffelem."},
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {13005,13035},
        },

        [13048] = {
            [questKeys.objectives] = {{{30395}},nil,{{42839}}},
        },

        [13051] = {
            [questKeys.requiredSourceItems] = {42797},
        },

        [13052] = {
            [questKeys.preQuestSingle] = {12523},
        },

        [13058] = {
            [questKeys.objectives] = {nil,{{194123}},{{42918}}},
        },

        [13059] = {
            [questKeys.objectives] = {{{32821},{30475}}},
            [questKeys.requiredSourceItems] = {42928},
            [questKeys.preQuestSingle] = {},
        },

        [13068] = {
            [questKeys.objectivesText] = {"Highlord Tirion Fordring at Crusaders' Pinnacle has requested that you locate the hero, Crusader Bridenbrad at the Silent Vigil, in northeast Icecrown.  His fire pit will likely be the most obvious indication of his location from the air."},
            [questKeys.preQuestSingle] = {},
        },

        [13069] = {
            [questKeys.preQuestSingle] = {},
        },

        [13075] = {
            [questKeys.objectives] = {nil,nil,{{44790}}},
            [questKeys.questFlags] = 128,
        },

        [13079] = {
            [questKeys.objectives] = {nil,nil,{{43096}}},
            [questKeys.questFlags] = 128,
        },

        [13083] = {
            [questKeys.objectives] = {nil,nil,{{44789}}},
        },

        [13084] = {
            [questKeys.preQuestSingle] = {},
        },

        [13085] = {
            [questKeys.preQuestSingle] = {12992,13084},
        },

        [13086] = {
            [questKeys.objectives] = {{{30670},{30575}}},
        },

        [13087] = {
            [questKeys.objectivesText] = {"Bring four chilled meat to Brom Brewbaster at Valgarde.   Chilled meat can be found on any Northrend beast."},
        },

        [13088] = {
            [questKeys.objectivesText] = {"Bring four chilled meat to Rollick Mackreel at Valiance Keep.   Chilled meat can be found on any Northrend beast."},
        },

        [13089] = {
            [questKeys.objectivesText] = {"Bring four chilled meat to Thomas Kolichio at Vengeance Landing.   Chilled meat can be found on any Northrend beast."},
        },

        [13090] = {
            [questKeys.objectivesText] = {"Bring four chilled meat to Orn Tenderhoof at Warsong Hold.   Chilled meat can be found on any Northrend beast."},
        },

        [13091] = {
            [questKeys.objectives] = {{{30644}}},
        },

        [13092] = {
            [questKeys.preQuestSingle] = {},
        },

        [13093] = {
            [questKeys.questFlags] = 8584,
        },

        [13098] = {
            [questKeys.preQuestSingle] = {13099},
        },

        [13104] = {
            [questKeys.exclusiveTo] = {13105},
        },

        [13105] = {
            [questKeys.exclusiveTo] = {13104},
        },

        [13106] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13110] = {
            [questKeys.objectives] = {{{30546}}},
            [questKeys.requiredSourceItems] = {43153},
            [questKeys.preQuestSingle] = {},
            [questKeys.specialFlags] = 32,
        },

        [13117] = {
            [questKeys.preQuestSingle] = {13106},
        },

        [13118] = {
            [questKeys.preQuestSingle] = {},
        },

        [13119] = {
            [questKeys.specialFlags] = 32,
        },

        [13120] = {
            [questKeys.requiredSourceItems] = {43229},
        },

        [13121] = {
            [questKeys.objectives] = {{{30750}}},
        },

        [13122] = {
            [questKeys.preQuestSingle] = {},
        },

        [13124] = {
            [questKeys.objectivesText] = {"Raelorasz wants you to enter the Oculus and rescue Belgaristrasz  and his companions."},
        },

        [13125] = {
            [questKeys.requiredSourceItems] = {43206},
            [questKeys.preQuestSingle] = {13118,13122},
        },

        [13130] = {
            [questKeys.preQuestSingle] = {},
        },

        [13133] = {
            [questKeys.objectives] = {{{30880}}},
            [questKeys.requiredSourceItems] = {43166},
        },

        [13134] = {
            [questKeys.preQuestSingle] = {13119,13120},
        },

        [13135] = {
            [questKeys.preQuestSingle] = {},
        },

        [13138] = {
            [questKeys.requiredSourceItems] = {43289},
        },

        [13139] = {
            [questKeys.objectives] = {nil,nil,{{43290}}},
            [questKeys.preQuestSingle] = {13110,13125,13130,13135},
        },

        [13141] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {43243},
        },

        [13143] = {
            [questKeys.objectives] = {{{31049}}},
            [questKeys.requiredSourceItems] = {43315},
        },

        [13144] = {
            [questKeys.objectives] = {{{30995}}},
            [questKeys.preQuestSingle] = {13152,13211},
        },

        [13147] = {
            [questKeys.objectives] = {{{31481}}},
        },

        [13149] = {
            [questKeys.requiredSourceItems] = {37888},
        },

        [13151] = {
            [questKeys.objectives] = {{{31006}}},
        },

        [13152] = {
            [questKeys.objectives] = {{{30993}},{{193025}}},
            [questKeys.specialFlags] = 0,
        },

        [13153] = {
            [questKeys.exclusiveTo] = {13198},
        },

        [13154] = {
            [questKeys.exclusiveTo] = {13196},
        },

        [13155] = {
            [questKeys.preQuestSingle] = {13172,13174},
        },

        [13156] = {
            [questKeys.exclusiveTo] = {13195},
        },

        [13161] = {
            [questKeys.preQuestSingle] = {},
        },

        [13162] = {
            [questKeys.preQuestSingle] = {},
        },

        [13163] = {
            [questKeys.preQuestSingle] = {},
        },

        [13164] = {
            [questKeys.preQuestSingle] = {13161,13162,13163},
        },

        [13166] = {
            [questKeys.objectives] = {{{31099},{31100}}},
        },

        [13169] = {
            [questKeys.objectives] = {{{31119}}},
            [questKeys.preQuestSingle] = {},
        },

        [13170] = {
            [questKeys.preQuestSingle] = {},
        },

        [13171] = {
            [questKeys.preQuestSingle] = {},
        },

        [13172] = {
            [questKeys.objectives] = {{{31555}}},
        },

        [13177] = {
            [questKeys.objectives] = {{{39019}}},
        },

        [13178] = {
            [questKeys.objectives] = {{{31086}}},
        },

        [13179] = {
            [questKeys.objectives] = {{{39019}}},
        },

        [13180] = {
            [questKeys.objectives] = {{{31086}}},
        },

        [13183] = {
            [questKeys.specialFlags] = 3,
        },

        [13185] = {
            [questKeys.objectives] = {{{31093}}},
        },

        [13186] = {
            [questKeys.objectives] = {{{31093}}},
        },

        [13188] = {
            [questKeys.objectives] = {nil,nil,{{43440}}},
        },

        [13189] = {
            [questKeys.objectives] = {nil,nil,{{43441}}},
            [questKeys.questFlags] = 384,
        },

        [13190] = {
            [questKeys.objectivesText] = {"Kilix the Unraveler in the Pit of Narjun wants you to obtain an Ahn'kahar Watcher's Corpse and place it upon the Ahn'kahet Brazier in Ahn'kahet.$b$bThis quest can only be completed on Heroic Difficulty."},
            [questKeys.objectives] = {{{31105}}},
            [questKeys.requiredSourceItems] = {},
        },

        [13191] = {
            [questKeys.exclusiveTo] = {13200},
        },

        [13192] = {
            [questKeys.exclusiveTo] = {13202},
        },

        [13193] = {
            [questKeys.exclusiveTo] = {13199},
        },

        [13194] = {
            [questKeys.exclusiveTo] = {13201},
        },

        [13195] = {
            [questKeys.exclusiveTo] = {13156},
        },

        [13196] = {
            [questKeys.exclusiveTo] = {13154},
        },

        [13197] = {
            [questKeys.exclusiveTo] = {236},
        },

        [13198] = {
            [questKeys.exclusiveTo] = {13153},
        },

        [13199] = {
            [questKeys.exclusiveTo] = {13193},
        },

        [13200] = {
            [questKeys.exclusiveTo] = {13191},
        },

        [13201] = {
            [questKeys.exclusiveTo] = {13194},
        },

        [13202] = {
            [questKeys.exclusiveTo] = {13192},
        },

        [13203] = {
            [questKeys.exclusiveTo] = {},
        },

        [13211] = {
            [questKeys.requiredSourceItems] = {43524},
            [questKeys.specialFlags] = 32,
        },

        [13215] = {
            [questKeys.objectives] = nil,
        },

        [13216] = {
            [questKeys.objectives] = nil,
        },

        [13217] = {
            [questKeys.objectives] = nil,
        },

        [13218] = {
            [questKeys.objectives] = nil,
        },

        [13219] = {
            [questKeys.objectives] = nil,
        },

        [13220] = {
            [questKeys.requiredSourceItems] = {43564,43567,43568},
        },

        [13224] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {13225},
        },

        [13225] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {13224},
        },

        [13226] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 13036,
        },

        [13227] = {
            [questKeys.nextQuestInChain] = 0,
            [questKeys.breadcrumbForQuestId] = 13036,
        },

        [13228] = {
            [questKeys.objectives] = {{{31272}}},
        },

        [13230] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 0,
        },

        [13231] = {
            [questKeys.objectives] = {{{31312}}},
        },

        [13232] = {
            [questKeys.objectives] = {{{31312}}},
            [questKeys.preQuestSingle] = {},
            [questKeys.parentQuest] = 0,
        },

        [13236] = {
            [questKeys.objectives] = {{{31329}}},
        },

        [13239] = {
            [questKeys.objectivesText] = {"Chief Engineer Copperclaw wants you to use Copperclaw's Volatile Oil at the Broken Front to attract 3 Frostbrood Skytalons.$b$bTo use the oil, you must collect a Pile of Bones, an Abandoned Helm, and Abandoned Armor from the battlefield there."},
            [questKeys.objectives] = {{{31364}}},
            [questKeys.requiredSourceItems] = {43608,43609,43610,43616},
        },

        [13240] = {
            [questKeys.exclusiveTo] = {13241,13243,13244},
        },

        [13241] = {
            [questKeys.exclusiveTo] = {13240,13243,13244},
        },

        [13242] = {
            [questKeys.preQuestSingle] = {},
        },

        [13243] = {
            [questKeys.exclusiveTo] = {13240,13241,13244},
        },

        [13244] = {
            [questKeys.exclusiveTo] = {13240,13241,13243},
        },

        [13245] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Axe of the Plunderer.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13246] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with Keristrasza's Broken Heart.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13247] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with a Ley Line Tuner.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13248] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Locket of the Deceased Queen.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13249] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Prophet's Enchanted Tiki.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13250] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Mojo Remnant of Akali.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13251] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Artifact from the Nathrezim Homeworld.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13252] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Curse of Flesh Disc.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13253] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Celestial Ruby Ring.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13254] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Idle Crown of Anub'arak.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13255] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Faceless One's Withered Brain.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13256] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with the Head of Cyanigosa.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [13261] = {
            [questKeys.objectivesText] = {"Chief Engineer Copperclaw wants you to use Copperclaw's Volatile Oil at the Broken Front to attract 3 Frostbrood Skytalons.$b$bTo use the oil, you must collect a Pile of Bones, an Abandoned Helm, and Abandoned Armor from the battlefield there."},
            [questKeys.objectives] = {{{31364}}},
            [questKeys.requiredSourceItems] = {43608,43609,43610,43616},
            [questKeys.preQuestSingle] = {13329},
        },

        [13264] = {
            [questKeys.objectives] = {{{31743},{32168},{32167}}},
            [questKeys.requiredSourceItems] = {43966,43968},
        },

        [13267] = {
            [questKeys.specialFlags] = 2,
        },

        [13273] = {
            [questKeys.sourceItemId] = 0,
        },

        [13274] = {
            [questKeys.sourceItemId] = 0,
        },

        [13276] = {
            [questKeys.objectives] = {{{31743},{32168},{32167}}},
            [questKeys.requiredSourceItems] = {43966,43968},
        },

        [13279] = {
            [questKeys.objectives] = {{{31767}}},
            [questKeys.requiredSourceItems] = {44010},
        },

        [13281] = {
            [questKeys.objectivesText] = {"Koltira Deathweaver aboard Orgrim's Hammer wants you use Pustulant Spinal Fluid on a blight cauldron at Mord'rethar.$b$bYou can create Pustulant Spinal Fluid by using a Giant Spine collected from a Pustulant Horror."},
            [questKeys.objectives] = {{{31767}}},
        },

        [13284] = {
            [questKeys.objectives] = {{{31794}}},
        },

        [13285] = {
            [questKeys.sourceItemId] = 0,
            [questKeys.requiredSourceItems] = {40971},
        },

        [13288] = {
            [questKeys.objectives] = {{{31743},{32168},{32167}}},
            [questKeys.requiredSourceItems] = {43966,43968},
        },

        [13289] = {
            [questKeys.objectives] = {{{31743},{32168},{32167}}},
            [questKeys.requiredSourceItems] = {43966,43968},
        },

        [13291] = {
            [questKeys.objectivesText] = {"Chief Engineer Boltwrench aboard the Skybreaker wants you to use the Smuggled Solution at the Broken Front.$b$bUsing the solution will require an Abandoned Helm, Abandoned Armor, and Pile of Bones, all found at the Broken Front."},
            [questKeys.objectives] = {{{31364}}},
            [questKeys.requiredSourceItems] = {43609,43610,43616,44048},
        },

        [13292] = {
            [questKeys.objectivesText] = {"Chief Engineer Boltwrench aboard the Skybreaker wants you to use the Smuggled Solution at the Broken Front.$b$bUsing the solution will require an Abandoned Helm, Abandoned Armor, and Pile of Bones, all found at the Broken Front."},
            [questKeys.objectives] = {{{31364}}},
            [questKeys.requiredSourceItems] = {43609,43610,43616,44048},
        },

        [13295] = {
            [questKeys.objectives] = {{{31767}}},
            [questKeys.requiredSourceItems] = {44010},
        },

        [13297] = {
            [questKeys.objectivesText] = {"Thassarian aboard the Skybreaker wants you use Pustulant Spinal Fluid on a plague cauldron at Mord'rethar.$b$bYou can create Pustulant Spinal Fluid by using a Giant Spine collected from a Pustulant Horror."},
            [questKeys.objectives] = {{{31767}}},
        },

        [13300] = {
            [questKeys.objectives] = {{{31866}}},
        },

        [13301] = {
            [questKeys.objectives] = {{{31845}}},
        },

        [13302] = {
            [questKeys.objectives] = {{{31866}}},
        },

        [13303] = {
            [questKeys.questLevel] = 75,
            [questKeys.objectives] = {nil,nil,{{192}}},
            [questKeys.questFlags] = 128,
        },

        [13305] = {
            [questKeys.objectivesText] = {"Use the Refurbished Demolisher to destroy 150 Decomposed Ghouls, 20 Frostskull Mages and 2 Bone Giants in the Valley of Lost Hope.  Speak to Matthias Lehner at the First Legion Forward Camp when you've completed this task."},
        },

        [13306] = {
            [questKeys.requiredSourceItems] = {44127},
        },

        [13309] = {
            [questKeys.objectives] = {{{32224}}},
        },

        [13310] = {
            [questKeys.objectives] = {{{31888}}},
        },

        [13311] = {
            [questKeys.objectives] = {nil,nil,{{44185}}},
        },

        [13312] = {
            [questKeys.requiredSourceItems] = {44186},
            [questKeys.preQuestSingle] = {13306,13367},
        },

        [13313] = {
            [questKeys.requiredSourceItems] = {44212},
        },

        [13314] = {
            [questKeys.requiredSourceItems] = {44222},
        },

        [13315] = {
            [questKeys.objectivesText] = {"Thassarian, aboard the Skybreaker, wants you to fly down to the gate of desolation, visiting the south, central, north, and northwest regions of the gate. "},
        },

        [13318] = {
            [questKeys.objectives] = {{{32229}}},
        },

        [13320] = {
            [questKeys.objectives] = {{{32242},{32244},{32245}},nil,{{44251}}},
        },

        [13321] = {
            [questKeys.requiredSourceItems] = {44301,44304,44307},
        },

        [13322] = {
            [questKeys.requiredSourceItems] = {44301,44304,44307},
        },

        [13323] = {
            [questKeys.objectives] = {{{32229}}},
        },

        [13324] = {
            [questKeys.objectives] = {nil,nil,{{44259}}},
        },

        [13325] = {
            [questKeys.objectives] = {nil,nil,{{44276}}},
        },

        [13326] = {
            [questKeys.objectives] = {nil,nil,{{44326}}},
        },

        [13327] = {
            [questKeys.objectives] = {nil,nil,{{44294}}},
        },

        [13329] = {
            [questKeys.objectives] = {{{32288}}},
            [questKeys.requiredSourceItems] = {44653},
            [questKeys.preQuestSingle] = {13307,13312},
        },

        [13330] = {
            [questKeys.objectives] = {{{31258}}},
        },

        [13331] = {
            [questKeys.requiredSourceItems] = {44212},
        },

        [13332] = {
            [questKeys.requiredSourceItems] = {44127},
        },

        [13333] = {
            [questKeys.requiredSourceItems] = {44222},
        },

        [13335] = {
            [questKeys.objectives] = {{{32288}}},
            [questKeys.requiredSourceItems] = {44653},
            [questKeys.preQuestSingle] = {13334,13337},
        },

        [13336] = {
            [questKeys.objectives] = {{{31258}}},
        },

        [13337] = {
            [questKeys.requiredSourceItems] = {44186},
        },

        [13342] = {
            [questKeys.objectives] = {{{32314}}},
            [questKeys.requiredSourceItems] = {44433,44434},
        },

        [13343] = {
            [questKeys.objectives] = nil,
            [questKeys.requiredSourceItems] = {44450},
        },

        [13344] = {
            [questKeys.objectives] = {{{32314}}},
            [questKeys.requiredSourceItems] = {44433,44434},
        },

        [13346] = {
            [questKeys.requiredSourceItems] = {44476,44477,44478,44479},
        },

        [13347] = {
            [questKeys.preQuestSingle] = {},
        },

        [13350] = {
            [questKeys.requiredSourceItems] = {44476,44477,44478,44479},
        },

        [13351] = {
            [questKeys.objectivesText] = {"Koltira, aboard Orgrim's Hammer, wants you to fly down to the gate of desolation, visiting the south, central, north, and northwest regions of the gate. "},
        },

        [13352] = {
            [questKeys.objectives] = {{{32229}}},
        },

        [13353] = {
            [questKeys.objectives] = {{{32229}}},
        },

        [13355] = {
            [questKeys.objectives] = {{{32242},{32244},{32245}},nil,{{44251}}},
        },

        [13356] = {
            [questKeys.requiredSourceItems] = {44301,44304,44307},
        },

        [13357] = {
            [questKeys.requiredSourceItems] = {44301,44304,44307},
        },

        [13358] = {
            [questKeys.objectives] = {{{32314}}},
            [questKeys.requiredSourceItems] = {44433,44434},
        },

        [13359] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [13361] = {
            [questKeys.objectives] = {{{32797}}},
        },

        [13365] = {
            [questKeys.objectives] = {{{32314}}},
            [questKeys.requiredSourceItems] = {44433,44434},
        },

        [13367] = {
            [questKeys.requiredSourceItems] = {44476,44477,44478,44479},
        },

        [13368] = {
            [questKeys.requiredSourceItems] = {44476,44477,44478,44479},
        },

        [13372] = {
            [questKeys.objectives] = {nil,nil,{{44569}}},
        },

        [13373] = {
            [questKeys.objectives] = {{{32399},{32410},{32188}}},
        },

        [13374] = {
            [questKeys.objectives] = {{{32399},{32188},{32154},{31721}}},
        },

        [13375] = {
            [questKeys.objectives] = {nil,nil,{{44577}}},
        },

        [13376] = {
            [questKeys.objectives] = {{{32399},{32188},{32154},{31721}}},
        },

        [13377] = {
            [questKeys.objectives] = nil,
        },

        [13380] = {
            [questKeys.objectives] = {{{32399},{32410},{32188}}},
        },

        [13381] = {
            [questKeys.objectives] = {{{32399},{32188},{32154},{31721}}},
        },

        [13382] = {
            [questKeys.objectives] = {{{32399},{32188},{32154},{31721}}},
        },

        [13394] = {
            [questKeys.objectivesText] = {"Use the Refurbished Demolisher to destroy 150 Decomposed Ghouls, 20 Frostskull Mages and 2 Bone Giants in the Valley of Lost Hope.  Speak to Matthias Lehner at the First Legion Forward Camp when you've completed this task."},
        },

        [13395] = {
            [questKeys.objectives] = {{{31329}}},
        },

        [13400] = {
            [questKeys.objectives] = {{{32797}}},
        },

        [13404] = {
            [questKeys.objectives] = {{{32399},{32410},{32188}}},
        },

        [13406] = {
            [questKeys.objectives] = {{{32399},{32410},{32188}}},
        },

        [13408] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.preQuestSingle] = {10143},
            [questKeys.nextQuestInChain] = 0,
        },

        [13409] = {
            [questKeys.requiredClasses] = 0,
            [questKeys.nextQuestInChain] = 0,
        },

        [13410] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [13411] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [13415] = {
            [questKeys.objectives] = {nil,nil,{{41197}}},
            [questKeys.requiredSourceItems] = {},
        },

        [13416] = {
            [questKeys.objectives] = {nil,nil,{{41197}}},
            [questKeys.requiredSourceItems] = {},
        },

        [13420] = {
            [questKeys.requiredSourceItems] = {44724},
        },

        [13421] = {
            [questKeys.requiredMinRep] = {1119,3000},
        },

        [13422] = {
            [questKeys.objectives] = {{{29886}}},
            [questKeys.requiredSourceItems] = {42837},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13423] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13424] = {
            [questKeys.requiredSourceItems] = {42499},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13425] = {
            [questKeys.objectivesText] = {"Gretta the Arbiter in Brunnhildar Village wants you to go to Valkyrion and obtain Vials of Frost Oil from the Valkyrion Aspirants.  Use the Vials of Frost Oil to destroy 30 Plagued Proto-Drake Eggs."},
            [questKeys.exclusiveTo] = {},
        },

        [13426] = {
            [questKeys.preQuestSingle] = {},
        },

        [13427] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [13428] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [13429] = {
            [questKeys.exclusiveTo] = {},
        },

        [13431] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13432] = {
            [questKeys.exclusiveTo] = {},
        },

        [13433] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13434] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13435] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13436] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13437] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13438] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13439] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13448] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13452] = {
            [questKeys.questFlags] = 65536,
        },

        [13456] = {
            [questKeys.questFlags] = 65536,
        },

        [13459] = {
            [questKeys.questFlags] = 65536,
        },

        [13460] = {
            [questKeys.questFlags] = 65536,
        },

        [13461] = {
            [questKeys.questFlags] = 65536,
        },

        [13462] = {
            [questKeys.questFlags] = 65536,
        },

        [13463] = {
            [questKeys.questFlags] = 65536,
        },

        [13464] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13465] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13466] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13467] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13468] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13469] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13470] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13471] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13472] = {
            [questKeys.questFlags] = 65536,
        },

        [13473] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13474] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13475] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectives] = {nil,nil,{{20558},{20559},{20560}}},
            [questKeys.preQuestSingle] = {13476},
            [questKeys.specialFlags] = 1,
        },

        [13476] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectivesText] = {"Bring 3 Alterac Valley Marks of Honor, 3 Arathi Basin Marks of Honor and 3 Warsong Gulch Marks of Honor to a Horde Warbringer outside the battlegrounds."},
            [questKeys.objectives] = {nil,nil,{{20558},{20559},{20560}}},
        },

        [13477] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectives] = {nil,nil,{{20558},{20559},{20560}}},
            [questKeys.preQuestSingle] = {13478},
            [questKeys.specialFlags] = 1,
        },

        [13478] = {
            [questKeys.requiredLevel] = 51,
            [questKeys.objectivesText] = {"Bring 3 Alterac Valley Mark of Honor, 3 Arathi Basin Mark of Honor and 3 Warsong Gulch Mark of Honor to an Alliance Brigadier General outside the battlegrounds."},
            [questKeys.objectives] = {nil,nil,{{20558},{20559},{20560}}},
        },

        [13479] = {
            [questKeys.breadcrumbs] = {},
        },

        [13480] = {
            [questKeys.breadcrumbs] = {},
        },

        [13481] = {
            [questKeys.preQuestSingle] = {13144},
        },

        [13482] = {
            [questKeys.preQuestSingle] = {13144},
        },

        [13483] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [13484] = {
            [questKeys.breadcrumbForQuestId] = 0,
        },

        [13501] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13502] = {
            [questKeys.objectives] = {nil,nil,{{44791},{44802}}},
        },

        [13503] = {
            [questKeys.objectives] = {nil,nil,{{44791},{44802}}},
        },

        [13524] = {
            [questKeys.objectivesText] = {"Open the Wooden Cage and help the Freed Alliance Scout escape from Silverbrook.  Report to Lieutenant Dumont when you reach Amberpine Lodge."},
            [questKeys.exclusiveTo] = {12308},
        },

        [13538] = {
            [questKeys.specialFlags] = 1,
        },

        [13541] = {
            [questKeys.questFlags] = 8,
        },

        [13548] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 65536,
        },

        [13549] = {
            [questKeys.objectives] = {{{33005},{33006}}},
            [questKeys.requiredSourceItems] = {44890},
        },

        [13559] = {
            [questKeys.requiredMinRep] = {1119,3000},
            [questKeys.preQuestSingle] = {},
        },

        [13592] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13593] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 13718,
        },

        [13600] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13603] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13604] = {
            [questKeys.objectives] = {nil,nil,{{45506}}},
        },

        [13614] = {
            [questKeys.objectives] = {nil,nil,{{45791}}},
            [questKeys.preQuestSingle] = {13606,13609,13610,13611},
        },

        [13616] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13622] = {
            [questKeys.objectives] = {nil,nil,{{45039}}},
        },

        [13625] = {
            [questKeys.objectives] = {{{33341},{33339},{33340}}},
            [questKeys.exclusiveTo] = {},
        },

        [13627] = {
            [questKeys.requiredSourceItems] = {45046},
        },

        [13629] = {
            [questKeys.requiredSourceItems] = {45896},
        },

        [13631] = {
            [questKeys.objectives] = {nil,nil,{{46052}}},
        },

        [13633] = {
            [questKeys.preQuestSingle] = {},
        },

        [13634] = {
            [questKeys.preQuestSingle] = {},
        },

        [13643] = {
            [questKeys.requiredSourceItems] = {45070},
        },

        [13662] = {
            [questKeys.questFlags] = 1,
        },

        [13663] = {
            [questKeys.objectives] = {{{33519}},nil,{{45121},{45122}}},
            [questKeys.requiredSourceItems] = {45083},
        },

        [13664] = {
            [questKeys.preQuestSingle] = {13663},
        },

        [13665] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13666] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.exclusiveTo] = {},
        },

        [13669] = {
            [questKeys.exclusiveTo] = {},
        },

        [13670] = {
            [questKeys.exclusiveTo] = {},
        },

        [13671] = {
            [questKeys.objectives] = {{{33192}}},
            [questKeys.exclusiveTo] = {},
        },

        [13672] = {
            [questKeys.preQuestSingle] = {13828,13835,13837},
        },

        [13673] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.exclusiveTo] = {},
        },

        [13674] = {
            [questKeys.exclusiveTo] = {},
        },

        [13675] = {
            [questKeys.exclusiveTo] = {},
        },

        [13676] = {
            [questKeys.objectives] = {{{33192}}},
            [questKeys.exclusiveTo] = {},
        },

        [13677] = {
            [questKeys.objectives] = {{{33341},{33339},{33340}}},
            [questKeys.exclusiveTo] = {},
        },

        [13678] = {
            [questKeys.preQuestSingle] = {13829,13838,13839},
        },

        [13679] = {
            [questKeys.objectives] = {{{38595}}},
        },

        [13680] = {
            [questKeys.objectives] = {{{38595}}},
        },

        [13681] = {
            [questKeys.requiredSourceItems] = {45281},
        },

        [13682] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13684] = {
            [questKeys.objectivesText] = {"Speak with Marshal Jacob Alerius at the Argent Tournament Grounds  to become a valiant of Stormwind."},
        },

        [13685] = {
            [questKeys.objectivesText] = {"Speak with Lana Stouthammer at the Argent Tournament Grounds  to become a valiant of Ironforge."},
        },

        [13688] = {
            [questKeys.objectivesText] = {"Speak with Ambrose Boltspark at the Argent Tournament Grounds  to become a valiant of Gnomeregan."},
        },

        [13689] = {
            [questKeys.objectivesText] = {"Speak with Jaelyne Evensong at the Argent Tournament Grounds  to become a valiant of Darnassus."},
        },

        [13690] = {
            [questKeys.objectivesText] = {"Speak with Colosos at the Argent Tournament Grounds  to become a valiant of the Exodar."},
        },

        [13691] = {
            [questKeys.objectivesText] = {"Speak with Mokra the Skullcrusher at the Argent Tournament Grounds  to become a valiant of Orgrimmar."},
        },

        [13693] = {
            [questKeys.objectivesText] = {"Speak with Zul'tore at the Argent Tournament Grounds  to become a valiant of Sen'jin."},
        },

        [13694] = {
            [questKeys.objectivesText] = {"Speak with Runok Wildmane at the Argent Tournament Grounds  to become a valiant of Thunder Bluff."},
        },

        [13695] = {
            [questKeys.objectivesText] = {"Speak with Deathstalker Visceri at the Argent Tournament Grounds  to become a valiant of the Undercity."},
        },

        [13696] = {
            [questKeys.objectivesText] = {"Speak with Eressea Dawnsinger at the Argent Tournament Grounds  to become a valiant of Silvermoon."},
        },

        [13697] = {
            [questKeys.preQuestSingle] = {},
        },

        [13699] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13703] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13704] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13705] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13706] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13707] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13708] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13709] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13710] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13711] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13713] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13714] = {
            [questKeys.preQuestSingle] = {},
        },

        [13715] = {
            [questKeys.preQuestSingle] = {},
        },

        [13716] = {
            [questKeys.preQuestSingle] = {},
        },

        [13717] = {
            [questKeys.preQuestSingle] = {},
        },

        [13718] = {
            [questKeys.preQuestSingle] = {},
        },

        [13719] = {
            [questKeys.preQuestSingle] = {},
        },

        [13720] = {
            [questKeys.preQuestSingle] = {},
        },

        [13721] = {
            [questKeys.preQuestSingle] = {},
        },

        [13722] = {
            [questKeys.preQuestSingle] = {},
        },

        [13723] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13724] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13725] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13726] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13727] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13728] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13729] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13731] = {
            [questKeys.objectives] = {{{33708}}},
        },

        [13741] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13742] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13743] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13744] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13745] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13746] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13747] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13748] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13749] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13750] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13752] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13753] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13754] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13755] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13756] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13757] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13758] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13759] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13760] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13761] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13762] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13763] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13764] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13765] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13767] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13768] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13769] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13770] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13771] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13772] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13773] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13774] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13775] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13776] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13777] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13778] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13779] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13780] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13781] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13782] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13783] = {
            [questKeys.requiredSourceItems] = {44986},
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13784] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13785] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13786] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13787] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13788] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13789] = {
            [questKeys.objectives] = {{{35297}}},
            [questKeys.preQuestSingle] = {13794},
        },

        [13790] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13791] = {
            [questKeys.objectives] = {{{35297}}},
            [questKeys.preQuestSingle] = {13795},
        },

        [13793] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13794] = {
            [questKeys.requiredClasses] = 1503,
            [questKeys.preQuestSingle] = {},
        },

        [13795] = {
            [questKeys.preQuestSingle] = {},
        },

        [13809] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13810] = {
            [questKeys.objectives] = {{{35297}}},
            [questKeys.preQuestSingle] = {13794},
        },

        [13811] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13812] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13813] = {
            [questKeys.objectives] = {{{35297}}},
            [questKeys.preQuestSingle] = {13795},
        },

        [13814] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13817] = {
            [questKeys.objectives] = {nil,nil,{{45857}}},
        },

        [13818] = {
            [questKeys.objectives] = {nil,nil,{{45855}}},
            [questKeys.preQuestSingle] = {13821,13822,13823,13824},
        },

        [13819] = {
            [questKeys.objectives] = {nil,nil,{{46053}}},
        },

        [13820] = {
            [questKeys.exclusiveTo] = {},
        },

        [13825] = {
            [questKeys.requiredSkill] = {185,1},
        },

        [13826] = {
            [questKeys.requiredSkill] = {356,1},
        },

        [13827] = {
            [questKeys.questLevel] = 77,
            [questKeys.requiredLevel] = 70,
            [questKeys.objectives] = {nil,nil,{{45863}}},
        },

        [13828] = {
            [questKeys.objectives] = {{{33973},{33341}}},
        },

        [13829] = {
            [questKeys.objectives] = {{{33973},{33341}}},
        },

        [13835] = {
            [questKeys.objectives] = {{{33974},{33339}}},
        },

        [13837] = {
            [questKeys.objectives] = {{{33972},{33340}}},
        },

        [13838] = {
            [questKeys.objectives] = {{{33974},{33339}}},
        },

        [13839] = {
            [questKeys.objectives] = {{{33972},{33340}}},
        },

        [13840] = {
            [questKeys.questLevel] = 1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Find some Special Chicken Feed and return to your befriended chicken. When you find it,/cheer at it before trying to give it the Special Chicken Feed."},
            [questKeys.objectives] = {nil,nil,{{11109}}},
            [questKeys.questFlags] = 264,
        },

        [13843] = {
            [questKeys.requiredSkill] = {},
            [questKeys.preQuestSingle] = {},
        },

        [13845] = {
            [questKeys.objectives] = {nil,nil,{{46005}}},
        },

        [13846] = {
            [questKeys.requiredMaxRep] = false,
            [questKeys.preQuestSingle] = {},
        },

        [13847] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13851] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13852] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13854] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13855] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13856] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13857] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13858] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13859] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13860] = {
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {},
        },

        [13861] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13862] = {
            [questKeys.preQuestSingle] = {13794},
        },

        [13863] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13864] = {
            [questKeys.preQuestSingle] = {13795},
        },

        [13889] = {
            [questKeys.exclusiveTo] = {},
        },

        [13903] = {
            [questKeys.exclusiveTo] = {},
        },

        [13904] = {
            [questKeys.exclusiveTo] = {},
        },

        [13905] = {
            [questKeys.exclusiveTo] = {},
        },

        [13906] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Return 20 Venomhide Baby Teeth,  the Venomhide Hatchling, 20 Runecloth, 20 Rugged Leather, and 80 gold to Mor'vek in the southeastern part of the Marshlands in Un'Goro Crater."},
            [questKeys.objectives] = {nil,nil,{{46362},{47196},{14047},{8170}}},
        },

        [13914] = {
            [questKeys.exclusiveTo] = {},
        },

        [13915] = {
            [questKeys.exclusiveTo] = {},
        },

        [13916] = {
            [questKeys.exclusiveTo] = {},
        },

        [13917] = {
            [questKeys.exclusiveTo] = {},
        },

        [13929] = {
            [questKeys.exclusiveTo] = {},
        },

        [13930] = {
            [questKeys.exclusiveTo] = {},
        },

        [13931] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{33955}}},
        },

        [13932] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{33955}}},
        },

        [13933] = {
            [questKeys.exclusiveTo] = {},
        },

        [13934] = {
            [questKeys.exclusiveTo] = {},
        },

        [13937] = {
            [questKeys.objectives] = {{{36209}}},
            [questKeys.sourceItemId] = 0,
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {13954},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [13938] = {
            [questKeys.objectives] = {{{36209}}},
            [questKeys.sourceItemId] = 0,
            [questKeys.requiredSourceItems] = {},
            [questKeys.preQuestSingle] = {13955},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
        },

        [13950] = {
            [questKeys.exclusiveTo] = {},
        },

        [13951] = {
            [questKeys.exclusiveTo] = {},
        },

        [13952] = {
            [questKeys.requiredRaces] = 1,
            [questKeys.exclusiveTo] = {14166,14167,14168,14169,14170,14171,14172,14173,14174,14175,14176,14177},
        },

        [13954] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {13929},
            [questKeys.exclusiveTo] = {},
        },

        [13955] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {13930},
            [questKeys.exclusiveTo] = {},
        },

        [13956] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {13929},
            [questKeys.exclusiveTo] = {},
        },

        [13957] = {
            [questKeys.objectives] = nil,
            [questKeys.preQuestSingle] = {13930},
            [questKeys.exclusiveTo] = {},
        },

        [13959] = {
            [questKeys.exclusiveTo] = {},
        },

        [13960] = {
            [questKeys.exclusiveTo] = {},
        },

        [13966] = {
            [questKeys.exclusiveTo] = {},
        },

        [13986] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46775}}},
        },

        [14016] = {
            [questKeys.objectives] = nil,
            [questKeys.questFlags] = 138,
        },

        [14022] = {
            [questKeys.requiredRaces] = 0,
        },

        [14023] = {
            [questKeys.preQuestSingle] = {14064},
        },

        [14032] = {
            [questKeys.questFlags] = 8,
            [questKeys.specialFlags] = 4,
        },

        [14036] = {
            [questKeys.requiredRaces] = 0,
        },

        [14037] = {
            [questKeys.preQuestSingle] = {14065},
        },

        [14048] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14051] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14053] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14054] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14055] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14058] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14059] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14060] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14061] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14062] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14064] = {
            [questKeys.preQuestSingle] = {14022},
        },

        [14065] = {
            [questKeys.preQuestSingle] = {14036},
        },

        [14074] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14076] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredSourceItems] = {46893},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14077] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34852}},nil,{{46870}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14079] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46875}}},
            [questKeys.questFlags] = 0,
        },

        [14080] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34838}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14081] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46882}}},
            [questKeys.questFlags] = 0,
        },

        [14082] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46879}}},
        },

        [14083] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46877}}},
            [questKeys.questFlags] = 0,
        },

        [14084] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46878}}},
            [questKeys.questFlags] = 0,
        },

        [14085] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46876}}},
            [questKeys.questFlags] = 0,
        },

        [14086] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46880}}},
            [questKeys.questFlags] = 0,
        },

        [14087] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46884}}},
        },

        [14088] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46883}}},
        },

        [14089] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{46881}}},
            [questKeys.questFlags] = 0,
        },

        [14090] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34899}}},
            [questKeys.requiredSourceItems] = {46885},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14092] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredSourceItems] = {46893},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14095] = {
            [questKeys.objectives] = {nil,nil,{{46955}}},
        },

        [14096] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
        },

        [14100] = {
            [questKeys.requiredRaces] = 0,
        },

        [14101] = {
            [questKeys.requiredSourceItems] = {47006},
            [questKeys.exclusiveTo] = {},
        },

        [14102] = {
            [questKeys.requiredSourceItems] = {47009},
            [questKeys.exclusiveTo] = {},
        },

        [14103] = {
            [questKeys.specialFlags] = 0,
        },

        [14104] = {
            [questKeys.requiredSourceItems] = {47029},
            [questKeys.exclusiveTo] = {},
        },

        [14105] = {
            [questKeys.exclusiveTo] = {},
        },

        [14106] = {
            [questKeys.objectives] = {{{721},{2442}},nil,{{33935},{13703},{3509},{19222},{4587},{20560}}},
        },

        [14107] = {
            [questKeys.objectives] = {{{35055}}},
            [questKeys.requiredSourceItems] = {47033,47035},
            [questKeys.exclusiveTo] = {},
        },

        [14108] = {
            [questKeys.objectives] = {{{35009},{35092}},nil,{{46954}}},
            [questKeys.exclusiveTo] = {},
        },

        [14111] = {
            [questKeys.requiredRaces] = 0,
        },

        [14112] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14136] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14140] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34838}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14141] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34899}}},
            [questKeys.requiredSourceItems] = {46885},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14142] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
        },

        [14143] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14144] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{34852}},nil,{{46870}}},
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14145] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14151] = {
            [questKeys.objectivesText] = {"Linzy Blackbolt in Dalaran wants you to successfully transmute 5 epic gems with your alchemy skill.  Acceptable transmutes include Ametrine, Eye of Zul, Dreadstone, King's Amber, and Majestic Zircon."},
            [questKeys.objectives] = {{{28701}}},
        },

        [14152] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMinRep] = false,
            [questKeys.exclusiveTo] = {},
        },

        [14160] = {
            [questKeys.objectives] = {nil,nil,{{47247}}},
        },

        [14163] = {
            [questKeys.requiredRaces] = 0,
        },

        [14164] = {
            [questKeys.requiredRaces] = 0,
        },

        [14166] = {
            [questKeys.exclusiveTo] = {13952,14167,14168,14169,14170,14171,14172,14173,14174,14175,14176,14177},
        },

        [14167] = {
            [questKeys.requiredRaces] = 4,
            [questKeys.exclusiveTo] = {13952,14166,14168,14169,14170,14171,14172,14173,14174,14175,14176,14177},
        },

        [14168] = {
            [questKeys.requiredRaces] = 64,
            [questKeys.exclusiveTo] = {13952,14166,14167,14169,14170,14171,14172,14173,14174,14175,14176,14177},
        },

        [14169] = {
            [questKeys.requiredRaces] = 1024,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14170,14171,14172,14173,14174,14175,14176,14177},
        },

        [14170] = {
            [questKeys.requiredRaces] = 8,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14171,14172,14173,14174,14175,14176,14177},
        },

        [14171] = {
            [questKeys.requiredRaces] = 512,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14172,14173,14174,14175,14176,14177},
        },

        [14172] = {
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14173,14174,14175,14176,14177},
        },

        [14173] = {
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14172,14174,14175,14176,14177},
        },

        [14174] = {
            [questKeys.requiredRaces] = 16,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14172,14173,14175,14176,14177},
        },

        [14175] = {
            [questKeys.requiredRaces] = 2,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14172,14173,14174,14176,14177},
        },

        [14176] = {
            [questKeys.requiredRaces] = 32,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14172,14173,14174,14175,14177},
        },

        [14177] = {
            [questKeys.requiredRaces] = 128,
            [questKeys.exclusiveTo] = {13952,14166,14167,14168,14169,14170,14171,14172,14173,14174,14175,14176},
        },

        [14178] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMaxLevel] = 0,
        },

        [14179] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {13427,14178,14180},
            [questKeys.requiredMaxLevel] = 0,
        },

        [14180] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMaxLevel] = 0,
        },

        [14181] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMaxLevel] = 0,
        },

        [14182] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Win an Eye of the Storm battleground match and return to a Horde Warbringer at any Horde capital city, Wintergrasp, Dalaran,  or Shattrath."},
            [questKeys.requiredMaxLevel] = 0,
        },

        [14183] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredMaxLevel] = 0,
        },

        [14199] = {
            [questKeys.objectivesText] = {"Archmage Timear in Dalaran wants you to return with a Fragment of the Black Knight's Soul.","","This quest may only be completed on Heroic difficulty."},
            [questKeys.questFlags] = 4232,
        },

        [14203] = {
            [questKeys.objectives] = {nil,nil,{{48681}}},
        },

        [14349] = {
            [questKeys.exclusiveTo] = {6144},
        },

        [14350] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {},
            [questKeys.exclusiveTo] = {6145},
        },

        [14351] = {
            [questKeys.objectivesText] = {"Take Darthalia's Sealed Commendation to Varimathras in the Undercity."},
            [questKeys.objectives] = {nil,nil,{{3701}}},
        },

        [14352] = {
            [questKeys.objectivesText] = {"Take the Small Scroll to Varimathras in the Undercity."},
            [questKeys.objectives] = {nil,nil,{{49205}}},
        },

        [14353] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectivesText] = {"Bring Ambassador Malcin's Head to Varimathras in the Undercity."},
            [questKeys.preQuestSingle] = {14352},
        },

        [14355] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectivesText] = {"Kill High Inquisitor Whitemane, Scarlet Commander Mograine, Herod, the Scarlet Champion and Houndmaster Loksey and then report back to Varimathras in the Undercity."},
        },

        [14356] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectivesText] = {"Bring the books Spells of Shadow and Incantations from the Nether to Varimathras in Undercity."},
        },

        [14409] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{49335}}},
        },

        [14418] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{7294}}},
        },

        [14419] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.objectives] = {nil,nil,{{7231}}},
        },

        [14420] = {
            [questKeys.requiredRaces] = 690,
            [questKeys.preQuestSingle] = {1885},
            [questKeys.breadcrumbs] = {},
        },

        [14421] = {
            [questKeys.requiredRaces] = 690,
        },

        [14437] = {
            [questKeys.objectives] = {nil,nil,{{4783}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [14441] = {
            [questKeys.objectives] = {nil,nil,{{49377}}},
        },

        [14443] = {
            [questKeys.objectives] = {nil,nil,{{50379}}},
        },

        [14444] = {
            [questKeys.objectives] = {{{36715}}},
        },

        [14483] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{49641}}},
        },

        [24216] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24217] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24218] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24219] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24220] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24221] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24222] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 61,
            [questKeys.objectivesText] = {"Win an Eye of the Storm battleground match and return to a Horde Warbringer at any Horde capital city,Wintergrasp,Dalaran, or Shattrath."},
            [questKeys.questFlags] = 4226,
            [questKeys.specialFlags] = 1,
        },

        [24223] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24224] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24225] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24226] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24227] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 61,
            [questKeys.objectivesText] = {"Win an Eye of the Storm battleground match and return to an Alliance Brigadier General at any Alliance capital city,Wintergrasp,Dalaran,or Shattrath."},
            [questKeys.questFlags] = 4226,
            [questKeys.specialFlags] = 1,
        },

        [24426] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24427] = {
            [questKeys.requiredMaxLevel] = 0,
        },

        [24428] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{49644}}},
        },

        [24429] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{49643}}},
        },

        [24431] = {
            [questKeys.objectives] = {nil,nil,{{49667}}},
            [questKeys.specialFlags] = 0,
        },

        [24442] = {
            [questKeys.objectives] = {nil,nil,{{49676},{49678}}},
        },

        [24454] = {
            [questKeys.objectives] = {nil,nil,{{49698}}},
        },

        [24461] = {
            [questKeys.requiredSourceItems] = {49718,49723,49740},
        },

        [24476] = {
            [questKeys.requiredSourceItems] = {49920},
        },

        [24480] = {
            [questKeys.objectivesText] = {"Bring your Tempered Quel'Delar to Sword's Rest inside the Halls of Reflection. "},
            [questKeys.requiredSourceItems] = {49766},
        },

        [24498] = {
            [questKeys.objectives] = {{{36764},{36494}}},
        },

        [24499] = {
            [questKeys.preQuestSingle] = {24510},
        },

        [24500] = {
            [questKeys.objectives] = {{{36955},{38211}}},
            [questKeys.preQuestSingle] = {24711},
        },

        [24507] = {
            [questKeys.objectives] = {{{36770},{36494}}},
        },

        [24511] = {
            [questKeys.preQuestSingle] = {24506},
        },

        [24522] = {
            [questKeys.objectives] = {nil,nil,{{49870}}},
        },

        [24535] = {
            [questKeys.objectives] = {{{37601}},nil,{{49870}}},
        },

        [24536] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{37558}}},
            [questKeys.requiredSourceItems] = {50131},
            [questKeys.preQuestSingle] = {24805},
        },

        [24541] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.sourceItemId] = 0,
            [questKeys.questFlags] = 2,
        },

        [24545] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [24547] = {
            [questKeys.requiredClasses] = 35,
        },

        [24548] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.nextQuestInChain] = 0,
        },

        [24549] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [24554] = {
            [questKeys.objectives] = {nil,nil,{{50380}}},
        },

        [24555] = {
            [questKeys.objectives] = {{{36715}}},
        },

        [24558] = {
            [questKeys.objectives] = {nil,nil,{{49698}}},
        },

        [24559] = {
            [questKeys.requiredSourceItems] = {49718,49723,49740},
        },

        [24560] = {
            [questKeys.requiredSourceItems] = {49920},
        },

        [24561] = {
            [questKeys.requiredSourceItems] = {49766},
        },

        [24562] = {
            [questKeys.objectives] = {nil,nil,{{49870}}},
        },

        [24563] = {
            [questKeys.objectives] = {{{37601}},nil,{{49870}}},
        },

        [24564] = {
            [questKeys.requiredSourceItems] = {49879},
        },

        [24576] = {
            [questKeys.requiredRaces] = 0,
        },

        [24594] = {
            [questKeys.requiredClasses] = 1519,
            [questKeys.requiredSourceItems] = {49889},
        },

        [24596] = {
            [questKeys.requiredClasses] = 16,
            [questKeys.requiredSourceItems] = {49889},
        },

        [24597] = {
            [questKeys.requiredRaces] = 0,
        },

        [24598] = {
            [questKeys.requiredSourceItems] = {49879},
        },

        [24609] = {
            [questKeys.requiredRaces] = 0,
        },

        [24610] = {
            [questKeys.requiredRaces] = 0,
        },

        [24611] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.questFlags] = 4104,
        },

        [24612] = {
            [questKeys.requiredRaces] = 0,
        },

        [24613] = {
            [questKeys.requiredRaces] = 0,
        },

        [24614] = {
            [questKeys.requiredRaces] = 0,
        },

        [24615] = {
            [questKeys.requiredRaces] = 0,
        },

        [24629] = {
            [questKeys.requiredSourceItems] = {49668},
            [questKeys.exclusiveTo] = {},
        },

        [24635] = {
            [questKeys.requiredSourceItems] = {49669},
            [questKeys.exclusiveTo] = {},
        },

        [24636] = {
            [questKeys.requiredSourceItems] = {49670},
            [questKeys.exclusiveTo] = {},
        },

        [24638] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37214}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24645] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37917}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24647] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37984}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24648] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38006}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24649] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38016}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24650] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38023}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24651] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38030}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24652] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38032}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24655] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{37558}}},
            [questKeys.requiredSourceItems] = {50131},
            [questKeys.preQuestSingle] = {24804},
        },

        [24656] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.sourceItemId] = 0,
            [questKeys.questFlags] = 2,
        },

        [24657] = {
            [questKeys.requiredRaces] = 0,
        },

        [24658] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37214}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24659] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37917}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24660] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{37984}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24661] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Kill 5 Crown Lackeys and use Snagglebolt's Khorium Bomb to damage one Chemical Wagon just west of Orgrimmar's gates in Durotar,then return to Detective Snap Snagglebolt in Orgrimmar."},
            [questKeys.objectives] = {{{38035},{37214}}},
            [questKeys.sourceItemId] = 50130,
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.questFlags] = 4096,
            [questKeys.specialFlags] = 1,
        },

        [24662] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38006}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24663] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38016}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24664] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38023}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24665] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38030}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24666] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{38035},{38032}}},
            [questKeys.requiredSourceItems] = {50130},
            [questKeys.exclusiveTo] = {},
        },

        [24743] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.nextQuestInChain] = 0,
        },

        [24745] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{50320}}},
        },

        [24746] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectives] = {{{37558}}},
            [questKeys.sourceItemId] = 50131,
            [questKeys.requiredSourceItems] = {50131},
        },

        [24748] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.objectives] = {{{38153}}},
        },

        [24749] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.objectives] = nil,
        },

        [24756] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.objectives] = nil,
        },

        [24757] = {
            [questKeys.requiredClasses] = 35,
            [questKeys.objectives] = nil,
            [questKeys.nextQuestInChain] = 0,
        },

        [24789] = {
            [questKeys.specialFlags] = 9,
        },

        [24791] = {
            [questKeys.specialFlags] = 9,
        },

        [24792] = {
            [questKeys.requiredRaces] = 0,
        },

        [24793] = {
            [questKeys.requiredRaces] = 0,
        },

        [24795] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24796] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24797] = {
            [questKeys.questLevel] = 80,
            [questKeys.requiredLevel] = 77,
            [questKeys.questFlags] = 136,
        },

        [24798] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24799] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24800] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24801] = {
            [questKeys.objectives] = {nil,nil,{{49871}}},
        },

        [24802] = {
            [questKeys.objectives] = {{{37554},{38211}}},
            [questKeys.preQuestSingle] = {24713},
        },

        [24804] = {
            [questKeys.requiredRaces] = 0,
        },

        [24805] = {
            [questKeys.requiredRaces] = 0,
        },

        [24819] = {
            [questKeys.requiredMinRep] = {1156,6000},
            [questKeys.exclusiveTo] = {},
        },

        [24820] = {
            [questKeys.requiredMinRep] = {1156,6000},
            [questKeys.exclusiveTo] = {},
        },

        [24821] = {
            [questKeys.requiredMinRep] = {1156,6000},
            [questKeys.exclusiveTo] = {},
        },

        [24822] = {
            [questKeys.requiredMinRep] = {1156,6000},
            [questKeys.exclusiveTo] = {},
        },

        [24836] = {
            [questKeys.exclusiveTo] = {},
        },

        [24837] = {
            [questKeys.exclusiveTo] = {},
        },

        [24838] = {
            [questKeys.exclusiveTo] = {},
        },

        [24839] = {
            [questKeys.exclusiveTo] = {},
        },

        [24840] = {
            [questKeys.exclusiveTo] = {},
        },

        [24841] = {
            [questKeys.exclusiveTo] = {},
        },

        [24842] = {
            [questKeys.exclusiveTo] = {},
        },

        [24843] = {
            [questKeys.exclusiveTo] = {},
        },

        [24848] = {
            [questKeys.requiredRaces] = 0,
        },

        [24849] = {
            [questKeys.requiredRaces] = 0,
        },

        [24850] = {
            [questKeys.requiredRaces] = 0,
        },

        [24851] = {
            [questKeys.requiredRaces] = 0,
        },

        [24857] = {
            [questKeys.objectives] = {nil,nil,{{4850}}},
            [questKeys.questFlags] = 0,
            [questKeys.specialFlags] = 4,
        },

        [24869] = {
            [questKeys.objectives] = {{{39091}}},
            [questKeys.exclusiveTo] = {},
        },

        [24870] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [24871] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [24872] = {
            [questKeys.requiredSourceItems] = {50851},
            [questKeys.exclusiveTo] = {},
        },

        [24873] = {
            [questKeys.objectives] = nil,
            [questKeys.exclusiveTo] = {},
        },

        [24874] = {
            [questKeys.exclusiveTo] = {},
        },

        [24875] = {
            [questKeys.objectives] = {{{39092}}},
            [questKeys.exclusiveTo] = {},
        },

        [24876] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [24877] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [24878] = {
            [questKeys.objectives] = nil,
            [questKeys.exclusiveTo] = {},
        },

        [24879] = {
            [questKeys.objectives] = {{{39123}}},
            [questKeys.exclusiveTo] = {},
        },

        [24880] = {
            [questKeys.requiredSourceItems] = {50851},
            [questKeys.exclusiveTo] = {},
        },

        [24912] = {
            [questKeys.nextQuestInChain] = 0,
        },

        [24914] = {
            [questKeys.requiredSourceItems] = {51315},
            [questKeys.preQuestSingle] = {},
        },

        [24923] = {
            [questKeys.specialFlags] = 9,
        },

        [25055] = {
            [questKeys.questLevel] = 80,
            [questKeys.requiredLevel] = 80,
            [questKeys.objectivesText] = {"[ph] log description"},
            [questKeys.objectives] = {{{39021}}},
            [questKeys.sourceItemId] = 52274,
        },

        [25092] = {
            [questKeys.questLevel] = 80,
            [questKeys.requiredLevel] = 80,
            [questKeys.objectivesText] = {"[ph] log description"},
            [questKeys.objectives] = {{{39047}}},
            [questKeys.sourceItemId] = 52344,
            [questKeys.questFlags] = 1,
        },

        [25180] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Bring the Tablets of Earth to King Magni Bronzebeard in Ironforge."},
            [questKeys.objectives] = {nil,nil,{{52275}}},
            [questKeys.questFlags] = 136,
        },

        [25181] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Bring the Tablets of Fire to Seer Bahura in Orgrimmar."},
            [questKeys.objectives] = {nil,nil,{{52276}}},
            [questKeys.questFlags] = 136,
        },

        [25199] = {
            [questKeys.objectives] = {{{39355},{39356},{39362},{39361}}},
        },

        [25212] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.requiredSourceItems] = {52541},
        },

        [25228] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Listen to a speech given by a Doomsayer in the Drag and obtain copies of the pamphlets \"Elemental Fire for the Soul\",\"What Does 'The End of All Things' Mean for Me?\",and \"Finding Security and Comfort in a Doomed World\"."},
            [questKeys.objectives] = {{{39454}},nil,{{52562},{52563},{52565}}},
            [questKeys.nextQuestInChain] = 25254,
            [questKeys.questFlags] = 136,
        },

        [25229] = {
            [questKeys.requiredLevel] = 0,
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{39623},{39466}}},
            [questKeys.requiredSourceItems] = {52566},
        },

        [25247] = {
            [questKeys.requiredMinRep] = {1156,6000},
            [questKeys.exclusiveTo] = {},
        },

        [25248] = {
            [questKeys.exclusiveTo] = {},
        },

        [25249] = {
            [questKeys.exclusiveTo] = {},
        },

        [25253] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Listen to a speech given by a Doomsayer in Old Town and obtain copies of the pamphlets \"Elemental Fire for the Soul\",\"What Does 'The End of All Things' Mean for Me?\",and \"Finding Security and Comfort in a Doomed World\"."},
            [questKeys.objectives] = {{{39454}},nil,{{52562},{52563},{52565}}},
            [questKeys.nextQuestInChain] = 25282,
            [questKeys.questFlags] = 136,
        },

        [25254] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Setup 5 Warning Posters around the Valley of Strength,the Drag,or the Valley of Honor."},
            [questKeys.objectives] = {{{39581}}},
            [questKeys.sourceItemId] = 52706,
            [questKeys.requiredSourceItems] = {52706},
            [questKeys.questFlags] = 8,
        },

        [25282] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Setup 5 Warning Posters in the Trade District,Mage District,or Cathedral District of Stormwind."},
            [questKeys.objectives] = {{{39672}}},
            [questKeys.sourceItemId] = 52707,
            [questKeys.requiredSourceItems] = {52707},
            [questKeys.questFlags] = 8,
        },

        [25283] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"Use the Gnomish Playback Device in front of Ozzie Togglevolt north of Kharanos,Milli Featherwhistle at Steelgrill Depot and Tog Rustsprocket outside the Kharanos Inn.  Return to Toby Ziegear when all the speeches have been given."},
            [questKeys.requiredSourceItems] = {52709},
            [questKeys.preQuestSingle] = {25295},
            [questKeys.nextQuestInChain] = 0,
        },

        [25285] = {
            [questKeys.objectives] = {{{39683}}},
        },

        [25286] = {
            [questKeys.questLevel] = 75,
            [questKeys.requiredRaces] = 0,
            [questKeys.exclusiveTo] = {},
        },

        [25287] = {
            [questKeys.questLevel] = 75,
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{52731}}},
            [questKeys.preQuestSingle] = {},
        },

        [25288] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Speak to a Doomsayer Orgrimmar's Drag to join the cult,then put on your Recruit's Robe."},
            [questKeys.objectives] = {{{39872}}},
            [questKeys.nextQuestInChain] = 25380,
            [questKeys.questFlags] = 8,
        },

        [25289] = {
            [questKeys.objectives] = {{{39691},{39692},{39695}}},
        },

        [25290] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 1,
            [questKeys.objectivesText] = {"Speak to Doomsayer Stormwind's Old Town to join the doomsday cult,then equip the Doomsday Recruit's Robe you receive."},
            [questKeys.objectives] = {{{39872}}},
            [questKeys.nextQuestInChain] = 25415,
            [questKeys.questFlags] = 8,
        },

        [25293] = {
            [questKeys.objectivesText] = {"While wearing your Cult Disguise,speak to Cultist Kagarn,Cultish Agtar,Cultist Tokka,and Cultist Rokaga at the Jaggedswine Farm in Durotar."},
        },

        [25295] = {
            [questKeys.objectives] = {{{39703}}},
        },

        [25343] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Learn more about the cult's plans at the altar in the eastern part of the Jaggedswine Farm."},
            [questKeys.objectives] = {{{39821}}},
            [questKeys.nextQuestInChain] = 25347,
            [questKeys.questFlags] = 8,
        },

        [25347] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Take the Elemental Devices to Blood Guard Torek in Orgrimmar's Valley of Strength."},
            [questKeys.objectives] = {nil,nil,{{52835}}},
            [questKeys.sourceItemId] = 52835,
            [questKeys.nextQuestInChain] = 25348,
        },

        [25348] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Break Elemental Devices to release their elementals. You must defeat 5 Raging Fire Elementals."},
            [questKeys.objectives] = {{{39852}}},
            [questKeys.nextQuestInChain] = 25351,
            [questKeys.questFlags] = 8,
        },

        [25351] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Speak with Thrall at Grommash Hold in Orgrimmar's Valley of Wisdom."},
            [questKeys.requiredSourceItems] = {52729},
            [questKeys.questFlags] = 8,
        },

        [25380] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"While wearing your Doomsday Message,visit the East Zeppelin Tower,the West Zeppelin Tower,and the town square of Razor Hill."},
            [questKeys.objectives] = {{{39975},{39976},{39977}}},
            [questKeys.sourceItemId] = 53048,
            [questKeys.requiredSourceItems] = {53048},
            [questKeys.nextQuestInChain] = 25343,
            [questKeys.questFlags] = 8,
        },

        [25393] = {
            [questKeys.questLevel] = 75,
            [questKeys.requiredLevel] = 0,
            [questKeys.requiredRaces] = 0,
            [questKeys.preQuestSingle] = {},
        },

        [25414] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"While wearing your Doomdsay Recruit's Robe,speak to Cultist Lethelyn,Cultish Kaima,Cultist Wyman,and Cultist Orlunn at Mirror Lake Orchard in Elywnn Forest."},
            [questKeys.objectives] = {{{39967},{39968},{39969},{39970}}},
            [questKeys.questFlags] = 8,
        },

        [25415] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"While wearing your Doomsday Message,visit the Westbrook Garrison,the Valley of Heroes in Stormwind,and the town square of Goldshire."},
            [questKeys.objectives] = {{{40102},{40101},{40103}}},
            [questKeys.sourceItemId] = 53048,
            [questKeys.requiredSourceItems] = {53048},
            [questKeys.nextQuestInChain] = 25416,
        },

        [25416] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Learn more about the cult's plans at the altar in the northern part of Mirror Lake Orchard."},
            [questKeys.objectives] = {{{39821}}},
            [questKeys.nextQuestInChain] = 25417,
            [questKeys.questFlags] = 8,
        },

        [25417] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Take the Elemental Devices to Captain Anton in Stormwind's Trade District."},
            [questKeys.objectives] = {nil,nil,{{52835}}},
            [questKeys.sourceItemId] = 52835,
            [questKeys.nextQuestInChain] = 25418,
        },

        [25418] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Destroy Elemental Devices to release their captive elementals. Defeat 5 Raging Wind Elementals."},
            [questKeys.objectives] = {{{40104}}},
            [questKeys.nextQuestInChain] = 25425,
            [questKeys.questFlags] = 8,
        },

        [25425] = {
            [questKeys.questLevel] = -1,
            [questKeys.requiredLevel] = 5,
            [questKeys.objectivesText] = {"Speak with King Varian Wrynn in Stormwind Keep."},
            [questKeys.requiredSourceItems] = {52729},
            [questKeys.questFlags] = 8,
        },

        [25444] = {
            [questKeys.requiredRaces] = 0,
        },

        [25445] = {
            [questKeys.questLevel] = 78,
            [questKeys.requiredLevel] = 0,
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{40428}}},
        },

        [25446] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"While riding a bat,use the Sack o' Frogs to place 12 attuned frogs on the markers in the Echo Isles."},
            [questKeys.requiredSourceItems] = {53637},
            [questKeys.nextQuestInChain] = 0,
        },

        [25461] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{40257},{40260}}},
            [questKeys.requiredSourceItems] = {54215},
            [questKeys.nextQuestInChain] = 0,
        },

        [25470] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectivesText] = {"While imbued with the Spirit of the Tiger,lure the Tiger Matriarch out of hiding and use your new abilities to best it in combat."},
        },

        [25480] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {{{40387}}},
            [questKeys.nextQuestInChain] = 0,
        },

        [25483] = {
            [questKeys.specialFlags] = 25,
        },

        [25495] = {
            [questKeys.requiredRaces] = 0,
        },

        [25500] = {
            [questKeys.requiredRaces] = 0,
            [questKeys.objectives] = {nil,nil,{{52731}}},
            [questKeys.exclusiveTo] = {},
            [questKeys.nextQuestInChain] = 0,
            [questKeys.requiredMaxLevel] = 0,
        },

        [26012] = {
            [questKeys.exclusiveTo] = {},
        },

        [26034] = {
            [questKeys.preQuestSingle] = {},
        },

    }

    return QuestieCompat.Merge(relationCorrections, metadataCorrections, true)
end)
