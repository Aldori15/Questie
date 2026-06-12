---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieStream
local QuestieStream = QuestieLoader:ImportModule("QuestieStreamLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieEventHandler
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type TrackerLinePool
local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@class QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords")
---@class Sounds
local Sounds = QuestieLoader:ImportModule("Sounds")
---@class QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@class QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@class QuestieNameplate
local QuestieNameplate = QuestieLoader:ImportModule("QuestieNameplate")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@class QuestieLink
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")

-- addon/folder name
QuestieCompat.addonName = ...

QuestieCompat.NOOP = function() end
QuestieCompat.NOOP_MT = {__index = function() return QuestieCompat.NOOP end}

-- events handler
QuestieCompat.frame = CreateFrame("Frame")
QuestieCompat.frame:RegisterEvent("ADDON_LOADED")
QuestieCompat.frame:RegisterEvent("PLAYER_LOGIN")
QuestieCompat.frame:RegisterEvent("PLAYER_LOGOUT")
QuestieCompat.frame:SetScript("OnEvent", function(self, event, ...)
    QuestieCompat[event](self, event, ...)
end)

-- current expansion level (https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID)
QuestieCompat.WOW_PROJECT_CLASSIC = 2
QuestieCompat.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
QuestieCompat.WOW_PROJECT_WRATH_CLASSIC = 11
QuestieCompat.WOW_PROJECT_ID = tonumber(GetAddOnMetadata(QuestieCompat.addonName, "X-WOW_PROJECT_ID"))

-- check for a specific type of group
QuestieCompat.LE_PARTY_CATEGORY_HOME = 1 -- home-realm parties
QuestieCompat.LE_PARTY_CATEGORY_INSTANCE = 2 -- instance-specific groups

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

-- https://wago.tools/db2/ChrRaces?build=3.4.3.52237
QuestieCompat.ChrRaces = {
	Human = 1,
	Orc = 2,
	Dwarf = 3,
	NightElf = 4,
	Scourge = 5,
	Tauren = 6,
	Gnome = 7,
	Troll = 8,
	Goblin = 9,
	BloodElf = 10,
	Draenei = 11,
	FelOrc = 12,
	Naga_ = 13,
	Broken = 14,
	Skeleton = 15,
	Vrykul = 16,
	Tuskarr = 17,
	ForestTroll = 18,
	Taunka = 19,
	NorthrendSkeleton = 20,
	IceTroll = 21,
}

-- https://wago.tools/db2/ChrClasses?build=3.4.3.52237
QuestieCompat.ChrClasses = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 3,
	ROGUE = 4,
	PRIEST = 5,
	DEATHKNIGHT = 6,
	SHAMAN = 7,
	MAGE = 8,
	WARLOCK = 9,
	DRUID = 11,
}

local activeTimers = {}
local inactiveTimers = {}

local math_max = math.max
local strfind = string.find

local MIN_TIMER_DURATION = 0.01

local function timerCancel(id)
    local timer = activeTimers[id]
    if not timer then return end

    timer:GetParent():Stop()

    timer.id = nil
    activeTimers[id] = nil
	inactiveTimers[timer] = true
end

local function timerOnFinished(self)
    local id = self.id
    self.callback(id)

    -- Make sure timer wasn't cancelled during the callback and used again
    if id == self.id then
        if self.iterations > 0 then
            self.iterations = self.iterations - 1
            if self.iterations == 0 then
                timerCancel(id)
            end
        end
    end
end

QuestieCompat.C_Timer = {
    -- Schedules a (repeating) timer that can be canceled. (https://wowpedia.fandom.com/wiki/API_C_Timer.NewTimer)
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
        timer:SetDuration(duration)

        timer.callback = callback
        timer.iterations = iterations or -1
        timer.id = {Cancel = timerCancel}
        activeTimers[timer.id] = timer

        local anim = timer:GetParent()
        anim:SetLooping("REPEAT")
        anim:Play()

        return timer.id
    end,
    -- Schedules a timer. (https://wowpedia.fandom.com/wiki/API_C_Timer.After)
    After = function(duration, callback)
        return QuestieCompat.C_Timer.NewTicker(duration, callback, 1)
    end
}

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

-- https://wowwiki-archive.fandom.com/wiki/API_UnitGUID?oldid=2368080
local GUIDType = {
    [0]="Player",
    [1]="GameObject",
    [3]="Creature",
    [4]="Pet",
    [5]="Vehicle"
}

-- Returns the GUID of the unit.
-- https://wowpedia.fandom.com/wiki/GUID
-- Patch 6.0.2 (2014-10-14): Changed to a new format
function QuestieCompat.UnitGUID(unit)
    local guid = UnitGUID(unit)
    if guid then
        local type = tonumber(guid:sub(5,5), 16) % 8
        if type and (type == 1 or type == 3 or type == 5) then
            local id = tonumber(guid:sub(6, 12), 16)
            -- Creature-0-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
            return string.format("%s-0-4170-0-41-%d-00000F4B37", GUIDType[type], id)
        end
    end
end

function QuestieCompat.GetMaxPlayerLevel()
    return (Questie.IsWotlk and 80) or (Questie.IsTBC and 70) or (Questie.IsClassic and 60)
end

-- https://wowpedia.fandom.com/wiki/API_UnitAura?oldid=2681338
-- Returns the buffs/debuffs for the unit.
-- an alias for UnitAura(unit, index, "HELPFUL"), returning only buffs.
-- Patch 8.0.1 (2018-07-17): Removed 'rank' return value.
function QuestieCompat.UnitBuff(unit, index)
    local name, rank, icon, count, debuffType, duration, expirationTime,
        unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff(unit, index)
    return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
end

-- Returns the race of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitRace
function QuestieCompat.UnitRace(unit)
    local raceName, raceFile = UnitRace(unit)
    return raceName, raceFile, QuestieCompat.ChrRaces[raceFile]
end

-- Returns the class of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitClass
-- Patch 5.0.4 (2012-08-28): Added classId return value.
function QuestieCompat.UnitClass(unit)
    local className, classFile = UnitClass(unit)
    return className, classFile, QuestieCompat.ChrClasses[classFile]
end

-- Returns info for a faction.
-- https://wowpedia.fandom.com/wiki/API_GetFactionInfo
-- Patch 5.0.4 (2012-08-28): Added new return value: factionID
-- TODO: localize factions name(https://www.curseforge.com/wow/addons/libbabble-faction-3-0)
function QuestieCompat.GetFactionInfo(factionIndex)
    local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

    return name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, QuestieCompat.FactionId[name:trim()]
end

-- Returns true if the unit is a member of your party
-- https://wowpedia.fandom.com/wiki/API_UnitInParty
-- As of 2.0.3, UnitInParty("player") always returns 1, even when you are not in a party.
function QuestieCompat.UnitInParty(unit)
    if unit == "player" then
        return QuestieCompat.IsInGroup()
    end
    return UnitInParty(unit)
end

-- Returns true if the player is in a group.
-- https://wowpedia.fandom.com/wiki/API_IsInGroup
function QuestieCompat.IsInGroup(groupType)
    if groupType then return false end
    return UnitInParty("player") and GetNumPartyMembers() > 0
end

-- Returns true if the player is in a raid.
-- https://wowpedia.fandom.com/wiki/API_IsInRaid
function QuestieCompat.IsInRaid(groupType)
    if groupType then return false end
    return UnitInRaid("player") and GetNumRaidMembers() > 0
end

-- Returns names of characters in your home (non-instance) party.
-- https://wowpedia.fandom.com/wiki/API_GetHomePartyInfo
function QuestieCompat.GetHomePartyInfo(homePlayers)
	if QuestieCompat.UnitInParty("player") then
		homePlayers = homePlayers or {}
		for i=1, MAX_PARTY_MEMBERS do
			if GetPartyMember(i) then
				table.insert(homePlayers, UnitName("party"..i))
			end
		end
		return homePlayers
	end
end

-- Gets a list of the auction house item classes.
-- https://wowpedia.fandom.com/wiki/API_GetAuctionItemClasses?oldid=1835520
local itemClass = {GetAuctionItemClasses()}
for classId, className in ipairs(itemClass) do
    itemClass[className] = classId
    itemClass[classId] = nil
end

-- Returns info for an item.
-- https://wowpedia.fandom.com/wiki/API_GetItemInfo?oldid=2376031
-- Patch 7.0.3 (2016-07-19): Added classID, subclassID returns.
function QuestieCompat.GetItemInfo(item)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(item)

    return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice, itemClass[itemType]
end

-- Returns info for an item in a container slot.
-- https://wowpedia.fandom.com/wiki/API_GetContainerItemInfo
function QuestieCompat.GetContainerItemInfo(bagID, slot)
	local iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink = GetContainerItemInfo(bagID, slot)
    if hyperlink then
	    local itemID = string.match(hyperlink, "(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	    -- GetContainerItemInfo does not return a quality value for all items.  If it does not, it returns -1
	    if quality and quality < 0 then
	    	quality = (select(3, GetItemInfo(hyperlink)))
	    end

	    return iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, false, false, tonumber(itemID), false
    end
end

-- https://wowpedia.fandom.com/wiki/API_IsSpellKnown
QuestieCompat.IsSpellKnownOrOverridesKnown = IsSpellKnown
QuestieCompat.IsPlayerSpell = IsSpellKnown

local LARGE_NUMBER_SEPERATOR = ",";
function QuestieCompat.FormatLargeNumber(amount)
	amount = tostring(amount);
	local newDisplay = "";
	local strlen = amount:len();
	--Add each thing behind a comma
	for i=4, strlen, 3 do
		newDisplay = LARGE_NUMBER_SEPERATOR..amount:sub(-(i - 1), -(i - 3))..newDisplay;
	end
	--Add everything before the first comma
	newDisplay = amount:sub(1, (strlen % 3 == 0) and 3 or (strlen % 3))..newDisplay;
	return newDisplay;
end

local function Round(value)
	if value < 0.0 then
		return math.ceil(value - .5);
	end
	return math.floor(value + .5);
end
QuestieCompat.Round = Round

local function GenerateHexColor(r, g, b, a)
	return ("ff%.2x%.2x%.2x"):format(Round(r * 255), Round(g * 255), Round(b * 255), Round((a or 1) * 255));
end

-- Returns the color value associated with a given class.
function QuestieCompat.GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename];
	if color then
		return color.r, color.g, color.b, GenerateHexColor(color.r, color.g, color.b)
	end
	return 1, 1, 1, "ffffffff";
end

--[[
    xpcall wrapper implementation
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, eh, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh or errorhandler)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", table.concat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

Dispatchers[0] = function(func, eh)
	return xpcall(func, eh or errorhandler)
end

function QuestieCompat.xpcall(func, eh, ...)
    if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, eh, ...)
	end
end

--[[
    It seems that the table size is capped in 3.3.5, with a maximum of 524,288 entries.
    For instance, this code triggers an error message: 'memory allocation error: block too big.

    local t = {}
	for i=1, 524289 do
		t[i] = true
	end

    Spliting the table into multiple subtables should do the trick.
]]

local stringchar = string.char
local MAX_TABLE_SIZE = 524288

function QuestieCompat._writeByte(self, val)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

	self._bin[subIndex] = self._bin[subIndex] or {}
	self._bin[subIndex][index] = stringchar(val)

    self._pointer = self._pointer + 1
end

function QuestieCompat._readByte(self)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

    self._pointer = self._pointer + 1

	return self._bin[subIndex][index]
end

function QuestieCompat.Save(self)
	local result = ""
	for i=1, #self._bin do
		result = result .. table.concat(self._bin[i])
	end
	return result
end

local _QuestieNameplate = QuestieNameplate.private
local npFrames = {}
local npActiveQuestNPCs = {}
local npBorderTexture = "Interface\\Tooltips\\Nameplate-Border"

local function isNamePlate(frame)
    if frame.UnitFrame  -- ElvUI
    or frame.extended   -- TidyPlates
    or frame.aloftData  -- Aloft
    or frame.kui  -- Kui_Nameplate
    then return true end

    local _, borderRegion = frame:GetRegions()
    if borderRegion and borderRegion:GetObjectType() == "Texture" then
        return borderRegion:GetTexture() == npBorderTexture
    end

    return false
end

local function scanWorldFrameChildren(...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if frame and (not npFrames[frame]) and isNamePlate(frame) then
            npFrames[frame] = select(7, frame:GetRegions())

            frame:HookScript("OnShow", QuestieCompat.NameplateCreated)
            frame:HookScript("OnHide", _QuestieNameplate.RemoveFrame)

            if frame:IsShown() then
                QuestieCompat.NameplateCreated(frame)
            end
        end
    end
end

local function getGUID(unit)
    if type(unit) == "string" then
        return UnitGUID(unit)
    elseif type(unit) == "table" then
        if unit.guid then
            return unit.guid
        elseif type(unit.unit) == "string" then
            return UnitGUID(unit.unit)
        elseif type(unit.unitid) == "string" then
            return UnitGUID(unit.unitid)
        elseif type(unit.unitID) == "string" then
            return UnitGUID(unit.unitID)
        elseif type(unit.unitToken) == "string" then
            return UnitGUID(unit.unitToken)
        elseif unit.isTarget then
            return UnitGUID("target")
        elseif unit.isMouseover then
            return UnitGUID("mouseover")
        elseif type(unit.partyID) == "string" then
            return UnitGUID(unit.partyID)
        end
    end
end

local function getGUIDFromCandidates(...)
    for i = 1, select("#", ...) do
        local guid = getGUID(select(i, ...))
        if guid then return guid end
    end
end

local function getNameplateFrameGUID(frame)
    local guid = getGUIDFromCandidates(frame.unit, frame.unitid, frame.unitID, frame.unitToken, frame.namePlateUnitToken)
    if guid then return guid end

    if frame.UnitFrame then
        guid = getGUIDFromCandidates(frame.UnitFrame.unit, frame.UnitFrame.unitid, frame.UnitFrame.unitID, frame.UnitFrame.unitToken)
        if guid then return guid end
    end

    if frame.unitFrame then
        guid = getGUIDFromCandidates(frame.unitFrame.unit, frame.unitFrame.unitid, frame.unitFrame.unitID, frame.unitFrame.unitToken)
        if guid then return guid end
    end

    if frame.extended then
        guid = getGUIDFromCandidates(frame.extended.unit, frame.extended.unitid, frame.extended.unitID, frame.extended.unitToken)
        if guid then return guid end
    end

    if frame.aloftData then
        guid = getGUIDFromCandidates(frame.aloftData.unit, frame.aloftData.unitid, frame.aloftData.unitID, frame.aloftData.unitToken)
        if guid then return guid end
    end

    if frame.kui then
        return getGUIDFromCandidates(frame.kui.unit, frame.kui.unitid, frame.kui.unitID, frame.kui.unitToken)
    end
end

local function isTargetNameplateFrame(frame, forceCheck)
    if (not forceCheck) and (not Questie.db.profile.nameplateObjectiveTextTargetOnly) then
        return true
    end

    local targetGUID = UnitGUID("target")
    local frameGUID = getNameplateFrameGUID(frame)
    if targetGUID and frameGUID then
        return frameGUID == targetGUID
    end

    local targetName = UnitName("target")
    local nameRegion = npFrames[frame]
    if (not targetName) or (not nameRegion) or nameRegion:GetText() ~= targetName then
        return false
    end

    local visibleTargetNameplateCount = 0
    local visibleTargetNameplate
    for nameplateFrame, nameplateNameRegion in pairs(npFrames) do
        if nameplateFrame:IsShown() and nameplateNameRegion:GetText() == targetName then
            visibleTargetNameplateCount = visibleTargetNameplateCount + 1
            visibleTargetNameplate = nameplateFrame
        end
    end

    if visibleTargetNameplateCount == 1 then
        return frame == visibleTargetNameplate
    end

    -- 3.3.5 exposes no reliable nameplate frame <-> GUID mapping here.
    -- If multiple visible nameplates share the target name, avoid showing text on all of them.
    return false
end

function QuestieCompat.NameplateCreated(frame)
    local nameRegion = npFrames[frame]
    local name = nameRegion and nameRegion:GetText()
    if not name then
        return
    end

    local key = npActiveQuestNPCs[name]
    if key then
        local objectiveInfo = _QuestieNameplate.GetValidObjectiveInfo(QuestieTooltips.lookupByKey[key])

        if objectiveInfo then
            local f = _QuestieNameplate.GetFrame(frame)
            f.Icon:SetTexture(objectiveInfo.icon)
            f.lastIcon = objectiveInfo.icon -- this is used to prevent updating the texture when it's already what it needs to be
            _QuestieNameplate.SetTargetNameplateState(f, isTargetNameplateFrame(frame, true))
            if Questie.db.profile.nameplateObjectiveTextTargetOnly and not f.isTargetNameplate then
                objectiveInfo.text = nil
            end
            _QuestieNameplate.SetObjectiveText(f, objectiveInfo.text)
            f:Show()
        end
    end
end

function QuestieCompat.UpdateNameplate()
    for frame in pairs(npFrames) do
        local nameRegion = npFrames[frame]
        local name = nameRegion and nameRegion:GetText()
        local key = npActiveQuestNPCs[name]

        local objectiveInfo = _QuestieNameplate.GetValidObjectiveInfo(QuestieTooltips.lookupByKey[key])

        if objectiveInfo then
            local f = _QuestieNameplate.GetFrame(frame)
            _QuestieNameplate.SetTargetNameplateState(f, isTargetNameplateFrame(frame, true))
            -- check if the texture needs to be changed
            if f.lastIcon ~= objectiveInfo.icon then
                f.lastIcon = objectiveInfo.icon
                f.Icon:SetTexture(objectiveInfo.icon)
            end

            if Questie.db.profile.nameplateObjectiveTextTargetOnly and not f.isTargetNameplate then
                objectiveInfo.text = nil
            end

            if f.lastText ~= objectiveInfo.text then
                _QuestieNameplate.SetObjectiveText(f, objectiveInfo.text)
            else
                _QuestieNameplate.ApplyFrameLayout(f)
            end
        else
            -- tooltip removed but we still have the frame active, remove it
            _QuestieNameplate.RemoveFrame(frame)
        end
    end
end

function QuestieCompat:QuestieTooltips_RegisterObjectiveTooltip(questId, key, objective)
    if key:find("m_") then
        local name = QuestieDB.QueryNPCSingle(tonumber(key:sub(3)), "name")
        if name then
            npActiveQuestNPCs[name] = key
        end
    end
end

local _EventHandler = QuestieEventHandler.private
function QuestieCompat.QuestieEventHandler_RegisterLateEvents()
    -- In fullscreen mode, WorldMap intercepts keyboard input,
    -- preventing the MODIFIER_STATE_CHANGED event
    if WorldMapFrame:GetScript("OnKeyDown") then
        local modifierStateChanged
        WorldMapFrame:HookScript("OnKeyDown", function(self, key)
            if IsModifierKeyDown() then
                _EventHandler:ModifierStateChanged(key, 1)
                modifierStateChanged = true
            end
        end)
        WorldMapFrame:HookScript("OnKeyUp", function(self, key)
            if modifierStateChanged then
                _EventHandler:ModifierStateChanged(key, 0)
                modifierStateChanged = nil
            end
        end)
    end

    Questie:UnregisterEvent("MAP_EXPLORATION_UPDATED") -- https://wowpedia.fandom.com/wiki/MAP_EXPLORATION_UPDATED
    Questie:UnregisterEvent("NEW_RECIPE_LEARNED")

    -- Party join event for QuestieComms, Use bucket to hinder this from spamming (Ex someone using a raid invite addon etc)
    Questie:UnregisterEvent("GROUP_ROSTER_UPDATE") -- https://wowpedia.fandom.com/wiki/GROUP_ROSTER_UPDATE
    Questie:UnregisterEvent("GROUP_JOINED") -- https://wowpedia.fandom.com/wiki/GROUP_JOINED
    Questie:UnregisterEvent("GROUP_LEFT") -- https://wowpedia.fandom.com/wiki/GROUP_LEFT
    Questie:RegisterEvent("PARTY_MEMBERS_CHANGED", QuestieCompat.GroupRosterUpdate)
    Questie:RegisterBucketEvent("RAID_ROSTER_UPDATE", 1, QuestieCompat.GroupRosterUpdate)

    -- Nameplate / Target Frame Objective Events
    Questie:UnregisterEvent("NAME_PLATE_UNIT_ADDED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_ADDED
    Questie:UnregisterEvent("NAME_PLATE_UNIT_REMOVED") -- https://wowpedia.fandom.com/wiki/NAME_PLATE_UNIT_REMOVED

    -- Use loot events as additional sync points for tracker refreshes.
    Questie:RegisterEvent("LOOT_SLOT_CLEARED", QuestieCompat.LOOT_SLOT_CLEARED)
    Questie:RegisterEvent("LOOT_CLOSED", QuestieCompat.LOOT_CLOSED)

    if Questie.db.profile.nameplateEnabled then
        QuestieNameplate.UpdateNameplate = QuestieCompat.UpdateNameplate
        hooksecurefunc(QuestieQuest, "GetAllQuestIds", QuestieCompat.UpdateNameplate)
        hooksecurefunc(QuestieTooltips, "RegisterObjectiveTooltip", QuestieCompat.QuestieTooltips_RegisterObjectiveTooltip)

        local lastNumChildren
        QuestieCompat.C_Timer.NewTicker(0.25, function()
            if not next(npActiveQuestNPCs) then
                return
            end

            local numChildren = WorldFrame:GetNumChildren()
            if numChildren ~= lastNumChildren then
                lastNumChildren = numChildren
                scanWorldFrameChildren(WorldFrame:GetChildren())
            end
        end)
    end
end

function QuestieCompat.QuestieTracker_Initialize(trackerQuestFrame)
    -- TrackerHeaderFrame.Initialize
    Questie_HeaderFrame.trackedQuests.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
    -- TrackerQuestFrame.Initialize
    trackerQuestFrame.ScrollFrame.scrollBarHideable = true
    trackerQuestFrame.ScrollBar:ClearAllPoints()
    trackerQuestFrame.ScrollBar:SetPoint("TOPRIGHT", trackerQuestFrame.ScrollUpButton, "BOTTOMRIGHT", -1, 4)
    trackerQuestFrame.ScrollBar:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollDownButton, "TOPRIGHT", -1, -4)
    trackerQuestFrame.ScrollDownButton:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollFrame, "BOTTOMRIGHT", -4, 12)
    trackerQuestFrame.ScrollBg:SetTexture(0, 0, 0, 0.35)
    trackerQuestFrame.ScrollBg:Show()
    trackerQuestFrame.ScrollBar.Show = function() end
    -- TrackerLinePool.Initialize
    for i = 1, 250 do
        local line = _G["linePool" .. i]
        line.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
        line.label.GetWrappedWidth = line.label.GetWidth
        line.label.GetNumLines = QuestieCompat.GetNumLines
    end
end

-- prevents the override of existing global variables with the same name(e.g., WorldMapButton)
function QuestieCompat.PopulateGlobals(self)
    for name, module in pairs(QuestieLoader._modules) do
        if not _G[name] then
            _G[name] = module
        end
    end
end

-- change sound files extension from .ogg to .wav
function QuestieCompat.GetSelectedSoundFile(typeSelected)
    return QuestieCompat.orig_GetSelectedSoundFile(typeSelected):gsub("[^.]+$", "wav")
end

QuestieCompat.isReloadingUi = false
function QuestieCompat.OnReloadUi(command)
	command = command or "reloadui"
	if (command == "reloadui") then
		Questie.db.profile.isInitialLogin = false
		QuestieCompat.isReloadingUi = true
	end
end

-- disable builtin quest progress tooltips, re-enable on logout
function QuestieCompat:ToggleQuestTrackingTooltips(event)
    if event:find("LOGOUT") then
        SetCVar("showQuestTrackingTooltips", "1")
    elseif Questie.db.profile.enableTooltips ~= false then
        SetCVar("showQuestTrackingTooltips", "0")
    end
end
QuestieCompat.PLAYER_LOGIN = QuestieCompat.ToggleQuestTrackingTooltips

function QuestieCompat:PLAYER_LOGOUT(event)
	QuestieCompat:ToggleQuestTrackingTooltips(event)
	if not QuestieCompat.isReloadingUi then
		Questie.db.profile.isInitialLogin = true
	end
end

local townsfolk_texturemap = {
    ["Ammo"] = "Interface\\Icons\\inv_ammo_arrow_02",
    ["Bags"] = "Interface\\Icons\\inv_misc_bag_09",
    ["Potions"] = "Interface\\Icons\\inv_potion_51",
    ["Trade Goods"] ="Interface\\Icons\\inv_fabric_wool_02",
    ["Drink"] = "Interface\\Icons\\inv_potion_01",
    ["Food"] = "Interface\\Icons\\inv_misc_food_11",
    ["Pet Food"] = "Interface\\Icons\\ability_hunter_beasttraining",
    ["Spirit Healer"] = "Interface\\Addons\\"..QuestieCompat.addonName.."\\Compat\\Icons\\Raid-Icon-Rez.blp",
    ["Portal Trainer"] = "Interface\\Addons\\"..QuestieCompat.addonName.."\\Compat\\Icons\\Vehicle-AllianceMagePortal.blp",
}

StaticPopupDialogs["QUESTIE_RELOAD"] = {
    text = "Changes you have made require a UI reload",
    button1 = 'Reload UI',
    button2 = CANCEL,
    OnAccept = function()
        ReloadUI()
    end,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function QuestieCompat.QuestieOptions_Initialize()
    QuestieCompat.orig_QuestieOptions_Initialize()

    local optionsTable = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("Questie", "dialog", "MyLib-1.0")

    -- revert instant quest text to old cvar
    optionsTable.args.general_tab.args.interface_options_group.args.instantQuest.get = function()
        return GetCVar("questFadingDisable") == '1' and true or false
    end
    optionsTable.args.general_tab.args.interface_options_group.args.instantQuest.set = function(info, value)
        QUEST_FADING_DISABLE = tostring(value and 1 or 0)
        SetCVar("questFadingDisable", tostring(value and 1 or 0))
    end

    optionsTable.args.nameplate_tab.args.nameplate_options_group.args.nameplateEnabled.set = function (info, value)
        QuestieOptions:SetProfileValue(info, value)
        StaticPopup_Show("QUESTIE_RELOAD")
    end

    -- disable settings for not implemented functionality
    Questie.db.profile.hideUnexploredMapIcons = false
    optionsTable.args.icons_tab.args.map_settings_group.args.hideUnexploredMapIconsToggle.disabled = true

    -- 3.3.5 section
    optionsTable.args.advanced_tab.args.compat_header = {
        type = "header",
        order = 6,
        name = "3.3.5 Compatibility Settings",
    }
	
	optionsTable.args.advanced_tab.args.initDelay = {
        type = "range",
        order = 6.1,
        name = "Init rate delay",
        desc = "Init rate delay",
        width = "full",
        min = 0.1,
        max = 1,
        step = 0.01,
        hidden = function() return not Questie.db.profile.debugEnabled; end,
        get = function(info) return QuestieOptions:GetProfileValue(info)*10; end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value/10)
        end,
    }

    optionsTable.args.advanced_tab.args.useQuestieLinks = {
        type = "toggle",
        order = 6.3,
        name = "Use Questie Links",
        desc = "Use Questie Links",
        width = "full",
        get = function (info) return QuestieOptions:GetProfileValue(info); end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }

    optionsTable.args.advanced_tab.args.resetDailyQuests = {
        type = "toggle",
        order = 6.4,
        name = "Reset Daily Quests",
        desc = "Reset Daily Quests",
        width = 1.65,
        get = function (info) return QuestieOptions:GetProfileValue(info); end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            Questie.db.profile.dailyResetTime = nil
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }

    optionsTable.args.advanced_tab.args.weeklyResetDay = {
        type = "select",
        order = 6.5,
        values = QuestieCompat.CALENDAR_WEEKDAY_NAMES,
        style = 'dropdown',
        disabled = function() return not Questie.db.profile.resetDailyQuests end,
        name = "Weekly Reset Day",
        desc = "Weekly Reset Day",
        width = 1.6,
        get = function (info) return QuestieOptions:GetProfileValue(info) end,
        set = function (info, value)
            QuestieOptions:SetProfileValue(info, value)
            Questie.db.profile.weeklyResetTime = nil
            StaticPopup_Show("QUESTIE_RELOAD")
        end,
    }
end

local correctionsRegistry = {}

function QuestieCompat.RegisterCorrection(dbName, corrections)
    correctionsRegistry[dbName] = correctionsRegistry[dbName] or {}
    table.insert(correctionsRegistry[dbName], corrections)
end

function QuestieCompat.LoadCorrections(_LoadCorrections, validationTables)
    for dbName in pairs(correctionsRegistry) do
        local dbKeysReversed = QuestieDB[dbName:sub(1, -5).."KeysReversed"]
        for i, corrections in ipairs(correctionsRegistry[dbName]) do
            _LoadCorrections(dbName, corrections(), dbKeysReversed, validationTables)
        end
    end
end

local blacklistRegistry = {}

function QuestieCompat.RegisterBlacklist(blName, blacklist)
    blacklistRegistry[blName] = blacklistRegistry[blName] or {}
    table.insert(blacklistRegistry[blName], blacklist)
end

function QuestieCompat.LoadBlacklists()
    for blName in pairs(blacklistRegistry) do
        for _, blacklist in ipairs(blacklistRegistry[blName]) do
            QuestieCompat.Merge(QuestieCorrections[blName], blacklist(), true)
        end
    end
end

function QuestieCompat.Merge(target, source, override)
	if type(target) ~= "table" then target = {} end
	for k,v in pairs(source) do
		if type(v) == "table" then
			target[k] = QuestieCompat.Merge(target[k], v, override)
		elseif target[k] == nil or override then
			target[k] = v
		end
	end
	return target
end

function QuestieCompat:ADDON_LOADED(event, addon)
    if addon ~= QuestieCompat.addonName then return end

    QuestieCompat.Merge(Questie.db, {
        profile = {
			isInitialLogin = true,
            initDelay = 0.01,
            resetDailyQuests = true,
            weeklyResetDay = 4,
			useQuestieLinks = false,
        },
        char = {
            daily = {},
            weekly = {},
        }
    })

    QuestieCompat.InitializeMapCompatibility()
    QuestieCompat.InitializeQuestLogCompatibility()

    for name, path in pairs(townsfolk_texturemap) do
        QuestieMenu.private.townsfolk_texturemap[name] = path
    end
	
	local DISABLED_MODULES = {
        "HBDHooks",
        "QuestieDBMIntegration"
    }
	
	if not Questie.db.profile.useQuestieLinks then
		table.insert(DISABLED_MODULES, "ChatFilter")
		table.insert(DISABLED_MODULES, "Hooks")
		table.insert(DISABLED_MODULES, "QuestieLink")
	end

    for _, moduleName in pairs(DISABLED_MODULES) do
        local module = QuestieLoader:ImportModule(moduleName)
        setmetatable(wipe(module), QuestieCompat.NOOP_MT)
    end

	QuestieLoader.PopulateGlobals = QuestieCompat.PopulateGlobals
    QuestieStream._writeByte = QuestieCompat._writeByte
    QuestieStream._readByte = QuestieCompat._readByte
    QuestieStream.Save = QuestieCompat.Save
    ZoneDB.private.RunTests = QuestieCompat.NOOP
    QuestieLib.TextWrap = QuestieCompat.TextWrap
    QuestieCoords.GetPlayerMapPosition = QuestieCompat.GetPlayerMapPosition
    QuestieCoords.ResetMiniWorldMapText = QuestieCompat.NOOP
    QuestieEventHandler.private.UiInfoMessage = QuestieCompat.UiInfoMessage
    QuestieCompat.orig_QuestieOptions_Initialize = QuestieOptions.Initialize
    QuestieOptions.Initialize = QuestieCompat.QuestieOptions_Initialize
    QuestieCompat.orig_GetSelectedSoundFile = Sounds.GetSelectedSoundFile
    Sounds.GetSelectedSoundFile = QuestieCompat.GetSelectedSoundFile
	QuestieLink.GetQuestLinkString = rawget(QuestieLink, "GetQuestLinkString") or QuestieCompat.GetQuestLinkString
	QuestieLink.GetQuestLinkStringById = rawget(QuestieLink, "GetQuestLinkStringById") or QuestieCompat.GetQuestLinkStringById
	QuestieLink.GetQuestHyperLink = rawget(QuestieLink, "GetQuestHyperLink") or QuestieCompat.GetQuestLinkStringById

    hooksecurefunc(QuestieEventHandler, "RegisterLateEvents", QuestieCompat.QuestieEventHandler_RegisterLateEvents)
    hooksecurefunc(QuestEventHandler, "RegisterEvents", QuestieCompat.QuestEventHandler_RegisterEvents)
    hooksecurefunc(TrackerLinePool, "Initialize", QuestieCompat.QuestieTracker_Initialize)
    hooksecurefunc(QuestieQuest, "ToggleNotes", QuestieCompat.HBDPins.UpdateWorldMap)
	hooksecurefunc("ReloadUI", QuestieCompat.OnReloadUi)
	hooksecurefunc("ConsoleExec", QuestieCompat.OnReloadUi)


    local Mapster = LibStub("AceAddon-3.0"):GetAddon("Mapster", true)
    if Mapster and Mapster.RefreshQuestObjectivesDisplay then
        hooksecurefunc(Mapster, "RefreshQuestObjectivesDisplay", QuestieCompat.HBDPins.UpdateWorldMap)
    end

    QuestieCompat.PatchTomTomWorldCoords()

    local MBF = LibStub("AceAddon-3.0"):GetAddon("Minimap Button Frame", true)
    if MBF and MBF.db.profile.MinimapIcons then
        table.insert(MBF.db.profile.MinimapIcons, "QuestieFrame")
        MBF:fillDropdowns()
    end
end