---@class QuestRuntimeCorrections
local QuestRuntimeCorrections = QuestieLoader:CreateModule("QuestRuntimeCorrections")

local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")

-- Objective display ordering.
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

-- Quest and objective tooltip hints.
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

function QuestRuntimeCorrections:LoadEventTooltipTargets()
    QuestieCorrections.triggerEndTooltipTargets = QuestieDB.questEventTooltipTargets or {}
end

function QuestRuntimeCorrections:ApplyFactionFixes(overrides, addOverride)
    local factionSelections = QuestieDB.questFactionSelections

    if type(factionSelections) ~= "table" then
        error("Missing generated quest faction selections; regenerate acoreQuestDB.lua", 0)
    end

    addOverride(overrides, factionSelections)
end
