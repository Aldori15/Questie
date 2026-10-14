---@class TrackerQuestItemButtons
local TrackerQuestItemButtons = QuestieLoader:CreateModule("TrackerQuestItemButtons")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerBaseFrame
local TrackerBaseFrame = QuestieLoader:ImportModule("TrackerBaseFrame")
---@type TrackerFadeTicker
local TrackerFadeTicker = QuestieLoader:ImportModule("TrackerFadeTicker")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local C_Timer = QuestieCompat.C_Timer
local C_QuestLog = QuestieCompat.C_QuestLog
local LSM30 = LibStub("LibSharedMedia-3.0")

local buttonPoolSize = 25
local buttonIndex = 0
local buttonPool = {}
local ITEM_BUTTON_UPDATE_INTERVAL = 0.1
local ITEM_BUTTON_CHARGE_UPDATE_INTERVAL = 0.2
local ITEM_BUTTON_RANGE_UPDATE_INTERVAL = 0.3

-- Called after the tracker line frames are initialized, outside combat.
function TrackerQuestItemButtons.Initialize()
    -- create buttonPool for quest items
    for i = 1, C_QuestLog.GetMaxNumQuestsCanAccept() do
        local buttonName = "Questie_ItemButton" .. i
        local btn = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate")
        local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.range = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        btn.count = btn:CreateFontString(nil, "ARTWORK", "SystemFont_Outline_Small")
        btn:Hide()

        if Questie.db.profile.trackerFadeQuestItemButtons then
            btn:SetAlpha(0)
        end

        btn.SetItem = function(self, questItemId, questId, size, isNativeQuestItem)
            local validTexture
            self.itemId = nil
            self.itemName = nil

            for bag = -2, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local texture, _, _, _, _, _, _, _, _, itemId = QuestieCompat.GetContainerItemInfo(bag, slot)
                    if questItemId == itemId and (isNativeQuestItem or QuestieDB.QueryItemSingle(itemId, "class") == 12) then
                        validTexture = texture
                        self.itemId = questItemId
                        break
                    end
                end
            end

            -- Edge case to find "equipped" quest items since they will no longer be in the players bag
            if (not validTexture) then
                for inventorySlot = 1, 19 do
                    local itemId = GetInventoryItemID("player", inventorySlot)
                    if questItemId == itemId and (isNativeQuestItem or QuestieDB.QueryItemSingle(itemId, "class") == 12) then
                        validTexture = GetInventoryItemTexture("player", inventorySlot)
                        self.itemId = questItemId
                        break
                    end
                end
            end

            if validTexture and self.itemId then
                self.questID = questId
                self.charges = GetItemCount(self.itemId, nil, true)
                self.rangeTimer = -1

                self:SetNormalTexture(validTexture)
                self:SetPushedTexture(validTexture)
                self:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
                self:SetSize(size, size)

                self:RegisterForClicks("anyUp")

                self:SetScript("OnEvent", self.OnEvent)
                self:SetScript("OnShow", self.OnShow)
                self:SetScript("OnHide", self.OnHide)
                self:SetScript("OnEnter", self.OnEnter)
                self:SetScript("OnLeave", self.OnLeave)

                self:SetAttribute("type1", "item")
                self:SetAttribute("item1", "item:" .. self.itemId)
                self:Show()

                -- Cooldown Updates
                cooldown:SetSize(size - 4, size - 4)
                cooldown:SetPoint("CENTER", self, "CENTER", 0, 0)
                cooldown:Hide()

                -- Range Updates
                self.range:SetText("●")
                self.range:SetPoint("TOPRIGHT", self, "TOPRIGHT", 3, 0)
                self.range:Hide()

                -- Charges Updates
                self.count:Hide()
                self.count:SetFont(LSM30:Fetch("font", Questie.db.profile.trackerFontQuest), Questie.db.profile.trackerFontSizeQuest, "OUTLINE")
                if self.charges > 1 then
                    self.count:SetText(self.charges)
                    self.count:Show()
                end
                self.count:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 3)

                return true
            else
                self.questID = nil
                self:SetAttribute("item1", nil)
                self:Hide()
            end

            return false
        end

        btn.OnEvent = function(self, event, ...)
            if (event == "PLAYER_TARGET_CHANGED") then
                self.rangeTimer = -1
                self.range:Hide()
            elseif event == "BAG_UPDATE_COOLDOWN" then
                self.cooldownTimer = 0
            elseif event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
                self.cooldownTimer = 0
                self.chargeTimer = 0
            end
        end

        btn.RefreshCooldown = function(self)
            local start, duration, enabled = GetItemCooldown(self.itemId)

            if enabled == 1 and duration > 0 then
                if self.cooldownStart ~= start or self.cooldownDuration ~= duration or self.cooldownEnabled ~= enabled then
                    cooldown:SetCooldown(start, duration, enabled)
                    self.cooldownStart = start
                    self.cooldownDuration = duration
                    self.cooldownEnabled = enabled
                end

                if not cooldown:IsShown() then
                    cooldown:Show()
                end
            else
                self.cooldownStart = nil
                self.cooldownDuration = nil
                self.cooldownEnabled = nil

                if cooldown:IsShown() then
                    cooldown:Hide()
                end
            end
        end

        btn.RefreshCharges = function(self)
            local charges = GetItemCount(self.itemId, nil, true) or 0
            if charges ~= self.charges then
                self.charges = charges
                if self.charges > 1 then
                    self.count:SetText(self.charges)
                    self.count:Show()
                else
                    self.count:Hide()
                end

                if self.charges == 0 then
                    Questie.Debug(Questie.DEBUG_DEVELOP, "[TrackerQuestItemButtons: Button.OnUpdate]")
                    QuestieCombatQueue:Queue(function()
                        C_Timer.After(0.2, function()
                            QuestieTracker:Update()
                        end)
                    end)
                end
            end
        end

        btn.RefreshRangeIndicator = function(self)
            if not UnitExists("target") then
                if self.range:IsShown() then
                    self.range:Hide()
                end
                return
            end

            -- IsItemInRange is restricted to only be used either on hostile targets or friendly ones while NOT in combat.
            if UnitIsFriend("player", "target") and InCombatLockdown() then
                return
            end

            local isInRange = IsItemInRange(self.itemId, "target")
            if isInRange == nil then
                if not self.itemName then
                    self.itemName = GetItemInfo(self.itemId)
                end

                if self.itemName then
                    isInRange = IsItemInRange(self.itemName, "target")
                end
            end

            if isInRange == false then
                self.range:SetVertexColor(1.0, 0.1, 0.1)
                self.range:Show()
            elseif isInRange == true then
                self.range:SetVertexColor(0.6, 0.6, 0.6)
                self.range:Show()
            elseif self.range:IsShown() then
                self.range:Hide()
            end
        end

        btn.OnUpdate = function(self, elapsed)
            if not self.itemId or not self:IsVisible() then
                return
            end

            local cooldownTimer = (self.cooldownTimer or 0) - elapsed
            if cooldownTimer <= 0 then
                self:RefreshCooldown()
                cooldownTimer = ITEM_BUTTON_UPDATE_INTERVAL
            end
            self.cooldownTimer = cooldownTimer

            local chargeTimer = (self.chargeTimer or 0) - elapsed
            if chargeTimer <= 0 then
                self:RefreshCharges()
                chargeTimer = ITEM_BUTTON_CHARGE_UPDATE_INTERVAL
            end
            self.chargeTimer = chargeTimer

            if UnitExists("target") then
                local rangeTimer = (self.rangeTimer or 0) - elapsed
                if rangeTimer <= 0 then
                    self:RefreshRangeIndicator()
                    rangeTimer = ITEM_BUTTON_RANGE_UPDATE_INTERVAL
                end
                self.rangeTimer = rangeTimer
            elseif self.range:IsShown() then
                self.range:Hide()
            end
        end

        btn.OnShow = function(self)
            self:RegisterEvent("PLAYER_TARGET_CHANGED")
            self:RegisterEvent("BAG_UPDATE_COOLDOWN")
            self:RegisterEvent("BAG_UPDATE")
            self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            self.cooldownTimer = 0
            self.chargeTimer = 0
            self.rangeTimer = -1
        end

        btn.OnHide = function(self)
            self:UnregisterEvent("PLAYER_TARGET_CHANGED")
            self:UnregisterEvent("BAG_UPDATE_COOLDOWN")
            self:UnregisterEvent("BAG_UPDATE")
            self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        end

        btn.OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink("item:" .. tostring(self.itemId) .. ":0:0:0:0:0:0:0")
            GameTooltip:Show()

            TrackerFadeTicker.Unfade(self)
        end

        btn.OnLeave = function(self)
            GameTooltip:Hide()

            TrackerFadeTicker.Fade(self)
        end

        btn.FakeHide = function(self)
            self:RegisterForClicks()
            self:SetScript("OnEnter", nil)
            self:SetScript("OnLeave", nil)
        end

        btn:HookScript("OnUpdate", btn.OnUpdate)

        btn:FakeHide()

        buttonPool[i] = btn
        buttonPool[i]:Hide()
    end
end

function TrackerQuestItemButtons.ResetForChange()
    if TrackerBaseFrame.isSizing == true or TrackerBaseFrame.isMoving == true then
        Questie.Debug(Questie.DEBUG_SPAM, "[TrackerQuestItemButtons:ResetForChange]")
    else
        Questie.Debug(Questie.DEBUG_INFO, "[TrackerQuestItemButtons:ResetForChange]")
    end

    if InCombatLockdown() or not Questie.db.profile.trackerEnabled then
        return
    end

    buttonIndex = 0
end

---@return Button|nil button
function TrackerQuestItemButtons.GetNextButton()
    buttonIndex = buttonIndex + 1
    if not buttonPool[buttonIndex] then
        return nil -- past the button pool limit
    end

    return buttonPool[buttonIndex]
end

---@return Button|nil button
function TrackerQuestItemButtons.GetCurrentButton()
    return buttonPool[buttonIndex]
end

function TrackerQuestItemButtons.HideUnusedButtons()
    if TrackerBaseFrame.isSizing == true or TrackerBaseFrame.isMoving == true then
        Questie.Debug(Questie.DEBUG_SPAM, "[TrackerQuestItemButtons:HideUnusedButtons]")
    else
        Questie.Debug(Questie.DEBUG_INFO, "[TrackerQuestItemButtons:HideUnusedButtons]")
    end
    local startUnusedButtons = 0

    if Questie.db.char.isTrackerExpanded then
        startUnusedButtons = buttonIndex + 1
    end

    for i = startUnusedButtons, buttonPoolSize do
        local button = buttonPool[i]
        if button then
            button:FakeHide()
            button.itemId = nil
            button.itemName = nil
            button.lineID = nil
            button.fontSize = nil
            button.cooldownTimer = nil
            button.chargeTimer = nil
            button.rangeTimer = nil
            button.cooldownStart = nil
            button.cooldownDuration = nil
            button.cooldownEnabled = nil
            button:ClearAllPoints()
            button:SetParent(UIParent)
            button:Hide()
        end
    end
end
