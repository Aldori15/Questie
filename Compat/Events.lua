---@type QuestieEventHandler
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")

local _EventHandler = QuestieEventHandler.private

function QuestieCompat.QuestieEventHandler_RegisterLateEvents()
    -- In fullscreen mode, WorldMap intercepts keyboard input,
    -- preventing the MODIFIER_STATE_CHANGED event
    if WorldMapFrame:GetScript("OnKeyDown") then
        local modifierStateChanged
        WorldMapFrame:HookScript("OnKeyDown", function(self, key)
            if IsModifierKeyDown() then
                _EventHandler:ModifierStateChanged(key, 1)
                modifierStateChanged = true
            end
        end)
        WorldMapFrame:HookScript("OnKeyUp", function(self, key)
            if modifierStateChanged then
                _EventHandler:ModifierStateChanged(key, 0)
                modifierStateChanged = nil
            end
        end)
    end

    Questie:UnregisterEvent("MAP_EXPLORATION_UPDATED") -- https://wowpedia.fandom.com/wiki/MAP_EXPLORATION_UPDATED
    Questie:UnregisterEvent("NEW_RECIPE_LEARNED")

    -- Party join event for QuestieComms, Use bucket to hinder this from spamming (Ex someone using a raid invite addon etc)
    Questie:UnregisterEvent("GROUP_ROSTER_UPDATE") -- https://wowpedia.fandom.com/wiki/GROUP_ROSTER_UPDATE
    Questie:UnregisterEvent("GROUP_JOINED") -- https://wowpedia.fandom.com/wiki/GROUP_JOINED
    Questie:UnregisterEvent("GROUP_LEFT") -- https://wowpedia.fandom.com/wiki/GROUP_LEFT
    Questie:RegisterEvent("PARTY_MEMBERS_CHANGED", QuestieCompat.GroupRosterUpdate)
    Questie:RegisterBucketEvent("RAID_ROSTER_UPDATE", 1, QuestieCompat.GroupRosterUpdate)

    QuestieCompat.RegisterNameplateCompatibilityEvents()

    -- Use loot events as additional sync points for tracker refreshes.
    Questie:RegisterEvent("LOOT_SLOT_CLEARED", QuestieCompat.LOOT_SLOT_CLEARED)
    Questie:RegisterEvent("LOOT_CLOSED", QuestieCompat.LOOT_CLOSED)
end

function QuestieCompat.RegisterEventCompatibilityHooks()
    QuestieEventHandler.private.UiInfoMessage = QuestieCompat.UiInfoMessage
    hooksecurefunc(QuestieEventHandler, "RegisterLateEvents", QuestieCompat.QuestieEventHandler_RegisterLateEvents)
    hooksecurefunc(QuestEventHandler, "RegisterEvents", QuestieCompat.QuestEventHandler_RegisterEvents)
end
