QuestieLoader:StampLoadBoundary("Compat/QuestResets.lua")

---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")

local math_max = math.max
local math_min = math.min

local MAX_DAILY_RESET_SECONDS = 48 * 60 * 60
local FALLBACK_DAILY_RESET_HOUR = 6
local MONTHLY_RESET_HOUR = 6
local SECONDS_PER_DAY = 24 * 60 * 60
local MAX_ANIMATION_TIMER_SECONDS = 30 * 60
local warnedInvalidQuestResetTime = false
local dailyResetRetryTimer

local function _CalculateFallbackQuestResetTime(currentTime, currentDate)
    local resetHour = Questie.db.profile.weeklyResetHour
    if type(resetHour) ~= "number" then
        resetHour = FALLBACK_DAILY_RESET_HOUR
    end

    local nextResetTime = time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day,
        hour = resetHour,
        min = 0,
        sec = 0,
    })

    if (not nextResetTime) or nextResetTime <= currentTime then
        nextResetTime = time({
            year = currentDate.year,
            month = currentDate.month,
            day = currentDate.day + 1,
            hour = resetHour,
            min = 0,
            sec = 0,
        })
    end

    return (nextResetTime or currentTime) - currentTime
end

local function _CalculateNextMonthlyResetTime(currentTime, currentDate)
    local resetThisMonth = time({
        year = currentDate.year,
        month = currentDate.month,
        day = 1,
        hour = MONTHLY_RESET_HOUR,
        min = 0,
        sec = 0,
    })
    if resetThisMonth and currentTime < resetThisMonth then
        return resetThisMonth
    end

    local nextMonth = currentDate.month + 1
    local nextYear = currentDate.year
    if nextMonth > 12 then
        nextMonth = 1
        nextYear = nextYear + 1
    end

    return time({
        year = nextYear,
        month = nextMonth,
        day = 1,
        hour = MONTHLY_RESET_HOUR,
        min = 0,
        sec = 0,
    }) or (currentTime + (32 * SECONDS_PER_DAY))
end

local function _CalculateNextWeeklyResetTime(currentTime, currentDate)
    local resetHour = Questie.db.profile.weeklyResetHour or FALLBACK_DAILY_RESET_HOUR
    local dayOffset = ((Questie.db.profile.weeklyResetDay or 4) - currentDate.weekday + 7) % 7
    local deadline = time({year = currentDate.year, month = currentDate.month,
        day = currentDate.day + dayOffset, hour = resetHour, min = 0, sec = 0})
    if deadline <= currentTime then
        deadline = time({year = currentDate.year, month = currentDate.month,
            day = currentDate.day + dayOffset + 7, hour = resetHour, min = 0, sec = 0})
    end
    return deadline
end

local function _GetLegacyDailyResetTime()
    local char = Questie.db.char
    if next(char.daily or {}) or next(char.acoreDailyQuestCompletions or {}) then
        return Questie.db.profile.dailyResetTime
    end
end

function QuestieCompat.GetQuestResetTime()
    local timeUntilReset = tonumber(GetQuestResetTime())
    local currentTime, currentDate = QuestieCompat.GetServerTime()

    -- Some 3.3.5a servers briefly report a small negative value immediately after
    -- the reset. Treat it as the rollover into the next daily cycle instead of
    -- turning it into a reset timestamp equal to the current time.
    if timeUntilReset and timeUntilReset < 0 and timeUntilReset >= -10 then
        return SECONDS_PER_DAY + timeUntilReset
    end

    if timeUntilReset and timeUntilReset >= 0 and timeUntilReset <= MAX_DAILY_RESET_SECONDS then
        return timeUntilReset
    end

    -- Some private servers return an invalid value close to -GetServerTime(), which means their reset timestamp is zero.
    if (not warnedInvalidQuestResetTime) then
        warnedInvalidQuestResetTime = true
        Questie.Debug(Questie.DEBUG_DEVELOP, "[GetQuestResetTime] Invalid native value, using fallback: ", timeUntilReset)
    end

    local storedResetTime = Questie.db.char.dailyResetTime or _GetLegacyDailyResetTime()
    if type(storedResetTime) == "number" and storedResetTime > currentTime then
        return storedResetTime - currentTime
    end

    return _CalculateFallbackQuestResetTime(currentTime, currentDate)
end

local function _ScheduleDailyResetRetry()
    if dailyResetRetryTimer then
        return
    end

    dailyResetRetryTimer = QuestieCompat.C_Timer.After(3, function()
        dailyResetRetryTimer = nil
        QuestieCompat.CalculateNextResetTime()
        QuestieCompat.ResetDailyQuests()
    end)
end

function QuestieCompat.CalculateNextResetTime()
    local currentTime, currentDate = QuestieCompat.GetServerTime()
    local timeUntilReset = QuestieCompat.GetQuestResetTime()

    Questie.Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] GetQuestResetTime: ", timeUntilReset)

    -- A zero value means the server has not supplied reset data yet. Do not cache
    -- the current time as the next reset; retry after the server data can arrive.
    if timeUntilReset <= 0 then
        _ScheduleDailyResetRetry()
        return
    end

    if dailyResetRetryTimer then
        dailyResetRetryTimer:Cancel()
        dailyResetRetryTimer = nil
    end

    -- Completion history belongs to the character. Migrate its old deadline
    -- once, then keep other characters from advancing this character's reset.
    local dailyResetTime = Questie.db.char.dailyResetTime
    if type(dailyResetTime) ~= "number" then
        local legacyResetTime = _GetLegacyDailyResetTime()
        dailyResetTime = type(legacyResetTime) == "number" and legacyResetTime or (currentTime + timeUntilReset)
        Questie.db.char.dailyResetTime = dailyResetTime
    end
    Questie.db.profile.dailyResetTime = dailyResetTime
    Questie.Debug(Questie.DEBUG_DEVELOP, "[CalculateNextResetTime] Next daily rest time: ", date("%m/%d/%y %H:%M:%S", Questie.db.profile.dailyResetTime))

    Questie.db.profile.weeklyResetHour = Questie.db.profile.weeklyResetHour or tonumber(date("%H", Questie.db.profile.dailyResetTime+300))
    if type(Questie.db.char.weeklyResetTime) ~= "number" then
        local legacy = next(Questie.db.char.weekly or {}) and Questie.db.profile.weeklyResetTime
        Questie.db.char.weeklyResetTime = type(legacy) == "number" and legacy
            or _CalculateNextWeeklyResetTime(currentTime, currentDate)
    end
end

function QuestieCompat.ResetDailyQuests(reset)
    local currentTime = QuestieCompat.GetServerTime()
    local resetTime = Questie.db.char.dailyResetTime

    if type(resetTime) ~= "number" then
        resetTime = _GetLegacyDailyResetTime()
        if type(resetTime) == "number" then
            Questie.db.char.dailyResetTime = resetTime
        end
    end

    local didReset = reset or (type(resetTime) == "number" and currentTime >= resetTime)
    if didReset then
        for questId in pairs(Questie.db.char.daily or {}) do
            Questie.db.char.daily[questId] = nil
            QuestieCompat.ClearQuestCompletion(questId)
        end
        for questId in pairs(Questie.db.char.acoreDailyQuestCompletions or {}) do
            QuestieCompat.ClearQuestCompletion(questId)
        end
        -- A server query can also report dailies completed outside this session.
        QuestieCompat.ClearServerDailyQuestCompletions()
        Questie.db.char.acoreDailyQuestCompletions = {}
        Questie.db.char.dailyResetTime = nil
        Questie.db.profile.dailyResetTime = nil
    end

    if didReset or type(resetTime) ~= "number" then
        QuestieCompat.CalculateNextResetTime()
    end

    if didReset and Questie.started then
        AvailableQuests.CalculateAndDrawAll()
    end

    return didReset
end

local periodicResetTimers = {}
local resetTimingGraceUntil
local function _ResetPeriodicQuests(period)
    local currentTime, currentDate = QuestieCompat.GetServerTime()
    local char = Questie.db.char
    char[period] = char[period] or {}
    char.serverQuestResetTimes = char.serverQuestResetTimes or {}
    local marker = period .. "ResetTime"
    local calculate = period == "weekly" and _CalculateNextWeeklyResetTime or _CalculateNextMonthlyResetTime
    local server = QuestieLoader:ImportModule("QuestieServer")
    local resets = server.GetQuestResetTimes and server:GetQuestResetTimes()
    local didReset, delay = false, nil
    resetTimingGraceUntil = resetTimingGraceUntil or (GetTime() + 5)

    if resets then
        local deadline, previous = resets[period], char.serverQuestResetTimes[period]
        -- Passing the advertised time alone is insufficient: wait for AC to
        -- advance its deadline after actually resetting the quest status.
        didReset = type(previous) == "number" and resets.serverTime >= previous and deadline > previous
        if deadline > resets.serverTime then
            char.serverQuestResetTimes[period] = deadline
            -- Keep a usable fallback in the compatibility clock's time domain.
            char[marker] = currentTime + deadline - resets.serverTime
            delay = deadline - resets.serverTime + 1
        else
            char.serverQuestResetTimes[period] = deadline
            delay = 3
        end
    else
        if type(char[marker]) ~= "number" then
            local legacy = period == "weekly" and next(char.weekly) and Questie.db.profile.weeklyResetTime
            char[marker] = type(legacy) == "number" and legacy or calculate(currentTime, currentDate)
        end
        -- A completed-quest query can arrive before the first bridge response.
        -- Give that response time to correct an expired guessed schedule before
        -- deleting saved completions. An absent bridge still falls back after 5s.
        local waiting = server.GetQuestResetTimes and not server:HasCapability("HEARTBEAT")
            and next(char[period]) and GetTime() < resetTimingGraceUntil
        didReset = currentTime >= char[marker] and not waiting
        if didReset then
            char[marker] = calculate(currentTime, currentDate)
            char.serverQuestResetTimes[period] = nil
        end
        delay = waiting and math_max(1, resetTimingGraceUntil - GetTime()) or (char[marker] - currentTime)
    end

    if didReset then
        for questId in pairs(char[period]) do
            char[period][questId] = nil
            QuestieCompat.ClearQuestCompletion(questId)
        end
        if Questie.started then
            AvailableQuests.CalculateAndDrawAll()
        end
    end

    if periodicResetTimers[period] then periodicResetTimers[period]:Cancel() end
    periodicResetTimers[period] = QuestieCompat.C_Timer.After(math_min(math_max(0.01, delay), MAX_ANIMATION_TIMER_SECONDS), function()
        periodicResetTimers[period] = nil
        if Questie.db.profile.resetDailyQuests then _ResetPeriodicQuests(period) end
    end)
    return didReset
end

function QuestieCompat.ResetWeeklyQuests()
    return _ResetPeriodicQuests("weekly")
end

function QuestieCompat.ResetMonthlyQuests()
    return _ResetPeriodicQuests("monthly")
end

function QuestieCompat.RefreshServerQuestResets()
    if not Questie.db.char or not Questie.db.char.complete or not Questie.db.profile.resetDailyQuests then return end
    QuestieCompat.ResetWeeklyQuests()
    QuestieCompat.ResetMonthlyQuests()
end

local DAILY_QUESTS_MSG = DAILY_QUESTS_REMAINING:gsub("%%d", "(%%d+)"):gsub("|4(.-)$", "")

function QuestieCompat.HandleDailyQuestResetMessage(message)
    if Questie.db.profile.resetDailyQuests then
        local dailyQuestCount = tonumber(message:match(DAILY_QUESTS_MSG))
        if dailyQuestCount and (dailyQuestCount == GetMaxDailyQuests()) then
            QuestieCompat.C_Timer.After(1, function()
                QuestieCompat.ResetDailyQuests(true)
            end)
        end
    end
end
