---@class QuestLifecycle
local QuestLifecycle = QuestieLoader:CreateModule("QuestLifecycle")

---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

local tinsert = table.insert
local pairs = pairs

local function _RemoveQuestsThen(questIds, onComplete)
    local uniqueQuestIds = {}
    local pendingRemovals = 0

    for _, questId in pairs(questIds) do
        if not uniqueQuestIds[questId] then
            uniqueQuestIds[questId] = true
            pendingRemovals = pendingRemovals + 1
        end
    end

    if pendingRemovals == 0 then
        onComplete()
        return
    end

    for questId in pairs(uniqueQuestIds) do
        AvailableQuests.RemoveQuest(questId, function()
            pendingRemovals = pendingRemovals - 1
            if pendingRemovals == 0 then
                onComplete()
            end
        end)
    end
end

local allianceTournamentMarkerQuests = {[13684] = true, [13685] = true, [13688] = true, [13689] = true, [13690] = true, [13593] = true, [13703] = true, [13704] = true, [13705] = true, [13706] = true}
local hordeTournamentMarkerQuests = {[13691] = true, [13693] = true, [13694] = true, [13695] = true, [13696] = true, [13707] = true, [13708] = true, [13709] = true, [13710] = true, [13711] = true}

---@param questId number
function QuestLifecycle:AcceptQuest(questId)
    local quest = QuestieDB.GetQuest(questId)

    if quest then
        local complete = quest:IsComplete()
        -- If any of these flags exist then this quest has already once been accepted and is probably in a failed state
        if (quest.WasComplete or quest.isComplete or complete == 0 or complete == -1) and (QuestiePlayer.currentQuestlog[questId]) then
            Questie:Debug(Questie.DEBUG_INFO, "[QuestLifecycle] Accepted Quest:", questId, " Warning: This quest was once accepted and needs to be reset.")

            -- Reset quest log
            QuestiePlayer.currentQuestlog[questId] = nil

            -- Reset quest objectives
            quest.Objectives = {}

            -- Reset quest flags
            quest.WasComplete = nil
            quest.isComplete = nil

            -- Reset tooltips
            QuestieTooltips:RemoveQuest(questId)
        end

        local childQuests = QuestieDB.QueryQuestSingle(questId, "childQuests")
        if childQuests then
            for _, childQuestId in pairs(childQuests) do
                -- Daily quest status is reset after parent accept
                if QuestieDB.IsDailyQuest(childQuestId) then
                    Questie.db.char.complete[childQuestId] = nil
                end
            end
        end

        if not QuestiePlayer.currentQuestlog[questId] then
            Questie:Debug(Questie.DEBUG_INFO, "[QuestLifecycle] Accepted Quest:", questId)

            QuestiePlayer.currentQuestlog[questId] = quest

            if allianceTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13686] = true -- Alliance Tournament Eligibility Marker
            elseif hordeTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13687] = true -- Horde Tournament Eligibility Marker
            end

            -- Re-accepted quest can be collapsed. Expand it. Especially dailies.
            if Questie.db.char.collapsedQuests then
                Questie.db.char.collapsedQuests[questId] = nil
            end
            -- Re-accepted quest can be untracked. Clear it. Especially timed quests.
            if Questie.db.char.AutoUntrackedQuests[questId] then
                Questie.db.char.AutoUntrackedQuests[questId] = nil
            end

            -- Remove the starter/finisher frames first, then draw objective notes once the
            -- unload coroutine has finished. This prevents the draw coroutines from racing
            -- with the unload coroutine and removing the newly created objective icons.
            AvailableQuests.RemoveQuest(questId, function()
                QuestieQuest:PopulateQuestLogInfo(quest)
                -- This needs to happen after QuestieQuest:PopulateQuestLogInfo because that is the place where quest.Objectives is generated
                Questie:SendMessage("QC_ID_BROADCAST_QUEST_UPDATE", questId)
                QuestieQuest:PopulateObjectiveNotes(quest)

                -- Run a delayed refresh so newly accepted quests are
                -- guaranteed visible without manual collapse/expand.
                C_Timer.After(0.20, function()
                    QuestieCombatQueue:Queue(function()
                        QuestieTracker:Update()
                    end)
                end)

                AvailableQuests.CalculateAndDrawAll(nil, true)
            end)
        else
            Questie:Debug(Questie.DEBUG_INFO, "[QuestLifecycle] Accepted Quest:", questId, " Warning: Quest already exists, not adding")
        end
    end
end

local allianceChampionMarkerQuests = {[13699] = true, [13713] = true, [13723] = true, [13724] = true, [13725] = true}
local hordeChampionMarkerQuests = {[13726] = true, [13727] = true, [13728] = true, [13729] = true, [13731] = true}

---@param questId number
function QuestLifecycle:CompleteQuest(questId)
    -- Skip quests which are turn in only and are not added to the quest log in the first place
    if QuestiePlayer.currentQuestlog[questId] then
        -- Reset quest flags of
        QuestiePlayer.currentQuestlog[questId].WasComplete = nil
        QuestiePlayer.currentQuestlog[questId].isComplete = nil
        QuestiePlayer.currentQuestlog[questId] = nil;
    end

    -- Only quests that are daily quests or aren't repeatable should be marked complete,
    -- otherwise objectives for repeatable quests won't track correctly - #1433
    if QuestieCompat.Is335 then
        QuestieCompat.SetQuestComplete(questId)
    else
        Questie.db.char.complete[questId] = (not QuestieDB.IsRepeatable(questId)) or QuestieDB.IsDailyQuest(questId) or QuestieDB.IsWeeklyQuest(questId) or QuestieDB.IsMonthlyQuest(questId);
    end

    if allianceChampionMarkerQuests[questId] then
        Questie.db.char.complete[13700] = true -- Alliance Champion Marker
        Questie.db.char.complete[13686] = nil -- Alliance Tournament Eligibility Marker
    elseif hordeChampionMarkerQuests[questId] then
        Questie.db.char.complete[13701] = true -- Horde Champion Marker
        Questie.db.char.complete[13687] = nil -- Horde Tournament Eligibility Marker
    end

    local questIdsToRemove = {questId}
    local childQuests = QuestieDB.QueryQuestSingle(questId, "childQuests")
    if childQuests then
        for _, childQuestId in pairs(childQuests) do
            if not QuestiePlayer.currentQuestlog[childQuestId] then
                -- Make sure all other childQuests are unloaded: all exclusives, chains etc
                tinsert(questIdsToRemove, childQuestId)
            end
        end
    end

    QuestieTracker:RemoveQuest(questId)

    -- Turn-in flow can update tracker before quest log header counters settle.
    -- Run a short delayed refresh to keep the header/count in sync.
    C_Timer.After(0.20, function()
        QuestieCombatQueue:Queue(function()
            QuestieTracker:Update()
        end)
    end)

    _RemoveQuestsThen(questIdsToRemove, function()
        AvailableQuests.CalculateAndDrawAll(nil, true)
    end)

    Questie:Debug(Questie.DEBUG_INFO, "[QuestLifecycle] Completed Quest:", questId)
end

---@param questId number
function QuestLifecycle:AbandonQuest(questId)
    if (QuestiePlayer.currentQuestlog[questId]) then
        QuestiePlayer.currentQuestlog[questId] = nil
        local questIdsToRemove = {questId}
        local quest = QuestieDB.GetQuest(questId)

        if quest then
            -- Reset quest objectives
            quest.Objectives = {}

            -- Reset quest flags
            quest.WasComplete = nil
            quest.isComplete = nil

            if allianceTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13686] = nil -- Alliance Tournament Eligibility Marker
            elseif hordeTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13687] = nil -- Horde Tournament Eligibility Marker
            end

            local childQuests = QuestieDB.QueryQuestSingle(questId, "childQuests")
            if childQuests then
                for _, childQuestId in pairs(childQuests) do
                    if not QuestiePlayer.currentQuestlog[childQuestId] then
                        -- Make sure all other childQuests are unloaded: all exclusives, chains etc
                        tinsert(questIdsToRemove, childQuestId)
                    end
                end
            end
        end

        QuestieTracker:RemoveQuest(questId)

        -- Abandon flow can update tracker before quest log header counters settle.
        -- Run a short delayed refresh to keep the header/count in sync.
        C_Timer.After(0.20, function()
            QuestieCombatQueue:Queue(function()
                QuestieTracker:Update()
            end)
        end)

        _RemoveQuestsThen(questIdsToRemove, function()
            AvailableQuests.CalculateAndDrawAll(nil, true)
        end)

        Questie:Debug(Questie.DEBUG_INFO, "[QuestLifecycle] Abandoned Quest:", questId)
    end
end

