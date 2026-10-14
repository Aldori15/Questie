---@class TrackerData
local TrackerData = QuestieLoader:CreateModule("TrackerData")

local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")
local l10n = QuestieLoader:ImportModule("l10n")

-- Only tracker display records live here. Never insert native-only quests into
-- currentQuestlog: map, routing, and communications consumers require database objects.
local nativeQuests = {}
local nativePreviewQuestId
local counterTypes = {monster = true, item = true, object = true, reputation = true, killcredit = true, spell = true}

local function IsComplete(self)
    return self.completionState
end

local function RefreshNativeQuest(id, title, level, header, complete, frequency, index)
    local quest = nativeQuests[id]
    if not quest then
        quest = {Id = id, NativeOnly = true, Objectives = {}, SpecialObjectives = {},
            requiredSourceItems = {}, ObjectiveData = {}, IsComplete = IsComplete}
        nativeQuests[id] = quest
    end
    quest.name = title
    quest.level = level == -1 and QuestiePlayer.GetPlayerLevel() or level or 0
    quest.zoneName = header or quest.zoneName or l10n("Unknown Zone")
    quest.completionState = complete == -1 and -1 or complete == 1 and 1 or 0
    quest.isComplete = complete == 1
    quest.isDaily = frequency == 2

    local cached = QuestLogCache.questLog_DO_NOT_MODIFY[id]
    quest.objectivesLoaded = cached ~= nil
    if cached then
        local indices = {}
        for nativeIndex in pairs(cached.objectives) do indices[#indices + 1] = nativeIndex end
        table.sort(indices)
        local objectives = {}
        for displayIndex, nativeIndex in ipairs(indices) do
            local live = cached.objectives[nativeIndex]
            local previous = quest.Objectives[displayIndex]
            local objective = previous and previous.NativeIndex == nativeIndex and previous or {}
            objective.Index, objective.NativeIndex = displayIndex, nativeIndex
            objective.questId, objective.NativeOnly = id, true
            objective.Type = live.type
            objective.Description = live.text
            objective.NativeText = live.raw_text or live.text
            objective.FullDescription = QuestieLib.GetFullObjectiveText(objective.NativeText)
            objective.HasCounter = counterTypes[live.type] and (objective.NativeText:find("%d+/%d+") ~= nil)
            objective.Collected, objective.Needed = live.numFulfilled or 0, live.numRequired or 1
            -- Use native completion, not counter equality or database completion inference.
            objective.Completed = quest.isComplete or live.raw_finished == true
            objectives[displayIndex] = objective
        end
        quest.Objectives = objectives
    end -- Keep the previous valid display if loading temporarily removes the snapshot.

    local link = GetQuestLogSpecialItemInfo(index)
    quest.sourceItemId = link and tonumber(link:match("item:(%d+)")) or nil
    return quest
end

---Merge database-backed map objects with native-only tracker records.
---Enumerate beyond the visible count to include quests under collapsed headers.
function TrackerData.Refresh()
    local quests, present, headers, precedingHeader = {}, {}, {}, nil
    for id, quest in pairs(QuestiePlayer.currentQuestlog) do quests[id] = quest end
    local visibleEntries = GetNumQuestLogEntries()
    for index = 1, 75 do
        local title, level, _, isHeader, _, complete, frequency, id = QuestieCompat.GetQuestLogTitle(index)
        if not title then break end
        if isHeader then
            precedingHeader = title
            -- Ask the same native API for headers and quests rather than assuming
            -- a sort key is a visible log index or a header ordinal.
            local sortKey = GetQuestSortIndex(index)
            if sortKey then headers[sortKey] = title end
        elseif id and id > 0 then
            present[id] = true
            if not QuestieDB.HasQuestData(id) or id == nativePreviewQuestId then
                local header = precedingHeader
                if index > visibleEntries then
                    header = headers[GetQuestSortIndex(index)]
                end
                quests[id] = RefreshNativeQuest(id, title, level, header, complete, frequency, index)
            end
        end
    end
    for id in pairs(nativeQuests) do
        if not present[id] or (QuestieDB.HasQuestData(id) and id ~= nativePreviewQuestId) then nativeQuests[id] = nil end
    end
    return quests
end

function TrackerData.GetQuest(id)
    if id == nativePreviewQuestId or not QuestieDB.HasQuestData(id) then return TrackerData.Refresh()[id] end
    return QuestiePlayer.currentQuestlog[id] or TrackerData.Refresh()[id]
end

function TrackerData.ContainsQuest(id)
    local index = QuestieCompat.GetQuestLogIndexByID(id)
    return index ~= nil and index > 0
end

function TrackerData.RemoveQuest(id)
    nativeQuests[id] = nil
end

---Temporary in-game smoke test: force one current quest through the native display fallback.
---Only tracker display changes. Database pointers, map objects, and cached objectives stay intact.
---Pass nil to stop; this local override is never saved and also clears on /reload.
function TrackerData.SetNativeQuestPreview(id)
    if id ~= nil and (type(id) ~= "number" or not TrackerData.ContainsQuest(id)) then
        return false, "Choose a quest ID currently in your quest log."
    end
    if nativePreviewQuestId then nativeQuests[nativePreviewQuestId] = nil end
    nativePreviewQuestId = id
    QuestieLoader:ImportModule("QuestieCombatQueue"):Queue(function()
        QuestieLoader:ImportModule("QuestieTracker"):Update(true)
    end)
    return true, id and "Native quest preview enabled: " .. id or "Native quest preview disabled."
end

function TrackerData.GetColoredQuestName(quest, showLevel, showState, blizzLike)
    if not quest.NativeOnly then
        return QuestieLib:GetColoredQuestName(quest.Id, showLevel, showState, blizzLike)
    end
    local name = quest.name
    if showLevel then name = "[" .. quest.level .. "] " .. name end
    if Questie.db.profile.enableTooltipsQuestID then name = name .. " (" .. quest.Id .. ")" end
    if showState then
        if quest:IsComplete() == -1 then
            name = name .. " " .. Questie:Colorize("(" .. l10n("Failed") .. ")", "red")
        elseif quest:IsComplete() == 1 then
            name = name .. " " .. Questie:Colorize("(" .. l10n("Complete") .. ")", "green")
        end
    end
    return QuestieLib:PrintDifficultyColor(quest.level, name, quest.isDaily)
end

function TrackerData.GetQuestLink(quest)
    if not quest.NativeOnly then return QuestieLink:GetQuestInsertStringById(quest.Id) end
    return QuestieCompat.GetQuestLink(quest.Id) or "[" .. quest.name .. " (" .. quest.Id .. ")]"
end

---Native item identity comes from the client, so it need not exist in QuestieDB.
function TrackerData.IsNativeQuestItem(quest, itemId)
    return quest.NativeOnly and quest.sourceItemId == itemId
end
