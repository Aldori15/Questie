---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@class QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords")
---@class Sounds
local Sounds = QuestieLoader:ImportModule("Sounds")
---@class QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
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

-- Returns the total number of group members, including the player.
-- https://wowpedia.fandom.com/wiki/API_GetNumGroupMembers
function QuestieCompat.GetNumGroupMembers()
    if QuestieCompat.IsInRaid() then
        return GetNumRaidMembers()
    elseif QuestieCompat.IsInGroup() then
        return GetNumPartyMembers() + 1
    end

    return 0
end

-- Resolves a group member name to a 3.3.5 unit token.
function QuestieCompat.GetGroupUnitByName(playerName)
    if not playerName then
        return nil
    end

    local function matchesUnit(unit)
        local name, realm = UnitName(unit)
        if not name then
            return false
        end

        local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
        return playerName == fullName or playerName == name
    end

    if matchesUnit("player") then
        return "player"
    end

    if QuestieCompat.IsInRaid() then
        for index = 1, GetNumRaidMembers() do
            local unit = "raid" .. index
            if matchesUnit(unit) then
                return unit
            end
        end
    elseif QuestieCompat.IsInGroup() then
        for index = 1, GetNumPartyMembers() do
            local unit = "party" .. index
            if matchesUnit(unit) then
                return unit
            end
        end
    end

    return nil
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
            correctionsRegistry[dbName][i] = nil
        end
        correctionsRegistry[dbName] = nil
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
        blacklistRegistry[blName] = nil
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
    QuestieCompat.RegisterStreamCompatibility()
    ZoneDB.private.RunTests = QuestieCompat.NOOP
    QuestieLib.TextWrap = QuestieCompat.TextWrap
    QuestieCoords.GetPlayerMapPosition = QuestieCompat.GetPlayerMapPosition
    QuestieCoords.ResetMiniWorldMapText = QuestieCompat.NOOP
    QuestieCompat.orig_QuestieOptions_Initialize = QuestieOptions.Initialize
    QuestieOptions.Initialize = QuestieCompat.QuestieOptions_Initialize
    QuestieCompat.orig_GetSelectedSoundFile = Sounds.GetSelectedSoundFile
    Sounds.GetSelectedSoundFile = QuestieCompat.GetSelectedSoundFile
	QuestieLink.GetQuestLinkString = rawget(QuestieLink, "GetQuestLinkString") or QuestieCompat.GetQuestLinkString
	QuestieLink.GetQuestLinkStringById = rawget(QuestieLink, "GetQuestLinkStringById") or QuestieCompat.GetQuestLinkStringById
	QuestieLink.GetQuestHyperLink = rawget(QuestieLink, "GetQuestHyperLink") or QuestieCompat.GetQuestLinkStringById

    QuestieCompat.RegisterEventCompatibilityHooks()
    QuestieCompat.RegisterTrackerCompatibilityHooks()
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