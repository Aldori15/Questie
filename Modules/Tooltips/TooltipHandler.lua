---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips");
local _QuestieTooltips = QuestieTooltips.private

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

--- COMPATIBILITY ---
local RawUnitGUID = UnitGUID
local UnitGUID = QuestieCompat.UnitGUID

local strfind = string.find

local lastGuid

local function _AreQuestieTooltipsEnabled()
    return Questie.db.profile.enabled and Questie.db.profile.enableTooltips
end

local function _AddSpellId(tooltip, spellId)
    if (not _AreQuestieTooltipsEnabled()) or (not Questie.db.profile.enableTooltipsSpellID)
        or type(spellId) ~= "number" or spellId <= 0 or tooltip.questieSpellID == spellId then
        return
    end

    tooltip.questieSpellID = spellId
    tooltip:AddDoubleLine(l10n("Spell ID"), tostring(spellId), 1, 0.82, 0, 1, 1, 1)
    tooltip:Show()
end

local spellIdHooksInitialized = {}

function _QuestieTooltips.InitializeSpellIdTooltip(tooltip)
    if spellIdHooksInitialized[tooltip] then
        return
    end
    spellIdHooksInitialized[tooltip] = true

    tooltip:HookScript("OnTooltipCleared", function(self)
        self.questieSpellID = nil
    end)
    tooltip:HookScript("OnTooltipSetSpell", function(self)
        -- Original 3.3.5 returns name, rank, spellId (unlike current Classic).
        local _, _, spellId = self:GetSpell()
        _AddSpellId(self, spellId)
    end)

    -- Aura tooltips do not consistently fire OnTooltipSetSpell on 3.3.5.
    for _, aura in ipairs({{"SetUnitAura", UnitAura}, {"SetUnitBuff", UnitBuff}, {"SetUnitDebuff", UnitDebuff}}) do
        local getAura = aura[2]
        hooksecurefunc(tooltip, aura[1], function(self, unit, index, filter)
            if (not _AreQuestieTooltipsEnabled()) or (not Questie.db.profile.enableTooltipsSpellID) then
                return
            end
            -- All three Wrath aura APIs return the spell ID as their eleventh value.
            _AddSpellId(self, select(11, getAura(unit, index, filter)))
        end)
    end
end

function _QuestieTooltips:AddUnitDataToTooltip()
    if (self.IsForbidden and self:IsForbidden()) or (not _AreQuestieTooltipsEnabled()) then
        return
    end

    local name, unitToken = self:GetUnit();
    if not unitToken then return end
    local guid = UnitGUID(unitToken);
    local rawGuid = RawUnitGUID(unitToken)
    if (not guid) then
        guid = UnitGUID("mouseover");
        rawGuid = RawUnitGUID("mouseover")
    end

    local type, _, _, _, _, npcId, _ = strsplit("-", guid or "");

    if name and (type == "Creature" or type == "Vehicle") and (
        name ~= QuestieTooltips.lastGametooltipUnit or
        (not QuestieTooltips.lastGametooltipCount) or
        _QuestieTooltips:CountTooltip() < QuestieTooltips.lastGametooltipCount or
        QuestieTooltips.lastGametooltipType ~= "monster" or
        lastGuid ~= rawGuid
    ) then
        QuestieTooltips.lastGametooltipUnit = name
        if Questie.db.profile.enableTooltipsNPCID then
            GameTooltip:AddDoubleLine(l10n("NPC ID"), "|cFFFFFFFF" .. npcId .. "|r")
        end

        local server = QuestieLoader:ImportModule("QuestieServer")
        local starterState = server.GetNPCQuestgiverUnitState
            and server:GetNPCQuestgiverUnitState(tonumber(npcId), rawGuid)
        local tooltipData = QuestieTooltips:GetTooltip("m_" .. npcId, nil, starterState);
        if tooltipData then
            GameTooltip:AddLine(" ")
            for _, v in pairs (tooltipData) do
                GameTooltip:AddLine(v)
            end
            self:Show()
        end
        QuestieTooltips.lastGametooltipCount = _QuestieTooltips:CountTooltip()
    end
    lastGuid = rawGuid;
    QuestieTooltips.lastGametooltipType = "monster";
end

local checkedQuestStartItems = {} -- cache item IDs that were already checked if they start a quest
local lastItemId = 0;

local function _IsLootTooltip(tooltip)
    if tooltip ~= GameTooltip or not tooltip.GetOwner then
        return false
    end

    local owner = tooltip:GetOwner()
    local ownerName = owner and owner.GetName and owner:GetName()

    return ownerName and (string.match(ownerName, "^LootButton%d+$") or string.match(ownerName, "^GroupLootFrame%d+$"))
end

function _QuestieTooltips:AddItemDataToTooltip()
    if (self.IsForbidden and self:IsForbidden()) or (not _AreQuestieTooltipsEnabled()) or _IsLootTooltip(self) then
        return
    end

    local name, link = self:GetItem()
    local itemId
    if link then
        itemId = select(3, string.match(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?"))
    end
    if name and itemId and (
        name ~= QuestieTooltips.lastGametooltipItem or
        (not QuestieTooltips.lastGametooltipCount) or
        _QuestieTooltips:CountTooltip() < QuestieTooltips.lastGametooltipCount or
        QuestieTooltips.lastGametooltipType ~= "item" or
        lastItemId ~= itemId or
        QuestieTooltips.lastFrameName ~= self:GetName()
    ) then
        QuestieTooltips.lastGametooltipItem = name
        if Questie.db.profile.enableTooltipsItemID then
            self:AddDoubleLine(l10n("Item ID"), "|cFFFFFFFF" .. itemId .. "|r")
        end

        if (not checkedQuestStartItems[itemId]) then
            checkedQuestStartItems[itemId] = true
            local itemIdAsNumber = tonumber(itemId)
            if itemIdAsNumber then
                local startQuestId = QuestieDB.QueryItemSingle(itemIdAsNumber, "startQuest")
                local itemName = QuestieDB.QueryItemSingle(itemIdAsNumber, "name")
                if startQuestId and startQuestId ~= 0 and itemName then
                    QuestieTooltips:RegisterQuestStartTooltip(startQuestId, itemName, itemIdAsNumber, "i_"..itemId, "itemFromMonster")
                end
            end
        end

        local tooltipData = QuestieTooltips:GetTooltip("i_" .. (itemId or 0));
        if tooltipData then
            for _, v in pairs (tooltipData) do
                self:AddLine(v)
            end
            self:Show()
        end
        QuestieTooltips.lastGametooltipCount = _QuestieTooltips:CountTooltip()
    end
    lastItemId = itemId;
    QuestieTooltips.lastGametooltipType = "item";
    QuestieTooltips.lastFrameName = self:GetName();
end

function _QuestieTooltips:AddObjectDataToTooltip(name)
    if (not _AreQuestieTooltipsEnabled()) then
        return
    end
    if name then
        local titleAdded = false
        local tooltipModified = false
        local lookup = l10n:GetObjectNameLookup(name)
        local count = type(lookup) == "table" and table.getn(lookup) or (lookup and 1 or 0)
        local zoneFilter = count == 1 and 0 or nil

        if Questie.db.profile.enableTooltipsObjectID == true and count ~= 0 then
            if count == 1 then
                GameTooltip:AddDoubleLine("Object ID", "|cFFFFFFFF" .. (type(lookup) == "table" and lookup[1] or lookup) .. "|r")
            else
                GameTooltip:AddDoubleLine("Object ID", "|cFFFFFFFF" .. lookup[1] .. " (" .. count .. ")|r")
            end
            tooltipModified = true
        end

        local alreadyAddedObjectiveLines = {}
        local function _AddTooltipData(gameObjectId)
            local tooltipData = QuestieTooltips:GetTooltip("o_" .. gameObjectId, zoneFilter)

            if type(gameObjectId) == "number" and tooltipData then
                if (not titleAdded) then
                    GameTooltip:AddLine(tooltipData[1])
                    titleAdded = true
                    tooltipModified = true
                end

                if tooltipData[2] then
                    -- Quest has objectives
                    for index, line in pairs (tooltipData) do
                        if index > 1 and (not alreadyAddedObjectiveLines[line]) then -- skip the first entry, it's the title
                            local _, _, acquired, needed = strfind(line, "(%d+)/(%d+)")
                            -- We need "tonumber", because acquired can contain parts of the color string
                            if acquired and tonumber(acquired) == tonumber(needed) then
                                -- We don't want to show completed objectives on game objects
                                break;
                            end
                            alreadyAddedObjectiveLines[line] = true
                            GameTooltip:AddLine(line)
                            tooltipModified = true
                        end
                    end
                end
            end
        end

        if type(lookup) == "table" then
            for _, gameObjectId in pairs(lookup) do
                _AddTooltipData(gameObjectId)
            end
        elseif lookup then
            _AddTooltipData(lookup)
        end
        
        if tooltipModified then
            GameTooltip:Show()
        end
    end
    QuestieTooltips.lastGametooltipType = "object";
end

function _QuestieTooltips:CountTooltip()
    local tooltipCount = 0
    for i = 1, GameTooltip:NumLines() do
        local frame = _G["GameTooltipTextLeft"..i]
        if frame and frame:GetText() then
            tooltipCount = tooltipCount + 1
        else
            return tooltipCount
        end
    end
    return tooltipCount
end
