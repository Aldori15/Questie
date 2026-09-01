---@class ChatFilter
local ChatFilter = QuestieLoader:CreateModule("ChatFilter")
---@type QuestieLink
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID
local GetQuestObjectives = QuestieCompat.C_QuestLog.GetQuestObjectives
local HaveQuestData = QuestieCompat.HaveQuestData
local strfind = string.find
local prefetchedQuestIds = {}

-- Compatibility: 2.5.5+ uses ChatFrameUtil.AddMessageEventFilter instead of ChatFrame_AddMessageEventFilter
local ChatFrameAddMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter

---------------------------------------------------------------------------------------------------
-- These must be loaded in order together and loaded before the hook for custom quest links
-- The Hyperlink hook is located in Link.lua
---------------------------------------------------------------------------------------------------

local function escapeMagic(toEscape)
    return (toEscape
        :gsub("%%", "%%%%")
        :gsub("^%^", "%%^")
        :gsub("%$$", "%%$")
        :gsub("%(", "%%(")
        :gsub("%)", "%%)")
        :gsub("%.", "%%.")
        :gsub("%[", "%%[")
        :gsub("%]", "%%]")
        :gsub("%*", "%%*")
        :gsub("%+", "%%+")
        :gsub("%-", "%%-")
        :gsub("%?", "%%?")
        :gsub("%|", "%%|")
    )
end

-- 3.3.5 native quest links use quest:questId:level. The level can be -1 for scaling quests.
local nativeQuestPattern = "(|c%x%x%x%x%x%x%x%x|Hquest:(%d+):%-?%d+|h%[(.-)%]|h|r)"

local function getQuestHyperLink(questId, sender)
    if not (questId and QuestieDB.QuestPointers[questId]) then
        return nil
    end

    if (not prefetchedQuestIds[questId]) and (not HaveQuestData(questId)) then
        local questLogIndex = GetQuestLogIndexByID(questId)
        if questLogIndex then
            prefetchedQuestIds[questId] = true
            GetQuestObjectives(questId, questLogIndex)
        end
    end

    return QuestieLink:GetQuestHyperLink(questId, sender)
end

local function processQuestLink(message, questId, sender, searchPattern)
    local questLink = getQuestHyperLink(questId, sender)
    if not questLink then
        return message
    end

    return string.gsub(message, searchPattern, function()
        return questLink
    end)
end

-- Protect native links while the legacy bracketed-link pass runs. Otherwise a converted native
-- link whose display text includes a quest ID could be matched again and become a nested hyperlink.
local function protectNativeQuestLinks(message, sender)
    local replacements = {}
    local protectedMessage = string.gsub(message, nativeQuestPattern, function(nativeLink, questIdString)
        local questLink = getQuestHyperLink(tonumber(questIdString), sender) or nativeLink
        replacements[#replacements + 1] = questLink
        return "\001QuestieNative" .. #replacements .. "\002"
    end)
    return protectedMessage, replacements
end

local function restoreNativeQuestLinks(message, replacements)
    return string.gsub(message, "\001QuestieNative(%d+)\002", function(index)
        return replacements[tonumber(index)]
    end)
end

--- Message Event Filter which intercepts incoming linked quests and replaces them with Hyperlinks
ChatFilter.Filter = function(chatFrame, _, msg, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, senderGUID, bnSenderID, ...)
    if (not Questie.started) then
        return
    end

    if not (chatFrame and ((chatFrame.historyBuffer and #(chatFrame.historyBuffer.elements) > 0) or QuestieCompat.Is335) and chatFrame ~= _G.ChatFrame2) then
        return
    end

    local originalMessage = msg
    local sender = senderGUID or bnSenderID or "0"
    local nativeLinkReplacements
    msg, nativeLinkReplacements = protectNativeQuestLinks(msg, sender)

    if strfind(msg, "%[(..-) %((%d+)%)%]") then
        for bracketedLink in string.gmatch(msg, "%[%[?%d?..?%]?..-%]") do
            local sqid, questId, questLevel, questName

            questName, sqid = string.match(bracketedLink, "%[(..-) %((%d+)%)%]")

            if questName and sqid then
                questId = tonumber(sqid)

                if strfind(questName, "(%[%d+.-%]) ") ~= nil then
                    questLevel, questName = string.match(questName, "%[(..-)%] (.+)")
                end
            end

            if questId and QuestieDB.QuestPointers[questId] then
                questName = questName and escapeMagic(questName)
                questLevel = questLevel and escapeMagic(questLevel)

                local searchPattern
                if questLevel then
                    searchPattern = "%[%[" .. questLevel .. "%] " .. questName .. " %(" .. sqid .. "%)%]"
                else
                    searchPattern = "%[" .. questName .. " %(" .. sqid .. "%)%]"
                end

                msg = processQuestLink(msg, questId, sender, searchPattern)
            end
        end
    end

    msg = restoreNativeQuestLinks(msg, nativeLinkReplacements)
    if msg ~= originalMessage then
        return false, msg, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, senderGUID, bnSenderID, ...
    end
end

function ChatFilter:RegisterEvents() -- todo: register immediately and cache calls until db is available
    -- Party
    ChatFrameAddMessageEventFilter("CHAT_MSG_PARTY", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ChatFilter.Filter)

    -- Raid
    ChatFrameAddMessageEventFilter("CHAT_MSG_RAID", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_RAID_LEADER", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_RAID_WARNING", ChatFilter.Filter)

    -- Guild
    ChatFrameAddMessageEventFilter("CHAT_MSG_GUILD", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_OFFICER", ChatFilter.Filter)

    -- Battleground
    ChatFrameAddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", ChatFilter.Filter)

    -- Whisper
    ChatFrameAddMessageEventFilter("CHAT_MSG_WHISPER", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatFilter.Filter)

    -- Battle Net
    ChatFrameAddMessageEventFilter("CHAT_MSG_BN", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatFilter.Filter)

    -- Open world
    ChatFrameAddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_SAY", ChatFilter.Filter)
    ChatFrameAddMessageEventFilter("CHAT_MSG_YELL", ChatFilter.Filter)

    -- Emote
    ChatFrameAddMessageEventFilter("CHAT_MSG_EMOTE", ChatFilter.Filter)
end
