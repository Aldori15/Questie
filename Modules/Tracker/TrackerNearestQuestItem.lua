---@class TrackerNearestQuestItem
local TrackerNearestQuestItem = QuestieLoader:CreateModule("TrackerNearestQuestItem")

---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local C_Timer = QuestieCompat.C_Timer

-- The hidden secure button also serves players who disable the tracker.
-- Keep its name stable because Bindings.xml and saved bindings refer to it.
local nearestQuestItemButton

---@param quest Quest
---@return ItemId|nil
local function _GetUsableClickQuestItemId(quest)
    if not quest then
        return nil
    end

    local items = TrackerUtils:GetUsableQuestItemIds(quest)
    if quest:IsComplete() == 1 then
        local isComplete = (quest.isComplete ~= true and #quest.Objectives == 0) or quest.isComplete == true
        local primaryItem = items[1]
        if not isComplete or not primaryItem or not GetItemSpell(primaryItem) then
            return nil
        end

        local sourceItemId = quest.sourceItemId
        if sourceItemId == nil then
            sourceItemId = QuestieDB.QueryQuestSingle(quest.Id, "sourceItemId")
        end
        if primaryItem == sourceItemId then
            return primaryItem
        end
        for _, itemId in pairs(quest.requiredSourceItems or {}) do
            if itemId == primaryItem then
                return primaryItem
            end
        end
        return nil
    end

    for _, itemId in ipairs(items) do
        -- The keybind is specifically for USING an item.
        if GetItemSpell(itemId) then
            return itemId
        end
    end

    return nil
end

---@return ItemId|nil
local function _GetNearestQuestItemId()
    -- Prefer the quest Questie is currently routing to.
    -- This covers both manually selected Questie/TomTom targets and AutoRoute,
    -- because both store quest ownership in _tom_waypoint_quest.
    local waypointQuest = TrackerUtils:GetTomTomTarget() and Questie.db.char._tom_waypoint_quest

    if waypointQuest and waypointQuest.questId then
        local quest = QuestiePlayer.currentQuestlog[waypointQuest.questId]
        local itemId = _GetUsableClickQuestItemId(quest)

        if itemId then
            return itemId
        end
    end

    -- With Questie's tracker enabled, respect its tracked quests. When disabled,
    -- consider the whole quest log so the keybind does not depend on Blizzard watches.
    local bestItemId
    local bestDistance
    local bestQuestId

    for questId, quest in pairs(QuestiePlayer.currentQuestlog or {}) do
        if quest and (not Questie.db.profile.trackerEnabled or QuestieQuest:IsQuestTracked(questId)) then
            local itemId = _GetUsableClickQuestItemId(quest)

            if itemId then
                local _, _, _, _, _, distance = QuestieMap:GetNearestQuestSpawn(quest)

                if type(distance) == "number" and ((not bestDistance) or distance < bestDistance or (distance == bestDistance and questId < bestQuestId)) then
                    bestItemId = itemId
                    bestDistance = distance
                    bestQuestId = questId
                end
            end
        end
    end

    return bestItemId
end

local function _UpdateNearestQuestItemButton()
    if not nearestQuestItemButton or InCombatLockdown() then
        return
    end

    local itemId = _GetNearestQuestItemId()

    -- Secure attributes cannot be changed in combat, so only update them here.
    -- Also avoid rewriting the same secure attribute unnecessarily.
    if nearestQuestItemButton.questieItemId == itemId then
        return
    end

    nearestQuestItemButton.questieItemId = itemId
    nearestQuestItemButton:SetAttribute("item", itemId and ("item:" .. itemId) or nil)
end

function TrackerNearestQuestItem.Initialize()
    if nearestQuestItemButton then
        return
    end

    nearestQuestItemButton = CreateFrame("Button", "Questie_NearestQuestItemButton", UIParent, "SecureActionButtonTemplate")

    nearestQuestItemButton:SetAttribute("type", "item")
    nearestQuestItemButton:RegisterForClicks("AnyDown")
    nearestQuestItemButton:Hide()

    _UpdateNearestQuestItemButton()

    -- Re-evaluate periodically because proximity can change simply by moving.
    -- During combat the existing secure selection remains untouched.
    C_Timer.NewTicker(5, _UpdateNearestQuestItemButton)
end

function TrackerNearestQuestItem.SetupKeybinding()
    _G["BINDING_NAME_CLICK Questie_NearestQuestItemButton:LeftButton"] = l10n("Use Nearest Quest Item")
end
