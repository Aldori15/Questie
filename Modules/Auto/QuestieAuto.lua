---@class QuestieAuto
---@field public private QuestieAutoPrivate
local QuestieAuto = QuestieLoader:CreateModule("QuestieAuto")
QuestieAuto.private = QuestieAuto.private or {}

---@class QuestieAutoPrivate
local _QuestieAuto = QuestieAuto.private

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local GetQuestID = QuestieCompat.GetQuestID
local UnitGUID = QuestieCompat.UnitGUID

local shouldRunAuto = true

local _AllQuestWindowsClosed
local _GetAutoAcceptSettings
local _GetQuestGiverGuid
local _GetStructuredActiveQuests
local _GetStructuredAvailableQuests
local _IsAllowedNPC
local _IsQuestAllowedToAccept
local _IsQuestAllowedToTurnIn
local _ShouldAutoAcceptQuest
local _StartStoppedTalkingTimer

local bindTruthTable = {
    ["shift"] = function() return IsShiftKeyDown() end,
    ["ctrl"] = function() return IsControlKeyDown() end,
    ["alt"] = function() return IsAltKeyDown() end,
    ["disabled"] = function() return false end,
}

_GetAutoAcceptSettings = function()
    local autoAccept = Questie.db.profile.autoAccept
    if type(autoAccept) ~= "table" then
        autoAccept = {
            enabled = Questie.db.profile.autoaccept or false,
            trivial = Questie.db.profile.acceptTrivial or false,
            repeatable = true,
            pvp = true,
            rejectSharedInBattleground = Questie.db.profile.autoreject_battleground or false,
        }
        Questie.db.profile.autoAccept = autoAccept
    end

    if autoAccept.enabled == nil then
        autoAccept.enabled = Questie.db.profile.autoaccept or false
    end
    if autoAccept.trivial == nil then
        autoAccept.trivial = Questie.db.profile.acceptTrivial or false
    end
    if autoAccept.repeatable == nil then
        autoAccept.repeatable = true
    end
    if autoAccept.pvp == nil then
        autoAccept.pvp = true
    end
    if autoAccept.rejectSharedInBattleground == nil then
        autoAccept.rejectSharedInBattleground = Questie.db.profile.autoreject_battleground or false
    end

    return autoAccept
end

_GetQuestGiverGuid = function()
    return UnitGUID("npc") or UnitGUID("questnpc") or UnitGUID("target")
end

_GetStructuredAvailableQuests = function()
    local rawAvailableQuests = { QuestieCompat.GetAvailableQuests() }
    if type(rawAvailableQuests[1]) == "table" then
        return rawAvailableQuests
    end

    local availableQuests = {}
    for index = 1, #rawAvailableQuests, 7 do
        local title = rawAvailableQuests[index]
        if title then
            availableQuests[#availableQuests + 1] = {
                title = title,
                questLevel = rawAvailableQuests[index + 1],
                isTrivial = rawAvailableQuests[index + 2],
                frequency = rawAvailableQuests[index + 3],
                repeatable = rawAvailableQuests[index + 4],
                isLegendary = rawAvailableQuests[index + 5],
                isIgnored = rawAvailableQuests[index + 6],
                questID = GetQuestID(true, title),
            }
        end
    end

    return availableQuests
end

_GetStructuredActiveQuests = function()
    local rawActiveQuests = { QuestieCompat.GetActiveQuests() }
    if type(rawActiveQuests[1]) == "table" then
        return rawActiveQuests
    end

    local activeQuests = {}
    for index = 1, #rawActiveQuests, 6 do
        local title = rawActiveQuests[index]
        if title then
            activeQuests[#activeQuests + 1] = {
                title = title,
                questLevel = rawActiveQuests[index + 1],
                isTrivial = rawActiveQuests[index + 2],
                isComplete = rawActiveQuests[index + 3],
                isLegendary = rawActiveQuests[index + 4],
                isIgnored = rawActiveQuests[index + 5],
                questID = GetQuestID(false, title),
            }
        end
    end

    return activeQuests
end

_IsAllowedNPC = function()
    local npcGuid = _GetQuestGiverGuid()
    if npcGuid then
        local _, _, _, _, _, npcIDStr = strsplit("-", npcGuid)
        if npcIDStr then
            local npcId = tonumber(npcIDStr)
            local disallowedNPCs = _QuestieAuto.disallowedNPCs or _QuestieAuto.disallowedNPC or {}
            if disallowedNPCs[npcId] then
                return false
            end
        end
    end

    return true
end

_IsQuestAllowedToAccept = function(questId)
    if (not questId) or questId <= 0 then
        questId = GetQuestID(true)
    end

    if questId and questId > 0 then
        local disallowedQuests = _QuestieAuto.disallowedQuests
        if disallowedQuests and disallowedQuests.accept then
            return not disallowedQuests.accept[questId]
        elseif disallowedQuests then
            return not disallowedQuests[questId]
        end
    end

    return true
end

_IsQuestAllowedToTurnIn = function(questId)
    if (not questId) or questId <= 0 then
        questId = GetQuestID(false)
    end

    if questId and questId > 0 then
        local disallowedQuests = _QuestieAuto.disallowedQuests
        if disallowedQuests and disallowedQuests.turnIn then
            return not disallowedQuests.turnIn[questId]
        elseif disallowedQuests then
            return not disallowedQuests[questId]
        end
    end

    return true
end

_ShouldAutoAcceptQuest = function(questId, gossipQuest)
    if not _IsQuestAllowedToAccept(questId) then
        return false
    end

    local autoAccept = _GetAutoAcceptSettings()

    local isTrivial = gossipQuest and gossipQuest.isTrivial
    if isTrivial == nil and questId and questId > 0 then
        local questLevel = QuestieDB.QueryQuestSingle(questId, "questLevel")
        if questLevel then
            isTrivial = QuestieDB.IsTrivial(questLevel)
        end
    end
    if (not autoAccept.trivial) and isTrivial then
        return false
    end

    local isRepeatable = gossipQuest and gossipQuest.repeatable
    if isRepeatable == nil and questId and questId > 0 then
        isRepeatable = QuestieDB.IsRepeatable(questId)
    end
    if (not autoAccept.repeatable) and isRepeatable then
        return false
    end

    if (not autoAccept.pvp) and questId and questId > 0 and QuestieDB.IsPvPQuest(questId) then
        return false
    end

    return true
end

_AllQuestWindowsClosed = function()
    if ((not GossipFrame) or (not GossipFrame:IsVisible()))
        and ((not GossipFrameGreetingPanel) or (not GossipFrameGreetingPanel:IsVisible()))
        and ((not QuestFrameGreetingPanel) or (not QuestFrameGreetingPanel:IsVisible()))
        and ((not QuestFrameDetailPanel) or (not QuestFrameDetailPanel:IsVisible()))
        and ((not QuestFrameProgressPanel) or (not QuestFrameProgressPanel:IsVisible()))
        and ((not QuestFrameRewardPanel) or (not QuestFrameRewardPanel:IsVisible()))
        and ((not ImmersionFrame) or (not ImmersionFrame.TitleButtons) or (not ImmersionFrame.TitleButtons:IsVisible()))
        and ((not ImmersionContentFrame) or (not ImmersionContentFrame:IsVisible()))
    then
        return true
    end

    return false
end

_StartStoppedTalkingTimer = function()
    C_Timer.After(0.5, function()
        if (not shouldRunAuto) and _AllQuestWindowsClosed() then
            QuestieAuto.Reset()
        end
    end)
end

---@return boolean
function QuestieAuto.IsModifierHeld()
    local bind = Questie.db.profile.autoModifier
    if not bind then
        return false
    end

    return bindTruthTable[bind]()
end

function QuestieAuto.Reset()
    shouldRunAuto = true
end

function QuestieAuto.GOSSIP_SHOW()
    if (not shouldRunAuto) or QuestieAuto.IsModifierHeld() or (not _IsAllowedNPC()) then
        shouldRunAuto = false
        return
    end

    if Questie.db.profile.autocomplete then
        local completeQuests = _GetStructuredActiveQuests()
        for index = 1, #completeQuests do
            local gossipQuest = completeQuests[index]
            if gossipQuest.isComplete and _IsQuestAllowedToTurnIn(gossipQuest.questID) then
                QuestieCompat.SelectActiveQuest(index)
                return
            end
        end
    end

    local autoAccept = _GetAutoAcceptSettings()
    if autoAccept.enabled then
        local availableQuests = _GetStructuredAvailableQuests()
        for index = 1, #availableQuests do
            local gossipQuest = availableQuests[index]
            if _ShouldAutoAcceptQuest(gossipQuest.questID, gossipQuest) then
                QuestieCompat.SelectAvailableQuest(index)
                return
            end
        end
    end
end

function QuestieAuto.QUEST_GREETING()
    if (not shouldRunAuto) or QuestieAuto.IsModifierHeld() or (not _IsAllowedNPC()) then
        shouldRunAuto = false
        return
    end

    if Questie.db.profile.autocomplete then
        for index = 1, GetNumActiveQuests() do
            local questTitle, isComplete = GetActiveTitle(index)
            if isComplete and _IsQuestAllowedToTurnIn(GetQuestID(false, questTitle)) then
                SelectActiveQuest(index)
                return
            end
        end
    end

    local autoAccept = _GetAutoAcceptSettings()
    if autoAccept.enabled then
        for index = 1, GetNumAvailableQuests() do
            local questTitle = GetAvailableTitle(index)
            if _ShouldAutoAcceptQuest(GetQuestID(true, questTitle)) then
                SelectAvailableQuest(index)
                return
            end
        end
    end
end

function QuestieAuto.QUEST_DETAIL()
    local autoAccept = _GetAutoAcceptSettings()
    if (not shouldRunAuto) or (not autoAccept.enabled) or QuestieAuto.IsModifierHeld() or (not _IsAllowedNPC()) then
        return
    end

    local questNpcGuid = UnitGUID("questnpc") or _GetQuestGiverGuid()
    if autoAccept.rejectSharedInBattleground and UnitInBattleground("player") and questNpcGuid then
        local unitType = strsplit("-", questNpcGuid)
        if unitType == "Player" then
            DeclineQuest()
            Questie:Print(l10n("Automatically rejected quest shared by player."))
            return
        end
    end

    local questId = GetQuestID(true)
    if questId == 0 then
        AcceptQuest()
        return
    end

    if _ShouldAutoAcceptQuest(questId) then
        AcceptQuest()
    end
end

function QuestieAuto.QUEST_PROGRESS()
    if (not shouldRunAuto) or (not Questie.db.profile.autocomplete) or QuestieAuto.IsModifierHeld() or (not IsQuestCompletable()) or (not _IsAllowedNPC()) or (not _IsQuestAllowedToTurnIn()) then
        return
    end

    CompleteQuest()
end

function QuestieAuto.QUEST_ACCEPT_CONFIRM()
    if not _GetAutoAcceptSettings().enabled then
        return
    end

    ConfirmAcceptQuest()
end

function QuestieAuto.QUEST_COMPLETE()
    if (not shouldRunAuto) or (not Questie.db.profile.autocomplete) or QuestieAuto.IsModifierHeld() or GetNumQuestChoices() > 1 or (not _IsAllowedNPC()) or (not _IsQuestAllowedToTurnIn()) then
        return
    end

    GetQuestReward(1)
end

function QuestieAuto.QUEST_FINISHED()
    _StartStoppedTalkingTimer()
end

function QuestieAuto.GOSSIP_CLOSED()
    _StartStoppedTalkingTimer()
end

function QuestieAuto.QUEST_ACCEPTED()
    if Questie.db.profile.bugWorkarounds == true and QuestFrameDetailPanel and QuestFrameDetailPanel:IsVisible() and QuestFrameCloseButton then
        QuestFrameCloseButton:Click()
    end
end

return QuestieAuto
