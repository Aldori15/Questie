-- Run from the addon directory with Lua 5.1 or 5.2. Exercise the production
-- timer API by delivering animation completion events as the client would.
local function loadInEnv(path, env)
    if setfenv then return setfenv(assert(loadfile(path)), env)() end
    return assert(loadfile(path, "t", env))()
end

local function harness()
    local frame = {groups = {}}
    function frame:CreateAnimationGroup()
        local group = {playing = false, stops = 0}
        self.groups[#self.groups + 1] = group
        function group:CreateAnimation()
            local animation = {scripts = {}}
            self.animation = animation
            function animation:GetParent() return group end
            function animation:SetDuration(duration) self.duration = duration end
            function animation:SetScript(event, callback) self.scripts[event] = callback end
            return animation
        end
        function group:SetLooping(mode) self.looping = mode end
        function group:Play() self.playing = true; frame.lastPlayed = self end
        function group:Stop() self.playing = false; self.stops = self.stops + 1 end
        function group:FinishCycle()
            if self.playing then self.animation.scripts.OnFinished(self.animation) end
        end
        return group
    end
    local boundaries = 0
    local env = setmetatable({
        QuestieCompat = {frame = frame},
        QuestieLoader = {StampLoadBoundary = function() boundaries = boundaries + 1 end},
    }, {__index = _G})
    loadInEnv("Compat/Timers.lua", env)
    assert(boundaries == 1, "timer file records its load boundary")
    assert(#frame.groups == 0, "loading the API does not start timers")
    return env.QuestieCompat.C_Timer, frame
end

-- Both one-shot entry points preserve their handle and fire only once.
for _, method in ipairs({"NewTimer", "After"}) do
    local timers, frame = harness()
    local calls, delivered = 0
    local handle = timers[method](2.5, function(id) calls = calls + 1; delivered = id end)
    local group = frame.lastPlayed
    assert(calls == 0 and group.animation.duration == 2.5)
    assert(group.looping == "REPEAT", "one-shot uses the client animation scheduler")
    group:FinishCycle()
    assert(calls == 1 and delivered == handle and not group.playing)
    group:FinishCycle()
    handle:Cancel()
    assert(calls == 1 and group.stops == 1, "finished timer cannot run or stop twice")
end

-- Finite and indefinite tickers keep their existing iteration semantics.
do
    local timers, frame = harness()
    local calls = 0
    local handle
    handle = timers.NewTicker(0.25, function(id)
        assert(id == handle)
        calls = calls + 1
    end, 3)
    local group = frame.lastPlayed
    for count = 1, 3 do
        group:FinishCycle()
        assert(calls == count and group.playing == (count < 3))
    end
    group:FinishCycle()
    assert(calls == 3)
end
do
    local timers, frame = harness()
    local calls = 0
    local handle = timers.NewTicker(1, function() calls = calls + 1 end)
    local group = frame.lastPlayed
    for _ = 1, 6 do group:FinishCycle() end
    assert(calls == 6 and group.playing)
    handle:Cancel()
    handle:Cancel()
    group:FinishCycle()
    assert(calls == 6 and not group.playing and group.stops == 1)
end

-- Cancelling before the first completion suppresses the callback. Reusing
-- the pooled animation must not let its old handle cancel the new timer.
do
    local timers, frame = harness()
    local calls = 0
    local old = timers.NewTimer(5, function() error("cancelled callback ran") end)
    local group = frame.lastPlayed
    old:Cancel()
    group:FinishCycle()
    local current = timers.NewTimer(7, function() calls = calls + 1 end)
    assert(current ~= old and #frame.groups == 1 and frame.lastPlayed == group)
    old:Cancel()
    assert(group.playing and group.animation.duration == 7)
    group:FinishCycle()
    assert(calls == 1 and not group.playing)
end

-- A callback can cancel itself and immediately reuse its animation. The old
-- completion must not consume an iteration of the newly scheduled ticker.
do
    local timers, frame = harness()
    local replacement, calls = nil, 0
    timers.NewTicker(1, function(id)
        id:Cancel()
        replacement = timers.NewTicker(4, function() calls = calls + 1 end, 2)
    end)
    local group = frame.lastPlayed
    group:FinishCycle()
    assert(replacement and #frame.groups == 1 and group.animation.duration == 4)
    group:FinishCycle()
    assert(calls == 1 and group.playing, "replacement retains both iterations")
    group:FinishCycle()
    assert(calls == 2 and not group.playing)
end

-- Independent live timers cannot cancel or consume each other's callbacks.
do
    local timers, frame = harness()
    local firstCalls, secondCalls = 0, 0
    local first = timers.NewTicker(1, function() firstCalls = firstCalls + 1 end)
    local firstGroup = frame.lastPlayed
    local second = timers.NewTicker(2, function() secondCalls = secondCalls + 1 end)
    local secondGroup = frame.lastPlayed
    assert(#frame.groups == 2)
    firstGroup:FinishCycle()
    assert(firstCalls == 1 and secondCalls == 0)
    first:Cancel()
    firstGroup:FinishCycle()
    secondGroup:FinishCycle()
    assert(firstCalls == 1 and secondCalls == 1 and secondGroup.playing)
    second:Cancel()
end

-- Very short requests retain the minimum animation duration.
do
    local timers, frame = harness()
    local calls = 0
    for _, duration in ipairs({0, -2, 0.005}) do
        timers.NewTimer(duration, function() calls = calls + 1 end)
        assert(frame.lastPlayed.animation.duration == 0.01)
        frame.lastPlayed:FinishCycle()
    end
    assert(calls == 3 and #frame.groups == 1)
end

-- Day-long tickers use short animation cycles, but only call the consumer
-- when its full interval passes. Check repeated intervals and boundary cases.
do
    local timers, frame = harness()
    local calls = 0
    timers.NewTicker(86400, function() calls = calls + 1 end, 2)
    local group = frame.lastPlayed
    assert(group.animation.duration == 1800)
    for expected = 1, 2 do
        for _ = 1, 47 do group:FinishCycle(); assert(calls == expected - 1) end
        group:FinishCycle()
        assert(calls == expected and group.playing == (expected < 2))
    end
    for _, duration in ipairs({1800, 1801}) do
        local count = 0
        timers.NewTimer(duration, function() count = count + 1 end)
        group = frame.lastPlayed
        if duration == 1800 then
            assert(group.animation.duration == 1800)
        else
            assert(group.animation.duration == 900.5)
            group:FinishCycle()
            assert(count == 0, "partial long interval never fires early")
        end
        group:FinishCycle()
        assert(count == 1 and not group.playing)
    end
end

-- A failed one-shot reports its original error and still stops exactly once.
-- Its cancelled handle must not affect a timer that later reuses the animation.
for _, method in ipairs({"NewTimer", "After"}) do
    local timers, frame = harness()
    local calls, originalError = 0, {}
    local handle
    handle = timers[method](1, function(id)
        assert(id == handle, "failed callback receives its timer handle")
        calls = calls + 1
        error(originalError)
    end)
    local group = frame.lastPlayed
    local success, reportedError = pcall(function() group:FinishCycle() end)
    assert(not success and reportedError == originalError, "callback error remains observable and unchanged")
    assert(calls == 1 and not group.playing and group.stops == 1, "failed one-shot is stopped")
    group:FinishCycle()
    handle:Cancel()
    assert(calls == 1 and group.stops == 1, "failed one-shot cannot repeat or cancel twice")
    local replacementCalls = 0
    timers.NewTimer(2, function() replacementCalls = replacementCalls + 1 end)
    assert(frame.lastPlayed == group and #frame.groups == 1, "failed animation returns to pool")
    handle:Cancel()
    assert(group.playing, "failed timer handle cannot cancel its replacement")
    group:FinishCycle()
    assert(replacementCalls == 1 and not group.playing, "replacement fires normally")
end

-- Cleanup after an error must not cancel or consume the replacement created
-- inside a callback that cancels itself and reuses its animation immediately.
for _, method in ipairs({"NewTimer", "After"}) do
    local timers, frame = harness()
    local originalError, replacement, calls = {}, nil, 0
    timers[method](1, function(id)
        id:Cancel()
        replacement = timers.NewTicker(4, function() calls = calls + 1 end, 2)
        error(originalError)
    end)
    local group = frame.lastPlayed
    local success, reportedError = pcall(function() group:FinishCycle() end)
    assert(not success and reportedError == originalError, "self-cancelling callback still reports its error")
    assert(replacement and #frame.groups == 1 and group.playing and group.animation.duration == 4)
    assert(group.stops == 1, "error cleanup does not stop the replacement")
    group:FinishCycle()
    assert(calls == 1 and group.playing, "replacement retains its first iteration")
    group:FinishCycle()
    assert(calls == 2 and not group.playing, "replacement retains its final iteration")
end

-- Finite tickers share the completion path; their failing final callback must
-- still finish, while an indefinite ticker remains scheduled after an error.
do
    local timers, frame = harness()
    local calls, originalError = 0, {}
    timers.NewTicker(1, function()
        calls = calls + 1
        if calls == 2 then error(originalError) end
    end, 2)
    local group = frame.lastPlayed
    group:FinishCycle()
    assert(calls == 1 and group.playing, "finite ticker retains its next iteration")
    local success, reportedError = pcall(function() group:FinishCycle() end)
    assert(not success and reportedError == originalError)
    group:FinishCycle()
    assert(calls == 2 and not group.playing and group.stops == 1, "failed final iteration stops finite ticker")
    local handle = timers.NewTicker(1, function() error(originalError) end)
    group = frame.lastPlayed
    success, reportedError = pcall(function() group:FinishCycle() end)
    assert(not success and reportedError == originalError and group.playing, "indefinite ticker preserves repeating behavior")
    handle:Cancel()
    assert(not group.playing, "indefinite ticker remains cancellable after an error")
end

print("Compatibility timers: one-shots, tickers, callback errors, cancellation, reuse and long intervals passed")
