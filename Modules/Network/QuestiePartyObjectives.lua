---@class QuestiePartyObjectives : QuestieModule
local QuestiePartyObjectives = QuestieLoader:CreateModule("QuestiePartyObjectives")
---@class QuestiePartyObjectivesPrivate
QuestiePartyObjectives.private = QuestiePartyObjectives.private or {}
-------------------------
--Import modules.
-------------------------
---@type QuestieComms
local QuestieComms = QuestieLoader:ImportModule("QuestieComms")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type ThreadLib
local ThreadLib = QuestieLoader:ImportModule("ThreadLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@type CommsVisibility
local CommsVisibility = QuestieLoader:ImportModule("CommsVisibility")
local MapIconTooltip = QuestieLoader:ImportModule("MapIconTooltip")
local QuestieIconVisibility = QuestieLoader:ImportModule("QuestieIconVisibility")

local NOP_FUNCTION = function() end

--- COMPATIBILITY ---
local C_QuestLog = QuestieCompat.C_QuestLog
local C_Timer = QuestieCompat.C_Timer
local GetGroupUnitByName = QuestieCompat.GetGroupUnitByName
local GetNumGroupMembers = QuestieCompat.GetNumGroupMembers
local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID
local CallErrorHandler = CallErrorHandler or geterrorhandler()

local MAX_GROUP_SIZE = 5
local MAX_PARTY_ICONS = 500
local CHUNK_SIZE = 10
local ICONS_PER_FRAME = 50

local typeCharToFull = {
    ["m"] = "monster",
    ["o"] = "object",
    ["i"] = "item",
}

local drawnByQuest = {}
local spawnListCache = {}
local drawnIconCount = 0

-- Scheduling state.
local dirtyQuests = {}
local fullRefreshPending = false
local updateScheduled = false
local processing = false
local processingGeneration = 0

-- Forward declarations (these reference each other).
local _ScheduleProcessing, _ProcessScheduled, _ProcessQueue

-- The objective needs a non-nil Description or the map icon tooltip skips it entirely
-- (see MapIconTooltip "iconData.ObjectiveData.Description" check). The compiled database
-- objective text is often empty, so fall back to the target's name.
---@param objType string
---@param objId number
---@return string?
local function _GetObjectiveName(objType, objId)
    if objType == "monster" then
        local npc = QuestieDB:GetNPC(objId)
        return npc and npc.name
    elseif objType == "object" then
        local object = QuestieDB:GetObject(objId)
        return object and object.name
    elseif objType == "item" then
        local item = QuestieDB:GetItem(objId)
        return item and item.name
    end
end

-- A flagged objective's database name is meaningless (kill-credit, event, etc.). The Blizzard API
-- returns the real objective text on clients that can query quest data by quest ID. On 335, the
-- compat API can only read objective text when the quest is also in the local quest log.
---@param questId number
---@param objectiveIndex number
---@return string?
local function _GetApiObjectiveText(questId, objectiveIndex)
    local questLogIndex = GetQuestLogIndexByID(questId)
    if not questLogIndex then
        return nil
    end

    local objectives = C_QuestLog.GetQuestObjectives(questId, questLogIndex)
    local objective = objectives and objectives[objectiveIndex]
    local text = objective and objective.text
    if (not text) or text == "" or string.byte(text, 1) == 32 or (not objective.type) then
        return nil
    end

    return QuestieLib.GetFullObjectiveText(text) or text
end

-- The tooltips prefer FullDescription (the objective text including "slain", see
-- QuestieLib:GetObjectiveDescription), which QuestieQuest extracts from the local quest log
-- for local objectives. The local player does not always have a party member's quest,
-- so rebuild the text from the client's own quest log format string for the objective type.
local objectiveTypePatterns = {
    monster = QUEST_MONSTERS_KILLED, -- "%s slain: %d/%d"
    item = QUEST_ITEMS_NEEDED,
    object = QUEST_OBJECTS_FOUND,
}

---@param objType string
---@param description string
---@return string?
local function _GetFullDescription(objType, description)
    if description == "" then
        return nil
    end
    local pattern = objectiveTypePatterns[objType]
    if not pattern then
        return nil
    end
    local rawText = string.format(pattern, description, 0, 0)
    return QuestieLib.GetFullObjectiveText(rawText)
end

---@return boolean
local function _ShouldDraw()
    return Questie.db.profile.showPartyQuestObjectives
        and QuestiePlayer:GetGroupType() ~= nil
        and GetNumGroupMembers() <= MAX_GROUP_SIZE
end

---@param name string
---@return boolean @true if the named party member is online
local function _IsPlayerOnline(name)
    local unit = GetGroupUnitByName(name)
    return unit and UnitIsConnected(unit)
end

---@param objective table
---@return number @the number of map-icons this objective drew
local function _CountIcons(objective)
    local count = 0
    for _, spawn in pairs(objective.AlreadySpawned) do
        count = count + #spawn.mapRefs
    end
    return count
end

-- Frames may be recycled before the next batch runs; retain their original data.
local pendingUnloads = {}
local nextUnload = 1
local unloadScheduled = false
local function _ProcessUnloads()
    local stop = math.min(nextUnload + ICONS_PER_FRAME - 1, #pendingUnloads)
    while nextUnload <= stop do
        local pending = pendingUnloads[nextUnload]
        nextUnload = nextUnload + 1
        if pending[1].data == pending[2] then
            local ok, err = pcall(QuestieFramePool.UnloadFrame, QuestieFramePool, pending[1])
            if not ok then pcall(CallErrorHandler, err) end
        end
    end
    if nextUnload <= #pendingUnloads then
        C_Timer.After(0, _ProcessUnloads)
    else
        pendingUnloads, nextUnload, unloadScheduled = {}, 1, false
    end
end

local function _UnloadObjectivesLater(objectives)
    for _, objective in pairs(objectives) do
        for _, spawn in pairs(objective.AlreadySpawned) do
            for _, refs in ipairs({spawn.mapRefs, spawn.minimapRefs}) do
                for _, icon in pairs(refs) do
                    pendingUnloads[#pendingUnloads + 1] = {icon, spawn.data}
                end
            end
        end
    end
    if not unloadScheduled and nextUnload <= #pendingUnloads then
        unloadScheduled = true
        C_Timer.After(0, _ProcessUnloads)
    end
end

local function _HasAllIcons(entry)
    local count = 0
    for _, objective in pairs(entry.objectives) do
        for _, spawn in pairs(objective.AlreadySpawned) do
            for _, icon in pairs(spawn.mapRefs) do
                if icon.data ~= spawn.data or icon._needsUnload then return false end
                count = count + 1
            end
            for _, icon in pairs(spawn.minimapRefs) do
                if icon.data ~= spawn.data or icon._needsUnload then return false end
            end
        end
    end
    return count == entry.iconCount
end

---@param questId number
local function _ClearQuest(questId)
    local entry = drawnByQuest[questId]
    if not entry then
        return
    end
    _UnloadObjectivesLater(entry.objectives)
    if entry.counted then
        drawnIconCount = drawnIconCount - entry.iconCount
    end
    drawnByQuest[questId] = nil
end

local function _CollectIndices(questId)
    local players = QuestieComms.remoteQuestLogs[questId]
    if not players then return end
    local localEntry = QuestLogCache.questLog_DO_NOT_MODIFY[questId]
    local localQuest = localEntry and QuestieDB.GetQuest(questId)
    local localDrawsNothing = localEntry and (localEntry.isComplete == 1 or localEntry.isComplete == -1
        or (localQuest and localQuest.isComplete == true))
    local localObjectives = localEntry and localEntry.objectives or {}
    local localMapped = localQuest and localQuest.Objectives or {}

    -- An objective index is drawn if at least one online party member still needs it. Offline
    -- members and failed quests are ignored so their objective icons are not actionable.
    local neededIndices = {}
    local reportedIndices = {}
    for playerName, objectives in pairs(players) do
        if _IsPlayerOnline(playerName) and CommsVisibility:ShouldShowPartyObjective(playerName, questId) then
            for objectiveIndex, objective in pairs(objectives) do
                if objective.status ~= "F" then
                    reportedIndices[objectiveIndex] = true
                    local localObjective = localObjectives[objectiveIndex]
                    local mapped = localMapped[objectiveIndex]
                    local drawnLocally = localEntry and not localDrawsNothing and localObjective
                        and not localObjective.finished and mapped and not mapped.Completed
                    if not objective.finished and not drawnLocally then
                        neededIndices[objectiveIndex] = objective
                    end
                end
            end
        end
    end
    if not next(neededIndices) then
        return
    end
    return neededIndices, reportedIndices, not localEntry or localDrawsNothing
end

local function _GetDrawSignature(needed, reported, drawSpecials)
    if not needed then return end
    local parts = {tostring(drawSpecials), tostring(Questie.db.profile.enabled),
        tostring(Questie.db.profile.enableMapIcons), tostring(Questie.db.profile.enableMiniMapIcons)}
    for index, objective in pairs(needed) do
        parts[#parts + 1] = index .. ":" .. tostring(objective.type) .. ":" .. tostring(objective.id)
    end
    for index in pairs(reported) do parts[#parts + 1] = "k" .. index end
    if QuestieIconVisibility.IsEnabled then
        parts[#parts + 1] = "map:" .. tostring(QuestieIconVisibility:IsEnabled("objective", false))
        parts[#parts + 1] = "mini:" .. tostring(QuestieIconVisibility:IsEnabled("objective", true))
    else
        parts[#parts + 1] = "objectives:" .. tostring(QuestieIconVisibility:IsEnabledAnywhere("objective"))
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- Draw only objectives not already supplied by the local quest pipeline.
local function _DrawQuest(questId, generation, neededIndices, reportedIndices, drawSpecials, signature)
    if drawnIconCount >= MAX_PARTY_ICONS then return end

    local quest = QuestieDB.GetQuest(questId)
    if not (quest and quest.ObjectiveData) then
        return
    end
    if not quest.Color then
        quest.Color = QuestieLib:ColorWheel()
    end

    local objectives = {}
    local iconCount = 0
    local entry = { objectives = objectives, iconCount = 0, counted = false }
    drawnByQuest[questId] = entry
    local completeDraw = true
    local function _IsCurrentDraw()
        return generation == processingGeneration and drawnByQuest[questId] == entry and _ShouldDraw()
    end

    local function _AbortDraw()
        _UnloadObjectivesLater(objectives)
        if drawnByQuest[questId] == entry then
            drawnByQuest[questId] = nil
        end
    end

    for objectiveIndex, remoteObjective in pairs(neededIndices) do
        if drawnIconCount + iconCount >= MAX_PARTY_ICONS then
            completeDraw = false
            break
        end

        -- Prefer the database ObjectiveData (canonical Type/Id). It only misses an entry at this
        -- index when the party members' databases disagree (e.g. different Questie versions);
        -- in that case fall back to the comms data as a whole, to not mix the two sources.
        local objData = quest.ObjectiveData[objectiveIndex]
        local objType, objId
        if objData then
            objType = objData.Type
            objId = objData.Id or objData.RootId
        else
            objType = typeCharToFull[remoteObjective.type]
            objId = remoteObjective.id
        end

        if objType and (objId or objType == "event") then
            local cachedSpawnList = spawnListCache[questId] and spawnListCache[questId][objectiveIndex]
            -- When the objective's live API type (first char, from comms) differs from the
            -- database's compiled type (kill-credit, events, invisible "bunny" NPCs), the id/type
            -- no longer map to a meaningful name, so use the Blizzard objective text and skip the
            -- name-based fallback. Derived here rather than transmitted so it works for every comms
            -- path, including the full quest list received on login/join.
            local useApiObjectiveText = objData ~= nil and remoteObjective.type ~= nil
                and string.sub(objData.Type, 1, 1) ~= remoteObjective.type
            local apiText = useApiObjectiveText and _GetApiObjectiveText(questId, objectiveIndex) or nil
            local description = apiText or (objData and objData.Text) or (not useApiObjectiveText and _GetObjectiveName(objType, objId)) or ""
            local objective = {
                Id = objId,
                Type = objType,
                Index = objectiveIndex,
                questId = questId,
                Description = description,
                FullDescription = (not useApiObjectiveText) and _GetFullDescription(objType, description) or nil,
                Icon = objData and objData.Icon,
                Coordinates = objData and objData.Coordinates,
                Completed = false,
                spawnList = cachedSpawnList or {},
                AlreadySpawned = {},
                Update = NOP_FUNCTION,
                -- Marks this as a party member's objective (the local player does not have the
                -- quest), so the map tooltip doesn't label it with the local player's name.
                IsPartyObjective = true,
                IsCurrentDraw = _IsCurrentDraw,
                -- Skip in-world unit/item tooltip registration; the map icon tooltip already
                -- shows party members via QuestieComms, and this avoids leaking tooltip entries.
                hasRegisteredTooltips = true,
                registeredItemTooltips = true,
            }

            objectives[#objectives + 1] = objective
            local spawnCache = objective.AlreadySpawned
            QuestieQuest:PopulateObjective(quest, objectiveIndex, objective, true)
            if objective.AlreadySpawned ~= spawnCache then
                _UnloadObjectivesLater({{AlreadySpawned = spawnCache}})
                _AbortDraw()
                return
            end
            if not _IsCurrentDraw() then
                _AbortDraw()
                return
            end
            local objectiveIconCount = _CountIcons(objective)
            if drawnIconCount + iconCount + objectiveIconCount > MAX_PARTY_ICONS then
                completeDraw = false
                _UnloadObjectivesLater({objective})
                objectives[#objectives] = nil
                break
            end
            if (not cachedSpawnList) and objective.spawnList and next(objective.spawnList) then
                if not spawnListCache[questId] then
                    spawnListCache[questId] = {}
                end
                spawnListCache[questId][objectiveIndex] = objective.spawnList
            end
            iconCount = iconCount + objectiveIconCount
            entry.iconCount = iconCount
        end
    end

    -- Also draw the quest's extra/special objectives (DB-defined, e.g. "use item" custom spawns
    -- and required source items). These come from QuestieDB.GetQuest, independent of comms data.
    local visibleSpecialObjectives = {}
    for _, special in pairs(quest.SpecialObjectives or {}) do
        local linkedObjectiveIndex = special.RealObjectiveIndex
        local hasValidLink = linkedObjectiveIndex and linkedObjectiveIndex > 0 and reportedIndices[linkedObjectiveIndex]

        -- Match the local quest pipeline: linked extras disappear when every visible party member
        -- has completed that objective. Unlinked (0/nil) and invalid links remain visible.
        if (hasValidLink and neededIndices[linkedObjectiveIndex]) or (not hasValidLink and drawSpecials) then
            visibleSpecialObjectives[#visibleSpecialObjectives + 1] = special
        end
    end

    local specialCounter = 0
    for _, special in ipairs(visibleSpecialObjectives) do
        if drawnIconCount + iconCount >= MAX_PARTY_ICONS then
            completeDraw = false
            break
        end

        specialCounter = specialCounter + 1
        local objective = {
            Id = special.Id,
            Type = special.Type,
            Index = 64 + specialCounter,
            questId = questId,
            Description = special.Description or "Special objective",
            Icon = special.Icon,
            Coordinates = special.Coordinates,
            Completed = false,
            spawnList = special.spawnList or {},
            AlreadySpawned = {},
            Update = NOP_FUNCTION,
            IsPartyObjective = true,
            IsCurrentDraw = _IsCurrentDraw,
            hasRegisteredTooltips = true,
            registeredItemTooltips = true,
        }

        objectives[#objectives + 1] = objective
        local spawnCache = objective.AlreadySpawned
        QuestieQuest:PopulateObjective(quest, objective.Index, objective, true)
        if objective.AlreadySpawned ~= spawnCache then
            _UnloadObjectivesLater({{AlreadySpawned = spawnCache}})
            _AbortDraw()
            return
        end
        if not _IsCurrentDraw() then
            _AbortDraw()
            return
        end
        local objectiveIconCount = _CountIcons(objective)
        if drawnIconCount + iconCount + objectiveIconCount > MAX_PARTY_ICONS then
            completeDraw = false
            _UnloadObjectivesLater({objective})
            objectives[#objectives] = nil
            break
        end
        iconCount = iconCount + objectiveIconCount
        entry.iconCount = iconCount
    end

    if not _IsCurrentDraw() then
        _AbortDraw()
        return
    end
    if #objectives > 0 then
        entry.counted = true
        drawnIconCount = drawnIconCount + iconCount
        entry.signature = completeDraw and signature or nil
    else
        drawnByQuest[questId] = nil
    end
end

-- Process a queue of questIds in chunks, one chunk per frame, to avoid a single large hitch.
---@param queue number[]
---@param index number
---@param generation number
_ProcessQueue = function(queue, index, generation)
    if generation ~= processingGeneration then
        return
    end

    ThreadLib.ThreadCallbackInstant(function()
        if generation ~= processingGeneration then
            return
        end
        if not _ShouldDraw() then
            QuestiePartyObjectives:Clear()
            return
        end

        local stop = math.min(index + CHUNK_SIZE - 1, #queue)
        for i = index, stop do
            if generation ~= processingGeneration then
                return
            end
            if not _ShouldDraw() then
                QuestiePartyObjectives:Clear()
                return
            end

            local questId = queue[i]
            -- A malformed or incomplete quest must not abort the entire party queue.
            -- The next refresh can clear and retry this quest once its data is ready.
            -- A child coroutine isolates errors without preventing yields on Lua 5.1.
            local worker = coroutine.create(function()
                local needed, reported, drawSpecials = _CollectIndices(questId)
                local signature = _GetDrawSignature(needed, reported, drawSpecials)
                local entry = drawnByQuest[questId]
                if signature and entry and entry.signature == signature and _HasAllIcons(entry) then
                    if MapIconTooltip.RefreshQuest then MapIconTooltip.RefreshQuest(questId) end
                else
                    _ClearQuest(questId)
                    if signature then _DrawQuest(questId, generation, needed, reported, drawSpecials, signature) end
                end
            end)
            local success, err = coroutine.resume(worker)
            while success and coroutine.status(worker) == "suspended" do
                coroutine.yield()
                success, err = coroutine.resume(worker)
            end
            if not success then
                CallErrorHandler(err)
                if generation == processingGeneration then _ClearQuest(questId) end
            end
        end

        if stop < #queue then
            C_Timer.After(0, function()
                if generation ~= processingGeneration then
                    return
                end
                if not _ShouldDraw() then
                    QuestiePartyObjectives:Clear()
                    return
                end

                local ok = xpcall(function()
                    _ProcessQueue(queue, stop + 1, generation)
                end, CallErrorHandler)
                if not ok and generation == processingGeneration then
                    processing = false
                end
            end)
        else
            if generation ~= processingGeneration then
                return
            end
            processing = false
            -- Work that arrived while we were processing.
            if fullRefreshPending or next(dirtyQuests) then
                _ScheduleProcessing()
            end
        end
    end, function(success)
        if not success and generation == processingGeneration then
            -- The worker failed outside the per-quest guard. Release the scheduler and
            -- retry from the current remote quest log instead of staying stuck in processing.
            processing = false
            fullRefreshPending = true
            _ScheduleProcessing()
        end
    end)
end

_ProcessScheduled = function()
    if processing then
        _ScheduleProcessing()
        return
    end

    if not _ShouldDraw() then
        QuestiePartyObjectives:Clear()
        dirtyQuests = {}
        fullRefreshPending = false
        return
    end

    local queue = {}
    if fullRefreshPending then
        fullRefreshPending = false
        dirtyQuests = {}
        -- Retire departed quests without rebuilding the unchanged ones.
        for questId in pairs(drawnByQuest) do
            if not QuestieComms.remoteQuestLogs[questId] then queue[#queue + 1] = questId end
        end
        for questId in pairs(QuestieComms.remoteQuestLogs) do
            queue[#queue + 1] = questId
        end
    else
        for questId in pairs(dirtyQuests) do
            queue[#queue + 1] = questId
        end
        dirtyQuests = {}
    end

    if #queue == 0 then
        return
    end
    processing = true
    _ProcessQueue(queue, 1, processingGeneration)
end

-- Debounce: coalesce bursts of incoming packets into a single processing pass.
_ScheduleProcessing = function()
    if updateScheduled then
        return
    end
    updateScheduled = true
    C_Timer.After(1.5, function()
        local ok = xpcall(function()
            updateScheduled = false
            _ProcessScheduled()
        end, CallErrorHandler)
        if not ok then
            updateScheduled = false
            processing = false
        end
    end)
end

-- Unload all party objective icons and forget them.
function QuestiePartyObjectives:Clear()
    -- Invalidate any queued worker chunks and deferred timer callbacks before unloading.
    processingGeneration = processingGeneration + 1
    processing = false

    for _, entry in pairs(drawnByQuest) do
        _UnloadObjectivesLater(entry.objectives)
    end
    drawnByQuest = {}
    drawnIconCount = 0
end

-- Immediate full refresh, used by the options toggle.
function QuestiePartyObjectives:Update()
    fullRefreshPending = true
    _ProcessScheduled()
end

-- Schedule a debounced redraw. Pass a questId to redraw only that quest (incremental); pass
-- nothing to request a full refresh (e.g. a player left the group).
---@param questId number?
function QuestiePartyObjectives:ScheduleUpdate(questId)
    if not Questie.db.profile.showPartyQuestObjectives then
        return
    end
    if questId then
        dirtyQuests[questId] = true
    else
        fullRefreshPending = true
    end
    _ScheduleProcessing()
end
