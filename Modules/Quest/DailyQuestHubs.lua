---@type DailyQuests
local DailyQuests = QuestieLoader:ImportModule("DailyQuests")

---@alias HubId string

---@class Hub
---@field quests QuestId[]
---@field limit number
---@field exclusiveHubs table<HubId, boolean>
---@field preQuestHubsSingle table<HubId, boolean>
---@field preQuestHubsGroup table<HubId, boolean>
---@field IsActive? function(completedQuests: table<QuestId, boolean>, questLog: table<QuestId, Quest>): boolean

-- WotLK 3.3.5 daily quest hub definitions.
-- Hub IDs are string keys. The logic in DailyQuests.lua iterates this table;
-- exclusiveHubs uses sibling hub ID strings as keys.
--
-- limit = number of completions that causes the hub to be considered "done" for
-- the day. For rotating single-daily pools (cooking/fishing) use 1. For hubs
-- where all quests are available every day, use the total quest count.
--
-- Sources: quest_template.sql (Flags & 4096 = daily), sorted by QuestSortID,
-- separated by QuestRewardFactionID1 where quests are mutually exclusive.

---@type table<HubId, Hub>
DailyQuests.hubs = {
    -- -------------------------------------------------------------------------
    -- Argent Tournament  (Icecrown, level 80, QuestSortID -241)
    -- Valiant, Champion and guest-faction dailies all in one pool.
    -- limit = total because the server offers the full set on each reset.
    -- -------------------------------------------------------------------------
    ["argent_tournament"] = {
        -- Requires having enrolled at the tournament by completing the
        -- registration quest from the Tournament Herald outside the main tent.
        -- Alliance = 13667, Horde = 13668 ("The Argent Tournament").
        IsActive = function(completedQuests)
            return completedQuests[13667] or completedQuests[13668]
        end,
        quests = {
            13592, 13600, 13603, 13616, 13625, 13627,
            13665, 13666, 13669, 13670, 13671, 13673, 13674, 13675,
            13676, 13677, 13681, 13682,
            13741, 13742, 13743, 13744, 13745, 13746, 13747, 13748,
            13749, 13750, 13752, 13753, 13754, 13755, 13756, 13757,
            13758, 13759, 13760, 13761, 13762, 13763, 13764, 13765,
            13767, 13768, 13769, 13770, 13771, 13772, 13773, 13774,
            13775, 13776, 13777, 13778, 13779, 13780, 13781, 13782,
            13783, 13784, 13785, 13786, 13787, 13788, 13789, 13790,
            13791, 13793,
            13809, 13810, 13811, 13812, 13813, 13814,
            13846, 13847, 13851, 13852, 13854, 13855, 13856, 13857,
            13858, 13859, 13860, 13861, 13862, 13863, 13864,
            14074, 14076, 14077, 14080, 14090, 14092, 14095, 14096,
            14101, 14102, 14104, 14105, 14107, 14108, 14112, 14136,
            14140, 14141, 14142, 14143, 14144, 14145, 14152,
        },
        limit = 112,
    },

    -- -------------------------------------------------------------------------
    -- Icecrown  (level 80, QuestSortID 210)
    -- Death's Rise / Shadow Vault / Argent Vanguard / Ymirheim
    -- -------------------------------------------------------------------------
    ["icecrown"] = {
        quests = {
            12813, 12815, 12838, 12995,
            13069, 13071,
            13233, 13234, 13261, 13276, 13280, 13281, 13283, 13284,
            13289, 13292, 13297, 13300, 13301, 13302, 13309, 13310,
            13322, 13323, 13330, 13331, 13333, 13336, 13344, 13350,
            13353, 13357, 13365, 13368, 13376, 13382, 13404, 13406,
        },
        limit = 38,
    },

    -- -------------------------------------------------------------------------
    -- Storm Peaks – K3 / Frosthold  (QuestSortID 67)
    -- "Overstock" (12833) and "Pushed Too Far" (12869).
    -- Prereqs are normal zone quests that players complete on the way through;
    -- no IsActive needed at level 80.
    -- -------------------------------------------------------------------------
    ["storm_peaks_k3"] = {
        quests = {
            12833, -- Overstock          (K3, Ricket)
            12869, -- Pushed Too Far     (Frosthold, Fjorlin Frostbrow)
        },
        limit = 2,
    },

    -- -------------------------------------------------------------------------
    -- Storm Peaks – Sons of Hodir  (QuestSortID 67, faction 1119)
    -- Unlocked by completing "A Monument to the Fallen" (12976), the last quest
    -- of the Sons of Hodir intro chain before the first daily (12977) opens.
    -- Individual quests also require varying rep levels (Friendly → Revered),
    -- so the server won't offer all six until those thresholds are met.
    -- -------------------------------------------------------------------------
    ["storm_peaks_sohodir"] = {
        IsActive = function(completedQuests)
            return completedQuests[12976]  -- "A Monument to the Fallen"
        end,
        quests = {
            12977, -- Blowing Hodir's Horn       (Friendly+)
            12981, -- Hot and Cold               (Friendly+)
            12994, -- Spy Hunter                 (Honored+)
            13003, -- Thrusting Hodir's Spear    (Honored+)
            13006, -- Polishing the Helm         (Friendly+)
            13046, -- Feeding Arngrim            (Revered+)
        },
        limit = 6,
    },

    -- -------------------------------------------------------------------------
    -- Storm Peaks – Brunnhildar Village  (QuestSortID 67)
    -- Gretta the Arbiter's dailies.  Unlocked by completing "The Drakkensryd"
    -- (12886), the final Hyldsmeet quest that grants you Hyldnir acceptance.
    -- -------------------------------------------------------------------------
    ["storm_peaks_brunnhildar"] = {
        IsActive = function(completedQuests)
            return completedQuests[12886]  -- "The Drakkensryd"
        end,
        quests = {
            13422, -- Maintaining Discipline
            13423, -- Defending Your Title
            13424, -- Back to the Pit
            13425, -- The Hyldsmeet: Prelims
        },
        limit = 4,
    },

    -- -------------------------------------------------------------------------
    -- Sholazar Basin – Oracles  (QuestSortID 3711, RewardFactionID 1105)
    -- Mutually exclusive with the Frenzyheart hub below.
    -- -------------------------------------------------------------------------
    ["sholazar_oracles"] = {
        -- Requires completing "A Hero's Burden" (12581), the Artruis kill
        -- where the player chooses to side with the Oracles.
        IsActive = function(completedQuests)
            return completedQuests[12581]
        end,
        quests = {
            12689, -- Hand of the Oracles
            12704, -- Appeasing the Great Rain Stone
            12705, -- Will of the Titans
            12726, -- Song of Wind and Water
            12735, -- A Cleansing Song
            12736, -- Song of Reflection
            12737, -- Song of Fecundity
            12761, -- Mastery of the Crystals
            12762, -- Power of the Great Ones
        },
        limit = 9,
        exclusiveHubs = { ["sholazar_frenzyheart"] = true },
    },

    -- -------------------------------------------------------------------------
    -- Sholazar Basin – Frenzyheart  (QuestSortID 3711, RewardFactionID 1104)
    -- Mutually exclusive with the Oracles hub above.
    -- -------------------------------------------------------------------------
    ["sholazar_frenzyheart"] = {
        -- Same gate as Oracles: the Artruis choice quest (12581).
        -- exclusiveHubs already prevents both showing simultaneously.
        IsActive = function(completedQuests)
            return completedQuests[12581]
        end,
        quests = {
            12582, -- Frenzyheart Champion
            12702, -- Chicken Party!
            12703, -- Kartak's Rampage
            12732, -- The Heartblood's Strength
            12734, -- Rejek: First Blood
            12741, -- Strength of the Tempest
            12758, -- A Hero's Headgear
            12759, -- Tools of War
            12760, -- Secret Strength of the Frenzyheart
        },
        limit = 9,
        exclusiveHubs = { ["sholazar_oracles"] = true },
    },

    -- -------------------------------------------------------------------------
    -- Zul'Drak – Argent Stand  (level 76, QuestSortID 66)
    -- -------------------------------------------------------------------------
    ["zul_drak"] = {
        -- Requires completing "Pa'Troll" (12596), the Argent Stand intro patrol
        -- quest that unlocks all Argent Stand dailies in Zul'Drak.
        IsActive = function(completedQuests)
            return completedQuests[12596]
        end,
        quests = {
            12501, 12502, 12509, 12519, 12541,
            12563, 12564, 12568, 12585, 12587,
            12588, 12591, 12594, 12601, 12602, 12604,
        },
        limit = 16,
    },

    -- -------------------------------------------------------------------------
    -- Grizzly Hills  (level 72-74, QuestSortID 394)
    -- Includes Granite Springs, Venture Bay, Blackriver, Blue Sky Logging
    -- -------------------------------------------------------------------------
    ["grizzly_hills"] = {
        quests = {
            12038, 12170, 12244, 12268, 12270, 12280,
            12284, 12288, 12289, 12296, 12314, 12315,
            12316, 12317, 12323, 12324, 12432, 12437, 12444,
        },
        limit = 19,
    },

    -- -------------------------------------------------------------------------
    -- Dragonblight – Wyrmrest Temple  (QuestSortID 65)
    -- 11960 "Defending Wyrmrest Temple" has no prereq.
    -- 12372 "Wyrmrest Imperative" requires "Report to Lord Afrasastrasz" (12435).
    -- -------------------------------------------------------------------------
    ["dragonblight_wyrmrest_defend"] = {
        quests = {
            11960, -- Defending Wyrmrest Temple
        },
        limit = 1,
    },

    ["dragonblight_wyrmrest_imperative"] = {
        IsActive = function(completedQuests)
            return completedQuests[12435]  -- "Report to Lord Afrasastrasz"
        end,
        quests = {
            12372, -- Wyrmrest Imperative
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Coldarra – Transitus Shield  (QuestSortID 4024)
    -- "Drake Hunt" daily (11940) requires the non-daily intro (11919).
    -- -------------------------------------------------------------------------
    ["coldarra_drake_hunt"] = {
        IsActive = function(completedQuests)
            return completedQuests[11919]  -- "Drake Hunt" (non-daily intro)
        end,
        quests = {
            11940, -- Drake Hunt  (Transitus Shield)
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Coldarra – Oculus  (QuestSortID 4024)
    -- "Aces High!" daily (13414) requires the intro "Aces High!" (13413).
    -- -------------------------------------------------------------------------
    ["coldarra_aces_high"] = {
        IsActive = function(completedQuests)
            return completedQuests[13413]  -- "Aces High!" (non-daily intro)
        end,
        quests = {
            13414, -- Aces High!  (upper ring of the Nexus)
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Kalu'ak  (QuestSortID 3537)
    -- Borean Tundra confirmed; Kamagua/Moa'ki quests may lack the daily flag.
    -- -------------------------------------------------------------------------
    ["kalu_ak"] = {
        quests = {
            11945, -- Preparing for the Worst  (Kaskala)
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Dalaran Cooking Daily  (QuestSortID -304, WotLK pool, level-independent)
    -- Exactly one quest is offered each day; limit = 1 hides the rest once done.
    -- -------------------------------------------------------------------------
    ["dalaran_cooking"] = {
        quests = {
            13100, -- Infused Mushroom Meatloaf
            13101, -- Cheese for Glowergold
            13102, -- Convention at the Legerdemain
            13103, -- Sewer Stew
            13107, -- Mustard Dogs!
            13112, -- Cooking with Style
            13113, -- Feeling Crabby?
            13114, -- Crawfish Creole
            13115, -- Identifying the Correct Vendor
            13116, -- Kung Fu Cooking
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Dalaran Fishing Daily  (QuestSortID -101, WotLK pool, level 80)
    -- Exactly one quest is offered each day; limit = 1 hides the rest once done.
    -- -------------------------------------------------------------------------
    ["dalaran_fishing"] = {
        quests = {
            13692, -- The Sword and the Sea
            13830, -- Dangerously Delicious
            13832, -- Blood Is Thicker
            13833, -- Jewel of the Sewers
            13834, -- Monsterbelly Appetite
            13836, -- Terror of the Tainted Reef
        },
        limit = 1,
    },

    -- -------------------------------------------------------------------------
    -- Northrend Heroic Daily  (level 80; Proof of Demise + Archmage Timear)
    -- Each heroic dungeon has its own independent daily; all are available daily.
    -- -------------------------------------------------------------------------
    ["northrend_heroic"] = {
        quests = {
            13190, -- All Things in Good Time   (Azjol-Nerub)
            13240, 13241, 13243,
            13244, -- Timear Foresees Titanium Vanguards
            13245, 13246, 13247,
            13248, -- Proof of Demise: King Ymiron
            13249, 13250, 13251, 13252, 13253,
            13254, -- Proof of Demise: Anub'arak
            13255,
            13256, -- Proof of Demise: Cyanigosa
            14199, -- Proof of Demise: The Black Knight  (Trial of the Champion)
        },
        limit = 18,
    },

    -- -------------------------------------------------------------------------
    -- Call to Arms  (battleground daily rotation, all factions)
    -- Only one battleground is the "Call to Arms" each day;
    -- Each BG has an Alliance and a Horde version (hence two IDs per BG).
    -- -------------------------------------------------------------------------
    ["call_to_arms"] = {
        quests = {
            13427, 13428, -- Alterac Valley         (QuestSortID 2597)
            14178, 14181, -- Arathi Basin           (QuestSortID 3358)
            14179, 14182, -- Eye of the Storm       (QuestSortID 3820)
            14180, 14183, -- Warsong Gulch          (QuestSortID 3277)
            13405, 13407, -- Strand of the Ancients (QuestSortID 4384)
            14163, 14164, -- Isle of Conquest       (QuestSortID 4710)
        },
        limit = 1,
    },
}
