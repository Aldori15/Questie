---@class QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:CreateModule("QuestieCombatQueue")

---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

local tpack =  QuestieLib.tpack
local tunpack = QuestieLib.tunpack

local _Queue = {}
local started = false
local ticker

-- This will limit the amount of updates Questie does to the UI and will reduce the chance to lag the game
local maxUpdatesPerCircle = 5

local function _ProcessQueue()
    if InCombatLockdown() then
        return
    end

    local entry = tremove(_Queue, 1)
    if not entry then
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        return
    end

    local count = 0
    while entry do
        entry.func(tunpack(entry.args))

        if InCombatLockdown() or count >= maxUpdatesPerCircle then
            break
        end
        entry = tremove(_Queue, 1)
        count = count + 1
    end

    if (not entry) and (not next(_Queue)) and ticker then
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
    if next(_Queue) then
        _StartTicker()
    end
end

function QuestieCombatQueue:Queue(func, ...)
    if started then
        tinsert(_Queue, {func=func, args=tpack(...)})
        _StartTicker()
    end
end