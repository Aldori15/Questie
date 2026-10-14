QuestieLoader:StampLoadBoundary()

-- Animation-backed timer APIs for the 3.3.5 client.
local activeTimers = {}
local inactiveTimers = {}

local math_ceil = math.ceil

local MIN_TIMER_DURATION = 0.01
-- WoW 3.3.5 stores animation progress as a single-precision float. Long
-- animation durations can stop advancing once their elapsed time reaches 2048
-- seconds, so longer timer intervals are divided into safe animation chunks.
local MAX_ANIMATION_TIMER_SECONDS = 30 * 60

local function timerCancel(id)
    local timer = activeTimers[id]
    if not timer then return end

    timer:GetParent():Stop()

    timer.id = nil
    activeTimers[id] = nil
	inactiveTimers[timer] = true
end

local function timerOnFinished(self)
    self.pendingChunks = self.pendingChunks - 1
    if self.pendingChunks > 0 then return end

    self.pendingChunks = self.chunksPerIteration
    local id = self.id
    local success, callbackError = pcall(self.callback, id)

    -- Make sure timer wasn't cancelled during the callback and used again
    if id == self.id then
        if self.iterations > 0 then
            self.iterations = self.iterations - 1
            if self.iterations == 0 then
                timerCancel(id)
            end
        end
    end

    -- Finish iteration/cancellation bookkeeping even when the callback fails,
    -- then preserve error reporting instead of repeating a failed one-shot.
    if not success then
        error(callbackError, 0)
    end
end

QuestieCompat.C_Timer = {
    -- Schedules a repeating timer that can be canceled. (https://wowpedia.fandom.com/wiki/API_C_Timer.NewTicker)
    NewTicker = function(duration, callback, iterations)
        local timer = next(inactiveTimers)
        if timer then
        	inactiveTimers[timer] = nil
        else
        	local anim = QuestieCompat.frame:CreateAnimationGroup()
        	timer = anim:CreateAnimation()
        	timer:SetScript("OnFinished", timerOnFinished)
        end

        if duration < MIN_TIMER_DURATION then duration = MIN_TIMER_DURATION end
        local chunksPerIteration = math_ceil(duration / MAX_ANIMATION_TIMER_SECONDS)
        timer:SetDuration(duration / chunksPerIteration)

        timer.callback = callback
        timer.chunksPerIteration = chunksPerIteration
        timer.pendingChunks = chunksPerIteration
        timer.iterations = iterations or -1
        timer.id = {Cancel = timerCancel}
        activeTimers[timer.id] = timer

        local anim = timer:GetParent()
        anim:SetLooping("REPEAT")
        anim:Play()

        return timer.id
    end,
    -- Schedules a one-shot timer that can be canceled. (https://wowpedia.fandom.com/wiki/API_C_Timer.NewTimer)
    NewTimer = function(duration, callback)
        return QuestieCompat.C_Timer.NewTicker(duration, callback, 1)
    end,
    -- Schedules a timer. (https://wowpedia.fandom.com/wiki/API_C_Timer.After)
    After = function(duration, callback)
        return QuestieCompat.C_Timer.NewTimer(duration, callback)
    end
}
