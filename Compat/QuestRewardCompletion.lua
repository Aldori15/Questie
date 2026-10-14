QuestieLoader:StampLoadBoundary("Compat/QuestRewardCompletion.lua")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
local _QuestEventHandler = QuestEventHandler.private
local MAX_QUEST_LOG_INDEX = 75

local QUEST_COMPLETE_MSG = string.gsub(ERR_QUEST_COMPLETE_S, "(%%s)", "(.+)")

-- QUEST_TURNED_IN is unavailable on the 3.3.5 client. Most quests are
-- reconstructed from ERR_QUEST_COMPLETE_S, but some immediate-turn-in quests
-- do not produce a usable message. Keep reward claims until the server confirms
-- the exact quest ID. Shared titles retain candidates until the rewarded set
-- and live quest-log removals disambiguate them.
local pendingRewardCompletions = {}
local rewardCompletionQueryScheduled = false
local rewardCompletionQueryInFlight = false
local rewardCompletionQuerySerial = 0
local REWARD_COMPLETION_QUERY_DELAY = 0.5
local REWARD_COMPLETION_QUERY_TIMEOUT = 5

local function ResolveQuestEnderQuestId(questTitle)
    local guid = QuestieCompat.UnitGUID("npc")
    if not guid then
        return nil
    end

    local questgiverId = tonumber(guid:match("-(%d+)-%x+$"), 10)
    local unitType = strsplit("-", guid)
    local questsEnded

    if unitType == "Creature" then
        questsEnded = QuestieDB.QueryNPCSingle(questgiverId, "questEnds")
    elseif unitType == "GameObject" then
        questsEnded = QuestieDB.QueryObjectSingle(questgiverId, "questEnds")
    else
        return nil
    end

    if not questsEnded then
        return nil
    end

    local uniqueMatch
    local uniqueDoableMatch
    local multipleMatches = false
    local multipleDoableMatches = false
    local matches, doableMatches = {}, {}

    for _, questId in pairs(questsEnded) do
        if QuestieDB.QueryQuestSingle(questId, "name") == questTitle then
            matches[questId] = true
            if uniqueMatch and uniqueMatch ~= questId then
                multipleMatches = true
            else
                uniqueMatch = questId
            end

            if QuestieDB.IsDoable(questId) then
                doableMatches[questId] = true
                if uniqueDoableMatch and uniqueDoableMatch ~= questId then
                    multipleDoableMatches = true
                else
                    uniqueDoableMatch = questId
                end
            end
        end
    end

    if uniqueDoableMatch and not multipleDoableMatches then
        return uniqueDoableMatch, {[uniqueDoableMatch] = true}
    end
    if uniqueMatch and not multipleMatches then
        return uniqueMatch, {[uniqueMatch] = true}
    end
    return nil, next(doableMatches) and doableMatches or matches
end

local function ResolveRewardQuestId(questTitle)
    -- Immediate-turn-in quests can disappear from (or never enter) the quest
    -- log, so resolve against the current quest ender first.
    local questId, candidates = ResolveQuestEnderQuestId(questTitle)
    if questId then
        return questId, candidates
    end

    -- Database mismatches can prevent quest-ender resolution. Fall back to the
    -- quest log only when the title identifies one unique quest ID.
    local uniqueQuestId
    local logMatches = {}
    local multipleMatches = false
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if not title then
            break
        end

        if (not isHeader) and title == questTitle then
            if uniqueQuestId and uniqueQuestId ~= id then
                multipleMatches = true
            end
            uniqueQuestId = id
            logMatches[id] = true
        end
    end

    if not multipleMatches and uniqueQuestId and
        (not candidates or not next(candidates) or candidates[uniqueQuestId]) then
        return uniqueQuestId, logMatches
    end
    -- Prefer the current ender's candidates when available; unrelated NPCs can
    -- also offer quests with this title.
    return nil, candidates and next(candidates) and candidates or logMatches
end

local function CompleteRewardQuest(questId)
    -- Keep the raw cache in sync even when the normal chat path handled the
    -- turn-in before another completed-quest query was needed.
    if QuestieDB.IsDailyQuest(questId) then
        QuestieCompat.SetAzerothCoreDailyQuestComplete(questId)
    end
    QuestieCompat.RecordServerQuestCompletion(questId)
    _QuestEventHandler:QuestTurnedIn(questId)
    _QuestEventHandler:QuestRemoved(questId)
end

local ScheduleRewardCompletionQuery

local function ExpireRewardCompletionQuery(querySerial)
    if (not rewardCompletionQueryInFlight) or rewardCompletionQuerySerial ~= querySerial then
        return
    end

    rewardCompletionQueryInFlight = false

    -- Only discard entries which were included in the timed-out request.
    -- Entries queued while it was in flight still need their own query.
    for index = #pendingRewardCompletions, 1, -1 do
        if pendingRewardCompletions[index].minimumQuerySerial <= querySerial then
            table.remove(pendingRewardCompletions, index)
        end
    end

    ScheduleRewardCompletionQuery()
end

ScheduleRewardCompletionQuery = function()
    if rewardCompletionQueryScheduled or rewardCompletionQueryInFlight or #pendingRewardCompletions == 0 then
        return
    end

    rewardCompletionQueryScheduled = true
    QuestieCompat.C_Timer.After(REWARD_COMPLETION_QUERY_DELAY, function()
        rewardCompletionQueryScheduled = false
        if rewardCompletionQueryInFlight or #pendingRewardCompletions == 0 then
            return
        end

        rewardCompletionQuerySerial = rewardCompletionQuerySerial + 1
        local querySerial = rewardCompletionQuerySerial
        rewardCompletionQueryInFlight = true

        QueryQuestsCompleted()
        QuestieCompat.C_Timer.After(REWARD_COMPLETION_QUERY_TIMEOUT, function()
            ExpireRewardCompletionQuery(querySerial)
        end)
    end)
end

function QuestieCompat.ProcessPendingRewardCompletions()
    if not rewardCompletionQueryInFlight then
        -- An unrelated completion query may finish between GetQuestReward and
        -- our delayed request. Fold its result into each pending baseline so it
        -- cannot be mistaken for the reward we are about to verify.
        for _, pending in ipairs(pendingRewardCompletions) do
            for questId, candidate in pairs(pending.candidates) do
                if QuestieCompat.HasRawServerQuestCompletion(questId) then
                    candidate.completedBefore = true
                end
            end
        end
        return
    end

    local completedQuerySerial = rewardCompletionQuerySerial
    rewardCompletionQueryInFlight = false
    local groups = {}
    for index = #pendingRewardCompletions, 1, -1 do
        local pending = pendingRewardCompletions[index]
        if pending.minimumQuerySerial <= completedQuerySerial then
            table.remove(pendingRewardCompletions, index)
            local group = groups[pending.title] or {claims = {}, confirmed = {}}
            groups[pending.title] = group
            group.claims[#group.claims + 1] = pending
            for questId, candidate in pairs(pending.candidates) do
                local leftLog = candidate.wasInLog and not QuestieCompat.GetQuestLogIndexByID(questId)
                -- AzerothCore can retain lifetime reward history for repeatables.
                -- In that case a live-log removal proves this claim succeeded.
                -- Never treat an explicit abandon or an unchanged log as a reward.
                if not candidate.abandoned and QuestieCompat.HasRawServerQuestCompletion(questId)
                    and ((candidate.wasInLog and leftLog)
                        or (not candidate.wasInLog and not candidate.completedBefore)) then
                    group.confirmed[questId] = group.confirmed[questId] or {}
                    group.confirmed[questId][#group.claims] = true
                end
            end
        end
    end

    for _, group in pairs(groups) do
        local confirmedIds = {}
        for questId in pairs(group.confirmed) do confirmedIds[#confirmedIds + 1] = questId end
        table.sort(confirmedIds)
        -- Each confirmed ID must have a distinct supporting reward claim.
        -- Counts alone are insufficient if different NPCs share this title.
        local assignedClaims = {}
        local function assignClaim(questId, visited)
            for claimIndex in pairs(group.confirmed[questId]) do
                if not visited[claimIndex] then
                    visited[claimIndex] = true
                    if not assignedClaims[claimIndex] or assignClaim(assignedClaims[claimIndex], visited) then
                        assignedClaims[claimIndex] = questId
                        return true
                    end
                end
            end
            return false
        end
        local canConfirm = #confirmedIds <= #group.claims
        if canConfirm then
            for _, questId in ipairs(confirmedIds) do
                if not assignClaim(questId, {}) then canConfirm = false; break end
            end
        end
        if canConfirm then
            -- Several same-title rewards can finish before one query. Consume
            -- each confirmed ID once, without guessing which claim came first.
            for _, questId in ipairs(confirmedIds) do
                for _, pending in ipairs(pendingRewardCompletions) do
                    local candidate = pending.candidates[questId]
                    if candidate then
                        candidate.completedBefore, candidate.wasInLog = true, false
                    end
                end
                CompleteRewardQuest(questId)
            end
        else
            -- A newer claim may have completed while this query was in flight.
            -- Wait for its query rather than assign several rewards to one claim.
            for _, pending in ipairs(group.claims) do
                if GetTime() < pending.expiresAt then
                    pending.minimumQuerySerial = completedQuerySerial + 1
                    pendingRewardCompletions[#pendingRewardCompletions + 1] = pending
                end
            end
        end
    end

    -- A reward can be claimed while another completion query is in flight.
    -- Those newer entries require one additional batched query.
    ScheduleRewardCompletionQuery()
end

function QuestieCompat.HandleQuestRewardMessage(message)
    local questName = message:match(QUEST_COMPLETE_MSG)
    if questName then
        -- Preserve the existing fast path for ordinary quests. Only consume a
        -- title when it identifies one pending reward; same-title batches are
        -- left to exact-ID server confirmation instead of relying on order.
        local matchingIndex
        local matchingCount = 0
        for index, pending in ipairs(pendingRewardCompletions) do
            if pending.title == questName then
                matchingIndex = index
                matchingCount = matchingCount + 1
            end
        end

        local pending = matchingIndex and pendingRewardCompletions[matchingIndex]
        if matchingCount == 1 and pending.questId and not pending.candidates[pending.questId].abandoned then
            local questId = pending.questId
            table.remove(pendingRewardCompletions, matchingIndex)
            CompleteRewardQuest(questId)
        end
    end
end

function QuestieCompat.RegisterQuestRewardCompletionHook()
    hooksecurefunc("GetQuestReward", function(itemChoice)
        local questTitle = GetTitleText()
        if not questTitle or questTitle == "" then
            return
        end

        local questId, matchingIds = ResolveRewardQuestId(questTitle)
        local candidates = {}
        for id in pairs(matchingIds or {}) do
            candidates[id] = {
                completedBefore = QuestieCompat.HasRawServerQuestCompletion(id),
                wasInLog = QuestieCompat.GetQuestLogIndexByID(id) ~= nil,
            }
        end
        if not next(candidates) then return end
        pendingRewardCompletions[#pendingRewardCompletions + 1] = {
            title = questTitle,
            questId = questId,
            candidates = candidates,
            expiresAt = GetTime() + REWARD_COMPLETION_QUERY_TIMEOUT,
            -- The next query issued after this hook is the first one which can
            -- legitimately contain this completion.
            minimumQuerySerial = rewardCompletionQuerySerial + 1,
        }

        ScheduleRewardCompletionQuery()
    end)
end

function QuestieCompat.MarkPendingQuestRewardAbandoned(questId)
    for _, pending in ipairs(pendingRewardCompletions) do
        if pending.candidates[questId] then
            pending.candidates[questId].abandoned = true
        end
    end
end
