---@class QuestieDB
local QuestieDB = QuestieLoader:CreateModule("QuestieDB")

---@type QuestieDBPrivate
QuestieDB.private = QuestieDB.private or {}

---@class QuestieDBPrivate
local _QuestieDB = QuestieDB.private

-------------------------
--Import modules.
-------------------------
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieQuestBlacklist
local QuestieQuestBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type DailyQuests
local DailyQuests = QuestieLoader:ImportModule("DailyQuests")
---@type QuestieReputation
local QuestieReputation = QuestieLoader:ImportModule("QuestieReputation")
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type DBCompiler
local QuestieDBCompiler = QuestieLoader:ImportModule("DBCompiler")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@type DropDB
local DropDB = QuestieLoader:ImportModule("DropDB")

---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieQuestPrivate
local _QuestieQuest = QuestieQuest.private

--- A list of quests that will never be available, used to quickly skip quests.
---@alias AutoBlacklistString "rep"|"skill"|"race"|"class"|"rank"
---@type table<number, AutoBlacklistString>
QuestieDB.autoBlacklist = {}

local tinsert = table.insert
local bitband = bit.band

-- questFlags https://github.com/cmangos/issues/wiki/Quest_template#questflags
local QUEST_FLAGS_DAILY = 4096
local QUEST_FLAGS_WEEKLY = 32768
-- Pre calculated 2 * QUEST_FLAGS, for testing a bit flag
local QUEST_FLAGS_DAILY_X2 = 2 * QUEST_FLAGS_DAILY
local QUEST_FLAGS_WEEKLY_X2 = 2 * QUEST_FLAGS_WEEKLY
local playerFaction = UnitFactionGroup("Player")
local serverName = GetRealmName()

---@enum QuestTagIds
QuestieDB.questTagIds = {
    ELITE = 1,
    CLASS = 21,
    PVP = 41,
    RAID = 62,
    DUNGEON = 81,
    WORLD_EVENT = 82,
    LEGENDARY = 83,
    ESCORT = 84,
    HEROIC = 85,
    RAID_10 = 88,
    RAID_25 = 89,
    SCENARIO = 98,
    ACCOUNT = 102,
    CELESTIAL = 294,
}
---@enum DoableStates
QuestieDB.DoableStates = {
    AVAILABLE = 0,
    COMPLETED = 1,
    QUEST_LOG = 2,
    BLACKLISTED = 3,
    EXCEED_REPUTATION = 4,
    PARENT_ACTIVE = 5,
    WRONG_RACE = 6,
    NO_PREQUESTSINGLE = 7,
    WRONG_CLASS = 8,
    MISSING_REPUTATION = 9,
    PROFESSION_SKILL = 10,
    NO_PREQUESTGROUP = 11,
    PARENT_INACTIVE = 12,
    NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED = 13,
    EXCLUSIVE_COMPLETED = 14,
    EXCLUSIVE_IN_QUEST_LOG = 15,
    MISSING_DAILY = 16,
    PROFESSION_SPECIALIZATION = 17,
    SPELL_MISSING = 18,
    SPELL_KNOWN = 19,
    MISSING_ACHIEVEMENT = 20,
    BREADCRUMB_FOLLOWUP = 21,
    EVENT_INACTIVE = 22,
    BREADCRUMB_ACTIVE = 23,
    INACTIVE_DAILY = 24,
    LEVEL_TOO_HIGH = 25,
    LEVEL_TOO_LOW = 26,
    DISABLING_QUEST_COMPLETED = 27,
    ENABLING_QUEST_MISSING = 28,
    PROFESSION_MISSING = 29,
    PROFESSION_RANK = 30,
}
--- COMPATIBILITY ---
local WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_ID
local WOW_PROJECT_CLASSIC = QuestieCompat.WOW_PROJECT_CLASSIC
local C_QuestLog = QuestieCompat.C_QuestLog
local C_Timer = QuestieCompat.C_Timer
local GetQuestTagInfo = QuestieCompat.GetQuestTagInfo
local IsPlayerSpell = QuestieCompat.IsPlayerSpell
local IsSpellKnownOrOverridesKnown = QuestieCompat.IsSpellKnownOrOverridesKnown
local IsQuestFlaggedCompleted = QuestieCompat.IsQuestFlaggedCompleted or C_QuestLog.IsQuestFlaggedCompleted

--- Tag corrections for quests for which the API returns the wrong values.
--- Strucute: [questId] = {tagId, "questType"}
---@type table<number, {[1]: number, [2]: string}>
local questTagCorrections = {
    [17] = Questie.IsEra and {81, "Dungeon"} or nil, -- Uldaman Reagent Run
    [19] = {1, "Elite"}, -- Tharil'zun
    [55] = Questie.IsEra and {1, "Elite"} or nil, -- Morbent Fel
    [99] = Questie.IsEra and {1, "Elite"} or nil, -- Arugal's Folly
    [105] = {1, "Elite"}, -- Alas, Andorhal
    [115] = Questie.IsEra and {1, "Elite"} or nil, -- Shadow Magic
    [155] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Defias Brotherhood
    [166] = {81, "Dungeon"}, -- The Defias Brotherhood
    [169] = {1, "Elite"}, -- Wanted: Gath'Ilzogg
    [176] = {1, "Elite"}, -- Wanted: "Hogger"
    [193] = Questie.IsEra and {1, "Elite"} or nil, -- Panther Mastery
    [197] = Questie.IsEra and {1, "Elite"} or nil, -- Raptor Mastery
    [202] = Questie.IsEra and {1, "Elite"} or nil, -- Colonel Kurzen
    [206] = Questie.IsEra and {1, "Elite"} or nil, -- Mai'Zoth
    [208] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Big Game Hunter
    [211] = {1, "Elite"}, -- Alas, Andorhal
    [214] = {81, "Dungeon"}, -- Red Silk Bandanas
    [228] = {1, "Elite"}, -- Mor'Ladim
    [236] = {41, "PvP"}, -- Fueling the Demolishers
    [248] = Questie.IsEra and {1, "Elite"} or nil, -- Looking Further
    [249] = Questie.IsEra and {1, "Elite"} or nil, -- Morganth
    [253] = Questie.IsEra and {1, "Elite"} or nil, -- Bride of the Embalmer
    [255] = Questie.IsEra and {1, "Elite"} or nil, -- Mercenaries
    [256] = {1, "Elite"}, -- WANTED: Chok'sul
    [271] = Questie.IsEra and {1, "Elite"} or nil, -- Vyrin's Revenge
    [278] = Questie.IsEra and {1, "Elite"} or nil, -- A Dark Threat Looms
    [303] = Questie.IsEra and {1, "Elite"} or nil, -- The Dark Iron War
    [304] = Questie.IsEra and {1, "Elite"} or nil, -- A Grim Task
    [314] = Questie.IsEra and {1, "Elite"} or nil, -- Protecting the Herd
    [377] = {81, "Dungeon"}, -- Crime and Punishment
    [378] = {81, "Dungeon"}, -- The Fury Runs Deep
    [386] = {81, "Dungeon"}, -- What Comes Around...
    [387] = {81, "Dungeon"}, -- Quell The Uprising
    [388] = {81, "Dungeon"}, -- The Color of Blood
    [391] = {81, "Dungeon"}, -- The Stockade Riots
    [442] = Questie.IsEra and {1, "Elite"} or nil, -- Assault on Fenris Isle
    [450] = Questie.IsEra and {1, "Elite"} or nil, -- A Recipe For Death
    [452] = Questie.IsEra and {1, "Elite"} or nil, -- Pyrewood Ambush
    [474] = Questie.IsEra and {1, "Elite"} or nil, -- Defeat Nek'rosh
    [504] = Questie.IsEra and {1, "Elite"} or nil, -- Crushridge Warmongers
    [517] = Questie.IsEra and {1, "Elite"} or nil, -- Elixir of Agony
    [518] = Questie.IsEra and {1, "Elite"} or nil, -- The Crown of Will
    [519] = Questie.IsEra and {1, "Elite"} or nil, -- The Crown of Will
    [520] = Questie.IsEra and {1, "Elite"} or nil, -- The Crown of Will
    [531] = Questie.IsEra and {1, "Elite"} or nil, -- Vyrin's Revenge
    [540] = Questie.IsEra and {1, "Elite"} or nil, -- Preserving Knowledge
    [541] = Questie.IsEra and {1, "Elite"} or nil, -- Battle of Hillsbrad
    [543] = {1, "Elite"}, -- The Perenolde Tiara
    [547] = Questie.IsEra and {1, "Elite"} or nil, -- Humbert's Sword
    [591] = Questie.IsEra and {1, "Elite"} or nil, -- The Mind's Eye
    [611] = Questie.IsEra and {1, "Elite"} or nil, -- The Curse of the Tides
    [613] = Questie.IsEra and {1, "Elite"} or nil, -- Cracking Maury's Foot
    [628] = Questie.IsEra and {1, "Elite"} or nil, -- Excelsior
    [629] = Questie.IsEra and {1, "Elite"} or nil, -- The Vile Reef
    [630] = Questie.IsEra and {1, "Elite"} or nil, -- Message in a Bottle
    [631] = Questie.IsEra and {1, "Elite"} or nil, -- The Thandol Span
    [639] = Questie.IsEra and {1, "Elite"} or nil, -- Sigil of Strom
    [640] = Questie.IsEra and {1, "Elite"} or nil, -- The Broken Sigil
    [643] = Questie.IsEra and {1, "Elite"} or nil, -- Sigil of Arathor
    [644] = Questie.IsEra and {1, "Elite"} or nil, -- Sigil of Trollbane
    [645] = Questie.IsEra and {1, "Elite"} or nil, -- Trol'kalar
    [646] = Questie.IsEra and {1, "Elite"} or nil, -- Trol'kalar
    [652] = Questie.IsEra and {1, "Elite"} or nil, -- Breaking the Keystone
    [656] = {1, "Elite"}, -- Summoning the Princess
    [673] = Questie.IsEra and {1, "Elite"} or nil, -- Foul Magics
    [679] = Questie.IsEra and {1, "Elite"} or nil, -- Call to Arms
    [680] = Questie.IsEra and {1, "Elite"} or nil, -- The Real Threat
    [682] = Questie.IsEra and {1, "Elite"} or nil, -- Stromgarde Badges
    [684] = Questie.IsEra and {1, "Elite"} or nil, -- Wanted! Marez Cowl
    [685] = Questie.IsEra and {1, "Elite"} or nil, -- Wanted! Otto and Falconcrest
    [694] = Questie.IsEra and {1, "Elite"} or nil, -- Trelane's Defenses
    [695] = Questie.IsEra and {1, "Elite"} or nil, -- An Apprentice's Enchantment
    [696] = Questie.IsEra and {1, "Elite"} or nil, -- Attack on the Tower
    [697] = Questie.IsEra and {1, "Elite"} or nil, -- Malin's Request
    [704] = Questie.IsEra and {81, "Dungeon"} or nil, -- Agmond's Fate
    [705] = Questie.IsEra and {1, "Elite"} or nil, -- Pearl Diving
    [706] = Questie.IsEra and {1, "Elite"} or nil, -- Fiery Blaze Enchantments
    [709] = Questie.IsEra and {81, "Dungeon"} or nil, -- Solution to Doom
    [717] = Questie.IsEra and {1, "Elite"} or nil, -- Tremors of the Earth
    [721] = {81, "Dungeon"}, -- A Sign of Hope
    [722] = {81, "Dungeon"}, -- Amulet of Secrets
    [731] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Absent Minded Prospector
    [735] = {1, "Elite"}, -- The Star, the Hand and the Heart
    [736] = {1, "Elite"}, -- The Star, the Hand and the Heart
    [762] = Questie.IsEra and {1, "Elite"} or nil, -- An Ambassador of Evil
    [793] = Questie.IsEra and {1, "Elite"} or nil, -- Broken Alliances
    [914] = {81, "Dungeon"}, -- Leaders of the Fang
    [969] = {1, "Elite"}, -- Luck Be With You
    [971] = {81, "Dungeon"}, -- Knowledge in the Deeps
    [1013] = {81, "Dungeon"}, -- The Book of Ur
    [1014] = {81, "Dungeon"}, -- Arugal Must Die
    [1048] = {81, "Dungeon"}, -- Into The Scarlet Monastery
    [1049] = {81, "Dungeon"}, -- Compendium of the Fallen
    [1050] = {81, "Dungeon"}, -- Mythology of the Titans
    [1051] = {1, "Elite"}, -- Vorrel's Revenge
    [1053] = {81, "Dungeon"}, -- In the Name of the Light
    [1089] = Questie.IsEra and {1, "Elite"} or nil, -- The Den
    [1098] = {81, "Dungeon"}, -- Deathstalkers in Shadowfang
    [1100] = Questie.IsEra and {1, "Elite"} or nil, -- Lonebrow's Journal
    [1101] = {81, "Dungeon"}, -- The Crone of the Kraul
    [1102] = {81, "Dungeon"}, -- A Vengeful Fate
    [1107] = Questie.IsEra and {1, "Elite"} or nil, -- Encrusted Tail Fins
    [1109] = {81, "Dungeon"}, -- Going, Going, Guano!
    [1139] = {81, "Dungeon"}, -- The Lost Tablets of Will
    [1142] = {81, "Dungeon"}, -- Mortality Wanes
    [1144] = {81, "Dungeon"}, -- Willix the Importer
    [1151] = Questie.IsEra and {1, "Elite"} or nil, -- Test of Strength
    [1160] = {81, "Dungeon"}, -- Test of Lore
    [1166] = Questie.IsEra and {1, "Elite"} or nil, -- Overlord Mok'Morokk's Concern
    [1172] = Questie.IsEra and {1, "Elite"} or nil, -- The Brood of Onyxia
    [1173] = {1, "Elite"}, -- Challenge Overlord Mok'Morokk
    [1193] = {81, "Dungeon"}, -- A Broken Trap
    [1198] = {81, "Dungeon"}, -- In Search of Thaelrid
    [1199] = {81, "Dungeon"}, -- Twilight Falls
    [1200] = {81, "Dungeon"}, -- Blackfathom Villainy
    [1221] = {81, "Dungeon"}, -- Blueleaf Tubers
    [1222] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {84, "Escort"} or nil, -- Stinky's Escape
    [1270] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {84, "Escort"} or nil, -- Stinky's Escape
    [1275] = {81, "Dungeon"}, -- Researching the Corruption
    [1360] = Questie.IsEra and {81, "Dungeon"} or nil, -- Reclaimed Treasures
    [1380] = Questie.IsEra and {1, "Elite"} or nil, -- Khan Hratha
    [1381] = Questie.IsEra and {1, "Elite"} or nil, -- Khan Hratha
    [1383] = Questie.IsEra and {1, "Elite"} or nil, -- Nothing But The Truth
    [1424] = Questie.IsEra and {1, "Elite"} or nil, -- Pool of Tears
    [1442] = {81, "Dungeon"}, -- Seeking the Kor Gem
    [1445] = {81, "Dungeon"}, -- The Temple of Atal'Hakkar
    [1446] = {81, "Dungeon"}, -- Jammal'an the Prophet
    [1448] = {1, "Elite"}, -- In Search of The Temple
    [1475] = {81, "Dungeon"}, -- Into The Temple of Atal'Hakkar
    [1486] = {81, "Dungeon"}, -- Deviate Hides
    [1487] = {81, "Dungeon"}, -- Deviate Eradication
    [1488] = {1, "Elite"}, -- The Corrupter
    [1491] = {81, "Dungeon"}, -- Smart Drinks
    [1653] = {81, "Dungeon"}, -- The Test of Righteousness
    [1654] = {81, "Dungeon"}, -- The Test of Righteousness
    [1655] = {1, "Elite"}, -- Bailor's Ore Shipment
    [1657] = {41, "PvP"}, -- Stinking Up Southshore
    [1658] = {41, "PvP"}, -- Crashing the Wickerman Festival
    [1701] = {1, "Elite"}, -- Fire Hardened Mail
    [1713] = {1, "Elite"}, -- The Summoning
    [1740] = {81, "Dungeon"}, -- The Orb of Soran'ruk
    [1951] = {81, "Dungeon"}, -- Rituals of Power
    [1955] = {1, "Elite"}, -- The Exorcism
    [1956] = {81, "Dungeon"}, -- Power in Uldaman
    [2040] = {81, "Dungeon"}, -- Underground Assault
    [2078] = Questie.IsEra and {1, "Elite"} or nil, -- Gyromast's Revenge
    [2198] = {81, "Dungeon"}, -- The Shattered Necklace
    [2199] = {81, "Dungeon"}, -- Lore for a Price
    [2200] = {81, "Dungeon"}, -- Back to Uldaman
    [2201] = {81, "Dungeon"}, -- Find the Gems
    [2202] = Questie.IsEra and {81, "Dungeon"} or nil, -- Uldaman Reagent Run
    [2203] = Questie.IsEra and {1, "Elite"} or nil, -- Badlands Reagent Run II
    [2204] = {81, "Dungeon"}, -- Restoring the Necklace
    [2240] = {81, "Dungeon"}, -- The Hidden Chamber
    [2278] = {81, "Dungeon"}, -- The Platinum Discs
    [2280] = {81, "Dungeon"}, -- The Platinum Discs
    [2283] = {81, "Dungeon"}, -- Necklace Recovery
    [2284] = {81, "Dungeon"}, -- Necklace Recovery, Take 2
    [2318] = {81, "Dungeon"}, -- Translating the Journal
    [2338] = {81, "Dungeon"}, -- Translating the Journal
    [2339] = {81, "Dungeon"}, -- Find the Gems and Power Source
    [2340] = {81, "Dungeon"}, -- Deliver the Gems
    [2341] = {81, "Dungeon"}, -- Necklace Recovery, Take 3
    [2342] = Questie.IsEra and {81, "Dungeon"} or nil, -- Reclaimed Treasures
    [2359] = Questie.IsEra and {1, "Elite"} or nil, -- Klaven's Tower
    [2361] = {81, "Dungeon"}, -- Restoring the Necklace
    [2398] = {81, "Dungeon"}, -- The Lost Dwarves
    [2418] = Questie.IsEra and {81, "Dungeon"} or nil, -- Power Stones
    [2478] = Questie.IsEra and {1, "Elite"} or nil, -- Mission: Possible But Not Probable
    [2499] = Questie.IsEra and {1, "Elite"} or nil, -- Oakenscowl
    [2501] = Questie.IsEra and {1, "Elite"} or nil, -- Badlands Reagent Run II
    [2721] = Questie.IsEra and {1, "Elite"} or nil, -- Kirith
    [2768] = {81, "Dungeon"}, -- Divino-matic Rod
    [2769] = {81, "Dungeon"}, -- The Brassbolts Brothers
    [2770] = {81, "Dungeon"}, -- Gahz'rilla
    [2841] = {81, "Dungeon"}, -- Rig Wars
    [2842] = {81, "Dungeon"}, -- Chief Engineer Scooty
    [2843] = {81, "Dungeon"}, -- Gnomer-gooooone!
    [2846] = {81, "Dungeon"}, -- Tiara of the Deep
    [2861] = {81, "Dungeon"}, -- Tabetha's Task
    [2864] = {81, "Dungeon"}, -- Tran'rek
    [2865] = {81, "Dungeon"}, -- Scarab Shells
    [2904] = {81, "Dungeon"}, -- A Fine Mess
    [2922] = {81, "Dungeon"}, -- Save Techbot's Brain!
    [2923] = {81, "Dungeon"}, -- Tinkmaster Overspark
    [2924] = {81, "Dungeon"}, -- Essential Artificials
    [2925] = {81, "Dungeon"}, -- Klockmort's Essentials
    [2926] = {81, "Dungeon"}, -- Gnogaine
    [2927] = {81, "Dungeon"}, -- The Day After
    [2928] = {81, "Dungeon"}, -- Gyrodrillmatic Excavationators
    [2929] = {81, "Dungeon"}, -- The Grand Betrayal
    [2930] = {81, "Dungeon"}, -- Data Rescue
    [2931] = {81, "Dungeon"}, -- Castpipe's Task
    [2935] = Questie.IsEra and {1, "Elite"} or nil, -- Consult Master Gadrin
    [2936] = {81, "Dungeon"}, -- The Spider God
    [2937] = {1, "Elite"}, -- Summoning Shadra
    [2944] = Questie.IsEra and {1, "Elite"} or nil, -- The Super Snapper FX
    [2945] = {81, "Dungeon"}, -- Grime-Encrusted Ring
    [2946] = {1, "Elite"}, -- Seeing What Happens
    [2947] = {81, "Dungeon"}, -- Return of the Ring
    [2949] = {81, "Dungeon"}, -- Return of the Ring
    [2951] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [2952] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [2953] = {81, "Dungeon"}, -- More Sparklematic Action
    [2954] = Questie.IsEra and {1, "Elite"} or nil, -- The Stone Watcher
    [2962] = {81, "Dungeon"}, -- The Only Cure is More Green Glow
    [2966] = {1, "Elite"}, -- Seeing What Happens
    [2967] = Questie.IsEra and {1, "Elite"} or nil, -- Return to Thunder Bluff
    [2977] = Questie.IsEra and {1, "Elite"} or nil, -- Return to Ironforge
    [2991] = {81, "Dungeon"}, -- Nekrum's Medallion
    [2993] = Questie.IsEra and {1, "Elite"} or nil, -- Return to the Hinterlands
    [2994] = Questie.IsEra and {1, "Elite"} or nil, -- Saving Sharpbeak
    [3042] = {81, "Dungeon"}, -- Troll Temper
    [3062] = Questie.IsEra and {1, "Elite"} or nil, -- Dark Heart
    [3127] = {1, "Elite"}, -- Mountain Giant Muisek
    [3181] = Questie.IsEra and {1, "Elite"} or nil, -- The Horn of the Beast
    [3182] = Questie.IsEra and {1, "Elite"} or nil, -- Proof of Deed
    [3201] = Questie.IsEra and {1, "Elite"} or nil, -- At Last!
    [3341] = {81, "Dungeon"}, -- Bring the End
    [3372] = Questie.IsEra and {1, "Elite"} or nil, -- Release Them
    [3373] = {81, "Dungeon"}, -- The Essence of Eranikus
    [3380] = {81, "Dungeon"}, -- The Sunken Temple
    [3385] = Questie.IsEra and {1, "Elite"} or nil, -- The Undermarket
    [3446] = {81, "Dungeon"}, -- Into the Depths
    [3447] = {81, "Dungeon"}, -- Secret of the Circle
    [3452] = Questie.IsEra and {1, "Elite"} or nil, -- The Flame's Casing
    [3463] = Questie.IsEra and {1, "Elite"} or nil, -- Set Them Ablaze!
    [3510] = Questie.IsEra and {1, "Elite"} or nil, -- The Name of the Beast
    [3514] = Questie.IsEra and {1, "Elite"} or nil, -- Horde Presence
    [3523] = {81, "Dungeon"}, -- Scourge of the Downs
    [3525] = {81, "Dungeon"}, -- Extinguishing the Idol
    [3527] = {81, "Dungeon"}, -- The Prophecy of Mosh'aru
    [3528] = {81, "Dungeon"}, -- The God Hakkar
    [3566] = Questie.IsEra and {1, "Elite"} or nil, -- Rise, Obsidion!
    [3602] = {1, "Elite"}, -- Azsharite
    [3627] = {1, "Elite"}, -- Uniting the Shattered Amulet
    [3628] = {1, "Elite"}, -- You Are Rakh'likh, Demon
    [3636] = {81, "Dungeon"}, -- Bring the Light
    [3801] = {81, "Dungeon"}, -- Dark Iron Legacy
    [3802] = {81, "Dungeon"}, -- Dark Iron Legacy
    [3906] = {81, "Dungeon"}, -- Disharmony of Flame
    [3907] = {81, "Dungeon"}, -- Disharmony of Fire
    [3962] = {1, "Elite"}, -- It's Dangerous to Go Alone
    [3981] = {81, "Dungeon"}, -- Commander Gor'shak
    [3982] = {81, "Dungeon"}, -- What Is Going On?
    [4001] = {81, "Dungeon"}, -- What Is Going On?
    [4002] = {81, "Dungeon"}, -- The Eastern Kingdoms
    [4003] = {81, "Dungeon"}, -- The Royal Rescue
    [4004] = {81, "Dungeon"}, -- The Princess Saved?
    [4021] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Counterattack!
    [4023] = Questie.IsEra and {1, "Elite"} or nil, -- A Taste of Flame
    [4024] = {81, "Dungeon"}, -- A Taste of Flame
    [4063] = {81, "Dungeon"}, -- The Rise of the Machines
    [4081] = {81, "Dungeon"}, -- KILL ON SIGHT: Dark Iron Dwarves
    [4082] = {81, "Dungeon"}, -- KILL ON SIGHT: High Ranking Dark Iron Officials
    [4083] = {81, "Dungeon"}, -- The Spectral Chalice
    [4121] = {81, "Dungeon"}, -- Precarious Predicament
    [4122] = {81, "Dungeon"}, -- Grark Lorkrub
    [4123] = {81, "Dungeon"}, -- The Heart of the Mountain
    [4126] = {81, "Dungeon"}, -- Hurley Blackbreath
    [4128] = {81, "Dungeon"}, -- Ragnar Thunderbrew
    [4132] = {81, "Dungeon"}, -- Operation: Death to Angerforge
    [4133] = {81, "Dungeon"}, -- Vivian Lagrave
    [4134] = {81, "Dungeon"}, -- Lost Thunderbrew Recipe
    [4136] = {81, "Dungeon"}, -- Ribbly Screwspigot
    [4143] = {81, "Dungeon"}, -- Haze of Evil
    [4146] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {81, "Dungeon"} or {1, "Elite"}, -- Zapper Fuel
    [4148] = {81, "Dungeon"}, -- Bloodpetal Zapper
    [4182] = Questie.IsEra and {1, "Elite"} or nil, -- Dragonkin Menace
    [4201] = {81, "Dungeon"}, -- The Love Potion
    [4241] = {81, "Dungeon"}, -- Marshal Windsor
    [4242] = {81, "Dungeon"}, -- Abandoned Hope
    [4262] = {81, "Dungeon"}, -- Overmaster Pyron
    [4263] = {81, "Dungeon"}, -- Incendius!
    [4264] = {81, "Dungeon"}, -- A Crumpled Up Note
    [4282] = {81, "Dungeon"}, -- A Shred of Hope
    [4286] = {81, "Dungeon"}, -- The Good Stuff
    [4295] = {81, "Dungeon"}, -- Rocknot's Ale
    [4322] = {81, "Dungeon"}, -- Jail Break!
    [4324] = {81, "Dungeon"}, -- Yuka Screwspigot
    [4341] = {81, "Dungeon"}, -- Kharan Mighthammer
    [4342] = {81, "Dungeon"}, -- Kharan's Tale
    [4361] = {81, "Dungeon"}, -- The Bearer of Bad News
    [4362] = {81, "Dungeon"}, -- The Fate of the Kingdom
    [4363] = {81, "Dungeon"}, -- The Princess's Surprise
    [4601] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [4602] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [4603] = {81, "Dungeon"}, -- More Sparklematic Action
    [4604] = {81, "Dungeon"}, -- More Sparklematic Action
    [4605] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [4606] = {81, "Dungeon"}, -- The Sparklematic 5200!
    [4701] = {81, "Dungeon"}, -- Put Her Down
    [4724] = {81, "Dungeon"}, -- The Pack Mistress
    [4729] = {81, "Dungeon"}, -- Kibler's Exotic Pets
    [4734] = {62, "Raid"}, -- Egg Freezing
    [4735] = {62, "Raid"}, -- Egg Collection
    [4742] = {81, "Dungeon"}, -- Seal of Ascension
    [4743] = {81, "Dungeon"}, -- Seal of Ascension
    [4764] = {62, "Raid"}, -- Doomrigger's Clasp
    [4766] = {62, "Raid"}, -- Mayara Brightwing
    [4768] = {62, "Raid"}, -- The Darkstone Tablet
    [4769] = {62, "Raid"}, -- Vivian Lagrave and the Darkstone Tablet
    [4771] = {81, "Dungeon"}, -- Dawn's Gambit
    [4787] = Questie.IsEra and {1, "Elite"} or nil, -- The Ancient Egg
    [4788] = {81, "Dungeon"}, -- The Final Tablets
    [4862] = {81, "Dungeon"}, -- En-Ay-Es-Tee-Why
    [4866] = {81, "Dungeon"}, -- Mother's Milk
    [4867] = {81, "Dungeon"}, -- Urok Doomhowl
    [4903] = {81, "Dungeon"}, -- Warlord's Command
    [4907] = {62, "Raid"}, -- Tinkee Steamboil
    [4961] = {1, "Elite"}, -- Cleansing of the Orb of Orahil
    [4974] = {62, "Raid"}, -- For The Horde!
    [4981] = {81, "Dungeon"}, -- Operative Bijou
    [4982] = {81, "Dungeon"}, -- Bijou's Belongings
    [4983] = {81, "Dungeon"}, -- Bijou's Reconnaissance Report
    [5001] = {81, "Dungeon"}, -- Bijou's Belongings
    [5002] = {81, "Dungeon"}, -- Message to Maxwell
    [5047] = {81, "Dungeon"}, -- Pip Quickwit, At Your Service!
    [5054] = Questie.IsEra and {1, "Elite"} or nil, -- Ursius of the Shardtooth
    [5055] = Questie.IsEra and {1, "Elite"} or nil, -- Brumeran of the Chillwind
    [5056] = Questie.IsEra and {1, "Elite"} or nil, -- Shy-Rotam
    [5063] = {1, "Elite"}, -- Cap of the Scarlet Savant
    [5065] = Questie.IsEra and {1, "Elite"} or nil, -- The Lost Tablets of Mosh'aru
    [5067] = {1, "Elite"}, -- Leggings of Arcana
    [5068] = {1, "Elite"}, -- Breastplate of Bloodthirst
    [5081] = {81, "Dungeon"}, -- Maxwell's Mission
    [5088] = Questie.IsEra and {1, "Elite"} or nil, -- Arikara
    [5089] = {81, "Dungeon"}, -- General Drakkisath's Command
    [5098] = Questie.IsEra and {1, "Elite"} or nil, -- All Along the Watchtowers
    [5102] = {62, "Raid"}, -- General Drakkisath's Demise
    [5103] = {81, "Dungeon"}, -- Hot Fiery Death
    [5121] = Questie.IsEra and {1, "Elite"} or nil, -- High Chief Winterfall
    [5122] = {81, "Dungeon"}, -- The Medallion of Faith
    [5124] = {1, "Elite"}, -- Fiery Plate Gauntlets
    [5125] = {81, "Dungeon"}, -- Aurius' Reckoning
    [5127] = {81, "Dungeon"}, -- The Demon Forge
    [5151] = {1, "Elite"}, -- Hypercapacitor Gizmo
    [5153] = Questie.IsEra and {1, "Elite"} or nil, -- A Strange Historian
    [5156] = Questie.IsEra and {1, "Elite"} or nil, -- Verifying the Corruption
    [5160] = {81, "Dungeon"}, -- The Matron Protectorate
    [5162] = {1, "Elite"}, -- Wrath of the Blue Flight
    [5164] = {1, "Elite"}, -- Catalogue of the Wayward
    [5166] = {1, "Elite"}, -- Breastplate of the Chromatic Flight
    [5167] = {1, "Elite"}, -- Legplates of the Chromatic Defier
    [5168] = Questie.IsEra and {1, "Elite"} or nil, -- Heroes of Darrowshire
    [5212] = {81, "Dungeon"}, -- The Flesh Does Not Lie
    [5213] = {81, "Dungeon"}, -- The Active Agent
    [5214] = {81, "Dungeon"}, -- The Great Ezra Grimm
    [5243] = {81, "Dungeon"}, -- Houses of the Holy
    [5247] = Questie.IsEra and {1, "Elite"} or nil, -- Fragments of the Past
    [5251] = {81, "Dungeon"}, -- The Archivist
    [5262] = {81, "Dungeon"}, -- The Truth Comes Crashing Down
    [5263] = {81, "Dungeon"}, -- Above and Beyond
    [5264] = Questie.IsEra and {1, "Elite"} or nil, -- Lord Maxwell Tyrosus
    [5265] = Questie.IsEra and {1, "Elite"} or nil, -- The Argent Hold
    [5281] = {81, "Dungeon"}, -- The Restless Souls
    [5282] = {81, "Dungeon"}, -- The Restless Souls
    [5305] = {81, "Dungeon"}, -- Sweet Serenity
    [5306] = {81, "Dungeon"}, -- Snakestone of the Shadow Huntress
    [5307] = {81, "Dungeon"}, -- Corruption
    [5341] = {81, "Dungeon"}, -- Barov Family Fortune
    [5342] = Questie.IsEra and {41, "PvP"} or {1, "Elite"}, -- The Last Barov
    [5343] = {81, "Dungeon"}, -- Barov Family Fortune
    [5344] = Questie.IsEra and {41, "PvP"} or {1, "Elite"}, -- The Last Barov
    [5382] = {81, "Dungeon"}, -- Doctor Theolen Krastinov, the Butcher
    [5384] = {81, "Dungeon"}, -- Kirtonos the Herald
    [5461] = {1, "Elite"}, -- The Human, Ras Frostwhisper
    [5462] = {1, "Elite"}, -- The Dying, Ras Frostwhisper
    [5463] = {81, "Dungeon"}, -- Menethil's Gift
    [5464] = {1, "Elite"}, -- Menethil's Gift
    [5465] = {1, "Elite"}, -- Soulbound Keepsake
    [5466] = {81, "Dungeon"}, -- The Lich, Ras Frostwhisper
    [5515] = {81, "Dungeon"}, -- Krastinov's Bag of Horrors
    [5518] = {81, "Dungeon"}, -- The Gordok Ogre Suit
    [5519] = {81, "Dungeon"}, -- The Gordok Ogre Suit
    [5522] = {81, "Dungeon"}, -- Leonid Barthalomew
    [5525] = {81, "Dungeon"}, -- Free Knot!
    [5526] = {81, "Dungeon"}, -- Shards of the Felvine
    [5528] = {81, "Dungeon"}, -- The Gordok Taste Test
    [5529] = {81, "Dungeon"}, -- Plagued Hatchlings
    [5531] = {81, "Dungeon"}, -- Betina Bigglezink
    [5582] = {81, "Dungeon"}, -- Healthy Dragon Scale
    [5721] = {62, "Raid"}, -- The Battle of Darrowshire
    [5722] = {81, "Dungeon"}, -- Searching for the Lost Satchel
    [5723] = {81, "Dungeon"}, -- Testing an Enemy's Strength
    [5724] = {81, "Dungeon"}, -- Returning the Lost Satchel
    [5725] = {81, "Dungeon"}, -- The Power to Destroy...
    [5728] = {81, "Dungeon"}, -- Hidden Enemies
    [5761] = {81, "Dungeon"}, -- Slaying the Beast
    [5803] = {1, "Elite"}, -- Araj's Scarab
    [5804] = {1, "Elite"}, -- Araj's Scarab
    [5848] = {81, "Dungeon"}, -- Of Love and Family
    [5862] = {1, "Elite"}, -- Scarlet Subterfuge
    [5892] = {41, "PvP"}, -- Irondeep Supplies
    [5893] = {41, "PvP"}, -- Coldtooth Supplies
    [5944] = {1, "Elite"}, -- In Dreams
    [5981] = {1, "Elite"}, -- Rampaging Giants
    [6025] = Questie.IsEra and {1, "Elite"} or nil, -- Unfinished Business
    [6041] = Questie.IsEra and {1, "Elite"} or nil, -- When Smokey Sings, I Get Violent
    [6135] = Questie.IsEra and {1, "Elite"} or nil, -- Duskwing, Oh How I Hate Thee...
    [6136] = Questie.IsEra and {1, "Elite"} or nil, -- The Corpulent One
    [6145] = {1, "Elite"}, -- The Crimson Courier
    [6146] = {1, "Elite"}, -- Nathanos' Ruse
    [6147] = {1, "Elite"}, -- Return to Nathanos
    [6148] = {1, "Elite"}, -- The Scarlet Oracle, Demetria
    [6163] = {81, "Dungeon"}, -- Ramstein
    [6182] = {1, "Elite"}, -- The First and the Last
    [6183] = {1, "Elite"}, -- Honor the Dead
    [6184] = {1, "Elite"}, -- Flint Shadowmore
    [6185] = {1, "Elite"}, -- The Eastern Plagues
    [6186] = {1, "Elite"}, -- The Blightcaller Cometh
    [6187] = {62, "Raid"}, -- Order Must Be Restored
    [6283] = Questie.IsEra and {1, "Elite"} or nil, -- Bloodfury Bloodline
    [6284] = Questie.IsEra and {1, "Elite"} or nil, -- Arachnophobia
    [6402] = {62, "Raid"}, -- Stormwind Rendezvous
    [6403] = {62, "Raid"}, -- The Great Masquerade
    [6481] = Questie.IsEra and {1, "Elite"} or nil, -- Earthen Arise
    [6501] = {62, "Raid"}, -- The Dragon's Eye
    [6502] = {62, "Raid"}, -- Drakefire Amulet
    [6521] = {81, "Dungeon"}, -- An Unholy Alliance
    [6522] = {81, "Dungeon"}, -- An Unholy Alliance
    [6561] = {81, "Dungeon"}, -- Blackfathom Villainy
    [6562] = {81, "Dungeon"}, -- Trouble in the Deeps
    [6563] = {81, "Dungeon"}, -- The Essence of Aku'Mai
    [6564] = {81, "Dungeon"}, -- Allegiance to the Old Gods
    [6565] = {81, "Dungeon"}, -- Allegiance to the Old Gods
    [6569] = {62, "Raid"}, -- Oculus Illusions
    [6570] = {1, "Elite"}, -- Emberstrife
    [6582] = {62, "Raid"}, -- The Test of Skulls, Scryer
    [6583] = {62, "Raid"}, -- The Test of Skulls, Somnus
    [6584] = {62, "Raid"}, -- The Test of Skulls, Chronalis
    [6585] = {62, "Raid"}, -- The Test of Skulls, Axtroz
    [6602] = {62, "Raid"}, -- Blood of the Black Dragon Champion
    [6626] = {81, "Dungeon"}, -- A Host of Evil
    [6641] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Vorsha the Lasher
    [6642] = {81, "Dungeon"}, -- Favor Amongst the Brotherhood, Dark Iron Ore
    [6643] = {81, "Dungeon"}, -- Favor Amongst the Brotherhood, Fiery Core
    [6644] = {81, "Dungeon"}, -- Favor Amongst the Brotherhood, Lava Core
    [6645] = {81, "Dungeon"}, -- Favor Amongst the Brotherhood, Core Leather
    [6646] = {81, "Dungeon"}, -- Favor Amongst the Brotherhood, Blood of the Mountain
    [6741] = {41, "PvP"}, -- More Booty!
    [6781] = {41, "PvP"}, -- More Armor Scraps
    [6801] = {41, "PvP"}, -- Lokholar the Ice Lord
    [6821] = {62, "Raid"}, -- Eye of the Emberseer
    [6822] = {62, "Raid"}, -- The Molten Core
    [6824] = {62, "Raid"}, -- Hands of the Enemy
    [6825] = {41, "PvP"}, -- Call of Air - Guse's Fleet
    [6826] = {41, "PvP"}, -- Call of Air - Jeztor's Fleet
    [6827] = {41, "PvP"}, -- Call of Air - Mulverick's Fleet
    [6846] = {41, "PvP"}, -- Begin the Attack!
    [6847] = {41, "PvP"}, -- Master Ryson's All Seeing Eye
    [6848] = {41, "PvP"}, -- Master Ryson's All Seeing Eye
    [6861] = {41, "PvP"}, -- Zinfizzlex's Portable Shredder Unit
    [6862] = {41, "PvP"}, -- Zinfizzlex's Portable Shredder Unit
    [6881] = {41, "PvP"}, -- Ivus the Forest Lord
    [6901] = {41, "PvP"}, -- Launch the Attack!
    [6921] = {81, "Dungeon"}, -- Amongst the Ruins
    [6922] = {81, "Dungeon"}, -- Baron Aquanis
    [6941] = {41, "PvP"}, -- Call of Air - Vipore's Fleet
    [6942] = {41, "PvP"}, -- Call of Air - Slidore's Fleet
    [6943] = {41, "PvP"}, -- Call of Air - Ichman's Fleet
    [6982] = {41, "PvP"}, -- Coldtooth Supplies
    [6983] = {1, "Elite"}, -- You're a Mean One...
    [6985] = {41, "PvP"}, -- Irondeep Supplies
    [7001] = {41, "PvP"}, -- Empty Stables
    [7002] = {41, "PvP"}, -- Ram Hide Harnesses
    [7026] = {41, "PvP"}, -- Ram Riding Harnesses
    [7027] = {41, "PvP"}, -- Empty Stables
    [7028] = {81, "Dungeon"}, -- Twisted Evils
    [7029] = {81, "Dungeon"}, -- Vyletongue Corruption
    [7041] = {81, "Dungeon"}, -- Vyletongue Corruption
    [7043] = {1, "Elite"}, -- You're a Mean One...
    [7044] = {81, "Dungeon"}, -- Legends of Maraudon
    [7046] = {81, "Dungeon"}, -- The Scepter of Celebras
    [7064] = {81, "Dungeon"}, -- Corruption of Earth and Seed
    [7065] = {81, "Dungeon"}, -- Corruption of Earth and Seed
    [7066] = {81, "Dungeon"}, -- Seed of Life
    [7067] = {81, "Dungeon"}, -- The Pariah's Instructions
    [7068] = {81, "Dungeon"}, -- Shadowshard Fragments
    [7070] = {81, "Dungeon"}, -- Shadowshard Fragments
    [7081] = {41, "PvP"}, -- Alterac Valley Graveyards
    [7082] = {41, "PvP"}, -- The Graveyards of Alterac
    [7101] = {41, "PvP"}, -- Towers and Bunkers
    [7102] = {41, "PvP"}, -- Towers and Bunkers
    [7121] = {41, "PvP"}, -- The Quartermaster
    [7122] = {41, "PvP"}, -- Capture a Mine
    [7123] = {41, "PvP"}, -- Speak with our Quartermaster
    [7124] = {41, "PvP"}, -- Capture a Mine
    [7141] = {41, "PvP"}, -- The Battle of Alterac
    [7142] = {41, "PvP"}, -- The Battle for Alterac
    [7161] = {41, "PvP"}, -- Proving Grounds
    [7162] = {41, "PvP"}, -- Proving Grounds
    [7163] = {41, "PvP"}, -- Rise and Be Recognized
    [7164] = {41, "PvP"}, -- Honored Amongst the Clan
    [7165] = {41, "PvP"}, -- Earned Reverence
    [7166] = {41, "PvP"}, -- Legendary Heroes
    [7167] = {41, "PvP"}, -- The Eye of Command
    [7168] = {41, "PvP"}, -- Rise and Be Recognized
    [7169] = {41, "PvP"}, -- Honored Amongst the Guard
    [7170] = {41, "PvP"}, -- Earned Reverence
    [7171] = {41, "PvP"}, -- Legendary Heroes
    [7172] = {41, "PvP"}, -- The Eye of Command
    [7181] = {41, "PvP"}, -- The Legend of Korrak
    [7201] = {81, "Dungeon"}, -- The Last Element
    [7202] = {41, "PvP"}, -- Korrak the Bloodrager
    [7221] = {41, "PvP"}, -- Speak with Prospector Stonehewer
    [7222] = {41, "PvP"}, -- Speak with Voggah Deathgrip
    [7223] = {41, "PvP"}, -- Armor Scraps
    [7224] = {41, "PvP"}, -- Enemy Booty
    [7241] = {41, "PvP"}, -- In Defense of Frostwolf
    [7261] = {41, "PvP"}, -- The Sovereign Imperative
    [7281] = {41, "PvP"}, -- Brotherly Love
    [7282] = {41, "PvP"}, -- Brotherly Love
    [7301] = {41, "PvP"}, -- Fallen Sky Lords
    [7302] = {41, "PvP"}, -- Fallen Sky Lords
    [7361] = {41, "PvP"}, -- Favor Amongst the Darkspear
    [7362] = {41, "PvP"}, -- Ally of the Tauren
    [7363] = {41, "PvP"}, -- The Human Condition
    [7364] = {41, "PvP"}, -- Gnomeregan Bounty
    [7365] = {41, "PvP"}, -- Staghelm's Requiem
    [7366] = {41, "PvP"}, -- The Archbishop's Mercy
    [7367] = {41, "PvP"}, -- Defusing the Threat
    [7368] = {41, "PvP"}, -- Defusing the Threat
    [7381] = {41, "PvP"}, -- The Return of Korrak
    [7382] = {41, "PvP"}, -- Korrak the Everliving
    [7385] = {41, "PvP"}, -- A Gallon of Blood
    [7386] = {41, "PvP"}, -- Crystal Cluster
    [7401] = {41, "PvP"}, -- WANTED: Dwarves!
    [7402] = {41, "PvP"}, -- WANTED: Orcs!
    [7421] = {41, "PvP"}, -- Darkspear Defense
    [7422] = {41, "PvP"}, -- Tuft it Out
    [7423] = {41, "PvP"}, -- I've Got A Fever For More Bone Chips
    [7424] = {41, "PvP"}, -- What the Hoof?
    [7425] = {41, "PvP"}, -- Staghelm's Mojo Jamboree
    [7426] = {41, "PvP"}, -- One Man's Love
    [7427] = {41, "PvP"}, -- Wanted: MORE DWARVES!
    [7428] = {41, "PvP"}, -- Wanted: MORE ORCS!
    [7429] = {81, "Dungeon"}, -- Free Knot!
    [7441] = {81, "Dungeon"}, -- Pusillin and the Elder Azj'Tordin
    [7461] = {81, "Dungeon"}, -- The Madness Within
    [7463] = {81, "Dungeon"}, -- Arcane Refreshment
    [7481] = {81, "Dungeon"}, -- Elven Legends
    [7482] = {81, "Dungeon"}, -- Elven Legends
    [7483] = {81, "Dungeon"}, -- Libram of Rapidity
    [7484] = {81, "Dungeon"}, -- Libram of Focus
    [7485] = {81, "Dungeon"}, -- Libram of Protection
    [7488] = {81, "Dungeon"}, -- Lethtendris's Web
    [7489] = {81, "Dungeon"}, -- Lethtendris's Web
    [7492] = {81, "Dungeon"}, -- Camp Mojache
    [7494] = {81, "Dungeon"}, -- Feathermoon Stronghold
    [7498] = {81, "Dungeon"}, -- Garona: A Study on Stealth and Treachery
    [7499] = {81, "Dungeon"}, -- Codex of Defense
    [7500] = {81, "Dungeon"}, -- The Arcanist's Cookbook
    [7501] = {81, "Dungeon"}, -- The Light and How To Swing It
    [7502] = {81, "Dungeon"}, -- Harnessing Shadows
    [7503] = {81, "Dungeon"}, -- The Greatest Race of Hunters
    [7504] = {81, "Dungeon"}, -- Holy Bologna: What the Light Won't Tell You
    [7505] = {81, "Dungeon"}, -- Frost Shock and You
    [7506] = {81, "Dungeon"}, -- The Emerald Dream...
    [7507] = {81, "Dungeon"}, -- Nostro's Compendium
    [7508] = {81, "Dungeon"}, -- The Forging of Quel'Serrar
    [7509] = {62, "Raid"}, -- The Forging of Quel'Serrar
    [7581] = {81, "Dungeon"}, -- The Prison's Bindings
    [7582] = {1, "Elite"}, -- The Prison's Casing
    [7583] = {1, "Elite"}, -- Suppression
    [7603] = Questie.IsEra and {1, "Elite"} or nil, -- Kroshius' Infernal Core
    [7604] = {81, "Dungeon"}, -- A Binding Contract
    [7629] = {81, "Dungeon"}, -- Imp Delivery
    [7631] = {81, "Dungeon"}, -- Dreadsteed of Xoroth
    [7634] = {62, "Raid"}, -- Ancient Sinew Wrapped Lamina
    [7635] = {62, "Raid"}, -- A Proper String
    [7636] = Questie.IsEra and {1, "Elite"} or nil, -- Stave of the Ancients
    [7642] = {81, "Dungeon"}, -- Collection of Goods
    [7643] = {81, "Dungeon"}, -- Ancient Equine Spirit
    [7647] = {81, "Dungeon"}, -- Judgment and Redemption
    [7649] = {81, "Dungeon"}, -- Enchanted Thorium Platemail: Volume I
    [7650] = {81, "Dungeon"}, -- Enchanted Thorium Platemail: Volume II
    [7651] = {81, "Dungeon"}, -- Enchanted Thorium Platemail: Volume III
    [7666] = {81, "Dungeon"}, -- Again Into the Great Ossuary
    [7668] = {81, "Dungeon"}, -- The Darkreaver Menace
    [7701] = Questie.IsEra and {1, "Elite"} or nil, -- WANTED: Overseer Maltorius
    [7703] = {81, "Dungeon"}, -- Unfinished Gordok Business
    [7737] = {81, "Dungeon"}, -- Gaining Acceptance
    [7761] = {81, "Dungeon"}, -- Blackhand's Command
    [7786] = {62, "Raid"}, -- Thunderaan the Windseeker
    [7788] = {41, "PvP"}, -- Vanquish the Invaders!
    [7789] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [7810] = {41, "PvP"}, -- Arena Master
    [7816] = Questie.IsEra and {1, "Elite"} or nil, -- Gammerita, Mon!
    [7838] = {41, "PvP"}, -- Arena Grandmaster
    [7841] = {41, "PvP"}, -- Message to the Wildhammer
    [7842] = {41, "PvP"}, -- Another Message to the Wildhammer
    [7843] = {41, "PvP"}, -- The Final Message to the Wildhammer
    [7845] = Questie.IsEra and {1, "Elite"} or nil, -- Kidnapped Elder Torntusk!
    [7846] = Questie.IsEra and {1, "Elite"} or nil, -- Recover the Key!
    [7847] = Questie.IsEra and {1, "Elite"} or nil, -- Return to Primal Torntusk
    [7848] = {81, "Dungeon"}, -- Attunement to the Core
    [7849] = Questie.IsEra and {1, "Elite"} or nil, -- Separation Anxiety
    [7850] = Questie.IsEra and {1, "Elite"} or nil, -- Dark Vessels
    [7861] = Questie.IsEra and {1, "Elite"} or nil, -- Wanted: Vile Priestess Hexx and Her Minions
    [7862] = Questie.IsEra and {1, "Elite"} or nil, -- Job Opening: Guard Captain of Revantusk Village
    [7871] = {41, "PvP"}, -- Vanquish the Invaders!
    [7872] = {41, "PvP"}, -- Vanquish the Invaders!
    [7873] = {41, "PvP"}, -- Vanquish the Invaders!
    [7874] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [7875] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [7876] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [7877] = {81, "Dungeon"}, -- The Treasure of the Shen'dralar
    [7886] = {41, "PvP"}, -- Talismans of Merit
    [7887] = {41, "PvP"}, -- Talismans of Merit
    [7888] = {41, "PvP"}, -- Talismans of Merit
    [7921] = {41, "PvP"}, -- Talismans of Merit
    [7922] = {41, "PvP"}, -- Mark of Honor
    [7923] = {41, "PvP"}, -- Mark of Honor
    [7924] = {41, "PvP"}, -- Mark of Honor
    [7925] = {41, "PvP"}, -- Mark of Honor
    [8041] = {62, "Raid"}, -- Strength of Mount Mugamba
    [8042] = {62, "Raid"}, -- Strength of Mount Mugamba
    [8043] = {62, "Raid"}, -- Strength of Mount Mugamba
    [8044] = {62, "Raid"}, -- The Rage of Mugamba
    [8045] = {62, "Raid"}, -- The Heathen's Brand
    [8046] = {62, "Raid"}, -- The Heathen's Brand
    [8047] = {62, "Raid"}, -- The Heathen's Brand
    [8048] = {62, "Raid"}, -- The Hero's Brand
    [8049] = {62, "Raid"}, -- The Eye of Zuldazar
    [8050] = {62, "Raid"}, -- The Eye of Zuldazar
    [8051] = {62, "Raid"}, -- The Eye of Zuldazar
    [8052] = {62, "Raid"}, -- The All-Seeing Eye of Zuldazar
    [8053] = {62, "Raid"}, -- Paragons of Power: The Freethinker's Armguards
    [8054] = {62, "Raid"}, -- Paragons of Power: The Freethinker's Belt
    [8055] = {62, "Raid"}, -- Paragons of Power: The Freethinker's Breastplate
    [8056] = {62, "Raid"}, -- Paragons of Power: The Augur's Bracers
    [8057] = {62, "Raid"}, -- Paragons of Power: The Haruspex's Bracers
    [8058] = {62, "Raid"}, -- Paragons of Power: The Vindicator's Armguards
    [8059] = {62, "Raid"}, -- Paragons of Power: The Demoniac's Wraps
    [8060] = {62, "Raid"}, -- Paragons of Power: The Illusionist's Wraps
    [8061] = {62, "Raid"}, -- Paragons of Power: The Confessor's Wraps
    [8062] = {62, "Raid"}, -- Paragons of Power: The Predator's Bracers
    [8063] = {62, "Raid"}, -- Paragons of Power: The Madcap's Bracers
    [8064] = {62, "Raid"}, -- Paragons of Power: The Haruspex's Belt
    [8065] = {62, "Raid"}, -- Paragons of Power: The Haruspex's Tunic
    [8066] = {62, "Raid"}, -- Paragons of Power: The Predator's Belt
    [8067] = {62, "Raid"}, -- Paragons of Power: The Predator's Mantle
    [8068] = {62, "Raid"}, -- Paragons of Power: The Illusionist's Mantle
    [8069] = {62, "Raid"}, -- Paragons of Power: The Illusionist's Robes
    [8070] = {62, "Raid"}, -- Paragons of Power: The Confessor's Bindings
    [8071] = {62, "Raid"}, -- Paragons of Power: The Confessor's Mantle
    [8072] = {62, "Raid"}, -- Paragons of Power: The Madcap's Mantle
    [8073] = {62, "Raid"}, -- Paragons of Power: The Madcap's Tunic
    [8074] = {62, "Raid"}, -- Paragons of Power: The Augur's Belt
    [8075] = {62, "Raid"}, -- Paragons of Power: The Augur's Hauberk
    [8076] = {62, "Raid"}, -- Paragons of Power: The Demoniac's Mantle
    [8077] = {62, "Raid"}, -- Paragons of Power: The Demoniac's Robes
    [8078] = {62, "Raid"}, -- Paragons of Power: The Vindicator's Belt
    [8079] = {62, "Raid"}, -- Paragons of Power: The Vindicator's Breastplate
    [8080] = {41, "PvP"}, -- Arathi Basin Resources!
    [8081] = {41, "PvP"}, -- More Resource Crates
    [8101] = {62, "Raid"}, -- The Pebble of Kajaro
    [8102] = {62, "Raid"}, -- The Pebble of Kajaro
    [8103] = {62, "Raid"}, -- The Pebble of Kajaro
    [8104] = {62, "Raid"}, -- The Jewel of Kajaro
    [8105] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8106] = {62, "Raid"}, -- Kezan's Taint
    [8107] = {62, "Raid"}, -- Kezan's Taint
    [8108] = {62, "Raid"}, -- Kezan's Taint
    [8109] = {62, "Raid"}, -- Kezan's Unstoppable Taint
    [8110] = {62, "Raid"}, -- Enchanted South Seas Kelp
    [8111] = {62, "Raid"}, -- Enchanted South Seas Kelp
    [8112] = {62, "Raid"}, -- Enchanted South Seas Kelp
    [8113] = {62, "Raid"}, -- Pristine Enchanted South Seas Kelp
    [8114] = {41, "PvP"}, -- Control Four Bases
    [8115] = {41, "PvP"}, -- Control Five Bases
    [8116] = {62, "Raid"}, -- Vision of Voodress
    [8117] = {62, "Raid"}, -- Vision of Voodress
    [8118] = {62, "Raid"}, -- Vision of Voodress
    [8119] = {62, "Raid"}, -- The Unmarred Vision of Voodress
    [8120] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8121] = {41, "PvP"}, -- Take Four Bases
    [8122] = {41, "PvP"}, -- Take Five Bases
    [8123] = {41, "PvP"}, -- Cut Arathor Supply Lines
    [8124] = {41, "PvP"}, -- More Resource Crates
    [8141] = {62, "Raid"}, -- Zandalarian Shadow Talisman
    [8142] = {62, "Raid"}, -- Zandalarian Shadow Talisman
    [8143] = {62, "Raid"}, -- Zandalarian Shadow Talisman
    [8144] = {62, "Raid"}, -- Zandalarian Shadow Mastery Talisman
    [8145] = {62, "Raid"}, -- The Maelstrom's Tendril
    [8146] = {62, "Raid"}, -- The Maelstrom's Tendril
    [8147] = {62, "Raid"}, -- The Maelstrom's Tendril
    [8148] = {62, "Raid"}, -- Maelstrom's Wrath
    [8154] = {41, "PvP"}, -- Arathi Basin Resources!
    [8155] = {41, "PvP"}, -- Arathi Basin Resources!
    [8156] = {41, "PvP"}, -- Arathi Basin Resources!
    [8157] = {41, "PvP"}, -- More Resource Crates
    [8158] = {41, "PvP"}, -- More Resource Crates
    [8159] = {41, "PvP"}, -- More Resource Crates
    [8160] = {41, "PvP"}, -- Cut Arathor Supply Lines
    [8161] = {41, "PvP"}, -- Cut Arathor Supply Lines
    [8162] = {41, "PvP"}, -- Cut Arathor Supply Lines
    [8163] = {41, "PvP"}, -- More Resource Crates
    [8164] = {41, "PvP"}, -- More Resource Crates
    [8165] = {41, "PvP"}, -- More Resource Crates
    [8166] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8167] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8168] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8169] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8170] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8171] = {41, "PvP"}, -- The Battle for Arathi Basin!
    [8181] = {62, "Raid"}, -- Confront Yeh'kinya
    [8182] = {62, "Raid"}, -- The Hand of Rastakhan
    [8184] = {62, "Raid"}, -- Presence of Might
    [8185] = {62, "Raid"}, -- Syncretist's Sigil
    [8186] = {62, "Raid"}, -- Death's Embrace
    [8187] = {62, "Raid"}, -- Falcon's Call
    [8188] = {62, "Raid"}, -- Vodouisant's Vigilant Embrace
    [8189] = {62, "Raid"}, -- Presence of Sight
    [8190] = {62, "Raid"}, -- Hoodoo Hex
    [8191] = {62, "Raid"}, -- Prophetic Aura
    [8192] = {62, "Raid"}, -- Animist's Caress
    [8201] = {62, "Raid"}, -- A Collection of Heads
    [8227] = {62, "Raid"}, -- Nat's Measuring Tape
    [8232] = {81, "Dungeon"}, -- The Green Drake
    [8236] = {81, "Dungeon"}, -- The Azure Key
    [8253] = {81, "Dungeon"}, -- Destroy Morphaz
    [8257] = {81, "Dungeon"}, -- Blood of Morphaz
    [8258] = {81, "Dungeon"}, -- The Darkreaver Menace
    [8260] = {41, "PvP"}, -- Arathor Basic Care Package
    [8261] = {41, "PvP"}, -- Arathor Standard Care Package
    [8262] = {41, "PvP"}, -- Arathor Advanced Care Package
    [8263] = {41, "PvP"}, -- Defiler's Basic Care Package
    [8264] = {41, "PvP"}, -- Defiler's Standard Care Package
    [8265] = {41, "PvP"}, -- Defiler's Advanced Care Package
    [8266] = {41, "PvP"}, -- Ribbons of Sacrifice
    [8267] = {41, "PvP"}, -- Ribbons of Sacrifice
    [8268] = {41, "PvP"}, -- Ribbons of Sacrifice
    [8269] = {41, "PvP"}, -- Ribbons of Sacrifice
    [8271] = {41, "PvP"}, -- Hero of the Stormpike
    [8272] = {41, "PvP"}, -- Hero of the Frostwolf
    [8283] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted - Deathclasp, Terror of the Sands
    [8288] = {62, "Raid"}, -- Only One May Rise
    [8289] = {41, "PvP"}, -- Talismans of Merit
    [8290] = {41, "PvP"}, -- Vanquish the Invaders
    [8291] = {41, "PvP"}, -- Vanquish the Invaders!
    [8292] = {41, "PvP"}, -- Talismans of Merit
    [8293] = {41, "PvP"}, -- Mark of Honor
    [8294] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [8295] = {41, "PvP"}, -- Quell the Silverwing Usurpers
    [8296] = {41, "PvP"}, -- Mark of Honor
    [8297] = {41, "PvP"}, -- Arathi Basin Resources!
    [8298] = {41, "PvP"}, -- More Resource Crates
    [8299] = {41, "PvP"}, -- Cut Arathor Supply Lines
    [8300] = {41, "PvP"}, -- More Resource Crates
    [8301] = Questie.IsEra and {1, "Elite"} or nil, -- The Path of the Righteous
    [8302] = Questie.IsEra and {1, "Elite"} or nil, -- The Hand of the Righteous
    [8304] = Questie.IsEra and {1, "Elite"} or nil, -- Dearest Natalia
    [8306] = Questie.IsEra and {1, "Elite"} or nil, -- Into The Maw of Madness
    [8308] = Questie.IsEra and {1, "Elite"} or nil, -- Brann Bronzebeard's Lost Letter
    [8309] = Questie.IsEra and {1, "Elite"} or nil, -- Glyph Chasing
    [8310] = Questie.IsEra and {1, "Elite"} or nil, -- Breaking the Code
    [8314] = Questie.IsEra and {1, "Elite"} or nil, -- Unraveling the Mystery
    [8315] = Questie.IsEra and {62, "Raid"} or {1, "Elite"}, -- The Calling
    [8316] = {62, "Raid"}, -- Armaments of War
    [8322] = {41, "PvP"}, -- Rotten Eggs
    [8331] = Questie.IsEra and {1, "Elite"} or nil, -- Aurel Goldleaf
    [8332] = Questie.IsEra and {1, "Elite"} or nil, -- Dukes of the Council
    [8341] = {1, "Elite"}, -- Lords of the Council
    [8348] = {1, "Elite"}, -- Signet of the Dukes
    [8349] = Questie.IsEra and {1, "Elite"} or nil, -- Bor Wildmane
    [8351] = {62, "Raid"}, -- Bor Wishes to Speak
    [8352] = {62, "Raid"}, -- Scepter of the Council
    [8361] = Questie.IsEra and {1, "Elite"} or nil, -- Abyssal Contacts
    [8362] = Questie.IsEra and {1, "Elite"} or nil, -- Abyssal Crests
    [8363] = {1, "Elite"}, -- Abyssal Signets
    [8364] = {62, "Raid"}, -- Abyssal Scepters
    [8367] = {41, "PvP"}, -- For Great Honor
    [8368] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8369] = {41, "PvP"}, -- Invaders of Alterac Valley
    [8370] = {41, "PvP"}, -- Conquering Arathi Basin
    [8371] = {41, "PvP"}, -- Concerted Efforts
    [8372] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8373] = {41, "PvP"}, -- The Power of Pine
    [8374] = {41, "PvP"}, -- Claiming Arathi Basin
    [8375] = {41, "PvP"}, -- Remember Alterac Valley!
    [8376] = {62, "Raid"}, -- Armaments of War
    [8377] = {62, "Raid"}, -- Armaments of War
    [8378] = {62, "Raid"}, -- Armaments of War
    [8379] = {62, "Raid"}, -- Armaments of War
    [8380] = {62, "Raid"}, -- Armaments of War
    [8381] = {62, "Raid"}, -- Armaments of War
    [8382] = {62, "Raid"}, -- Armaments of War
    [8383] = {41, "PvP"}, -- Remember Alterac Valley!
    [8384] = {41, "PvP"}, -- Claiming Arathi Basin
    [8385] = {41, "PvP"}, -- Concerted Efforts
    [8386] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8387] = {41, "PvP"}, -- Invaders of Alterac Valley
    [8388] = {41, "PvP"}, -- For Great Honor
    [8389] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8390] = {41, "PvP"}, -- Conquering Arathi Basin
    [8391] = {41, "PvP"}, -- Claiming Arathi Basin
    [8392] = {41, "PvP"}, -- Claiming Arathi Basin
    [8393] = {41, "PvP"}, -- Claiming Arathi Basin
    [8394] = {41, "PvP"}, -- Claiming Arathi Basin
    [8395] = {41, "PvP"}, -- Claiming Arathi Basin
    [8396] = {41, "PvP"}, -- Claiming Arathi Basin
    [8397] = {41, "PvP"}, -- Claiming Arathi Basin
    [8398] = {41, "PvP"}, -- Claiming Arathi Basin
    [8399] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8400] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8401] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8402] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8403] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8404] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8405] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8406] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8407] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8408] = {41, "PvP"}, -- Fight for Warsong Gulch
    [8409] = {41, "PvP"}, -- Ruined Kegs
    [8413] = {81, "Dungeon"}, -- Da Voodoo
    [8418] = {81, "Dungeon"}, -- Forging the Mightstone
    [8422] = {81, "Dungeon"}, -- Trolls of a Feather
    [8425] = {81, "Dungeon"}, -- Voodoo Feathers
    [8426] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8427] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8428] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8429] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8430] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8431] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8432] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8433] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8434] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8435] = {41, "PvP"}, -- Battle of Warsong Gulch
    [8436] = {41, "PvP"}, -- Conquering Arathi Basin
    [8437] = {41, "PvP"}, -- Conquering Arathi Basin
    [8438] = {41, "PvP"}, -- Conquering Arathi Basin
    [8439] = {41, "PvP"}, -- Conquering Arathi Basin
    [8440] = {41, "PvP"}, -- Conquering Arathi Basin
    [8441] = {41, "PvP"}, -- Conquering Arathi Basin
    [8442] = {41, "PvP"}, -- Conquering Arathi Basin
    [8443] = {41, "PvP"}, -- Conquering Arathi Basin
    [8481] = {1, "Elite"}, -- The Root of All Evil
    [8498] = Questie.IsEra and {1, "Elite"} or nil, -- Twilight Battle Orders
    [8501] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Ashi Stingers
    [8502] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Ashi Workers
    [8507] = Questie.IsEra and {1, "Elite"} or nil, -- Field Duty
    [8534] = Questie.IsEra and {1, "Elite"} or nil, -- Hive'Zora Scout Report
    [8535] = Questie.IsEra and {1, "Elite"} or nil, -- Hoary Templar
    [8536] = Questie.IsEra and {1, "Elite"} or nil, -- Earthen Templar
    [8537] = Questie.IsEra and {1, "Elite"} or nil, -- Crimson Templar
    [8538] = {1, "Elite"}, -- The Four Dukes
    [8539] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Zora Hive Sisters
    [8544] = {62, "Raid"}, -- Conqueror's Spaulders
    [8551] = {1, "Elite"}, -- The Captain's Chest
    [8554] = {1, "Elite"}, -- Facing Negolash
    [8556] = {62, "Raid"}, -- Signet of Unyielding Strength
    [8557] = {62, "Raid"}, -- Drape of Unyielding Strength
    [8558] = {62, "Raid"}, -- Sickle of Unyielding Strength
    [8559] = {62, "Raid"}, -- Conqueror's Greaves
    [8560] = {62, "Raid"}, -- Conqueror's Legguards
    [8561] = {62, "Raid"}, -- Conqueror's Crown
    [8562] = {62, "Raid"}, -- Conqueror's Breastplate
    [8578] = {62, "Raid"}, -- Scrying Goggles? No Problem!
    [8579] = {62, "Raid"}, -- Mortal Champions
    [8585] = {62, "Raid"}, -- The Isle of Dread!
    [8592] = {62, "Raid"}, -- Tiara of the Oracle
    [8593] = {62, "Raid"}, -- Trousers of the Oracle
    [8594] = {62, "Raid"}, -- Mantle of the Oracle
    [8595] = {62, "Raid"}, -- Mortal Champions
    [8596] = {62, "Raid"}, -- Footwraps of the Oracle
    [8602] = {62, "Raid"}, -- Stormcaller's Pauldrons
    [8603] = {62, "Raid"}, -- Vestments of the Oracle
    [8606] = {1, "Elite"}, -- Decoy!
    [8620] = {62, "Raid"}, -- The Only Prescription
    [8621] = {62, "Raid"}, -- Stormcaller's Footguards
    [8622] = {62, "Raid"}, -- Stormcaller's Hauberk
    [8623] = {62, "Raid"}, -- Stormcaller's Diadem
    [8624] = {62, "Raid"}, -- Stormcaller's Leggings
    [8625] = {62, "Raid"}, -- Enigma Shoulderpads
    [8626] = {62, "Raid"}, -- Striker's Footguards
    [8627] = {62, "Raid"}, -- Avenger's Breastplate
    [8628] = {62, "Raid"}, -- Avenger's Crown
    [8629] = {62, "Raid"}, -- Avenger's Legguards
    [8630] = {62, "Raid"}, -- Avenger's Pauldrons
    [8631] = {62, "Raid"}, -- Enigma Leggings
    [8632] = {62, "Raid"}, -- Enigma Circlet
    [8633] = {62, "Raid"}, -- Enigma Robes
    [8634] = {62, "Raid"}, -- Enigma Boots
    [8637] = {62, "Raid"}, -- Deathdealer's Boots
    [8638] = {62, "Raid"}, -- Deathdealer's Vest
    [8639] = {62, "Raid"}, -- Deathdealer's Helm
    [8640] = {62, "Raid"}, -- Deathdealer's Leggings
    [8641] = {62, "Raid"}, -- Deathdealer's Spaulders
    [8655] = {62, "Raid"}, -- Avenger's Greaves
    [8656] = {62, "Raid"}, -- Striker's Hauberk
    [8657] = {62, "Raid"}, -- Striker's Diadem
    [8658] = {62, "Raid"}, -- Striker's Leggings
    [8659] = {62, "Raid"}, -- Striker's Pauldrons
    [8660] = {62, "Raid"}, -- Doomcaller's Footwraps
    [8661] = {62, "Raid"}, -- Doomcaller's Robes
    [8662] = {62, "Raid"}, -- Doomcaller's Circlet
    [8663] = {62, "Raid"}, -- Doomcaller's Trousers
    [8664] = {62, "Raid"}, -- Doomcaller's Mantle
    [8665] = {62, "Raid"}, -- Genesis Boots
    [8666] = {62, "Raid"}, -- Genesis Vest
    [8667] = {62, "Raid"}, -- Genesis Helm
    [8668] = {62, "Raid"}, -- Genesis Trousers
    [8669] = {62, "Raid"}, -- Genesis Shoulderpads
    [8687] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Zora Tunnelers
    [8689] = {62, "Raid"}, -- Shroud of Infinite Wisdom
    [8690] = {62, "Raid"}, -- Cloak of the Gathering Storm
    [8691] = {62, "Raid"}, -- Drape of Vaulted Secrets
    [8692] = {62, "Raid"}, -- Cloak of Unending Life
    [8693] = {62, "Raid"}, -- Cloak of Veiled Shadows
    [8694] = {62, "Raid"}, -- Shroud of Unspoken Names
    [8695] = {62, "Raid"}, -- Cape of Eternal Justice
    [8696] = {62, "Raid"}, -- Cloak of the Unseen Path
    [8697] = {62, "Raid"}, -- Ring of Infinite Wisdom
    [8698] = {62, "Raid"}, -- Ring of the Gathering Storm
    [8699] = {62, "Raid"}, -- Band of Vaulted Secrets
    [8700] = {62, "Raid"}, -- Band of Unending Life
    [8701] = {62, "Raid"}, -- Band of Veiled Shadows
    [8702] = {62, "Raid"}, -- Ring of Unspoken Names
    [8703] = {62, "Raid"}, -- Ring of Eternal Justice
    [8704] = {62, "Raid"}, -- Signet of the Unseen Path
    [8705] = {62, "Raid"}, -- Gavel of Infinite Wisdom
    [8706] = {62, "Raid"}, -- Hammer of the Gathering Storm
    [8707] = {62, "Raid"}, -- Blade of Vaulted Secrets
    [8708] = {62, "Raid"}, -- Mace of Unending Life
    [8709] = {62, "Raid"}, -- Dagger of Veiled Shadows
    [8710] = {62, "Raid"}, -- Kris of Unspoken Names
    [8711] = {62, "Raid"}, -- Blade of Eternal Justice
    [8712] = {62, "Raid"}, -- Scythe of the Unseen Path
    [8729] = {62, "Raid"}, -- The Wrath of Neptulon
    [8730] = {62, "Raid"}, -- Nefarius's Corruption
    [8731] = Questie.IsEra and {1, "Elite"} or nil, -- Field Duty
    [8735] = {62, "Raid"}, -- The Nightmare's Corruption
    [8736] = {62, "Raid"}, -- The Nightmare Manifests
    [8737] = Questie.IsEra and {1, "Elite"} or nil, -- Azure Templar
    [8738] = Questie.IsEra and {1, "Elite"} or nil, -- Hive'Regal Scout Report
    [8739] = Questie.IsEra and {1, "Elite"} or nil, -- Hive'Ashi Scout Report
    [8740] = Questie.IsEra and {1, "Elite"} or nil, -- Twilight Marauders
    [8743] = {82, "World Event"}, -- Bang a Gong!
    [8770] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Ashi Defenders
    [8771] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Ashi Sandstalkers
    [8772] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Zora Waywatchers
    [8773] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Zora Reavers
    [8774] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Regal Ambushers
    [8775] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Regal Spitfires
    [8776] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Regal Slavemakers
    [8777] = Questie.IsEra and {1, "Elite"} or nil, -- Target: Hive'Regal Burrowers
    [8789] = {62, "Raid"}, -- Imperial Qiraji Armaments
    [8790] = {62, "Raid"}, -- Imperial Qiraji Regalia
    [8791] = {62, "Raid"}, -- The Fall of Ossirian
    [8829] = {1, "Elite"}, -- The Ultimate Deception
    [8868] = {62, "Raid"}, -- Elune's Blessing
    [8905] = {81, "Dungeon"}, -- An Earnest Proposition
    [8906] = {81, "Dungeon"}, -- An Earnest Proposition
    [8907] = {81, "Dungeon"}, -- An Earnest Proposition
    [8908] = {81, "Dungeon"}, -- An Earnest Proposition
    [8909] = {81, "Dungeon"}, -- An Earnest Proposition
    [8910] = {81, "Dungeon"}, -- An Earnest Proposition
    [8911] = {81, "Dungeon"}, -- An Earnest Proposition
    [8912] = {81, "Dungeon"}, -- An Earnest Proposition
    [8913] = {81, "Dungeon"}, -- An Earnest Proposition
    [8914] = {81, "Dungeon"}, -- An Earnest Proposition
    [8915] = {81, "Dungeon"}, -- An Earnest Proposition
    [8916] = {81, "Dungeon"}, -- An Earnest Proposition
    [8917] = {81, "Dungeon"}, -- An Earnest Proposition
    [8918] = {81, "Dungeon"}, -- An Earnest Proposition
    [8919] = {81, "Dungeon"}, -- An Earnest Proposition
    [8920] = {81, "Dungeon"}, -- An Earnest Proposition
    [8926] = {81, "Dungeon"}, -- Just Compensation
    [8927] = {81, "Dungeon"}, -- Just Compensation
    [8928] = {1, "Elite"}, -- A Shifty Merchant
    [8931] = {81, "Dungeon"}, -- Just Compensation
    [8932] = {81, "Dungeon"}, -- Just Compensation
    [8933] = {81, "Dungeon"}, -- Just Compensation
    [8934] = {81, "Dungeon"}, -- Just Compensation
    [8935] = {81, "Dungeon"}, -- Just Compensation
    [8936] = {81, "Dungeon"}, -- Just Compensation
    [8937] = {81, "Dungeon"}, -- Just Compensation
    [8938] = {81, "Dungeon"}, -- Just Compensation
    [8939] = {81, "Dungeon"}, -- Just Compensation
    [8940] = {81, "Dungeon"}, -- Just Compensation
    [8941] = {81, "Dungeon"}, -- Just Compensation
    [8942] = {81, "Dungeon"}, -- Just Compensation
    [8943] = {81, "Dungeon"}, -- Just Compensation
    [8944] = {81, "Dungeon"}, -- Just Compensation
    [8945] = {81, "Dungeon"}, -- Dead Man's Plea
    [8948] = {81, "Dungeon"}, -- Anthion's Old Friend
    [8949] = {81, "Dungeon"}, -- Falrin's Vendetta
    [8950] = {81, "Dungeon"}, -- The Instigator's Enchantment
    [8951] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8952] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8953] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8954] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8955] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8956] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8957] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8958] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8959] = {81, "Dungeon"}, -- Anthion's Parting Words
    [8961] = {62, "Raid"}, -- Three Kings of Flame
    [8962] = {1, "Elite"}, -- Components of Importance
    [8963] = {1, "Elite"}, -- Components of Importance
    [8964] = {1, "Elite"}, -- Components of Importance
    [8965] = {1, "Elite"}, -- Components of Importance
    [8966] = {81, "Dungeon"}, -- The Left Piece of Lord Valthalak's Amulet
    [8967] = {81, "Dungeon"}, -- The Left Piece of Lord Valthalak's Amulet
    [8968] = {81, "Dungeon"}, -- The Left Piece of Lord Valthalak's Amulet
    [8969] = {81, "Dungeon"}, -- The Left Piece of Lord Valthalak's Amulet
    [8970] = {1, "Elite"}, -- I See Alcaz Island In Your Future...
    [8985] = {1, "Elite"}, -- More Components of Importance
    [8986] = {1, "Elite"}, -- More Components of Importance
    [8987] = {1, "Elite"}, -- More Components of Importance
    [8988] = {1, "Elite"}, -- More Components of Importance
    [8989] = {81, "Dungeon"}, -- The Right Piece of Lord Valthalak's Amulet
    [8990] = {81, "Dungeon"}, -- The Right Piece of Lord Valthalak's Amulet
    [8991] = {81, "Dungeon"}, -- The Right Piece of Lord Valthalak's Amulet
    [8992] = {81, "Dungeon"}, -- The Right Piece of Lord Valthalak's Amulet
    [8994] = {62, "Raid"}, -- Final Preparations
    [8995] = {62, "Raid"}, -- Mea Culpa, Lord Valthalak
    [8999] = {81, "Dungeon"}, -- Saving the Best for Last
    [9000] = {81, "Dungeon"}, -- Saving the Best for Last
    [9001] = {81, "Dungeon"}, -- Saving the Best for Last
    [9002] = {81, "Dungeon"}, -- Saving the Best for Last
    [9003] = {81, "Dungeon"}, -- Saving the Best for Last
    [9004] = {81, "Dungeon"}, -- Saving the Best for Last
    [9005] = {81, "Dungeon"}, -- Saving the Best for Last
    [9006] = {81, "Dungeon"}, -- Saving the Best for Last
    [9007] = {81, "Dungeon"}, -- Saving the Best for Last
    [9008] = {81, "Dungeon"}, -- Saving the Best for Last
    [9009] = {81, "Dungeon"}, -- Saving the Best for Last
    [9010] = {81, "Dungeon"}, -- Saving the Best for Last
    [9011] = {81, "Dungeon"}, -- Saving the Best for Last
    [9012] = {81, "Dungeon"}, -- Saving the Best for Last
    [9013] = {81, "Dungeon"}, -- Saving the Best for Last
    [9014] = {81, "Dungeon"}, -- Saving the Best for Last
    [9015] = {81, "Dungeon"}, -- The Challenge
    [9016] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9017] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9018] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9019] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9020] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9021] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9022] = {81, "Dungeon"}, -- Anthion's Parting Words
    [9023] = {62, "Raid"}, -- The Perfect Poison
    [9033] = {62, "Raid"}, -- Echoes of War
    [9034] = {62, "Raid"}, -- Dreadnaught Breastplate
    [9036] = {62, "Raid"}, -- Dreadnaught Legplates
    [9037] = {62, "Raid"}, -- Dreadnaught Helmet
    [9038] = {62, "Raid"}, -- Dreadnaught Pauldrons
    [9039] = {62, "Raid"}, -- Dreadnaught Sabatons
    [9040] = {62, "Raid"}, -- Dreadnaught Gauntlets
    [9041] = {62, "Raid"}, -- Dreadnaught Waistguard
    [9042] = {62, "Raid"}, -- Dreadnaught Bracers
    [9043] = {62, "Raid"}, -- Redemption Tunic
    [9044] = {62, "Raid"}, -- Redemption Legguards
    [9045] = {62, "Raid"}, -- Redemption Headpiece
    [9046] = {62, "Raid"}, -- Redemption Spaulders
    [9047] = {62, "Raid"}, -- Redemption Boots
    [9048] = {62, "Raid"}, -- Redemption Handguards
    [9049] = {62, "Raid"}, -- Redemption Girdle
    [9050] = {62, "Raid"}, -- Redemption Wristguards
    [9051] = {1, "Elite"}, -- Toxic Test
    [9053] = {81, "Dungeon"}, -- A Better Ingredient
    [9054] = {62, "Raid"}, -- Cryptstalker Tunic
    [9055] = {62, "Raid"}, -- Cryptstalker Legguards
    [9056] = {62, "Raid"}, -- Cryptstalker Headpiece
    [9057] = {62, "Raid"}, -- Cryptstalker Spaulders
    [9058] = {62, "Raid"}, -- Cryptstalker Boots
    [9059] = {62, "Raid"}, -- Cryptstalker Handguards
    [9060] = {62, "Raid"}, -- Cryptstalker Girdle
    [9061] = {62, "Raid"}, -- Cryptstalker Wristguards
    [9068] = {62, "Raid"}, -- Earthshatter Tunic
    [9069] = {62, "Raid"}, -- Earthshatter Legguards
    [9070] = {62, "Raid"}, -- Earthshatter Headpiece
    [9071] = {62, "Raid"}, -- Earthshatter Spaulders
    [9072] = {62, "Raid"}, -- Earthshatter Boots
    [9073] = {62, "Raid"}, -- Earthshatter Handguards
    [9074] = {62, "Raid"}, -- Earthshatter Girdle
    [9075] = {62, "Raid"}, -- Earthshatter Wristguards
    [9077] = {62, "Raid"}, -- Bonescythe Breastplate
    [9078] = {62, "Raid"}, -- Bonescythe Legplates
    [9079] = {62, "Raid"}, -- Bonescythe Helmet
    [9080] = {62, "Raid"}, -- Bonescythe Pauldrons
    [9081] = {62, "Raid"}, -- Bonescythe Sabatons
    [9082] = {62, "Raid"}, -- Bonescythe Gauntlets
    [9083] = {62, "Raid"}, -- Bonescythe Waistguard
    [9084] = {62, "Raid"}, -- Bonescythe Bracers
    [9085] = (Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Shadows of Doom
    [9086] = {62, "Raid"}, -- Dreamwalker Tunic
    [9087] = {62, "Raid"}, -- Dreamwalker Legguards
    [9088] = {62, "Raid"}, -- Dreamwalker Headpiece
    [9089] = {62, "Raid"}, -- Dreamwalker Spaulders
    [9090] = {62, "Raid"}, -- Dreamwalker Boots
    [9091] = {62, "Raid"}, -- Dreamwalker Handguards
    [9092] = {62, "Raid"}, -- Dreamwalker Girdle
    [9093] = {62, "Raid"}, -- Dreamwalker Wristguards
    [9095] = {62, "Raid"}, -- Frostfire Robe
    [9096] = {62, "Raid"}, -- Frostfire Leggings
    [9097] = {62, "Raid"}, -- Frostfire Circlet
    [9098] = {62, "Raid"}, -- Frostfire Shoulderpads
    [9099] = {62, "Raid"}, -- Frostfire Sandals
    [9100] = {62, "Raid"}, -- Frostfire Gloves
    [9101] = {62, "Raid"}, -- Frostfire Belt
    [9102] = {62, "Raid"}, -- Frostfire Bindings
    [9103] = {62, "Raid"}, -- Plagueheart Robe
    [9104] = {62, "Raid"}, -- Plagueheart Leggings
    [9105] = {62, "Raid"}, -- Plagueheart Circlet
    [9106] = {62, "Raid"}, -- Plagueheart Shoulderpads
    [9107] = {62, "Raid"}, -- Plagueheart Sandals
    [9108] = {62, "Raid"}, -- Plagueheart Gloves
    [9109] = {62, "Raid"}, -- Plagueheart Belt
    [9110] = {62, "Raid"}, -- Plagueheart Bindings
    [9111] = {62, "Raid"}, -- Robe of Faith
    [9112] = {62, "Raid"}, -- Leggings of Faith
    [9113] = {62, "Raid"}, -- Circlet of Faith
    [9114] = {62, "Raid"}, -- Shoulderpads of Faith
    [9115] = {62, "Raid"}, -- Sandals of Faith
    [9116] = {62, "Raid"}, -- Gloves of Faith
    [9117] = {62, "Raid"}, -- Belt of Faith
    [9118] = {62, "Raid"}, -- Bindings of Faith
    [9156] = {1, "Elite"}, -- Wanted: Knucklerot and Luzran
    [9167] = {1, "Elite"}, -- The Traitor's Destruction
    [9208] = {62, "Raid"}, -- The Savage Guard - Arcanum of Protection
    [9209] = {62, "Raid"}, -- The Savage Guard - Arcanum of Rapidity
    [9210] = {62, "Raid"}, -- The Savage Guard - Arcanum of Focus
    [9215] = {1, "Elite"}, -- Bring Me Kel'gash's Head!
    [9229] = {62, "Raid"}, -- The Fate of Ramaladni
    [9230] = {62, "Raid"}, -- Ramaladni's Icy Grasp
    [9232] = {62, "Raid"}, -- The Only Song I Know...
    [9233] = {62, "Raid"}, -- Omarion's Handbook
    [9234] = {62, "Raid"}, -- Icebane Gauntlets
    [9235] = {62, "Raid"}, -- Icebane Bracers
    [9236] = {62, "Raid"}, -- Icebane Breastplate
    [9237] = {62, "Raid"}, -- Glacial Cloak
    [9238] = {62, "Raid"}, -- Glacial Wrists
    [9239] = {62, "Raid"}, -- Glacial Gloves
    [9240] = {62, "Raid"}, -- Glacial Vest
    [9241] = {62, "Raid"}, -- Polar Bracers
    [9242] = {62, "Raid"}, -- Polar Gloves
    [9243] = {62, "Raid"}, -- Polar Tunic
    [9244] = {62, "Raid"}, -- Icy Scale Bracers
    [9245] = {62, "Raid"}, -- Icy Scale Gauntlets
    [9246] = {62, "Raid"}, -- Icy Scale Breastplate
    [9250] = {62, "Raid"}, -- Frame of Atiesh
    [9251] = {62, "Raid"}, -- Atiesh, the Befouled Greatstaff
    [9257] = {81, "Dungeon"}, -- Atiesh, Greatstaff of the Guardian
    [9269] = {81, "Dungeon"}, -- Atiesh, Greatstaff of the Guardian
    [9270] = {81, "Dungeon"}, -- Atiesh, Greatstaff of the Guardian
    [9271] = {81, "Dungeon"}, -- Atiesh, Greatstaff of the Guardian
    [9315] = {1, "Elite"}, -- Anok'suten
    [9375] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {"Elite"} or {84, "Escort"}, -- The Road to Falcon Watch
    [9419] = {41, "PvP"}, -- Scouring the Desert
    [9422] = {41, "PvP"}, -- Scouring the Desert
    [9444] = {41, "PvP"}, -- Defiling Uther's Tomb
    [9446] = {1, "Elite"}, -- Tomb of the Lightbringer
    [9466] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted: Blacktalon the Savage
    [9490] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Rock Flayer Matriarch
    [9492] = {81, "Dungeon"}, -- Turning the Tide
    [9493] = {81, "Dungeon"}, -- Pride of the Fel Horde
    [9494] = {81, "Dungeon"}, -- Fel Embers
    [9495] = {81, "Dungeon"}, -- The Will of the Warchief
    [9496] = {81, "Dungeon"}, -- Pride of the Fel Horde
    [9521] = {41, "PvP"}, -- Report from the Northern Front
    [9524] = {85, "Heroic"}, -- Imprisoned in the Citadel
    [9525] = {85, "Heroic"}, -- Imprisoned in the Citadel
    [9528] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- A Cry For Help
    [9664] = {41, "PvP"}, -- Establishing New Outposts
    [9665] = {41, "PvP"}, -- Bolstering Our Defenses
    [9572] = {81, "Dungeon"}, -- Weaken the Ramparts
    [9575] = {81, "Dungeon"}, -- Weaken the Ramparts
    [9587] = {81, "Dungeon"}, -- Dark Tidings
    [9588] = {81, "Dungeon"}, -- Dark Tidings
    [9589] = {81, "Dungeon"}, -- The Blood is Life
    [9590] = {81, "Dungeon"}, -- The Blood is Life
    [9607] = {81, "Dungeon"}, -- Heart of Rage
    [9608] = {81, "Dungeon"}, -- Heart of Rage
    [9630] = {62, "Raid"}, -- Medivh's Journal
    [9637] = {85, "Heroic"}, -- Kalynna's Request
    [9640] = {62, "Raid"}, -- The Shade of Aran
    [9644] = {62, "Raid"}, -- Nightbane
    [9645] = {62, "Raid"}, -- The Master's Terrace
    [9689] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Razormaw
    [9692] = {81, "Dungeon"}, -- The Path of the Adept
    [9706] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Galaen's Journal - The Fate of Vindicator Saruan
    [9711] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Matis the Cruel
    [9714] = {81, "Dungeon"}, -- Bring Me Another Shrubbery!
    [9715] = {81, "Dungeon"}, -- Bring Me A Shrubbery!
    [9717] = {81, "Dungeon"}, -- Oh, It's On!
    [9719] = {81, "Dungeon"}, -- Stalk the Stalker
    [9723] = {81, "Dungeon"}, -- A Gesture of Commitment
    [9729] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Fhwoor Smash!
    [9730] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Leader of the Darkcrest
    [9735] = {1, "Elite"}, -- True Masters of the Light
    [9737] = {81, "Dungeon"}, -- True Masters of the Light
    [9738] = {81, "Dungeon"}, -- Lost in Action
    [9753] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- What We Know...
    [9756] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- What We Don't Know...
    [9759] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Ending Their World
    [9760] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Vindicator's Rest
    [9761] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Clearing the Way
    [9763] = {81, "Dungeon"}, -- The Warlord's Hideout
    [9765] = {81, "Dungeon"}, -- Preparing for War
    [9817] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Leader of the Bloodscale
    [9831] = {81, "Dungeon"}, -- Entry Into Karazhan
    [9832] = {81, "Dungeon"}, -- The Second and Third Fragments
    [9836] = {81, "Dungeon"}, -- The Master's Touch
    [9840] = {62, "Raid"}, -- Assessing the Situation
    [9843] = {62, "Raid"}, -- Keanna's Log
    [9844] = {62, "Raid"}, -- A Demonic Presence
    [9851] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Clefthoof Mastery
    [9852] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Ultimate Bloodsport
    [9853] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Gurok the Usurper
    [9856] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Windroc Mastery
    [9859] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Talbuk Mastery
    [9868] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Totem of Kar'dash
    [9879] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Totem of Kar'dash
    [9894] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Safeguarding the Watchers
    [9895] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Dying Balance
    [9937] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted: Durn the Hungerer
    [9938] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted: Durn the Hungerer
    [9946] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Cho'war the Pillager
    [9954] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Corki's Ransom
    [9955] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Cho'war the Pillager
    [9962] = {1, "Elite"}, -- The Ring of Blood: Brokentoe
    [9967] = {1, "Elite"}, -- The Ring of Blood: The Blue Brothers
    [9970] = {1, "Elite"}, -- The Ring of Blood: Rokdar the Sundered Lord
    [9972] = {1, "Elite"}, -- The Ring of Blood: Skra'gath
    [9973] = {1, "Elite"}, -- The Ring of Blood: The Warmaul Champion
    [9977] = {1, "Elite"}, -- The Ring of Blood: The Final Challenge
    [9982] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- He Called Himself Altruis...
    [9983] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- He Called Himself Altruis...
    [9991] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Survey the Land
    [9999] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Buying Time
    [10001] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Master Planner
    [10004] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Patience and Understanding
    [10009] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Crackin' Some Skulls
    [10010] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- It's Just That Easy?
    [10011] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Forge Camp: Annihilated
    [10020] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- A Cure for Zahlia
    [10035] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Torgos!
    [10036] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Torgos!
    [10051] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Escape from Firewing Point!
    [10052] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Escape from Firewing Point!
    [10074] = {41, "PvP"}, -- Oshu'gun Crystal Powder
    [10075] = {41, "PvP"}, -- Oshu'gun Crystal Powder
    [10076] = {41, "PvP"}, -- Oshu'gun Crystal Powder
    [10077] = {41, "PvP"}, -- Oshu'gun Crystal Powder
    [10091] = {81, "Dungeon"}, -- The Soul Devices
    [10094] = {81, "Dungeon"}, -- The Codex of Blood
    [10095] = {81, "Dungeon"}, -- Into the Heart of the Labyrinth
    [10097] = {81, "Dungeon"}, -- Brother Against Brother
    [10098] = {81, "Dungeon"}, -- Terokk's Legacy
    [10106] = {41, "PvP"}, -- Hellfire Fortifications
    [10110] = {41, "PvP"}, -- Hellfire Fortifications
    [10111] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Bring Me The Egg!
    [10116] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted: Chieftain Mummaki
    [10117] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Wanted: Chieftain Mummaki
    [10132] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Colossal Menace
    [10134] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Crimson Crystal Clue
    [10136] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Cruel's Intentions
    [10164] = {81, "Dungeon"}, -- Everything Will Be Alright
    [10165] = {81, "Dungeon"}, -- Undercutting the Competition
    [10167] = {81, "Dungeon"}, -- Auchindoun...
    [10168] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- What the Soul Sees
    [10177] = {81, "Dungeon"}, -- Trouble at Auchindoun
    [10178] = {81, "Dungeon"}, -- Find Spy To'gun
    [10191] = {1, "Elite"}, -- Mark V is Alive!
    [10216] = {81, "Dungeon"}, -- Safety Is Job One
    [10218] = {81, "Dungeon"}, -- Someone Else's Hard Work Pays Off
    [10231] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- What Book? I Don't See Any Book.
    [10247] = {1, "Elite"}, -- Doctor Vomisa, Ph.T.
    [10248] = {1, "Elite"}, -- You, Robot
    [10252] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Vision of the Dead
    [10253] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Levixus the Soul Caller
    [10256] = {1, "Elite"}, -- Finding the Keymaster
    [10257] = {81, "Dungeon"}, -- Capturing the Keystone
    [10261] = {1, "Elite"}, -- Wanted: Annihilator Servo!
    [10274] = {1, "Elite"}, -- Securing the Celestial Ridge
    [10276] = {1, "Elite"}, -- Full Triangle
    [10282] = {81, "Dungeon"}, -- Old Hillsbrad
    [10283] = {81, "Dungeon"}, -- Taretha's Diversion
    [10284] = {81, "Dungeon"}, -- Escape from Durnholde
    [10290] = {1, "Elite"}, -- In Search of Farahlite
    [10293] = {1, "Elite"}, -- Hitting the Motherlode
    [10296] = {81, "Dungeon"}, -- The Black Morass
    [10297] = {81, "Dungeon"}, -- The Opening of the Dark Portal
    [10309] = {1, "Elite"}, -- It's a Fel Reaver, But with Heart
    [10310] = {1, "Elite"}, -- Sabotage the Warp-Gate!
    [10320] = {1, "Elite"}, -- Destroy Naberius!
    [10323] = {1, "Elite"}, -- Shutting Down Manaforge Ara
    [10337] = {1, "Elite"}, -- When the Cows Come Home
    [10349] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Earthbinder
    [10351] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Natural Remedies
    [10365] = {1, "Elite"}, -- Shutting Down Manaforge Ara
    [10400] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Overlord
    [10407] = {1, "Elite"}, -- Socrethar's Shadow
    [10408] = {1, "Elite"}, -- Nexus-King Salhadaar
    [10409] = {1, "Elite"}, -- Deathblow to the Legion
    [10439] = {1, "Elite"}, -- Dimensius the All-Devouring
    [10445] = {62, "Raid"}, -- The Vials of Eternity
    [10451] = {1, "Elite"}, -- Escape from Coilskar Cistern
    [10492] = {81, "Dungeon"}, -- An Earnest Proposition
    [10493] = {81, "Dungeon"}, -- An Earnest Proposition
    [10494] = {81, "Dungeon"}, -- Just Compensation
    [10495] = {81, "Dungeon"}, -- Just Compensation
    [10496] = {81, "Dungeon"}, -- Anthion's Parting Words
    [10497] = {81, "Dungeon"}, -- Anthion's Parting Words
    [10498] = {81, "Dungeon"}, -- Saving the Best for Last
    [10499] = {81, "Dungeon"}, -- Saving the Best for Last
    [10507] = {1, "Elite"}, -- Turning Point
    [10508] = {1, "Elite"}, -- A Gift for Voren'thal
    [10518] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Planting the Banner
    [10578] = {1, "Elite"}, -- The Cipher of Damnation - Borak's Charge
    [10588] = {1, "Elite"}, -- The Cipher of Damnation
    [10593] = {81, "Dungeon"}, -- Ancient Evil
    [10626] = {1, "Elite"}, -- Capture the Weapons
    [10627] = {1, "Elite"}, -- Capture the Weapons
    [10634] = {1, "Elite"}, -- Divination: Gorefiend's Armor
    [10636] = {1, "Elite"}, -- Divination: Gorefiend's Truncheon
    [10647] = {1, "Elite"}, -- Wanted: Uvuros, Scourge of Shadowmoon
    [10648] = {1, "Elite"}, -- Wanted: Uvuros, Scourge of Shadowmoon
    [10649] = {81, "Dungeon"}, -- The Book of Fel Names
    [10651] = {1, "Elite"}, -- Varedis Must Be Stopped
    [10665] = {81, "Dungeon"}, -- Fresh from the Mechanar
    [10666] = {81, "Dungeon"}, -- The Lexicon Demonica
    [10667] = {81, "Dungeon"}, -- Underworld Loam
    [10670] = {81, "Dungeon"}, -- Tear of the Earthmother
    [10692] = {1, "Elite"}, -- Varedis Must Be Stopped
    [10701] = {1, "Elite"}, -- Breaking Down Netherock
    [10704] = {81, "Dungeon"}, -- How to Break Into the Arcatraz
    [10705] = {81, "Dungeon"}, -- Seer Udalo
    [10707] = {1, "Elite"}, -- The Ata'mal Terrace
    [10724] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Prisoner of the Bladespire
    [10742] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Showdown
    [10750] = {1, "Elite"}, -- The Path of Conquest
    [10751] = {1, "Elite"}, -- Breaching the Path
    [10758] = {1, "Elite"}, -- Hotter than Hell
    [10764] = {1, "Elite"}, -- Hotter than Hell
    [10765] = {1, "Elite"}, -- When Worlds Collide...
    [10768] = {1, "Elite"}, -- Tabards of the Illidari
    [10769] = {1, "Elite"}, -- Dissension Amongst the Ranks...
    [10772] = {1, "Elite"}, -- The Path of Conquest
    [10773] = {1, "Elite"}, -- Breaching the Path
    [10774] = {1, "Elite"}, -- Blood Elf + Giant = ???
    [10775] = {1, "Elite"}, -- Tabards of the Illidari
    [10776] = {1, "Elite"}, -- Dissension Amongst the Ranks...
    [10781] = {1, "Elite"}, -- Battle of the Crimson Watch
    [10793] = {1, "Elite"}, -- The Journal of Val'zareq: Portends of War
    [10805] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Massacre at Gruul's Lair
    [10806] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Showdown
    [10821] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- You're Fired!
    [10834] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Grillok "Darkeye"
    [10838] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Demoniac Scryer
    [10842] = Questie.IsTBC and {1, "Elite"} or nil, -- The Vengeful Harbinger/Vengeful Souls
    [10858] = {1, "Elite"}, -- Karynaku
    [10866] = {1, "Elite"}, -- Zuluhed the Whacked
    [10872] = {1, "Elite"}, -- Zuluhed the Whacked
    [10876] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Foot of the Citadel
    [10879] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Skettis Offensive
    [10882] = {81, "Dungeon"}, -- Harbinger of Doom
    [10884] = {85, "Heroic"}, -- Trial of the Naaru: Mercy
    [10885] = {85, "Heroic"}, -- Trial of the Naaru: Strength
    [10886] = {85, "Heroic"}, -- Trial of the Naaru: Tenacity
    [10888] = {62, "Raid"}, -- Trial of the Naaru: Magtheridon
    [10897] = {81, "Dungeon"}, -- Master of Potions
    [10898] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Skywing
    [10900] = {62, "Raid"}, -- The Mark of Vashj
    [10901] = {62, "Raid"}, -- The Cudgel of Kar'desh
    [10902] = {81, "Dungeon"}, -- Master of Elixirs
    [10921] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Terokkarantula
    [10922] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Digging Through Bones
    [10923] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Evil Draws Near
    [10929] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Fumping
    [10930] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Big Bone Worm
    [10937] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Drill the Drillmaster
    [10946] = {62, "Raid"}, -- Ruse of the Ashtongue
    [10947] = {62, "Raid"}, -- An Artifact From the Past
    [10957] = {62, "Raid"}, -- Redemption of the Ashtongue
    [10958] = {62, "Raid"}, -- Seek Out the Ashtongue
    [10959] = {62, "Raid"}, -- The Fall of the Betrayer
    [10974] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Stasis Chambers of Bash'ir
    [10975] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Purging the Chambers of Bash'ir
    [10976] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- The Mark of the Nexus-King
    [10977] = {85, "Heroic"}, -- Stasis Chambers of the Mana-Tombs
    [10981] = {85, "Heroic"}, -- Nexus-Prince Shaffar's Personal Chamber
    [10995] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Grulloc Has Two Skulls
    [10996] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Maggoc's Treasure Chest
    [10997] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Even Gronn Have Standards
    [10998] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Grim(oire) Business
    [11000] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Into the Soulgrinder
    [11001] = {85, "Heroic"}, -- Vanquish the Raven God
    [11041] = {1, "Elite"}, -- A Job Unfinished...
    [11059] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- Guardian of the Monument
    [11073] = {1, "Elite"}, -- Terokk's Downfall
    [11078] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- To Rule The Skies
    [11079] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {1, "Elite"} or nil, -- A Fel Whip For Gahk
    [11097] = {1, "Elite"}, -- The Deadliest Trap Ever Laid
    [11101] = {1, "Elite"}, -- The Deadliest Trap Ever Laid
    [11130] = {62, "Raid"}, -- Oooh, Shinies!
    [11132] = {62, "Raid"}, -- Promises, Promises...
    [11164] = {62, "Raid"}, -- Tuskin' Raiders
    [11165] = {62, "Raid"}, -- A Troll Among Trolls
    [11166] = {62, "Raid"}, -- X Marks... Your Doom!
    [11171] = {62, "Raid"}, -- Hex Lord? Hah!
    [11178] = {62, "Raid"}, -- Blood of the Warlord
    [11195] = {62, "Raid"}, -- Playin' With Dolls
    [11196] = (Questie.IsClassic or Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335) and {62, "Raid"} or {81, "Dungeon"}, -- Warlord of the Amani
    [11335] = {41, "PvP"}, -- Call to Arms: Arathi Basin
    [11336] = {41, "PvP"}, -- Call to Arms: Alterac Valley
    [11337] = {41, "PvP"}, -- Call to Arms: Eye of the Storm
    [11338] = {41, "PvP"}, -- Call to Arms: Warsong Gulch
    [11339] = {41, "PvP"}, -- Call to Arms: Arathi Basin
    [11340] = {41, "PvP"}, -- Call to Arms: Alterac Valley
    [11341] = {41, "PvP"}, -- Call to Arms: Eye of the Storm
    [11342] = {41, "PvP"}, -- Call to Arms: Warsong Gulch
    [11354] = {85, "Heroic"}, -- Wanted: Nazan's Riding Crop
    [11362] = {85, "Heroic"}, -- Wanted: Keli'dan's Feathered Stave
    [11363] = {85, "Heroic"}, -- Wanted: Bladefist's Seal
    [11364] = {81, "Dungeon"}, -- Wanted: Wanted: Shattered Hand Centurions
    [11368] = {85, "Heroic"}, -- Wanted: The Heart of Quagmirran
    [11369] = {85, "Heroic"}, -- Wanted: A Black Stalker Egg
    [11370] = {85, "Heroic"}, -- Wanted: The Warlord's Treatise
    [11371] = {81, "Dungeon"}, -- Wanted: Coilfang Myrmidons
    [11372] = {85, "Heroic"}, -- Wanted: The Headfeathers of Ikiss
    [11373] = {85, "Heroic"}, -- Wanted: Shaffar's Wondrous Pendant
    [11374] = {85, "Heroic"}, -- Wanted: The Exarch's Soul Gem
    [11375] = {85, "Heroic"}, -- Wanted: Murmur's Whisper
    [11376] = {81, "Dungeon"}, -- Wanted: Malicious Instructors
    [11378] = {85, "Heroic"}, -- Wanted: The Epoch Hunter's Head
    [11382] = {85, "Heroic"}, -- Wanted: Aeonus's Hourglass
    [11383] = {81, "Dungeon"}, -- Wanted: Rift Lords
    [11384] = {85, "Heroic"}, -- Wanted: A Warp Splinter Clipping
    [11385] = {81, "Dungeon"}, -- Wanted: Sunseeker Channelers
    [11386] = {85, "Heroic"}, -- Wanted: Pathaleon's Projector
    [11387] = {81, "Dungeon"}, -- Wanted: Tempest-Forge Destroyers
    [11388] = {85, "Heroic"}, -- Wanted: The Scroll of Skyriss
    [11389] = {81, "Dungeon"}, -- Wanted: Arcatraz Sentinels
    [11401] = {81, "Dungeon"}, -- Call the Headless Horseman
    [11405] = {81, "Dungeon"}, -- Call the Headless Horseman
    [11488] = {81, "Dungeon"}, -- Magisters' Terrace
    [11490] = {81, "Dungeon"}, -- The Scryer's Scryer
    [11492] = {81, "Dungeon"}, -- Hard to Kill
    [11499] = {85, "Heroic"}, -- Wanted: The Signet Ring of Prince Kael'thas
    [11500] = {81, "Dungeon"}, -- Wanted: Sisters of Torment
    [11502] = {41, "PvP"}, -- In Defense of Halaa
    [11503] = {41, "PvP"}, -- Enemies, Old and New
    [11505] = {41, "PvP"}, -- Spirits of Auchindoun
    [11506] = {41, "PvP"}, -- Spirits of Auchindoun
    [11691] = {81, "Dungeon"}, -- Summon Ahune
    [11885] = {1, "Elite"}, -- Adversarial Blood
    [11955] = {81, "Dungeon"}, -- Ahune, the Frost Lord
    [12062] = {81, "Dungeon"}, -- Insult Coren Direbrew
    [12170] = {41, "PvP"}, -- 
    [12244] = {41, "PvP"}, -- 
    [12268] = {41, "PvP"}, -- 
    [12270] = {41, "PvP"}, -- 
    [12280] = {41, "PvP"}, -- 
    [12284] = {41, "PvP"}, -- 
    [12288] = {41, "PvP"}, -- 
    [12289] = {41, "PvP"}, -- 
    [12296] = {41, "PvP"}, -- 
    [12314] = {41, "PvP"}, -- 
    [12315] = {41, "PvP"}, -- 
    [12316] = {41, "PvP"}, -- 
    [12317] = {41, "PvP"}, -- 
    [12323] = {41, "PvP"}, -- 
    [12324] = {41, "PvP"}, -- 
    [12432] = {41, "PvP"}, -- 
    [12433] = {41, "PvP"}, -- 
    [12434] = {41, "PvP"}, -- 
    [12437] = {41, "PvP"}, -- 
    [12443] = {41, "PvP"}, -- 
    [12446] = {41, "PvP"}, -- 
    [12513] = {81, "Dungeon"}, -- Nice Hat...
    [12515] = {81, "Dungeon"}, -- Nice Hat...
    [13129] = {81, "Dungeon"}, -- Head Games
    [13199] = {41, "PvP"}, -- 
    [13662] = {81, "Dungeon"}, -- Gaining Acceptance
}

-- race bitmask data, for easy access
local VANILLA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

QuestieDB.raceKeys = {
    ALL_ALLIANCE = VANILLA and 77 or 1101,
    ALL_HORDE = VANILLA and 178 or 690,
    NONE = 0,

    HUMAN = 1,
    ORC = 2,
    DWARF = 4,
    NIGHT_ELF = 8,
    UNDEAD = 16,
    TAUREN = 32,
    GNOME = 64,
    TROLL = 128,
    --GOBLIN = 256,
    BLOOD_ELF = 512,
    DRAENEI = 1024
}

-- Combining these with "and" makes the order matter
-- 1 and 2 ~= 2 and 1
QuestieDB.classKeys = {
    ALL_CLASSES = (function()
        if Questie.IsClassic then
            return playerFaction == "Alliance" and 1439 or 1501
        elseif Questie.IsTBC then
            return 1503
        elseif Questie.IsWotlk or QuestieCompat.Is335 then
            return 1535
        else
            print("Unknown expansion for ALL_CLASSES")
            return playerFaction == "Alliance" and 1439 or 1501
        end
    end)(),

    NONE = 0,
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 4,
    ROGUE = 8,
    PRIEST = 16,
    DEATH_KNIGHT = 32,
    SHAMAN = 64,
    MAGE = 128,
    WARLOCK = 256,
    DRUID = 1024
}

QuestieDB.specialFlags = {
    REPEATABLE = 1,
}

_QuestieDB.questCache = {}; -- stores quest objects so they dont need to be regenerated
_QuestieDB.npcCache = {};

---A Memoized table for function Quest:CheckRace
---
---Usage: checkRace[requiredRaces]
---@type table<number, boolean>
local checkRace
---A Memoized table for function Quest:CheckClass
---
---Usage: checkRace[requiredClasses]
---@type table<number, boolean>
local checkClass

---QuestieCorrections.hiddenQuests
local QuestieCorrectionshiddenQuests
---Questie.db.char.hidden
local Questiedbcharhidden

QuestieDB.itemDataOverrides = {}
QuestieDB.npcDataOverrides = {}
QuestieDB.objectDataOverrides = {}
QuestieDB.questDataOverrides = {}

QuestieDB.activeChildQuests = {}


function QuestieDB:Initialize()

    StaticPopupDialogs["QUESTIE_DATABASE_ERROR"] = { -- /run StaticPopup_Show ("QUESTIE_DATABASE_ERROR")
        text = l10n("There was a problem initializing Questie's database. This can usually be fixed by recompiling the database."),
        button1 = l10n("Recompile Database"),
        button2 = l10n("Don't show again"),
        OnAccept = function()
            if Questie.IsSoD then
                Questie.db.global.sod.dbIsCompiled = false
            else
                Questie.db.global.dbIsCompiled = false
            end
            ReloadUI()
        end,
        OnDecline = function()
            Questie.db.profile.disableDatabaseWarnings = true
        end,
        OnShow = function(self)
            self:SetFrameStrata("TOOLTIP")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3
    }

    -- For now we store both, the SoD database and the Era/HC database
    local npcBin, npcPtrs, questBin, questPtrs, objBin, objPtrs, itemBin, itemPtrs
    if Questie.IsSoD then
        npcBin = Questie.db.global.sod.npcBin
        npcPtrs = Questie.db.global.sod.npcPtrs
        questBin = Questie.db.global.sod.questBin
        questPtrs = Questie.db.global.sod.questPtrs
        objBin = Questie.db.global.sod.objBin
        objPtrs = Questie.db.global.sod.objPtrs
        itemBin = Questie.db.global.sod.itemBin
        itemPtrs = Questie.db.global.sod.itemPtrs
    else
        npcBin = Questie.db.global.npcBin
        npcPtrs = Questie.db.global.npcPtrs
        questBin = Questie.db.global.questBin
        questPtrs = Questie.db.global.questPtrs
        objBin = Questie.db.global.objBin
        objPtrs = Questie.db.global.objPtrs
        itemBin = Questie.db.global.itemBin
        itemPtrs = Questie.db.global.itemPtrs
    end

    QuestieDB.QueryNPC = QuestieDBCompiler:GetDBHandle(npcBin, npcPtrs, QuestieDBCompiler:BuildSkipMap(QuestieDB.npcCompilerTypes, QuestieDB.npcCompilerOrder), QuestieDB.npcKeys, QuestieDB.npcDataOverrides)
    QuestieDB.QueryQuest = QuestieDBCompiler:GetDBHandle(questBin, questPtrs, QuestieDBCompiler:BuildSkipMap(QuestieDB.questCompilerTypes, QuestieDB.questCompilerOrder), QuestieDB.questKeys, QuestieDB.questDataOverrides)
    QuestieDB.QueryObject = QuestieDBCompiler:GetDBHandle(objBin, objPtrs, QuestieDBCompiler:BuildSkipMap(QuestieDB.objectCompilerTypes, QuestieDB.objectCompilerOrder), QuestieDB.objectKeys, QuestieDB.objectDataOverrides)
    QuestieDB.QueryItem = QuestieDBCompiler:GetDBHandle(itemBin, itemPtrs, QuestieDBCompiler:BuildSkipMap(QuestieDB.itemCompilerTypes, QuestieDB.itemCompilerOrder), QuestieDB.itemKeys, QuestieDB.itemDataOverrides)

    QuestieDB.NPCPointers = QuestieDB.QueryNPC.pointers
    QuestieDB.QuestPointers = QuestieDB.QueryQuest.pointers
    QuestieDB.ObjectPointers = QuestieDB.QueryObject.pointers
    QuestieDB.ItemPointers = QuestieDB.QueryItem.pointers

    QuestieDB.QueryNPCSingle = QuestieDB.QueryNPC.QuerySingle
    QuestieDB.QueryQuestSingle = QuestieDB.QueryQuest.QuerySingle
    QuestieDB.QueryObjectSingle = QuestieDB.QueryObject.QuerySingle
    QuestieDB.QueryItemSingle = QuestieDB.QueryItem.QuerySingle

    QuestieDB.QueryNPC = QuestieDB.QueryNPC.Query
    QuestieDB.QueryQuest = QuestieDB.QueryQuest.Query
    QuestieDB.QueryObject = QuestieDB.QueryObject.Query
    QuestieDB.QueryItem = QuestieDB.QueryItem.Query

    -- data has been corrected, ensure cache is empty (something might have accessed the api before questie initialized)
    _QuestieDB.questCache = {};
    _QuestieDB.npcCache = {};

    --? This improves performance a lot, the regular functions still work but this is much faster because i caches
    checkRace  = QuestieLib:TableMemoizeFunction(QuestiePlayer.HasRequiredRace)
    checkClass = QuestieLib:TableMemoizeFunction(QuestiePlayer.HasRequiredClass)
    --? Set the localized versions of these.
    QuestieCorrectionshiddenQuests = QuestieCorrections.hiddenQuests
    Questiedbcharhidden = Questie.db.char.hidden
end

function QuestieDB:GetObject(objectId)
    if not objectId then
        return nil
    end

    --local rawdata = QuestieDB.objectData[objectId];
    local rawdata = QuestieDB.QueryObject(objectId, QuestieDB._objectAdapterQueryOrder)

    if not rawdata then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetObject] rawdata is nil for objectID:", objectId)
        return nil
    end

    local obj = {
        id = objectId,
        type = "object"
    }

    for stringKey, intKey in pairs(QuestieDB.objectKeys) do
        obj[stringKey] = rawdata[intKey]
    end
    return obj;
end

function QuestieDB:GetItem(itemId)
    if (not itemId) or (itemId == 0) then
        return nil
    end

    local rawdata = QuestieDB.QueryItem(itemId, QuestieDB._itemAdapterQueryOrder)

    if not rawdata then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetItem] rawdata is nil for itemID:", itemId)
        return nil
    end

    local item = {
        Id = itemId,
        Sources = {},
        Hidden = QuestieCorrections.questItemBlacklist[itemId]
    }

    for stringKey, intKey in pairs(QuestieDB.itemKeys) do
        item[stringKey] = rawdata[intKey]
    end

    local sources = item.Sources

    if rawdata[QuestieDB.itemKeys.npcDrops] then
        for _, npcId in pairs(rawdata[QuestieDB.itemKeys.npcDrops]) do
            sources[#sources + 1] = {
                Id = npcId,
                Type = "monster",
            }
        end
    end

    if rawdata[QuestieDB.itemKeys.vendors] then
        for _, npcId in pairs(rawdata[QuestieDB.itemKeys.vendors]) do
            local friendlyToFaction = QuestieDB.QueryNPCSingle(npcId, "friendlyToFaction")
            local isFriendlyToPlayer = QuestieDB.IsFriendlyToPlayer(friendlyToFaction)
            if isFriendlyToPlayer then
                -- We don't want to show vendors from the opposite faction
                sources[#sources + 1] = {
                    Id = npcId,
                    Type = "monster",
                }
            end
        end
    end

    if rawdata[QuestieDB.itemKeys.objectDrops] then
        for _, v in pairs(rawdata[QuestieDB.itemKeys.objectDrops]) do
            sources[#sources + 1] = {
                Id = v,
                Type = "object",
            }
        end
    end

    return item
end

---@param itemId ItemId
---@param npcId NpcId
---@return table<number, string>?
function QuestieDB.GetItemDroprate(itemId, npcId)
     if not DropDB or not DropDB.GetItemDroprate then
         Questie:Debug(Questie.DEBUG_CRITICAL, "ItemDrops: DropDB not available")
         return nil
     end
     return DropDB.GetItemDroprate(itemId, npcId)
end

---@param questId number
---@return boolean
function QuestieDB.IsRepeatable(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
    return flags and bitband(flags, 1) ~= 0
end

---@param questId number
---@return boolean
function QuestieDB.IsDailyQuest(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "questFlags")
    -- test a bit flag: (value % (2*flag) >= flag)
    return flags and (flags % QUEST_FLAGS_DAILY_X2) >= QUEST_FLAGS_DAILY
end

---@param questId number
---@return boolean
function QuestieDB.IsWeeklyQuest(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "questFlags")
    -- test a bit flag: (value % (2*flag) >= flag)
    return flags and (flags % QUEST_FLAGS_WEEKLY_X2) >= QUEST_FLAGS_WEEKLY
end

---@param questId number
---@return boolean
function QuestieDB.IsDungeonQuest(questId)
    local questType, _ = QuestieDB.GetQuestTagInfo(questId)
    return questType == 81
end

---@param questId number
---@return boolean
function QuestieDB.IsRaidQuest(questId)
    local questType, _ = QuestieDB.GetQuestTagInfo(questId)
    return questType == 62
end

---@param questId number
---@return boolean
function QuestieDB.IsPvPQuest(questId)
    local questType, _ = QuestieDB.GetQuestTagInfo(questId)
    return questType == 41
end

---@param questId number
---@return boolean
function QuestieDB.IsGroupQuest(questId)
    local questType, _ = QuestieDB.GetQuestTagInfo(questId)
    return questType == 1
end

--[[ Commented out because not used anywhere
---@param questId number
---@return boolean
function QuestieDB:IsAQWarEffortQuest(questId)
    return QuestieQuestBlacklist.AQWarEffortQuests[questId]
end
]]--

---@param class string
---@return number
function QuestieDB:GetZoneOrSortForClass(class)
    return QuestieDB.sortKeys[class]
end

local questTagInfoCache = {}

--- Wrapper function for the GetQuestTagInfo API to correct
--- quests that are falsely marked by Blizzard and cache the results.
---@param questId number
---@return number|nil questTagId
---@return string|nil questTagName
function QuestieDB.GetQuestTagInfo(questId)
    if not questId then return nil, nil end

    if questTagInfoCache[questId] then
        return questTagInfoCache[questId][1], questTagInfoCache[questId][2]
    end

    local questTagId, questTagName
    if questTagCorrections[questId] then
        questTagId, questTagName = questTagCorrections[questId][1], questTagCorrections[questId][2]
    else
        questTagId, questTagName = GetQuestTagInfo(questId)

        if questTagId == nil and questTagName == nil then
            -- Retry the API call after a short delay, as the API tends to incorrectly return nil on the first call.
            -- Doing it here asserts, we only call the API twice per quest at most.
            local retryQuestId = questId
            C_Timer.After(1, function()
                if not retryQuestId then
                    return
                end

                local retryQuestTagId, retryQuestTagName = GetQuestTagInfo(retryQuestId)
                questTagInfoCache[retryQuestId] = {retryQuestTagId, retryQuestTagName}
            end)
        end
    end

    -- cache the result to avoid hitting the API throttling limit
    questTagInfoCache[questId] = {questTagId, questTagName}

    return questTagId, questTagName
end

---@param questId number
---@return boolean
function QuestieDB.IsActiveEventQuest(questId)
    --! If you edit the logic here, also edit in QuestieDB:IsLevelRequirementsFulfilled
    return QuestieEvent.activeQuests[questId] == true
end

---@param exclusiveTo table<number, number>
---@return boolean
function QuestieDB:IsExclusiveQuestInQuestLogOrComplete(exclusiveTo)
    if (not exclusiveTo) then
        return false
    end

    for _, exId in pairs(exclusiveTo) do
        if Questie.db.char.complete[exId] or QuestiePlayer.currentQuestlog[exId] then
            return true
        end
    end
    return false
end

---@param questId QuestId
---@param minLevel Level @The level a quest must have at least to be shown
---@param maxLevel Level @The level a quest can have at most to be shown
---@param playerLevel Level? @Pass player level to avoid calling UnitLevel or to use custom level
---@return boolean
function QuestieDB.IsLevelRequirementsFulfilled(questId, minLevel, maxLevel, playerLevel)
    local level, requiredLevel, requiredMaxLevel = QuestieLib.GetTbcLevel(questId, playerLevel)

    --* QuestiePlayer.currentQuestlog[parentQuestId] logic is from QuestieDB.IsParentQuestActive, if you edit here, also edit there
    local parentQuestId = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuestId and QuestiePlayer.currentQuestlog[parentQuestId] then
        -- If the quest is in the player's log already, there's no need to do any logic here, it must already be available
        return true
    end

    --* QuestieEvent.activeQuests[questId] logic is from QuestieDB.IsParentQuestActive, if you edit here, also edit there
    if (Questie.db.profile.lowLevelStyle ~= Questie.LOWLEVEL_RANGE) and
        minLevel > requiredLevel and
        QuestieEvent.activeQuests[questId]  then
        return true
    end

    if (Questie.IsSoD == true) and (QuestieDB.IsSoDRuneQuest(questId) == true) and (requiredLevel <= playerLevel) then
        -- Season of Discovery Rune quests are still shown when trivial
        return true
    end

    if maxLevel >= level then
        if (Questie.db.profile.lowLevelStyle ~= Questie.LOWLEVEL_ALL) and minLevel > level then
            -- The quest level is too low and trivial quests are not shown
            return false
        end
    else
        if (Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_RANGE) or maxLevel < requiredLevel then
            -- Either an absolute level range is set and maxLevel < level OR the maxLevel is manually set to a lower value
            return false
        end
    end

    if maxLevel < requiredLevel then
        -- Either the players level is not high enough or the maxLevel is manually set to a lower value
        return false
    end

    if requiredMaxLevel ~= 0 and playerLevel > requiredMaxLevel then
        -- The players level exceeds the requiredMaxLevel of a quest
        return false
    end

    return true
end

---@param parentID number
---@return boolean
function QuestieDB.IsParentQuestActive(parentID)
    --! If you edit the logic here, also edit in QuestieDB:IsLevelRequirementsFulfilled
    if (not parentID) or (parentID == 0) then
        return false
    end
    if QuestiePlayer.currentQuestlog[parentID] then
        return true
    end
    return false
end

---@param preQuestGroup table<number, number>
---@return boolean
function QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
    if not preQuestGroup then
        return true
    end
    for preQuestIndex=1, #preQuestGroup do
        -- If a quest is not complete and no exlusive quest is complete, the requirement is not fulfilled
        if not Questie.db.char.complete[preQuestGroup[preQuestIndex]] then
            local preQuest = QuestieDB.QueryQuestSingle(preQuestGroup[preQuestIndex], "exclusiveTo")
            if (not preQuest) then
                return false
            end

            local anyExlusiveFinished = false
            for i=1, #preQuest do
                if Questie.db.char.complete[preQuest[i]] then
                    anyExlusiveFinished = true
                end
            end
            if not anyExlusiveFinished then
                return false
            end
        end
    end
    -- All preQuests are complete
    return true
end

---@param preQuestSingle number[]
---@return boolean
function QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
    if (not preQuestSingle) then
        return true
    end
    for preQuestIndex=1, #preQuestSingle do
        -- If a quest is complete the requirement is fulfilled
        if Questie.db.char.complete[preQuestSingle[preQuestIndex]] then
            return true
        end
    end
    -- No preQuest is complete
    return false
end

---@param questId number
---@param debugPrint boolean? -- if true, IsDoable will print conclusions to debug channel
---@return boolean
function QuestieDB.IsDoable(questId, debugPrint)

    --!  Before changing any logic in QuestieDB.IsDoable, make sure
    --!  to mirror the same logic to QuestieDB.IsDoableVerbose!

    -- IsDoable determines if the player is currently eligible for
    -- a quest, and returns that result as true/false in order to
    -- programmatically show/hide quests and determine further logic.

    -- IsDoableVerbose does the same logic, but returns human-readable
    -- explanations as a string for display in the UI.

    -- These functions are maintained separately for performance,
    -- because IsDoable is often called in a loop through every
    -- quest in the DB in order to update icons, while
    -- IsDoableVerbose is only called manually by the user.

    local completedQuests = Questie.db.char.complete
    local currentQuestlog = QuestiePlayer.currentQuestlog

    -- These are localized in the init function
    if completedQuests[questId] then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is already finished!") end
        return false
    end

    -- Blacklisted quests
    if QuestieCorrectionshiddenQuests[questId] then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is hidden automatically!") end
        return false
    end

    -- Only present in IsDoable, not IsDoableVerbose
    if Questiedbcharhidden[questId] then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is hidden manually!") end
        return false
    end

    if C_QuestLog.IsOnQuest(questId) == true then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is eligible because Player is on the quest!") end
        return true
    end

    if QuestieDB.activeChildQuests[questId] then -- The parent quest is active, so this quest is doable
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is eligible because it's a child quest and the parent is active!") end
        return true
        -- this scenario actually returns true, so it skips the rest of the later checks, because
        -- if we're on the parent quest then we implicitly know all other requirements are met
    end

    local requiredRaces = QuestieDB.QueryQuestSingle(questId, "requiredRaces")
    if (requiredRaces and not checkRace[requiredRaces]) then
        QuestieDB.autoBlacklist[questId] = "race"
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Race requirement not fulfilled for quest " .. questId) end
        return false
    end

    -- Check the preQuestSingle field where just one of the required quests has to be complete for a quest to show up
    local preQuestSingle = QuestieDB.QueryQuestSingle(questId, "preQuestSingle")
    if preQuestSingle then
        local isPreQuestSingleFulfilled = QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
        if not isPreQuestSingleFulfilled then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Pre-quest requirement not fulfilled for quest " .. questId) end
            return false
        end
    end

    local requiredClasses = QuestieDB.QueryQuestSingle(questId, "requiredClasses")
    if (requiredClasses and not checkClass[requiredClasses]) then
        QuestieDB.autoBlacklist[questId] = "class"
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Class requirement not fulfilled for quest " .. questId) end
        return false
    end

    local requiredMinRep = QuestieDB.QueryQuestSingle(questId, "requiredMinRep")
    local requiredMaxRep = QuestieDB.QueryQuestSingle(questId, "requiredMaxRep")
    if (requiredMinRep or requiredMaxRep) then
        local aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction = QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)
        if (not ((aboveMinRep and hasMinFaction) and (belowMaxRep and hasMaxFaction))) then
            --- If we haven't got the faction for min or max we blacklist it
            if not hasMinFaction or not hasMaxFaction then -- or not belowMaxRep -- This is something we could have done, but would break if you rep downwards
                QuestieDB.autoBlacklist[questId] = "rep"
            end

            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet reputation requirements for quest " .. questId) end
            return false
        end
    end

    local requiredSkill = QuestieDB.QueryQuestSingle(questId, "requiredSkill")
    if (requiredSkill) then
        local hasProfession, hasSkillLevel = QuestieProfessions:HasProfessionAndSkillLevel(requiredSkill)
        if (not (hasProfession and hasSkillLevel)) then
            --? We haven't got the profession so we blacklist it.
            if(not hasProfession) then
                QuestieDB.autoBlacklist[questId] = "skill"
            end

            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet profession requirements for quest " .. questId) end
            return false
        end
    end

    local requiredRanks = QuestieDB.QueryQuestSingle(questId, "requiredRanks")
    if (requiredRanks) then
        local hasProfession, hasRankLevel = QuestieProfessions:HasProfessionAndRankLevel(requiredRanks)
        if (not (hasProfession and hasRankLevel)) then
            --? We haven't got the profession so we blacklist it.
            if(not hasProfession) then
                QuestieDB.autoBlacklist[questId] = "rank"
            end

            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not have profession rank for quest " .. questId) end
            return false
        end
    end

    --? preQuestGroup and preQuestSingle are mutualy exclusive to eachother and preQuestSingle is more prevalent
    --? Only try group if single does not exist.
    if not preQuestSingle then
        -- Check the preQuestGroup field where every required quest has to be complete for a quest to show up
        local preQuestGroup = QuestieDB.QueryQuestSingle(questId, "preQuestGroup")
        if preQuestGroup then
            local isPreQuestGroupFulfilled = QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
            if not isPreQuestGroupFulfilled then
                if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Group pre-quest requirement not fulfilled for quest " .. questId) end
                return false
            end
        end
    end

    local parentQuest = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuest and parentQuest ~= 0 then
        if not currentQuestlog[parentQuest] then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " has an inactive parent quest") end
            return false
        end
    end

    local nextQuestInChain = QuestieDB.QueryQuestSingle(questId, "nextQuestInChain")
    if nextQuestInChain and nextQuestInChain ~= 0 then
        if completedQuests[nextQuestInChain] or currentQuestlog[nextQuestInChain] then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Follow up quests already completed or in the quest log for quest " .. questId) end
            return false
        end
    end

    -- Check if a quest which is exclusive to the current has already been completed or accepted
    -- If yes the current quest can't be accepted
    local ExclusiveQuestGroup = QuestieDB.QueryQuestSingle(questId, "exclusiveTo")
    if ExclusiveQuestGroup then -- fix (DO NOT REVERT, tested thoroughly)
        for _, v in pairs(ExclusiveQuestGroup) do
            if completedQuests[v] or currentQuestlog[v] then
                if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player has completed a quest exclusive with quest " .. questId) end
                return false
            end
        end
    end

    local requiredSpecialization = QuestieDB.QueryQuestSingle(questId, "requiredSpecialization")
    if (requiredSpecialization) and (requiredSpecialization > 0) then
        local hasSpecialization = QuestieProfessions:HasSpecialization(requiredSpecialization)
        if (not hasSpecialization) then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet profession specialization requirements for quest " .. questId) end
            return false
        end
    end

    local requiredSpell = QuestieDB.QueryQuestSingle(questId, "requiredSpell")
    if (requiredSpell) and (requiredSpell ~= 0) then
        local hasSpell = IsSpellKnownOrOverridesKnown(math.abs(requiredSpell))
        local hasProfSpell = IsPlayerSpell(math.abs(requiredSpell))
        if (requiredSpell > 0) and (not hasSpell) and (not hasProfSpell) then --if requiredSpell is positive, we make the quest unavailable if the player does NOT have the spell
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet learned spell requirements for quest " .. questId) end
            return false
        elseif (requiredSpell < 0) and (hasSpell or hasProfSpell) then --if requiredSpell is negative, we make the quest unavailable if the player DOES  have the spell
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet unlearned spell requirements for quest " .. questId) end
            return false
        end
    end

    -- Check and see if the Quest requires an achievement before showing as available
    if _QuestieDB:CheckAchievementRequirements(questId) == false then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet achievement requirements for quest " .. questId) end
        return false
    end

    -- Check if this quest is a breadcrumb
    local breadcrumbForQuestId = QuestieDB.QueryQuestSingle(questId, "breadcrumbForQuestId")
    if breadcrumbForQuestId and breadcrumbForQuestId ~= 0 then
        -- Check the target quest of this breadcrumb
        if completedQuests[breadcrumbForQuestId] or currentQuestlog[breadcrumbForQuestId] then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Target of breadcrumb quest already completed or in the quest log for quest " .. questId) end
            return false
        end
        -- The next case is commented out since it's not a valid check to have. Breadcrumbs to the same quest are not always exclusive to each other
        --[[ Check if the other breadcrumbs are active
        local otherBreadcrumbs = QuestieDB.QueryQuestSingle(breadcrumbForQuestId, "breadcrumbs")
        for _, breadcrumbId in ipairs(otherBreadcrumbs or {}) do -- TODO: Remove `or {}` when we have a validation for the breadcrumb data
            if breadcrumbId ~= questId and currentQuestlog[breadcrumbId] then
                if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Alternative breadcrumb quest in the quest log for quest " .. questId) end
                return false
            end
        end]]
    end

    -- Check if this quest has active breadcrumbs
    local breadcrumbs = QuestieDB.QueryQuestSingle(questId, "breadcrumbs")
    if breadcrumbs then
        for _, breadcrumbId in ipairs(breadcrumbs) do
            if currentQuestlog[breadcrumbId] then
                if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Breadcrumb quest in the quest log for quest " .. questId) end
                return false
            end
        end
    end

    -- Check if this quest is not detected as active from the NPC/object itself
    if DailyQuests.ShouldBeHidden(questId, completedQuests, currentQuestlog) then
        if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Daily quest " .. questId .. " is not active") end
        return false
    end

    -- Check if this quest is visible until you turn in a certain quest
    local availableUntilCompleted = QuestieDB.QueryQuestSingle(questId, "availableUntilCompleted")
    if availableUntilCompleted and availableUntilCompleted ~= 0 then
        if completedQuests[availableUntilCompleted] then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is not available because " .. availableUntilCompleted .. " has been turned in!") end
            return false
        end
    end

    -- Check if this quest is visible if you have a certain quest in log or turned in (slightly different to preQuestSingle)
    -- In order to not mess with the existing logic for preQuestSingle, this field must be accompanied by preQuestSingle
    local availableStartingWith = QuestieDB.QueryQuestSingle(questId, "availableStartingWith")
    if availableStartingWith and availableStartingWith ~= 0 then
        if not completedQuests[availableStartingWith] and not currentQuestlog[availableStartingWith] then
            if debugPrint then Questie:Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is not available because " .. availableStartingWith .. " is not active/turned in!") end
            return false
        end
    end

    return true
end

---@param questId number
---@param debugPrint boolean? -- if true, IsDoable will print conclusions to debug channel
---@param returnText boolean? -- if true, IsDoable will return plaintext explanation instead of true/false
---@param returnBrief boolean? -- if true and returnText is true, IsDoable will return a very brief explanation instead of a verbose one
---@return boolean
function QuestieDB.IsDoableVerbose(questId, debugPrint, returnText, returnBrief)

    --!  Before changing any logic in QuestieDB.IsDoable, make sure
    --!  to mirror the same logic to QuestieDB.IsDoableVerbose!

    -- IsDoable determines if the player is currently eligible for
    -- a quest, and returns that result as true/false in order to
    -- programmatically show/hide quests and determine further logic.

    -- IsDoableVerbose does the same logic, but returns human-readable
    -- explanations as a string for display in the UI.

    -- These functions are maintained separately for performance,
    -- because IsDoable is often called in a loop through every
    -- quest in the DB in order to update icons, while
    -- IsDoableVerbose is only called manually by the user.

    local completedQuests = Questie.db.char.complete
    local currentQuestlog = QuestiePlayer.currentQuestlog
    local DoableStates = QuestieDB.DoableStates
    local HIDE_ON_MAP = QuestieQuestBlacklist.HIDE_ON_MAP

    -- Completed quests
    if completedQuests[questId] then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Already complete"), false, DoableStates.COMPLETED -- we return false here as we don't want to show it as label when completed in QBZ/QBF
        elseif returnText then
            return "Player has already completed quest " .. questId .. "!", false, DoableStates.COMPLETED
        end
    end

    -- The player has this quest in the quest log
    if C_QuestLog.IsOnQuest(questId) == true then
        local msg = "Quest " .. questId .. " is active"
        if returnText and returnBrief then
            return l10n("Available")..l10n(": ")..l10n("Player is on quest"), false, DoableStates.QUEST_LOG
        elseif returnText and not returnBrief then
            return msg, false, DoableStates.QUEST_LOG
        end
    end

    -- Automatically blacklisted quests by Questie. These are localized in the init function
    if QuestieCorrectionshiddenQuests[questId] and QuestieCorrectionshiddenQuests[questId] ~= HIDE_ON_MAP then
        local msg = "Quest " .. questId .. " is hidden automatically"
        local msgevent = "Quest " .. questId .. " is unavailable because the world event is inactive"
        if QuestieEvent:IsEventQuest(questId) and not QuestieEvent:IsEventActiveForQuest(questId) then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
            elseif returnText and not returnBrief then
                return msgevent, true, DoableStates.EVENT_INACTIVE
            end
        end
        if returnText and returnBrief then
            return l10n("Unknown")..l10n(": ")..l10n("Automatically blacklisted"), true, DoableStates.BLACKLISTED
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.BLACKLISTED
        end
    end

    -- AQ War Effort quests (one-time world event that has ended for all realms)
    if (not Questie.IsSoD) and QuestieQuestBlacklist.AQWarEffortQuests[questId] then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
        elseif returnText then
            return "AQ event quest " .. questId .. " is not active", true, DoableStates.EVENT_INACTIVE
        end
    end

    -- Check character race
    local requiredRaces = QuestieDB.QueryQuestSingle(questId, "requiredRaces")
    if (requiredRaces and not checkRace[requiredRaces]) then
        local msg = "Race requirement not fulfilled for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Race requirement"), true, DoableStates.WRONG_RACE
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.WRONG_RACE
        end
    end

    -- Check character class
    local requiredClasses = QuestieDB.QueryQuestSingle(questId, "requiredClasses")
    if (requiredClasses and not checkClass[requiredClasses]) then
        QuestieDB.autoBlacklist[questId] = "class"
        local msg = "Class requirement not fulfilled for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Class requirement"), true, DoableStates.WRONG_CLASS
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.WRONG_CLASS
        end
    end

    -- We keep this here, even though it is removed from QuestieDB.IsDoable because AvailableQuests.CalculateAndDrawAll
    -- checks child quests differently and before IsDoable
    if QuestieDB.activeChildQuests[questId] then -- The parent quest is active, so this quest is doable
        local msg = "Quest " .. questId .. " is available because it's a child quest, the parent is active and conditions are met"
        if returnText and returnBrief then
            return l10n("Available")..l10n(": ")..l10n("Parent active"), false, DoableStates.PARENT_ACTIVE
        elseif returnText and not returnBrief then
            return msg, false, DoableStates.PARENT_ACTIVE
        end
    end

    -- Check if a quest which is exclusive to the current has already been completed or accepted
    -- If yes the current quest can't be accepted
    local ExclusiveQuestGroup = QuestieDB.QueryQuestSingle(questId, "exclusiveTo")
    if ExclusiveQuestGroup then -- fix (DO NOT REVERT, tested thoroughly)
        for _, v in pairs(ExclusiveQuestGroup) do
            if completedQuests[v] then
                local msg = "Quest " .. questId .. " is unavailable because exclusive quest " .. v .. " is completed"
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Exclusive quest completed"), true, DoableStates.EXCLUSIVE_COMPLETED
                elseif returnText and not returnBrief then
                    return msg, true, DoableStates.EXCLUSIVE_COMPLETED
                end
            elseif currentQuestlog[v] then
                local msg = "Quest " .. questId .. " is unavailable because exclusive quest " .. v .. " is in the quest log"
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Exclusive quest in quest log"), true, DoableStates.EXCLUSIVE_IN_QUEST_LOG
                elseif returnText and not returnBrief then
                    return msg, true, DoableStates.EXCLUSIVE_IN_QUEST_LOG
                end
            end
        end
    end

    -- Check if the character is higher than the quest allows
    local requiredMaxLevel = QuestieDB.QueryQuestSingle(questId, "requiredMaxLevel")
    if (requiredMaxLevel and requiredMaxLevel ~= 0 and (UnitLevel("player") > requiredMaxLevel)) then
        local msg = "Player level is too high for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Level too high"), true, DoableStates.LEVEL_TOO_HIGH
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.LEVEL_TOO_HIGH
        end
    end

    -- only present in verbose.
    -- IsDoable has its own logic that varies based on player settings for quest visibility
    local requiredLevel = QuestieDB.QueryQuestSingle(questId, "requiredLevel")
    if (requiredLevel and (UnitLevel("player") < requiredLevel)) then
        local msg = "Player level is too low for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Level too low"), true, DoableStates.LEVEL_TOO_LOW
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.LEVEL_TOO_LOW
        end
    end

    -- Check reputation requirements
    local requiredMinRep = QuestieDB.QueryQuestSingle(questId, "requiredMinRep")
    local requiredMaxRep = QuestieDB.QueryQuestSingle(questId, "requiredMaxRep")
    if (requiredMinRep or requiredMaxRep) then
        local aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction = QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)
        -- Below reputation requirement
        if not (aboveMinRep and hasMinFaction) then
            local msg = "Reputation too low for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Reputation too low"), true, DoableStates.MISSING_REPUTATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.MISSING_REPUTATION
            end
        end
        -- Above reputation requirement
        if not (belowMaxRep and hasMaxFaction) then
            local msg = "Reputation too high for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Reputation too high"), true, DoableStates.EXCEED_REPUTATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.EXCEED_REPUTATION
            end
        end
    end

    -- Check profession requirements
    local requiredSkill = QuestieDB.QueryQuestSingle(questId, "requiredSkill")
    local requiredRanks = QuestieDB.QueryQuestSingle(questId, "requiredRanks")
    -- Until then these two should be mutually exclusive
    -- TODO: if we find a quest that has both requiredSkill and requiredRanks we need to be able to return correct message
    if (requiredSkill) then
        local hasProfession, hasSkillLevel = QuestieProfessions:HasProfessionAndSkillLevel(requiredSkill)
        if not hasProfession then
            local msg = "Profession missing for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession missing"), true, DoableStates.PROFESSION_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_MISSING
            end
        elseif not hasSkillLevel then
            local msg = "Player does not have required profession skill for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession skill"), true, DoableStates.PROFESSION_SKILL
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_SKILL
            end
        end
    end
    if (requiredRanks) then
        local hasProfession, hasRankLevel = QuestieProfessions:HasProfessionAndRankLevel(requiredRanks)
        if not hasProfession then
            local msg = "Profession missing for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession missing"), true, DoableStates.PROFESSION_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_MISSING
            end
        elseif not hasRankLevel then
            local msg = "Player does not have required profession rank for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession rank"), true, DoableStates.PROFESSION_RANK
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_RANK
            end
        end
    end

    -- Check the preQuestSingle field where just one of the required quests has to be complete for a quest to show up
    local preQuestSingle = QuestieDB.QueryQuestSingle(questId, "preQuestSingle")
    if preQuestSingle then
        local isPreQuestSingleFulfilled = QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
        if not isPreQuestSingleFulfilled then
            local msg = "Pre-quest requirement not fulfilled for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Incomplete pre-quest"), true, DoableStates.NO_PREQUESTSINGLE
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NO_PREQUESTSINGLE
            end
        end
    end

    -- Check the preQuestGroup field where every required quest has to be complete for a quest to show up
    local preQuestGroup = QuestieDB.QueryQuestSingle(questId, "preQuestGroup")
    if preQuestGroup then
        local isPreQuestGroupFulfilled = QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
        if not isPreQuestGroupFulfilled then
            local msg = "Group pre-quest requirement not fulfilled for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Incomplete pre-quest group"), true, DoableStates.NO_PREQUESTGROUP
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NO_PREQUESTGROUP
            end
        end
    end

    -- Check parent quests
    local parentQuest = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuest and parentQuest ~= 0 then
        if not currentQuestlog[parentQuest] then
            local msg = "Quest " .. questId .. " has an inactive parent quest: " .. parentQuest
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Inactive parent"), true, DoableStates.PARENT_INACTIVE
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PARENT_INACTIVE
            end
        end
    end

    -- Check if it has nextQuestInChain completed or in quest log
    local nextQuestInChain = QuestieDB.QueryQuestSingle(questId, "nextQuestInChain")
    if nextQuestInChain and nextQuestInChain ~= 0 then
        if completedQuests[nextQuestInChain] or currentQuestlog[nextQuestInChain] then
            local msg = "Follow up quest " .. nextQuestInChain .. " already completed or in the quest log for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Later quest completed or active"), true, DoableStates.NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED
            end
        end
    end

    -- Check profession specialization requirements
    local requiredSpecialization = QuestieDB.QueryQuestSingle(questId, "requiredSpecialization")
    if (requiredSpecialization) and (requiredSpecialization > 0) then
        local hasSpecialization = QuestieProfessions.HasSpecialization(requiredSpecialization)
        if (not hasSpecialization) then
            local msg = "Player does not meet profession specialization requirements for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession specialization requirement"), true, DoableStates.PROFESSION_SPECIALIZATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_SPECIALIZATION
            end
        end
    end

    -- Check spell requirements
    local requiredSpell = QuestieDB.QueryQuestSingle(questId, "requiredSpell")
    if (requiredSpell) and (requiredSpell ~= 0) then
        local hasSpell = IsSpellKnownOrOverridesKnown(math.abs(requiredSpell))
        local hasProfSpell = IsPlayerSpell(math.abs(requiredSpell))
        if (requiredSpell > 0) and (not hasSpell) and (not hasProfSpell) then --if requiredSpell is positive, we make the quest unavailable if the player does NOT have the spell
            local msg = "Player does not know spell ID: " .. math.abs(requiredSpell) .. " for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Spell not yet learned"), true, DoableStates.SPELL_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.SPELL_MISSING
            end
        elseif (requiredSpell < 0) and (hasSpell or hasProfSpell) then --if requiredSpell is negative, we make the quest unavailable if the player DOES have the spell
            local msg = "Player knows spell ID: " .. math.abs(requiredSpell) .. " for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Already learned spell"), true, DoableStates.SPELL_KNOWN
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.SPELL_KNOWN
            end
        end
    end

    -- Check and see if the Quest requires an achievement before showing as available
    if _QuestieDB:CheckAchievementRequirements(questId) == false then
        local msg = "Player does not meet achievement requirements for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Achievement requirement"), true, DoableStates.MISSING_ACHIEVEMENT
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.MISSING_ACHIEVEMENT
        end
    end

    -- Check if this quest is a breadcrumb
    local breadcrumbForQuestId = QuestieDB.QueryQuestSingle(questId, "breadcrumbForQuestId")
    if breadcrumbForQuestId and breadcrumbForQuestId ~= 0 then
        -- Check the follow up quest of this breadcrumb
        if completedQuests[breadcrumbForQuestId] or currentQuestlog[breadcrumbForQuestId] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Follow up quest active or completed"), true, DoableStates.BREADCRUMB_FOLLOWUP
            elseif returnText and not returnBrief then
                return "Follow up of breadcrumb quest " .. breadcrumbForQuestId .. " already completed or in the quest log for quest " .. questId, true, DoableStates.BREADCRUMB_FOLLOWUP
            end
        end
        -- The next case is commented out since it's not a valid check to have. Breadcrumbs to the same quest are not always exclusive to eachother
        --[[ Check if the other breadcrumbs are active
        local otherBreadcrumbs = QuestieDB.QueryQuestSingle(breadcrumbForQuestId, "breadcrumbs")
        for _, breadcrumbId in ipairs(otherBreadcrumbs or {}) do
            if breadcrumbId ~= questId and currentQuestlog[breadcrumbId] then
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Another breadcrumb is active"), true, DoableStates.EXCLUSIVE_BREADCRUMB
                elseif returnText and not returnBrief then
                    return "Alternative breadcrumb quest " .. breadcrumbId .." in the quest log for quest " .. questId, true, DoableStates.EXCLUSIVE_BREADCRUMB
                end
            end
        end]]
    end

    -- Check if this quest has active breadcrumbs
    local breadcrumbs = QuestieDB.QueryQuestSingle(questId, "breadcrumbs")
    if breadcrumbs then
        for _, breadcrumbId in ipairs(breadcrumbs) do
            if currentQuestlog[breadcrumbId] then
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("A breadcrumb is active"), true, DoableStates.BREADCRUMB_ACTIVE
                elseif returnText and not returnBrief then
                    return "A breadcrumb quest " .. breadcrumbId .." is in the quest log for quest " .. questId, true, DoableStates.BREADCRUMB_ACTIVE
                end
            end
        end
    end

    -- Daily quest not active (based on ShouldBeHidden)
    if DailyQuests.ShouldBeHidden(questId, completedQuests, currentQuestlog) then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Daily quest not active"), true, DoableStates.INACTIVE_DAILY
        elseif returnText then
            return "Daily quest " .. questId .. " is not active", true, DoableStates.INACTIVE_DAILY
        end
    end

    -- Check if this quest is visible until you turn in a certain quest
    local availableUntilCompleted = QuestieDB.QueryQuestSingle(questId, "availableUntilCompleted")
    if availableUntilCompleted and availableUntilCompleted ~= 0 then
        if completedQuests[availableUntilCompleted] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Disabling quest already turned in"), true, DoableStates.DISABLING_QUEST_COMPLETED
            elseif returnText and not returnBrief then
                return "Quest " .. questId .. " is not available because " .. availableUntilCompleted .. " has been turned in", true, DoableStates.DISABLING_QUEST_COMPLETED
            end
        end
    end

    -- Check if this quest is visible if you have a certain quest in log or turned in (slightly different to preQuestSingle)
    local availableStartingWith = QuestieDB.QueryQuestSingle(questId, "availableStartingWith")
    if availableStartingWith and availableStartingWith ~= 0 then
        if not completedQuests[availableStartingWith] and not currentQuestlog[availableStartingWith] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Enabling quest not active nor turned in"), true, DoableStates.ENABLING_QUEST_MISSING
            elseif returnText and not returnBrief then
                return "Quest " .. questId .. " is not available because " .. availableStartingWith .. " is not active/turned in", true, DoableStates.ENABLING_QUEST_MISSING
            end
        end
    end

    -- Check if daily quests not available via npcInteraction and/or comms
    if (not Questie.db.global.unavailableQuestsDeterminedByTalking[serverName]) or QuestieLib.DidDailyResetHappenSinceLastLogin() then
        Questie.db.global.unavailableQuestsDeterminedByTalking[serverName] = {}
    end
    local unavailableQuestsDeterminedByTalking = Questie.db.global.unavailableQuestsDeterminedByTalking[serverName]
    for i, _ in pairs(unavailableQuestsDeterminedByTalking) do
        if i == questId then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Daily quest not active"), true, DoableStates.MISSING_DAILY
            elseif returnText then
                return "Daily quest " .. questId .. " is not active", true, DoableStates.MISSING_DAILY
            end
        end
    end

    -- Available quests
    if returnText and returnBrief then
        return l10n("Available"), false, DoableStates.AVAILABLE
    elseif returnText and not returnBrief then
        return "Quest " .. questId .. " is available", false, DoableStates.AVAILABLE
    else
        return "", false, DoableStates.AVAILABLE
    end
end

---@param questId number
---@return number @Complete = 1, Failed = -1, Incomplete = 0
function QuestieDB.IsComplete(questId)
    local questLogEntry = QuestLogCache.questLog_DO_NOT_MODIFY[questId] -- DO NOT MODIFY THE RETURNED TABLE
    local noQuestItem = not QuestieQuest:CheckQuestSourceItem(questId)

    --[[ pseudo:
    if no questLogEntry then return 0
    if has questLogEntry.isComplete then return questLogEntry.isComplete
    if no objectives and an item is needed but not obtained then return 0
    if no objectives then return 1
    return 0
    --]]

    return questLogEntry and (questLogEntry.isComplete or (questLogEntry.objectives[1] and 0) or (#questLogEntry.objectives == 0 and noQuestItem and 0) or 1) or 0
end

---@param self Quest
---@return number @Complete = 1, Failed = -1, Incomplete = 0
local function _IsComplete(self)
    return QuestieDB.IsComplete(self.Id)
end

---@param questLevel number the level of the quest
---@return boolean @Returns true if the quest should be grey, false otherwise
function QuestieDB.IsTrivial(questLevel)
    if questLevel == -1 then
        return false -- Scaling quests are never trivial
    end

    local levelDiff = questLevel - QuestiePlayer.GetPlayerLevel();
    if (levelDiff >= 5) then
        return false -- Red
    elseif (levelDiff >= 3) then
        return false -- Orange
    elseif (levelDiff >= -2) then
        return false -- Yellow
    elseif (-levelDiff <= GetQuestGreenRange("player")) then
        return false -- Green
    else
        return true -- Grey
    end
end

---@return number
local _GetIconScale = function()
    return Questie.db.profile.objectScale or 1
end

---@param questId QuestId
---@return Quest|nil @The quest object or nil if the quest is missing
function QuestieDB.GetQuest(questId) -- /dump QuestieDB.GetQuest(867)
    if not questId then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieDB.GetQuest] No questId.")
        return nil
    end
    if _QuestieDB.questCache[questId] then
        return _QuestieDB.questCache[questId];
    end

    local rawdata = QuestieDB.QueryQuest(questId, QuestieDB._questAdapterQueryOrder)

    if (not rawdata) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieDB.GetQuest] rawdata is nil for questID:", questId)
        return nil
    end

    ---@class Quest
    ---@field public Id QuestId
    ---@field public name Name
    ---@field public startedBy StartedBy
    ---@field public finishedBy FinishedBy
    ---@field public requiredLevel Level
    ---@field public questLevel Level
    ---@field public requiredRaces number @bitmask
    ---@field public requiredClasses number @bitmask
    ---@field public objectivesText string[]
    ---@field public triggerEnd { [1]: string, [2]: table<AreaId, CoordPair[]>}
    ---@field public objectives RawObjectives
    ---@field public sourceItemId ItemId
    ---@field public preQuestGroup QuestId[]
    ---@field public preQuestSingle QuestId[]
    ---@field public childQuests QuestId[]
    ---@field public inGroupWith QuestId[]
    ---@field public exclusiveTo QuestId[]
    ---@field public zoneOrSort ZoneOrSort
    ---@field public requiredSkill SkillPair
    ---@field public requiredMinRep ReputationPair
    ---@field public requiredMaxRep ReputationPair
    ---@field public requiredSourceItems ItemId[]
    ---@field public nextQuestInChain number
    ---@field public questFlags number @bitmask: see https://github.com/cmangos/issues/wiki/Quest_template#questflags
    ---@field public specialFlags number @bitmask: 1 = Repeatable, 2 = Needs event, 4 = Monthly reset (req. 1). See https://github.com/cmangos/issues/wiki/Quest_template#specialflags
    ---@field public parentQuest QuestId
    ---@field public reputationReward ReputationPair[]
    ---@field public extraObjectives ExtraObjective[]
    ---@field public requiredMaxLevel Level
    ---@field public breacrumbForQuestId number
    ---@field public breacrumbs QuestId[]
    ---@field public availableUntilCompleted QuestId
    ---@field public availableStartingWith QuestId
    ---@field public requiredRanks SkillPair[]
    local QO = {
        Id = questId
    }

    -- General filling of the QuestObjective with all database values
    local questKeys = QuestieDB.questKeys
    for stringKey, intKey in pairs(questKeys) do
        QO[stringKey] = rawdata[intKey]
    end

    local questLevel, requiredLevel = QuestieLib.GetTbcLevel(questId)
    QO.level = questLevel
    QO.requiredLevel = requiredLevel

    ---@type StartedBy
    local startedBy = QO.startedBy
    QO.Starts = {
        NPC = startedBy[1],
        GameObject = startedBy[2],
        Item = startedBy[3],
    }
    QO.isHidden = rawdata.hidden or QuestieCorrections.hiddenQuests[questId]
    QO.Description = QO.objectivesText
    if QO.specialFlags then
        QO.IsRepeatable = bitband(QO.specialFlags, 1) ~= 0
    end

    QO.IsComplete = _IsComplete

    ---@type FinishedBy
    local finishedBy = QO.finishedBy
    if finishedBy[1] then
        for _, id in pairs(finishedBy[1]) do
            if id then
                QO.Finisher = {
                    Type = "monster",
                    Id = id,
                    ---@type Name @We have to hard-type it here because of the function
                    Name = QuestieDB.QueryNPCSingle(id, "name")
                }
            end
        end
    end
    if finishedBy[2] then
        for _, id in pairs(finishedBy[2]) do
            if id then
                QO.Finisher = {
                    Type = "object",
                    Id = id,
                    ---@type Name @We have to hard-type it here because of the function
                    Name = QuestieDB.QueryObjectSingle(id, "name")
                }
            end
        end
    end

    --- to differentiate from the current quest log info.
    --- Quest objectives generated from DB+Corrections.
    --- Data itself is for example for monster type { Type = "monster", Id = 16518, Text = "Nestlewood Owlkin inoculated" }
    ---@type Objective[]
    QO.ObjectiveData = {}

    ---@type RawObjectives
    local objectives = QO.objectives
    if objectives then
        if objectives[1] then
            for _, creatureObjective in pairs(objectives[1]) do
                if creatureObjective then
                    local icon = creatureObjective[3]
                    if icon == 0 then
                        icon = nil
                    end
                    ---@type NpcObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = {
                        Type = "monster",
                        Id = creatureObjective[1],
                        Text = creatureObjective[2],
                        Icon = icon
                    }
                end
            end
        end
        if objectives[2] then
            for _, objectObjective in pairs(objectives[2]) do
                if objectObjective then
                    local icon = objectObjective[3]
                    if icon == 0 then
                        icon = nil
                    end
                    ---@type ObjectObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = {
                        Type = "object",
                        Id = objectObjective[1],
                        Text = objectObjective[2],
                        Icon = icon
                    }
                end
            end
        end
        if objectives[3] then
            for _, itemObjective in pairs(objectives[3]) do
                if itemObjective then
                    local icon = itemObjective[3]
                    if icon == 0 then
                        icon = nil
                    end
                    ---@type ItemObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = {
                        Type = "item",
                        Id = itemObjective[1],
                        Text = itemObjective[2],
                        Icon = icon
                    }
                    if QuestieCorrections.itemObjectiveFirst[questId] then
                        tinsert(QO.ObjectiveData, 1, QO.ObjectiveData[#QO.ObjectiveData])
                        tremove(QO.ObjectiveData)
                    end
                end
            end
        end
        if objectives[4] then
            ---@type ReputationObjective
            QO.ObjectiveData[#QO.ObjectiveData+1] = {
                Type = "reputation",
                Id = objectives[4][1],
                RequiredRepValue = objectives[4][2]
            }
        end
        if objectives[5] and type(objectives[5]) == "table" and #objectives[5] > 0 then
            for _, creditObjective in pairs(objectives[5]) do
                local icon = creditObjective[4]
                if icon == 0 then
                    icon = nil
                end
                ---@type KillObjective
                local killCreditObjective = {
                    Type = "killcredit",
                    IdList = creditObjective[1],
                    RootId = creditObjective[2],
                    Text = creditObjective[3],
                    Icon = icon
                }

                --? There are quest(s) which have the killCredit at first so we need to switch them
                -- Place the kill credit objective first
                if QuestieCorrections.killCreditObjectiveFirst[questId] then
                    tinsert(QO.ObjectiveData, 1, killCreditObjective);
                else
                    tinsert(QO.ObjectiveData, killCreditObjective);
                end
            end
        end
        if objectives[6] then
            for index, spellObjective in pairs(objectives[6]) do
                if spellObjective then
                    ---@type SpellObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = {
                        Type = "spell",
                        Id = spellObjective[1],
                        Text = spellObjective[2],
                        ItemSourceId = spellObjective[3],
                    }
                    QO.SpellItemId = spellObjective[3]
                end
            end
        end
    end

    -- Events need to be added at the end of ObjectiveData
    local triggerEnd = QO.triggerEnd
    if triggerEnd then
        ---@type TriggerEndObjective
        QO.ObjectiveData[#QO.ObjectiveData+1] = {
            Type = "event",
            Text = triggerEnd[1],
            Coordinates = triggerEnd[2]
        }
    end

    local preQuestGroup = QO.preQuestGroup
    local preQuestSingle = QO.preQuestSingle
    if preQuestGroup and preQuestSingle and next(preQuestGroup) and next(preQuestSingle) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "ERRRRORRRRRRR not mutually exclusive for questID:", questId)
    end

    --- Quest objectives generated from quest log in QuestieQuest.lua -> QuestieQuest:PopulateQuestLogInfo(quest)
    --- Includes also icons drawn to maps, and other stuff.
    ---@type table<ObjectiveIndex, QuestObjective>
    QO.Objectives = {}

    QO.SpecialObjectives = {}

    ---@type ItemId[]
    local requiredSourceItems = QO.requiredSourceItems
    if requiredSourceItems then
        for _, itemId in pairs(requiredSourceItems) do
            if itemId then
                -- Make sure requiredSourceItems aren't already an objective
                local itemObjPresent = false
                if objectives[3] then
                    for _, itemObjective in pairs(objectives[3]) do
                        if itemObjective then
                            if itemId == itemObjective[1] then
                                itemObjPresent = true
                                break
                            end
                        end
                    end
                end

                -- Make an objective for requiredSourceItem
                if not itemObjPresent then
                    QO.SpecialObjectives[itemId] = {
                        Type = "item",
                        Id = itemId,
                        ---@type string @We have to hard-type it here because of the function
                        Description = QuestieDB.QueryItemSingle(itemId, "name")
                    }
                end
            end
        end
    end

    ---@type ExtraObjective[]
    local extraObjectives = QO.extraObjectives
    if extraObjectives then
        for index, o in pairs(extraObjectives) do
            local specialObjective = {
                Icon = o[2],
                Description = o[3],
                RealObjectiveIndex = o[4],
            }
            if o[1] then -- custom spawn
                specialObjective.spawnList = {{
                    Name = o[3],
                    Spawns = o[1],
                    Icon = o[2],
                    GetIconScale = _GetIconScale,
                    IconScale = _GetIconScale(),
                }}
            end
            if o[5] then -- db ref
                specialObjective.Type = o[5][1][1]
                specialObjective.Id = o[5][1][2]
                local spawnList = {}

                for _, ref in pairs(o[5]) do
                    for k, v in pairs(_QuestieQuest.objectiveSpawnListCallTable[ref[1]](ref[2], specialObjective)) do
                        -- we want to be able to override the icon in the corrections (e.g. Questie.ICON_TYPE_OBJECT on objects instead of Questie.ICON_TYPE_LOOT)
                        v.Icon = o[2]
                        spawnList[k] = v
                    end
                end

                specialObjective.spawnList = spawnList
            end
            QO.SpecialObjectives[index] = specialObjective
        end
    end

    _QuestieDB.questCache[questId] = QO
    return QO
end

QuestieDB._CreatureLevelCache = {}
---@param quest Quest
---@return table<string, table> @List of creature names with their min-max level and rank
function QuestieDB:GetCreatureLevels(quest)
    if quest and QuestieDB._CreatureLevelCache[quest.Id] then
        return QuestieDB._CreatureLevelCache[quest.Id]
    end
    local creatureLevels = {}

    local function _CollectCreatureLevels(npcIds)
        for _, npcId in pairs(npcIds) do
            local npc = QuestieDB:GetNPC(npcId)
            if npc and not creatureLevels[npc.name] then
                creatureLevels[npc.name] = {npc.minLevel, npc.maxLevel, npc.rank}
            end
        end
    end

    if quest.objectives then
        if quest.objectives[1] then -- Killing creatures
            for _, creatureObjective in pairs(quest.objectives[1]) do
                local npcId = creatureObjective[1]
                _CollectCreatureLevels({npcId})
            end
        end
        if quest.objectives[3] then -- Looting items from creatures
            for _, itemObjective in pairs(quest.objectives[3]) do
                local itemId = itemObjective[1]
                local npcIds = QuestieDB.QueryItemSingle(itemId, "npcDrops")
                if npcIds then
                    _CollectCreatureLevels(npcIds)
                end
            end
        end
    end
    if quest.Id then
        QuestieDB._CreatureLevelCache[quest.Id] = creatureLevels
    end
    return creatureLevels
end

local playerFaction = UnitFactionGroup("player")
local factionReactions = {
    A = (playerFaction == "Alliance") or nil,
    H = (playerFaction == "Horde") or nil,
    AH = true,
}
--
--
--function __TEST()
--    local questsWithoutTriggerEnd = {
--        869,
--        944,
--        1448,
--        6185,
--        9260,
--        9261,
--        9262,
--        9263,
--        9264,
--        9265,
--        12032,
--        12036,
--        12816,
--        12817,
--        13564,
--        13639,
--        13881,
--        13961,
--        14066,
--        14165,
--        14389,
--        24452,
--        24618,
--        25081,
--        25325,
--        25621,
--        25715,
--        25930,
--        26258,
--        26512,
--        26930,
--        26975,
--        27007,
--        27044,
--        27152,
--        27341,
--        27349,
--        27610,
--        27704,
--        28228,
--        28635,
--        28732,
--        29392,
--        29415,
--        29536,
--        29539,
--    }
--
--    local corrections = {}
--
--    -- Read QuestieDB to check if the quest has a triggerEnd
--    for _, questId in pairs(questsWithoutTriggerEnd) do
--        local quest = QuestieDB.GetQuest(questId)
--        if (not quest) then
--            print("Quest " .. questId .. " not found in QuestieDB")
--            corrections[questId] = true
--        else
--            if quest.triggerEnd then
--                print("Quest " .. questId .. " has a triggerEnd")
--            else
--                print("Quest " .. questId .. " does not have a triggerEnd")
--                corrections[questId] = true
--            end
--        end
--    end
--
--    Questie.db.global.__TEST = corrections
--end
---@param npcId number
---@return table
function QuestieDB:GetNPC(npcId)
    if not npcId then
        return nil
    end
    if _QuestieDB.npcCache[npcId] then
        return _QuestieDB.npcCache[npcId]
    end

    local rawdata = QuestieDB.QueryNPC(npcId, QuestieDB._npcAdapterQueryOrder)
    if (not rawdata) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetNPC] rawdata is nil for npcID:", npcId)
        return nil
    end

    local npcKeys = QuestieDB.npcKeys
    local npc = {
        id = npcId,
        type = "monster",
    }
    for stringKey, intKey in pairs(npcKeys) do
        npc[stringKey] = rawdata[intKey]
    end

    local friendlyToFaction = rawdata[npcKeys.friendlyToFaction]
    npc.friendly = QuestieDB.IsFriendlyToPlayer(friendlyToFaction)

    _QuestieDB.npcCache[npcId] = npc
    return npc
end

---@param friendlyToFaction string --The NPC database field friendlyToFaction - so either nil, "A", "H" or "AH"
---@return boolean
function QuestieDB.IsFriendlyToPlayer(friendlyToFaction)
    if (not friendlyToFaction) or friendlyToFaction == "AH" then
        return true
    end

    if friendlyToFaction == "H" then
        return QuestiePlayer.faction == "Horde"
    elseif friendlyToFaction == "A" then
        return QuestiePlayer.faction == "Alliance"
    end

    return false
end

---------------------------------------------------------------------------------------------------
-- Modifications to objectDB
function _QuestieDB:DeleteGatheringNodes()
    local prune = { -- gathering nodes
        1617,1618,1619,1620,1621,1622,1623,1624,1628, -- herbs

        1731,1732,1733,1734,1735,123848,150082,175404,176643,177388,324,150079,176645,2040,123310 -- mining
    }
    local objectSpawnsKey = QuestieDB.objectKeys.spawns
    for i=1, #prune do
        local id = prune[i]
        QuestieDB.objectData[id][objectSpawnsKey] = nil
    end
end

---------------------------------------------------------------------------------------------------
-- Modifications to questDB

-- Quests where the reputation only goes in one direction (ex. Thorium Brotherhood)
QuestieDB.questsOnlyAvailableUntilReputationValue = {
    -- Thorium Brotherhood
    [7736] = true, -- Restoring Fiery Flux Supplies via Kingsblood
    [7737] = true, -- Gaining Acceptance
    [8241] = true, -- Restoring Fiery Flux Supplies via Iron
    [8242] = true, -- Restoring Fiery Flux Supplies via Heavy Leather

    -- Brood of Nozdormu
    [8302] = true, -- The Hand of the Righteous

    -- Argent Dawn
    [9221] = true, -- Superior Armaments of Battle - Friend of the Dawn
    [9222] = true, -- Epic Armaments of Battle - Friend of the Dawn
    [9223] = true, -- Superior Armaments of Battle - Honored Amongst the Dawn
    [9224] = true, -- Epic Armaments of Battle - Honored Amongst the Dawn
    [9225] = true, -- Epic Armaments of Battle - Revered Amongst the Dawn
    [9226] = true, -- Superior Armaments of Battle - Revered Amongst the Dawn
    [28755] = true, -- Annals of the Silver Hand
    [28756] = true, -- Aberrations of Bone

    -- Consortium
    [9882] = true, -- Stealing from Thieves
    [9883] = true, -- More Crystal Fragments
    [9884] = true, -- Membership Benefits
    [9885] = true, -- Membership Benefits
    [9886] = true, -- Membership Benefits
    [9914] = true, -- A Head Full of Ivory
    [9915] = true, -- More Heads Full of Ivory

    -- Cenarion Expedition
    [9784] = true, -- Identify Plant Parts
    --[9802] = true, -- Plants of Zangarmarsh -- TO DO CHECK THIS
    [9875] = true, -- Uncatalogued Species

    -- Sporregar
    --[9739] = true, -- The Sporelings' Plight -- TO DO CHECK THIS
    [9742] = true, -- More Spore Sacs
    --[9743] = true, -- Natural Enemies -- TO DO CHECK THIS
    [9744] = true, -- More Tendrils!
    --[9808] = true, -- Glowcap Mushrooms -- TO DO CHECK THIS
    [9809] = true, -- More Glowcaps

    -- Lower City
    --[10917] = true, -- The Outcast's Plight -- TO DO CHECK THIS
    [10918] = true, -- More Feathers

    -- Order of the Cloud Serpent
    [31784] = true, -- Onyx To Goodness
}

function _QuestieDB:CheckAchievementRequirements(questId)
    -- So far the only Quests that we know of that requires an earned Achievement are the ones offered by:
    -- https://www.wowhead.com/wotlk/npc=35094/crusader-silverdawn
    -- Get Kraken (14108)
    -- The Fate Of The Fallen (14107)
    -- This NPC requires these earned Achievements baseed on a Players home faction:
    -- https://www.wowhead.com/wotlk/achievement=2817/exalted-argent-champion-of-the-alliance
    -- https://www.wowhead.com/wotlk/achievement=2816/exalted-argent-champion-of-the-horde
    if questId == 14101 or questId == 14102 or questId == 14104 or questId == 14105 or questId == 14107 or questId == 14108 then
        local retN = QuestieCompat.Is335 and 4 or 13
        if select(retN, GetAchievementInfo(2817)) or select(retN, GetAchievementInfo(2816)) then
            return true
        end

        return false
    end
end

function _QuestieDB:HideClassAndRaceQuests()
    local questKeys = QuestieDB.questKeys
    for _, entry in pairs(QuestieDB.questData) do
        -- check requirements, set hidden flag if not met
        local requiredClasses = entry[questKeys.requiredClasses]
        if (requiredClasses) and (requiredClasses ~= 0) then
            if (not QuestiePlayer.HasRequiredClass(requiredClasses)) then
                entry.hidden = true
            end
        end
        local requiredRaces = entry[questKeys.requiredRaces]
        if (requiredRaces) and (requiredRaces ~= 0) and (requiredRaces ~= 255) then
            if (not QuestiePlayer.HasRequiredRace(requiredRaces)) then
                entry.hidden = true
            end
        end
    end
    Questie:Debug(Questie.DEBUG_DEVELOP, "Other class and race quests hidden");
end

-- This function is intended for usage with Gossip and Greeting frames, where there's a list of quests but no QuestIDs are
-- obtainable until entering the specific quest dialog.
-- This is a bruteforce method for obtaining a QuestID with no input other than a quest name, and the ID of the questgiver.
-- It compares the name of the quest entry with the names of every quest that questgiver can either start or end.
---@param name string? @The name of the quest entry
---@param questgiverGUID string? @Should be UnitGUID("questnpc")
---@param questStarter boolean @Should be True if this is an available quest, False if this is an "active" quest (quest ender)
---@return number
function QuestieDB.GetQuestIDFromName(name, questgiverGUID, questStarter)
    local questID = 0 -- worst case, we end up returning an ID of 0 if we can't find a match; any function relying on this one should handle 0 cleanly
    if questgiverGUID then
        local questgiverID = tonumber(questgiverGUID:match("-(%d+)-%x+$"), 10)
        local unit_type = strsplit("-", questgiverGUID)
        local questsStarted
        local questsEnded
        if unit_type == "Creature" then -- if questgiver is an NPC
            questsStarted = QuestieDB.QueryNPCSingle(questgiverID, "questStarts")
            questsEnded = QuestieDB.QueryNPCSingle(questgiverID, "questEnds")
        elseif unit_type == "GameObject" then -- if questgiver is an object (it's rare for an object to have a gossip/greeting frame, but Wanted Boards exist; see object 2713)
            questsStarted = QuestieDB.QueryObjectSingle(questgiverID, "questStarts")
            questsEnded = QuestieDB.QueryObjectSingle(questgiverID, "questEnds")
        else
            return questID; -- If the questgiver is not an NPC or object, bail!
        end
        -- iterate through every questEnds entry in our questgiver's DB, and check if each quest name matches this greeting frame entry
        if questStarter == true then
            if questsStarted then
                for _, id in pairs(questsStarted) do
                    if (name == QuestieDB.QueryQuestSingle(id, "name")) and (QuestieDB.IsDoable(id)) then
                        -- the QuestieDB.IsDoable check is important to filter out identically named quests
                        questID = id
                    end
                end
            else
                Questie:Debug(Questie.DEBUG_ELEVATED, "Database mismatch! No entries found that match quest name. Queststarter is: " .. unit_type .. " " .. questgiverID .. ", quest name is: " .. name)
            end
        else
            if questsEnded then
                for _, id in pairs(questsEnded) do
                    if (name == QuestieDB.QueryQuestSingle(id, "name")) and (QuestieDB.IsDoable(id)) and QuestiePlayer.currentQuestlog[id] then
                        questID = id
                    end
                end
            else
                Questie:Debug(Questie.DEBUG_ELEVATED, "Database mismatch! No entries found that match quest name. Questender is: " .. unit_type .. " " .. questgiverID .. ", quest name is: " .. name)
            end
        end
    end
    return questID;
end

QuestieDB.waypointPresets = {
    ORGRIMS_HAMMER = {[ZoneDB.zoneIDs.ICECROWN]={{{62.37,30.60},{61.93,30.93},{61.48,31.24},{61.08,31.55},{60.74,31.92},{60.46,32.44},{60.26,33.11},{60.14,33.85},{60.11,34.63},{60.17,35.35},{60.31,36.01},{60.56,36.66},{60.84,37.33},{61.15,38.00},{61.44,38.67},{61.71,39.28},{62.00,39.92},{62.31,40.55},{62.60,41.20},{62.90,41.83},{63.05,42.20},{63.33,42.85},{63.58,43.53},{63.85,44.19},{64.08,44.86},{64.33,45.50},{64.45,45.87},{64.69,46.56},{64.94,47.21},{65.16,47.87},{65.43,48.51},{65.71,49.15},{66.03,49.77},{66.36,50.46},{66.72,51.10},{67.07,51.67},{67.41,52.08},{67.82,52.37},{68.31,52.47},{68.80,52.38},{69.23,51.98},{69.45,51.56},{69.57,51.13},{69.67,50.59},{69.73,49.96},{69.77,49.26},{69.79,48.48},{69.80,47.62},{69.79,46.68},{69.79,45.68},{69.78,44.90},{69.78,44.25},{69.76,43.55},{69.75,42.80},{69.72,42.01},{69.70,41.20},{69.67,40.38},{69.64,39.54},{69.61,38.71},{69.58,37.88},{69.55,37.07},{69.52,36.28},{69.49,35.54},{69.46,34.83},{69.45,34.18},{69.42,33.50},{69.41,32.46},{69.42,31.52},{69.45,30.67},{69.47,29.92},{69.48,29.25},{69.46,28.65},{69.42,28.12},{69.35,27.83},{69.11,27.19},{68.71,26.77},{68.23,26.54},{67.71,26.51},{67.24,26.55},{66.81,26.76},{66.35,27.09},{65.90,27.52},{65.44,27.95},{65.01,28.39},{64.58,28.73},{64.16,29.10},{63.74,29.43},{63.34,29.79},{62.94,30.11},{62.65,30.37},{62.37,30.60}}}},
    THE_SKYBREAKER = {[ZoneDB.zoneIDs.ICECROWN]={{{63.59,52.34},{63.44,51.88},{63.30,51.52},{63.15,51.19},{63.01,50.85},{62.85,50.52},{62.68,50.17},{62.50,49.78},{62.31,49.36},{62.09,48.88},{61.86,48.33},{61.81,48.20},{61.67,47.88},{61.52,47.52},{61.37,47.13},{61.19,46.74},{61.02,46.32},{60.84,45.88},{60.65,45.44},{60.46,44.99},{60.28,44.53},{60.09,44.08},{59.90,43.63},{59.72,43.18},{59.54,42.75},{59.36,42.34},{59.20,41.94},{59.04,41.56},{58.89,41.22},{58.75,40.87},{58.52,40.30},{58.32,39.77},{58.14,39.27},{57.97,38.80},{57.81,38.39},{57.65,38.03},{57.49,37.72},{57.31,37.50},{57.12,37.34},{56.87,37.29},{56.57,37.39},{56.27,37.60},{55.97,37.88},{55.72,38.23},{55.53,38.61},{55.43,38.95},{55.43,39.09},{55.46,39.49},{55.52,39.92},{55.62,40.39},{55.76,40.88},{55.89,41.38},{56.02,41.85},{56.17,42.25},{56.33,42.68},{56.51,43.13},{56.70,43.56},{56.88,43.99},{57.05,44.39},{57.22,44.74},{57.42,45.15},{57.64,45.52},{57.83,45.81},{58.03,46.14},{58.23,46.56},{58.41,46.90},{58.60,47.25},{58.80,47.62},{59.00,48.03},{59.19,48.46},{59.36,48.84},{59.53,49.22},{59.69,49.63},{59.86,50.04},{60.03,50.46},{60.19,50.90},{60.36,51.32},{60.51,51.74},{60.65,52.17},{60.79,52.59},{60.94,53.02},{61.07,53.46},{61.23,53.89},{61.39,54.30},{61.55,54.72},{61.70,55.18},{61.88,55.65},{62.05,56.14},{62.23,56.58},{62.43,56.95},{62.65,57.21},{62.87,57.30},{62.95,57.27},{63.22,57.16},{63.52,56.97},{63.81,56.68},{64.07,56.32},{64.26,55.91},{64.33,55.47},{64.30,55.11},{64.25,54.72},{64.16,54.30},{64.04,53.84},{63.91,53.36},{63.76,52.88},{63.59,52.34}}}},
}

return QuestieDB
