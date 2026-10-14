-- Run from the addon root with Lua 5.1 or 5.2+.
-- Execute complete tracker modules with native-style frames, without post-initialization patching.
local unpackValues = unpack or table.unpack
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local env = setmetatable({}, {__index = _G})
env._G, env.unpack, env.tinsert = env, unpackValues, table.insert
local function loadModule(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local chunk
    if setfenv then
        chunk = setfenv(assert(loadstring(source, "@" .. path)), env)
    else
        chunk = assert(load(source, "@" .. path, "t", env))
    end
    chunk()
end
local function noop() end
local inCombat = false
local methods = {}
local function object(name, parent)
    return setmetatable({name = name, parent = parent, width = 0, height = 0,
        text = "", font = {"Fonts/FRIZQT__.TTF", 12, ""}, points = {}, scripts = {}, shown = true},
        {__index = methods})
end
for _, method in ipairs({"EnableMouse", "EnableMouseWheel", "SetMovable", "SetResizable",
    "RegisterForDrag", "RegisterForClicks", "SetJustifyH", "SetJustifyV", "SetFrameLevel",
    "SetAlpha", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
    "SetVertexColor", "SetTexCoord", "SetAttribute", "RegisterEvent", "UnregisterEvent", "SetHitRectInsets"}) do
    methods[method] = noop
end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width > 0 and self.width or self:GetStringWidth() end
function methods:GetHeight()
    if self.height > 0 then return self.height end
    return self.font[2] * math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self:GetWidth())))
end
function methods:SetAllPoints(relative)
    self.width, self.height = relative:GetWidth(), relative:GetHeight()
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...)
    local args = {...}
    if select("#", ...) == 5 then
        assert(type(args[2]) == "table", "anchor must reference an initialized control")
    end
    self.points[#self.points + 1] = args
end
function methods:SetTexture(...) self.texture = {...} end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, callback)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then original(...) end
        callback(...)
    end
end
function methods:CreateTexture() return object(nil, self) end
function methods:CreateFontString() return object(nil, self) end
function methods:SetFont(...) self.font = {...} end
function methods:GetFont() return unpackValues(self.font) end
function methods:SetText(value) self.text = value or "" end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text * self.font[2] / 2 end
function methods:SetValueStep(value) self.valueStep = value end
function methods:SetValue(value) self.value = value end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetAttribute(name, value)
    assert(not inCombat, "secure item attributes must not change in combat")
    self.attributes = self.attributes or {}
    self.attributes[name] = value
end
function methods:RegisterForClicks(...)
    assert(not inCombat, "secure item click registration must not change in combat")
    self.clicks = {...}
end
function methods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetNormalTexture(value) self.normalTexture = value end
function methods:SetVertexColor(...) self.color = {...} end
function methods:SetCooldown(start, duration, enabled)
    self.cooldown = {start, duration, enabled}
    self.cooldownWrites = (self.cooldownWrites or 0) + 1
end
function methods:SetParent(parent) self.parent = parent end

env.UIParent = object("UIParent")
local templates = {}
local cooldownFrames = {}
env.CreateFrame = function(kind, name, parent, template)
    local frame = object(name, parent)
    if name then env[name] = frame end
    if template then templates[template] = true end
    if kind == "Cooldown" then cooldownFrames[parent] = frame end
    if template == "UIPanelScrollFrameTemplate" then
        for _, suffix in ipairs({"ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton"}) do
            env[name .. suffix] = object(name .. suffix, frame)
        end
    end
    return frame
end
env.Questie = {db = {profile = {trackerHeaderEnabled = true, trackerFontSizeHeader = 14,
    trackerFontSizeQuest = 12, trackerFontSizeObjective = 10, trackerFontSizeZone = 13,
    trackerEnabled = true, trackerFadeQuestItemButtons = true}, char = {isTrackerExpanded = true}},
    icons = {complete = "complete"}, Debug = noop}
env.QuestieCompat = {NOOP = noop, NOOP_MT = {__index = function() return noop end},
    C_Timer = {}, C_QuestLog = {GetMaxNumQuestsCanAccept = function() return 25 end},
    LibUIDropDownMenu = {}}
env.LibStub = function(name)
    equal(name, "LibSharedMedia-3.0", "tracker media library")
    return {Fetch = function() return "Fonts/FRIZQT__.TTF" end}
end
loadModule("Modules/Libs/QuestieLoader.lua")
local loader = env.QuestieLoader
local l10n = loader:CreateModule("l10n")
setmetatable(l10n, {__call = function(_, text) return text end})
loader:CreateModule("QuestieTracker").HasQuest = function() return true end
loader:CreateModule("QuestieCombatQueue").Queue = function(_, callback) callback() end
loader:CreateModule("QuestieLib").AddonPath = "Interface/AddOns/Questie-335/"

local bags, equipment, itemClasses, charges = {}, {}, {}, {}
local cooldownValues, rangeValues, itemNames = {}, {}, {}
local cooldownReads, chargeReads, rangeReads = 0, 0, 0
local targetExists, friendlyTarget = false, false
env.InCombatLockdown = function() return inCombat end
env.GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end
env.QuestieCompat.GetContainerItemInfo = function(bag, slot)
    local item = bags[bag][slot]
    return item.texture, nil, nil, nil, nil, nil, nil, nil, nil, item.id
end
env.GetInventoryItemID = function(_, slot) return equipment[slot] and equipment[slot].id end
env.GetInventoryItemTexture = function(_, slot) return equipment[slot].texture end
loader:CreateModule("QuestieDB").QueryItemSingle = function(itemId, field)
    equal(field, "class", "item eligibility queries the class")
    return itemClasses[itemId]
end
env.GetItemCount = function(itemId, _, includeCharges)
    equal(includeCharges, true, "item button counts charges")
    chargeReads = chargeReads + 1
    return charges[itemId] or 0
end
env.GetItemCooldown = function(itemId)
    cooldownReads = cooldownReads + 1
    return unpackValues(cooldownValues[itemId] or {0, 0, 1})
end
env.UnitExists = function() return targetExists end
env.UnitIsFriend = function() return friendlyTarget end
env.IsItemInRange = function(itemId)
    rangeReads = rangeReads + 1
    return rangeValues[itemId]
end
env.GetItemInfo = function(itemId) return itemNames[itemId] end
local queued, delayed, trackerUpdates = {}, {}, 0
loader:ImportModule("QuestieTracker").Update = function() trackerUpdates = trackerUpdates + 1 end
loader:ImportModule("QuestieCombatQueue").Queue = function(_, callback) queued[#queued + 1] = callback end
env.QuestieCompat.C_Timer.After = function(delay, callback)
    delayed[#delayed + 1] = {delay, callback}
end
local faded, unfaded
loader:CreateModule("TrackerFadeTicker").Fade = function(button) faded = button end
loader:ImportModule("TrackerFadeTicker").Unfade = function(button) unfaded = button end
env.GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    SetHyperlink = function(self, link) self.link = link end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}
loadModule("Compat/UI.lua")
loadModule("Modules/Tracker/TrackerHeaderFrame.lua")
loadModule("Modules/Tracker/TrackerQuestFrame.lua")
loadModule("Modules/Tracker/TrackerQuestItemButtons.lua")
loadModule("Modules/Tracker/TrackerLinePool.lua")
local headerModule = loader:ImportModule("TrackerHeaderFrame")
local questModule = loader:ImportModule("TrackerQuestFrame")
local pool = loader:ImportModule("TrackerLinePool")
local base = object("Base")
local header = headerModule.Initialize(base)
local quest = questModule.Initialize(base, header)

-- The header can measure text correctly before the line pool is initialized.
local label = header.trackedQuests.label
label:SetFont("Fonts/FRIZQT__.TTF", 14, "")
label:SetText("Tracked Quests: 5")
label:SetWidth(10)
equal(label:GetUnboundedStringWidth(), 119, "header measures complete text")
equal(label:GetWidth(), 10, "header measurement preserves constrained width")
equal(headerModule.headerFrame, header, "header frame published")
equal(header:GetHeight(), 14, "header height preserves configured font size")
local tests = 1

-- Controls use the final layout immediately, without a later line-pool hook.
assert(templates.UIPanelScrollFrameTemplate, "native scroll template retained")
equal(quest.ScrollFrame.scrollBarHideable, true, "template scrollbar auto-show disabled")
equal(quest.ScrollBar:IsShown(), false, "scrollbar starts hidden")
quest.ScrollBar:Show()
equal(quest.ScrollBar:IsShown(), false, "template cannot show scrollbar again")
equal(quest.ScrollBg:IsShown(), true, "scrollbar background setup preserved")
equal(quest.ScrollBg.texture[4], 0.35, "scrollbar background opacity preserved")
equal(quest.ScrollUpButton:IsShown(), false, "up button remains hidden")
equal(quest.ScrollDownButton:IsShown(), false, "down button remains hidden")
equal(quest.ScrollBar.points[1][2], quest.ScrollUpButton, "scrollbar top uses up button")
equal(quest.ScrollBar.points[2][2], quest.ScrollDownButton, "scrollbar bottom uses down button")
equal(quest.ScrollBar.points[2][5], -4, "scrollbar lower offset preserved")
equal(quest.ScrollDownButton.points[1][5], 12, "down button offset preserved")
equal(quest.ScrollBar.valueStep, 25, "scroll increment retained")
equal(quest.ScrollFrame.scrollChild, quest.ScrollChildFrame, "scroll child attached")
tests = tests + 1

-- Mouse-wheel movement stays bounded even while the scrollbar itself is hidden.
quest.ScrollFrame:SetHeight(100)
quest.ScrollChildFrame:SetHeight(180)
quest.ScrollFrame:SetVerticalScroll(0)
quest.ScrollFrame:GetScript("OnMouseWheel")(quest.ScrollFrame, -1)
equal(quest.ScrollFrame:GetVerticalScroll(), 25, "wheel moves down")
equal(quest.ScrollBar.value, 25, "scrollbar value tracks wheel")
quest.ScrollChildFrame:GetScript("OnMouseWheel")(quest.ScrollChildFrame, -10)
equal(quest.ScrollFrame:GetVerticalScroll(), 80, "wheel clamps at bottom")
quest:GetScript("OnMouseWheel")(quest, 10)
equal(quest.ScrollFrame:GetVerticalScroll(), 0, "wheel clamps at top")
quest.ScrollChildFrame:SetHeight(80)
questModule.OnMouseWheel(quest, -1)
equal(quest.ScrollFrame:GetVerticalScroll(), 0, "short content does not scroll")
tests = tests + 1

-- Execute the whole pooled-frame initialization, including its coroutine yields and item buttons.
local resumes = 0
local initialization = coroutine.create(function() pool.Initialize(quest) end)
while coroutine.status(initialization) ~= "dead" do
    local ok, message = coroutine.resume(initialization)
    assert(ok, message)
    resumes = resumes + 1
    -- Every label already created must be ready, including during partially completed initialization.
    for index = 1, 250 do
        local line = env["linePool" .. index]
        if line then
            equal(line.label.GetUnboundedStringWidth, env.QuestieCompat.GetUnboundedStringWidth, "pooled text-width adapter")
            equal(line.label.GetWrappedWidth, line.label.GetWidth, "pooled wrapped-width adapter")
            equal(line.label.GetNumLines, env.QuestieCompat.GetNumLines, "pooled line-count adapter")
        end
    end
end
assert(resumes > 1, "initialization still yields to avoid a startup stall")
assert(env.linePool250 and not env.linePool251, "complete line pool created")
assert(env.Questie_ItemButton25 and not env.Questie_ItemButton26, "quest item button pool retained")
equal(pool.GetLastLine(), env.linePool250, "module pool matches created frames")
tests = tests + 1

-- Font adapters use separate measurement state; wrapped labels still resize their clickable frames.
local line = env.linePool1
label = line.label
label:SetFont("Fonts/FRIZQT__.TTF", 10, "")
label:SetWidth(45)
label:SetText("Collect nine items")
equal(label:GetUnboundedStringWidth(), 90, "objective measures full text width")
equal(label:GetWrappedWidth(), 45, "objective keeps wrapped width")
equal(label:GetNumLines(), 2, "objective reports wrapped line count")
equal(line:GetWidth(), 45, "clickable frame follows label width")
equal(line:GetHeight(), 20, "clickable frame follows wrapped label height")
label:SetWidth(90)
label:SetText("Collect nine items")
equal(label:GetNumLines(), 1, "wider objective wraps to one line")
equal(line:GetHeight(), 10, "clickable frame shrinks after unwrapping")
label:SetText("")
equal(label:GetUnboundedStringWidth(), 0, "empty objective has no text width")
tests = tests + 1
print("Tracker initialization regression tests passed (" .. tests .. " groups)")

-- Quest-item buttons retain their public pool interface and native secure click setup.
pool.ResetButtonsForChange()
local button = pool.GetNextItemButton()
equal(button, env.Questie_ItemButton1, "first pooled button")
equal(button.alpha, 0, "configured item-button fade applied during initialization")
equal(pool.GetCurrentButton(), button, "current pooled button")
bags[0] = {{id = 100, texture = "bag-item"}}
itemClasses[100], charges[100] = 12, 3
assert(button:SetItem(100, 200, 24), "quest item in bags binds successfully")
equal(button.normalTexture, "bag-item", "bag texture used")
equal(button.attributes.type1, "item", "secure item action type")
equal(button.attributes.item1, "item:100", "secure item action value")
equal(button.clicks[1], "anyUp", "native click registration")
equal(button.questID, 200, "item button quest association")
equal(button.count:GetText(), 3, "charge count shown")
equal(button.count:IsShown(), true, "multiple charges visible")
equal(button.events.BAG_UPDATE, true, "shown button watches bags")
equal(button.events.PLAYER_EQUIPMENT_CHANGED, true, "shown button watches equipment")
equal(cooldownFrames[button]:GetWidth(), 20, "cooldown inset preserved")
button:OnEnter()
equal(env.GameTooltip.owner, button, "tooltip uses item button")
equal(env.GameTooltip.link, "item:100:0:0:0:0:0:0:0", "item tooltip hyperlink")
equal(unfaded, button, "hover unfades item button")
button:OnLeave()
equal(faded, button, "leaving fades item button")
equal(env.GameTooltip.shown, false, "leaving hides tooltip")

-- A pool reset cannot reassign a secure button during combat or while disabled.
inCombat = true
pool.ResetButtonsForChange()
equal(pool.GetCurrentButton(), button, "combat reset preserves selected button")
inCombat = false
env.Questie.db.profile.trackerEnabled = false
pool.ResetButtonsForChange()
equal(pool.GetCurrentButton(), button, "disabled tracker preserves selected button")
env.Questie.db.profile.trackerEnabled = true
pool.ResetButtonsForChange()
equal(pool.GetNextItemButton(), button, "eligible reset reuses first button")
for index = 2, 25 do
    equal(pool.GetNextItemButton(), env["Questie_ItemButton" .. index], "pooled button order")
end
equal(pool.GetNextItemButton(), nil, "pool exhaustion returns nil")

-- Cooldowns update when their values change, without restarting unchanged animations.
local cooldown = cooldownFrames[button]
cooldownValues[100] = {10, 30, 1}
button:RefreshCooldown()
equal(cooldown.cooldownWrites, 1, "initial cooldown applied")
equal(cooldown:IsShown(), true, "active cooldown visible")
button:RefreshCooldown()
equal(cooldown.cooldownWrites, 1, "unchanged cooldown does not restart")
cooldownValues[100] = {20, 30, 1}
button:RefreshCooldown()
equal(cooldown.cooldownWrites, 2, "changed cooldown applied")
cooldownValues[100] = {0, 0, 1}
button:RefreshCooldown()
equal(cooldown:IsShown(), false, "expired cooldown hidden")
equal(button.cooldownStart, nil, "expired cooldown cache cleared")

-- Charges trigger one deferred tracker update when an item is consumed.
charges[100] = 1
button:RefreshCharges()
equal(button.count:IsShown(), false, "single charge label hidden")
charges[100] = 0
button:RefreshCharges()
equal(#queued, 1, "consumed item update waits for combat queue")
equal(trackerUpdates, 0, "consumed item does not update immediately")
queued[1]()
equal(delayed[1][1], 0.2, "consumed item update delay")
delayed[1][2]()
equal(trackerUpdates, 1, "consumed item updates tracker")
button:RefreshCharges()
equal(#queued, 1, "unchanged zero charges do not queue repeated updates")

-- Range checks preserve friendly-target combat restrictions and name fallback.
targetExists, friendlyTarget = true, true
inCombat = true
local previousReads = rangeReads
button:RefreshRangeIndicator()
equal(rangeReads, previousReads, "friendly combat target is never queried")
inCombat = false
rangeValues[100] = false
button:RefreshRangeIndicator()
equal(button.range:IsShown(), true, "out-of-range indicator visible")
equal(button.range.color[1], 1, "out-of-range indicator red")
rangeValues[100] = true
button:RefreshRangeIndicator()
equal(button.range.color[1], 0.6, "in-range indicator gray")
rangeValues[100], itemNames[100], rangeValues["Quest item"] = nil, "Quest item", false
button:RefreshRangeIndicator()
equal(button.itemName, "Quest item", "range check falls back to cached item name")
equal(button.range.color[1], 1, "name fallback result used")
friendlyTarget, inCombat = false, true
previousReads = rangeReads
button:RefreshRangeIndicator()
assert(rangeReads > previousReads, "hostile combat target remains queryable")
inCombat = false
rangeValues["Quest item"] = nil
button:RefreshRangeIndicator()
equal(button.range:IsShown(), false, "unknown range indicator hidden")
targetExists = false
button.range:Show()
button:RefreshRangeIndicator()
equal(button.range:IsShown(), false, "missing target indicator hidden")

-- Equipment fallback retains quest-item eligibility and rejects missing or ordinary items.
bags[0] = {}
equipment[16] = {id = 101, texture = "equipped-item"}
itemClasses[101], charges[101] = 12, 1
assert(button:SetItem(101, 201, 20), "equipped quest item binds successfully")
equal(button.normalTexture, "equipped-item", "equipped texture used")
equal(button.attributes.item1, "item:101", "equipped quest item action")
equal(button.itemName, nil, "reassignment clears cached item name")
bags[0] = {{id = 102, texture = "ordinary-item"}}
itemClasses[102] = 2
equal(button:SetItem(102, 202, 20), false, "ordinary items are rejected")
equal(button.attributes.item1, nil, "rejected item clears secure action")
equal(button:IsShown(), false, "rejected item button hidden")
equal(button.events.BAG_UPDATE, nil, "hidden button stops watching bags")
equal(button:SetItem(999, 203, 20), false, "missing quest items are rejected")

-- Refresh work is throttled and events invalidate the appropriate timers.
assert(button:SetItem(101, 201, 20))
targetExists, friendlyTarget = true, false
rangeValues[101] = true
local update = button:GetScript("OnUpdate")
local oldCooldownReads, oldChargeReads, oldRangeReads = cooldownReads, chargeReads, rangeReads
update(button, 0.01)
equal(cooldownReads, oldCooldownReads + 1, "first visible update checks cooldown")
equal(chargeReads, oldChargeReads + 1, "first visible update checks charges")
equal(rangeReads, oldRangeReads + 1, "first visible update checks range")
update(button, 0.01)
equal(cooldownReads, oldCooldownReads + 1, "cooldown checks throttled")
equal(chargeReads, oldChargeReads + 1, "charge checks throttled")
equal(rangeReads, oldRangeReads + 1, "range checks throttled")
button:OnEvent("BAG_UPDATE_COOLDOWN")
equal(button.cooldownTimer, 0, "cooldown event invalidates cooldown timer")
button:OnEvent("BAG_UPDATE")
equal(button.chargeTimer, 0, "bag event invalidates charges")
button.chargeTimer = 1
button:OnEvent("PLAYER_EQUIPMENT_CHANGED")
equal(button.chargeTimer, 0, "equipment event invalidates charges")
button:OnEvent("PLAYER_TARGET_CHANGED")
equal(button.rangeTimer, -1, "target event invalidates range")
equal(button.range:IsShown(), false, "target event clears old range marker")
button:Hide()
oldCooldownReads = cooldownReads
update(button, 1)
equal(cooldownReads, oldCooldownReads, "hidden buttons skip refresh work")
button:Show()

-- Unused buttons release item state and can be reused on the next layout pass.
pool.ResetButtonsForChange()
local first = pool.GetNextItemButton()
local second = pool.GetNextItemButton()
assert(second:SetItem(101, 201, 20))
cooldownValues[101] = {20, 30, 1}
second:RefreshCooldown()
equal(second.cooldownStart, 20, "unused button starts with cached cooldown")
pool.ResetButtonsForChange()
equal(pool.GetNextItemButton(), first, "retain only first button in next layout")
pool.HideUnusedButtons()
equal(first:IsShown(), true, "used button stays visible")
equal(second:IsShown(), false, "unused button hidden")
equal(second.itemId, nil, "unused item cleared")
equal(second.cooldownTimer, nil, "unused cooldown timer cleared")
equal(second.cooldownStart, nil, "unused cooldown cache cleared")
equal(#second.clicks, 0, "unused button cannot receive clicks")
equal(second:GetScript("OnEnter"), nil, "unused tooltip disabled")
equal(second:GetParent(), env.UIParent, "unused button detached from line")
equal(second.events.BAG_UPDATE, nil, "unused button unregisters events")
assert(second:SetItem(101, 201, 20), "unused button can be rebound")
env.Questie.db.char.isTrackerExpanded = false
pool.HideUnusedButtons()
equal(first:IsShown(), false, "collapsed tracker hides used buttons")
equal(second:IsShown(), false, "collapsed tracker hides all buttons")

-- A client-designated quest item remains usable when Questie lacks its item metadata.
itemClasses[100] = nil
bags[0] = {{id = 100, texture = "native-item"}}
assert(first:SetItem(100, 900001, 24, true), "native quest item bypasses missing database class")
equal(first.attributes.item1, "item:100", "native item uses the existing secure action")
assert(not first:SetItem(100, 900001, 24), "ordinary items still require quest-item metadata")
equal(first.attributes.item1, nil, "rejected item clears the previous secure action")
print("Tracker quest-item button regressions passed")
