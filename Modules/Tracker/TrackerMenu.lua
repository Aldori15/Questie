---@class TrackerMenu
local TrackerMenu = QuestieLoader:CreateModule("TrackerMenu")
-------------------------
--Import QuestieTracker modules.
-------------------------
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerBaseFrame
local TrackerBaseFrame = QuestieLoader:ImportModule("TrackerBaseFrame")
---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type AutoRoute
local AutoRoute = QuestieLoader:ImportModule("AutoRoute")
-------------------------
--Import Questie modules.
-------------------------
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieLink
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local GetQuestLogIndexByID = QuestieCompat.GetQuestLogIndexByID

local LibDropDown = QuestieCompat.LibUIDropDownMenu or LibStub:GetLibrary("LibUIDropDownMenuQuestie-4.0")

TrackerMenu.menuFrame = LibDropDown:Create_UIDropDownMenu("QuestieTrackerMenuFrame", UIParent)

local tinsert = table.insert

-- Create local Quest Menu functions
TrackerMenu.addFocusOption = function(menu, quest, objective)
    if Questie.db.char.TrackerFocus and type(Questie.db.char.TrackerFocus) == "string" and Questie.db.char.TrackerFocus == tostring(quest.Id) .. " " .. tostring(objective.Index) then
        tinsert(menu, {
            text = l10n('Unfocus'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                TrackerUtils:UnFocus()
                QuestieQuest:ToggleNotes(true)
            end
        })
    else
        tinsert(menu, {
            text = l10n('Focus Objective'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                TrackerUtils:FocusObjective(quest.Id, objective.Index)
                QuestieQuest:ToggleNotes(false)
            end
        })
    end
end

TrackerMenu.addTomTomOption = function(menu, quest, objective)
    tinsert(menu, {
        text = l10n('Set |cFF54e33bTomTom|r Target'),
        func = function()
            LibDropDown:CloseDropDownMenus()

            local spawn, zone, name = QuestieMap:GetNearestQuestSpawn(quest)
            local targetObjectiveIndex
            if (not spawn) and objective ~= nil then
                spawn, zone, name = QuestieMap:GetNearestSpawn(objective)
                targetObjectiveIndex = objective.Index
            end

            if spawn then
                local questId = quest and quest.Id or objective and objective.questId
                TrackerUtils:SetTomTomTarget(name, zone, spawn[1], spawn[2], questId, targetObjectiveIndex)
            elseif quest then
                TrackerUtils:SetTomTomTargetToDungeonEntrance(quest)
            end
        end
    })
end

TrackerMenu.minMaxQuestOption = function(menu, quest)
    if Questie.db.char.collapsedQuests[quest.Id] then
        tinsert(menu, {
            text = l10n('Maximize Quest'),
            func = function()
                Questie.db.char.collapsedQuests[quest.Id] = false

                QuestieCombatQueue:Queue(function()
                    QuestieTracker:Update()
                end)
            end
        })
    else
        tinsert(menu, {
            text = l10n('Minimize Quest'),
            func = function()
                Questie.db.char.collapsedQuests[quest.Id] = true

                QuestieCombatQueue:Queue(function()
                    QuestieTracker:Update()
                end)
            end
        })
    end
end

TrackerMenu.addShowHideObjectivesOption = function(menu, quest, objective)
    if objective.HideIcons then
        tinsert(menu, {
            text = l10n('Show Icons'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                objective.HideIcons = nil
                Questie.db.char.TrackerHiddenObjectives[tostring(quest.Id) .. " " .. tostring(objective.Index)] = nil
                QuestieQuest.ToggleQuestNotes(true)
            end
        })
    else
        tinsert(menu, {
            text = l10n('Hide Icons'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                objective.HideIcons = true
                Questie.db.char.TrackerHiddenObjectives[tostring(quest.Id) .. " " .. tostring(objective.Index)] = true
                QuestieQuest.ToggleQuestNotes(false)
            end
        })
    end
end

TrackerMenu.addShowHideQuestsOption = function(menu, quest)
    if quest.HideIcons then
        tinsert(menu, {
            text = l10n('Show Icons'),
            func = function()
                quest.HideIcons = nil
                Questie.db.char.TrackerHiddenQuests[quest.Id] = nil
                QuestieQuest.ToggleQuestNotes(true)
            end
        })
    else
        tinsert(menu, {
            text = l10n('Hide Icons'),
            func = function()
                quest.HideIcons = true
                Questie.db.char.TrackerHiddenQuests[quest.Id] = true
                QuestieQuest.ToggleQuestNotes(false)
            end
        })
    end
end

TrackerMenu.addShowObjectivesOnMapOption = function(menu, quest, objective)
    tinsert(menu, {
        text = l10n('Show on Map'),
        func = function()
            LibDropDown:CloseDropDownMenus()

            local needHiddenUpdate = false
            if (Questie.db.char.TrackerFocus and type(Questie.db.char.TrackerFocus) == "string" and Questie.db.char.TrackerFocus ~= tostring(quest.Id) .. " " .. tostring(objective.Index))
                or (Questie.db.char.TrackerFocus and type(Questie.db.char.TrackerFocus) == "number" and Questie.db.char.TrackerFocus ~= quest.Id) then
                TrackerUtils:UnFocus()
                needHiddenUpdate = true
            end

            if objective.HideIcons then
                objective.HideIcons = nil
                needHiddenUpdate = true
            end

            if quest.HideIcons then
                quest.HideIcons = nil
                needHiddenUpdate = true
            end

            if needHiddenUpdate then
                QuestieQuest.ToggleQuestNotes(true)
            end

            TrackerUtils:ShowObjectiveOnMap(objective)
        end
    })
end

TrackerMenu.addShowFinisherOnMapOption = function(menu, quest)
    if quest:IsComplete() == 1 then
        tinsert(menu, {
            text = l10n('Show on Map'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                TrackerUtils:ShowFinisherOnMap(quest)
            end
        })
    end
end

TrackerMenu.addObjectiveOption = function(menu, subMenu, quest)
    if quest:IsComplete() == 0 then
        tinsert(menu, { text = l10n('Objectives'), hasArrow = true, menuList = subMenu })
    end
end

TrackerMenu.addLinkToChatOption = function(menu, quest)
    tinsert(menu, {
        text = l10n('Link Quest to chat'),
        func = function()
            LibDropDown:CloseDropDownMenus()

            if (not ChatFrame1EditBox:IsVisible()) then
                ChatFrame_OpenChat(QuestieLink:GetQuestInsertStringById(quest.Id))
            else
                ChatEdit_InsertLink(QuestieLink:GetQuestInsertStringById(quest.Id))
            end
        end
    })
end

TrackerMenu.addShowInQuestLogOption = function(menu, quest)
    tinsert(menu, {
        text = l10n('Show in Quest Log'),
        func = function()
            LibDropDown:CloseDropDownMenus()
            TrackerUtils:ShowQuestLog(quest)
        end
    })
end

TrackerMenu.addAbandonedQuest = function(menu, quest)
    tinsert(menu, {
        text = l10n('Abandon Quest'),
        func = function()
            LibDropDown:CloseDropDownMenus()
            local lastQuest = GetQuestLogSelection()
            local questLogIndex = GetQuestLogIndexByID(quest.Id)
            if (not questLogIndex) then
                Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerMenu:addAbandonedQuest] Missing quest log index for tracked quest:", quest.Id)
                QuestieTracker:UntrackQuestId(quest.Id)
                return
            end
            SelectQuestLogEntry(questLogIndex)
            SetAbandonQuest()

            local items = GetAbandonQuestItems()
            if items then
                StaticPopup_Hide("ABANDON_QUEST")
                StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), items)
            else
                StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
                StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
            end

            SelectQuestLogEntry(lastQuest)
            local questLogFrame = QuestLogExFrame or ClassicQuestLog or QuestLogFrame

            if questLogFrame:IsShown() then
                QuestLog_Update()
            end
        end
    })
end

TrackerMenu.addUntrackOption = function(menu, quest)
    tinsert(menu, {
        text = l10n('Untrack Quest'),
        func = function()
            LibDropDown:CloseDropDownMenus()
            QuestieTracker:UntrackQuestId(quest.Id)
            local questLogFrame = QuestLogExFrame or ClassicQuestLog or QuestLogFrame

            if questLogFrame:IsShown() then
                QuestLog_Update()
            end
        end
    })
end

TrackerMenu.addRouteOption = function(menu, quest)
    local position = AutoRoute.GetRoutePosition(quest.Id)
    if not position then
        tinsert(menu, {
            text = l10n("Add to |cFF54e33bTomTom|r Route"),
            func = function()
                LibDropDown:CloseDropDownMenus()
                AutoRoute.AddToRoute(quest.Id)
            end,
        })
        return
    end

    local routeMenu = {
        {
            text = l10n("Move Up"),
            disabled = position == 1,
            func = function()
                LibDropDown:CloseDropDownMenus()
                AutoRoute.MoveInRoute(quest.Id, -1)
            end,
        },
        {
            text = l10n("Move Down"),
            disabled = position == #(Questie.db.char.autoRouteOrder or {}),
            func = function()
                LibDropDown:CloseDropDownMenus()
                AutoRoute.MoveInRoute(quest.Id, 1)
            end,
        },
        {
            text = l10n("Remove from Route"),
            func = function()
                LibDropDown:CloseDropDownMenus()
                AutoRoute.RemoveFromRoute(quest.Id)
            end,
        },
        {
            text = l10n("Clear Route"),
            func = function()
                LibDropDown:CloseDropDownMenus()
                AutoRoute.ClearRoute()
            end,
        },
    }
    tinsert(menu, {
        text = l10n("|cFF54e33bTomTom|r Route") .. " |cFFAAAAAA(#" .. position .. ")|r",
        hasArrow = true,
        menuList = routeMenu,
    })
end

TrackerMenu.addFocusUnfocusOption = function(menu, quest)
    if Questie.db.char.TrackerFocus and type(Questie.db.char.TrackerFocus) == "number" and Questie.db.char.TrackerFocus == quest.Id then
        tinsert(menu, {
            text = l10n('Unfocus'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                TrackerUtils:UnFocus()
                QuestieQuest:ToggleNotes(true)
            end
        })
    else
        tinsert(menu, {
            text = l10n('Focus Quest'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                TrackerUtils:FocusQuest(quest.Id)
                QuestieQuest:ToggleNotes(false)
            end
        })
    end
end

TrackerMenu.addLockUnlockOption = function(menu)
    if Questie.db.profile.trackerLocked then
        tinsert(menu, {
            text = l10n('Unlock Tracker'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                Questie.db.profile.trackerLocked = false
                TrackerBaseFrame:Update()
            end
        })
    else
        tinsert(menu, {
            text = l10n('Lock Tracker'),
            func = function()
                LibDropDown:CloseDropDownMenus()
                Questie.db.profile.trackerLocked = true
                TrackerBaseFrame:Update()
            end
        })
    end
end

local wowheadDialog

local function CreateWowheadDialog()
    local popup = CreateFrame("Frame", "QuestieWowheadURLDialog", UIParent)
    popup:Hide()
    popup:SetPoint("TOP", UIParent, "TOP", 0, -135)
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11},
    })
    tinsert(UISpecialFrames, "QuestieWowheadURLDialog")

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -20)
    title:SetText("WoWHead URL")
    popup.label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.label:SetPoint("TOP", title, "BOTTOM", 0, -14)

    local editBox = CreateFrame("EditBox", nil, popup)
    popup.editBox = editBox
    editBox:SetPoint("TOP", popup.label, "BOTTOM", 0, -16)
    editBox:SetHeight(32)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetTextInsets(10, 10, 0, 0)
    -- A tiled backdrop scales with the field, unlike 3.3.5's two fixed StaticPopup caps.
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    editBox:SetBackdropColor(0, 0, 0, 1)
    popup.measure = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.measure:Hide()

    local close = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    close:SetSize(120, 24)
    close:SetPoint("BOTTOM", 0, 18)
    close:SetText(CLOSE)
    close:SetScript("OnClick", function() popup:Hide() end)
    editBox:SetScript("OnEnterPressed", function() popup:Hide() end)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
    -- Let the focused native edit box handle Ctrl+C. Dismiss manually on 3.3.5.
    popup:SetScript("OnHide", function()
        editBox:ClearFocus()
    end)
    return popup
end

local function ShowWowheadURL(kind, id, name)
    if not wowheadDialog then wowheadDialog = CreateWowheadDialog() end
    local popup = wowheadDialog
    popup:Hide()
    local lang = string.sub(l10n:GetUILocale(), 1, 2)
    local link = "https://wowhead.com/wotlk/" .. (lang == "en" and "" or lang .. "/") .. kind .. "=" .. id
    popup.measure:SetText(link)
    local width = math.max(360, math.ceil(popup.measure:GetStringWidth()) + 72)
    popup:SetWidth(width)
    popup.label:SetWidth(width - 48)
    popup.label:SetText(name)
    popup:SetHeight(148 + popup.label:GetStringHeight())
    popup.editBox:SetWidth(width - 48)
    popup.editBox:SetText(link)
    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:SetCursorPosition(0)
    popup.editBox:HighlightText()
end

-- Create Quest Menu
function TrackerMenu:GetMenuForQuest(quest)
    local menu = {}
    local subMenu = {}

    for _, objective in pairs(quest.Objectives) do
        local objectiveMenu = {}

        TrackerMenu.addFocusOption(objectiveMenu, quest, objective)
        TrackerMenu.addTomTomOption(objectiveMenu, nil, objective)
        TrackerMenu.addShowHideObjectivesOption(objectiveMenu, quest, objective)
        TrackerMenu.addShowObjectivesOnMapOption(objectiveMenu, quest, objective)

        tinsert(subMenu, { text = objective.Description, hasArrow = true, menuList = objectiveMenu })
    end

    if next(quest.SpecialObjectives) then
        for _, objective in pairs(quest.SpecialObjectives) do
            local objectiveMenu = {}

            TrackerMenu.addFocusOption(objectiveMenu, quest, objective)
            TrackerMenu.addTomTomOption(objectiveMenu, nil, objective)
            TrackerMenu.addShowHideObjectivesOption(objectiveMenu, quest, objective)
            TrackerMenu.addShowObjectivesOnMapOption(objectiveMenu, quest, objective)

            tinsert(subMenu, { text = objective.Description, hasArrow = true, menuList = objectiveMenu })
        end
    end

    local coloredQuestName = QuestieLib:GetColoredQuestName(quest.Id, Questie.db.profile.enableTooltipsQuestLevel, true, true)

    tinsert(menu, { text = coloredQuestName, isTitle = true })

    TrackerMenu.addObjectiveOption(menu, subMenu, quest)
    TrackerMenu.addFocusUnfocusOption(menu, quest)
    TrackerMenu.addTomTomOption(menu, quest, nil)
    if IsAddOnLoaded("TomTom") then
        TrackerMenu.addRouteOption(menu, quest)
    end
    TrackerMenu.minMaxQuestOption(menu, quest)
    TrackerMenu.addShowHideQuestsOption(menu, quest)
    TrackerMenu.addShowFinisherOnMapOption(menu, quest)
    TrackerMenu.addShowInQuestLogOption(menu, quest)
    TrackerMenu.addLinkToChatOption(menu, quest)
    TrackerMenu.addUntrackOption(menu, quest)
    TrackerMenu.addAbandonedQuest(menu, quest)

    tinsert(menu, {
        text = "|cFF39c0edWoWHead URL|r",
        func = function()
            ShowWowheadURL("quest", quest.Id, QuestieDB.GetQuest(quest.Id).name)
        end
    })

    TrackerMenu.addLockUnlockOption(menu)

    tinsert(menu, {
        text = l10n('Cancel'),
        func = function()
        end
    })

    return menu
end

-- Create local Achievement Menu functions
TrackerMenu.addAchieveLinkToChatOption = function(menu, achieve)
    tinsert(menu, {
        text = l10n('Link Achievement to chat'),
        func = function()
            LibDropDown:CloseDropDownMenus()

            if (not ChatFrame1EditBox:IsVisible()) then
                ChatFrame_OpenChat(GetAchievementLink(achieve.Id))
            else
                ChatEdit_InsertLink(GetAchievementLink(achieve.Id))
            end
        end
    })
end

TrackerMenu.addShowInAchievementsOption = function(menu, achieve)
    tinsert(menu, {
        text = l10n('Show in Achievements Log'),
        func = function()
            LibDropDown:CloseDropDownMenus()

            if (not AchievementFrame) then
                AchievementFrame_LoadUI()
            end

            if (not AchievementFrame:IsShown()) then
                AchievementFrame_ToggleAchievementFrame()
                AchievementFrame_SelectAchievement(achieve.Id)
            else
                if (AchievementFrameAchievements.selection ~= achieve.Id) then
                    AchievementFrame_SelectAchievement(achieve.Id)
                end
            end
        end
    })
end

TrackerMenu.addUntrackAchieveOption = function(menu, achieve)
    tinsert(menu, {
        text = l10n('Untrack Achievement'),
        func = function()
            LibDropDown:CloseDropDownMenus()
            QuestieTracker:UntrackAchieveId(achieve.Id)
            QuestieTracker:UpdateAchieveTrackerCache(achieve.Id)

            if (not AchievementFrame) then
                AchievementFrame_LoadUI()
            end

            AchievementFrameAchievements_ForceUpdate()

            QuestieCombatQueue:Queue(function()
                QuestieTracker:Update()
            end)
        end
    })
end

-- Create Achievement Menu
function TrackerMenu:GetMenuForAchievement(achieve)
    local menu = {}
    tinsert(menu, { text = "|cFFFFFF00" .. select(2, GetAchievementInfo(achieve.Id)) .. "|r", isTitle = true })

    TrackerMenu.addAchieveLinkToChatOption(menu, achieve)
    TrackerMenu.addShowInAchievementsOption(menu, achieve)

    for trackedId, _ in pairs(Questie.db.char.trackedAchievementIds) do
        if trackedId == achieve.Id then
            TrackerMenu.addUntrackAchieveOption(menu, achieve)
        end
    end

    tinsert(menu, {
        text = "|cFF39c0edWoWHead URL|r",
        func = function()
            ShowWowheadURL("achievement", achieve.Id, select(2, GetAchievementInfo(achieve.Id)))
        end
    })

    TrackerMenu.addLockUnlockOption(menu)

    tinsert(menu, {
        text = l10n('Cancel'),
        func = function()
        end
    })

    return menu
end
