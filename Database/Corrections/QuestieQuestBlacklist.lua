---@class QuestieQuestBlacklist
local QuestieQuestBlacklist = QuestieLoader:CreateModule("QuestieQuestBlacklist")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")

local HIDE_ON_MAP = "HIDE_ON_MAP"

QuestieQuestBlacklist.HIDE_ON_MAP = HIDE_ON_MAP

---@return table<QuestId, boolean|string>
function QuestieQuestBlacklist:Load()
    local questsToBlacklist = {
        -- Present in AzerothCore's quest_template but unavailable through a
        -- creature, gameobject, or item starter in the final SQL state.
        [615] = true, -- The Captain's Cutlass
        [934] = true, -- Crown of the Earth
        [2000] = true, -- Rokar Bladeshadow
        [7668] = true, -- The Darkreaver Menace
        [7908] = true, -- Arena Master
        [8856] = true, -- Desert Survival Kits
        [10530] = true, -- The Hunter's Path
        [10694] = true, -- Ten Commendation Signets
        [10695] = true, -- One Commendation Signet
        [11072] = true, -- Adversarial Blood
        [11115] = true, -- The Mark of Vashj (FLAG ONLY)
        [11402] = true, -- Clayton's Quest: Extreme!
        [11463] = true, -- Pirates of the North Seas
        [12405] = true, -- Candy Bucket
        [12410] = true, -- Candy Bucket
        [12452] = true, -- zzOLD The Fate of the Ruby Dragonshrine
        [12625] = true, -- Dominion Over Acherus
        [13053] = true, -- Looking for Survivors
        [13417] = true, -- The Brothers Bronzebeard
        [14436] = true, -- Dwarven Digging
        [14437] = true, -- Rites of the Earthmother
        [14438] = true, -- Sharing the Land
        [14439] = true, -- Journey into Thunder Bluff
        [14440] = true, -- Rites of the Earthmother

        -- Special visibility overrides
        [3861] = HIDE_ON_MAP, -- CLUCK!

        -- Classic-era world event quests. These are hidden by default and
        -- QuestieEvent reveals the applicable quests while their event is active.
        [171] = true,
        [172] = true,
        [558] = true,
        [910] = true,
        [911] = true,
        [915] = true,
        [925] = true,
        [1468] = true,
        [1479] = true,
        [1558] = true,
        [1657] = true,
        [1658] = true,
        [1687] = true,
        [1800] = true,
        [4822] = true,
        [5502] = true,
        [6961] = true,
        [6962] = true,
        [6963] = true,
        [6964] = true,
        [6983] = true,
        [6984] = true,
        [7021] = true,
        [7022] = true,
        [7023] = true,
        [7024] = true,
        [7025] = true,
        [7042] = true,
        [7043] = true,
        [7045] = true,
        [7061] = true,
        [7062] = true,
        [7063] = true,
        [8149] = true,
        [8150] = true,
        [8311] = true,
        [8312] = true,
        [8322] = true,
        [8353] = true,
        [8354] = true,
        [8355] = true,
        [8356] = true,
        [8357] = true,
        [8358] = true,
        [8359] = true,
        [8360] = true,
        [8373] = true,
        [8409] = true,
        [8619] = true,
        [8635] = true,
        [8636] = true,
        [8642] = true,
        [8643] = true,
        [8644] = true,
        [8645] = true,
        [8646] = true,
        [8647] = true,
        [8648] = true,
        [8649] = true,
        [8650] = true,
        [8651] = true,
        [8652] = true,
        [8653] = true,
        [8654] = true,
        [8670] = true,
        [8671] = true,
        [8672] = true,
        [8673] = true,
        [8674] = true,
        [8675] = true,
        [8676] = true,
        [8677] = true,
        [8678] = true,
        [8679] = true,
        [8680] = true,
        [8681] = true,
        [8682] = true,
        [8683] = true,
        [8684] = true,
        [8685] = true,
        [8686] = true,
        [8688] = true,
        [8713] = true,
        [8714] = true,
        [8715] = true,
        [8716] = true,
        [8717] = true,
        [8718] = true,
        [8719] = true,
        [8720] = true,
        [8721] = true,
        [8722] = true,
        [8723] = true,
        [8724] = true,
        [8725] = true,
        [8726] = true,
        [8727] = true,
        [8744] = true,
        [8746] = true,
        [8762] = true,
        [8763] = true,
        [8767] = true,
        [8768] = true,
        [8769] = true,
        [8788] = true,
        [8799] = true,
        [8803] = true,
        [8827] = true,
        [8828] = true,
        [8857] = true,
        [8858] = true,
        [8859] = true,
        [8860] = true,
        [8861] = true,
        [8862] = true,
        [8863] = true,
        [8864] = true,
        [8865] = true,
        [8866] = true,
        [8867] = true,
        [8868] = true,
        [8870] = true,
        [8871] = true,
        [8872] = true,
        [8873] = true,
        [8874] = true,
        [8875] = true,
        [8876] = true,
        [8877] = true,
        [8878] = true,
        [8879] = true,
        [8880] = true,
        [8881] = true,
        [8882] = true,
        [8883] = true,
        [9030] = true,
        [9324] = true,
        [9325] = true,
        [9326] = true,
        [9330] = true,
        [9331] = true,
        [9332] = true,
        [9339] = true,
        [9365] = true,
        -- Retired mount exchange/replacement quests
        [7660] = true,
        [7661] = true,
        [7662] = true,
        [7663] = true,
        [7664] = true,
        [7665] = true,
        [7671] = true,
        [7672] = true,
        [7673] = true,
        [7674] = true,
        [7675] = true,
        [7676] = true,
        [7677] = true,
        [7678] = true,
        -- Fishing tournament quests
        [8193] = true,
        [8194] = true,
        [8221] = true,
        [8224] = true,
        [8225] = true,
        [8228] = true,
        [8229] = true,
        -- Retired Love is in the Air quests
        [8900] = true,
        [8901] = true,
        [8902] = true,
        [8903] = true,
        [8904] = true,
        [8979] = true,
        [8980] = true,
        [8981] = true, --removed in wotlk
        [8982] = true,
        [8983] = true,
        [8984] = true,
        [8993] = true, --removed in wotlk
        [9024] = true,
        [9025] = true,
        [9026] = true,
        [9027] = true,
        [9028] = true,
        [9029] = true,
        -- TBC event quests
        [10942] = true,
        [10943] = true,
        [10945] = true,
        [10950] = true,
        [10951] = true,
        [10952] = true,
        [10953] = true,
        [10954] = true,
        [10956] = true,
        [10962] = true,
        [10963] = true,
        [10966] = true,
        [10967] = true,
        [10968] = true,
        [11116] = true,
        [11117] = true,
        [11118] = true,
        [11120] = true,
        [11122] = true,
        [11131] = true,
        [11135] = true,
        [11219] = true,
        [11220] = true,
        [11242] = true,
        [11293] = true,
        [11294] = true,
        [11318] = true,
        [11356] = true,
        [11357] = true,
        [11360] = true,
        [11361] = true,
        [11392] = true,
        [11400] = true,
        [11401] = true,
        [11403] = true,
        [11404] = true,
        [11405] = true,
        [11407] = true,
        [11408] = true,
        [11409] = true,
        [11412] = true,
        [11431] = true,
        [11439] = true,
        [11440] = true,
        [11441] = true,
        [11442] = true,
        [11446] = true,
        [11447] = true,
        [11449] = true,
        [11450] = true,
        [11454] = true,
        [11528] = true,
        [11580] = true,
        [11581] = true,
        [11583] = true,
        [11584] = true,
        [11657] = true,
        [11691] = true,
        [11696] = true,
        [11731] = true,
        [11732] = true,
        [11734] = true,
        [11735] = true,
        [11736] = true,
        [11737] = true,
        [11738] = true,
        [11739] = true,
        [11740] = true,
        [11741] = true,
        [11742] = true,
        [11743] = true,
        [11744] = true,
        [11745] = true,
        [11746] = true,
        [11747] = true,
        [11748] = true,
        [11749] = true,
        [11750] = true,
        [11751] = true,
        [11752] = true,
        [11753] = true,
        [11754] = true,
        [11755] = true,
        [11756] = true,
        [11757] = true,
        [11758] = true,
        [11759] = true,
        [11760] = true,
        [11761] = true,
        [11762] = true,
        [11763] = true,
        [11764] = true,
        [11765] = true,
        [11766] = true,
        [11767] = true,
        [11768] = true,
        [11769] = true,
        [11770] = true,
        [11771] = true,
        [11772] = true,
        [11773] = true,
        [11774] = true,
        [11775] = true,
        [11776] = true,
        [11777] = true,
        [11778] = true,
        [11779] = true,
        [11780] = true,
        [11781] = true,
        [11782] = true,
        [11783] = true,
        [11784] = true,
        [11785] = true,
        [11786] = true,
        [11787] = true,
        [11799] = true,
        [11800] = true,
        [11801] = true,
        [11802] = true,
        [11803] = true,
        [11804] = true,
        [11805] = true,
        [11806] = true,
        [11807] = true,
        [11808] = true,
        [11809] = true,
        [11810] = true,
        [11811] = true,
        [11812] = true,
        [11813] = true,
        [11814] = true,
        [11815] = true,
        [11816] = true,
        [11817] = true,
        [11818] = true,
        [11819] = true,
        [11820] = true,
        [11821] = true,
        [11822] = true,
        [11823] = true,
        [11824] = true,
        [11825] = true,
        [11826] = true,
        [11827] = true,
        [11828] = true,
        [11829] = true,
        [11830] = true,
        [11831] = true,
        [11832] = true,
        [11833] = true,
        [11834] = true,
        [11835] = true,
        [11836] = true,
        [11837] = true,
        [11838] = true,
        [11839] = true,
        [11840] = true,
        [11841] = true,
        [11842] = true,
        [11843] = true,
        [11844] = true,
        [11845] = true,
        [11846] = true,
        [11847] = true,
        [11848] = true,
        [11849] = true,
        [11850] = true,
        [11851] = true,
        [11852] = true,
        [11853] = true,
        [11854] = true,
        [11855] = true,
        [11856] = true,
        [11857] = true,
        [11858] = true,
        [11859] = true,
        [11860] = true,
        [11861] = true,
        [11862] = true,
        [11863] = true,
        [11882] = true,
        [11886] = true,
        [11891] = true,
        [11915] = true,
        [11917] = true,
        [11921] = true,
        [11922] = true,
        [11923] = true,
        [11924] = true,
        [11925] = true,
        [11926] = true,
        [11933] = true,
        [11935] = true,
        [11947] = true,
        [11948] = true,
        [11952] = true,
        [11953] = true,
        [11954] = true,
        [11955] = true,
        [11964] = true,
        [11966] = true,
        [11970] = true,
        [11971] = true,
        [11972] = true,
        [11975] = true,
        [12012] = true,
        [12020] = true,
        [12022] = true,
        [12062] = true,
        [12133] = true,
        [12135] = true,
        [12139] = true,
        [12155] = true,
        [12191] = true,
        [12192] = true,
        [12278] = true,
        [12286] = true,
        [12318] = true,
        [12331] = true,
        [12332] = true,
        [12333] = true,
        [12334] = true,
        [12335] = true,
        [12336] = true,
        [12337] = true,
        [12338] = true,
        [12339] = true,
        [12340] = true,
        [12341] = true,
        [12342] = true,
        [12343] = true,
        [12344] = true,
        [12345] = true,
        [12346] = true,
        [12347] = true,
        [12348] = true,
        [12349] = true,
        [12350] = true,
        [12351] = true,
        [12352] = true,
        [12353] = true,
        [12354] = true,
        [12355] = true,
        [12356] = true,
        [12357] = true,
        [12358] = true,
        [12359] = true,
        [12360] = true,
        [12361] = true,
        [12362] = true,
        [12363] = true,
        [12364] = true,
        [12365] = true,
        [12366] = true,
        [12367] = true,
        [12368] = true,
        [12369] = true,
        [12370] = true,
        [12371] = true,
        [12373] = true,
        [12374] = true,
        [12375] = true,
        [12376] = true,
        [12377] = true,
        [12378] = true,
        [12379] = true,
        [12380] = true,
        [12381] = true,
        [12382] = true,
        [12383] = true,
        [12384] = true,
        [12385] = true,
        [12386] = true,
        [12387] = true,
        [12388] = true,
        [12389] = true,
        [12390] = true,
        [12391] = true,
        [12392] = true,
        [12393] = true,
        [12394] = true,
        [12395] = true,
        [12396] = true,
        [12397] = true,
        [12398] = true,
        [12399] = true,
        [12400] = true,
        [12401] = true,
        [12402] = true,
        [12403] = true,
        [12404] = true,
        [12406] = true,
        [12407] = true,
        [12408] = true,
        [12409] = true,
        [12420] = true,
        [12421] = true,
        ----------------------
        -- WotLK event quests
        -- Winter Veil
        [13203] = true, -- A Winter Veil Gift
        [13966] = true, -- A Winter Veil Gift

        -- Noblegarden
        [13479] = true,
        [13480] = true,
        [13483] = true,
        [13484] = true,
        [13502] = true,
        [13503] = true,

        -- Love is in the Air
        [14483] = true,
        [14488] = true,
        [24536] = true,
        [24597] = true,
        [24609] = true,
        [24610] = true,
        [24611] = true,
        [24612] = true,
        [24613] = true,
        [24614] = true,
        [24615] = true,
        [24629] = true,
        [24635] = true,
        [24636] = true,
        [24655] = true,
        [24745] = true,
        [24804] = true,
        [24805] = true,

        -- Kalu'ak Fishing Derby
        [24803] = true,
        [24806] = true,

        -- Children's Week
        [13926] = true,
        [13927] = true,

        -- Hallow's End
        [12940] = true,
        [12941] = true,
        [12944] = true,
        [12945] = true,
        [12946] = true,
        [12947] = true,
        [12950] = true,
        [13433] = true,
        [13434] = true,
        [13435] = true,
        [13436] = true,
        [13437] = true,
        [13438] = true,
        [13439] = true,
        [13448] = true,
        [13452] = true,
        [13456] = true,
        [13459] = true,
        [13460] = true,
        [13461] = true,
        [13462] = true,
        [13463] = true,
        [13464] = true,
        [13465] = true,
        [13466] = true,
        [13467] = true,
        [13468] = true,
        [13469] = true,
        [13470] = true,
        [13471] = true,
        [13472] = true,
        [13473] = true,
        [13474] = true,
        [13501] = true,
        [13548] = true,

        -- Pilgrim's Bounty
        [14022] = true,
        [14023] = true,
        [14024] = true,
        [14028] = true,
        [14030] = true,
        [14033] = true,
        [14035] = true,
        [14036] = true,
        [14037] = true,
        [14040] = true,
        [14041] = true,
        [14043] = true,
        [14044] = true,
        [14047] = true,
        [14048] = true,
        [14051] = true,
        [14053] = true,
        [14054] = true,
        [14055] = true,
        [14058] = true,
        [14059] = true,
        [14060] = true,
        [14061] = true,
        [14062] = true,
        [14064] = true,
        [14065] = true,

        -- Brewfest
        [12193] = true,
        [12194] = true,
        [13931] = true,
        [13932] = true,

        -- Darkmoon Faire
        [7881] = true,
        [7882] = true,
        [7883] = true,
        [7884] = true,
        [7885] = true,
        [7889] = true,
        [7890] = true,
        [7891] = true,
        [7892] = true,
        [7893] = true,
        [7894] = true,
        [7895] = true,
        [7896] = true,
        [7897] = true,
        [7898] = true,
        [7899] = true,
        [7900] = true,
        [7901] = true,
        [7902] = true,
        [7903] = true,
        [7905] = true,
        [7907] = true,
        [7926] = true,
        [7927] = true,
        [7928] = true,
        [7929] = true,
        [7930] = true,
        [7931] = true,
        [7932] = true,
        [7933] = true,
        [7934] = true,
        [7935] = true,
        [7936] = true,
        [7937] = true,
        [7938] = true,
        [7939] = true,
        [7940] = true,
        [7941] = true,
        [7942] = true,
        [7943] = true,
        [7944] = true,
        [7945] = true,
        [7946] = true,
        [7981] = true,
        [8222] = true,
        [8223] = true,
        [9249] = true,
        [10938] = true,
        [10939] = true,
        [10940] = true,
        [10941] = true,
        [13324] = true,
        [13325] = true,
        [13326] = true,
        [13327] = true,

        -- Day of the Dead
        [13952] = true,
        [14166] = true,
        [14167] = true,
        [14168] = true,
        [14169] = true,
        [14170] = true,
        [14171] = true,
        [14172] = true,
        [14173] = true,
        [14174] = true,
        [14175] = true,
        [14176] = true,
        [14177] = true,

        -- Lunar Festival
        [13012] = true,
        [13013] = true,
        [13014] = true,
        [13015] = true,
        [13016] = true,
        [13017] = true,
        [13018] = true,
        [13019] = true,
        [13020] = true,
        [13021] = true,
        [13022] = true,
        [13023] = true,
        [13024] = true,
        [13025] = true,
        [13026] = true,
        [13027] = true,
        [13028] = true,
        [13029] = true,
        [13030] = true,
        [13031] = true,
        [13032] = true,
        [13033] = true,
        [13065] = true,
        [13066] = true,
        [13067] = true,

        -- End of WotLK event quests
        ----------------------------

        -- PvP Quests which are not in the game anymore
        -----------------------------------------------
        -- Vanquish the Invaders
        [7788] = true,
        [7871] = true,
        [7872] = true,
        [7873] = true,
        [8290] = true,
        [8291] = true,
        -- Talisman of Merit
        [7886] = true,
        [7887] = true,
        [7888] = true,
        [7921] = true,
        [8001] = true,
        [8289] = true,
        [8292] = true,
        -- Quell the Silverwing Usurpers
        [7789] = true,
        [7874] = true,
        [7875] = true,
        [7876] = true,
        [8294] = true,
        [8295] = true,
        -- Warsong Mark of Honor
        [7922] = true,
        [7923] = true,
        [7924] = true,
        [7925] = true,
        [8293] = true,
        [8296] = true,
        -- Arathi Basin
        [8081] = true,
        [8124] = true,
        [8157] = true,
        [8158] = true,
        [8159] = true,
        [8163] = true,
        [8164] = true,
        [8165] = true,
        [8298] = true,
        [8300] = true,
        [8565] = true,
        [8566] = true,
        -- Alterac Valley
        [7221] = true,
        [7222] = true,
        [7367] = true,
        [7368] = true,
        -- Master Ryson's All Seeing Eye
        [6847] = true,
        [6848] = true,
        -- WANTED: Orcs and WANTED: Dwarves
        [7401] = true,
        [7402] = true,
        [7427] = true,
        [7428] = true,
        -- Ribbons of Sacrifice
        [8266] = true,
        [8267] = true,
        [8268] = true,
        [8269] = true,

        -- Cenarion plant salve quests (keep searchable, but hide their map pins)
        [996] = HIDE_ON_MAP,
        [998] = HIDE_ON_MAP,
        [1514] = HIDE_ON_MAP,
        [2523] = HIDE_ON_MAP,
        [2878] = HIDE_ON_MAP,
        [3363] = HIDE_ON_MAP,
        [4113] = HIDE_ON_MAP,
        [4114] = HIDE_ON_MAP,
        [4115] = HIDE_ON_MAP,
        [4116] = HIDE_ON_MAP,
        [4117] = HIDE_ON_MAP,
        [4118] = HIDE_ON_MAP,
        [4119] = HIDE_ON_MAP,
        [4221] = HIDE_ON_MAP,
        [4222] = HIDE_ON_MAP,
        [4343] = HIDE_ON_MAP,
        [4401] = HIDE_ON_MAP,
        [4403] = HIDE_ON_MAP,
        [4443] = HIDE_ON_MAP,
        [4444] = HIDE_ON_MAP,
        [4445] = HIDE_ON_MAP,
        [4446] = HIDE_ON_MAP,
        [4447] = HIDE_ON_MAP,
        [4448] = HIDE_ON_MAP,
        [4461] = HIDE_ON_MAP,
        [4462] = HIDE_ON_MAP,
        [4464] = HIDE_ON_MAP,
        [4465] = HIDE_ON_MAP,
        [4466] = HIDE_ON_MAP,
        [4467] = HIDE_ON_MAP,

        [8743] = true, -- Bang a Gong! (AQ40 opening quest)

        ----- TBC -------------- TBC quests --------------- TBC -----
        ----- TBC ------------- starting here -------------- TBC -----

        -- [BETA] quests
        [999] = true, -- When Dreams Turn to Nightmares
        [1005] = true, -- What Lurks Beyond
        [1006] = true, -- What Lies Beyond
        [1099] = true, -- Goblins Win!
        [1500] = true, -- Waking Naralex
        [8478] = true, -- Choose Your Weapon
        [8489] = true, -- An Intact Converter
        [8896] = true, -- The Dwarven Spy
        [9342] = true, -- Marauding Crust Bursters
        [9344] = true, -- A Hasty Departure
        [9346] = true, -- When Helboars Fly
        [9357] = true, -- Report to Aeldon Sunbrand
        [9382] = true, -- The Fate of the Clefthoof
        [9408] = true, -- Forgotten Heroes
        [9511] = true, -- Kargath's Battle Plans
        [9568] = true, -- On the Offensive
        [9749] = true, -- They're Alive! Maybe...
        [9929] = true, -- The Missing Merchant
        [9930] = true, -- The Missing Merchant
        [9941] = true, -- Tracking Down the Culprits
        [9942] = true, -- Tracking Down the Culprits
        [9943] = true, -- Return to Thander
        [9947] = true, -- Return to Rokag
        [9952] = true, -- Prospector Balmoral
        [9953] = true, -- Lookout Nodak
        [9958] = true, -- Scouting the Defenses
        [9959] = true, -- Scouting the Defenses
        [9963] = true, -- Seeking Help from the Source
        [9964] = true, -- Seeking Help from the Source
        [9965] = true, -- A Show of Good Faith
        [9966] = true, -- A Show of Good Faith
        [9969] = true, -- The Final Reagents
        [9974] = true, -- The Final Reagents
        [9975] = true, -- Primal Magic
        [9976] = true, -- Primal Magic
        [9980] = true, -- Rescue Deirom!
        [9981] = true, -- Rescue Dugar!
        [9984] = true, -- Host of the Hidden City
        [9985] = true, -- Host of the Hidden City
        [9988] = true, -- A Dandy's Best Friend
        [9989] = true, -- Alien Spirits
        [10014] = true, -- The Firewing Point Project
        [10015] = true, -- The Firewing Point Project
        [10029] = true, -- The Spirits Are Calling
        [10046] = true, -- Through the Dark Portal
        [10053] = true, -- Dealing with Zeth'Gor
        [10054] = true, -- Impending Doom
        [10056] = true, -- Bleeding Hollow Supplies
        [10059] = true, -- Dealing With Zeth'Gor
        [10060] = true, -- Impending Doom
        [10061] = true, -- The Unyielding
        [10062] = true, -- Looking to the Leadership
        [10084] = true, -- Assault on Mageddon
        [10089] = true, -- Forge Camps of the Legion
        [10092] = true, -- Assault on Mageddon
        [10100] = true, -- The Mastermind
        [10122] = true, -- The Citadel's Reach
        [10125] = true, -- Mission: Disrupt Communications
        [10126] = true, -- Warboss Nekrogg's Orders
        [10127] = true, -- Mission: Sever the Tie
        [10128] = true, -- Saving Private Imarion
        [10130] = true, -- The Western Flank
        [10131] = true, -- Planning the Escape
        [10133] = true, -- Mission: Kill the Messenger
        [10135] = true, -- Mission: Be the Messenger
        [10137] = true, -- Provoking the Warboss
        [10138] = true, -- Under Whose Orders?
        [10139] = true, -- Dispatching the Commander
        [10147] = true, -- Mission: Kill the Messenger
        [10148] = true, -- Mission: Be the Messenger
        [10149] = true, -- Mission: End All, Be All
        [10150] = true, -- The Citadel's Reach
        [10151] = true, -- Warboss Nekrogg's Orders
        [10152] = true, -- The Western Flank
        [10153] = true, -- Saving Scout Makha
        [10154] = true, -- Planning the Escape
        [10155] = true, -- Provoking the Warboss
        [10156] = true, -- Under Whose Orders?
        [10157] = true, -- Dispatching the Commander
        [10158] = true, -- Bleeding Hollow Supplies
        [10179] = true, -- The Custodian of Kirin'Var
        [10187] = true, -- A Message for the Archmage
        [10195] = true, -- Mercenary See, Mercenary Do
        [10196] = true, -- More Arakkoa Feathers
        [10244] = true, -- R.T.F.R.C.M.
        [10260] = true, -- Netherologist Coppernickels
        [10292] = true, -- More Power!
        [10375] = true, -- Obsidian Warbeads
        [10386] = true, -- The Fel Reaver Slayer
        [10387] = true, -- The Fel Reaver Slayer
        [10398] = true, -- Return to Honor Hold
        [10401] = true, -- Mission: End All, Be All
        [10404] = true, -- Against the Legion
        [10441] = true, -- Peddling the Goods
        [10737] = true, -- The Master's Touch
        [10815] = true, -- The Journal of Val'zareq: Portends of War
        [10841] = true, -- The Vengeful Harbringer
        [10844] = true, -- Forge Camp: Anger
        [10872] = true, -- Zuluhed the Whacked
        [10925] = true, -- Evil Draws Near

        -- <NYI> quests
        [3482] = true, -- <NYI> <TXT> The Pocked Black Box

        -- [Not Used] quests
        [2019] = true, -- Tools of the Trade
        [9510] = true, -- BETA Bristlehide Clefthoof Hides
        [11027] = true, -- NOT IN GAME: Yous Have Da Darkrune? , "replaced" by 11060 (A Crystalforged Darkrune)

        [8329] = true, -- Warrior Training / Not in the game
        [8547] = true, -- Welcome!
        [9065] = true, -- Unavailable quest "The "Chow" Quest (123)aa"
        [9278] = true, -- Welcome!
        [9926] = true, -- FLAG Shadow Council/Warmaul Questline
        [10048] = true, -- A Handful of Magic Dust BETA
        [10049] = true, -- A Handful of Magic Dust BETA
        [10169] = true, -- Losing Gracefully (removed with 2.4.0)
        [10259] = true, -- Into the Breach (TBC Pre patch event)
        [10364] = true, -- Caedmos (Unavailable Priest quest)
        [10531] = true, -- The Battle for Arathi Basin!
        [10532] = true, -- Cut Arathor Supply Lines
        [10533] = true, -- More Resource Crates
        [10534] = true, -- Returning Home (Unavailable Priest quest)
        [10535] = true, -- Arathi Basin Resources!
        [10536] = true, -- More Resource Crates
        [10539] = true, -- Returning Home (Unavailable Priest quest)
        [10638] = true, -- NOT A QUEST (Unavailable Priest quest)
        [10779] = true, -- The Hunter's Path (Unused)
        [10931] = true, -- Level 0 Priest quest
        [10932] = true, -- Level 0 Priest quest
        [10933] = true, -- Level 0 Priest quest
        [10934] = true, -- Level 0 Priest quest

        -- Revered Among X quests
        [10459] = true,
        [10558] = true,
        [10559] = true,
        [10560] = true,
        [10561] = true,

        [11497] = true, -- Learning to Fly (requires NOT to have flying skill, which can't be handled atm)
        [11498] = true, -- Learning to Fly (requires NOT to have flying skill, which can't be handled atm)

        -- [OLD] quests. Classic quests deprecated in TBC
        [708] = true,
        [1288] = true,
        [1661] = QuestieCorrections.TBC_AND_WOTLK,
        [3366] = true,
        [3381] = true,
        [6131] = true,
        [6221] = true,
        [6241] = true,
        [7364] = true,
        [7365] = true,
        [7421] = true,
        [7422] = true,
        [7423] = true,
        [7425] = true,
        [7426] = true,
        [7521] = true,
        [7522] = true,
        [8368] = true,
        [8383] = true,
        [8387] = true,
        [8411] = true,
        [8426] = true,
        [8427] = true,
        [8428] = true,
        [8429] = true,
        [8430] = true,
        [9712] = true,
        [11052] = true,

        -- Phase 4 Zul'Aman
        [11195] = true, -- Not in the game
        [11196] = true, -- Not in the game

        ----- WotLK -------------- WotLK quests --------------- WotLK -----
        ----- WotLK ------------- starting here -------------- WotLK -----

        [10445] = QuestieCorrections.WOTLK_ONLY, -- Got replaced by 13432
        [10985] = QuestieCorrections.WOTLK_ONLY, -- Got replaced by 13429
        [11621] = true, -- Not in the game
        [11622] = true, -- Not in the game
        [11939] = true, -- Not in the game
        [12021] = true, -- Duplicate of 12067 and 12085 (not entirely a duplicate but this is the easiest way to hide multiple quests)
        [12051] = true, -- Not in the game
        [12162] = true, -- Not in the game
        [12163] = true, -- Not in the game
        [12479] = true, -- Not in the game
        [12480] = true, -- Not in the game
        [12490] = true, -- Not in the game
        [12586] = true, -- Not in the game
        [12780] = true, -- Not in the game
        [12825] = true, -- Not in the game
        [12834] = true, -- Not in the game
        [12835] = true, -- Not in the game
        [12837] = true, -- Not in the game
        [12881] = true, -- Not in the game
        [12890] = true, -- Not in the game
        [12990] = true, -- Not in the game
        [13150] = true, -- Not in the game
        [13173] = true, -- Not in the game
        [13175] = true, -- Not in the game
        [13176] = true, -- Not in the game
        [13184] = true, -- Not in the game
        [13374] = true, -- Not in the game
        [13825] = true, -- EXISTS ingame, but can only be picked up if quest 6610 was completed PRIOR to wrath - impossible for us to discern eligibility, better to hide than misinform everyone
        [13826] = true, -- EXISTS ingame, but can only be picked up if quest 6607 was completed PRIOR to wrath - impossible for us to discern eligibility, better to hide than misinform everyone
        [13908] = true, -- Not in the game
        [14032] = true, -- Not in the game
        [14160] = true, -- Not in the game
        [14203] = true, -- Not in the game
        [14351] = true, -- Not in the game


        [6804] = QuestieCorrections.WOTLK_ONLY,
        [7737] = QuestieCorrections.WOTLK_ONLY, -- replaced by 13662 in wotlk
        [9094] = QuestieCorrections.WOTLK_ONLY,
        [9317] = QuestieCorrections.WOTLK_ONLY,
        [9318] = QuestieCorrections.WOTLK_ONLY,
        [9320] = QuestieCorrections.WOTLK_ONLY,
        [9321] = QuestieCorrections.WOTLK_ONLY,
        [9333] = QuestieCorrections.WOTLK_ONLY,
        [9334] = QuestieCorrections.WOTLK_ONLY,
        [9335] = QuestieCorrections.WOTLK_ONLY,
        [9336] = QuestieCorrections.WOTLK_ONLY,
        [9337] = QuestieCorrections.WOTLK_ONLY,
        [9341] = QuestieCorrections.WOTLK_ONLY,
        [9343] = QuestieCorrections.WOTLK_ONLY,

        -- Old Naxx quests (Naxx40 goes away in wotlk)
        [9120] = QuestieCorrections.WOTLK_ONLY, -- The Fall of Kel'Thuzad
        [9229] = QuestieCorrections.WOTLK_ONLY, -- The Fate of Ramaladni
        [9230] = QuestieCorrections.WOTLK_ONLY, -- Ramaladni's Icy Grasp
        [9232] = QuestieCorrections.WOTLK_ONLY, -- The Only Song I Know...
        [9233] = QuestieCorrections.WOTLK_ONLY, -- Omarion's Handbook
        [9234] = QuestieCorrections.WOTLK_ONLY, -- Icebane Gauntlets
        [9235] = QuestieCorrections.WOTLK_ONLY, -- Icebane Bracers
        [9236] = QuestieCorrections.WOTLK_ONLY, -- Icebane Breastplate
        [9237] = QuestieCorrections.WOTLK_ONLY, -- Glacial Cloak
        [9238] = QuestieCorrections.WOTLK_ONLY, -- Glacial Wrists
        [9239] = QuestieCorrections.WOTLK_ONLY, -- Glacial Gloves
        [9240] = QuestieCorrections.WOTLK_ONLY, -- Glacial Vest
        [9241] = QuestieCorrections.WOTLK_ONLY, -- Polar Bracers
        [9242] = QuestieCorrections.WOTLK_ONLY, -- Polar Gloves
        [9243] = QuestieCorrections.WOTLK_ONLY, -- Polar Tunic
        [9244] = QuestieCorrections.WOTLK_ONLY, -- Icy Scale Bracers
        [9245] = QuestieCorrections.WOTLK_ONLY, -- Icy Scale Gauntlets
        [9246] = QuestieCorrections.WOTLK_ONLY, -- Icy Scale Breastplate

        -- Vanilla Onyxia Alliance attunement
        [4182] = QuestieCorrections.WOTLK_ONLY,
        [4241] = QuestieCorrections.WOTLK_ONLY,
        [4242] = QuestieCorrections.WOTLK_ONLY,
        [4264] = QuestieCorrections.WOTLK_ONLY,
        [4282] = QuestieCorrections.WOTLK_ONLY,
        [4322] = QuestieCorrections.WOTLK_ONLY,
        [6402] = QuestieCorrections.WOTLK_ONLY,
        [6403] = QuestieCorrections.WOTLK_ONLY,
        [6501] = QuestieCorrections.WOTLK_ONLY,
        [6502] = QuestieCorrections.WOTLK_ONLY,

        -- "learn to ride" series (unimplemented)
        [14079] = true, -- elwynn (human)
        [14081] = true, -- eversong (belf)
        [14082] = true, -- exodar (draenei)
        [14083] = true, -- dun morogh (dwarf)
        [14084] = true, -- dun morogh (gnome)
        [14085] = true, -- darnassus (nelf)
        [14086] = true, -- orgrimmar (orc)
        [14087] = true, -- mulgore (tauren)
        [14088] = true, -- durotar (troll)
        [14089] = true, -- tirisfal (undead)

        -- Phase 2: Secrets of Ulduar
        [13372] = true, -- 10man EoE keys become unavailable with P2
        [13384] = true, -- 10man EoE keys become unavailable with P2

        -- AzerothCore quests disabled by the final `disables` SQL state.
        [1] = true,
        [73] = true,
        [108] = true,
        [137] = true,
        [241] = true,
        [242] = true,
        [259] = true,
        [260] = true,
        [316] = true,
        [326] = true,
        [327] = true,
        [352] = true,
        [390] = true,
        [402] = true,
        [406] = true,
        [462] = true,
        [490] = true,
        [497] = true,
        [534] = true,
        [548] = true,
        [550] = true,
        [612] = true,
        [620] = true,
        [636] = true,
        [740] = true,
        [774] = true,
        [785] = true,
        [796] = true,
        [797] = true,
        [798] = true,
        [799] = true,
        [800] = true,
        [801] = true,
        [802] = true,
        [803] = true,
        [807] = true,
        [810] = true,
        [811] = true,
        [814] = true,
        [820] = true,
        [839] = true,
        [856] = true,
        [859] = true,
        [904] = true,
        [908] = true,
        [909] = true,
        [912] = true,
        [946] = true,
        [960] = true,
        [987] = true,
        [988] = true,
        [989] = true,
        [1128] = true,
        [1129] = true,
        [1155] = true,
        [1156] = true,
        [1157] = true,
        [1158] = true,
        [1161] = true,
        [1162] = true,
        [1163] = true,
        [1165] = true,
        [1174] = true,
        [1263] = true,
        [1272] = true,
        [1277] = true,
        [1278] = true,
        [1279] = true,
        [1280] = true,
        [1281] = true,
        [1283] = true,
        [1289] = true,
        [1290] = true,
        [1291] = true,
        [1292] = true,
        [1293] = true,
        [1294] = true,
        [1295] = true,
        [1296] = true,
        [1297] = true,
        [1298] = true,
        [1299] = true,
        [1300] = true,
        [1318] = true,
        [1390] = true,
        [1397] = true,
        [1441] = true,
        [1443] = true,
        [1460] = true,
        [1461] = true,
        [1533] = true,
        [1537] = true,
        [1538] = true,
        [1659] = true,
        [1660] = true,
        [1662] = true,
        [1663] = true,
        [1664] = true,
        [2018] = true,
        [2020] = true,
        [2058] = true,
        [2059] = true,
        [2868] = true,
        [2971] = true,
        [3023] = true,
        [3064] = true,
        [3111] = true,
        [3241] = true,
        [3383] = true,
        [3384] = true,
        [3401] = true,
        [3403] = true,
        [3404] = true,
        [3405] = true,
        [3422] = true,
        [3423] = true,
        [3424] = true,
        [3425] = true,
        [3515] = true,
        [3516] = true,
        [3529] = true,
        [3530] = true,
        [3531] = true,
        [3581] = true,
        [3622] = true,
        [3623] = true,
        [3624] = true,
        [3631] = true,
        [3644] = true,
        [3645] = true,
        [3646] = true,
        [3647] = true,
        [3885] = true,
        [3910] = true,
        [4183] = true,
        [4184] = true,
        [4185] = true,
        [4186] = true,
        [4223] = true,
        [4224] = true,
        [4299] = true,
        [4323] = true,
        [4487] = true,
        [4488] = true,
        [4489] = true,
        [4490] = true,
        [4541] = true,
        [4905] = true,
        [5053] = true,
        [5101] = true,
        [5205] = true,
        [5207] = true,
        [5208] = true,
        [5209] = true,
        [5303] = true,
        [5304] = true,
        [5383] = true,
        [5506] = true,
        [5512] = true,
        [5516] = true,
        [5520] = true,
        [5523] = true,
        [5530] = true,
        [5532] = true,
        [5627] = true,
        [5628] = true,
        [5629] = true,
        [5630] = true,
        [5631] = true,
        [5632] = true,
        [5633] = true,
        [5634] = true,
        [5635] = true,
        [5636] = true,
        [5637] = true,
        [5638] = true,
        [5639] = true,
        [5640] = true,
        [5641] = true,
        [5642] = true,
        [5643] = true,
        [5644] = true,
        [5645] = true,
        [5646] = true,
        [5647] = true,
        [5652] = true,
        [5653] = true,
        [5654] = true,
        [5655] = true,
        [5656] = true,
        [5657] = true,
        [5658] = true,
        [5659] = true,
        [5660] = true,
        [5661] = true,
        [5662] = true,
        [5663] = true,
        [5664] = true,
        [5665] = true,
        [5666] = true,
        [5667] = true,
        [5668] = true,
        [5669] = true,
        [5670] = true,
        [5671] = true,
        [5672] = true,
        [5673] = true,
        [5674] = true,
        [5675] = true,
        [5676] = true,
        [5677] = true,
        [5678] = true,
        [5679] = true,
        [5680] = true,
        [5681] = true,
        [5682] = true,
        [5683] = true,
        [5684] = true,
        [5685] = true,
        [5686] = true,
        [5687] = true,
        [5688] = true,
        [5689] = true,
        [5690] = true,
        [5691] = true,
        [5692] = true,
        [5693] = true,
        [5694] = true,
        [5695] = true,
        [5696] = true,
        [5697] = true,
        [5698] = true,
        [5699] = true,
        [5700] = true,
        [5701] = true,
        [5702] = true,
        [5703] = true,
        [5704] = true,
        [5705] = true,
        [5706] = true,
        [5707] = true,
        [5708] = true,
        [5709] = true,
        [5710] = true,
        [5711] = true,
        [5712] = true,
        [6003] = true,
        [6144] = true,
        [6145] = true,
        [6165] = true,
        [6201] = true,
        [6202] = true,
        [6521] = true,
        [6522] = true,
        [6702] = true,
        [6703] = true,
        [6704] = true,
        [6705] = true,
        [6706] = true,
        [6707] = true,
        [6708] = true,
        [6709] = true,
        [6710] = true,
        [6711] = true,
        [6841] = true,
        [6842] = true,
        [7069] = true,
        [7181] = true,
        [7202] = true,
        [7381] = true,
        [7382] = true,
        [7384] = true,
        [7561] = true,
        [7681] = true,
        [7682] = true,
        [7741] = true,
        [7790] = true,
        [7797] = true,
        [7869] = true,
        [7870] = true,
        [7904] = true,
        [7906] = true,
        [7961] = true,
        [7962] = true,
        [8002] = true,
        [8021] = true,
        [8022] = true,
        [8023] = true,
        [8024] = true,
        [8025] = true,
        [8026] = true,
        [8080] = true,
        [8123] = true,
        [8152] = true,
        [8154] = true,
        [8155] = true,
        [8156] = true,
        [8160] = true,
        [8161] = true,
        [8162] = true,
        [8226] = true,
        [8230] = true,
        [8237] = true,
        [8244] = true,
        [8245] = true,
        [8247] = true,
        [8248] = true,
        [8270] = true,
        [8274] = true,
        [8297] = true,
        [8299] = true,
        [8337] = true,
        [8339] = true,
        [8340] = true,
        [8367] = true,
        [8371] = true,
        [8384] = true,
        [8385] = true,
        [8386] = true,
        [8388] = true,
        [8389] = true,
        [8390] = true,
        [8391] = true,
        [8392] = true,
        [8397] = true,
        [8398] = true,
        [8404] = true,
        [8405] = true,
        [8406] = true,
        [8407] = true,
        [8408] = true,
        [8431] = true,
        [8432] = true,
        [8433] = true,
        [8434] = true,
        [8435] = true,
        [8440] = true,
        [8441] = true,
        [8442] = true,
        [8443] = true,
        [8444] = true,
        [8445] = true,
        [8448] = true,
        [8449] = true,
        [8450] = true,
        [8451] = true,
        [8452] = true,
        [8453] = true,
        [8454] = true,
        [8458] = true,
        [8459] = true,
        [8530] = true,
        [8531] = true,
        [8567] = true,
        [8568] = true,
        [8569] = true,
        [8570] = true,
        [8571] = true,
        [8617] = true,
        [8618] = true,
        [8869] = true,
        [8897] = true,
        [8898] = true,
        [8899] = true,
        [8971] = true,
        [8972] = true,
        [8973] = true,
        [8974] = true,
        [8975] = true,
        [8976] = true,
        [9031] = true,
        [9034] = true,
        [9036] = true,
        [9037] = true,
        [9038] = true,
        [9039] = true,
        [9040] = true,
        [9041] = true,
        [9042] = true,
        [9043] = true,
        [9044] = true,
        [9046] = true,
        [9047] = true,
        [9048] = true,
        [9049] = true,
        [9050] = true,
        [9054] = true,
        [9055] = true,
        [9056] = true,
        [9057] = true,
        [9058] = true,
        [9059] = true,
        [9060] = true,
        [9061] = true,
        [9068] = true,
        [9069] = true,
        [9070] = true,
        [9071] = true,
        [9072] = true,
        [9073] = true,
        [9074] = true,
        [9075] = true,
        [9077] = true,
        [9078] = true,
        [9079] = true,
        [9080] = true,
        [9081] = true,
        [9082] = true,
        [9083] = true,
        [9084] = true,
        [9086] = true,
        [9087] = true,
        [9088] = true,
        [9089] = true,
        [9090] = true,
        [9091] = true,
        [9092] = true,
        [9093] = true,
        [9095] = true,
        [9096] = true,
        [9097] = true,
        [9098] = true,
        [9099] = true,
        [9100] = true,
        [9101] = true,
        [9102] = true,
        [9103] = true,
        [9104] = true,
        [9105] = true,
        [9106] = true,
        [9107] = true,
        [9108] = true,
        [9109] = true,
        [9110] = true,
        [9111] = true,
        [9112] = true,
        [9113] = true,
        [9114] = true,
        [9115] = true,
        [9116] = true,
        [9117] = true,
        [9118] = true,
        [9168] = true,
        [9231] = true,
        [9273] = true,
        [9284] = true,
        [9285] = true,
        [9286] = true,
        [9296] = true,
        [9297] = true,
        [9298] = true,
        [9306] = true,
        [9307] = true,
        [9308] = true,
        [9316] = true,
        [9319] = true,
        [9322] = true,
        [9323] = true,
        [9347] = true,
        [9350] = true,
        [9353] = true,
        [9354] = true,
        [9367] = true,
        [9368] = true,
        [9378] = true,
        [9379] = true,
        [9380] = true,
        [9384] = true,
        [9386] = true,
        [9388] = true,
        [9389] = true,
        [9411] = true,
        [9412] = true,
        [9413] = true,
        [9414] = true,
        [9445] = true,
        [9458] = true,
        [9459] = true,
        [9477] = true,
        [9478] = true,
        [9479] = true,
        [9480] = true,
        [9481] = true,
        [9482] = true,
        [9497] = true,
        [9507] = true,
        [9546] = true,
        [9577] = true,
        [9583] = true,
        [9596] = true,
        [9597] = true,
        [9599] = true,
        [9611] = true,
        [9613] = true,
        [9614] = true,
        [9615] = true,
        [9650] = true,
        [9651] = true,
        [9652] = true,
        [9653] = true,
        [9654] = true,
        [9655] = true,
        [9656] = true,
        [9657] = true,
        [9658] = true,
        [9659] = true,
        [9660] = true,
        [9661] = true,
        [9662] = true,
        [9679] = true,
        [9695] = true,
        [9745] = true,
        [9750] = true,
        [9754] = true,
        [9755] = true,
        [9767] = true,
        [9768] = true,
        [9880] = true,
        [9881] = true,
        [9908] = true,
        [9909] = true,
        [9949] = true,
        [9950] = true,
        [10083] = true,
        [10088] = true,
        [10090] = true,
        [10145] = true,
        [10181] = true,
        [10207] = true,
        [10214] = true,
        [10215] = true,
        [10370] = true,
        [10376] = true,
        [10377] = true,
        [10378] = true,
        [10379] = true,
        [10402] = true,
        [10452] = true,
        [10453] = true,
        [10454] = true,
        [10549] = true,
        [10616] = true,
        [10631] = true,
        [10716] = true,
        [10743] = true,
        [10746] = true,
        [10787] = true,
        [10871] = true,
        [10888] = true,
        [10890] = true,
        [10901] = true,
        [10960] = true,
        [11088] = true,
        [11121] = true,
        [11125] = true,
        [11127] = true,
        [11179] = true,
        [11197] = true,
        [11226] = true,
        [11320] = true,
        [11334] = true,
        [11335] = true,
        [11336] = true,
        [11337] = true,
        [11338] = true,
        [11339] = true,
        [11340] = true,
        [11341] = true,
        [11342] = true,
        [11345] = true,
        [11347] = true,
        [11425] = true,
        [11435] = true,
        [11437] = true,
        [11438] = true,
        [11444] = true,
        [11445] = true,
        [11461] = true,
        [11462] = true,
        [11493] = true,
        [11522] = true,
        [11551] = true,
        [11552] = true,
        [11553] = true,
        [11577] = true,
        [11578] = true,
        [11579] = true,
        [11588] = true,
        [11589] = true,
        [11874] = true,
        [11934] = true,
        [11937] = true,
        [11974] = true,
        [11987] = true,
        [11992] = true,
        [11994] = true,
        [11997] = true,
        [12001] = true,
        [12015] = true,
        [12018] = true,
        [12024] = true,
        [12025] = true,
        [12087] = true,
        [12103] = true,
        [12108] = true,
        [12156] = true,
        [12179] = true,
        [12228] = true,
        [12233] = true,
        [12313] = true,
        [12426] = true,
        [12445] = true,
        [12493] = true,
        [12590] = true,
        [12600] = true,
        [12626] = true,
        [12682] = true,
        [12731] = true,
        [12764] = true,
        [12765] = true,
        [12911] = true,
        [12923] = true,
        [13123] = true,
        [13210] = true,
        [13303] = true,
        [13317] = true,
        [13381] = true,
        [13405] = true,
        [13407] = true,
        [13427] = true,
        [13428] = true,
        [13475] = true,
        [13476] = true,
        [13477] = true,
        [13478] = true,
        [13541] = true,
        [13649] = true,
        [13827] = true,
        [13840] = true,
        [13990] = true,
        [14106] = true,
        [14119] = true,
        [14147] = true,
        [14148] = true,
        [14149] = true,
        [14150] = true,
        [14163] = true,
        [14164] = true,
        [14178] = true,
        [14179] = true,
        [14180] = true,
        [14181] = true,
        [14182] = true,
        [14183] = true,
        [14441] = true,
        [24216] = true,
        [24217] = true,
        [24218] = true,
        [24219] = true,
        [24220] = true,
        [24221] = true,
        [24222] = true,
        [24223] = true,
        [24224] = true,
        [24225] = true,
        [24226] = true,
        [24227] = true,
        [24426] = true,
        [24427] = true,
        [24661] = true,
        [24746] = true,
        [24797] = true,
        [25485] = true,

        -- Automatic overrides (for when Wowhead data is wrong)
        [13134] = false, -- Spill Their Blood
        [13136] = false, -- Jagged Shards
        [13138] = false, -- I'm Smelting... Smelting!
        [13140] = false, -- The Runesmiths of Malykriss
        [13144] = false, -- Killing Two Scourge With One Skeleton
        [13152] = false, -- A Visit to the Doctor
        [13161] = false, -- The Rider of the Unholy
        [13162] = false, -- The Rider of the Frost
        [13163] = false, -- The Rider of the Blood
        [13211] = false, -- By Fire Be Purged
        [13212] = false, -- He's Gone to Pieces
        [13220] = false, -- Putting Olakin Back Together Again
        [13221] = false, -- I'm Not Dead Yet!
        [13229] = false, -- I'm Not Dead Yet!
        [13235] = false, -- The Flesh Giant Champion
        [13331] = false, -- Keeping the Alliance Blind
        [13359] = false, -- Where Dragons Fell
    }

    return questsToBlacklist
end

QuestieQuestBlacklist.AQWarEffortQuests = {
    -- Commendation Signet
    [8811] = true,
    [8812] = true,
    [8813] = true,
    [8814] = true,
    [8815] = true,
    [8816] = true,
    [8817] = true,
    [8818] = true,
    [8819] = true,
    [8820] = true,
    [8821] = true,
    [8822] = true,
    [8823] = true,
    [8824] = true,
    [8825] = true,
    [8826] = true,
    [8830] = true,
    [8831] = true,
    [8832] = true,
    [8833] = true,
    [8834] = true,
    [8835] = true,
    [8836] = true,
    [8837] = true,
    [8838] = true,
    [8839] = true,
    [8840] = true,
    [8841] = true,
    [8842] = true,
    [8843] = true,
    [8844] = true,
    [8845] = true,
    [8846] = true,
    [8847] = true,
    [8848] = true,
    [8849] = true,
    [8850] = true,
    [8851] = true,
    [8852] = true,
    [8853] = true,
    [8854] = true,
    [8855] = true,
    -- War Effort
    [8492] = true,
    [8493] = true,
    [8494] = true,
    [8495] = true,
    [8499] = true,
    [8500] = true,
    [8503] = true,
    [8504] = true,
    [8505] = true,
    [8506] = true,
    [8509] = true,
    [8510] = true,
    [8511] = true,
    [8512] = true,
    [8513] = true,
    [8514] = true,
    [8515] = true,
    [8516] = true,
    [8517] = true,
    [8518] = true,
    [8520] = true,
    [8521] = true,
    [8522] = true,
    [8523] = true,
    [8524] = true,
    [8525] = true,
    [8526] = true,
    [8527] = true,
    [8528] = true,
    [8529] = true,
    [8532] = true,
    [8533] = true,
    [8542] = true,
    [8543] = true,
    [8545] = true,
    [8546] = true,
    [8549] = true,
    [8550] = true,
    [8580] = true,
    [8581] = true,
    [8582] = true,
    [8583] = true,
    [8588] = true,
    [8589] = true,
    [8590] = true,
    [8591] = true,
    [8600] = true,
    [8601] = true,
    [8604] = true,
    [8605] = true,
    [8607] = true,
    [8608] = true,
    [8609] = true,
    [8610] = true,
    [8611] = true,
    [8612] = true,
    [8613] = true,
    [8614] = true,
    [8615] = true,
    [8616] = true,
    [8792] = true,
    [8793] = true,
    [8794] = true,
    [8795] = true,
    [8796] = true,
    [8797] = true,
    [10500] = true,
    [10501] = true,
}

QuestieQuestBlacklist.ScourgeInvasionQuests = {
    -- Scourge Invasion (Classic Phase 6)
    [9085] = true, -- Shadows of Doom
    [9153] = true, -- Under the Shadow
    [9154] = true, -- Light's Hope Chapel
    [9247] = true, -- The Keeper's Call
    [9260] = true, -- Investigate the Scourge of Stormwind
    [9261] = true, -- Investigate the Scourge of Ironforge
    [9262] = true, -- Investigate the Scourge of Darnassus
    [9263] = true, -- Investigate the Scourge of Orgrimmar
    [9264] = true, -- Investigate the Scourge of Thunder Bluff
    [9265] = true, -- Investigate the Scourge of the Undercity
    [9292] = true, -- Cracked Necrotic Crystal
    [9295] = true, -- Letter from the Front
    [9299] = true, -- Note from the Front
    [9300] = true, -- Page from the Front
    [9301] = true, -- Envelope from the Front
    [9302] = true, -- Missive from the Front
    [9304] = true, -- Document from the Front
    [9310] = true, -- Faint Necrotic Crystal
    -- Scourge Invasion (WotLK pre-patch)
    [12616] = true, -- Chamber of Secrets
    [12752] = true, -- Desperate Research
    [12753] = true, -- A Desperate Alliance
    [12772] = true, -- A Desperate Alliance
    [12775] = true, -- A Desperate Alliance
    [12777] = true, -- A Desperate Alliance
    [12782] = true, -- Desperate Research
    [12783] = true, -- Desperate Research
    [12784] = true, -- Desperate Research
    [12808] = true, -- A Desperate Alliance
    [12811] = true, -- Desperate Research
    [12816] = true, -- Investigate the Scourge of Silvermoon
    [12817] = true, -- Investigate the Scourge of Azuremyst
}

QuestieQuestBlacklist.SunsReachQuests = {
    -- Battle for Sun's Reach (Isle of Quel'Danas worldstate event)
    [11496] = true, -- Sanctum Wards
    [11513] = true, -- Intercepting the Mana Cells
    [11520] = true, -- Discovering Your Roots
    [11524] = true, -- Erratic Behavior
    [11532] = true, -- Distraction at the Dead Scar
    [11535] = true, -- Making Ready
    [11538] = true, -- Battle for the Sun's Reach Armory
    [11539] = true, -- Taking the Harbor
    [11542] = true, -- Intercept the Reinforcements
    [11545] = true, -- A Charitable Donation
    [11549] = true, -- A Magnanimous Benefactor
}

function QuestieQuestBlacklist.LoadAutoBlacklistWotlk()
    return {
        --! 1.11.1
        -- Battlegrounds -> Alterac Valley (6 -> 2597)
        [7361] = true, --* Favor Amongst the Darkspear (https://www.wowhead.com/wotlk/quest=7361) (Retail Data)
        [7362] = true, --* Ally of the Tauren (https://www.wowhead.com/wotlk/quest=7362) (Retail Data)
        [7363] = true, --* The Human Condition (https://www.wowhead.com/wotlk/quest=7363) (Retail Data)
        [7364] = true, --* Gnomeregan Bounty (https://www.wowhead.com/wotlk/quest=7364) (Retail Data)
        [7365] = true, --* Staghelm's Requiem (https://www.wowhead.com/wotlk/quest=7365) (Retail Data)
        [7366] = true, --* The Archbishop's Mercy (https://www.wowhead.com/wotlk/quest=7366) (Retail Data)
        [7401] = true, --* WANTED: Dwarves! (https://www.wowhead.com/wotlk/quest=7401) (Retail Data)
        [7402] = true, --* WANTED: Orcs! (https://www.wowhead.com/wotlk/quest=7402) (Retail Data)

        -- Classes -> Rogue (4 -> -162)
        [2019] = true, --* Tools of the Trade (https://www.wowhead.com/wotlk/quest=2019) (Retail Data)

        -- Uncategorized ->  (-2 -> 0)
        [6843] = true, --* Da Foo (https://www.wowhead.com/wotlk/quest=6843) (Retail Data)

        -- Battlegrounds -> Warsong Gulch (6 -> 3277)
        [7886] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=7886) (Retail Data)
        [7887] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=7887) (Retail Data)
        [7888] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=7888) (Retail Data)
        [7921] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=7921) (Retail Data)
        [7922] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=7922) (Retail Data)
        [7923] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=7923) (Retail Data)
        [7924] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=7924) (Retail Data)
        [7925] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=7925) (Retail Data)
        [8001] = true, --* Warsong Outriders <NYI> <TXT> (https://www.wowhead.com/wotlk/quest=8001) (Retail Data)
        [8267] = true, --* Ribbons of Sacrifice (https://www.wowhead.com/wotlk/quest=8267) (Retail Data)
        [8269] = true, --* Ribbons of Sacrifice (https://www.wowhead.com/wotlk/quest=8269) (Retail Data)
        [8289] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=8289) (Retail Data)
        [8292] = true, --* Talismans of Merit (https://www.wowhead.com/wotlk/quest=8292) (Retail Data)
        [8293] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=8293) (Retail Data)
        [8296] = true, --* Mark of Honor (https://www.wowhead.com/wotlk/quest=8296) (Retail Data)

        -- Battlegrounds -> Alterac Valley (6 -> 2597)
        [7421] = true, --* Darkspear Defense (https://www.wowhead.com/wotlk/quest=7421) (Retail Data)
        [7422] = true, --* Tuft it Out (https://www.wowhead.com/wotlk/quest=7422) (Retail Data)
        [7423] = true, --* I've Got A Fever For More Bone Chips (https://www.wowhead.com/wotlk/quest=7423) (Retail Data)
        [7424] = true, --* What the Hoof? (https://www.wowhead.com/wotlk/quest=7424) (Retail Data)
        [7425] = true, --* Staghelm's Mojo Jamboree (https://www.wowhead.com/wotlk/quest=7425) (Retail Data)
        [7426] = true, --* One Man's Love (https://www.wowhead.com/wotlk/quest=7426) (Retail Data)
        [7427] = true, --* Wanted: MORE DWARVES! (https://www.wowhead.com/wotlk/quest=7427) (Retail Data)
        [7428] = true, --* Wanted: MORE ORCS! (https://www.wowhead.com/wotlk/quest=7428) (Retail Data)

        -- Battlegrounds -> Arathi Basin (6 -> 3358)
        [8081] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8081) (Retail Data)
        [8124] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8124) (Retail Data)
        [8157] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8157) (Retail Data)
        [8158] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8158) (Retail Data)
        [8159] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8159) (Retail Data)
        [8163] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8163) (Retail Data)
        [8164] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8164) (Retail Data)
        [8165] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8165) (Retail Data)
        [8298] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8298) (Retail Data)
        [8300] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=8300) (Retail Data)

        -- Miscellaneous -> Legendary (7 -> -344)
        [7521] = true, --* Thunderaan the Windseeker (https://www.wowhead.com/wotlk/quest=7521) (Retail Data)
        [7522] = true, --* Examine the Vessel (https://www.wowhead.com/wotlk/quest=7522) (Retail Data)

        -- Eastern Kingdoms -> Eversong Woods (0 -> 3430)
        [8329] = true, --* Warrior Training (https://www.wowhead.com/wotlk/quest=8329) (Retail Data)
        [8478] = true, --* Choose Your Weapon (https://www.wowhead.com/wotlk/quest=8478) (Retail Data)

        --! 1.13.2
        -- Professions -> Engineering (5 -> -201)
        [3638] = true, --* The Pledge of Secrecy (https://www.wowhead.com/wotlk/quest=3638)
        [3640] = true, --* The Pledge of Secrecy (https://www.wowhead.com/wotlk/quest=3640)
        [3642] = true, --* The Pledge of Secrecy (https://www.wowhead.com/wotlk/quest=3642)

        -- Raids ->  (3 -> 0)
        [7509] = true, --* The Forging of Quel'Serrar (https://www.wowhead.com/wotlk/quest=7509)

        -- Eastern Kingdoms -> Wetlands (0 -> 11)
        [1132] = true, --* Fiora Longears (https://www.wowhead.com/wotlk/quest=1132)

        -- Classes -> Warlock (4 -> -61)
        [1470] = true, --* Piercing the Veil (https://www.wowhead.com/wotlk/quest=1470)
        [1485] = true, --* Vile Familiars (https://www.wowhead.com/wotlk/quest=1485)
        [1598] = true, --* The Stolen Tome (https://www.wowhead.com/wotlk/quest=1598)
        [1599] = true, --* Beginnings (https://www.wowhead.com/wotlk/quest=1599)

        -- Classes -> Rogue (4 -> -162)
        [1978] = true, --* The Deathstalkers (https://www.wowhead.com/wotlk/quest=1978)

        -- Kalimdor -> Mulgore (1 -> 215)
        [781] = true, --* Attack on Camp Narache (https://www.wowhead.com/wotlk/quest=781)

        -- Kalimdor -> Darkshore (1 -> 148)
        [1133] = true, --* Journey to Astranaar (https://www.wowhead.com/wotlk/quest=1133)

        -- Dungeons -> Scarlet Monastery (2 -> 796)
        [1048] = true, --* Into The Scarlet Monastery (https://www.wowhead.com/wotlk/quest=1048)

        -- Dungeons -> Ragefire Chasm (2 -> 2437)
        [5725] = true, --* The Power to Destroy... (https://www.wowhead.com/wotlk/quest=5725)

        -- Dungeons -> Dire Maul (2 -> 2557)
        [7507] = true, --* Nostro's Compendium (https://www.wowhead.com/wotlk/quest=7507)
        [7508] = true, --* The Forging of Quel'Serrar (https://www.wowhead.com/wotlk/quest=7508)

        --! 2.3.0
        [1135] = true, --* Highperch Venom (https://www.wowhead.com/wotlk/quest=1135)

        --! 2.5.1
        -- Classes -> Warlock (4 -> -61)
        [8344] = true, --* Windows to the Source (https://www.wowhead.com/wotlk/quest=8344)

        -- Uncategorized ->  (-2 -> 0)
        [11518] = true, --* Sunwell Daily Portal Flag (https://www.wowhead.com/wotlk/quest=11518) (Retail Data)
        [12186] = true, --* FLAG: Winner (https://www.wowhead.com/wotlk/quest=12186) (Retail Data)
        [12187] = true, --* FLAG: Participant (https://www.wowhead.com/wotlk/quest=12187) (Retail Data)
        [12693] = true, --* Wolvar Faction Choice Tracker (https://www.wowhead.com/wotlk/quest=12693) (Retail Data)
        [12694] = true, --* Oracle Faction Choice Tracker (https://www.wowhead.com/wotlk/quest=12694) (Retail Data)
        [12781] = true, --* Welcome! (https://www.wowhead.com/wotlk/quest=12781) (Retail Data)
        [12845] = true, --* Dalaran Teleport Crystal Flag (https://www.wowhead.com/wotlk/quest=12845) (Retail Data)

        --! 3.0.2
        -- Outland ->  (8 -> 0)
        [10610] = true, --* Prospecting Basics (https://www.wowhead.com/wotlk/quest=10610) (Retail Data)

        --! 3.0.3
        -- Uncategorized ->  (-2 -> 0)
        [9713] = true, --* Glowcap Harvesting Enabling Flag (https://www.wowhead.com/wotlk/quest=9713) (Retail Data)

        --! 3.1.0
        -- Uncategorized ->  (-2 -> 0)
        [13807] = true, --* FLAG: Tournament Invitation (https://www.wowhead.com/wotlk/quest=13807) (Retail Data)

        --! 3.3.0
        -- Battlegrounds -> Arathi Basin (6 -> 3358)
        [10533] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=10533) (Retail Data)
        [10536] = true, --* More Resource Crates (https://www.wowhead.com/wotlk/quest=10536) (Retail Data)

        -- Northrend -> Tournament (10 -> -241)
        [13820] = true, --* The Blastbolt Brothers (https://www.wowhead.com/wotlk/quest=13820) (Retail Data)

        -- Northrend -> Icecrown (10 -> 210)
        [24808] = true, --* Tank Ring Flag (https://www.wowhead.com/wotlk/quest=24808) (Retail Data)
        [24809] = true, --* Healer Ring Flag (https://www.wowhead.com/wotlk/quest=24809) (Retail Data)
        [24810] = true, --* Melee Ring Flag (https://www.wowhead.com/wotlk/quest=24810) (Retail Data)
        [24811] = true, --* Caster Ring Flag (https://www.wowhead.com/wotlk/quest=24811) (Retail Data)
        [25238] = true, --* Strength Ring Flag (https://www.wowhead.com/wotlk/quest=25238) (Retail Data)

        -- Northrend -> Dragonblight (10 -> 65)
        [12023] = true, --* Sweeter Revenge (https://www.wowhead.com/wotlk/quest=12023) (Retail Data)

        -- Northrend -> Howling Fjord (10 -> 495)
        [12485] = true, --* Howling Fjord: aa - A - LK FLAG (https://www.wowhead.com/wotlk/quest=12485) (Retail Data)

        -- Outland -> Hellfire Peninsula (8 -> 3483)
        [9342] = true, --* Marauding Crust Bursters (https://www.wowhead.com/wotlk/quest=9342)
        [9344] = true, --* A Hasty Departure (https://www.wowhead.com/wotlk/quest=9344)
        [9346] = true, --* When Helboars Fly (https://www.wowhead.com/wotlk/quest=9346)
        [9382] = true, --* The Fate of the Clefthoof (https://www.wowhead.com/wotlk/quest=9382)
        [9510] = true, --* Bristlehide Clefthoof Hides (https://www.wowhead.com/wotlk/quest=9510)
        [10053] = true, --* Dealing with Zeth'Gor (https://www.wowhead.com/wotlk/quest=10053)
        [10054] = true, --* Impending Doom (https://www.wowhead.com/wotlk/quest=10054)
        [10056] = true, --* Bleeding Hollow Supplies (https://www.wowhead.com/wotlk/quest=10056)
        [10059] = true, --* Dealing With Zeth'Gor (https://www.wowhead.com/wotlk/quest=10059)
        [10060] = true, --* Impending Doom (https://www.wowhead.com/wotlk/quest=10060)
        [10062] = true, --* Looking to the Leadership (https://www.wowhead.com/wotlk/quest=10062)
        [10084] = true, --* Assault on Mageddon (https://www.wowhead.com/wotlk/quest=10084)
        [10089] = true, --* Forge Camps of the Legion (https://www.wowhead.com/wotlk/quest=10089)
        [10092] = true, --* Assault on Mageddon (https://www.wowhead.com/wotlk/quest=10092)
        [10100] = true, --* The Mastermind (https://www.wowhead.com/wotlk/quest=10100)
        [10126] = true, --* Warboss Nekrogg's Orders (https://www.wowhead.com/wotlk/quest=10126)
        [10128] = true, --* Saving Private Imarion (https://www.wowhead.com/wotlk/quest=10128)
        [10131] = true, --* Planning the Escape (https://www.wowhead.com/wotlk/quest=10131)
        [10133] = true, --* Mission: Kill the Messenger (https://www.wowhead.com/wotlk/quest=10133)
        [10135] = true, --* Mission: Be the Messenger (https://www.wowhead.com/wotlk/quest=10135)
        [10137] = true, --* Provoking the Warboss (https://www.wowhead.com/wotlk/quest=10137)
        [10138] = true, --* Under Whose Orders? (https://www.wowhead.com/wotlk/quest=10138)
        [10139] = true, --* Dispatching the Commander (https://www.wowhead.com/wotlk/quest=10139)
        [10147] = true, --* Mission: Kill the Messenger (https://www.wowhead.com/wotlk/quest=10147)
        [10148] = true, --* Mission: Be the Messenger (https://www.wowhead.com/wotlk/quest=10148)
        [10149] = true, --* Mission: End All, Be All (https://www.wowhead.com/wotlk/quest=10149)
        [10151] = true, --* Warboss Nekrogg's Orders (https://www.wowhead.com/wotlk/quest=10151)
        [10153] = true, --* Saving Scout Makha (https://www.wowhead.com/wotlk/quest=10153)
        [10154] = true, --* Planning the Escape (https://www.wowhead.com/wotlk/quest=10154)
        [10155] = true, --* Provoking the Warboss (https://www.wowhead.com/wotlk/quest=10155)
        [10156] = true, --* Under Whose Orders? (https://www.wowhead.com/wotlk/quest=10156)
        [10157] = true, --* Dispatching the Commander (https://www.wowhead.com/wotlk/quest=10157)
        [10158] = true, --* Bleeding Hollow Supplies (https://www.wowhead.com/wotlk/quest=10158)
        [10398] = true, --* Return to Honor Hold (https://www.wowhead.com/wotlk/quest=10398)
        [10401] = true, --* Mission: End All, Be All (https://www.wowhead.com/wotlk/quest=10401)

        -- Outland -> Terokkar Forest (8 -> 3519)
        [9929] = true, --* The Missing Merchant (https://www.wowhead.com/wotlk/quest=9929)
        [9930] = true, --* The Missing Merchant (https://www.wowhead.com/wotlk/quest=9930)
        [9941] = true, --* Tracking Down the Culprits (https://www.wowhead.com/wotlk/quest=9941)
        [9942] = true, --* Tracking Down the Culprits (https://www.wowhead.com/wotlk/quest=9942)
        [9943] = true, --* Return to Thander (https://www.wowhead.com/wotlk/quest=9943)
        [9947] = true, --* Return to Rokag (https://www.wowhead.com/wotlk/quest=9947)
        [9952] = true, --* Prospector Balmoral (https://www.wowhead.com/wotlk/quest=9952)
        [9953] = true, --* Lookout Nodak (https://www.wowhead.com/wotlk/quest=9953)
        [9958] = true, --* Scouting the Defenses (https://www.wowhead.com/wotlk/quest=9958)
        [9959] = true, --* Scouting the Defenses (https://www.wowhead.com/wotlk/quest=9959)
        [9963] = true, --* Seeking Help from the Source (https://www.wowhead.com/wotlk/quest=9963)
        [9964] = true, --* Seeking Help from the Source (https://www.wowhead.com/wotlk/quest=9964)
        [9965] = true, --* A Show of Good Faith (https://www.wowhead.com/wotlk/quest=9965)
        [9966] = true, --* A Show of Good Faith (https://www.wowhead.com/wotlk/quest=9966)
        [9969] = true, --* The Final Reagents (https://www.wowhead.com/wotlk/quest=9969)
        [9974] = true, --* The Final Reagents (https://www.wowhead.com/wotlk/quest=9974)
        [9975] = true, --* Primal Magic (https://www.wowhead.com/wotlk/quest=9975)
        [9976] = true, --* Primal Magic (https://www.wowhead.com/wotlk/quest=9976)
        [9980] = true, --* Rescue Deirom! (https://www.wowhead.com/wotlk/quest=9980)
        [9981] = true, --* Rescue Dugar! (https://www.wowhead.com/wotlk/quest=9981)
        [10048] = true, --* A Handful of Magic Dust (https://www.wowhead.com/wotlk/quest=10048)
        [10049] = true, --* A Handful of Magic Dust (https://www.wowhead.com/wotlk/quest=10049)
        [10195] = true, --* Mercenary See, Mercenary Do (https://www.wowhead.com/wotlk/quest=10195)
        [10841] = true, --* The Vengeful Harbinger (https://www.wowhead.com/wotlk/quest=10841)
        [10925] = true, --* Evil Draws Near (https://www.wowhead.com/wotlk/quest=10925)

        -- Outland -> Nagrand (8 -> 3518)
        [9926] = true, --* FLAG Shadow Council/Warmaul Questline (https://www.wowhead.com/wotlk/quest=9926)

        -- Uncategorized ->  (-2 -> 0)
        [10219] = true, --* Walk the Dog (https://www.wowhead.com/wotlk/quest=10219) (Retail Data)
        [12494] = true, --* FLAG: Riding Trainer Advertisement (20) (https://www.wowhead.com/wotlk/quest=12494) (Retail Data)
        [14185] = true, --* FLAG: Riding Trainer Advertisement (40) (https://www.wowhead.com/wotlk/quest=14185) (Retail Data)
        [14186] = true, --* FLAG: Riding Trainer Advertisement (60) (https://www.wowhead.com/wotlk/quest=14186) (Retail Data)
        [14187] = true, --* FLAG: Riding Trainer Advertisement (70) (https://www.wowhead.com/wotlk/quest=14187) (Retail Data)
        [24508] = true, --* Temp Quest Record (https://www.wowhead.com/wotlk/quest=24508) (Retail Data)
        [24509] = true, --* Temp Quest Record (https://www.wowhead.com/wotlk/quest=24509) (Retail Data)

        -- Raids -> Magtheridons Lair (3 -> 3836)
        [11116] = true, --* Trial of the Naaru: (QUEST FLAG) (https://www.wowhead.com/wotlk/quest=11116)

        -- Eastern Kingdoms -> Isle Of Queldanas (0 -> 4080)
        [11517] = true, --* Report to Nasuun (https://www.wowhead.com/wotlk/quest=11517) (Retail Data)
        [11534] = true, --* Report to Nasuun (https://www.wowhead.com/wotlk/quest=11534) (Retail Data)

        -- World Events -> Childrens Week (9 -> -1002)
        [13929] = true, --* The Biggest Tree Ever! (https://www.wowhead.com/wotlk/quest=13929) (Retail Data)
        [13930] = true, --* Home Of The Bear-Men (https://www.wowhead.com/wotlk/quest=13930) (Retail Data)
        [13933] = true, --* The Bronze Dragonshrine (https://www.wowhead.com/wotlk/quest=13933) (Retail Data)
        [13934] = true, --* The Bronze Dragonshrine (https://www.wowhead.com/wotlk/quest=13934) (Retail Data)
        [13937] = true, --* A Trip To The Wonderworks (https://www.wowhead.com/wotlk/quest=13937) (Retail Data)
        [13938] = true, --* A Visit To The Wonderworks (https://www.wowhead.com/wotlk/quest=13938) (Retail Data)
        [13950] = true, --* Playmates! (https://www.wowhead.com/wotlk/quest=13950) (Retail Data)
        [13951] = true, --* Playmates! (https://www.wowhead.com/wotlk/quest=13951) (Retail Data)
        [13954] = true, --* The Dragon Queen (https://www.wowhead.com/wotlk/quest=13954) (Retail Data)
        [13955] = true, --* The Dragon Queen (https://www.wowhead.com/wotlk/quest=13955) (Retail Data)
        [13956] = true, --* Meeting a Great One (https://www.wowhead.com/wotlk/quest=13956) (Retail Data)
        [13957] = true, --* The Mighty Hemet Nesingwary (https://www.wowhead.com/wotlk/quest=13957) (Retail Data)
        [13959] = true, --* Back To The Orphanage (https://www.wowhead.com/wotlk/quest=13959) (Retail Data)
        [13960] = true, --* Back To The Orphanage (https://www.wowhead.com/wotlk/quest=13960) (Retail Data)

        -- World Events -> Brewfest (9 -> -370)
        [11486] = true, --* The Best of Brews (https://www.wowhead.com/wotlk/quest=11486) (Retail Data)
        [11487] = true, --* The Best of Brews (https://www.wowhead.com/wotlk/quest=11487) (Retail Data)
        [12491] = true, --* Direbrew's Dire Brew (https://www.wowhead.com/wotlk/quest=12491) (Retail Data)
        [12492] = true, --* Direbrew's Dire Brew (https://www.wowhead.com/wotlk/quest=12492) (Retail Data)

        -- World Events -> Love Is In The Air (9 -> -1004)
        [24576] = true, --* A Friendly Chat... (https://www.wowhead.com/wotlk/quest=24576) (Retail Data)
        [24657] = true, --* A Friendly Chat... (https://www.wowhead.com/wotlk/quest=24657) (Retail Data)
        [24792] = true, --* Man on the Inside (https://www.wowhead.com/wotlk/quest=24792) (Retail Data)
        [24793] = true, --* Man on the Inside (https://www.wowhead.com/wotlk/quest=24793) (Retail Data)
        [24848] = true, --* Fireworks At The Gilded Rose (https://www.wowhead.com/wotlk/quest=24848) (Retail Data)
        [24849] = true, --* Hot On The Trail (https://www.wowhead.com/wotlk/quest=24849) (Retail Data)
        [24850] = true, --* Snivel's Sweetheart (https://www.wowhead.com/wotlk/quest=24850) (Retail Data)
        [24851] = true, --* Hot On The Trail (https://www.wowhead.com/wotlk/quest=24851) (Retail Data)

        --! 3.3.2
        -- World Events -> Love Is In The Air (9 -> -1004)
        [24541] = true, --* Pilfering Perfume (https://www.wowhead.com/wotlk/quest=24541) (Retail Data)
        [24656] = true, --* Pilfering Perfume (https://www.wowhead.com/wotlk/quest=24656) (Retail Data)

        --  ->  (0 -> 0)
        [25293] = true, --* The Missing (https://www.wowhead.com/wotlk/quest=25293) (Retail Data)

        -- Northrend -> Tournament (10 -> -241)
        [13627] = true, --* Jack Me Some Lumber (https://www.wowhead.com/wotlk/quest=13627) (Retail Data)
        [13681] = true, --* A Chip Off the Ulduar Block (https://www.wowhead.com/wotlk/quest=13681) (Retail Data)

        -- World Events -> Love Is In The Air (9 -> -1004)
        [24638] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24638) (Retail Data)
        [24645] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24645) (Retail Data)
        [24647] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24647) (Retail Data)
        [24648] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24648) (Retail Data)
        [24649] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24649) (Retail Data)
        [24650] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24650) (Retail Data)
        [24651] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24651) (Retail Data)
        [24652] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24652) (Retail Data)
        [24658] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24658) (Retail Data)
        [24659] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24659) (Retail Data)
        [24660] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24660) (Retail Data)
        [24662] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24662) (Retail Data)
        [24663] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24663) (Retail Data)
        [24664] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24664) (Retail Data)
        [24665] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24665) (Retail Data)
        [24666] = true, --* Crushing the Crown (https://www.wowhead.com/wotlk/quest=24666) (Retail Data)

        -- Midsummer Festival
        [13440] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13440) (Retail Data)
        [13441] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13441) (Retail Data)
        [13442] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13442) (Retail Data)
        [13443] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13443) (Retail Data)
        [13444] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13444) (Retail Data)
        [13445] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13445) (Retail Data)
        [13446] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13446) (Retail Data)
        [13447] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13447) (Retail Data)
        [13449] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13449) (Retail Data)
        [13450] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13445) (Retail Data)
        [13451] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13451) (Retail Data)
        [13453] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13453) (Retail Data)
        [13454] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13454) (Retail Data)
        [13455] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13455) (Retail Data)
        [13457] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13457) (Retail Data)
        [13458] = true, --* Desecrate this Fire! (https://www.wowhead.com/wotlk/quest=13458) (Retail Data)
        [13485] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13485) (Retail Data)
        [13486] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13486) (Retail Data)
        [13487] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13487) (Retail Data)
        [13488] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13488) (Retail Data)
        [13489] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13489) (Retail Data)
        [13490] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13490) (Retail Data)
        [13491] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13491) (Retail Data)
        [13492] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13492) (Retail Data)
        [13493] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13493) (Retail Data)
        [13494] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13494) (Retail Data)
        [13495] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13495) (Retail Data)
        [13496] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13496) (Retail Data)
        [13497] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13497) (Retail Data)
        [13498] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13498) (Retail Data)
        [13499] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13499) (Retail Data)
        [13500] = true, --* Honor the Flame (https://www.wowhead.com/wotlk/quest=13500) (Retail Data)

        --! 3.4.0
        -- Darnassus WOTLK
        [10520] = QuestieCorrections.WOTLK_ONLY, --*Assisting Arch Druid Staghelm (https://www.wowhead.com/wotlk/quest=10520) not present anymore in wotlk

        -- 3.4.3
        -- ICC
        [13240] = true, --* Timear Foresees Centrifuge Constructs in your Future! (https://www.wowhead.com/wotlk/quest=13240) (Retail Data)
        [13241] = true, --* Timear Foresees Ymirjar Berserkers in your Future! (https://www.wowhead.com/wotlk/quest=13241) (Retail Data)
        [13243] = true, --* Timear Foresees Infinite Agents in your Future! (https://www.wowhead.com/wotlk/quest=13243) (Retail Data)
        [13244] = true, --* Timear Foresees Titanium Vanguards in your Future! (https://www.wowhead.com/wotlk/quest=13244) (Retail Data)
        [13245] = false, --* Proof of Demise: Ingvar the Plunderer (https://www.wowhead.com/wotlk/quest=13245) (Retail Data)
        [13246] = false, --* Proof of Demise: Keristrasza (https://www.wowhead.com/wotlk/quest=13246) (Retail Data)
        [13247] = false, --* Proof of Demise: Ley-Guardian Eregos (https://www.wowhead.com/wotlk/quest=13247) (Retail Data)
        [13248] = false, --* Proof of Demise: King Ymiron (https://www.wowhead.com/wotlk/quest=13248) (Retail Data)
        [13249] = false, --* Proof of Demise: The Prophet Tharon'ja (https://www.wowhead.com/wotlk/quest=13249) (Retail Data)
        [13250] = false, --* Proof of Demise: Gal'darah (https://www.wowhead.com/wotlk/quest=13250) (Retail Data)
        [13251] = false, --* Proof of Demise: Mal'Ganis (https://www.wowhead.com/wotlk/quest=13251) (Retail Data)
        [13252] = false, --* Proof of Demise: Sjonnir The Ironshaper (https://www.wowhead.com/wotlk/quest=13252) (Retail Data)
        [13253] = false, --* Proof of Demise: Loken (https://www.wowhead.com/wotlk/quest=13253) (Retail Data)
        [13254] = false, --* Proof of Demise: Anub'arak (https://www.wowhead.com/wotlk/quest=13254) (Retail Data)
        [13255] = false, --* Proof of Demise: Herald Volazj (https://www.wowhead.com/wotlk/quest=13255) (Retail Data)
        [13256] = false, --* Proof of Demise: Cyanigosa (https://www.wowhead.com/wotlk/quest=13256) (Retail Data)
        [14199] = false, --* Proof of Demise: The Black Knight (https://www.wowhead.com/wotlk/quest=14199) (Retail Data)

    }
end
