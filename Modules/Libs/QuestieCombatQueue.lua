---@class QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:CreateModule("QuestieCombatQueue")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

local tpack =  QuestieLib.tpack
local tunpack = QuestieLib.tunpack

local _Queue = {}
local _EntryPool = {}
local queueHead = 1
local queueTail = 0
local started = false
local ticker

-- This will limit the amount of updates Questie does to the UI and will reduce the chance to lag the game
local maxUpdatesPerCircle = 5

local function _QueueIsEmpty()
    return queueHead > queueTail
end

local function _ResetQueue()
    queueHead = 1
    queueTail = 0
end

local function _AcquireEntry(func, ...)
    local entry = next(_EntryPool)
    if entry then
        _EntryPool[entry] = nil
    else
        entry = {}
    end

    entry.func = func
    if select("#", ...) > 0 then
        entry.args = tpack(...)
    else
        entry.args = nil
    end

    return entry
end

local function _ReleaseEntry(entry)
    entry.func = nil
    entry.args = nil
    _EntryPool[entry] = true
end

local function _ProcessQueue()
    if InCombatLockdown() then
        return
    end

    local entry = _Queue[queueHead]
    if not entry then
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        _ResetQueue()
        return
    end

    local count = 0
    while entry do
        _Queue[queueHead] = nil
        queueHead = queueHead + 1

        if entry.args then
            entry.func(tunpack(entry.args))
        else
            entry.func()
        end

        _ReleaseEntry(entry)
        count = count + 1

        if InCombatLockdown() or count >= maxUpdatesPerCircle then
            break
        end
        entry = _Queue[queueHead]
    end

    if _QueueIsEmpty() then
        _ResetQueue()
    end

    if _QueueIsEmpty() and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function _StartTicker()
    if not ticker then
        ticker = C_Timer.NewTicker(0.1, _ProcessQueue)
    end
end

function QuestieCombatQueue.Initialize()
    started = true
    if not _QueueIsEmpty() then
        _StartTicker()
    end
end

function QuestieCombatQueue:Queue(func, ...)
    if started then
        queueTail = queueTail + 1
        _Queue[queueTail] = _AcquireEntry(func, ...)
        _StartTicker()
    end
end