-- Run from the addon root with Lua 5.1 or 5.2+.
-- Exercise the production tooltip without modern tooltip APIs or network requests.
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function fixture()
    local env = setmetatable({}, {__index = _G})
    local f = {grouped = true, raid = false, connected = true, tickers = {}, pool = {}, quests = {}, present = {},
        remote = {}, cached = {}, creates = 0, globalTooltipCalls = 0, queries = 0, units = {Friend = "party1"}}
    env._G = env
    env.UIParent = {}
    env.Questie = {db = {profile = {enableTooltips = true, trackerEnabled = true, enableTooltipsQuestLevel = true}}}
    env.UnitName = function(unit) return unit == "player" and "Me" or "Friend" end
    env.UnitIsConnected = function() return f.connected end
    env.UnitClass = function() return "Warrior", "WARRIOR" end
    env.GetClassColor = function() return 1, 1, 1, "ffffffff" end
    env.MouseIsOver = function(frame) return frame.hovered == true end
    env.GameTooltip = setmetatable({}, {__index = function()
        return function() f.globalTooltipCalls = f.globalTooltipCalls + 1 end
    end})
    env.QuestieCompat = {IsInGroup = function() return f.grouped end, IsInRaid = function() return f.raid end,
        GetGroupUnitByName = function(name) return name == "Me" and "player" or f.units[name] end,
        C_Timer = {NewTicker = function(interval, callback)
            local ticker = {interval = interval, callback = callback}
            function ticker:Cancel() self.cancelled = true end
            f.tickers[#f.tickers + 1] = ticker
            return ticker
        end}}
    env.CreateFrame = function(kind, name, parent, template)
        equal(kind, "GameTooltip", "dedicated tooltip frame type")
        equal(template, "GameTooltipTemplate", "native 3.3.5 tooltip template")
        f.creates = f.creates + 1
        local tip = {lines = {}, visible = false}
        function tip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
        function tip:ClearAllPoints() self.point = nil end
        function tip:SetPoint(...) self.point = {...} end
        function tip:ClearLines() self.lines = {} end
        function tip:AddLine(text) self.lines[#self.lines + 1] = tostring(text) end
        function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = tostring(left) .. " " .. tostring(right) end
        function tip:Show()
            self.visible = true
            self.showCalls = (self.showCalls or 0) + 1
        end
        function tip:Hide() self.visible = false end
        function tip:IsShown() return self.visible end
        function tip:SetScript(event, callback) self[event] = callback end
        f.tip = tip
        return tip
    end
    local modules = {}
    local function module(name) modules[name] = modules[name] or {}; return modules[name] end
    env.QuestieLoader = {CreateModule = function(_, name) return module(name) end,
        ImportModule = function(_, name) return module(name) end}
    module("TrackerData").GetQuest = function(id) return f.quests[id] end
    module("TrackerData").ContainsQuest = function(id) return f.present[id] end
    module("TrackerUtils").CanShareQuest = function() return f.canShare ~= false end
    module("TrackerData").GetColoredQuestName = function(quest, levels)
        return (levels and "[12] " or "") .. "Quest " .. quest.Id
    end
    module("TrackerLinePool").GetHighestIndex = function() return #f.pool end
    module("TrackerLinePool").GetLine = function(index) return f.pool[index] end
    module("QuestLogCache").questLog_DO_NOT_MODIFY = f.cached
    module("QuestieComms").GetQuest = function(_, id) f.queries = f.queries + 1; return f.remote[id] end
    module("QuestieLib").GetObjectiveDescription = function(_, objective) return objective.Description or "" end
    module("QuestieLib").GetRGBForObjective = function(_, objective)
        assert(objective.Needed ~= 0, "zero-needed objectives must not reach division-based color calculation")
        return "|cffffffff"
    end
    module("QuestiePlayer").GetPartyMemberByName = function() return {colorHex = "ffffffff"} end
    module("CommsVisibility").ShouldShowPartyObjective = function() return true end
    setmetatable(module("l10n"), {__call = function(_, key) return key end})
    local path = "Modules/Tracker/TrackerQuestTooltip.lua"
    if setfenv then setfenv(assert(loadfile(path)), env)()
    else assert(loadfile(path, "t", env))() end
    f.env, f.module = env, module("TrackerQuestTooltip")
    function f:line(mode, id)
        id = id or 844
        local quest = self.quests[id] or {Id = id, state = 0, Objectives = {{Index = 1, Description = "Plainstrider Beak"}}}
        function quest:IsComplete() return self.state end
        self.quests[id], self.present[id] = quest, true
        local line = {mode = mode or "quest", Quest = quest, visible = true, hovered = true}
        function line:IsVisible() return self.visible end
        function line:GetParent() return self.parent end
        self.pool[#self.pool + 1] = line
        return line
    end
    function f:progress(id)
        self.cached[id] = {objectives = {{text = "Plainstrider Beak", raw_text = "Plainstrider Beak: 2/7",
            type = "item", numFulfilled = 2, numRequired = 7, finished = false}}}
        self.remote[id] = {Friend = {{fulfilled = 3, required = 7, finished = false}}}
    end
    function f:contains(text)
        return self.tip and table.concat(self.tip.lines, "\n"):find(text, 1, true) ~= nil
    end
    function f:tick() self.tickers[#self.tickers].callback() end
    return f
end

do
    local f = fixture()
    local line = f:line()
    f:progress(844)
    local profile = f.env.Questie.db.profile
    for _, bind in ipairs({"disabled", "invalid", "hyperleft"}) do
        profile.trackerbindShareQuest = bind
        f.module.Show(line)
        assert(not f:contains("Share Quest"), "disabled or unknown shortcuts have no share hint")
    end
    profile.trackerbindShareQuest = "altright"
    f.module.Show(line)
    assert(f:contains("(Alt + Right Click: Share Quest)"), "hint describes configured modifier and button")
    f.canShare = false
    f:tick()
    assert(not f:contains("Share Quest") and f:contains("Friend"), "unpushable quests retain progress without share hint")
    f.canShare = true
    profile.trackerbindSetTomTom = "altright"
    f:tick()
    assert(not f:contains("Share Quest"), "TomTom priority suppresses conflicting share hint")
    line.Quest.NativeOnly = true
    f:tick()
    assert(f:contains("Share Quest"), "native-only quests skip TomTom and retain share hint")
    profile.trackerbindShareQuest = "left"
    f:tick()
    assert(f:contains("(Left Click: Share Quest)"), "unmodified shortcut hint")
end

-- Verify the first-display layout pass is synchronous and adds no progress reads or timers.
do
    local f = fixture()
    local line = f:line()
    f.module.Show(line)
    equal(f.tip.showCalls, nil, "absent data does not consume first-display sizing")
    f:progress(844)
    f:tick()
    equal(f.tip.showCalls, 2, "first available display settles layout before returning")
    equal(f.queries, 1, "sizing does not query progress twice")
    equal(#f.tickers, 1, "sizing adds no timer")
    f:tick()
    equal(f.tip.showCalls, 3, "ordinary refresh needs only one sizing pass")
    f.module.Hide(line)
    f.module.Show(line)
    equal(f.tip.showCalls, 4, "subsequent hovers reuse initialized layout")
end

do
    local f = fixture()
    local line = f:line()
    f.grouped, f.raid = false, true
    f:progress(844)
    f.units.Friend = "raid2"
    f.module.Show(line)
    assert(f.tip.visible and f:contains("Friend"), "3.3.5 raid groups qualify independently of party membership")
    equal(#f.tickers, 1, "raid hover starts one ticker")
    f.raid = false
    f:tick()
    assert(f.tickers[1].cancelled and not f.tip.visible, "leaving a raid stops the tooltip")
end

do
    local f = fixture()
    local line = f:line()
    f.cached[844] = {objectives = {{text = "Explore location", numFulfilled = 0, numRequired = 0, finished = false}}}
    f.remote[844] = {Friend = {{fulfilled = 0, required = 0, finished = false}}}
    f.module.Show(line)
    assert(f.tip.visible and f:contains("Explore location"), "uncounted local and remote objectives render safely")
    assert(not f:contains("0/0"), "uncounted objectives do not display meaningless fractions")
end

do
    local f = fixture()
    local line = f:line()
    f.grouped = false
    f.module.Show(line)
    equal(f.creates, 0, "solo does not allocate a tooltip")
    equal(#f.tickers, 0, "solo does not poll")
    f.grouped = true
    for _, setting in ipairs({"enableTooltips", "trackerEnabled"}) do
        f.env.Questie.db.profile[setting] = false
        f.module.Show(line)
        equal(#f.tickers, 0, "disabled " .. setting .. " does not poll")
        f.env.Questie.db.profile[setting] = true
    end
    for _, mode in ipairs({"zone", "achieve", "scenario", "recipe"}) do
        line.mode = mode
        f.module.Show(line)
    end
    line.mode, line.Quest = "objective", {Id = 844}
    f.module.Show(line)
    equal(f.creates, 0, "non-quest rows and achievement collisions are excluded")
end

do
    local f = fixture()
    local title, objective = f:line(), f:line("objective")
    title.hovered = false
    f:progress(844)
    f.module.Show(objective)
    equal(f.tip.owner, title, "objective hover belongs to its quest title")
    equal(f.tip.anchor, "ANCHOR_NONE", "fixed tooltip anchor")
    equal(f.tip.point[1], "BOTTOMLEFT", "tooltip bottom anchors above title")
    equal(f.tip.point[2], title, "tooltip anchor references title")
    equal(f.tip.point[3], "TOPLEFT", "tooltip above title")
    equal(f.tickers[1].interval, 0.5, "hover refresh interval")
    assert(f:contains("Quest 844") and f:contains("Me") and f:contains("Friend"), "quest and player headings")
    assert(f:contains("2/7") and f:contains("3/7"), "local and remote counts")
    f.cached[844].objectives[1].numFulfilled = 4
    f.cached[844].objectives[1].raw_text = "Plainstrider Beak: 4/7"
    f.remote[844].Friend[1].fulfilled = 5
    f:tick()
    assert(f:contains("4/7") and f:contains("5/7"), "stationary hover reads live cached counts")
    equal(f.creates, 1, "refresh reuses dedicated tooltip")
    equal(f.globalTooltipCalls, 0, "global item tooltip is untouched")
    objective.hovered = false
    f:tick()
    assert(f.tickers[1].cancelled and not f.tip.visible, "mouse leave stops polling and hides")
    local calls = f.queries
    f.tickers[1].callback()
    equal(f.queries, calls, "no background work after leave")
end

do
    local f = fixture()
    local line = f:line()
    f:progress(844)
    f.remote[844].Nearby = {{fulfilled = 6, required = 7}}
    f.remote[844].Me = {{fulfilled = 99, required = 99}}
    f.module.Show(line)
    assert(not f:contains("Nearby") and not f:contains("99/99"), "non-group and own remote entries excluded")
    f.connected = false
    f:tick()
    assert(not f:contains("Friend"), "offline party data is not presented as current")
    f.connected = true
    f.remote[844].Friend[1].status = "F"
    f:tick()
    assert(f:contains("Failed"), "remote failed quest status is visible")
    f.remote[844].Friend[1] = {fulfilled = 7, required = 7, finished = true, status = "I"}
    f:tick()
    assert(f:contains("7/7"), "full remote objective count remains visible")
    -- A full counter cannot prove that unrelated quest requirements are complete.
    assert(not f:contains("Quest Complete!"), "remote full counter does not invent turn-in readiness")
    f.remote[844].Friend[1].status = nil
    f:tick()
    assert(not f:contains("Quest Complete!"), "legacy full objectives without quest status do not invent completion")
    f.remote[844].Friend[1].status = "C"
    f:tick()
    assert(f:contains("Quest Complete!"), "explicit remote completion is displayed")
    f.remote[844].Friend[1].status = nil
    line.Quest.state = -1
    f:tick()
    assert(f:contains("Failed"), "local failure is displayed")
    line.Quest.state = 1
    f:tick()
    assert(f:contains("Quest Complete!"), "local completion is displayed")
end

do
    local f = fixture()
    local objective = f:line("objective")
    f.cached[844] = {objectives = {
        [3] = {text = "Third objective", numFulfilled = 2, numRequired = 4, finished = false},
        [1] = {text = "First objective", numFulfilled = 1, numRequired = 4, finished = false},
    }}
    f.remote[844] = {Friend = {
        [3] = {fulfilled = 3, required = 4},
        [2] = {fulfilled = 0, required = 1},
        [1] = {fulfilled = 2, required = 4},
        metadata = "ignored",
    }}
    f.module.Show(objective)
    equal(f.tip.owner, objective, "objective itself anchors when no title exists")
    local rendered = table.concat(f.tip.lines, "\n")
    assert(rendered:find("1/4 First objective", 1, true) < rendered:find("2/4 Third objective", 1, true),
        "sparse local objectives use index order")
    assert(rendered:find("2/4 First objective", 1, true) < rendered:find("0/1 Unknown", 1, true),
        "remote objective without a local label uses Unknown")
    assert(rendered:find("0/1 Unknown", 1, true) < rendered:find("3/4 Third objective", 1, true),
        "sparse remote objectives retain server objective order")
    equal(f:contains("metadata"), false, "non-objective metadata is ignored")
end

for _, change in ipairs({
    function(f, line) line.visible = false end,
    function(f, line) f.present[844] = nil end,
    function(f, line) f.quests[844] = {Id = 844} end,
    function(f, line) line.mode = "zone" end,
    function(f) f.grouped = false end,
    function(f) f.env.Questie.db.profile.enableTooltips = false end,
    function(f) f.env.Questie.db.profile.trackerEnabled = false end,
}) do
    local f = fixture()
    local line = f:line()
    f:progress(844)
    f.module.Show(line)
    change(f, line)
    f:tick()
    assert(f.tickers[1].cancelled and not f.tip.visible, "invalid hover cancels refresh")
end

do
    local f = fixture()
    local line = f:line()
    f.module.Show(line)
    assert(not f.tip.visible, "missing initial snapshot hides tooltip")
    f:progress(844)
    f:tick()
    assert(f.tip.visible and f:contains("3/7"), "data arriving during hover appears without moving")
    local other = f:line("quest", 853)
    f:progress(853)
    line.hovered = false
    f.module.Show(other)
    assert(f.tickers[1].cancelled, "switching hover cancels old ticker")
    f.module.Hide(line)
    assert(not f.tickers[2].cancelled and f.tip.visible, "late leave from previous row is ignored")
    f.module.Hide(other)
    assert(f.tickers[2].cancelled and not f.tip.visible, "own row hide cancels ticker")
    equal(f.creates, 1, "subsequent hovers reuse tooltip")
end

do
    local f = fixture()
    local line = f:line()
    f:progress(844)
    f.module.Show(line)
    local button = {hovered = true}
    function button:GetParent() return line end
    function button:IsVisible() return true end
    line.statusIcon = button
    f:tick()
    assert(f.tickers[1].cancelled and not f.tip.visible, "moving onto a child control stops row tooltip refresh")
end

for _, key in ipairs({"statusIcon", "playButton", "expandQuest", "button", "altButton"}) do
    local f = fixture()
    local line = f:line()
    local button = {hovered = true}
    function button:GetParent() return line end
    function button:IsVisible() return true end
    line[key] = button
    f:progress(844)
    f.module.Show(line)
    equal(#f.tickers, 0, key .. " keeps its own tooltip without starting a hover refresh")
end
print("Tracker quest tooltip: grouped cached progress, anchors, hover timers and pooled-row cleanup passed")
