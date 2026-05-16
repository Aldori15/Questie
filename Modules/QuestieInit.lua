---@class QuestieInit
local QuestieInit = QuestieLoader:CreateModule("QuestieInit")
local _QuestieInit = QuestieInit.private

---@type ThreadLib
local ThreadLib = QuestieLoader:ImportModule("ThreadLib")

---@type QuestEventHandler
local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type Migration
local Migration = QuestieLoader:ImportModule("Migration")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type InstanceLocations
local InstanceLocations = QuestieLoader:ImportModule("InstanceLocations")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type Cleanup
local QuestieCleanup = QuestieLoader:ImportModule("Cleanup")
---@type DBCompiler
local QuestieDBCompiler = QuestieLoader:ImportModule("DBCompiler")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type IsleOfQuelDanas
local IsleOfQuelDanas = QuestieLoader:ImportModule("IsleOfQuelDanas")
---@type DailyQuests
local DailyQuests = QuestieLoader:ImportModule("DailyQuests")
---@type QuestieEventHandler
local QuestieEventHandler = QuestieLoader:ImportModule("QuestieEventHandler")
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
---@type HBDHooks
local HBDHooks = QuestieLoader:ImportModule("HBDHooks")
---@type ChatFilter
local ChatFilter = QuestieLoader:ImportModule("ChatFilter")
---@type QuestieShutUp
local QuestieShutUp = QuestieLoader:ImportModule("QuestieShutUp")
---@type Hooks
local Hooks = QuestieLoader:ImportModule("Hooks")
---@type QuestieValidateGameCache
local QuestieValidateGameCache = QuestieLoader:ImportModule("QuestieValidateGameCache")
---@type MinimapIcon
local MinimapIcon = QuestieLoader:ImportModule("MinimapIcon")
---@type QuestieComms
local QuestieComms = QuestieLoader:ImportModule("QuestieComms");
---@type Comms
local Comms = QuestieLoader:ImportModule("Comms")
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions");
---@type QuestieCoords
local QuestieCoords = QuestieLoader:ImportModule("QuestieCoords");
---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips");
---@type QuestieDBMIntegration
local QuestieDBMIntegration = QuestieLoader:ImportModule("QuestieDBMIntegration");
---@type TrackerQuestTimers
local TrackerQuestTimers = QuestieLoader:ImportModule("TrackerQuestTimers")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type QuestieSlash
local QuestieSlash = QuestieLoader:ImportModule("QuestieSlash")
---@type QuestXP
local QuestXP = QuestieLoader:ImportModule("QuestXP")
---@type Tutorial
local Tutorial = QuestieLoader:ImportModule("Tutorial")
---@type WorldMapButton
local WorldMapButton = QuestieLoader:ImportModule("WorldMapButton")
---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
---@type QuestieAnnounce
local QuestieAnnounce = QuestieLoader:ImportModule("QuestieAnnounce")
---@type DropDB
local DropDB = QuestieLoader:ImportModule("DropDB")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")

--- COMPATIBILITY ---
local WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_ID
local C_Timer = QuestieCompat.C_Timer

local coYield = coroutine.yield

local function loadFullDatabase()
    print("\124cFF4DDBFF [1/9] " .. l10n("Loading database") .. "...")

    QuestieInit:LoadBaseDB()

    print("\124cFF4DDBFF [2/9] " .. l10n("Applying database corrections") .. "...")

    coYield()
    QuestieCorrections:Initialize()

    print("\124cFF4DDBFF [3/9] " .. l10n("Initializing townfolks") .. "...")
    coYield()
    Townsfolk.Initialize()

    print("\124cFF4DDBFF [4/9] " .. l10n("Initializing locale") .. "...")
    coYield()
    l10n:Initialize()

    coYield()
    QuestieDB.private:DeleteGatheringNodes()

    print("\124cFF4DDBFF [5/9] " .. l10n("Optimizing waypoints") .. "...")
    coYield()
    QuestieCorrections:PreCompile()
end

---Run the validator
local function runValidator()
    if type(QuestieDB.questData) == "string" or type(QuestieDB.npcData) == "string" or type(QuestieDB.objectData) == "string" or type(QuestieDB.itemData) == "string" then
        Questie:Error("Cannot run the validator on string data, load database first")
        return
    end
    -- Run validator
    if Questie.db.profile.debugEnabled then
        coYield()
        print("Validating NPCs...")
        QuestieDBCompiler:ValidateNPCs()
        coYield()
        print("Validating objects...")
        QuestieDBCompiler:ValidateObjects()
        coYield()
        print("Validating items...")
        QuestieDBCompiler:ValidateItems()
        coYield()
        print("Validating quests...")
        QuestieDBCompiler:ValidateQuests()
    end
end

-- ********************************************************************************
-- Start of QuestieInit.Stages ******************************************************

-- stage worker functions. Most are coroutines.
QuestieInit.Stages = {}

QuestieInit.Stages[1] = function() -- run as a coroutine
    Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieInit:Stage1] Starting the real init.")

    --? This was moved here because the lag that it creates is much less noticable here, while still initalizing correctly.
    Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieInit:Stage1] Starting QuestieOptions.Initialize Thread.")
    ThreadLib.ThreadSimple(QuestieOptions.Initialize, 0)

    MinimapIcon:Init()

    HBDHooks:Init()

    Questie:SetIcons()

    if QUESTIE_LOCALES_OVERRIDE ~= nil then
        l10n:InitializeLocaleOverride()
    end

    -- Set proper locale. Either default to client Locale or override based on user.
    if Questie.db.global.questieLocaleDiff then
        l10n:SetUILocale(Questie.db.global.questieLocale);
    else
        if QUESTIE_LOCALES_OVERRIDE ~= nil then
            l10n:SetUILocale(QUESTIE_LOCALES_OVERRIDE.locale);
        else
            l10n:SetUILocale(GetLocale());
        end
    end

    QuestieShutUp:ToggleFilters(Questie.db.profile.questieShutUp)

    coYield()
    ZoneDB:Initialize()

    coYield()
    Migration:Migrate()

    IsleOfQuelDanas.Initialize() -- This has to happen before option init

    QuestieProfessions:Init()
    l10n:CompactTranslations()
    QuestXP.Init()
    coYield()

    local dbCompiled = false

    local dbIsCompiled, dbCompiledOnVersion, dbCompiledLang, dbCompiledSchemaVersion

    dbIsCompiled = Questie.db.global.dbIsCompiled or false
    dbCompiledOnVersion = Questie.db.global.dbCompiledOnVersion
    dbCompiledLang = Questie.db.global.dbCompiledLang
    dbCompiledSchemaVersion = Questie.db.global.dbCompiledSchemaVersion

    -- Check if the DB needs to be recompiled
    if (not dbIsCompiled) or (QuestieLib:GetAddonVersionString() ~= dbCompiledOnVersion) or (l10n:GetUILocale() ~= dbCompiledLang) or (dbCompiledSchemaVersion ~= QuestieDBCompiler.compiledSchemaVersion) or (Questie.db.global.dbCompiledExpansion ~= WOW_PROJECT_ID) then
        print("\124cFFAAEEFF" .. l10n("Questie DB has updated!") .. "\124r\124cFFFF6F22 " .. l10n("Data is being processed, this may take a few moments and cause some lag..."))
        loadFullDatabase()
        QuestieDBCompiler:Compile()
        dbCompiled = true
    else
        l10n:Initialize()
        coYield()
        QuestieCorrections:MinimalInit()
    end

    -- The remaining init path no longer needs the source lookup blobs after database setup.
    QuestieCleanup:ClearLocalization()
    collectgarbage()

    local dbCompiledCount = Questie.db.global.dbCompiledCount

    if (not Questie.db.char.townsfolk) or (dbCompiledCount ~= Questie.db.char.townsfolkVersion) or (Questie.db.char.townsfolkClass ~= UnitClass("player")) then
        Questie.db.char.townsfolkVersion = dbCompiledCount
        coYield()
        Townsfolk:BuildCharacterTownsfolk()
    end

    coYield()
    QuestieDB:Initialize()

    coYield()
    Tutorial.Initialize()

    --? Only run the validator on recompile if debug is enabled, otherwise it's a waste of time.
    if Questie.db.profile.debugEnabled and dbCompiled then
        if Questie.db.profile.skipValidation ~= true then
            runValidator()
            print("\124cFF4DDBFF Load and Validation complete.")
        else
            print("\124cFF4DDBFF Validation skipped, load complete.")
        end
    end

    QuestieCleanup:Run()
end

QuestieInit.Stages[2] = function()
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieInit:Stage2] Stage 2 start.")
    QuestiePlayer:Initialize()
    coYield()
    QuestieJourney:Initialize()

    local keepWaiting = true
    -- We had users reporting that a quest did not reach a valid state in the game cache.
    -- In this case we still need to continue the initialization process, even though a specific quest might be bugged
    C_Timer.After(3, function()
        if keepWaiting then
            Questie:Debug(Questie.DEBUG_CRITICAL, "QuestieInit: Timeout waiting for Game Cache validation. Continuing.")
            keepWaiting = false
        end
    end)

    -- Continue to the next Init Stage once Game Cache's Questlog is good
    while (not QuestieValidateGameCache:IsCacheGood()) and keepWaiting do
        coYield()
    end
    keepWaiting = false
end

QuestieInit.Stages[3] = function() -- run as a coroutine
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieInit:Stage3] Stage 3 start.")

    -- register events that rely on questie being initialized
    QuestieEventHandler:RegisterLateEvents()

    -- ** OLD ** Questie:ContinueInit() ** START **
    QuestieTooltips:Initialize()
    DropDB:Initialize()
    QuestieCoords:Initialize()
    TrackerQuestTimers:Initialize()
    Comms.Initialize()
    QuestieComms:Initialize()

    QuestieSlash.RegisterSlashCommands()

    QuestieAnnounce:InitializeLogoFilter()

    coYield()

    if Questie.db.profile.dbmHUDEnable then
        QuestieDBMIntegration:EnableHUD()
    end
    -- ** OLD ** Questie:ContinueInit() ** END **

    QuestieMap:InitializeQueue()

    coYield()
    QuestieQuest:Initialize()
    coYield()
    WorldMapButton.Initialize()
    coYield()
    InstanceLocations.Initialize()
    coYield()
    -- Seed the quest log baseline before live quest events are registered.
    local cacheMiss, changes = QuestLogCache.CheckForChanges(nil)
    if cacheMiss then
        Questie:Debug(Questie.DEBUG_CRITICAL, "QuestieInit: Game Cache did not fill in time, waiting for valid cache.")
        changes = QuestieInit.WaitForValidGameCache()
    end
    QuestEventHandler.InitQuestLogStates(changes)
    coYield()
    QuestEventHandler:RegisterEvents()
    ChatFilter:RegisterEvents()
    coYield()
    QuestieQuest:GetAllQuestIdsNoObjectives()
    coYield()
    QuestieQuest:GetAllQuestIds()

    -- Initialize the tracker
    coYield()
    QuestieTracker.Initialize()
    Hooks:HookQuestLogTitle()
    QuestieCombatQueue.Initialize()

    local dateToday = date("%y-%m-%d")

    if Questie.db.profile.showAQWarEffortQuests and ((not Questie.db.profile.aqWarningPrintDate) or (Questie.db.profile.aqWarningPrintDate < dateToday)) then
        Questie.db.profile.aqWarningPrintDate = dateToday
        C_Timer.After(2, function()
            print("|cffff0000-----------------------------|r")
            Questie:Print("|cffff0000The AQ War Effort quests are shown for you. If your server is done you can hide those quests in the General settings of Questie!|r");
            print("|cffff0000-----------------------------|r")
        end)
    end

    if Questie.db.profile.showScourgeInvasionQuests and ((not Questie.db.profile.scourgeInvasionWarningPrintDate) or (Questie.db.profile.scourgeInvasionWarningPrintDate < dateToday)) then
        Questie.db.profile.scourgeInvasionWarningPrintDate = dateToday
        C_Timer.After(2, function()
            print("|cffff0000-----------------------------|r")
            Questie:Print("|cffff0000The Scourge Invasion quests are shown for you. If the worldstate event is not active on your server, you can hide those quests in the Icon settings of Questie!|r");
            print("|cffff0000-----------------------------|r")
        end)
    end

    if QuestieCompat.Is335 and Questie.db.profile.showSunsReachQuests and (not Questie.db.profile.isIsleOfQuelDanasPhaseReminderDisabled) then
        C_Timer.After(2, function()
            Questie:Print(l10n("Current active phase of Isle of Quel'Danas is '%s'. Check the Advanced settings to change the phase or disable this message.", IsleOfQuelDanas.localizedPhaseNames[Questie.db.profile.isleOfQuelDanasPhase]))
        end)
    end

    coYield()
    QuestieMenu:OnLogin()

    coYield()
    DailyQuests.Initialize()

    coYield()
    if Questie.db.profile.debugEnabled then
        QuestieLoader:PopulateGlobals()
    end

    Questie.started = true

    if Questie.db.profile.showEventQuests then
        QuestieEvent.Initialize()
    end

    if QuestieCompat.Is335 then
        -- 3.3.5 can miss the emulated group join sync on login/reload while already in a party.
        -- Request a fresh quest log sync only after Questie is fully initialized.
        local syncTicker
        local attempts = 0
        syncTicker = C_Timer.NewTicker(0.5, function()
            attempts = attempts + 1

            local currentMembers = 0
            if QuestieCompat.IsInRaid() then
                currentMembers = GetNumRaidMembers()
            elseif QuestieCompat.IsInGroup() then
                currentMembers = GetNumPartyMembers()
            end

            if currentMembers > 0 then
                QuestiePlayer.numberOfGroupMembers = currentMembers
                Questie:SendMessage("QC_ID_REQUEST_FULL_QUESTLIST")
                syncTicker:Cancel()
            elseif attempts >= 10 then
                syncTicker:Cancel()
            end
        end)
    end

    -- We only update this if Questie fully loads to make sure we don't update it on crashes/fast reloads
    QuestieLib.UpdateLastKnownDailyReset()

    if (Questie.IsWotlk or Questie.IsTBC) and QuestiePlayer.IsMaxLevel() then
        local lastRequestWasYesterday = Questie.db.global.lastDailyRequestDate ~= date("%d-%m-%y"); -- Yesterday or some day before
        local isPastDailyReset = Questie.db.global.lastDailyRequestResetTime < GetQuestResetTime();

        if lastRequestWasYesterday or isPastDailyReset then
            Questie.db.global.lastDailyRequestDate = date("%d-%m-%y");
            Questie.db.global.lastDailyRequestResetTime = GetQuestResetTime();
        end
    end

    -- We do this last because it will run for a while and we don't want to block the rest of the init
    coYield()
    AvailableQuests.CalculateAndDrawAll()

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieInit:Stage3] Questie init done.")
end

-- End of QuestieInit.Stages ******************************************************
-- ********************************************************************************



--- We really want to wait for the cache to be filled before we continue.
--- Other addons can interfere with the cache and we need to make sure it's correct.
---@return table<number, boolean>|nil
function QuestieInit.WaitForValidGameCache()
    local doWait = true
    local retries = 0
    local changes

    local timer
    timer = C_Timer.NewTicker(1, function()
        local cacheMiss, newChanges = QuestLogCache.CheckForChanges(nil)
        if (not cacheMiss) or retries >= 3 then
            if retries == 3 then
                Questie:Debug(Questie.DEBUG_CRITICAL, "QuestieInit: Game Cache did not become valid in 3 seconds, continuing with initialization.")
            end
            doWait = false
            timer:Cancel()
        end
        changes = newChanges
        retries = retries + 1
    end)

    while doWait do
        coYield()
    end

    return changes
end

function QuestieInit:LoadDatabase(key)
    if QuestieDB[key] then
        coYield()
        local func, err = loadstring(QuestieDB[key]) -- load the table from string (returns a function)
        if (not func) then
            Questie:Error("Failed to load database: ", key, err)
            return
        end
        QuestieDB[key] = func
        coYield()
        QuestieDB[key] = QuestieDB[key]()           -- execute the function (returns the table)
    else
        Questie:Debug(Questie.DEBUG_DEVELOP, "Database is missing, this is likely do to era vs tbc: ", key)
    end
end

function QuestieInit:LoadBaseDB()
    QuestieInit:LoadDatabase("npcData")
    QuestieInit:LoadDatabase("objectData")
    QuestieInit:LoadDatabase("questData")
    QuestieInit:LoadDatabase("itemData")
end

function _QuestieInit.StartStageCoroutine()
    for i = 1, #QuestieInit.Stages do
        QuestieInit.Stages[i]()
        Questie:Debug(Questie.DEBUG_INFO, "[QuestieInit:StartStageCoroutine] Stage " .. i .. " done.")
    end
end

-- called by the PLAYER_LOGIN event handler
function QuestieInit:Init()
    ThreadLib.ThreadError(_QuestieInit.StartStageCoroutine, Questie.db.profile.initDelay or 0, l10n("Error during initialization!"))

    if Questie.db.profile.trackerEnabled then
        -- This needs to be called ASAP otherwise tracked Achievements in the Blizzard WatchFrame shows upon login
        local WatchFrame = QuestTimerFrame or WatchFrame

        if Questie.IsWotlk or QuestieCompat.Is335 then
            -- Classic WotLK
            WatchFrame:Hide()
        else
            -- Classic WoW: This moves the QuestTimerFrame off screen. A faux Hide().
            -- Otherwise, if the frame is hidden then the OnUpdate doesn't work.
            WatchFrame:ClearAllPoints()
            WatchFrame:SetPoint("TOP", "UIParent", -10000, -10000)
        end
        if not (Questie.IsWotlk or QuestieCompat.Is335) then
            -- Need to hook this ASAP otherwise the scroll bars show up
            hooksecurefunc("ScrollFrame_OnScrollRangeChanged", function()
                if TrackedQuestsScrollFrame then
                    TrackedQuestsScrollFrame.ScrollBar:Hide()
                end

                if QuestieProfilerScrollFrame then
                    QuestieProfilerScrollFrame.ScrollBar:Hide()
                end
            end)
        end
    end
end
