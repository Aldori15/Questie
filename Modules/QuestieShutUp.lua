---@class QuestieShutUp
local QuestieShutUp = QuestieLoader:CreateModule("QuestieShutUp")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

local stringFind = string.find
local pattern
local chatIconSize = 16
local chatIconTag = "|T" .. QuestieLib.AddonPath .. "Icons\\questie.blp:" .. chatIconSize .. "|t "
local chatMarkerPattern = "^%b{} Questie%s?:%s?"

function QuestieShutUp.FilterFunc(self, event, msg, author, ...)
    -- Filter both legacy raid-marker prefix and icon-prefixed announce messages.
    if stringFind(msg, pattern) or stringFind(msg, chatIconTag, 1, true) then
        return true
    end
end

function QuestieShutUp:ToggleFilters(value)
    if value then
        pattern = chatMarkerPattern
        Questie:Debug(Questie.DEBUG_DEVELOP, "QuestieShutUp toggle on. Pattern:", pattern)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", QuestieShutUp.FilterFunc)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", QuestieShutUp.FilterFunc)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", QuestieShutUp.FilterFunc)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", QuestieShutUp.FilterFunc)
    else
        Questie:Debug(Questie.DEBUG_DEVELOP, "QuestieShutUp toggle off.")
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY", QuestieShutUp.FilterFunc)
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY_LEADER", QuestieShutUp.FilterFunc)
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID", QuestieShutUp.FilterFunc)
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_LEADER", QuestieShutUp.FilterFunc)
    end
end
