-- Run with Lua 5.2+. Real ThreadLib/profiler callbacks with a controlled clock.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.000001, label .. ": expected " .. expected .. ", got " .. actual)
end
local function noop() end
local env = setmetatable({}, {__index = _G})
local modules, timers, errors, now = {}, {}, {}, 0
env.Questie = {Error = function(...) errors[#errors + 1] = {...} end}
env.debugstack = function() return "test stack" end
env.CreateFrame = function() return {SetScript = noop} end
env.QuestieCompat = {Is335 = true, C_Timer = {NewTicker = function(_, callback)
    local timer = {tick = callback, Cancel = function(self) self.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end}}
env.QuestieLoader = {
    _modules = modules,
    CreateModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    ImportModule = function(_, name) modules[name] = modules[name] or {private = {}}; return modules[name] end,
    GetProfilerTime = function() return now / 1000 end,
}
modules.ProfilerUI = {Create = noop, Hide = noop, Show = noop, private = {}}
assert(loadfile("Modules/Libs/ThreadLib.lua", "t", env))()
assert(loadfile("Modules/Profiler/QuestieProfiler.lua", "t", env))()
assert(loadfile("Modules/Profiler/QuestieProfilerReport.lua", "t", env))()
local profiler, threadLib, report = modules.Profiler, modules.ThreadLib, modules.ProfilerReport
-- Hook traversal/UI construction are independent of the resume observers under test.
profiler.RefreshHooks = function() return true end
profiler.FindPreHookExclusionMismatches = function() return {} end
assert(profiler:Start(false))
local function spend(milliseconds) now = now + milliseconds end
local function submit(name, fn)
    threadLib.Thread(fn, 0, nil, nil, name)
    return timers[#timers]
end
local function rowFor(name)
    local key = "ThreadLib job: " .. name
    for _, row in ipairs(report.BuildReport(profiler).rows) do
        if row.lookupKey == key then return row end
    end
    error("Missing job: " .. name)
end
local function measurement(name, total, count, longest, average, jobs)
    local row = rowFor(name)
    near(row.totalTime, total, "active total")
    equal(row.resumeCount, count, "resume count")
    near(row.maxResumeTime, longest, "longest resume")
    near(row.averageResumeTime, average, "average resume")
    equal(row.jobCalls, jobs, "submitted jobs")
    near(row.averageTime, jobs > 0 and total / jobs or 0, "existing per-job average")
    return row
end

local name = "AvailableQuests.CalculateAndDrawAll"
local timer = submit(name, function()
    spend(2); coroutine.yield()
    spend(4); coroutine.yield()
    spend(9)
end)
measurement(name, 0, 0, 0, 0, 1) -- Submitted but not resumed: no division by zero.
timer.tick(); measurement(name, 2, 1, 2, 2, 1)
spend(1000) -- Suspended scheduler time never enters either duration metric.
timer.tick(); measurement(name, 6, 2, 4, 3, 1)
spend(500)
timer.tick(); measurement(name, 15, 3, 9, 5, 1)
timer.tick() -- Dead coroutine cleanup is not a resume.
measurement(name, 15, 3, 9, 5, 1)
equal(timer.cancelled, true, "completed timer cancelled")

timer = submit(name, function() spend(1); coroutine.yield(); spend(3) end)
timer.tick(); timer.tick(); timer.tick()
measurement(name, 19, 5, 9, 3.8, 2) -- Same named jobs aggregate; maximum is not summed.

timer = submit(name, function() spend(50); coroutine.yield(); spend(2) end)
timer.tick()
measurement(name, 69, 6, 50, 11.5, 3)
profiler:ResetMeasurements()
measurement(name, 0, 0, 0, 0, 1) -- Suspended job remains in the fresh window.
spend(1000)
timer.tick(); timer.tick()
measurement(name, 2, 1, 2, 2, 1)

profiler:ResetMeasurements()
timer = submit(name, function()
    spend(7)
    profiler:ResetMeasurements() -- Reset within a resume trims its elapsed prefix.
    spend(3)
end)
timer.tick(); timer.tick()
measurement(name, 3, 1, 3, 3, 1)

timer = submit("FailingJob", function() spend(5); error("intentional failure") end)
timer.tick()
measurement("FailingJob", 5, 1, 5, 5, 1)
equal(timer.cancelled, true, "failed timer cancelled")
equal(#errors, 1, "failure reported once without breaking profiling")
profiler:Stop()
measurement(name, 3, 1, 3, 3, 1) -- Stopping retains the capture.
assert(profiler:Start(false))
equal(next(profiler.threadJobMaxResumeTime), nil, "starting a session clears old maxima")
timer = submit(name, function() spend(1) end)
timer.tick(); timer.tick()
measurement(name, 1, 1, 1, 1, 1)

-- Grouped reports sum time/counts, take the maximum, and weight the resume average.
local grouped = report.BuildReport({
    hookCallCount = {["ThreadLib job: Job.private.Refresh"] = 1, ["ThreadLib job: Job.Refresh"] = 1},
    hookTimeCount = {["ThreadLib job: Job.private.Refresh"] = 2, ["ThreadLib job: Job.Refresh"] = 14},
    threadJobCallCount = {["ThreadLib job: Job.private.Refresh"] = 1, ["ThreadLib job: Job.Refresh"] = 1},
    threadJobResumeCount = {["ThreadLib job: Job.private.Refresh"] = 1, ["ThreadLib job: Job.Refresh"] = 2},
    threadJobMaxResumeTime = {["ThreadLib job: Job.private.Refresh"] = 2, ["ThreadLib job: Job.Refresh"] = 10},
}, {grouped = true})
equal(#grouped.rows, 1, "grouped jobs merged")
local row = grouped.rows[1]
near(row.totalTime, 16, "grouped total")
equal(row.resumeCount, 3, "grouped resumes")
near(row.maxResumeTime, 10, "grouped maximum")
near(row.averageResumeTime, 16 / 3, "weighted grouped average")
near(row.averageTime, 8, "grouped per-job average retained")
local capturedRow = row
profiler:ResetMeasurements()
near(capturedRow.maxResumeTime, 10, "built report retains its captured maximum")

local functionRow = report.BuildReport({hookCallCount = {Sample = 2}, hookTimeCount = {Sample = 8}}).rows[1]
equal(functionRow.maxResumeTime, nil, "ordinary function has no resume maximum")
equal(functionRow.averageResumeTime, nil, "ordinary function has no resume average")
near(functionRow.averageTime, 4, "ordinary per-call average retained")

-- The frame-free detail formatter used by the actual UI exposes both new metrics.
env.SlashCmdList = {}
assert(loadfile("Modules/Profiler/QuestieProfilerUI.lua", "t", env))()
local detail = modules.ProfilerUI.private.DetailLineFor(capturedRow)
assert(detail:find("10.000 ms longest resume", 1, true), detail)
assert(detail:find("5.333 ms avg resume", 1, true), detail)
assert(detail:find("3 resumes", 1, true), detail)
print("Profiler resume timing: slice timing, waits, aggregation, resets, failures, session lifecycle and UI details passed")
