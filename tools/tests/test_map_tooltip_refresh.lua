-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise real map tooltip collection/rendering and pooled hover highlights.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function setup()
    local env, modules = setmetatable({}, {__index = _G}), {}
    env._G, env.unpack = env, unpack or table.unpack
    local function module(name)
        modules[name] = modules[name] or {private = {}}
        return modules[name]
    end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    local s = {now = 100, progress = 1, pins = {}, env = env, modules = modules}
    local function tooltip()
        local frame = {shown = false, shows = 0, owners = 0}
        function frame:IsShown() return self.shown end
        function frame:SetOwner(owner) self.owner = owner; self.owners = self.owners + 1 end
        function frame:GetOwner() return self.owner end
        function frame:Show() self.shown = true; self.shows = self.shows + 1 end
        function frame:Hide() self.shown = false end
        function frame:ClearLines() self.lines = {} end
        frame.SetFrameStrata = noop
        return frame
    end
    env.GameTooltip, env.WorldMapTooltip = tooltip(), tooltip()
    s.tooltip = tooltip
    env.GetTime = function() return s.now end
    env.GetLocale = function() return "enUS" end
    env.IsShiftKeyDown = function() return s.shift or false end
    env.GetCVar = function(name) return name == "minimapZoom" and "0" or "1" end
    env.Minimap = {GetZoom = function() return 0 end, SetZoom = noop}
    env.Questie = {Debug = noop, Error = error, db = {profile = {questObjectiveColors = true}}}
    local map = {GetMapID = function() return 12 end}
    local pins = {activeMinimapPins = {}, worldmapProvider = {GetMap = function() return {
        EnumeratePinsByTemplate = function()
            local index = 0
            return function() index = index + 1; return s.pins[index] end
        end,
    } end}}
    env.QuestieCompat = {HBDPins = pins, WorldMapFrame = map, C_Map = {},
        SetupTooltip = function(icon) return icon.miniMapIcon and env.GameTooltip or env.WorldMapTooltip end}
    module("QuestieLib").AddonPath = "Interface/AddOns/Questie-335/"
    module("QuestieLib").Maxdist = function() return 0 end
    module("QuestieLib").SortQuestIDsByLevel = function(_, quests)
        local ids = {}; for id in pairs(quests) do ids[#ids + 1] = id end; table.sort(ids); return ids
    end
    module("QuestieLib").GetColoredQuestName = function(_, id) return "Quest " .. id end
    module("QuestieLib").GetDifficultyColorPercent = function() return 1, 1, 1 end
    module("QuestieLib").GetObjectiveDescription = function(_, objective) return objective.Description end
    module("QuestieLib").GetRGBForObjective = function() return "" end
    module("QuestXP").GetQuestLogRewardXP = function() return 0 end
    module("QuestieDB").GetQuest = function() return {level = 10} end
    module("QuestieCorrections").objectiveTooltipHints = {}
    module("QuestiePlayer").currentQuestlog = {}
    module("QuestiePlayer").GetPartyMemberByName = function() return {colorHex = "FFFFFFFF"} end
    module("QuestieComms").GetQuest = function() return {Bob = {[1] = {fulfilled = s.progress, required = 5}}} end
    setmetatable(module("l10n"), {__call = function(_, text) return text end})
    module("TooltipLayout").CreateRows = function()
        local rows = {}
        function rows:AddLine(text) self[#self + 1] = text end
        function rows:AddDoubleLine(left, right) self[#self + 1] = left .. " " .. right end
        return rows
    end
    module("TooltipLayout").Render = function(_, shownOn, rows) shownOn.lines = rows end
    local function loadModule(path)
        if setfenv then setfenv(assert(loadfile(path)), env)()
        else assert(loadfile(path, "t", env))() end
    end
    loadModule("Modules/FramePool/QuestieFrame.lua")
    loadModule("Modules/Tooltips/MapIconTooltip.lua")
    s.controller, s.frames = modules.MapIconTooltip, modules.QuestieFrame
    function s.icon(id, mini)
        local texture = {r = 1, g = 0.5, b = 0, a = 1, writes = 0}
        function texture:GetVertexColor() return self.r, self.g, self.b, self.a end
        function texture:SetVertexColor(r, g, b, a)
            self.r, self.g, self.b, self.a = r, g, b, a; self.writes = self.writes + 1
        end
        local icon = {x = 50, y = 50, AreaID = 12, texture = texture, miniMapIcon = mini or false,
            data = {Id = id, Type = "monster", ObjectiveIndex = 1, Name = "Target",
                ObjectiveData = {Description = "Target", Collected = 0, Needed = 5, Type = "monster",
                    IsPartyObjective = true, Update = noop}}}
        function icon:IsVisible() return not self.invisible end
        if mini then pins.activeMinimapPins[icon] = true else s.pins[#s.pins + 1] = {icon = icon} end
        return icon
    end
    function s.show(icon, shownOn, owner, icons)
        s.now = s.now + 1
        s.controller.ShowOnTooltip(icon, shownOn, owner, icons)
    end
    return s
end
local function contains(tooltip, text)
    assert(table.concat(tooltip.lines or {}, "\n"):find(text, 1, true), "tooltip missing " .. text)
end

-- Both native tooltip surfaces must recollect party progress even within the show throttle.
for _, mini in ipairs({false, true}) do
    local s = setup()
    local icon = s.icon(1, mini)
    s.show(icon)
    local tip = mini and s.env.GameTooltip or s.env.WorldMapTooltip
    contains(tip, "1/5")
    s.progress = 2
    tip:_Rebuild()
    contains(tip, "1/5") -- A formatting-only rebuild deliberately uses the old collection.
    s.controller.RefreshQuest(1)
    contains(tip, "2/5")
    equal(tip:GetOwner(), icon, "refresh retains the native tooltip owner")
    equal(tip.owners, 2, "refresh bypasses the show throttle")
    s.controller.RefreshQuest(99)
    equal(tip.owners, 2, "unlisted quests do not rebuild a tooltip")
end

-- Never revive a closed tooltip, a reused owner, a hidden icon or another consumer's tooltip.
for _, change in ipairs({"closed", "reused", "unloaded", "hidden", "invisible", "faded", "other-owner"}) do
    local s = setup()
    local icon = s.icon(1)
    s.show(icon)
    local tip = s.env.WorldMapTooltip
    if change == "closed" then tip:Hide()
    elseif change == "reused" then icon.data = {Id = 2}
    elseif change == "unloaded" then icon.data = nil
    elseif change == "hidden" then icon.hidden = true
    elseif change == "invisible" then icon.invisible = true
    elseif change == "faded" then icon.texture.a = 0
    else tip.owner = {} end
    s.controller.RefreshQuest(1)
    equal(tip.owners, 1, "refresh leaves stale tooltip alone: " .. change)
end

-- A patrol has its own tooltip/root and may legitimately show faded icon copies.
do
    local s = setup()
    local icon, other = s.icon(1), s.icon(2)
    local root, tip = {IsVisible = function() return true end}, s.tooltip()
    s.show(icon, tip, root, {icon, other})
    assert(tip.questOrder[2], "patrol initially includes both explicit icons")
    other.data = {Id = 3, Type = "monster", ObjectiveIndex = 1, Name = "Replacement",
        ObjectiveData = other.data.ObjectiveData}
    other.hidden = true -- Only a stale explicit cluster entry could bypass ordinary visibility.
    icon.texture.a, icon.hidden = 0, true
    s.progress = 3
    s.controller.RefreshQuest(1)
    contains(tip, "3/5")
    equal(tip:GetOwner(), root, "patrol keeps its root owner")
    equal(tip._owner, root, "modifier rebuild keeps the fork's root owner contract")
    equal(tip.questOrder[2], nil, "reused clustered icon is not included again")
    equal(tip.questOrder[3], nil, "replacement quest is not adopted into the old cluster")
    root.IsVisible = function() return false end
    s.controller.RefreshQuest(1)
    equal(tip.owners, 2, "hidden patrol root cannot refresh")
end

-- Restoring hover colors must not overwrite an icon reused by another quest.
do
    local s = setup()
    local kept, recycled, unloaded = s.icon(1), s.icon(2), s.icon(3)
    local oldRecycled, oldUnloaded = recycled.data, unloaded.data
    local owner = {data = {touchedPins = {
        {icon = kept, data = kept.data, color = {1, 0.5, 0, 1}},
        {icon = recycled, data = oldRecycled, color = {1, 0.5, 0, 1}},
        {icon = unloaded, data = oldUnloaded, color = {1, 0.5, 0, 1}},
    }}}
    recycled.data, unloaded.data = {Id = 4}, nil
    s.frames.ResetHoverHighlights(owner)
    equal(kept.texture.writes, 1, "matching occupant has its color restored")
    equal(recycled.texture.writes, 0, "recycled occupant keeps its new color")
    equal(unloaded.texture.writes, 0, "unloaded icon is not recolored")
    equal(owner.data.touchedPins, nil, "hover bookkeeping is retired")
end
-- Render the real giver-tooltip chain using cached records, rather than testing a copied traversal.
local function renderChain(links, config)
    config = config or {}
    local s = setup()
    local icon = s.icon(1)
    s.show(icon)
    local tip = s.env.WorldMapTooltip
    tip.npcAndObjectOrder = {Trainer = {{questId = 1, title = "Root quest", type = "Available"}}}
    tip.questOrder = {}
    s.shift = config.shift ~= false
    s.env.Questie.db.profile.enableTooltipsNextInChain = config.enabled ~= false
    local db, lib = s.modules.QuestieDB, s.modules.QuestieLib
    db.DoableStates = {WRONG_RACE = "race", WRONG_CLASS = "class",
        PROFESSION_MISSING = "profession", PROFESSION_SPECIALIZATION = "specialization"}
    db.QueryQuestSingle = function(id, field) return links[id] and links[id][field] end
    db.IsDoableVerbose = function(id) return false, nil, config.reasons and config.reasons[id] end
    s.modules.QuestXP.GetQuestRewardMoney = function() return 0 end
    s.modules.QuestieCorrections.hiddenQuests = config.hidden or {}
    s.modules.QuestieCorrections.questTooltipHints = {}
    s.modules.QuestieReputation.GetReputationReward = function() end
    local shown = {}
    lib.GetEffectiveQuestLevel = function() return 10 end
    lib.GetColoredQuestName = function(_, id)
        shown[#shown + 1] = id
        assert(#shown <= 20, "cyclic quest links must not hang the tooltip renderer")
        return "Quest " .. id
    end
    tip:_Rebuild()
    return shown, tip
end

for _, absent in ipairs({"zero", "nil"}) do
    local shown, tip = renderChain({[1] = {nextQuestInChain = absent == "zero" and 0 or nil, breadcrumbForQuestId = 2},
        [2] = {nextQuestInChain = 3}, [3] = {nextQuestInChain = 0}})
    equal(table.concat(shown, ","), "2,3", absent .. " chain field follows the breadcrumb target")
    contains(tip, "Next in chain:")
end
do
    local shown = renderChain({[1] = {nextQuestInChain = 2},
        [2] = {nextQuestInChain = 0, breadcrumbForQuestId = 3}, [3] = {nextQuestInChain = 0}})
    equal(table.concat(shown, ","), "2,3", "breadcrumb fallback works at later chain steps")
    shown = renderChain({[1] = {nextQuestInChain = 2, breadcrumbForQuestId = 3}, [2] = {nextQuestInChain = 0}})
    equal(table.concat(shown, ","), "2", "ordinary chain takes precedence over breadcrumb")
    shown = renderChain({[1] = {nextQuestInChain = -2, breadcrumbForQuestId = 3}})
    equal(#shown, 0, "negative explicit chain endpoint does not fall back to a breadcrumb")
    shown = renderChain({})
    equal(#shown, 0, "missing chain and breadcrumb links end cleanly")
    shown = renderChain({[1] = {nextQuestInChain = 2}, [2] = {nextQuestInChain = 3},
        [3] = {nextQuestInChain = 0, breadcrumbForQuestId = 2}})
    equal(table.concat(shown, ","), "2,3", "mixed-link cycle renders each follow-up only once")
    shown = renderChain({[1] = {nextQuestInChain = 0, breadcrumbForQuestId = 1}})
    equal(#shown, 0, "self-link does not repeat the hovered quest")
    shown = renderChain({[1] = {nextQuestInChain = 2}, [2] = {nextQuestInChain = 1}})
    equal(table.concat(shown, ","), "2", "cycle back to hovered quest does not repeat it")
end
for _, stop in ipairs({"race", "class", "profession", "specialization", "hidden"}) do
    local config = stop == "hidden" and {hidden = {[3] = true}} or {reasons = {[3] = stop}}
    local shown = renderChain({[1] = {breadcrumbForQuestId = 2}, [2] = {breadcrumbForQuestId = 3}}, config)
    equal(table.concat(shown, ","), "2", "chain retains existing eligibility stop: " .. stop)
end
for _, config in ipairs({{shift = false}, {enabled = false}}) do
    local shown, tip = renderChain({[1] = {breadcrumbForQuestId = 2}}, config)
    equal(#shown, 0, "follow-up display still requires Shift and its existing option")
    assert(not table.concat(tip.lines, "\n"):find("Next in chain:", 1, true), "disabled chain has no empty heading")
end
for _, mini in ipairs({false, true}) do
    for _, case in ipairs({{0, ""}, {1, " (Elite)"}, {2, " (Rare)"}, {3, " (Elite)"}, {4, " (Rare)"}}) do
        local s = setup()
        local db = s.modules.QuestieDB
        db.questTagIds, db.GetQuestTagInfo, db.QueryQuestSingle = {}, function() return 99 end, noop
        db.IsMonthlyQuest, db.IsWeeklyQuest, db.IsDailyQuest, db.IsRepeatable = noop, noop, noop, noop
        s.modules.QuestieEvent.activeQuests = {}
        s.modules.QuestieReputation.GetReputationReward = noop
        s.modules.QuestieCorrections.questTooltipHints = {}
        s.env.ITEM_QUALITY3_DESC = "Rare"
        local ordinary, dropper = s.icon(1, mini), s.icon(2, mini)
        ordinary.data = {Id = 1, Type = "available", Name = "Creature"}
        dropper.data = {Id = 2, Type = "available", Name = "Creature", DropperRank = case[1]}
        local tip = mini and s.env.GameTooltip or s.env.WorldMapTooltip
        s.show(ordinary, tip, nil, {ordinary, dropper})
        equal(tip.lines[1], "Creature" .. case[2] .. " (Hold Shift)", "starter rank is shown on the giver heading")
    end
end
print("Map tooltip refresh passed: native surfaces, patrol ownership, live progress, hover colors, breadcrumb chains and starter ranks")
