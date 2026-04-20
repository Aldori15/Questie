---@class Migration
local Migration = QuestieLoader:CreateModule("Migration")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-- add functions to this table to migrate users who have not yet run said function.
-- make sure to always add to the end of the table as it runs first to last
local migrationFunctions = {
    [1] = function()
        -- this is the big Questie v9.0 settings refactor, implementing profiles
        if Questie.db.char then -- if you actually have previous settings, then on first startup we should notify you of this
            Questie:Print("[Migration] Migrated Questie for v9.0. This will reset all Questie settings to default. Journey history has been preserved.")
        end
        -- theres no need to delete old settings, since we read/write to different addresses now;
        -- old settings can linger unused unless you roll back versions, no harm no foul
    end,
    [2] = function()
        -- Blizzard removed some sounds from Era/SoD, which are present in WotLK
        local objectiveSound = Questie.db.profile.objectiveCompleteSoundChoiceName
        if (not (Questie.IsWotlk or QuestieCompat.Is335)) and
            objectiveSound == "Explosion" or
            objectiveSound == "Shing!" or
            objectiveSound == "Wham!" or
            objectiveSound == "Simon Chime" or
            objectiveSound == "War Drums" or
            objectiveSound == "Humm" or
            objectiveSound == "Short Circuit"
        then
            Questie.db.profile.objectiveCompleteSoundChoiceName = "ObjectiveDefault"
        end

        local progressSound = Questie.db.profile.objectiveProgressSoundChoiceName
        if (not (Questie.IsWotlk or QuestieCompat.Is335)) and
            progressSound == "Explosion" or
            progressSound == "Shing!" or
            progressSound == "Wham!" or
            progressSound == "Simon Chime" or
            progressSound == "War Drums" or
            progressSound == "Humm" or
            progressSound == "Short Circuit"
        then
            Questie.db.profile.objectiveProgressSoundChoiceName = "ObjectiveProgress"
        end
    end,
    [3] = function()
        if Questie.IsSoD then
            if Questie.db.profile.showSoDRunes then
                Questie.db.profile.showRunesOfPhase = {
                    phase1 = true,
                    phase2 = false,
                    phase3 = false,
                    phase4 = false,
                }
            else
                Questie.db.profile.showRunesOfPhase = {
                    phase1 = false,
                    phase2 = false,
                    phase3 = false,
                    phase4 = false,
                }
            end
        end
    end,
    [4] = function()
        Questie.db.profile.tutorialShowRunesDone = false
    end,
    [5] = function()
        Questie.db.profile.enableTooltipsNextInChain = true
    end,
    [6] = function()
        -- Migrate users from the old default (0.03) to the new default (0.01)
        -- without overriding custom values.
        if QuestieCompat.Is335 then
            local initDelay = Questie.db.profile.initDelay
            if (initDelay == nil) or (initDelay > 0.029 and initDelay < 0.031) then
                Questie.db.profile.initDelay = 0.01
            end
        end
    end,
    [7] = function()
        local alpha = Questie.db.profile.trackerBackdropAlpha or 1
        Questie.db.profile.trackerBackdropColor = {r = 0, g = 0, b = 0, a = alpha}
        Questie.db.profile.trackerBackdropAlpha = nil
    end,
    [8] = function()
        Questie.db.profile.alwaysGlowMinimap = true
    end,
    [9] = function()
        Questie.db.profile.trackerDisableHoverFade = false
    end,
    [10] = function()
        Questie.db.global = Questie.db.global or {}
        Questie.db.global.unavailableQuestsDeterminedByTalking = Questie.db.global.unavailableQuestsDeterminedByTalking or {}
        ---@type table<string, number>
        Questie.db.global.lastKnownDailyReset = {}
    end,
    [11] = function()
        Questie.db.profile.questAnnounceIncompleteBreadcrumb = true
    end,
    [12] = function()
        Questie.db.profile.trackerWidthRatio = 0.20
    end,
    [13] = function()
        Questie.db.profile.enableTooltipDroprates = true
    end,
    [14] = function()
        local _, playerClass = UnitClass("player")
        if playerClass == "ROGUE" and Questie.db.profile.townsfolkConfig["Reagents"] then
            Questie.db.profile.townsfolkConfig["Reagents"] = false
            Questie.db.profile.townsfolkConfig["Poisons"] = true
        else
            Questie.db.profile.townsfolkConfig["Poisons"] = false
        end
    end,
    [15] = function()
        local previousVersion = Questie.db.profile.migrationVersion or 0
        if previousVersion == 0 then return end

        local previousHideInDungeons = Questie.db.profile.hideTrackerInDungeons

        Questie.db.profile.minimizeTrackerInCombat = false
        Questie.db.profile.minimizeTrackerInDungeons = previousHideInDungeons
        Questie.db.profile.hideTrackerInCombat = false
        Questie.db.profile.hideTrackerInDungeons = false
    end,
    [16] = function()
        Questie.db.profile.globalTownsfolkScale = 0.6
        Questie.db.profile.globalMiniMapTownsfolkScale = 0.7
    end,
    [17] = function()
        local autoAccept = Questie.db.profile.autoAccept
        if type(autoAccept) ~= "table" then
            autoAccept = {}
            Questie.db.profile.autoAccept = autoAccept
        end

        if Questie.db.profile.autoaccept ~= nil then
            autoAccept.enabled = Questie.db.profile.autoaccept
            Questie.db.profile.autoaccept = nil
        elseif autoAccept.enabled == nil then
            autoAccept.enabled = false
        end

        if Questie.db.profile.acceptTrivial ~= nil then
            autoAccept.trivial = Questie.db.profile.acceptTrivial
            Questie.db.profile.acceptTrivial = nil
        elseif autoAccept.trivial == nil then
            autoAccept.trivial = false
        end

        if autoAccept.repeatable == nil then
            autoAccept.repeatable = true
        end

        if autoAccept.pvp == nil then
            autoAccept.pvp = true
        end

        if Questie.db.profile.autoreject_battleground ~= nil then
            autoAccept.rejectSharedInBattleground = Questie.db.profile.autoreject_battleground
            Questie.db.profile.autoreject_battleground = nil
        elseif autoAccept.rejectSharedInBattleground == nil then
            autoAccept.rejectSharedInBattleground = false
        end
    end,
    [18] = function()
        Questie.db.profile.questObjectiveColors = true
        Questie.db.profile.questMinimapObjectiveColors = true
    end,
    [19] = function()
        Questie.db.profile.townsfolkConfig = Questie.db.profile.townsfolkConfig or {}
        Questie.db.profile.townsfolkConfig["Meeting Stones"] = false
    end,
}

function Migration:Migrate()
    if not Questie.db.profile.migrationVersion then
        Questie.db.profile.migrationVersion = 0
    end

    local currentVersion = Questie.db.profile.migrationVersion
    local targetVersion = table.getn(migrationFunctions)

    if currentVersion == targetVersion then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[Migration] Nothing to migrate. Already on latest version:", targetVersion)
        return
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[Migration] Starting Questie migration for targetVersion", targetVersion)

    while currentVersion < targetVersion do
        currentVersion = currentVersion + 1
        migrationFunctions[currentVersion]()
    end

    Questie.db.profile.migrationVersion = currentVersion
end
