---@type QuestieAuto
local QuestieAuto = QuestieLoader:ImportModule("QuestieAuto")
local _QuestieAuto = QuestieAuto.private

local acceptDisallowed = {
    -- Escort quests and quests with forced movement or special interactions
    [155] = true, -- The Defias Traitor (The Defias Brotherhood)
    [219] = true, -- Corporal Keeshan (Missing In Action)
    [309] = true, -- Miran (Protecting the Shipment)
    [349] = true, -- Stranglethorn Fever (Consumes items)
    [434] = true, -- Tyrion (The Attack!)
    [435] = true, -- Deathstalker Erland (Escorting Erland)
    [648] = true, -- Rescue OOX-17/TN!
    [660] = true, -- Hints of a New Plague?
    [665] = true, -- Sunken Treasure
    [667] = true, -- Death From Below
    [731] = true, -- The Absent Minded Prospector
    [836] = true, -- Rescue OOX-09/HL!
    [863] = true, -- The Escape
    [898] = true, -- Free From the Hold
    [938] = true, -- Mist
    [945] = true, -- Therylune's Escape
    [976] = true, -- Supplies to Auberdine
    [994] = true, -- Escape Through Force
    [995] = true, -- Escape Through Stealth
    [1120] = true, -- Get the Gnomes Drunk
    [1121] = true, -- Get the Goblins Drunk
    [1144] = true, -- Willix the Importer
    [1222] = true, -- Stinky's Escape
    [1270] = true, -- Stinky's Escape
    [1273] = true, -- Questioning Reethe
    [1324] = true, -- The Missing Diplomat
    [1393] = true, -- Galen's Escape
    [1440] = true, -- Return to Vahlarriel
    [1560] = true, -- Tooga's Quest
    [2742] = true, -- Rin'ji is Trapped!
    [2767] = true, -- Rescue OOX-22/FE!
    [2845] = true, -- Wandering Shay
    [2904] = true, -- A Fine Mess
    [3367] = true, -- Suntara Stones
    [3382] = true, -- A Crew Under Fire
    [3525] = true, -- Extinguishing the Idol
    [3526] = true, -- Goblin Engineering
    [3629] = true, -- Goblin Engineering
    [3630] = true, -- Gnome Engineering
    [3632] = true, -- Gnome Engineering
    [3633] = true, -- Goblin Engineering
    [3634] = true, -- Gnome Engineering
    [3635] = true, -- Gnome Engineering
    [3644] = true, -- Goblin Membership Card Renewal
    [3645] = true, -- Gnome Membership Card Renewal
    [3646] = true, -- Goblin Membership Card Renewal
    [3647] = true, -- Gnome Membership Card Renewal
    [3982] = true, -- What Is Going On?
    [4121] = true, -- Precarious Predicament
    [4181] = true, -- Goblin Engineering
    [4245] = true, -- Chasing A-Me 01
    [4261] = true, -- Ancient Spirit
    [4322] = true, -- Jail Break!
    [4491] = true, -- A Little Help From My Friends
    [4770] = true, -- Homeward Bound
    [4901] = true, -- Guardians of the Altar
    [4904] = true, -- Free at Last
    [4962] = true, -- Shard of a Felhound
    [4963] = true, -- Shard of an Infernal
    [4966] = true, -- Protect Kanati Greycloud
    [5162] = true, -- Wrath of the Blue Flight
    [5203] = true, -- Rescue From Jaedenar
    [5321] = true, -- The Sleeper Has Awakened
    [5713] = true, -- One Shot. One Kill.
    [5821] = true, -- Bodyguard for Hire
    [5943] = true, -- Gizelton Caravan
    [5944] = true, -- In Dreams
    [6132] = true, -- Get Me Out of Here!
    [6403] = true, -- The Great Masquerade
    [6482] = true, -- Freedom to Ruul
    [6523] = true, -- Protect Kaya
    [6544] = true, -- Torek's Assault
    [6641] = true, -- Vorsha the Lasher
    [7046] = true, -- The Scepter of Celebras
    [9212] = true, -- Escape from the Catacombs
    [9446] = true, -- Tomb of the Lightbringer
    [9528] = true, -- A Cry For Help
    [9729] = true, -- Fhwoor Smash!
    [9752] = true, -- Escape from Umbrafen
    [9868] = true, -- The Totem of Kar'dash
    [9879] = true, -- The Totem of Kar'dash
    [10051] = true, -- Escape from Firewing Point!
    [10052] = true, -- Escape from Firewing Point!
    [10191] = true, -- Mark V is Alive!
    [10218] = true, -- Someone Else's Hard Work Pays Off
    [10310] = true, -- Sabotage the Warp-Gate!
    [10337] = true, -- When the Cows Come Home
    [10346] = true, -- Return to the Abyssal Shelf (Alliance)
    [10347] = true, -- Return to the Abyssal Shelf (Horde)
    [10406] = true, -- Delivering the Message
    [10425] = true, -- Escape from the Staging Grounds
    [10451] = true, -- Escape from Coilskar Cistern
    [10551] = true, -- Allegiance to the Aldor
    [10552] = true, -- Allegiance to the Scryers
    [10898] = true, -- Skywing
    [10922] = true, -- Digging Through Bones
    [11085] = true, -- Escape from Skettis
    [11189] = true, -- One Last Time
    [11241] = true, -- Trail of Fire
    [11570] = true, -- Escape from the Winterfin Caverns
    [11664] = true, -- Escaping the Mist
    [11673] = true, -- Get Me Outa Here!
    [11705] = true, -- Foolish Endeavors
    [11733] = true, -- Traversing the Rift
    [11930] = true, -- Across Transborea
    [12082] = true, -- Dun-da-Dun-tah!
    [12174] = true, -- High Commander Halford Wyrmbane
    [12570] = true, -- Fortunate Misunderstandings
    [12671] = true, -- Reconnaissance Flight
    [12688] = true, -- Engineering a Disaster
    [12832] = true, -- Bitter Departure
    [13221] = true, -- I'm Not Dead Yet!
    [13229] = true, -- I'm Not Dead Yet!
    [13284] = true, -- Assault by Ground
    [13301] = true, -- Assault by Ground
    [13481] = true, -- Let's Get Out of Here!
    [13482] = true, -- Let's Get Out of Here
    [13926] = true, -- Little Orphan Roo of the Oracles
    [13927] = true, -- Little Orphan Kekek of the Wolvar
}

local turnInDisallowed = {
    -- Material and currency turn-ins
    [889] = true,
    [2199] = true, -- Lore for a Price
    [2948] = true, -- Gnome Improvement
    [2950] = true, -- Gnome Improvement
    [3375] = true, -- Replacement Phial
    [3644] = true, -- Goblin Membership Card Renewal
    [3645] = true, -- Gnome Membership Card Renewal
    [3646] = true, -- Goblin Membership Card Renewal
    [3647] = true, -- Gnome Membership Card Renewal
    [4083] = true, -- The Spectral Chalice
    [4781] = true, -- Components for the Enchanted Gold Bloodrobe
    [5042] = true,
    [5043] = true,
    [5044] = true,
    [5045] = true,
    [5046] = true,
    [5063] = true,
    [5067] = true,
    [5068] = true,
    [5166] = true,
    [5167] = true,
    [7637] = true, -- Emphasis on Sacrifice
    [8196] = true, -- Essence Mangoes
    [8288] = true,
    [8367] = true,
    [8371] = true,
    [8385] = true,
    [8388] = true,
    [8548] = true,
    [8572] = true,
    [8573] = true,
    [8574] = true,
    [8783] = true, -- Extraordinary Materials
    [8809] = true, -- Extraordinary Materials
    [9338] = true, -- Allegiance to Cenarion Circle
    [10551] = true, -- Allegiance to the Aldor
    [10552] = true, -- Allegiance to the Scryers
    [10975] = true, -- Purging the Chambers of Bash'ir
    [11109] = true,
    [11110] = true,
    [11111] = true,
    [11112] = true,
    [11113] = true,
    [11114] = true,
    [12567] = true, -- Blessing of Zim'Abwa
    [12618] = true, -- Blessing of Zim'Torga
    [12656] = true, -- Blessing of Zim'Rhuk
}

local allDisallowed = {}
for questId in pairs(acceptDisallowed) do
    allDisallowed[questId] = true
end
for questId in pairs(turnInDisallowed) do
    allDisallowed[questId] = true
end

-- NPC ID based
---@see QuestieAutoPrivate
_QuestieAuto.disallowedNPCs = {
    -- AQ
    [15176] = true, -- Vargus
    [15458] = true, -- Commander Stronghammer
    [15701] = true, -- Field Marshal Snowfall
    [15539] = true, -- General Zog
    [15700] = true, -- Warlord Gorchuk

    -- Commendations
    [15764] = true, -- Officer Ironbeard
    [15762] = true, -- Officer Lunalight
    [15766] = true, -- Officer Maloof
    [15763] = true, -- Officer Porterhouse
    [15768] = true, -- Officer Gothena
    [15765] = true, -- Officer Redblade
    [15767] = true, -- Officer Thunderstrider
    [15761] = true, -- Officer Vu'Shalay
    [15731] = true, -- Darnassus Commendation Officer
    [15737] = true, -- Darkspear Commendation Officer
    [15735] = true, -- Stormwind Commendation Officer
    [15739] = true, -- Thunder Bluff Commendation Officer
    [15736] = true, -- Orgrimmar Commendation Officer
    [15734] = true, -- Ironforge Commendation Officer
    [15738] = true, -- Undercity Commendation Officer
    [15733] = true, -- Gnomeregan Commendation Officer

    -- AQ gear turn-ins
    [15378] = true,
    [15380] = true,
    [15498] = true,
    [15499] = true,
    [15500] = true,
    [15503] = true,

    -- Miscellaneous
    [7802] = true, -- Galvan the Ancient
    [12944] = true, -- Lokhtos Darkbargainer
    [14567] = true, -- Derotain Mudsipper
    [14828] = true, -- Gelvas Grimegate
    [14921] = true, -- Rin'wosho the Trader
    [15192] = true, -- Anachronos
    [15909] = true, -- Fariel Starsong
    [16786] = true, -- Argent Quartermaster
    [18166] = true, -- Khadgar
    [18253] = true, -- Archmage Leryda
    [18471] = true, -- Gurgthock
    [19935] = true, -- Soridormi
    [19936] = true, -- Arazmodu
    [25112] = true, -- Anchorite Ayuri
    [25163] = true, -- Anchorite Kairthos
}

_QuestieAuto.disallowedNPC = _QuestieAuto.disallowedNPCs

---@see QuestieAutoPrivate
_QuestieAuto.disallowedQuests = setmetatable({
    accept = acceptDisallowed,
    turnIn = turnInDisallowed,
}, {
    __index = function(_, key)
        if type(key) == "number" then
            return allDisallowed[key]
        end
    end,
})
