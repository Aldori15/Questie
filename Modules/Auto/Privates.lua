---@type QuestieAuto
local QuestieAuto = QuestieLoader:ImportModule("QuestieAuto")
QuestieAuto.private = QuestieAuto.private or {}

---@class QuestieAutoPrivate
---@field disallowedNPCs table<NpcId, boolean>
---@field disallowedNPC table<NpcId, boolean>
---@field disallowedQuests table
local _QuestieAuto = QuestieAuto.private

--- COMPATIBILITY ---
local UnitGUID = QuestieCompat.UnitGUID
local GetQuestID = QuestieCompat.GetQuestID

local bindTruthTable = {
    ["shift"] = function() return IsShiftKeyDown() end,
    ["ctrl"] = function() return IsControlKeyDown() end,
    ["alt"] = function() return IsAltKeyDown() end,
    ["disabled"] = function() return false end,
}

function _QuestieAuto:AllQuestWindowsClosed()
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

function _QuestieAuto:IsAllowedNPC()
    local npcGuid = UnitGUID("npc") or UnitGUID("questnpc") or UnitGUID("target")
    local disallowedNPCs = self.disallowedNPCs or self.disallowedNPC or {}

    if npcGuid then
        local _, _, _, _, _, npcIDStr = strsplit("-", npcGuid)
        if npcIDStr then
            local npcId = tonumber(npcIDStr)
            return not disallowedNPCs[npcId]
        end
    end

    return true
end

function _QuestieAuto:IsAllowedQuest(questStarter, title, turnIn)
    local questId = GetQuestID(questStarter, title)
    if questId and questId > 0 then
        local disallowedQuests = self.disallowedQuests or {}
        if disallowedQuests.accept or disallowedQuests.turnIn then
            local questBucket = turnIn and disallowedQuests.turnIn or disallowedQuests.accept
            if questBucket and questBucket[questId] then
                return false
            end
        elseif disallowedQuests[questId] then
            return false
        end
    end

    return true
end

function _QuestieAuto:IsBindTrue(bind)
    return bind and bindTruthTable[bind]()
end
