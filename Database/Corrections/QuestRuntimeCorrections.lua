---@class QuestRuntimeCorrections
local QuestRuntimeCorrections = QuestieLoader:CreateModule("QuestRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")

QuestieCorrections.itemObjectiveFirst[503] = true
QuestieCorrections.itemObjectiveFirst[5088] = true

QuestieCorrections.killCreditObjectiveFirst[10503] = true
QuestieCorrections.killCreditObjectiveFirst[11652] = true
QuestieCorrections.killCreditObjectiveFirst[12100] = true
QuestieCorrections.killCreditObjectiveFirst[12546] = true
QuestieCorrections.killCreditObjectiveFirst[12561] = true
QuestieCorrections.killCreditObjectiveFirst[12762] = true
QuestieCorrections.killCreditObjectiveFirst[12779] = true
QuestieCorrections.killCreditObjectiveFirst[12919] = true
QuestieCorrections.killCreditObjectiveFirst[13086] = true
QuestieCorrections.killCreditObjectiveFirst[13373] = true
QuestieCorrections.killCreditObjectiveFirst[13376] = true
QuestieCorrections.killCreditObjectiveFirst[13380] = true
QuestieCorrections.killCreditObjectiveFirst[13382] = true
QuestieCorrections.killCreditObjectiveFirst[13404] = true
QuestieCorrections.killCreditObjectiveFirst[13406] = true
QuestieCorrections.killCreditObjectiveFirst[24498] = true
QuestieCorrections.killCreditObjectiveFirst[24507] = true

-- Hoverable entities that directly drive coordinate-only triggerEnd objectives
QuestieCorrections.triggerEndTooltipTargets[155] = {{"monster",467}} -- The Defias Traitor
QuestieCorrections.triggerEndTooltipTargets[219] = {{"monster",349}} -- Corporal Keeshan
QuestieCorrections.triggerEndTooltipTargets[273] = {{"monster",2057}} -- Huldar
QuestieCorrections.triggerEndTooltipTargets[309] = {{"monster",1379}} -- Miran
QuestieCorrections.triggerEndTooltipTargets[434] = {{"monster",1754}} -- Lord Gregor Lescovar
QuestieCorrections.triggerEndTooltipTargets[435] = {{"monster",1978}} -- Deathstalker Erland
QuestieCorrections.triggerEndTooltipTargets[590] = {{"monster",6784}} -- Calvin Montague
QuestieCorrections.triggerEndTooltipTargets[648] = {{"monster",7784}} -- Homing Robot OOX-17/TN
QuestieCorrections.triggerEndTooltipTargets[660] = {{"monster",2713}} -- Kinelory
QuestieCorrections.triggerEndTooltipTargets[665] = {{"monster",2768}} -- Professor Phizzlethorpe
QuestieCorrections.triggerEndTooltipTargets[667] = {{"monster",2610}} -- Shakes O'Breen
QuestieCorrections.triggerEndTooltipTargets[731] = {{"monster",2917}} -- Prospector Remtravel
QuestieCorrections.triggerEndTooltipTargets[836] = {{"monster",7806}} -- Homing Robot OOX-09/HL
QuestieCorrections.triggerEndTooltipTargets[863] = {{"monster",3439}} -- Wizzlecrank's Shredder
QuestieCorrections.triggerEndTooltipTargets[898] = {{"monster",3465}} -- Gilthares Firebough
QuestieCorrections.triggerEndTooltipTargets[945] = {{"monster",3584}} -- Therylune
QuestieCorrections.triggerEndTooltipTargets[976] = {{"monster",4484}} -- Feero Ironhand
QuestieCorrections.triggerEndTooltipTargets[994] = {{"monster",3692}} -- Volcor
QuestieCorrections.triggerEndTooltipTargets[995] = {{"monster",3692}} -- Volcor
QuestieCorrections.triggerEndTooltipTargets[1144] = {{"monster",4508}} -- Willix the Importer
QuestieCorrections.triggerEndTooltipTargets[1173] = {{"monster",4500}} -- Overlord Mok'Morokk
QuestieCorrections.triggerEndTooltipTargets[1222] = {{"monster",4880}} -- "Stinky" Ignatz
QuestieCorrections.triggerEndTooltipTargets[1270] = {{"monster",4880}} -- "Stinky" Ignatz
QuestieCorrections.triggerEndTooltipTargets[1273] = {{"monster",4980}} -- Paval Reethe
QuestieCorrections.triggerEndTooltipTargets[1393] = {{"monster",5391}} -- Galen Goodward
QuestieCorrections.triggerEndTooltipTargets[1440] = {{"monster",5644}} -- Dalinda Malem
QuestieCorrections.triggerEndTooltipTargets[1560] = {{"monster",5955}} -- Tooga
QuestieCorrections.triggerEndTooltipTargets[1651] = {{"monster",6182}} -- Daphne Stilwell
QuestieCorrections.triggerEndTooltipTargets[2480] = {{"monster",2391}} -- Serge Hinott
QuestieCorrections.triggerEndTooltipTargets[2608] = {{"monster",7207}} -- Doc Mixilpixil
QuestieCorrections.triggerEndTooltipTargets[2742] = {{"monster",7780}} -- Rin'ji
QuestieCorrections.triggerEndTooltipTargets[2767] = {{"monster",7807}} -- Homing Robot OOX-22/FE
QuestieCorrections.triggerEndTooltipTargets[2845] = {{"monster",7774}} -- Shay Leafrunner
QuestieCorrections.triggerEndTooltipTargets[2904] = {{"monster",7850}} -- Kernobee
QuestieCorrections.triggerEndTooltipTargets[2936] = {{"object",142715}} -- Tablet of Theka
QuestieCorrections.triggerEndTooltipTargets[2954] = {{"monster",7918}} -- Stone Watcher of Norgannon
QuestieCorrections.triggerEndTooltipTargets[3367] = {{"monster",8284}} -- Dorius Stonetender
QuestieCorrections.triggerEndTooltipTargets[3382] = {{"monster",8380}} -- Captain Vanessa Beltis
QuestieCorrections.triggerEndTooltipTargets[3525] = {{"monster",8516}} -- Belnistrasz
QuestieCorrections.triggerEndTooltipTargets[4121] = {{"monster",9520}} -- Grark Lorkrub
QuestieCorrections.triggerEndTooltipTargets[4245] = {{"monster",9623}} -- A-Me 01
QuestieCorrections.triggerEndTooltipTargets[4261] = {{"monster",9598}} -- Arei
QuestieCorrections.triggerEndTooltipTargets[4265] = {{"monster",9546}} -- Raschal the Courier
QuestieCorrections.triggerEndTooltipTargets[4285] = {{"object",164955}} -- Northern Crystal Pylon
QuestieCorrections.triggerEndTooltipTargets[4287] = {{"object",164957}} -- Eastern Crystal Pylon
QuestieCorrections.triggerEndTooltipTargets[4288] = {{"object",164956}} -- Western Crystal Pylon
QuestieCorrections.triggerEndTooltipTargets[4491] = {{"monster",9999}} -- Ringo
QuestieCorrections.triggerEndTooltipTargets[4506] = {{"monster",9937}} -- Common Kitten
QuestieCorrections.triggerEndTooltipTargets[4770] = {{"monster",10427}} -- Pao'ka Swiftmountain
QuestieCorrections.triggerEndTooltipTargets[4901] = {{"monster",10300}} -- Ranshalla
QuestieCorrections.triggerEndTooltipTargets[4904] = {{"monster",10646}} -- Lakota Windsong
QuestieCorrections.triggerEndTooltipTargets[4941] = {{"monster",3144}} -- Eitrigg
QuestieCorrections.triggerEndTooltipTargets[5203] = {{"monster",11016}} -- Captured Arko'narin
QuestieCorrections.triggerEndTooltipTargets[5321] = {{"monster",11218}} -- Kerlonian Evershade
QuestieCorrections.triggerEndTooltipTargets[5713] = {{"monster",11711}} -- Sentinel Aynasha
QuestieCorrections.triggerEndTooltipTargets[5821] = {{"monster",11625}} -- Cork Gizelton
QuestieCorrections.triggerEndTooltipTargets[5943] = {{"monster",11625}} -- Cork Gizelton
QuestieCorrections.triggerEndTooltipTargets[6132] = {{"monster",12277}} -- Melizza Brimbuzzle
QuestieCorrections.triggerEndTooltipTargets[6482] = {{"monster",12818}} -- Ruul Snowhoof
QuestieCorrections.triggerEndTooltipTargets[6523] = {{"monster",11856}} -- Kaya Flathoof
QuestieCorrections.triggerEndTooltipTargets[6544] = {{"monster",12858}} -- Torek
QuestieCorrections.triggerEndTooltipTargets[6566] = {{"monster",4949}} -- Thrall
QuestieCorrections.triggerEndTooltipTargets[6627] = {{"monster",4489}} -- Braug Dimspirit
QuestieCorrections.triggerEndTooltipTargets[6628] = {{"monster",4488}} -- Parqual Fintallas
QuestieCorrections.triggerEndTooltipTargets[7046] = {{"monster",13716}} -- Celebras the Redeemed
QuestieCorrections.triggerEndTooltipTargets[9212] = {{"monster",16295}} -- Ranger Lilatha
QuestieCorrections.triggerEndTooltipTargets[9375] = {{"monster",16993}} -- Wounded Blood Elf Pilgrim
QuestieCorrections.triggerEndTooltipTargets[9446] = {{"monster",17238}} -- Anchorite Truuen
QuestieCorrections.triggerEndTooltipTargets[9528] = {{"monster",17312}} -- Magwin
QuestieCorrections.triggerEndTooltipTargets[9729] = {{"monster",17877}} -- Fhwoor
QuestieCorrections.triggerEndTooltipTargets[9752] = {{"monster",17969}} -- Kayra Longmane
QuestieCorrections.triggerEndTooltipTargets[9868] = {{"monster",18210}} -- Mag'har Captive
QuestieCorrections.triggerEndTooltipTargets[9879] = {{"monster",18209}} -- Kurenai Captive
QuestieCorrections.triggerEndTooltipTargets[9889] = {{"monster",18262}} -- Unkor the Ruthless
QuestieCorrections.triggerEndTooltipTargets[10051] = {{"monster",18760}} -- Isla Starmane
QuestieCorrections.triggerEndTooltipTargets[10052] = {{"monster",18760}} -- Isla Starmane
QuestieCorrections.triggerEndTooltipTargets[10191] = {{"monster",19589}} -- Maxx A. Million Mk. V
QuestieCorrections.triggerEndTooltipTargets[10198] = {{"monster",19831}} -- Commander Dawnforge
QuestieCorrections.triggerEndTooltipTargets[10218] = {{"monster",19671}} -- Cryo-Engineer Sha'heen
QuestieCorrections.triggerEndTooltipTargets[10310] = {{"monster",20281}} -- Drijya
QuestieCorrections.triggerEndTooltipTargets[10337] = {{"monster",20415}} -- Bessy
QuestieCorrections.triggerEndTooltipTargets[10406] = {{"monster",20802}} -- Protectorate Demolitionist
QuestieCorrections.triggerEndTooltipTargets[10425] = {{"monster",20763}} -- Captured Protectorate Vanguard
QuestieCorrections.triggerEndTooltipTargets[10451] = {{"monster",21027}} -- Earthmender Wilda
QuestieCorrections.triggerEndTooltipTargets[10879] = {{"monster",22375}} -- Avatar of Terokk
QuestieCorrections.triggerEndTooltipTargets[10887] = {{"monster",22377}} -- Akuno
QuestieCorrections.triggerEndTooltipTargets[10898] = {{"monster",22424}} -- Skywing
QuestieCorrections.triggerEndTooltipTargets[10922] = {{"monster",22458}} -- Chief Archaeologist Letoll
QuestieCorrections.triggerEndTooltipTargets[10985] = {{"monster",22990}} -- Akama
QuestieCorrections.triggerEndTooltipTargets[11082] = {{"monster",23309}} -- Murkblood Overseer
QuestieCorrections.triggerEndTooltipTargets[11085] = {{"monster",23383}} -- Skyguard Prisoner
QuestieCorrections.triggerEndTooltipTargets[11241] = {{"monster",23784}} -- Apothecary Hanes
QuestieCorrections.triggerEndTooltipTargets[11436] = {{"monster",27924}} -- Dragonflayer Harpoon
QuestieCorrections.triggerEndTooltipTargets[11570] = {{"monster",25208}} -- Lurgglbr
QuestieCorrections.triggerEndTooltipTargets[11592] = {{"monster",25335}} -- Longrunner Proudhoof
QuestieCorrections.triggerEndTooltipTargets[11664] = {{"monster",25504}} -- Mootoo the Younger
QuestieCorrections.triggerEndTooltipTargets[11673] = {{"monster",25589}} -- Bonker Togglevolt
QuestieCorrections.triggerEndTooltipTargets[11891] = {{"monster",25949}} -- Ice Caller Briatha
QuestieCorrections.triggerEndTooltipTargets[12027] = {{"monster",26588}} -- Emily
QuestieCorrections.triggerEndTooltipTargets[12082] = {{"monster",26814}} -- Harrison Jones
QuestieCorrections.triggerEndTooltipTargets[12308] = {{"monster",27409}} -- Ducal's Horse
QuestieCorrections.triggerEndTooltipTargets[12330] = {{"monster",27626}} -- Tatjana's Horse
QuestieCorrections.triggerEndTooltipTargets[12570] = {{"monster",28217}} -- Injured Rainspeaker Oracle
QuestieCorrections.triggerEndTooltipTargets[12688] = {{"monster",28787}} -- Engineer Helice
QuestieCorrections.triggerEndTooltipTargets[12832] = {{"monster",29434}} -- Injured Goblin Miner
QuestieCorrections.triggerEndTooltipTargets[13168] = {{"object",193058}} -- Eye of Dominion
QuestieCorrections.triggerEndTooltipTargets[13221] = {{"monster",31279}} -- Father Kamaros
QuestieCorrections.triggerEndTooltipTargets[13229] = {{"monster",31279}} -- Father Kamaros
QuestieCorrections.triggerEndTooltipTargets[13429] = {{"monster",22990}} -- Akama

QuestieCorrections.questTooltipHints[6681] = "Speak to the npc and select \"<Take the letter>\", then read the letter to start the quest."
QuestieCorrections.questTooltipHints[9212] = "Inside the Amani Catacombs.  Entrances to the NW and NE."
QuestieCorrections.questTooltipHints[12020] = "The wreckage appears for 15 minutes after a successful Dark Iron attack. Attacks begin at :00 and :30 during Brewfest."
QuestieCorrections.questTooltipHints[12192] = "The wreckage appears for 15 minutes after a successful Dark Iron attack. Attacks begin at :00 and :30 during Brewfest."

QuestieCorrections.objectiveTooltipHints[8306] = {
    [15215] = "Inside Hive'Regal. Enter the hive cave to the NE to reach Mistress Natalia.",
}
QuestieCorrections.objectiveTooltipHints[8309] = {
    [180454] = "Inside Hive'Ashi. Enter the hive cave to the west to reach the crystal.",
    [180455] = "Inside Hive'Zora. Enter the hive cave to the west to reach the crystal.",
    [180453] = "Inside Hive'Regal. Enter the hive cave to the NE to reach the crystal.",
}

function QuestRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    if type(QuestieDB.questFactionSelections) ~= "table" then
        error("Missing generated quest faction selections; regenerate acoreQuestDB.lua", 0)
    end
    addOverride(overrides, QuestieDB.questFactionSelections)
end
