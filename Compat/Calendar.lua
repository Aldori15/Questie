QuestieLoader:StampLoadBoundary()

-- Date stuff
QuestieCompat.CALENDAR_WEEKDAY_NAMES = {
	WEEKDAY_SUNDAY,
	WEEKDAY_MONDAY,
	WEEKDAY_TUESDAY,
	WEEKDAY_WEDNESDAY,
	WEEKDAY_THURSDAY,
	WEEKDAY_FRIDAY,
	WEEKDAY_SATURDAY,
};

-- month names show up differently for full date displays in some languages
QuestieCompat.CALENDAR_FULLDATE_MONTH_NAMES = {
	FULLDATE_MONTH_JANUARY,
	FULLDATE_MONTH_FEBRUARY,
	FULLDATE_MONTH_MARCH,
	FULLDATE_MONTH_APRIL,
	FULLDATE_MONTH_MAY,
	FULLDATE_MONTH_JUNE,
	FULLDATE_MONTH_JULY,
	FULLDATE_MONTH_AUGUST,
	FULLDATE_MONTH_SEPTEMBER,
	FULLDATE_MONTH_OCTOBER,
	FULLDATE_MONTH_NOVEMBER,
	FULLDATE_MONTH_DECEMBER,
};

QuestieCompat.C_Calendar = {
    -- Returns information about the calendar month by offset.
	-- https://wowpedia.fandom.com/wiki/API_C_Calendar.GetMonthInfo
	GetMonthInfo = function(offsetMonths)
        local month, year, numdays, firstday = CalendarGetMonth(offsetMonths or 0);
		return {
			month = month,
			year = year,
			numDays = numdays,
			firstWeekday = firstday,
		}
	end,
    OpenCalendar = function()
        if OpenCalendar then
            OpenCalendar()
        end
    end,
    SetMonth = function(offsetMonths)
        if CalendarSetMonth then
            CalendarSetMonth(offsetMonths or 0)
        end
    end,
    GetNumDayEvents = function(offsetMonths, dayOfMonth)
        if CalendarGetNumDayEvents then
            return CalendarGetNumDayEvents(offsetMonths or 0, dayOfMonth)
        end

        return 0
    end,
    GetHolidayInfo = function(offsetMonths, dayOfMonth, index)
        if not CalendarGetHolidayInfo then
            return nil
        end

        local name, description, texture = CalendarGetHolidayInfo(
            offsetMonths or 0,
            dayOfMonth,
            index
        )

        if not name then
            return nil
        end

        return {
            name = name,
            description = description,
            texture = texture,
        }
    end,
}

QuestieCompat.C_DateAndTime = {
    -- Returns the realm's current date and time.
	-- https://wowpedia.fandom.com/wiki/API_C_DateAndTime.GetCurrentCalendarTime
	GetCurrentCalendarTime = function()
		local weekday, month, day, year = CalendarGetDate();
		local hours, minutes = GetGameTime()
		return {
			year = year,
			month = month,
			monthDay = day,
			weekday = weekday,
			hour = hours,
			minute = minutes
		}
	end
}

-- Returns the server's Unix time.
-- https://wowpedia.fandom.com/wiki/API_GetServerTime
function QuestieCompat.GetServerTime()
    local weekday, month, day, year = CalendarGetDate()
	local hours, minutes = GetGameTime()

    local currentDate = {
        year = year,
        month = month,
        day = day,
        weekday = weekday,
        hour = hours,
        min = minutes,
    }

    return time(currentDate), currentDate
end
